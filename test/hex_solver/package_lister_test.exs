defmodule HexSolver.PackageListerTest do
  use HexSolver.Case, async: true

  alias HexSolver.{PackageLister, PackageRange}
  alias HexSolver.Registry.Process, as: Registry

  defmodule CountingRegistry do
    @behaviour HexSolver.Registry

    alias HexSolver.Registry.Process, as: Registry

    def versions(repo, package) do
      count({:versions, repo, package})
      Registry.versions(repo, package)
    end

    def dependencies(repo, package, version) do
      count({:dependencies, repo, package, to_string(version)})
      Registry.dependencies(repo, package, version)
    end

    defdelegate prefetch(packages), to: Registry

    def calls(), do: Process.get({__MODULE__, :calls}, %{})

    defp count(call) do
      Process.put({__MODULE__, :calls}, Map.update(calls(), call, 1, &(&1 + 1)))
    end
  end

  describe "pick_package/2" do
    test "fetches the versions of each package once" do
      Registry.put("foo", "1.0.0", [])
      Registry.put("foo", "1.1.0", [])
      Registry.prefetch([{nil, "foo"}])

      lister = PackageLister.new(CountingRegistry, [], [], [])

      package_range = %PackageRange{
        name: "foo",
        constraint: HexSolver.Requirement.to_constraint!("~> 1.0")
      }

      assert {:ok, lister, ^package_range, version} =
               PackageLister.pick_package(lister, [package_range])

      assert version == v("1.1.0")

      package_range = %PackageRange{
        name: "foo",
        constraint: HexSolver.Requirement.to_constraint!("1.0.0")
      }

      assert {:ok, _lister, ^package_range, version} =
               PackageLister.pick_package(lister, [package_range])

      assert version == v("1.0.0")
      assert CountingRegistry.calls() == %{{:versions, nil, "foo"} => 1}
    end
  end

  describe "dependencies_as_incompatibilities/4" do
    test "skips dependencies already returned for the version" do
      Registry.put("foo", "1.0.0", [{"bar", "~> 1.0"}])
      Registry.put("foo", "2.0.0", [{"bar", "~> 1.0"}])
      Registry.put("bar", "1.0.0", [])
      Registry.prefetch([{nil, "foo"}])

      lister = %PackageLister{registry: Registry}

      assert {lister, [incompatibility]} =
               PackageLister.dependencies_as_incompatibilities(lister, nil, "foo", v("2.0.0"))

      assert to_string(incompatibility) ==
               ~s(every version of "foo" depends on "bar ~> 1.0")

      assert {_lister, []} =
               PackageLister.dependencies_as_incompatibilities(lister, nil, "foo", v("1.0.0"))
    end

    test "returns dependencies again for a package with the same name in another repo" do
      Registry.put("foo", "1.0.0", [{"bar", "~> 1.0"}])
      Registry.put("repo", "foo", "1.0.0", [{"bar", "~> 1.0"}])
      Registry.put("bar", "1.0.0", [])
      Registry.prefetch([{nil, "foo"}, {"repo", "foo"}])

      lister = %PackageLister{registry: Registry}

      assert {lister, [_incompatibility]} =
               PackageLister.dependencies_as_incompatibilities(lister, nil, "foo", v("1.0.0"))

      assert {_lister, [_incompatibility]} =
               PackageLister.dependencies_as_incompatibilities(lister, "repo", "foo", v("1.0.0"))
    end
  end
end
