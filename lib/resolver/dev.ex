if Mix.env() == :dev do
  defmodule Resolver.Dev do
    def test_registry() do
      {:ok, {200, _, names}} = :hex_repo.get_names(hex_config())

      registry =
        Task.async_stream(
          names,
          fn %{name: package} ->
            {:ok, {200, _, registry}} = :hex_repo.get_package(hex_config(), package)
            registry = Enum.map(registry, &Map.drop(&1, [:inner_checksum, :outer_checksum]))
            {package, registry}
          end,
          ordered: false
        )
        |> Enum.map(fn {:ok, package} -> package end)

      map = %{
        "requirements" => registry_requirements(registry),
        "versions" => registry_versions(registry)
      }

      File.write!("test/fixtures/registry.json", Jason.encode!(map, pretty: true))
    end

    defp registry_versions(registry) do
      registry
      |> Enum.flat_map(fn {_package, versions} ->
        Enum.map(versions, & &1.version)
      end)
      |> Enum.uniq()
      |> Enum.sort(Version)
    end

    defp registry_requirements(registry) do
      registry
      |> Enum.flat_map(fn {_package, versions} ->
        Enum.flat_map(versions, fn version ->
          Enum.map(version.dependencies, & &1.requirement)
        end)
      end)
      |> Enum.uniq()
      |> Enum.sort()
    end



    defp hex_config() do
      %{:hex_core.default_config() | http_adapter: {:hex_http_httpc, %{http_options: [ssl: []]}}}
    end
  end
end
