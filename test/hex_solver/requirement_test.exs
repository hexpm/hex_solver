defmodule HexSolver.RequirementTest do
  use HexSolver.Case, async: true
  use ExUnitProperties

  alias HexSolver.Requirement
  alias HexSolver.Constraints.{Range, Union}

  describe "to_constraint!/" do
    property "always converts" do
      check all requirement <- requirement() do
        constraint = Requirement.to_constraint!(requirement.source)
        assert constraint.__struct__ in [Range, Union, Version]
      end
    end

    test "merge overlapping ranges" do
      assert Requirement.to_constraint!("~> 1.0 or ~> 1.1") == %Range{
               min: v("1.0.0"),
               max: v("2.0.0-0"),
               include_min: true
             }

      assert Requirement.to_constraint!("~> 1.0 or ~> 2.0") == %Union{
               ranges: [
                 %Range{min: v("1.0.0"), max: v("2.0.0-0"), include_min: true},
                 %Range{min: v("2.0.0"), max: v("3.0.0-0"), include_min: true}
               ]
             }
    end
  end
end
