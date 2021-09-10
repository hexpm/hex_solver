defmodule Resolver do
  alias Resolver.{Constraint, Incompatibility, PackageRange, PartialSolution, Term}
  alias Resolver.Constraints.Util

  def run(registry) do
    solve("$root", new_state(registry))
  end

  defp solve(next, state) do
    state = unit_propagation([next], state)

    case choose_package_version(state) do
      :done -> state
      {:choice, package, state} -> solve(package, state)
    end
  end

  defp unit_propagation([], state) do
    state
  end

  defp unit_propagation([package | changed], state) do
    incompatibilities = Enum.reverse(Map.fetch!(state.incompatibilities, package))

    {changed, state} =
      Enum.reduce_while(incompatibilities, {changed, state}, fn
        incompatibility, {changed, state} ->
          case propagate_incompatability(incompatibility.terms, nil, incompatibility, state) do
            {:ok, result, state} ->
              {:cont, {changed ++ [result], state}}

            {:error, :conflict} ->
              raise "TODO"

            # root_cause = resolve_conflict(incompatibility)
            # {:ok, result, state} = propagate_incompatability(root_cause.terms, nil, root_cause, state)
            # {:halt, {[result], state}}

            {:error, :none} ->
              {:cont, {changed, state}}
          end
      end)

    unit_propagation(changed, state)
  end

  defp propagate_incompatability([term | terms], unsatisified, incompatibility, state) do
    case PartialSolution.relation(state.solution, term) do
      :disjoint ->
        # If the term is contradicted by the partial solution then the
        # incompatibility is also contradicted so we can deduce nothing
        {:error, :none}

      :overlapping when unsatisified == nil ->
        propagate_incompatability(terms, term, incompatibility, state)

      :overlapping ->
        # If more than one term is inconclusive we can deduce nothing
        {:error, :none}

      :subset ->
        propagate_incompatability(terms, unsatisified, incompatibility, state)
    end
  end

  defp propagate_incompatability([], nil, _incompatibility, _state) do
    # All terms in the incompatibility are satisified by the partial solution
    # so we have a conflict
    {:error, :conflict}
  end

  defp propagate_incompatability([], unsatisfied, incompatibility, state) do
    # Only one term in the incompatibility was unsatisfied
    solution =
      PartialSolution.derive(
        state.solution,
        unsatisfied.package_range,
        not unsatisfied.positive,
        incompatibility
      )

    {:ok, unsatisfied.package_range.name, %{state | solution: solution}}
  end

  defp choose_package_version(state) do
    unsatisfied = PartialSolution.unsatisfied(state.solution)

    if unsatisfied == [] do
      :done
    else
      package_range_versions =
        Enum.map(unsatisfied, fn package_range ->
          versions = state.registry.versions(package_range.name)
          allowed = Enum.filter(versions, &Constraint.allows?(package_range.constraint, &1))
          {package_range, allowed}
        end)

      # Prefer packages with few remaining versions so that if there is conflict
      # later it will be forced quickly
      {package_range, versions} =
        Enum.min_by(package_range_versions, fn {_package_range, versions} -> length(versions) end)

      if versions == [] do
        # TODO: Detect if the constraint excludes a single version, then it is
        #       from a lockfile (true?), in that case change the constraint
        #       to allow any version, this gives better error reporting.
        #       https://github.com/dart-lang/pub/blob/master/lib/src/solver/version_solver.dart#L349-L352

        # If no version satisfies the constraint then add an incompatibility that indicates that
        term = %Term{positive: true, package_range: package_range}
        incompatibility = %Incompatibility{terms: [term]}
        state = add_incompatibility(state, incompatibility)
        {:choice, package_range.name, state}
      else
        # TODO: Pick "best" version instead of last versions
        version = List.last(versions)
        incompatibilities = dependencies_as_incompatibilities(state, package_range.name, version)

        {state, conflict} =
          Enum.reduce(incompatibilities, {state, false}, fn incompatibility, {state, conflict} ->
            # If an incompatibility is already satisfied then selecting this version would cause
            # a conflict. We'll continue adding its dependencies then go back to unit propagation
            # that will eventually choose a better version.
            conflict =
              conflict or incompatibility_conflict?(state, incompatibility, package_range.name)

            state = add_incompatibility(state, incompatibility)
            {state, conflict}
          end)

        solution =
          if conflict do
            state.solution
          else
            PartialSolution.decide(state.solution, package_range.name, version)
          end

        state = %{state | solution: solution}
        {:choice, package_range.name, state}
      end
    end
  end

  defp add_incompatibility(state, incompatibility) do
    incompatibilities =
      Enum.reduce(incompatibility.terms, state.incompatibilities, fn term, incompatibilities ->
        Map.update(
          incompatibilities,
          term.package_range.name,
          [incompatibility],
          &[incompatibility | &1]
        )
      end)

    %{state | incompatibilities: incompatibilities}
  end

  defp incompatibility_conflict?(state, incompatibility, name) do
    Enum.all?(incompatibility.terms, fn term ->
      term.package_range.name == name or PartialSolution.satisfies?(state.solution, term)
    end)
  end

  # NOTE: Much of this can be cached
  # TODO: Don't return incompatibilities we already returned
  #       https://github.com/dart-lang/pub/blob/master/lib/src/solver/package_lister.dart#L255-L259
  defp dependencies_as_incompatibilities(state, package, version) do
    versions_dependencies =
      Map.new(state.registry.versions(package), fn version ->
        {version, Map.new(state.registry.dependencies(package, version))}
      end)

    Enum.map(versions_dependencies[version], fn {dependency, constraint} ->
      versions_constraint =
        Enum.map(versions_dependencies, fn {version, dependencies} ->
          {version, dependencies[dependency]}
        end)

      # Find range of versions around the current version for which the
      # constraint is the same to create an incompatibility based on a
      # larger set of versions for the parent package.
      # This optimization let us skip many versions during conflict resolution.
      upper = next_bound(versions_constraint, version, constraint)
      lower = next_bound(Enum.reverse(versions_constraint), version, constraint)

      package_range = %PackageRange{name: package, constraint: Util.from_bounds(lower, upper)}
      dependency_range = %PackageRange{name: dependency, constraint: constraint}
      package_term = %Term{positive: true, package_range: package_range}
      dependency_term = %Term{positive: false, package_range: dependency_range}
      %Incompatibility{terms: [package_term, dependency_term]}
    end)
  end

  defp next_bound([{version, _constraint} | versions_dependencies], version, constraint) do
    find_bound(versions_dependencies, version, constraint)
  end

  defp find_bound([{version, constraint} | versions_dependencies], _last, constraint) do
    find_bound(versions_dependencies, version, constraint)
  end

  defp find_bound([_ | _], last, _constraint) do
    last
  end

  defp find_bound([], last, _constraint) do
    last
  end

  defp new_state(registry) do
    version = Version.parse!("1.0.0")
    package_range = %PackageRange{name: "$root", constraint: version}
    root = %Incompatibility{terms: [%Term{positive: false, package_range: package_range}]}

    %{
      solution: %PartialSolution{},
      incompatibilities: %{},
      registry: registry
    }
    |> add_incompatibility(root)
  end
end
