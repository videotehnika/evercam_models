use Mix.Config

config :evercam_models, ecto_repos: [Evercam.Repo]

import_config "#{Mix.env()}.exs"
