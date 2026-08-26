defmodule HexSolver.RequirementTest do
  use HexSolver.Case, async: true
  use ExUnitProperties

  alias HexSolver.{Constraint, Requirement, UnsatisfiableRequirementError}
  alias HexSolver.Constraints.{Empty, Range, Union}

  @versions (for major <- 0..2, minor <- 0..2, patch <- 0..2, pre <- ["", "-0", "-rc.1"] do
               Version.parse!("#{major}.#{minor}.#{patch}#{pre}")
             end)

  @operators [">", ">=", "<", "<=", "==", "~>"]

  describe "to_constraint!/" do
    property "always converts" do
      check all requirement <- requirement() do
        constraint = Requirement.to_constraint!(requirement.source)
        assert constraint.__struct__ in [Range, Union, Version]
      end
    end

    test "union ranges" do
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

    test "intersect ranges" do
      assert Requirement.to_constraint!("~> 1.0 and ~> 1.1") == %Range{
               min: v("1.1.0"),
               max: v("2.0.0-0"),
               include_min: true
             }

      assert Requirement.to_constraint!("~> 1.0.0 and ~> 1.0") == %Range{
               min: v("1.0.0"),
               max: v("1.1.0-0"),
               include_min: true
             }

      assert Requirement.to_constraint!("~> 1.11 and >= 1.11.6") == %Range{
               min: v("1.11.6"),
               max: v("2.0.0-0"),
               include_min: true
             }

      assert Requirement.to_constraint!(">= 1.11.6 and ~> 1.11") == %Range{
               min: v("1.11.6"),
               max: v("2.0.0-0"),
               include_min: true
             }

      assert Requirement.to_constraint!(">= 1.0.0 and > 1.5.0") == %Range{min: v("1.5.0")}
      assert Requirement.to_constraint!("< 2.0.0 and <= 3.0.0") == %Range{max: v("2.0.0")}
      assert Requirement.to_constraint!("~> 1.0 and <= 1.0.0") == v("1.0.0")
      assert Requirement.to_constraint!("== 1.0.0 and >= 1.0.0") == v("1.0.0")
      assert Requirement.to_constraint!(">= 1.0.0 and <= 1.0.0") == v("1.0.0")

      for {requirement, left, right} <- [
            {"~> 1.0 and ~> 2.0", "~> 1.0", "~> 2.0"},
            {"~> 1.0 and >= 2.0.0", "~> 1.0", ">= 2.0.0"},
            {"== 1.0.0 and > 1.0.0", "1.0.0", "> 1.0.0"},
            {"> 1.0.0 and <= 1.0.0", "> 1.0.0", "<= 1.0.0"},
            {"< 0.0.0-0 and >= 1.0.0", "< 0.0.0-0", ">= 1.0.0"}
          ] do
        message =
          "requirement #{inspect(requirement)} is unsatisfiable because " <>
            "#{inspect(left)} and #{inspect(right)} are disjoint"

        assert_raise UnsatisfiableRequirementError, message, fn ->
          Requirement.to_constraint!(requirement)
        end

        assert Requirement.to_constraint(requirement) == :error
      end
    end

    test "intersect more than two ranges" do
      assert Requirement.to_constraint!(">= 1.0.0 and < 2.0.0 and > 1.5.0") == %Range{
               min: v("1.5.0"),
               max: v("2.0.0")
             }

      assert Requirement.to_constraint!("~> 1.0 and >= 1.2.0 and < 1.8.0 and >= 1.3.0") ==
               %Range{min: v("1.3.0"), max: v("1.8.0"), include_min: true}

      union = %Union{
        ranges: [
          %Range{min: v("1.5.0"), max: v("2.0.0")},
          %Range{min: v("3.0.0"), max: v("4.0.0-0"), include_min: true}
        ]
      }

      assert Requirement.to_constraint!(">= 1.0.0 and < 2.0.0 and > 1.5.0 or ~> 3.0") == union
      assert Requirement.to_constraint!("~> 3.0 or >= 1.0.0 and < 2.0.0 and > 1.5.0") == union

      message =
        ~s(requirement ">= 1.0.0 and < 2.0.0 and >= 2.0.0" is unsatisfiable because ) <>
          ~s(">= 1.0.0 and < 2.0.0" and ">= 2.0.0" are disjoint)

      assert_raise UnsatisfiableRequirementError, message, fn ->
        Requirement.to_constraint!(">= 1.0.0 and < 2.0.0 and >= 2.0.0")
      end
    end

    property "matches Version.match?/2" do
      check all terms <- list_of(requirement_term(), min_length: 1, max_length: 4) do
        requirement = Enum.join(terms, " and ")
        assert {:ok, parsed} = Version.parse_requirement(requirement)

        case Requirement.to_constraint(requirement) do
          {:ok, constraint} ->
            mismatches =
              Enum.reject(@versions, fn version ->
                Constraint.allows?(constraint, version) == Version.match?(version, parsed)
              end)

            assert mismatches == [], "#{requirement} differs from core on #{inspect(mismatches)}"

          :error ->
            refute Enum.any?(@versions, &Version.match?(&1, parsed)),
                   "#{requirement} rejected but matches versions"
        end
      end
    end

    test "minimum version range" do
      assert Requirement.to_constraint!(">= 0.0.0-0") == %Range{}
      assert Requirement.to_constraint!("< 0.0.0-0") == %Empty{}

      assert Requirement.to_constraint!(">= 0.0.0-0 and < 1.0.0") == %Range{
               max: v("1.0.0")
             }

      assert Requirement.to_constraint!("< 0.0.0-0 or >= 1.0.0") == %Range{
               min: v("1.0.0"),
               include_min: true
             }
    end
  end

  defp requirement_term() do
    gen all operator <- StreamData.member_of(@operators),
            version <- StreamData.member_of(@versions),
            short? <- StreamData.boolean() do
      version =
        if operator == "~>" and short? do
          "#{version.major}.#{version.minor}"
        else
          to_string(version)
        end

      "#{operator} #{version}"
    end
  end
end
