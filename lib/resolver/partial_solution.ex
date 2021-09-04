defmodule Resolver.PartialSolution do
  alias Resolver.{Assignment, Term}

  defstruct assignments: [],
            decisions: %{},
            positive: %{},
            negative: %{}

  def relation(%__MODULE__{} = solution, term) do
    case Map.fetch(solution.positive, term.range.name) do
      {:ok, positive} ->
        Term.relation(positive, term)

      :error ->
        case Map.fetch(solution.negative, term.range.name) do
          {:ok, negative} -> Term.relation(negative, term)
          :error -> :overlapping
        end
    end
  end

  def derive(%__MODULE__{} = solution, package_range, positive, incompatibility) do
    solution
    |> assign(package_range, positive, incompatibility)
    |> register(package_range)
  end

  defp assign(solution, package_range, positive, incompatibility) do
    term = %Term{positive: positive, package_range: package_range}

    assignment = %Assignment{
      term: term,
      decision_level: map_size(solution.decisions),
      index: length(solution.assignments),
      cause: incompatibility
    }

    %{solution | assignments: [assignment | solution.assignments]}
  end

  defp register(solution, package_range) do
    case Map.fetch(solution.positive, package_range.name) do
      {:ok, _positive} -> :TODO
      :error -> :TODO
    end
  end
end
