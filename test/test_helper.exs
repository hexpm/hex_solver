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

Resolver.Case.init_registry()
