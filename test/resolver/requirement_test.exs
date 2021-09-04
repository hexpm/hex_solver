defmodule Resolver.RequirementTest do
  use Resolver.Case, async: true
  use ExUnitProperties

  alias Resolver.Requirement
  alias Resolver.Constraint.{Range, Union}

  describe "parse!/" do
    property "always parses" do
      check all(requirement <- requirements()) do
        constraint = Requirement.parse!(requirement.source)
        assert constraint.__struct__ in [Range, Union, Elixir.Version]
      end
    end
  end
end
