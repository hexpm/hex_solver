defmodule Resolver.PackageLister do
  alias Resolver.{Constraint, Incompatibility, PackageRange, Term}
  alias Resolver.Constraints.Range

  # Prefer packages with few remaining versions so that if there is conflict
  # later it will be forced quickly
  def pick_package(registry, locked, package_ranges) do
    package_range_versions =
      Enum.map(package_ranges, fn package_range ->
        case registry.versions(package_range.name) do
          {:ok, versions} ->
            # TODO: This wont give a good error message when the lock file
            #       prevents a solution. Can we treat locked as optional instead
            #       from a "$lock" package instead?
            case Map.fetch(locked, package_range.name) do
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
            throw({__MODULE__, :minimal_versions, package_range.name})
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
    {:ok, versions} = registry.versions(package)

    versions_dependencies =
      Enum.map(versions, fn version ->
        {:ok, dependencies} = registry.dependencies(package, version)
        {version, Map.new(dependencies)}
      end)

    {_version, dependencies} = List.keyfind(versions_dependencies, version, 0)

    dependencies
    |> Enum.reject(fn {dependency, _} -> dependency in overrides and package != "$root" end)
    |> Enum.map(fn {dependency, {constraint, optional}} ->
      version_constraints =
        Enum.map(versions_dependencies, fn {version, dependencies} ->
          {version, dependencies[dependency]}
        end)

      # Find range of versions around the current version for which the
      # constraint is the same to create an incompatibility based on a
      # larger set of versions for the parent package.
      # This optimization let us skip many versions during conflict resolution.
      lower =
        next_bound(
          Enum.reverse(version_constraints),
          version,
          {constraint, optional},
          _skip? = false
        )

      upper = next_bound(version_constraints, version, {constraint, optional}, _skip? = true)
      lower = if lower == List.first(versions), do: nil, else: lower
      range = %Range{min: lower, max: upper, include_min: !!lower}
      package_range = %PackageRange{name: package, constraint: range}
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

  def next_bound(versions_dependencies, version, constraint, next?) do
    versions_dependencies
    |> skip_to_version(version)
    |> skip_to_constraint(constraint, next?)
  end

  defp skip_to_version([{version, _constraint} | _] = versions_dependencies, version) do
    versions_dependencies
  end

  defp skip_to_version([_ | versions_dependencies], version) do
    skip_to_version(versions_dependencies, version)
  end

  defp skip_to_constraint(
         [{_version, constraint} | {version, _constraint}],
         constraint,
         _skip? = true
       ) do
    version
  end

  defp skip_to_constraint([{_version, constraint}], constraint, _skip? = true) do
    nil
  end

  defp skip_to_constraint([{version, _version_constraint}], _constraint, _skip? = true) do
    version
  end

  defp skip_to_constraint([{version, constraint} | _], constraint, _skip? = false) do
    version
  end

  defp skip_to_constraint([_ | versions_dependencies], constraint, skip?) do
    skip_to_constraint(versions_dependencies, constraint, skip?)
  end
end
