defmodule Resolver.Assignment do
  alias Resolver.{Assignment, Term}

  defstruct term: nil,
            decision_level: nil,
            index: nil,
            cause: nil

  def relation(%Assignment{} = left, %Term{} = right) do
    Term.relation(left.term, right)
  end

  def intersect(%Assignment{} = left, %Assignment{} = right) do
    %{left | term: Term.intersect(left.term, right.term)}
  end

  def difference(%Assignment{} = left, %Term{} = right) do
    if term = Term.intersect(left.term, Term.inverse(right)) do
      %{left | term: term}
    end
  end

  def inverse(%Assignment{} = assignment) do
    %{assignment | term: Term.inverse(assignment.term)}
  end

  def decision?(%Assignment{cause: cause}) do
    cause == nil
  end

  defimpl String.Chars do
    def to_string(%{term: term}) do
      Kernel.to_string(term)
    end
  end

  defimpl Inspect do
    def inspect(
          %{term: term, decision_level: decision_level, index: index, cause: cause},
          _opts
        ) do
      "#Assignment<term: #{term}#{maybe(", cause: ", cause)}, level: #{decision_level}, index: #{index}>"
    end

    defp maybe(_prefix, nil), do: ""
    defp maybe(prefix, value), do: "#{prefix}#{value}"
  end
end
