defmodule Resolver.Constraints.RangeTest do
  use Resolver.Case, async: true
  use ExUnitProperties

  alias Resolver.Constraints.{Range, Version}

  describe "valid?/1" do
    test "samples" do
      assert Range.valid?(%Range{min: v(1, 0, 0, []), max: v(2, 0, 0, [])})

      assert Range.valid?(%Range{
               min: v(1, 0, 0, []),
               max: v(1, 0, 0, []),
               include_min: true,
               include_max: true
             })

      refute Range.valid?(%Range{min: v(2, 0, 0, []), max: v(1, 0, 0, [])})
      refute Range.valid?(%Range{min: v(1, 0, 0, []), max: v(1, 0, 0, [])})
    end

    test "samples with nil" do
      assert Range.valid?(%Range{min: nil, max: v(2, 0, 0, [])})
      assert Range.valid?(%Range{min: v(1, 0, 0, []), max: nil})
    end

    property "with different versions" do
      check all(
              version1 <- versions(),
              version2 <- versions(),
              Version.compare(version1, version2) != :eq
            ) do
        [min, max] = Enum.sort([version1, version2], Version)

        assert Range.valid?(%Range{min: min, max: max})
        refute Range.valid?(%Range{min: max, max: min})
      end
    end

    property "with same version" do
      check all(version <- versions()) do
        assert Range.valid?(%Range{
                 min: version,
                 max: version,
                 include_min: true,
                 include_max: true
               })

        refute Range.valid?(%Range{min: version, max: version})
      end
    end
  end

  describe "overlapping?/2" do
    test "samples" do
      assert Range.overlapping?(
               %Range{min: v(1, 0, 0, []), max: v(3, 0, 0, [])},
               %Range{min: v(2, 0, 0, []), max: v(4, 0, 0, [])}
             )

      assert Range.overlapping?(
               %Range{min: v(1, 0, 0, []), max: v(2, 0, 0, []), include_max: true},
               %Range{min: v(2, 0, 0, []), max: v(3, 0, 0, [])}
             )

      assert Range.overlapping?(
               %Range{min: v(1, 0, 0, []), max: v(2, 0, 0, [])},
               %Range{min: v(2, 0, 0, []), max: v(3, 0, 0, []), include_min: true}
             )

      refute Range.overlapping?(
               %Range{min: v(1, 0, 0, []), max: v(2, 0, 0, [])},
               %Range{min: v(2, 0, 0, []), max: v(3, 0, 0, [])}
             )
    end

    test "samples with nil" do
      assert Range.overlapping?(
               %Range{min: nil, max: nil},
               %Range{min: v(2, 0, 0, []), max: v(4, 0, 0, [])}
             )

      assert Range.overlapping?(
               %Range{min: nil, max: v(3, 0, 0, [])},
               %Range{min: v(2, 0, 0, []), max: v(4, 0, 0, [])}
             )

      assert Range.overlapping?(
               %Range{min: v(1, 0, 0, []), max: nil},
               %Range{min: v(2, 0, 0, []), max: v(4, 0, 0, [])}
             )

      assert Range.overlapping?(
               %Range{min: v(2, 0, 0, []), max: v(4, 0, 0, [])},
               %Range{min: nil, max: nil}
             )

      assert Range.overlapping?(
               %Range{min: v(2, 0, 0, []), max: v(4, 0, 0, [])},
               %Range{min: nil, max: v(3, 0, 0, [])}
             )

      assert Range.overlapping?(
               %Range{min: v(2, 0, 0, []), max: v(4, 0, 0, [])},
               %Range{min: v(1, 0, 0, []), max: nil}
             )
    end

    property "with different versions" do
      check all(
              version1 <- versions(),
              version2 <- versions(),
              Version.compare(version1, version2) != :eq,
              version3 <- versions(),
              Version.compare(version1, version3) != :eq,
              Version.compare(version2, version3) != :eq,
              version4 <- versions(),
              Version.compare(version1, version4) != :eq,
              Version.compare(version2, version4) != :eq,
              Version.compare(version3, version4) != :eq
            ) do
        [version1, version2, version3, version4] =
          Enum.sort([version1, version2, version3, version4], Version)

        assert Range.overlapping?(
                 %Range{min: version1, max: version3},
                 %Range{min: version2, max: version4}
               )

        assert Range.overlapping?(
                 %Range{min: version2, max: version4},
                 %Range{min: version1, max: version3}
               )

        refute Range.overlapping?(
                 %Range{min: version1, max: version2},
                 %Range{min: version3, max: version4}
               )
      end
    end

    property "with same versions" do
      check all(
              version1 <- versions(),
              version2 <- versions(),
              Version.compare(version1, version2) != :eq,
              version3 <- versions(),
              Version.compare(version1, version3) != :eq,
              Version.compare(version2, version3) != :eq
            ) do
        [version1, version2, version3] = Enum.sort([version1, version2, version3], Version)

        assert Range.overlapping?(
                 %Range{min: version1, max: version2, include_max: true},
                 %Range{min: version2, max: version3}
               )

        assert Range.overlapping?(
                 %Range{min: version1, max: version2},
                 %Range{min: version2, max: version3, include_min: true}
               )

        refute Range.overlapping?(
                 %Range{min: version1, max: version2},
                 %Range{min: version2, max: version3}
               )
      end
    end

    property "with nil" do
      check all(
              version1 <- versions(),
              version2 <- versions(),
              Version.compare(version1, version2) != :eq,
              version3 <- versions(),
              Version.compare(version1, version3) != :eq,
              Version.compare(version2, version3) != :eq
            ) do
        [version1, version2, version3] = Enum.sort([version1, version2, version3], Version)

        assert Range.overlapping?(
                 %Range{min: nil, max: version2},
                 %Range{min: version1, max: version3}
               )

        assert Range.overlapping?(
                 %Range{min: version2, max: nil},
                 %Range{min: version1, max: version3}
               )

        assert Range.overlapping?(
                 %Range{min: nil, max: nil},
                 %Range{min: version1, max: version2}
               )
      end
    end
  end

  describe "allows_all?/2" do
    property "with different versions" do
      check all(
              version1 <- versions(),
              version2 <- versions(),
              Version.compare(version1, version2) != :eq,
              version3 <- versions(),
              Version.compare(version1, version3) != :eq,
              Version.compare(version2, version3) != :eq,
              version4 <- versions(),
              Version.compare(version1, version4) != :eq,
              Version.compare(version2, version4) != :eq,
              Version.compare(version3, version4) != :eq
            ) do
        [version1, version2, version3, version4] =
          Enum.sort([version1, version2, version3, version4], Version)

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
  end

  describe "allows_higher?/2" do
    property "with different versions" do
      check all(
              version1 <- versions(),
              version2 <- versions(),
              Version.compare(version1, version2) != :eq,
              version3 <- versions(),
              Version.compare(version1, version3) != :eq,
              Version.compare(version2, version3) != :eq,
              version4 <- versions(),
              Version.compare(version1, version4) != :eq,
              Version.compare(version2, version4) != :eq,
              Version.compare(version3, version4) != :eq
            ) do
        [version1, version2, version3, version4] =
          Enum.sort([version1, version2, version3, version4], Version)

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
  end

  describe "allows_lower?/2" do
    property "with different versions" do
      check all(
              version1 <- versions(),
              version2 <- versions(),
              Version.compare(version1, version2) != :eq,
              version3 <- versions(),
              Version.compare(version1, version3) != :eq,
              Version.compare(version2, version3) != :eq,
              version4 <- versions(),
              Version.compare(version1, version4) != :eq,
              Version.compare(version2, version4) != :eq,
              Version.compare(version3, version4) != :eq
            ) do
        [version1, version2, version3, version4] =
          Enum.sort([version1, version2, version3, version4], Version)

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
  end
end
