ExUnit.start()

defmodule Resolver.Case do
  use ExUnit.CaseTemplate
  alias Resolver.Requirement
  alias Resolver.Constraints.{Empty, Range, Union}

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  def requirement() do
    StreamData.member_of(:persistent_term.get({:resolver_test, :requirements}))
  end

  def constraint() do
    StreamData.member_of(:persistent_term.get({:resolver_test, :constraints}))
  end

  def range() do
    StreamData.member_of(:persistent_term.get({:resolver_test, :ranges}))
  end

  def union() do
    StreamData.member_of(:persistent_term.get({:resolver_test, :unions}))
  end

  def version() do
    StreamData.member_of(:persistent_term.get({:resolver_test, :versions}))
  end

  def init_registry() do
    registry =
      "test/fixtures/registry.json"
      |> File.read!()
      |> Jason.decode!()

    versions =
      registry
      |> Map.get("versions")
      |> Enum.shuffle()
      |> Enum.map(&Version.parse!/1)

    requirements =
      registry
      |> Map.get("requirements")
      |> Enum.shuffle()
      |> Enum.map(&Version.parse_requirement!/1)

    constraints = Enum.map(requirements, &Requirement.to_constraint!/1)
    constraints = [%Empty{}, %Range{}] ++ constraints
    ranges = Enum.filter(constraints, &match?(%Range{}, &1))
    unions = Enum.filter(constraints, &match?(%Union{}, &1))

    :persistent_term.put({:resolver_test, :versions}, versions)
    :persistent_term.put({:resolver_test, :requirements}, requirements)
    :persistent_term.put({:resolver_test, :constraints}, constraints)
    :persistent_term.put({:resolver_test, :ranges}, ranges)
    :persistent_term.put({:resolver_test, :unions}, unions)
  end

  def v(string) do
    Version.parse!(string)
  end
end

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
      Enum.map(dependencies, fn
        {package, requirement} ->
          {package, {Resolver.Requirement.to_constraint!(requirement), false}}

        {package, requirement, :optional} ->
          {package, {Resolver.Requirement.to_constraint!(requirement), true}}
      end)

    Process.put({__MODULE__, :versions, package}, versions)
    Process.put({__MODULE__, :dependencies, package, version}, dependencies)
  end
end

Resolver.Case.init_registry()
