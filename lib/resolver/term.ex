defmodule Resolver.Term do
  alias Resolver.{Constraint, PackageRange, Term}
  alias Resolver.Constraint.Empty

  defstruct positive: true,
            package_range: nil

  def relation(%Term{} = left, %Term{} = right) do
    left_constraint = constraint(left)
    right_constraint = constraint(right)

    cond do
      right.positive and left.positive ->
        cond do
          not compatible_package?(left, right) -> :disjoint
          Constraint.allows_all?(right_constraint, left_constraint) -> :subset
          not Constraint.allows_any?(left_constraint, right_constraint) -> :disjoint
          true -> :overlapping
        end

      right.positive ->
        cond do
          not compatible_package?(left, right) -> :overlapping
          Constraint.allows_all?(left_constraint, right_constraint) -> :disjoint
          true -> :overlapping
        end

      left.positive ->
        cond do
          not compatible_package?(left, right) -> :subset
          not Constraint.allows_any?(right_constraint, left_constraint) -> :subset
          Constraint.allows_all?(left_constraint, right_constraint) -> :disjoint
          true -> :overlapping
        end

      true ->
        cond do
          not compatible_package?(left, right) -> :overlapping
          Constraint.allows_all?(left_constraint, right_constraint) -> :subset
          true -> :overlapping
        end
    end
  end

  def intersect(%Term{} = left, %Term{} = right) do
    cond do
      compatible_package?(left, right) ->
        cond do
          left.positive != right.positive ->
            positive = if left.positive, do: left, else: right
            negative = if left.positive, do: right, else: left

            constraint = Constraint.difference(constraint(positive), constraint(negative))
            non_empty_term(left, constraint, true)

          left.positive ->
            constraint = Constraint.intersect(constraint(left), constraint(right))
            non_empty_term(left, constraint, true)

          true ->
            constraint = Constraint.union(constraint(left), constraint(right))
            non_empty_term(left, constraint, true)
        end

      left.positive != right.positive ->
        :TODO

      true ->
        :TODO
    end
  end

  defp compatible_package?(left, right) do
    left.package_range.name == right.package_range.name
  end

  defp constraint(%Term{package_range: %PackageRange{constraint: constraint}}) do
    constraint
  end

  defp non_empty_term(_term, %Empty{}, _positive) do
    nil
  end

  defp non_empty_term(term, constraint, positive) do
    %Term{
      package_range: %{term.package_range | constraint: constraint},
      positive: positive
    }
  end
end
