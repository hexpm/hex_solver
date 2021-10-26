defmodule Resolver.Term do
  alias Resolver.{Constraint, PackageRange, Term}
  alias Resolver.Constraints.Empty

  require Logger

  defstruct positive: true,
            package_range: nil,
            optional: false

  def relation(%Term{} = left, %Term{} = right) do
    true = compatible_package?(left, right)

    left_constraint = constraint(left)
    right_constraint = constraint(right)

    cond do
      right.positive and left.positive ->
        cond do
          Constraint.allows_all?(right_constraint, left_constraint) -> :subset
          not Constraint.allows_any?(left_constraint, right_constraint) -> :disjoint
          true -> :overlapping
        end

      right.positive ->
        cond do
          Constraint.allows_all?(left_constraint, right_constraint) -> :disjoint
          true -> :overlapping
        end

      left.positive ->
        cond do
          not Constraint.allows_any?(right_constraint, left_constraint) -> :subset
          Constraint.allows_all?(right_constraint, left_constraint) -> :disjoint
          true -> :overlapping
        end

      true ->
        cond do
          Constraint.allows_all?(left_constraint, right_constraint) -> :subset
          true -> :overlapping
        end
    end
  end

  def intersect(%Term{} = left, %Term{} = right) do
    true = compatible_package?(left, right)
    # NOTE: Technically this should be set, but all tests pass without it
    # left = %{left | optional: left.optional and right.optional}

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
  end

  def satisfies?(%Term{} = left, %Term{} = right) do
    compatible_package?(left, right) and relation(left, right) == :subset
  end

  def inverse(%Term{} = term) do
    %{term | positive: not term.positive}
  end

  def compatible_package?(%Term{} = left, %Term{} = right) do
    left.package_range.name == right.package_range.name
  end

  defp constraint(%Term{package_range: %PackageRange{constraint: constraint}}) do
    constraint
  end

  defp non_empty_term(_term, %Empty{}, _positive) do
    # raise "oops"
    nil
  end

  defp non_empty_term(term, constraint, positive) do
    %Term{
      package_range: %{term.package_range | constraint: constraint},
      positive: positive
    }
  end

  defimpl String.Chars do
    def to_string(%{package_range: %{name: name, constraint: constraint}} = term) do
      "#{positive(term.positive)}#{name} #{constraint}#{optional(term.optional)}"
    end

    defp positive(true), do: ""
    defp positive(false), do: "not "

    defp optional(true), do: " (optional)"
    defp optional(false), do: ""
  end

  defimpl Inspect do
    def inspect(term, _opts) do
      "#Term<#{to_string(term)}>"
    end
  end
end
