defmodule Resolver.Constraints.Union do
  alias Resolver.Constraint
  alias Resolver.Constraints.{Empty, Range, Union, Util}

  # List of ranges or versions
  defstruct ranges: []

  def allows_all?(%Union{ranges: left}, %Union{ranges: right}) do
    do_allows_all?(left, right)
  end

  # We can recurse left and right together since they are
  # sorted on minimum version
  defp do_allows_all?([left | lefts], [right | rights]) do
    if Range.allows_all?(left, right) do
      do_allows_all?([left | lefts], rights)
    else
      do_allows_all?(lefts, [right | rights])
    end
  end

  defp do_allows_all?(_lefts, []), do: true
  defp do_allows_all?([], _rights), do: false

  def allows_any?(%Union{ranges: left}, %Union{ranges: right}) do
    do_allows_any?(left, right)
  end

  # We can recurse left and right together since they are
  # sorted on minimum version
  defp do_allows_any?([left | lefts], [right | rights]) do
    cond do
      Constraint.allows_any?(left, right) ->
        true

      # Move forward with the range with the lower max value
      Constraint.allows_higher?(right, left) ->
        do_allows_any?(lefts, [right | rights])

      true ->
        do_allows_any?([left | lefts], rights)
    end
  end

  defp do_allows_any?(_lefts, _rights), do: false

  def difference(%Union{ranges: left}, %Union{ranges: right}) do
    do_difference(left, right, [])
  end

  defp do_difference(lefts, [], acc) do
    # If there are no more "right" ranges, none of the rest needs to
    # be subtracted and can be added as-is
    Util.from_list(Enum.reverse(lefts) ++ acc)
  end

  defp do_difference([], _rights, acc) do
    Util.from_list(acc)
  end

  defp do_difference([left | lefts], [right | rights], acc) do
    cond do
      Constraint.strictly_lower?(right, left) ->
        do_difference([left | lefts], rights, acc)

      Constraint.strictly_higher?(right, left) ->
        do_difference(lefts, [right | rights], [left | acc])

      true ->
        # Left and right overlaps
        # TODO: match %Version{}
        case Constraint.difference(left, right) do
          %Union{ranges: [first, last]} ->
            # If right splits left in half, we only need to check future ranges
            # against the latter half
            do_difference([last | lefts], rights, [first | acc])

          %Range{} = range ->
            # Move the constraint with the lower max value forward. Ensures
            # we keep both lists in sync as much as possible and that large
            # ranges have a chance to subtract or be subtracted of multiple
            # small ranges
            if Range.allows_higher?(range, right) do
              do_difference([range | lefts], rights, acc)
            else
              do_difference(lefts, rights, [range | acc])
            end

          %Empty{} ->
            do_difference(lefts, [right | rights], acc)
        end
    end
  end

  def intersect(%Union{ranges: left}, %Union{ranges: right}) do
    do_intersect(left, right, [])
  end

  defp do_intersect([left | lefts], [right | rights], acc) do
    acc =
      case Constraint.intersect(left, right) do
        %Empty{} -> []
        intersection -> [intersection | acc]
      end

    if Constraint.allows_higher?(right, left) do
      do_intersect(lefts, [right | rights], acc)
    else
      do_intersect([left | lefts], rights, acc)
    end
  end

  defp do_intersect(_lefts, [], acc), do: Util.from_list(acc)
  defp do_intersect([], _rights, acc), do: Util.from_list(acc)

  def union(%Union{} = left, %Union{} = right) do
    Util.union_of([left, right])
  end
end
