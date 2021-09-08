defmodule Resolver.RequirementTest do
  use Resolver.Case, async: true
  use ExUnitProperties

  alias Resolver.Requirement
  alias Resolver.Constraints.{Range, Union}

  describe "to_constraint!/" do
    property "always converts" do
      check all requirement <- requirement() do
        constraint = Requirement.to_constraint!(requirement.source)
        assert constraint.__struct__ in [Range, Union, Version]
      end
    end
  end
end
