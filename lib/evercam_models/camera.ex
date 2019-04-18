defmodule Camera do
  use Evercam.Schema

  @required_fields [:name, :owner_id, :config, :is_public, :is_online_email_owner_notification]
  @optional_fields [:exid, :timezone, :thumbnail_url, :is_online, :offline_reason, :last_polled_at, :alert_emails, :last_online_at, :updated_at, :created_at, :model_id, :location, :mac_address, :discoverable, :project_id]

  schema "cameras" do
    belongs_to :owner, User, foreign_key: :owner_id
    belongs_to :vendor_model, VendorModel, foreign_key: :model_id
    belongs_to :projects, Project, foreign_key: :project_id
    has_many :access_rights, AccessRight
    has_many :shares, CameraShare
    has_one :cloud_recordings, CloudRecording
    has_one :timelapse_recordings, TimelapseRecording

    field :exid, :string
    field :name, :string
    field :timezone, :string
    field :thumbnail_url, :string
    field :is_online, :boolean
    field :offline_reason, :string
    field :is_public, :boolean, default: false
    field :is_online_email_owner_notification, :boolean, default: false
    field :alert_emails, :string
    field :discoverable, :boolean, default: false
    field :config, Evercam.Types.JSON
    field :mac_address, Evercam.Types.MACADDR
    field :location, Geo.PostGIS.Geometry
    field :last_polled_at, :utc_datetime_usec, default: Calendar.DateTime.now_utc
    field :last_online_at, :utc_datetime_usec, default: Calendar.DateTime.now_utc
    timestamps(inserted_at: :created_at, type: :utc_datetime_usec, default: Calendar.DateTime.now_utc)
  end

  def all do
    Camera
    |> preload(:cloud_recordings)
    |> preload(:vendor_model)
    |> preload([vendor_model: :vendor])
    |> Repo.all
  end

  def get_offline_cameras() do
    Camera
    |> where([c], c.is_online == false)
    |> Repo.all
  end

  def get_timelapse_recording_cameras() do
    Camera
    |> join(:inner, [c], tr in TimelapseRecording, on: tr.camera_id == c.id)
    |> preload(:timelapse_recordings)
    |> preload(:owner)
    |> preload(:vendor_model)
    |> preload([vendor_model: :vendor])
    |> Repo.all
  end

  def all_offline(day_before) do
    Camera
    |> where(is_online: false)
    |> where([c], c.last_online_at >= ^day_before)
    |> preload(:owner)
    |> Repo.all
  end

  def invalidate_user(nil), do: :noop
  def invalidate_user(%User{} = user) do
    ConCache.delete(:cameras, "#{user.username}_true")
    ConCache.delete(:cameras, "#{user.username}_false")
  end

  def invalidate_camera(nil), do: :noop
  def invalidate_camera(%Camera{} = camera) do
    ConCache.delete(:camera_full, camera.exid)
    ConCache.delete(:camera, camera.exid)
    invalidate_shares(camera)
  end

  defp invalidate_shares(%Camera{} = camera) do
    CameraShare
    |> where(camera_id: ^camera.id)
    |> preload(:user)
    |> Repo.all
    |> Enum.map(fn(cs) -> cs.user end)
    |> Enum.concat([camera.owner])
    |> Enum.each(fn(user) -> invalidate_user(user) end)
  end

  def for(user, true), do: owned_by(user) |> Enum.concat(shared_with(user))
  def for(user, false), do: owned_by(user)

  defp owned_by(user) do
    Camera
    |> where([cam], cam.owner_id == ^user.id)
    |> preload(:owner)
    |> preload(:projects)
    |> preload(:cloud_recordings)
    |> preload(:timelapse_recordings)
    |> preload([vendor_model: :vendor])
    |> Repo.all
  end

  defp shared_with(user) do
    Camera
    |> join(:left, [u], cs in CameraShare)
    |> where([cam, cs], cs.user_id == ^user.id)
    |> where([cam, cs], cam.id == cs.camera_id)
    |> preload(:owner)
    |> preload(:projects)
    |> preload(:cloud_recordings)
    |> preload(:timelapse_recordings)
    |> preload([vendor_model: :vendor])
    |> preload([access_rights: :access_token])
    |> Repo.all
  end

  def get(exid) do
    ConCache.dirty_get_or_store(:camera, exid, fn() ->
      Camera.by_exid(exid)
    end)
  end

  def get_full(exid) do
    exid = String.downcase(exid)

    ConCache.dirty_get_or_store(:camera_full, exid, fn() ->
      Camera.by_exid_with_associations(exid)
    end)
  end

  def by_exid(exid) do
    Camera
    |> where(exid: ^exid)
    |> Repo.one
  end

  def by_exid_with_associations(exid) do
    Camera
    |> where([cam], cam.exid == ^String.downcase(exid))
    |> preload(:owner)
    |> preload(:projects)
    |> preload(:cloud_recordings)
    |> preload(:timelapse_recordings)
    |> preload([vendor_model: :vendor])
    |> preload([access_rights: :access_token])
    |> Repo.one
  end

  def auth(camera) do
    username(camera) <> ":" <> password(camera)
  end

  def username(camera) do
    Util.deep_get(camera, [:config, "auth", "basic", "username"], "")
  end

  def password(camera) do
    Util.deep_get(camera, [:config, "auth", "basic", "password"], "")
  end

  def snapshot_url(camera, type \\ "jpg") do
    cond do
      external_url(camera) != "" && res_url(camera, type) != "" ->
        "#{external_url(camera)}#{res_url(camera, type)}"
      external_url(camera) != "" ->
        "#{external_url(camera)}"
      true ->
        ""
    end
  end

  def hd_snapshot_url(camera) do
    cond do
      secondary_url(camera) != "" ->
        "#{secondary_url(camera)}/Streaming/Channels/1/picture"
      true ->
        ""
    end
  end

  def secondary_url(camera, protocol \\ "http") do
    host = host(camera) |> to_string
    port = camera.config["secondary_port"]
    case {host, port} do
      {"", _} -> ""
      {host, ""} -> "#{protocol}://#{host}"
      {host, port} -> "#{protocol}://#{host}:#{port}"
    end
  end

  def external_url(camera, protocol \\ "http") do
    host = host(camera) |> to_string
    port = port(camera, "external", protocol) |> to_string
    case {host, port} do
      {"", _} -> ""
      {host, ""} -> "#{protocol}://#{host}"
      {host, port} -> "#{protocol}://#{host}:#{port}"
    end
  end

  def internal_snapshot_url(camera, type \\ "jpg") do
    case internal_url(camera) != "" && res_url(camera, type) != "" do
      true -> internal_url(camera) <> res_url(camera, type)
      false -> ""
    end
  end

  def internal_url(camera, protocol \\ "http") do
    host = host(camera, "internal") |> to_string
    port = port(camera, "internal", protocol) |> to_string
    case {host, port} do
      {"", _} -> ""
      {host, ""} -> "#{protocol}://#{host}"
      {host, port} -> "#{protocol}://#{host}:#{port}"
    end
  end

  def res_url(camera, type \\ "jpg") do
    url = Util.deep_get(camera, [:config, "snapshots", "#{type}"], "")
    case String.starts_with?(url, "/") || url == "" do
      true -> "#{url}"
      false -> "/#{url}"
    end
  end

  defp url_path(camera, type) do
    cond do
      res_url(camera, type) != "" ->
        res_url(camera, type)
      res_url(camera, type) == "" && VendorModel.get_url(camera.vendor_model, type) != nil ->
        VendorModel.get_url(camera.vendor_model, type)
      true ->
        ""
    end
  end

  def host(camera, network \\ "external") do
    camera.config["#{network}_host"]
  end

  def port(camera, network, protocol) do
    camera.config["#{network}_#{protocol}_port"]
  end

  def get_nvr_port(camera) do
    external_port = port(camera, "external", "http")
    case port(camera, "nvr", "http") do
      "" -> external_port
      nil -> external_port
      nvr_port -> nvr_port
    end
  end

  def rtsp_url(camera, network \\ "external", type \\ "h264", include_auth \\ true) do
    auth =
      case include_auth do
        true -> check_auth("#{auth(camera)}@")
        _ -> ""
      end
    path = url_path(camera, type)
    host = host(camera)
    port = port(camera, network, "rtsp")

    case path != "" && host != "" && "#{port}" != "" && "#{port}" != 0 do
      true -> "rtsp://#{auth}#{host}:#{port}#{path}"
      false -> ""
    end
  end

  defp check_auth(auth) do
    case auth do
      ":@" -> ""
      _ -> auth
    end
  end

  def get_vendor_attr(camera_full, attr) do
    case camera_full.vendor_model do
      nil -> ""
      vendor_model -> Map.get(vendor_model.vendor, attr)
    end
  end

  def get_model_attr(camera_full, attr) do
    case camera_full.vendor_model do
      nil -> ""
      vendor_model -> Map.get(vendor_model, attr)
    end
  end

  def get_auth_type(camera_full) do
    case camera_full.vendor_model do
      nil -> "basic"
      vendor_model -> Map.get(vendor_model, :auth_type)
    end
  end

  def get_timezone(camera) do
    case camera.timezone do
      nil -> "Etc/UTC"
      timezone -> timezone
    end
  end

  def get_offset(camera) do
    camera
    |> Camera.get_timezone
    |> Calendar.DateTime.now!
    |> Calendar.Strftime.strftime!("%z")
  end

  def get_mac_address(camera) do
    case camera.mac_address do
      nil -> ""
      mac_address -> Evercam.Types.MACADDR.decode(mac_address)
    end
  end

  def get_location(camera) do
    case camera.location do
      %Geo.Point{coordinates: {lng, lat}} ->
        %{lng: lng, lat: lat}
      _nil ->
        %{lng: 0, lat: 0}
    end
  end

  def get_camera_info(exid) do
    camera = Camera.get(exid)
    %{
      "url" => external_url(camera),
      "auth" => auth(camera)
    }
  end

  def get_rights(camera, user) do
    cond do
      user == nil && camera.is_public ->
        "snapshot,list"
      is_owner?(user, camera) ->
        "snapshot,list,edit,delete,view,grant~snapshot,grant~view,grant~edit,grant~delete,grant~list"
      camera.access_rights == [] ->
        "snapshot,list"
      true ->
        camera.access_rights
        |> Enum.filter(fn(ar) -> Util.deep_get(ar, [:access_token, :user_id], 0) == user.id && ar.status == 1 end)
        |> Enum.map(fn(ar) -> ar.right end)
        |> Enum.concat(["snapshot", "list"])
        |> Enum.uniq
        |> Enum.join(",")
    end
  end

  def is_owner?(nil, _camera), do: false
  def is_owner?(user, camera) do
    user.id == camera.owner_id
  end

  def get_remembrance_camera do
    Camera
    |> where(exid: "evercam-remembrance-camera")
    |> preload(:owner)
    |> Repo.one
  end

  def update_status(camera, status, mac_address \\ nil) do
    params = %{"is_online" => status}
    params =
      case mac_address do
        nil -> params
        _ -> params |> Map.merge(%{"mac_address" => mac_address})
      end
    changeset = changeset(camera, params)
    Repo.update!(changeset)
  end

  def delete_by_owner(owner_id) do
    Camera
    |> where([cam], cam.owner_id == ^owner_id)
    |> Repo.delete_all
  end

  def delete_by_id(camera_id) do
    Camera
    |> where(id: ^camera_id)
    |> Repo.delete_all
  end

  def validate_params(camera_changeset) do
    timezone = get_field(camera_changeset, :timezone)
    config = get_field(camera_changeset, :config)
    cond do
      config["external_host"] == nil || config["external_host"] == "" ->
        add_error(camera_changeset, :external_host, "can't be blank")
      !valid?("address", config["external_host"]) ->
        add_error(camera_changeset, :external_host, "External url is invalid")
      !is_nil(timezone) && !Tzdata.zone_exists?(timezone) ->
        add_error(camera_changeset, :timezone, "Timezone does not exist or is invalid")
      true ->
        camera_changeset
    end
  end

  def valid?("address", value) do
    valid?("ip_address", value) || valid?("domain", value)
  end

  def valid?("ip_address", value) do
    case :inet_parse.strict_address(to_charlist(value)) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  def valid?("domain", value) do
    :inet_parse.domain(to_charlist(value)) && String.contains?(value, ".")
  end

  defp validate_lng_lat(camera_changeset, nil, nil), do: camera_changeset
  defp validate_lng_lat(camera_changeset, _lng, nil), do: add_error(camera_changeset, :location_lat, "Must provide both location coordinates")
  defp validate_lng_lat(camera_changeset, nil, _lat), do: add_error(camera_changeset, :location_lng, "Must provide both location coordinates")
  defp validate_lng_lat(camera_changeset, lng, lat), do: put_change(camera_changeset, :location, %Geo.Point{coordinates: {lng, lat}})

  defp validate_exid(changeset) do
    case get_field(changeset, :exid) do
      nil -> auto_generate_camera_id(changeset)
      _exid -> changeset |> update_change(:exid, &String.downcase/1)
    end
  end

  defp auto_generate_camera_id(changeset) do
    case get_field(changeset, :name) do
      nil ->
        changeset
      camera_name ->
        camera_id =
          camera_name
          |> Util.slugify
          |> String.replace(" ", "")
          |> String.replace("-", "")
          |> String.downcase
          |> String.slice(0..4)
        put_change(changeset, :exid, "#{camera_id}-#{Enum.take_random(?a..?z, 5)}")
    end
  end

  def count(query \\ Camera) do
    query
    |> select([cam], count(cam.id))
    |> Repo.one
  end

  def public_cameras_query(coordinates, within_distance) do
    Camera
    |> Camera.where_public_and_discoverable
    |> Camera.by_distance(coordinates, within_distance)
  end

  def get_query_with_associations(query) do
    query
    |> preload(:owner)
    |> preload(:vendor_model)
    |> preload([vendor_model: :vendor])
    |> Repo.all
  end

  def get_query_with_associations(query, limit, offset) do
    query
    |> limit(^limit)
    |> offset(^offset)
    |> preload(:owner)
    |> preload(:vendor_model)
    |> preload([vendor_model: :vendor])
    |> Repo.all
  end

  def where_public_and_discoverable(query \\ Camera) do
    query
    |> where([cam], cam.is_public == true )
    |> where([cam], cam.discoverable == true)
  end

  def by_distance(query \\ Camera, _coordinates, _within_distance)
  def by_distance(query, {0, 0}, _within_distance), do: query
  def by_distance(query, {lng, lat}, within_distance) do
    query
    |> where([cam], fragment("ST_DWithin(?, ST_SetSRID(ST_Point(?, ?), 4326)::geography, CAST(? AS float8))", cam.location, ^lng, ^lat, ^within_distance))
  end

  def where_location_is_not_nil(query \\ Camera) do
    query
    |> where([cam], not(is_nil(cam.location)))
  end

  def delete_changeset(camera, params \\ :invalid) do
    camera
    |> cast(params, @required_fields ++ @optional_fields)
  end

  def changeset(camera, params \\ :invalid) do
    camera
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, max: 24, message: "Camera Name is too long. Maximum 24 characters.")
    |> validate_exid
    |> validate_params
    |> unique_constraint(:exid, [name: "cameras_exid_index"])
    |> validate_lng_lat(params[:location_lng], params[:location_lat])
  end
end
