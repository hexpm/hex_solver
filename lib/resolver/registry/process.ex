defmodule Resolver.Registry.Process do
  @behaviour Resolver.Registry

  def versions(package) do
    case Process.get({__MODULE__, :versions, package}) do
      nil -> :error
      versions -> {:ok, versions}
    end
  end

  def dependencies(package, version) do
    case Process.get({__MODULE__, :dependencies, package, version}) do
      nil -> :error
      dependencies -> {:ok, dependencies}
    end
  end

  def put(package, version, dependencies) do
    version = Version.parse!(version)
    versions = Process.get({__MODULE__, :versions, package}, [])
    versions = Enum.sort([version | versions], Version)

    dependencies =
      Enum.map(dependencies, fn {package, requirement} ->
        {package, Resolver.Requirement.to_constraint!(requirement)}
      end)

    Process.put({__MODULE__, :versions, package}, versions)
    Process.put({__MODULE__, :dependencies, package, version}, dependencies)
  end
end
