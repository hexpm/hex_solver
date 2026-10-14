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

    test "picks the package with the fewest allowed versions, the first by name on a tie" do
      for package <- ["foo", "bar", "baz"], version <- ["1.0.0", "1.1.0"] do
        Registry.put(package, version, [])
      end

      Registry.put("baz", "1.2.0", [])
      Registry.prefetch([{nil, "foo"}, {nil, "bar"}, {nil, "baz"}])

      lister = PackageLister.new(Registry, [], [], [])
      foo = package_range("foo", "~> 1.0")
      bar = package_range("bar", "~> 1.0")
      baz = package_range("baz", "~> 1.0")

      assert {:ok, lister, ^bar, version} = PackageLister.pick_package(lister, [foo, baz, bar])
      assert version == v("1.1.0")

      foo = package_range("foo", "1.0.0")

      assert {:ok, _lister, ^foo, version} = PackageLister.pick_package(lister, [baz, bar, foo])
      assert version == v("1.0.0")
    end

    test "reuses the candidates of a package range" do
      Registry.put("foo", "1.0.0", [])
      Registry.put("foo", "1.1.0", [])
      Registry.put("repo", "foo", "2.0.0", [])
      Registry.prefetch([{nil, "foo"}, {"repo", "foo"}])

      lister = PackageLister.new(Registry, [], [], [])
      foo = package_range("foo", "~> 1.0")

      assert {:ok, lister, ^foo, version} = PackageLister.pick_package(lister, [foo])
      assert version == v("1.1.0")
      assert lister.candidates == %{{nil, "foo", foo.constraint} => {:ok, 2, v("1.1.0")}}

      cached = %{lister | candidates: %{{nil, "foo", foo.constraint} => {:ok, 1, v("1.0.0")}}}
      assert {:ok, _lister, ^foo, version} = PackageLister.pick_package(cached, [foo])
      assert version == v("1.0.0")

      repo_foo = package_range("repo", "foo", ">= 0.0.0")
      assert {:ok, _lister, ^repo_foo, version} = PackageLister.pick_package(lister, [repo_foo])
      assert version == v("2.0.0")
    end

    test "returns the first package by name without versions after cached candidates" do
      Registry.put("foo", "1.0.0", [])
      Registry.prefetch([{nil, "foo"}, {nil, "bar"}, {nil, "baz"}])

      lister = PackageLister.new(Registry, [], [], [])
      foo = package_range("foo", "~> 1.0")
      bar = package_range("bar", "~> 1.0")
      baz = package_range("baz", "~> 1.0")

      assert {:ok, lister, ^foo, _version} = PackageLister.pick_package(lister, [foo])
      assert {:error, lister, ^bar} = PackageLister.pick_package(lister, [foo, baz, bar])
      assert {:error, _lister, ^baz} = PackageLister.pick_package(lister, [foo, baz])
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

    test "loads the dependencies of versions only as far as the constraint is the same" do
      Registry.put("foo", "0.1.0", [{"bar", "~> 0.1"}])
      Registry.put("foo", "1.0.0", [{"bar", "~> 1.0"}])
      Registry.put("foo", "2.0.0", [{"bar", "~> 2.0"}])
      Registry.put("foo", "3.0.0", [{"bar", "~> 2.0"}])
      Registry.put("foo", "4.0.0", [{"bar", "~> 2.0"}])
      Registry.put("foo", "5.0.0", [{"bar", "~> 3.0"}])
      Registry.put("foo", "6.0.0", [{"bar", "~> 3.0"}])
      Registry.prefetch([{nil, "foo"}])

      lister = PackageLister.new(CountingRegistry, [], [], [])

      assert {_lister, [incompatibility]} =
               PackageLister.dependencies_as_incompatibilities(lister, nil, "foo", v("3.0.0"))

      assert to_string(incompatibility) == ~s("foo >= 2.0.0 and < 5.0.0" depends on "bar ~> 2.0")

      loaded =
        for {{:dependencies, nil, "foo", version}, 1} <- CountingRegistry.calls(),
            do: version

      assert Enum.sort(loaded) == ["1.0.0", "2.0.0", "3.0.0", "4.0.0", "5.0.0"]
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

  defp package_range(repo \\ nil, name, requirement) do
    %PackageRange{
      repo: repo,
      name: name,
      constraint: HexSolver.Requirement.to_constraint!(requirement)
    }
  end
end
