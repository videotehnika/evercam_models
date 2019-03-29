defmodule Evercam.Repo.Migrations.AddLinkedFieldToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :linked_id, :string
    end
  end
end
