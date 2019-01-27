use Mix.Config

config :evercam_models, ecto_repos: [Evercam.Repo, Evercam.SnapshotRepo]

import_config "#{Mix.env()}.exs"
