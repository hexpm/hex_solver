defmodule Resolver.Constraints.VersionTest do
  use Resolver.Case, async: true
  use ExUnitProperties

  alias Resolver.Constraint
  alias Resolver.Constraints.Version

  property "any?/1" do
    check all version <- version() do
      refute Version.any?(version)
    end
  end

  property "empty?/1" do
    check all version <- version() do
      refute Version.empty?(version)
    end
  end

  property "allows?/2" do
    check all version1 <- version(),
              version2 <- version() do
      assert Version.allows?(version1, version2) == (Version.compare(version1, version2) == :eq)
    end
  end

  property "allows_any?/2" do
    check all version <- version(),
              constraint <- constraint() do
      Version.allows_any?(version, constraint) == Constraint.allows?(constraint, version)
    end
  end

  property "allows_all?/2" do
    check all version <- version(),
              constraint <- constraint() do
      Version.allows_all?(version, constraint)
    end
  end

  property "min/2" do
    check all version1 <- version(),
              version2 <- version() do
      [version1, version2] = Enum.sort([version1, version2], Version)
      assert Version.min(version1, version2) == version1
    end
  end

  property "max/2" do
    check all version1 <- version(),
              version2 <- version() do
      [version1, version2] = Enum.sort([version1, version2], Version)
      assert Version.max(version1, version2) == version2
    end
  end
end
