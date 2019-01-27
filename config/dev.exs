use Mix.Config

config :evercam_models, Evercam.Repo,
  types: Evercam.PostgresTypes,
  username: "postgres",
  password: "postgres",
  show_sensitive_data_on_connection_error: true,
  database: "evercam_dev"

# config :evercam_models, Evercam.SnapshotRepo,
#   username: "postgres",
#   password: "postgres",
#   database: System.get_env["db"] || "evercam_dev"
