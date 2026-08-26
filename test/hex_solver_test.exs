defmodule HexSolverTest do
  use HexSolver.Case, async: true

  alias HexSolver.Registry.Process, as: Registry
  alias HexSolver.Constraints.{Empty, Range}

  defp run(dependencies) do
    HexSolver.run(Registry, to_dependencies(dependencies), [], [])
  end

  @version_1 Version.parse!("1.0.0")

  describe "run/4" do
    test "success" do
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.0.0", [])

      assert run([{"foo", "~> 1.0"}]) ==
               {:ok, %{"foo" => {@version_1, nil}, "bar" => {@version_1, nil}}}
    end

    test "failure" do
      Registry.put("foo", "1.0.0", [{"bar", "~> 1.0"}])
      Registry.put("bar", "2.0.0", [])

      assert run([{"foo", "~> 1.0"}]) ==
               {:error,
                """
                Because every version of "foo" depends on "bar ~> 1.0" which doesn't match any versions, no version of "foo" is allowed.
                So, because "your app" depends on "foo ~> 1.0", version solving failed.\
                """}
    end
  end

  test "parse_constraint/1" do
    assert HexSolver.parse_constraint("1.0.0") == Version.parse("1.0.0")

    assert HexSolver.parse_constraint("~> 1.0") ==
             {:ok,
              %Range{
                min: Version.parse!("1.0.0"),
                max: Version.parse!("2.0.0-0"),
                include_min: true
              }}

    assert HexSolver.parse_constraint(Version.parse!("1.0.0")) == Version.parse("1.0.0")

    assert HexSolver.parse_constraint("1.2.3.4") == :error
    assert HexSolver.parse_constraint("~> 1.0 and >= 2.0.0") == :error
  end

  test "parse_constraint!/1" do
    assert HexSolver.parse_constraint!("1.0.0") == Version.parse!("1.0.0")

    assert HexSolver.parse_constraint!("~> 1.0") == %Range{
             min: Version.parse!("1.0.0"),
             max: Version.parse!("2.0.0-0"),
             include_min: true
           }

    assert HexSolver.parse_constraint!(Version.parse!("1.0.0")) == Version.parse!("1.0.0")

    assert_raise HexSolver.UnsatisfiableRequirementError, fn ->
      HexSolver.parse_constraint!("~> 1.0 and >= 2.0.0")
    end

    assert_raise Version.InvalidRequirementError, fn ->
      HexSolver.parse_constraint!("1.2.3.4")
    end
  end

  describe "constraint_to_requirement!/1" do
    test "serializes any constraint as a valid requirement" do
      requirement = HexSolver.constraint_to_requirement!(%Range{})

      assert requirement == ">= 0.0.0-0"
      assert {:ok, _requirement} = Version.parse_requirement(requirement)
      assert HexSolver.parse_constraint!(requirement) == %Range{}
    end

    test "serializes version constraints" do
      assert HexSolver.constraint_to_requirement!(Version.parse!("1.2.3")) == "1.2.3"
    end

    test "serializes bounded range constraints" do
      constraint = HexSolver.parse_constraint!("~> 1.2")
      assert HexSolver.constraint_to_requirement!(constraint) == "~> 1.2"
    end

    test "serializes union constraints" do
      constraint = HexSolver.parse_constraint!("~> 1.0 or ~> 2.0")
      assert HexSolver.constraint_to_requirement!(constraint) == "~> 1.0 or ~> 2.0"
    end

    test "serializes empty constraint as a valid requirement" do
      requirement = HexSolver.constraint_to_requirement!(%Empty{})

      assert requirement == "< 0.0.0-0"
      assert {:ok, _requirement} = Version.parse_requirement(requirement)
      assert HexSolver.parse_constraint!(requirement) == %Empty{}
    end
  end
end
