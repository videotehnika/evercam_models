defmodule EvercamModels.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Starts a worker by calling: EvercamModels.Worker.start_link(arg)
      # {EvercamModels.Worker, arg}
      {Evercam.Repo, []}
      # {Evercam.SnapshotRepo, []}
    ]

    opts = [strategy: :one_for_one, name: EvercamModels.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
