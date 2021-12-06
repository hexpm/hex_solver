defmodule HexSolverTest do
  use HexSolver.Case, async: true

  alias HexSolver.Registry.Process, as: Registry
  alias HexSolver.Constraints.Range

  defp run(dependencies) do
    HexSolver.run(Registry, to_dependencies(dependencies), [], [])
  end

  @version_1 Version.parse!("1.0.0")

  describe "run/4" do
    test "success" do
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.0.0", [])

      assert run([{"foo", "~> 1.0"}]) == {:ok, %{"foo" => @version_1, "bar" => @version_1}}
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
    assert HexSolver.parse_constraint("1.0.0") == {:ok, %Version{major: 1, minor: 0, patch: 0}}

    assert HexSolver.parse_constraint("~> 1.0") ==
             {:ok,
              %Range{
                min: %Version{major: 1, minor: 0, patch: 0},
                max: %Version{major: 2, minor: 0, patch: 0, pre: [0]},
                include_min: true
              }}

    assert HexSolver.parse_constraint(%Version{major: 1, minor: 0, patch: 0}) ==
             {:ok,
              %Version{
                major: 1,
                minor: 0,
                patch: 0
              }}

    assert HexSolver.parse_constraint("1.2.3.4") == :error
  end

  test "parse_constraint!/1" do
    assert HexSolver.parse_constraint!("1.0.0") == %Version{major: 1, minor: 0, patch: 0}

    assert HexSolver.parse_constraint!("~> 1.0") == %Range{
             min: %Version{major: 1, minor: 0, patch: 0},
             max: %Version{major: 2, minor: 0, patch: 0, pre: [0]},
             include_min: true
           }

    assert HexSolver.parse_constraint!(%Version{major: 1, minor: 0, patch: 0}) == %Version{
             major: 1,
             minor: 0,
             patch: 0
           }

    assert_raise Version.InvalidRequirementError, fn ->
      HexSolver.parse_constraint!("1.2.3.4")
    end
  end
end
