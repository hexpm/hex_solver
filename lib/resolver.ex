defmodule Resolver do
  alias Resolver.{Assignment, Constraint, Incompatibility, PackageRange, PartialSolution, Term}
  alias Resolver.Constraints.Util

  require Logger

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
    incompatibilities = Map.fetch!(state.incompatibilities, package)

    {changed, state} =
      Enum.reduce_while(incompatibilities, {changed, state}, fn
        incompatibility, {changed, state} ->
          case propagate_incompatibility(incompatibility.terms, nil, incompatibility, state) do
            {:error, :conflict} ->
              {:ok, root_cause, state} = conflict_resolution(state, incompatibility)

              {:ok, result, state} =
                propagate_incompatibility(root_cause.terms, nil, root_cause, state)

              {:halt, {[result], state}}

            {:ok, result, state} ->
              {:cont, {changed ++ [result], state}}

            {:error, :none} ->
              {:cont, {changed, state}}
          end
      end)

    unit_propagation(changed, state)
  end

  defp propagate_incompatibility([term | terms], unsatisified, incompatibility, state) do
    case PartialSolution.relation(state.solution, term) do
      :disjoint ->
        # If the term is contradicted by the partial solution then the
        # incompatibility is also contradicted so we can deduce nothing
        {:error, :none}

      :overlapping when unsatisified != nil ->
        # If more than one term is inconclusive we can deduce nothing
        {:error, :none}

      :overlapping ->
        propagate_incompatibility(terms, term, incompatibility, state)

      :subset ->
        propagate_incompatibility(terms, unsatisified, incompatibility, state)
    end
  end

  defp propagate_incompatibility([], nil, _incompatibility, _state) do
    # All terms in the incompatibility are satisified by the partial solution
    # so we have a conflict
    {:error, :conflict}
  end

  defp propagate_incompatibility([], unsatisfied, incompatibility, state) do
    # Only one term in the incompatibility was unsatisfied
    Logger.debug("RESOLVER: derived #{unsatisfied.package_range}")

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
      # TODO: Handle package not found
      #       Use :package_not_found incompatibility cause?
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
        incompatibility = Incompatibility.new([term], :no_versions)
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
            Logger.debug("RESOLVER: selecting #{package_range.name} #{version}")
            PartialSolution.decide(state.solution, package_range.name, version)
          end

        state = %{state | solution: solution}
        {:choice, package_range.name, state}
      end
    end
  end

  defp add_incompatibility(state, incompatibility) do
    Logger.debug("RESOLVER: fact #{incompatibility}")

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
    # TODO: Handle package not found
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
      lower = next_bound(Enum.reverse(versions_constraint), version, constraint)
      upper = next_bound(versions_constraint, version, constraint)

      package_range = %PackageRange{name: package, constraint: Util.from_bounds(lower, upper)}
      dependency_range = %PackageRange{name: dependency, constraint: constraint}
      package_term = %Term{positive: true, package_range: package_range}
      dependency_term = %Term{positive: false, package_range: dependency_range}
      Incompatibility.new([package_term, dependency_term], :dependency)
    end)
  end

  # Given an incompatibility that's satisified by the solution, construct a new
  # incompatibility that encapsulates the root cause of the conflict and backtracks
  # until the new incompatibility will allow propagation to deduce new assignments.
  defp conflict_resolution(state, incompatibility) do
    Logger.debug("RESOLVER: conflict #{incompatibility}")
    do_conflict_resolution(state, incompatibility, false)
  catch
    :throw, {:resolver_conflict, incompatibility, state} ->
      {:ok, incompatibility, state}
  end

  defp do_conflict_resolution(state, incompatibility, new_incompatibility?) do
    if Incompatibility.failure?(incompatibility) do
      # TODO
      :solve_failure
    else
      resolution = %{
        # The term in incompatibility.terms that was most recently satisfied by the solution.
        most_recent_term: nil,
        # The earliest assignment in the solution such that incompatibility is satisfied
        # by the solution up to and including this assignment.
        most_recent_satisfier: nil,
        # The difference between most_recent_satisfier and most_recent_term, that is,
        # the versions that are allowed by most_recent_satisfier but not by most_recent_term.
        # nil if most_recent_satisfier totally satisfies most_recent_term.
        difference: nil,
        # The decision level of the earliest assignment before most_recent_satisfier
        # such that incompatibility is satisfied by the solution up to and including
        # this assignment and most_recent_satisfier.

        # Decision level 1 is the level where the root package was selected. We can
        # go back to level 0 but level 1 tends to give better error messages, because
        # references to the root package end up closer to the final conclusion that
        # no solution exists.
        previous_satisfier_level: 1
      }

      resolution =
        Enum.reduce(incompatibility.terms, resolution, fn term, resolution ->
          satisfier = PartialSolution.satisfier(state.solution, term)

          resolution =
            cond do
              resolution.most_recent_satisfier == nil ->
                %{resolution | most_recent_term: term, most_recent_satisfier: satisfier}

              resolution.most_recent_satisfier.index < satisfier.index ->
                %{
                  resolution
                  | most_recent_term: term,
                    most_recent_satisfier: satisfier,
                    difference: nil,
                    previous_satisfier_level:
                      max(
                        resolution.previous_satisfier_level,
                        resolution.most_recent_satisfier.decision_level
                      )
                }

              true ->
                %{
                  resolution
                  | previous_satisfier_level:
                      max(resolution.previous_satisfier_level, satisfier.decision_level)
                }
            end

          if resolution.most_recent_term == term do
            # If most_recent_satisfier doesn't satisfy most_recent_term on its own,
            # then the next most recent satisfier may not be the one that satisfies
            # remainder

            difference =
              Assignment.difference(resolution.most_recent_satisfier, resolution.most_recent_term)

            if difference == nil do
              resolution
            else
              satisfier = PartialSolution.satisfier(state.solution, Term.inverse(difference.term))

              previous_satisfier_level =
                max(resolution.previous_satisfier_level, satisfier.decision_level)

              %{resolution | previous_satisfier_level: previous_satisfier_level}
            end
          else
            resolution
          end
        end)

      # If most_recent_satisfier is the only satisfier left at its decision level,
      # or if it has no cause (indicating that it's a decision rather than a
      # derivation), then the incompatibility is the root cause. We then backjump
      # to previous_satisfier_level, where the incompatibility is guaranteed to
      # allow propagation to produce more assignments
      if resolution.previous_satisfier_level < resolution.most_recent_satisfier.decision_level or
           resolution.most_recent_satisfier.cause == nil do
        solution = PartialSolution.backtrack(state.solution, resolution.previous_satisfier_level)
        state = %{state | solution: solution}

        state =
          if new_incompatibility?,
            do: add_incompatibility(state, incompatibility),
            else: state

        throw({:resolver_conflict, incompatibility, state})
      end

      # Create a new incompatibility be combining the given incompatibility with
      # the incompatibility that caused most_recent_satisfier to be assigned.
      # Doing this iteratively constructs a new new incompatibility that's guaranteed
      # to be true (we know for sure no solution will satisfy the incompatibility)
      # while also approximating the intuitive notion of the "root cause" of the conflict.
      new_terms =
        Enum.filter(incompatibility.terms, &(&1 != resolution.most_recent_term)) ++
          Enum.filter(
            resolution.most_recent_satisfier.cause.terms,
            &(&1.package_range != resolution.most_recent_satisfier.term.package_range)
          )

      # The most_recent_satisfier may not satisfy most_recent_term on its own if
      # there are a collection of constraints on most_recent_term that only satisfy
      # it together. For example, if most_recent_term is `foo ~> 1.0` and solution
      # contains `[foo >= 1.0.0, foo < 2.0.0]`, the most_recent_satisfier will be
      # `foo < 2.0.0` even though it doesn't totally satisfy `foo ~> 1.0`.

      # In this case we add `most_recent_satisfier \ most_recent_term` to the
      # incompatibility as well. See https://github.com/dart-lang/pub/tree/master/doc/solver.md#conflict-resolution
      # for more details.
      new_terms =
        if resolution.difference,
          do: new_terms ++ [Assignment.inverse(resolution.difference)],
          else: new_terms

      incompatibility = Incompatibility.new(new_terms, {:conflict, incompatibility, resolution.most_recent_satisfier.cause})

      partially = if resolution.difference, do: " partially"

      Logger.debug("""
      RESOLVER: conflict resolution
        #{resolution.most_recent_term} is#{partially} satisfied by #{resolution.most_recent_satisfier}
        which is caused by #{resolution.most_recent_satisfier.cause}
        thus #{incompatibility}\
      """)

      do_conflict_resolution(state, incompatibility, true)
    end
  end

  defp next_bound([{version, _constraint} | versions_dependencies], version, constraint) do
    find_bound(versions_dependencies, version, constraint)
  end

  defp next_bound([_ | versions_dependencies], version, constraint) do
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
    root = Incompatibility.new([%Term{positive: false, package_range: package_range}], :root)

    %{
      solution: %PartialSolution{},
      incompatibilities: %{},
      registry: registry
    }
    |> add_incompatibility(root)
  end
end
