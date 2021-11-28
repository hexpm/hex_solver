defmodule HexSolver.Constraints.UnionTest do
  use HexSolver.Case, async: true
  use ExUnitProperties

  alias HexSolver.Constraints.Union

  # property "intersect/2" do
  #   check all version1 <- version(),
  #             version2 <- version() do
  #     assert Union.intersect(
  #              %Union{ranges: [version1, version2]},
  #              %Union{ranges: [version2, version1]}
  #            ) == %Union{ranges: [version1, version2]}
  #   end
  # end

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
