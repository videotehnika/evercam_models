use Mix.Config

config :evercam_models, Evercam.Repo,
  types: Evercam.PostgresTypes,
  username: "postgres",
  password: "postgres",
  database: "evercam_dev"

config :evercam_models, Evercam.SnapshotRepo,
  username: "postgres",
  password: "postgres",
  database: "evercam_dev"
