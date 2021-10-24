defmodule Resolver.MixProject do
  use Mix.Project

  def project do
    [
      app: :resolver,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
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
