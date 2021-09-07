defmodule Resolver.Registry.Process do
  @behaviour Resolver.Registry

  def versions(package) do
    Process.get({__MODULE__, :versions, package})
  end

  def dependencies(package, version) do
    Process.get({__MODULE__, :dependencies, package, version})
  end

  def put(package, version, dependencies) do
    version = Version.parse!(version)
    versions = Process.get({__MODULE__, :versions, package}, [])
    versions = Enum.sort([version | versions], Version)

    dependencies =
      Enum.map(dependencies, fn {package, requirement} ->
        {package, Resolver.Requirement.parse!(requirement)}
      end)

    Process.put({__MODULE__, :versions, package}, versions)
    Process.put({__MODULE__, :dependencies, package, version}, dependencies)
  end
end
