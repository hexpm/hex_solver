# TODO:

# ASSUMPTIONS:

defmodule Resolver do
  alias Resolver.{Incompatibility, PackageRange, PartialSolution, Term}
  alias Resolver.Requirement.{Range, Union}

  # @registry %{
  #   "foo" => %{
  #     "1.0.0" => []
  #   },
  #   "bar" => %{
  #     "1.0.0" => [
  #       {"foo", "~> 1.0"}
  #     ]
  #   }
  # }

  def run() do
    state = new_state()
    unit_propagation(["$root"], state)
  end

  defp unit_propagation([], _state) do
    # TODO
  end

  defp unit_propagation([package | _changed], state) do
    Enum.reduce(state.incompatibilities, state, fn incompatibility ->
      if Incompatibility.has_package?(incompatibility, package) do
        case propagate_incompatability(incompatibility.terms, nil, incompatibility, state) do
          {:ok, package, state} ->
          {:error, :conflict} ->
          {:error, :none} ->
        end
      else
        state
      end
    end)
  end

  defp propagate_incompatability([term | terms], unsatisified, incompatibility, state) do
    case PartialSolution.relation(state.solution, term) do
      :disjoint ->
        # If the term is contradicted by the partial solution then the
        # incompatibility is also contradicted so we can deduce nothing
        {:error, :none}

      :overlapping when is_nil(unsatisified) ->
        propagate_incompatability(terms, term, incompatibility, state)

      :overlapping ->
        # If more than one term is inconclusive we can deduce nothing
        {:error, :none}

      :subset ->
        propagate_incompatability(terms, unsatisified, incompatibility, state)
    end
  end

  defp propagate_incompatability([], nil, incompatibility, state) do
    # All terms in the incompatibility are satisified by the partial solution
    # so we have a conflict
    {:error, :conflict}
  end

  defp propagate_incompatability([], unsatisified, incompatibility, state) do
    # Only one term in the incompatibility was unsatisfied
    solution = PartialSolution.derive(state, unsatisified.range, not unsatisfied.positive, incompatibility)
    {:ok, unsatisfied.range.name, %{state | solution: solution}}
  end

  defp package_in_terms?(package, [{package, _requirement} | _]), do: true
  defp package_in_terms?(package, [_ | terms]), do: package_in_terms?(package, terms)
  defp package_in_terms?(_package, []), do: false

  defp solution_relation({package, term_requirement}, state) do
    case Map.fetch(state.derivations, package) do
      {:ok, derivation_requirement} ->
        Requirement.relation(term_requirement, derivation_requirement)

      :error ->
        :overlapping
    end
  end

  defp new_state() do
    version = {1, 0, 0, []}
    range = %Range{min: version, max: version, include_min: true, include_max: true}
    union = %Union{ranges: [range]}
    package_range = %PackageRange{name: "$root", union: union}
    root = %Incompatibility{terms: %Term{positive: false, range: package_range}}

    %{
      solution: %PartialSolution{}
      incompatibilities: [{"$root", root}]
    }
  end
end
