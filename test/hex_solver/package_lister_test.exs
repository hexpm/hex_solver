defmodule HexSolver.PackageListerTest do
  use HexSolver.Case, async: true

  alias HexSolver.PackageLister
  alias HexSolver.Registry.Process, as: Registry

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
