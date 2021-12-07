defmodule HexSolver.MixProject do
  use Mix.Project

  def project do
    [
      app: :hex_solver,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      config_path: config_path(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp config_path() do
    if Version.compare(System.version(), "1.11.0") in [:eq, :gt] do
      "config/config.exs"
    else
      "config/mix_config.exs"
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:hex_core, "~> 0.8.2", only: :dev},
      {:jason, "~> 1.2", only: [:dev, :test]},
      {:stream_data, "~> 0.5.0", only: [:dev, :test]}
    ]
  end
end
