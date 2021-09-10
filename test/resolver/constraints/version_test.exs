defmodule Resolver.Constraints.VersionTest do
  use Resolver.Case, async: true
  use ExUnitProperties

  alias Resolver.Constraint
  alias Resolver.Constraints.{Empty, Range, Union, Version}

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
      assert Version.allows?(version1, version2) == (version1 == version2)
    end
  end

  property "allows_any?/2" do
    check all version <- version(),
              constraint <- constraint() do
      Version.allows_any?(version, constraint) == Constraint.allows?(constraint, version)
    end
  end

  describe "allows_all?/2" do
    property "with empty" do
      check all version <- version() do
        assert Version.allows_all?(version, %Empty{})
      end
    end

    property "with version" do
      check all version1 <- version(),
                version2 <- version() do
        assert Version.allows_all?(version1, version2) == (version1 == version2)
      end
    end

    property "with range" do
      check all version <- version() do
        range = %Range{min: version, max: version, include_min: true, include_max: true}
        assert Version.allows_all?(version, range)
      end

      check all version <- version(),
                range <- range(),
                Version.to_range(version) != range do
        refute Version.allows_all?(version, range)
      end
    end

    property "with union" do
      check all version <- version(),
                union <- union() do
        assert Version.allows_all?(version, union) ==
                 Enum.all?(union.ranges, &Version.allows_all?(version, &1))
      end
    end
  end

  property "compare/2" do
    check all version1 <- version(),
              version2 <- version() do
      assert Version.compare(version1, version2) == Elixir.Version.compare(version1, version2)
    end
  end

  property "difference/2 intersect/2 opposites" do
    check all version <- version(),
              constraint <- constraint() do
      assert Version.difference(version, constraint) in [%Empty{}, version]
      assert Version.intersect(version, constraint) in [%Empty{}, version]
      assert Version.difference(version, constraint) != Version.intersect(version, constraint)
    end
  end

  test "difference/2" do
    assert Version.difference(v("1.0.0"), v("2.0.0")) == v("1.0.0")
    assert Version.difference(v("1.0.0"), %Empty{}) == v("1.0.0")
    assert Version.difference(v("2.0.0"), %Range{min: v("1.0.0"), max: v("3.0.0")}) == %Empty{}
    assert Version.difference(v("4.0.0"), %Range{min: v("1.0.0"), max: v("3.0.0")}) == v("4.0.0")
    assert Version.difference(v("1.0.0"), %Union{ranges: [v("1.0.0"), v("2.0.0")]}) == %Empty{}
    assert Version.difference(v("3.0.0"), %Union{ranges: [v("1.0.0"), v("2.0.0")]}) == v("3.0.0")
  end

  test "intersect/2" do
    assert Version.intersect(v("1.0.0"), v("2.0.0")) == %Empty{}
    assert Version.intersect(v("1.0.0"), %Empty{}) == %Empty{}
    assert Version.intersect(v("2.0.0"), %Range{min: v("1.0.0"), max: v("3.0.0")}) == v("2.0.0")
    assert Version.intersect(v("4.0.0"), %Range{min: v("1.0.0"), max: v("3.0.0")}) == %Empty{}
    assert Version.intersect(v("1.0.0"), %Union{ranges: [v("1.0.0"), v("2.0.0")]}) == v("1.0.0")
    assert Version.intersect(v("3.0.0"), %Union{ranges: [v("1.0.0"), v("2.0.0")]}) == %Empty{}
  end

  describe "union/2" do
    test "samples" do
      assert Version.union(v("1.0.0"), %Empty{}) == v("1.0.0")
      assert Version.union(v("1.0.0"), v("1.0.0")) == v("1.0.0")
      assert Version.union(v("1.0.0"), v("2.0.0")) == %Union{ranges: [v("1.0.0"), v("2.0.0")]}

      assert Version.union(v("2.0.0"), %Range{min: v("1.0.0"), max: v("3.0.0")}) ==
               %Range{min: v("1.0.0"), max: v("3.0.0")}

      assert Version.union(v("3.0.0"), %Range{min: v("1.0.0"), max: v("2.0.0")}) ==
               %Union{ranges: [%Range{min: v("1.0.0"), max: v("2.0.0")}, v("3.0.0")]}

      assert Version.union(v("1.0.0"), %Range{min: v("2.0.0"), max: v("3.0.0")}) ==
               %Union{ranges: [v("1.0.0"), %Range{min: v("2.0.0"), max: v("3.0.0")}]}

      assert Version.union(v("1.0.0"), %Union{ranges: [v("2.0.0"), v("3.0.0")]}) ==
               %Union{ranges: [v("1.0.0"), v("2.0.0"), v("3.0.0")]}

      assert Version.union(v("2.0.0"), %Union{ranges: [v("1.0.0"), v("3.0.0")]}) ==
               %Union{ranges: [v("1.0.0"), v("2.0.0"), v("3.0.0")]}

      assert Version.union(v("3.0.0"), %Union{ranges: [v("1.0.0"), v("2.0.0")]}) ==
               %Union{ranges: [v("1.0.0"), v("2.0.0"), v("3.0.0")]}

      assert Version.union(
               v("2.0.0"),
               %Union{ranges: [%Range{min: v("1.0.0"), max: v("3.0.0")}, v("4.0.0")]}
             ) ==
               %Union{ranges: [%Range{min: v("1.0.0"), max: v("3.0.0")}, v("4.0.0")]}

      assert Version.union(
               v("4.0.0"),
               %Union{ranges: [%Range{min: v("1.0.0"), max: v("3.0.0")}, v("4.0.0")]}
             ) ==
               %Union{ranges: [%Range{min: v("1.0.0"), max: v("3.0.0")}, v("4.0.0")]}

      assert Version.union(
               v("5.0.0"),
               %Union{ranges: [%Range{min: v("1.0.0"), max: v("3.0.0")}, v("4.0.0")]}
             ) ==
               %Union{ranges: [%Range{min: v("1.0.0"), max: v("3.0.0")}, v("4.0.0"), v("5.0.0")]}
    end

    property "with empty" do
      check all version <- version() do
        assert Version.union(version, %Empty{}) == version
      end
    end

    property "with same version" do
      check all version <- version() do
        assert Version.union(version, version) == version
      end
    end

    property "with different version" do
      check all version1 <- version(),
                version2 <- version(),
                version1 != version2 do
        ranges = Enum.sort([version1, version2], Version)
        assert Version.union(version1, version2) == %Union{ranges: ranges}
      end
    end

    property "with other types" do
      check all version <- version(),
                constraint <- constraint(),
                version != constraint,
                constraint != %Empty{} do
        assert Version.union(version, constraint).__struct__ in [Range, Union]
      end
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

  property "to_range/1 gives single version range" do
    check all version <- version() do
      assert Range.single_version?(Version.to_range(version))
    end
  end
end
