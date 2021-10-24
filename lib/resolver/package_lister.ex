defmodule Resolver.PackageLister do
  alias Resolver.{Incompatibility, PackageRange, Term}
  alias Resolver.Constraints.Util

  # NOTE: Much of this can be cached
  # TODO: Don't return incompatibilities we already returned
  #       https://github.com/dart-lang/pub/blob/master/lib/src/solver/package_lister.dart#L255-L259
  def dependencies_as_incompatibilities(registry, package, version) do
    {:ok, versions} = registry.versions(package)

    versions_dependencies =
      Map.new(versions, fn version ->
        {:ok, dependencies} = registry.dependencies(package, version)
        {version, Map.new(dependencies)}
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
      # TODO: Remove bounds if there are none
      lower = next_bound(Enum.reverse(versions_constraint), version, constraint)
      upper = next_bound(versions_constraint, version, constraint)

      package_range = %PackageRange{name: package, constraint: Util.from_bounds(lower, upper)}
      dependency_range = %PackageRange{name: dependency, constraint: constraint}
      package_term = %Term{positive: true, package_range: package_range}
      dependency_term = %Term{positive: false, package_range: dependency_range}
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
