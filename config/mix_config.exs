use Mix.Config

config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

config :logger, :console, format: "[$level] $levelpad$message\n"

if Mix.env() == :test do
  config :stream_data, max_runs: 1000
end