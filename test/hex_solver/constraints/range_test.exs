defmodule HexSolver.Constraints.RangeTest do
  use HexSolver.Case, async: true
  use ExUnitProperties

  alias HexSolver.Constraints.{Empty, Range, Union, Util, Version}

  describe "valid?/1" do
    test "samples" do
      assert Range.valid?(%Range{min: v("1.0.0"), max: v("2.0.0")})

      assert Range.valid?(%Range{
               min: v("1.0.0"),
               max: v("1.0.0"),
               include_min: true,
               include_max: true
             })

      refute Range.valid?(%Range{min: v("2.0.0"), max: v("1.0.0")})
      refute Range.valid?(%Range{min: v("1.0.0"), max: v("1.0.0")})
    end

    test "samples with nil" do
      assert Range.valid?(%Range{min: nil, max: v("2.0.0")})
      assert Range.valid?(%Range{min: v("1.0.0"), max: nil})
    end

    property "with different versions" do
      check all version1 <- version(),
                version2 <- version(),
                version1 != version2 do
        [min, max] = Enum.sort([version1, version2], Version)

        assert Range.valid?(%Range{min: min, max: max})
        refute Range.valid?(%Range{min: max, max: min})

        assert Range.valid?(%Range{
                 min: version1,
                 max: version1,
                 include_min: true,
                 include_max: true
               })

        refute Range.valid?(%Range{min: version1, max: version1})
      end
    end
  end

  describe "allows?/2" do
    property "with versions" do
      check all versions <- uniq_list_of(version(), length: 3) do
        [version1, version2, version3] = Enum.sort(versions, Version)

        assert Range.allows?(%Range{min: version1, max: version3}, version2)
        refute Range.allows?(%Range{min: version1, max: version2}, version3)
        refute Range.allows?(%Range{min: version2, max: version3}, version1)

        assert Range.allows?(
                 %Range{min: version1, max: version1, include_min: true, include_max: true},
                 version1
               )

        assert Range.allows?(%Range{min: version1, max: version2, include_min: true}, version1)
        assert Range.allows?(%Range{min: version1, max: version2, include_max: true}, version2)

        refute Range.allows?(
                 %Range{min: version1, max: version1, include_min: true, include_max: true},
                 version2
               )

        refute Range.allows?(%Range{min: version2, max: version3, include_min: true}, version1)
        refute Range.allows?(%Range{min: version1, max: version2, include_max: true}, version3)
      end
    end
  end

  describe "allows_all?/2" do
    property "with empty" do
      check all range <- range() do
        assert Range.allows_all?(range, %Empty{})
      end
    end

    property "with version" do
      check all range <- range(),
                version <- version() do
        assert Range.allows_all?(range, version) == Range.allows?(range, version)
      end
    end

    property "with range" do
      check all versions <- uniq_list_of(version(), length: 4) do
        [version1, version2, version3, version4] = Enum.sort(versions, Version)

        assert Range.allows_all?(
                 %Range{min: version1, max: version4},
                 %Range{min: version2, max: version3}
               )

        refute Range.allows_all?(
                 %Range{min: version2, max: version3},
                 %Range{min: version1, max: version4}
               )

        refute Range.allows_all?(
                 %Range{min: version1, max: version3},
                 %Range{min: version2, max: version4}
               )

        refute Range.allows_all?(
                 %Range{min: version2, max: version4},
                 %Range{min: version1, max: version3}
               )
      end
    end

    property "with union" do
      check all versions <- uniq_list_of(version(), length: 5) do
        [version1, version2, version3, version4, version5] = Enum.sort(versions, Version)

        assert Range.allows_all?(
                 %Range{min: version1, max: version5},
                 %Union{ranges: [%Range{min: version2, max: version3}, version4]}
               )

        assert Range.allows_all?(
                 %Range{min: version1, max: version5},
                 %Union{ranges: [version2, %Range{min: version3, max: version4}]}
               )

        assert Range.allows_all?(
                 %Range{min: version1, max: version4},
                 %Union{ranges: [version2, version3]}
               )

        refute Range.allows_all?(
                 %Range{min: version2, max: version5},
                 %Union{ranges: [%Range{min: version1, max: version3}, version4]}
               )

        refute Range.allows_all?(
                 %Range{min: version1, max: version4},
                 %Union{ranges: [version2, %Range{min: version3, max: version5}]}
               )

        refute Range.allows_all?(
                 %Range{min: version2, max: version4},
                 %Union{ranges: [version3, version5]}
               )
      end
    end
  end

  describe "allows_any?/2" do
    property "with empty" do
      check all range <- range() do
        assert Range.allows_any?(range, %Empty{})
      end
    end

    property "with version" do
      check all range <- range(),
                version <- version() do
        assert Range.allows_any?(range, version) == Range.allows?(range, version)
      end
    end

    property "with range" do
      check all versions <- uniq_list_of(version(), length: 4) do
        [version1, version2, version3, version4] = Enum.sort(versions, Version)

        assert Range.allows_any?(
                 %Range{min: version1, max: version4},
                 %Range{min: version2, max: version3}
               )

        assert Range.allows_any?(
                 %Range{min: version2, max: version3},
                 %Range{min: version1, max: version4}
               )

        assert Range.allows_any?(
                 %Range{min: version1, max: version3},
                 %Range{min: version2, max: version4}
               )

        assert Range.allows_any?(
                 %Range{min: version2, max: version4},
                 %Range{min: version1, max: version3}
               )

        refute Range.allows_any?(
                 %Range{min: version1, max: version2},
                 %Range{min: version3, max: version4}
               )

        refute Range.allows_any?(
                 %Range{min: version3, max: version4},
                 %Range{min: version1, max: version2}
               )
      end
    end

    property "with union" do
      check all versions <- uniq_list_of(version(), length: 5) do
        [version1, version2, version3, version4, version5] = Enum.sort(versions, Version)

        assert Range.allows_any?(
                 %Range{min: version1, max: version5},
                 %Union{ranges: [%Range{min: version2, max: version3}, version4]}
               )

        assert Range.allows_any?(
                 %Range{min: version1, max: version5},
                 %Union{ranges: [version2, %Range{min: version3, max: version4}]}
               )

        assert Range.allows_any?(
                 %Range{min: version1, max: version4},
                 %Union{ranges: [version2, version3]}
               )

        assert Range.allows_any?(
                 %Range{min: version2, max: version5},
                 %Union{ranges: [%Range{min: version1, max: version3}, version4]}
               )

        assert Range.allows_any?(
                 %Range{min: version1, max: version4},
                 %Union{ranges: [version2, %Range{min: version3, max: version5}]}
               )

        assert Range.allows_any?(
                 %Range{min: version2, max: version4},
                 %Union{ranges: [version3, version5]}
               )

        refute Range.allows_any?(
                 %Range{min: version2, max: version4},
                 %Union{ranges: [version1, version5]}
               )

        refute Range.allows_any?(
                 %Range{min: version4, max: version5},
                 %Union{ranges: [%Range{min: version1, max: version2}, version3]}
               )

        refute Range.allows_any?(
                 %Range{min: version4, max: version5},
                 %Union{ranges: [version1, %Range{min: version2, max: version3}]}
               )
      end
    end
  end

  property "allows_higher?/2" do
    check all versions <- uniq_list_of(version(), length: 4) do
      [version1, version2, version3, version4] = Enum.sort(versions, Version)

      assert Range.allows_higher?(
               %Range{min: version3, max: version4},
               %Range{min: version1, max: version2}
             )

      assert Range.allows_higher?(
               %Range{min: version3, max: nil},
               %Range{min: version1, max: version4}
             )

      refute Range.allows_higher?(
               %Range{min: version1, max: version2},
               %Range{min: version3, max: version4}
             )

      refute Range.allows_higher?(
               %Range{min: version3, max: version4},
               %Range{min: version1, max: nil}
             )
    end
  end

  property "allows_lower?/2" do
    check all versions <- uniq_list_of(version(), length: 4) do
      [version1, version2, version3, version4] = Enum.sort(versions, Version)

      assert Range.allows_lower?(
               %Range{min: version1, max: version2},
               %Range{min: version3, max: version4}
             )

      assert Range.allows_lower?(
               %Range{min: nil, max: version2},
               %Range{min: version1, max: version4}
             )

      refute Range.allows_lower?(
               %Range{min: version3, max: version4},
               %Range{min: version1, max: version2}
             )

      refute Range.allows_lower?(
               %Range{min: version1, max: version4},
               %Range{min: nil, max: version2}
             )
    end
  end

  property "strictly_higher?/2" do
    check all range1 <- range(),
              range2 <- range() do
      assert Range.strictly_higher?(range1, range2) == Range.strictly_lower?(range2, range1)
    end
  end

  property "strictly_lower?/2" do
    check all versions <- uniq_list_of(version(), length: 4) do
      [version1, version2, version3, version4] = Enum.sort(versions, Version)

      assert Range.strictly_lower?(
               %Range{min: version1, max: version2},
               %Range{min: version3, max: version4}
             )

      assert Range.strictly_lower?(
               %Range{min: nil, max: version1},
               %Range{min: version2, max: version4}
             )

      assert Range.strictly_lower?(
               %Range{min: nil, max: version1},
               %Range{min: version2, max: nil}
             )

      refute Range.strictly_lower?(
               %Range{min: version1, max: nil},
               %Range{min: version2, max: version3}
             )

      refute Range.strictly_lower?(
               %Range{min: nil, max: version2},
               %Range{min: version1, max: version4}
             )

      refute Range.strictly_lower?(
               %Range{min: version3, max: version4},
               %Range{min: version1, max: version2}
             )

      refute Range.strictly_lower?(
               %Range{min: version1, max: version4},
               %Range{min: nil, max: version2}
             )
    end
  end

  describe "difference/2" do
    property "empty" do
      check all range <- range() do
        assert Range.difference(range, %Empty{}) == range
      end
    end

    property "with version" do
      check all versions <- uniq_list_of(version(), length: 3) do
        [version1, version2, version3] = Enum.sort(versions, Version)

        assert Range.difference(%Range{min: version1, max: version2}, version3) ==
                 %Range{min: version1, max: version2}

        assert Range.difference(%Range{min: version1, max: version2, include_max: true}, version2) ==
                 %Range{min: version1, max: version2}

        assert Range.difference(%Range{min: version1, max: version2, include_min: true}, version1) ==
                 %Range{min: version1, max: version2}

        assert Range.difference(%Range{min: version2, max: version3}, version1) ==
                 %Range{min: version2, max: version3}

        assert Range.difference(
                 %Range{min: version1, max: version3, include_min: true, include_max: true},
                 version2
               ) ==
                 %Union{
                   ranges: [
                     %Range{min: version1, max: version2, include_min: true},
                     %Range{min: version2, max: version3, include_max: true}
                   ]
                 }
      end
    end

    property "with range" do
      check all versions <- uniq_list_of(version(), length: 4) do
        [version1, version2, version3, version4] = Enum.sort(versions, Version)

        assert Range.difference(
                 %Range{min: version1, max: version2},
                 %Range{min: version1, max: version2}
               ) == %Empty{}

        assert Range.difference(
                 %Range{min: version2, max: version3},
                 %Range{min: version1, max: version4}
               ) == %Empty{}

        assert Range.difference(
                 %Range{min: version1, max: version3},
                 %Range{min: version2, max: version4}
               ) ==
                 %Range{min: version1, max: version2, include_max: true}

        assert Range.difference(
                 %Range{min: version2, max: version4},
                 %Range{min: version1, max: version3}
               ) ==
                 %Range{min: version3, max: version4, include_min: true}

        assert Range.difference(
                 %Range{min: version1, max: version2},
                 %Range{min: version3, max: version4}
               ) ==
                 %Range{min: version1, max: version2}

        assert Range.difference(
                 %Range{min: version1, max: version4},
                 %Range{min: version2, max: version3}
               ) ==
                 %Union{
                   ranges: [
                     %Range{min: version1, max: version2, include_max: true},
                     %Range{min: version3, max: version4, include_min: true}
                   ]
                 }

        assert Range.difference(
                 %Range{min: version1, max: version4},
                 %Range{min: version2, max: version3, include_min: true, include_max: true}
               ) ==
                 %Union{
                   ranges: [
                     %Range{min: version1, max: version2},
                     %Range{min: version3, max: version4}
                   ]
                 }

        assert Range.difference(
                 %Range{min: version1, max: version2, include_min: true, include_max: true},
                 %Range{min: version1, max: version2}
               ) == %Union{ranges: [version1, version2]}
      end
    end

    property "with union" do
      check all versions <- uniq_list_of(version(), length: 4) do
        [version1, version2, version3, version4] = Enum.sort(versions, Version)

        assert Range.difference(
                 %Range{min: version1, max: version2},
                 %Union{ranges: [version3, version4]}
               ) == %Range{min: version1, max: version2}

        assert Range.difference(
                 %Range{min: version1, max: version2},
                 %Union{ranges: [%Range{min: version1, max: version2}, version3]}
               ) == %Empty{}

        assert Range.difference(
                 %Range{min: version2, max: version3},
                 %Union{ranges: [version1, %Range{min: version2, max: version3}]}
               ) == %Empty{}

        assert Range.difference(
                 %Range{min: version1, max: version4},
                 %Union{ranges: [version2, version3]}
               ) == %Union{
                 ranges: [
                   %Range{min: version1, max: version2},
                   %Range{min: version2, max: version3},
                   %Range{min: version3, max: version4}
                 ]
               }
      end
    end
  end

  describe "intersect/2" do
    property "empty" do
      check all range <- range() do
        assert Range.intersect(range, %Empty{}) == %Empty{}
      end
    end

    property "version" do
      check all versions <- uniq_list_of(version(), length: 3) do
        [version1, version2, version3] = Enum.sort(versions, Version)

        assert Range.intersect(%Range{min: version1, max: version3}, version2) == version2
        assert Range.intersect(%Range{min: version1, max: version2}, version3) == %Empty{}
        assert Range.intersect(%Range{min: version2, max: version3}, version1) == %Empty{}
        assert Range.intersect(%Range{min: version1, max: version2}, version2) == %Empty{}
        assert Range.intersect(%Range{min: version1, max: version2}, version2) == %Empty{}
        assert Range.intersect(%Range{min: version1, max: version2}, version1) == %Empty{}

        assert Range.intersect(%Range{min: version1, max: version2, include_max: true}, version2) ==
                 version2

        assert Range.intersect(%Range{min: version1, max: version2, include_min: true}, version1) ==
                 version1
      end
    end

    property "range" do
      check all versions <- uniq_list_of(version(), length: 4) do
        [version1, version2, version3, version4] = Enum.sort(versions, Version)

        assert Range.intersect(
                 %Range{min: version1, max: version2},
                 %Range{min: version3, max: version4}
               ) == %Empty{}

        assert Range.intersect(
                 %Range{min: version3, max: version4},
                 %Range{min: version1, max: version2}
               ) == %Empty{}

        assert Range.intersect(
                 %Range{min: version1, max: version2},
                 %Range{min: version2, max: version3}
               ) == %Empty{}

        assert Range.intersect(
                 %Range{min: version1, max: version2, include_max: true},
                 %Range{min: version2, max: version3}
               ) == %Empty{}

        assert Range.intersect(
                 %Range{min: version1, max: version2},
                 %Range{min: version2, max: version3, include_min: true}
               ) == %Empty{}

        assert Range.intersect(
                 %Range{min: version1, max: version2, include_max: true},
                 %Range{min: version2, max: version3, include_min: true}
               ) == version2

        assert Range.intersect(
                 %Range{min: version1, max: version3},
                 %Range{min: version2, max: version4}
               ) == %Range{min: version2, max: version3}

        assert Range.intersect(
                 %Range{min: version1, max: version3, include_max: true},
                 %Range{min: version2, max: version4, include_min: true}
               ) == %Range{min: version2, max: version3, include_min: true, include_max: true}

        assert Range.intersect(%Range{}, %Range{}) == %Range{}
      end
    end

    property "mirrors version" do
      check all range <- range(),
                version <- version() do
        assert Range.intersect(range, version) == Version.intersect(version, range)
      end
    end

    property "mirrors union" do
      check all range <- range(),
                union <- union() do
        assert Range.intersect(range, union) == Union.intersect(union, range)
      end
    end
  end

  describe "union/2" do
    property "empty" do
      check all range <- range() do
        assert Range.union(range, %Empty{}) == range
      end
    end

    property "version" do
      check all versions <- uniq_list_of(version(), length: 3) do
        [version1, version2, version3] = Enum.sort(versions, Version)

        assert Range.union(%Range{min: version1, max: version3}, version2) ==
                 %Range{min: version1, max: version3}

        assert Range.union(%Range{min: version1, max: version2}, version2) ==
                 %Range{min: version1, max: version2, include_max: true}

        assert Range.union(%Range{min: version1, max: version2}, version1) ==
                 %Range{min: version1, max: version2, include_min: true}
      end
    end

    property "range" do
      check all versions <- uniq_list_of(version(), length: 4) do
        [version1, version2, version3, version4] = Enum.sort(versions, Version)

        assert Range.union(
                 %Range{min: version1, max: version2},
                 %Range{min: version3, max: version4}
               ) ==
                 %Union{
                   ranges: [
                     %Range{min: version1, max: version2},
                     %Range{min: version3, max: version4}
                   ]
                 }

        assert Range.union(
                 %Range{min: version3, max: version4},
                 %Range{min: version1, max: version2}
               ) ==
                 %Union{
                   ranges: [
                     %Range{min: version1, max: version2},
                     %Range{min: version3, max: version4}
                   ]
                 }
      end
    end

    property "union" do
      check all range <- range(),
                union <- union() do
        assert Range.union(range, union) == Util.union([range, union])
      end
    end
  end

  describe "compare/2" do
    property "version" do
      check all versions <- uniq_list_of(version(), length: 3) do
        [version1, version2, version3] = Enum.sort(versions, Version)

        assert Range.compare(%Range{min: version1, max: version2}, version3) == :lt
        assert Range.compare(%Range{min: version1, max: version2}, version1) == :gt

        assert Range.compare(%Range{min: version1, max: version2, include_min: true}, version1) ==
                 :eq

        assert Range.compare(%Range{min: nil, max: version2}, version1) == :lt
      end
    end

    property "range" do
      check all versions <- uniq_list_of(version(), length: 4) do
        [version1, version2, version3, version4] = Enum.sort(versions, Version)

        assert Range.compare(
                 %Range{min: version1, max: version2},
                 %Range{min: version2, max: version3}
               ) == :lt

        assert Range.compare(
                 %Range{min: version2, max: version3},
                 %Range{min: version1, max: version4}
               ) == :gt

        assert Range.compare(
                 %Range{min: version1, max: version2},
                 %Range{min: version1, max: version3}
               ) == :eq

        assert Range.compare(
                 %Range{min: version1, max: version2, include_min: true},
                 %Range{min: version1, max: version3}
               ) == :lt

        assert Range.compare(
                 %Range{min: version1, max: version2},
                 %Range{min: version1, max: version3, include_min: true}
               ) == :gt
      end
    end

    property "union" do
      check all range <- range(),
                union <- union() do
        assert Range.compare(range, union) == Range.compare(range, List.first(union.ranges))
      end
    end
  end

  property "single_version?/1" do
    check all versions <- uniq_list_of(version(), length: 2) do
      [version1, version2] = Enum.sort(versions, Version)

      assert Range.single_version?(%Range{
               min: version1,
               max: version1,
               include_min: true,
               include_max: true
             })

      refute Range.single_version?(%Range{
               min: version1,
               max: version2,
               include_min: true,
               include_max: true
             })

      refute Range.single_version?(%Range{min: version1, max: version2, include_max: true})
      refute Range.single_version?(%Range{min: version1, max: version2, include_min: true})
    end
  end

  property "to_string/1" do
    check all range <- range() do
      assert is_binary(Range.to_string(range))
    end
  end

  property "Kernel.inspect/1" do
    check all range <- range() do
      assert is_binary(inspect(range))
    end
  end
end
