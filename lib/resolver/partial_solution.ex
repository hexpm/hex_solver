defmodule Resolver.PartialSolution do
  alias Resolver.{Assignment, PackageRange, PartialSolution, Term}

  defstruct assignments: [],
            decisions: %{},
            positive: %{},
            negative: %{},
            backtracking: false,
            attempted_solutions: 1

  def relation(%PartialSolution{} = solution, term) do
    name = term.package_range.name

    case Map.fetch(solution.positive, name) do
      {:ok, positive} ->
        Assignment.relation(positive, term)

      :error ->
        case Map.fetch(solution.negative, name) do
          {:ok, negative} -> Assignment.relation(negative, term)
          :error -> :overlapping
        end
    end
  end

  def satisfies?(%PartialSolution{} = solution, term) do
    relation(solution, term) == :subset
  end

  def derive(%PartialSolution{} = solution, package_range, positive, incompatibility) do
    solution
    |> assign(package_range, positive, incompatibility)
    |> register(package_range.name)
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

  defp register(%{assignments: [assignment | _]} = solution, name) do
    case Map.fetch(solution.positive, name) do
      {:ok, old_assignment} ->
        positive =
          Map.put(solution.positive, name, Assignment.intersect(old_assignment, assignment))

        %{solution | positive: positive}

      :error ->
        assignment =
          if old_assignment = Map.get(solution.negative, name) do
            Assignment.intersect(old_assignment, assignment)
          else
            assignment
          end

        if assignment.term.positive do
          negative = Map.delete(solution.negative, name)
          positive = Map.put(solution.positive, name, assignment)
          %{solution | negative: negative, positive: positive}
        else
          negative = Map.put(solution.negative, name, assignment)
          %{solution | negative: negative}
        end
    end
  end

  def unsatisfied(%PartialSolution{} = solution) do
    solution.positive
    |> Enum.reject(fn {package, _assignment} -> Map.has_key?(solution.decisions, package) end)
    |> Enum.map(fn {_package, assignment} -> assignment.term.package_range end)
  end

  def decide(%PartialSolution{} = solution, package, version) do
    attempted_solutions = solution.attempted_solutions + if solution.backtracking, do: 1, else: 0
    decisions = Map.put(solution.decisions, package, version)
    package_range = %PackageRange{name: package, constraint: version}

    %{
      solution
      | attempted_solutions: attempted_solutions,
        backtracking: false,
        decisions: decisions
    }
    |> assign(package_range, true, nil)
  end
end
