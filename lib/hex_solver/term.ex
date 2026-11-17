defmodule HexSolver.Term do
  @moduledoc false

  alias HexSolver.{Constraint, PackageRange, Term}
  alias HexSolver.Constraints.{Empty, Util}

  defstruct positive: true,
            package_range: nil,
            optional: false

  def relation(left, right, opts \\ []) do
    optionals = Keyword.get(opts, :optionals, true)

    case do_relation(left, right) do
      # A negative term allows the package to be absent, so it can't satisfy an
      # optional term. It's disjoint when absent is all the negative term allows.
      :subset when right.optional and not left.positive ->
        if Constraint.any?(constraint(left)), do: :disjoint, else: :overlapping

      # An optional term allows the package to be absent, so it can't satisfy a
      # required positive term
      :subset when left.optional and right.positive and not right.optional ->
        :overlapping

      # An optional negative term only holds when the package is selected, so an
      # optional positive term can't satisfy it either
      :subset
      when not optionals and left.optional and left.positive and right.optional and
             not right.positive ->
        :overlapping

      # An optional term also allows the package to be absent, which a negative
      # term allows and a positive term doesn't
      :disjoint when left.optional and not right.optional and not right.positive ->
        :overlapping

      relation ->
        if optionals and left.optional and right.optional,
          do: :disjoint,
          else: relation
    end
  end

  def do_relation(%Term{} = left, %Term{} = right) do
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

      right.positive and not left.positive ->
        cond do
          not compatible_package?(left, right) -> :overlapping
          Constraint.allows_all?(left_constraint, right_constraint) -> :disjoint
          true -> :overlapping
        end

      not right.positive and left.positive ->
        cond do
          not compatible_package?(left, right) -> :subset
          not Constraint.allows_any?(right_constraint, left_constraint) -> :subset
          Constraint.allows_all?(right_constraint, left_constraint) -> :disjoint
          true -> :overlapping
        end

      not right.positive and not left.positive ->
        cond do
          not compatible_package?(left, right) -> :overlapping
          Constraint.allows_all?(left_constraint, right_constraint) -> :subset
          true -> :overlapping
        end
    end
  end

  def intersect(%Term{} = left, %Term{} = right) do
    if compatible_package?(left, right) do
      optional = left.optional and right.optional

      cond do
        left.positive != right.positive ->
          positive = if left.positive, do: left, else: right
          negative = if left.positive, do: right, else: left

          # A negative term only excludes versions, so it can't make an optional term
          # required. When it excludes every version the optional term allows, the
          # package can only be absent, which is the negative term for every version.
          case Constraint.difference(constraint(positive), constraint(negative)) do
            %Empty{} when positive.optional -> absent_term(left)
            constraint -> non_empty_term(left, constraint, positive.optional, true)
          end

        left.positive and right.positive ->
          # Two optional terms without common versions only allow the package to be absent
          case Constraint.intersect(constraint(left), constraint(right)) do
            %Empty{} when optional -> absent_term(left)
            constraint -> non_empty_term(left, constraint, optional, true)
          end

        not left.positive and not right.positive ->
          # An optional negative term only holds when the package is selected, so the
          # intersection does too
          constraint = Constraint.union(constraint(left), constraint(right))
          non_empty_term(left, constraint, left.optional or right.optional, false)
      end
    else
      nil
    end
  end

  def difference(%Term{} = left, %Term{} = right) do
    intersect(left, inverse(right))
  end

  def satisfies?(%Term{} = left, %Term{} = right, opts \\ []) do
    compatible_package?(left, right) and relation(left, right, opts) == :subset
  end

  def inverse(%Term{} = term) do
    %{term | positive: not term.positive}
  end

  def compatible_package?(%Term{package_range: %PackageRange{name: "$root"}}, %Term{}) do
    true
  end

  def compatible_package?(%Term{}, %Term{package_range: %PackageRange{name: "$root"}}) do
    true
  end

  def compatible_package?(%Term{package_range: left}, %Term{package_range: right}) do
    {left.repo, left.name} == {right.repo, right.name}
  end

  defp constraint(%Term{package_range: %PackageRange{constraint: constraint}}) do
    constraint
  end

  defp absent_term(term) do
    %Term{package_range: %{term.package_range | constraint: Util.any()}, positive: false}
  end

  defp non_empty_term(_term, %Empty{}, _optional, _positive) do
    nil
  end

  defp non_empty_term(term, constraint, optional, positive) do
    %Term{
      package_range: %{term.package_range | constraint: constraint},
      positive: positive,
      optional: optional
    }
  end

  def to_string(%Term{package_range: package_range, positive: positive}) do
    "#{positive(positive)}#{PackageRange.to_string(package_range)}"
  end

  defp positive(true), do: ""
  defp positive(false), do: "not "

  defimpl String.Chars do
    defdelegate to_string(term), to: HexSolver.Term
  end

  defimpl Inspect do
    def inspect(
          %Term{package_range: package_range, positive: positive, optional: optional},
          _opts
        ) do
      "#Term<#{positive(positive)}#{PackageRange.to_string(package_range)}#{optional(optional)}>"
    end

    defp positive(true), do: ""
    defp positive(false), do: "not "

    defp optional(true), do: " (optional)"
    defp optional(false), do: ""
  end
end
