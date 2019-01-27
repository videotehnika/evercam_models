use Mix.Config

config :evercam_models, Evercam.Repo,
  types: Evercam.PostgresTypes,
  url: Application.get_env(:evercam_models, :repo),
  socket_options: [keepalive: true],
  timeout: 60_000,
  pool_size: 80,
  lazy: false,
  ssl: true

config :evercam_models, Evercam.SnapshotRepo,
  url: System.get_env("DATABASE_SNAPSHOT_URL"),
  ownership_timeout: 60_000,
  socket_options: [keepalive: true],
  timeout: 60_000,
  pool_size: 100,
  lazy: false,
  ssl: true