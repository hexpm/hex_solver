defmodule Resolver.MixProject do
  use Mix.Project

  def project do
    [
      app: :resolver,
      version: "0.1.0",
      elixir: "~> 1.13-dev",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
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
      {:stream_data, "~> 0.5.0", only: :test}
    ]
  end

  defp aliases() do
    [
      "resolver.registry": &resolver_registry/1,
      test: &test/1
    ]
  end

  defp resolver_registry(_args) do
    Mix.Task.run("deps.get")
    Mix.Task.run("deps.compile")
    File.mkdir_p!("priv")

    {:ok, {200, _, names}} = :hex_repo.get_names(hex_config())

    result =
      Task.async_stream(
        names,
        fn %{name: package} ->
          {:ok, {200, _, registry}} = :hex_repo.get_package(hex_config(), package)
          {package, registry}
        end,
        ordered: false
      )
      |> Map.new(fn {:ok, package} -> package end)

    File.write!("priv/registry.term", :zlib.gzip(:erlang.term_to_binary(result)))
  end

  defp hex_config() do
    %{:hex_core.default_config() | http_adapter: {:hex_http_httpc, %{http_options: [ssl: []]}}}
  end

  defp test(args) do
    unless File.exists?("priv/registry.term") do
      Mix.Task.run("resolver.registry")
    end

    Mix.Task.run("test", args)
  end
end
