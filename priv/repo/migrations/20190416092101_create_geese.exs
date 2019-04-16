defmodule Evercam.Repo.Migrations.CreateGeese do
	use Ecto.Migration

  def change do
  	create table(:geese) do
			add :geese_number, :integer
			add :date, :string
			add :cam, :string
			add :geese_number1, :integer
			add :geese_number3, :integer
			add :min, :integer
			add :max, :integer
			add :sum, :integer
			add :accuracy, :integer
			add :date_recorded, :naive_datetime
			add :hour, :integer
			add :geeseinput, :integer
			add :frame, :string

      timestamps()
    end
	end
end
