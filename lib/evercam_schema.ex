defmodule Evercam.Schema do
  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      require Logger
      alias Evercam.Repo
      alias Evercam.SnapshotRepo
      alias Util
      import Ecto.Changeset
      import Ecto.Query
    end
  end
end
