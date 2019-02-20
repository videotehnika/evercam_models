defmodule CameraActivity do
  use Evercam.Schema

  @required_fields [:camera_id, :action]
  @optional_fields [:access_token_id, :camera_exid, :name, :action, :extra, :done_at]

  schema "camera_activities" do
    belongs_to :camera, Camera
    belongs_to :access_token, AccessToken

    field :action, :string
    field :done_at, :utc_datetime_usec, default: Calendar.DateTime.now_utc
    field :extra, Evercam.Types.JSON
    field :camera_exid, :string
    field :name, :string
  end

  def get_all(query) do
    query
    |> order_by([c], desc: c.done_at)
    |> SnapshotRepo.all
  end

  def delete_by_camera_id(camera_id) do
    CameraActivity
    |> where(camera_id: ^camera_id)
    |> SnapshotRepo.delete_all
  end

  def for_a_user(token_id, from, to, types) do
    CameraActivity
    |> where(access_token_id: ^token_id)
    |> where([c], c.done_at >= ^from and c.done_at <= ^to)
    |> with_types_if_specified(types)
    |> order_by([c], desc: c.done_at)
    |> SnapshotRepo.all
  end

  def get_last_on_off_log(camera_id, action \\ ["online", "offline"]) do
    CameraActivity
    |> where(camera_id: ^camera_id)
    |> where([c], c.action in ^action)
    |> order_by(desc: :id)
    |> limit(1)
    |> SnapshotRepo.one
  end

  def with_types_if_specified(query, nil) do
    query
  end
  def with_types_if_specified(query, types) do
    query
    |> where([c], c.action in ^types)
  end

  def changeset(camera_activity, params \\ :invalid) do
    camera_activity
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:camera_id, name: :camera_activities_camera_id_done_at_index)
  end
end
