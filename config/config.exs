import Config

config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

config :logger, :console, format: "[$level] $levelpad$message\n"

if config_env() == :test do
  max_runs = String.to_integer(System.get_env("MAX_RUNS") || "1000")
  config :stream_data, max_runs: max_runs
end
