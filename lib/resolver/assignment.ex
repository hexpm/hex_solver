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
end
