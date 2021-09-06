defmodule Resolver.Constraints.Util do
  alias Resolver.Constraint
  alias Resolver.Constraints.{Empty, Range, Union}

  def from_list([]), do: %Empty{}
  def from_list([single]), do: single
  def from_list(acc), do: %Union{ranges: acc}

  def union_of(list) do
    list = flatten(list)

    cond do
      list == [] ->
        %Empty{}

      Enum.any?(list, &Constraint.any?/1) ->
        %Range{}

      true ->
        Enum.reduce(Enum.sort(list, Constraint), [], fn constraint, acc ->
          previous = List.first(acc)

          cond do
            acc == [] ->
              [constraint | acc]

            not Constraint.allows_any?(previous, constraint) and
                not Constraint.adjacent?(previous, constraint) ->
              [constraint | acc]

            true ->
              # Merge this constraint with previous, but only if they touch
              List.replace_at(acc, 0, Constraint.union(previous, constraint))
          end
        end)
        |> Enum.reverse()
        |> from_list()
    end
  end

  defp flatten(list) do
    Enum.flat_map(list, fn
      %Union{ranges: ranges} -> ranges
      %Empty{} -> []
      other -> other
    end)
  end

  def from_bounds(%Version{} = lower, %Version{} = upper) do
    case Version.compare(lower, upper) do
      :eq -> lower
      :lt -> %Range{min: lower, max: upper, include_min: true, include_max: true}
    end
  end
end
