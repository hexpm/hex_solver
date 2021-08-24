defmodule Resolver.PartialSolution do
  alias Resolver.{Assignment, PackageRange, Term}

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
    |> register(package_range, )
  end

  defp assign(solution, package_range, positive, incompatibility) do
    term = %Term{positive: positive, range: package_range}

    assignment = %Assignment{
      term: term,
      decision_level: Map.size(state.decisions),
      index: length(assignments),
      cause: incompatibility
    }

    %{solution | assignments: [assignment | state.assignments]}
  end

  defp register() do
    case Map.fetch(solution.positive, package_range.name) do
      {:ok, positive}
    end
  end
end
