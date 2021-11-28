defmodule HexSolver.Constraints.EmptyTest do
  use HexSolver.Case, async: true
  use ExUnitProperties

  alias HexSolver.Constraint
  alias HexSolver.Constraints.Empty

  test "any?/1" do
    refute Empty.any?(%Empty{})
  end

  test "empty?/1" do
    assert Empty.empty?(%Empty{})
  end

  test "to_string/1" do
    assert Empty.to_string(%Empty{}) == "empty"
  end

  test "Kernel.inspect/1" do
    assert inspect(%Empty{}) == "#Empty<>"
  end

  property "allows?/2" do
    check all version <- version() do
      refute Empty.allows?(%Empty{}, version)
    end
  end

  property "allows_any?/2" do
    check all constraint <- constraint() do
      assert Empty.allows_any?(%Empty{}, constraint) == Constraint.empty?(constraint)
    end
  end

  property "allows_all?/2" do
    check all constraint <- constraint() do
      assert Empty.allows_all?(%Empty{}, constraint) == Constraint.empty?(constraint)
    end
  end

  property "difference/2" do
    check all constraint <- constraint() do
      assert Empty.difference(%Empty{}, constraint) == %Empty{}
    end
  end

  property "intersect/2" do
    check all constraint <- constraint() do
      assert Empty.intersect(%Empty{}, constraint) == %Empty{}
    end
  end

  property "union/2" do
    check all constraint <- constraint() do
      assert Empty.union(%Empty{}, constraint) == constraint
    end
  end

  property "compare/2" do
    check all constraint <- constraint(),
              max_runs: 10 do
      assert_raise FunctionClauseError, fn ->
        Empty.compare(%Empty{}, constraint)
      end
    end
  end
end
