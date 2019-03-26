defmodule Project do
  use Evercam.Schema

  @required_fields [:name, :exid, :user_id]
  @optional_fields [:updated_at, :inserted_at]

  schema "projects" do
    belongs_to :user, User, foreign_key: :user_id
    has_many :camera, Camera

    field :name, :string
    field :exid, :string
    timestamps(type: :utc_datetime_usec, default: Calendar.DateTime.now_utc)
  end

  def by_user(user_id) do
    Project
    |> where(user_id: ^user_id)
    |> preload(:user)
    |> Repo.all
  end

  def by_exid(exid) do
    Project
    |> where(exid: ^exid)
    |> preload(:user)
    |> Repo.all
  end

  def delete_by_exid(exid) do
    Project
    |> where(exid: ^exid)
    |> Repo.delete_all
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
