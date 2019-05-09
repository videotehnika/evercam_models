defmodule Overlay do
  use Evercam.Schema

  @required_fields [:path, :project_id, :sw_bounds, :ne_bounds]

  schema "overlays" do
    belongs_to :projects, Project, foreign_key: :project_id

    field :path, :string
    field :sw_bounds, Geo.PostGIS.Geometry
    field :ne_bounds, Geo.PostGIS.Geometry
  end

  def by_project_id(project_id) do
    Overlay
    |> where(project_id: ^project_id)
    |> preload(:projects)
    |> Repo.all
  end

  def delete_by_id(id) do
    Overlay
    |> where(id: ^id)
    |> Repo.delete_all
  end

  def delete_by_project_id(project_id) do
    Overlay
    |> where(project_id: ^project_id)
    |> Repo.delete_all
  end

  def insert_overlay(project_id, path, sw_points, ne_points) do
    overlay_params =
      %{
        project_id: project_id,
        path: path,
        sw_bounds: sw_points,
        ne_bounds: ne_points
      }
    overlay_changeset = changeset(%Overlay{}, overlay_params)
    case Repo.insert(overlay_changeset) do
      {:ok, overlay} -> {:ok, overlay}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
  end
end
