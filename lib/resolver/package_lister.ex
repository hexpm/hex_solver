defmodule Resolver.PackageLister do
  alias Resolver.{Constraint, Incompatibility, PackageRange, Term}
  alias Resolver.Constraints.Util

  # Prefer packages with few remaining versions so that if there is conflict
  # later it will be forced quickly
  def pick_package(registry, locked, package_ranges) do
    package_range_versions =
      Enum.map(package_ranges, fn package_range ->
        name = String.trim_trailing(package_range.name, "$optional")

        case registry.versions(name) do
          {:ok, versions} ->
            # TODO: This wont give a good error message when the lock file
            #       prevents a solution. Can we treat locked as optional instead
            #       from a "$lock" package instead?
            case Map.fetch(locked, name) do
              {:ok, version} ->
                allowed =
                  if Constraint.allows?(package_range.constraint, version),
                    do: [version],
                    else: []

                {package_range, allowed}

              :error ->
                allowed = Enum.filter(versions, &Constraint.allows?(package_range.constraint, &1))
                {package_range, allowed}
            end

          :error ->
            throw({__MODULE__, :minimal_versions, name})
        end
      end)

    {package_range, versions} =
      Enum.min_by(package_range_versions, fn {_package_range, versions} -> length(versions) end)

    {:ok, package_range, versions}
  catch
    :throw, {__MODULE__, :minimal_versions, name} ->
      {:error, name}
  end

  # NOTE: Much of this can be cached
  # TODO: Don't return incompatibilities we already returned
  #       https://github.com/dart-lang/pub/blob/master/lib/src/solver/package_lister.dart#L255-L259
  def dependencies_as_incompatibilities(registry, overrides, package, version) do
    package = String.trim_trailing(package, "$optional")
    {:ok, versions} = registry.versions(package)

    versions_dependencies =
      Map.new(versions, fn version ->
        {:ok, dependencies} = registry.dependencies(package, version)
        {version, Map.new(dependencies)}
      end)

    versions_dependencies[version]
    |> Enum.reject(fn {dependency, _} -> dependency in overrides and package != "$root" end)
    |> Enum.map(fn {dependency, {constraint, optional}} ->
      versions_constraints =
        Enum.map(versions_dependencies, fn {version, dependencies} ->
          {version, dependencies[dependency]}
        end)

      # Find range of versions around the current version for which the
      # constraint is the same to create an incompatibility based on a
      # larger set of versions for the parent package.
      # This optimization let us skip many versions during conflict resolution.
      lower = next_bound(Enum.reverse(versions_constraints), version, constraint)
      upper = next_bound(versions_constraints, version, constraint)
      lower = if lower == Enum.at(versions, 0), do: nil, else: lower
      upper = if upper == Enum.at(versions, -1), do: nil, else: upper

      package_range = %PackageRange{name: package, constraint: Util.from_bounds(lower, upper)}
      dependency_range = %PackageRange{name: dependency, constraint: constraint}
      package_term = %Term{positive: true, package_range: package_range}

      dependency_term = %Term{
        positive: false,
        package_range: dependency_range,
        optional: optional
      }

      Incompatibility.new([package_term, dependency_term], :dependency)
    end)
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
end
