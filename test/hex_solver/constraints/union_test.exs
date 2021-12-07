defmodule HexSolver.Constraints.UnionTest do
  use HexSolver.Case, async: true
  use ExUnitProperties

  alias HexSolver.{Constraint, Util}
  alias HexSolver.Constraints.Union

  property "allows?/2" do
    check all union <- union(),
              version <- version() do
      assert Enum.any?(union.ranges, &Constraint.allows_any?(&1, version)) ==
               Union.allows?(union, version)
    end
  end

  property "allows_any?/2" do
    check all union <- union(),
              constraint <- constraint() do
      assert Enum.any?(union.ranges, &Constraint.allows_any?(&1, constraint)) ==
               Union.allows_any?(union, constraint)
    end
  end

  property "allows_all?/2" do
    check all union <- union(),
              constraint <- constraint() do
      if Enum.all?(union.ranges, &Constraint.allows_all?(&1, constraint)) do
        assert Union.allows_all?(union, constraint)
      end
    end
  end

  describe "difference/2" do
    property "with contained versions" do
      check all versions <- uniq_list_of(version(), min_length: 2, max_length: 10) do
        versions = Enum.sort(versions, Util.compare(HexSolver.Constraint))
        version = Enum.random(versions)
        difference = Constraint.difference(%Union{ranges: versions}, version)

        if length(versions) == 2 do
          assert %Version{} = difference
          assert versions -- [version] == [difference]
        else
          refute version in difference.ranges
          assert length(difference.ranges) == length(versions) - 1
        end
      end
    end

    property "with not contained versions" do
      check all versions <- uniq_list_of(version(), min_length: 2, max_length: 10),
                version <- version(),
                version not in versions do
        versions = Enum.sort(versions, Util.compare(HexSolver.Constraint))
        union = %Union{ranges: versions}
        assert Constraint.difference(union, version) == union
      end
    end
  end

  property "to_string/1" do
    check all union <- union() do
      assert is_binary(Union.to_string(union))
    end
  end

  property "Kernel.inspect/1" do
    check all union <- union() do
      assert is_binary(inspect(union))
    end
  end
end
