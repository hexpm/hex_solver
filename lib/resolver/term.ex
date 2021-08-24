defmodule Resolver.Term do
  alias Resolver.Requirement.Union

  defstruct positive: true,
            range: nil

  def relation(left, right) do
    left_union = left.range.union
    right_union = right.range.union

    cond do
      right.positive and left.positive ->
        cond do
          not compatible_package?(left, right) -> :disjoint
          Union.allows_all?(right_union, left_union) -> :subset
          not Union.allows_any?(left_union, right_union) -> :disjoint
          true -> :overlapping
        end

      right.positive ->
        cond do
          not compatible_package?(left, right) -> :overlapping
          Union.allows_all?(left_union, right_union) -> :disjoint
          true -> :overlapping
        end

      left.positive ->
        cond do
          not compatible_package?(left, right) -> :subset
          not Union.allows_any?(right_union, left_union) -> :subset
          Union.allows_all?(left_union, right_union) -> :disjoint
          true -> :overlapping
        end

      true ->
        cond do
          not compatible_package?(left, right) -> :overlapping
          Union.allows_all?(left_union, right_union) -> :subset
          true -> :overlapping
        end
    end
  end

  def intersect(left, right) do
    cond do
      compatible_package?(left, right) ->
        cond do
          left.positive != right.positive ->
            positive = if left.positive, do: left, else: right
            negative = if left.positive, do: right, else: left

          left.positive ->
          true ->
        end

      left.positive != right.positive ->

      true ->
        is_nil
    end
  end

  defp compatible_package?(left, right) do
    left.range.name == right.range.name
  end
end
