defmodule HexSolver.PartialSolution do
  @moduledoc false

  alias HexSolver.{Assignment, PackageRange, PartialSolution, Term}

  defstruct assignments: [],
            decisions: %{},
            positive: %{},
            negative: %{},
            backtracking: false,
            attempted_solutions: 1

  def relation(%PartialSolution{} = solution, %Term{} = term, opts \\ []) do
    name = term.package_range.name

    case Map.fetch(solution.positive, name) do
      {:ok, positive} ->
        Term.relation(positive.term, term, opts)

      :error ->
        with {:ok, negatives} <- Map.fetch(solution.negative, name),
             {:ok, negative} <- fetch_negative(negatives, term) do
          Term.relation(negative.term, term, opts)
        else
          :error -> :overlapping
        end
    end
  end

  # The package being absent implies the negative term for every repo
  defp fetch_negative(negatives, term) do
    with :error <- Map.fetch(negatives, :any) do
      Map.fetch(negatives, term.package_range.repo)
    end
  end

  def satisfies?(%PartialSolution{} = solution, %Term{} = term, opts \\ []) do
    relation(solution, term, opts) == :subset
  end

  def satisfier(%PartialSolution{} = solution, term, opts \\ []) do
    name = term.package_range.name

    # Assignments are registered as in the solution, so that terms for the package
    # from other repos are taken into account
    {:satisfier, assignment} =
      solution.assignments
      |> Enum.reverse()
      |> Enum.filter(&(&1.term.package_range.name == name))
      |> Enum.reduce_while(%PartialSolution{}, fn assignment, partial ->
        partial = register(partial, assignment)

        if relation(partial, term, opts) == :subset do
          {:halt, {:satisfier, assignment}}
        else
          {:cont, partial}
        end
      end)

    assignment
  end

  def backtrack(%PartialSolution{} = solution, decision_level) do
    {removed, assignments} =
      Enum.split_while(solution.assignments, &(&1.decision_level > decision_level))

    removed_names = Enum.map(removed, & &1.term.package_range.name)
    removed_decisions = Enum.filter(removed, &Assignment.decision?/1)

    decisions =
      Map.drop(solution.decisions, Enum.map(removed_decisions, & &1.term.package_range.name))

    positive = Map.drop(solution.positive, removed_names)
    negative = Map.drop(solution.negative, removed_names)

    solution = %{
      solution
      | assignments: assignments,
        decisions: decisions,
        positive: positive,
        negative: negative,
        backtracking: true
    }

    Enum.reduce(assignments, solution, fn assignment, solution ->
      if assignment.term.package_range.name in removed_names do
        register(solution, assignment)
      else
        solution
      end
    end)
  end

  def derive(%PartialSolution{} = solution, term, incompatibility) do
    {assignment, solution} = assign(solution, term, incompatibility)
    register(solution, assignment)
  end

  def decide(
        %PartialSolution{} = solution,
        %PackageRange{repo: repo, name: package, constraint: version} = package_range
      ) do
    attempted_solutions = solution.attempted_solutions + if solution.backtracking, do: 1, else: 0
    decisions = Map.put(solution.decisions, package, {version, repo})
    term = %Term{package_range: package_range, positive: true}

    solution = %{
      solution
      | attempted_solutions: attempted_solutions,
        backtracking: false,
        decisions: decisions
    }

    {assignment, solution} = assign(solution, term, nil)
    register(solution, assignment)
  end

  defp assign(solution, term, incompatibility) do
    assignment = %Assignment{
      term: term,
      decision_level: map_size(solution.decisions),
      index: length(solution.assignments),
      cause: incompatibility
    }

    solution = %{solution | assignments: [assignment | solution.assignments]}
    {assignment, solution}
  end

  defp register(solution, assignment) do
    name = assignment.term.package_range.name
    repo = assignment.term.package_range.repo

    case Map.fetch(solution.positive, name) do
      {:ok, old_assignment} ->
        case Assignment.intersect(old_assignment, assignment) do
          # Optional terms for different repos only allow the package to be absent
          %Assignment{term: nil} when old_assignment.term.optional and assignment.term.optional ->
            term = Term.absent_term(old_assignment.term)
            negatives = %{term.package_range.repo => %{old_assignment | term: term}}
            positive = Map.delete(solution.positive, name)
            negative = Map.put(solution.negative, name, negatives)
            %{solution | positive: positive, negative: negative}

          # An optional term becomes negative when the package can only be absent
          %Assignment{term: %Term{positive: false}} = assignment ->
            positive = Map.delete(solution.positive, name)
            negatives = %{assignment.term.package_range.repo => assignment}
            negative = Map.put(solution.negative, name, negatives)
            %{solution | positive: positive, negative: negative}

          %Assignment{term: %Term{positive: true}} = assignment ->
            positive = Map.put(solution.positive, name, assignment)
            %{solution | positive: positive}
        end

      :error ->
        # Negative terms are kept per repo, since terms for the same package from
        # different repos can only be intersected when one of them is positive
        {old_assignment, negatives} =
          solution.negative
          |> Map.get(name, %{})
          |> Map.pop(repo)

        assignment =
          if old_assignment do
            Assignment.intersect(old_assignment, assignment)
          else
            assignment
          end

        if assignment.term.positive do
          assignment =
            Enum.reduce(Map.values(negatives), assignment, &Assignment.intersect(&2, &1))

          negative = Map.delete(solution.negative, name)
          positive = Map.put(solution.positive, name, assignment)
          %{solution | negative: negative, positive: positive}
        else
          negatives = Map.put(negatives, assignment.term.package_range.repo, assignment)
          negative = Map.put(solution.negative, name, negatives)
          %{solution | negative: negative}
        end
    end
  end

  def unsatisfied(%PartialSolution{} = solution) do
    solution.positive
    |> Map.values()
    |> Enum.reject(&Map.has_key?(solution.decisions, &1.term.package_range.name))
    |> Enum.reject(& &1.term.optional)
    |> Enum.map(& &1.term.package_range)
  end
end
