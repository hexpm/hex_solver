defmodule HexSolver.ConstraintTest do
  use HexSolver.Case, async: true
  use ExUnitProperties

  alias HexSolver.Constraint
  alias HexSolver.Constraints.Union

  defp always_lt([left, right | rest]) do
    assert Constraint.compare(left, right) == :lt
    always_lt([right | rest])
  end

  defp always_lt([_constraint]) do
    :ok
  end

  describe "allows_any?/2" do
    property "commutative" do
      check all left <- constraint(),
                not Constraint.empty?(left),
                right <- constraint(),
                not Constraint.empty?(right) do
        assert Constraint.allows_any?(left, right) == Constraint.allows_any?(right, left)
      end
    end
  end

  describe "compare/2" do
    property "ordered" do
      check all left <- constraint(),
                not Constraint.empty?(left),
                right <- constraint(),
                not Constraint.empty?(right) do
        if Constraint.compare(left, right) == :eq do
          assert Constraint.compare(right, left) == :eq
        else
          assert Constraint.compare(left, right) != Constraint.compare(right, left)
        end
      end
    end
  end

  describe "difference/2" do
    property "allows?/2" do
      check all left <- constraint(),
                right <- constraint(),
                version <- version() do
        difference = Constraint.difference(left, right)

        if Constraint.allows?(left, version) and not Constraint.allows?(right, version) do
          assert Constraint.allows?(difference, version)
        else
          refute Constraint.allows?(difference, version)
        end
      end
    end

    property "allows_any?/2" do
      check all left <- constraint(),
                right <- constraint(),
                constraint <- constraint(),
                not Constraint.empty?(constraint) do
        difference = Constraint.difference(left, right)

        if not Constraint.allows_any?(left, constraint) and
             Constraint.allows_any?(right, constraint) do
          refute Constraint.allows_any?(difference, constraint)
        end
      end
    end

    property "allows_all?/2" do
      check all left <- constraint(),
                right <- constraint(),
                constraint <- constraint() do
        difference = Constraint.difference(left, right)

        if not Constraint.allows_all?(left, constraint) and
             Constraint.allows_all?(right, constraint) do
          refute Constraint.allows_all?(difference, constraint)
        end
      end
    end
  end

  describe "intersect/2" do
    property "allows?/2" do
      check all left <- constraint(),
                right <- constraint(),
                version <- version() do
        intersection = Constraint.intersect(left, right)

        if Constraint.allows?(left, version) and Constraint.allows?(right, version) do
          assert Constraint.allows?(intersection, version)
        else
          refute Constraint.allows?(intersection, version)
        end
      end
    end

    property "allows_any?/2" do
      check all left <- constraint(),
                right <- constraint(),
                constraint <- constraint() do
        intersection = Constraint.intersect(left, right)

        if not Constraint.allows_any?(left, constraint) and
             not Constraint.allows_any?(right, constraint) and
             not Constraint.empty?(intersection) do
          refute Constraint.allows_any?(intersection, constraint)
        end
      end
    end

    property "allows_all?/2" do
      check all left <- constraint(),
                right <- constraint(),
                constraint <- constraint() do
        intersection = Constraint.intersect(left, right)

        if Constraint.allows_all?(left, constraint) and Constraint.allows_all?(right, constraint) do
          assert Constraint.allows_all?(intersection, constraint)
        else
          refute Constraint.allows_all?(intersection, constraint)
        end
      end
    end
  end

  describe "union/2" do
    property "orders unions" do
      check all left <- constraint(),
                right <- constraint() do
        case Constraint.union(left, right) do
          %Union{ranges: ranges} -> always_lt(ranges)
          _ -> :ok
        end
      end
    end

    property "allows?/2" do
      check all left <- constraint(),
                right <- constraint(),
                version <- version() do
        union = Constraint.union(left, right)

        if Constraint.allows?(left, version) or Constraint.allows?(right, version) do
          assert Constraint.allows?(union, version)
        else
          refute Constraint.allows?(union, version)
        end
      end
    end

    property "allows_any?/2" do
      check all left <- constraint(),
                right <- constraint(),
                constraint <- constraint(),
                not Constraint.empty?(constraint) do
        union = Constraint.union(left, right)

        if Constraint.allows_any?(left, constraint) or Constraint.allows_any?(right, constraint) do
          assert Constraint.allows_any?(union, constraint)
        else
          refute Constraint.allows_any?(union, constraint)
        end
      end
    end

    property "allows_all?/2" do
      check all left <- constraint(),
                right <- constraint(),
                constraint <- constraint() do
        union = Constraint.union(left, right)

        if Constraint.allows_all?(left, constraint) or Constraint.allows_all?(right, constraint) do
          assert Constraint.allows_all?(union, constraint)
        end
      end
    end
  end
end
