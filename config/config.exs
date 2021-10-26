import Config

config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

config :logger, :console, format: "[$level] $levelpad$message\n"

import_config "#{config_env()}.exs"
