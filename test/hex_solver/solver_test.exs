defmodule HexSolver.SolverTest do
  use HexSolver.Case, async: true

  alias HexSolver.Constraints.Range
  alias HexSolver.Registry.Process, as: Registry

  defp run(dependencies, locked \\ [], overrides \\ []) do
    run =
      HexSolver.Solver.run(
        Registry,
        to_dependencies(dependencies),
        to_locked(locked),
        overrides
      )

    case run do
      {:ok, decisions} ->
        result =
          Map.new(decisions, fn
            {package, {version, nil}} -> {package, to_string(version)}
            {package, {version, repo}} -> {{repo, package}, to_string(version)}
          end)

        assert result["$root"] == "1.0.0"
        assert not Map.has_key?(result, "$lock") or result["$lock"] == "1.0.0"
        Map.drop(result, ["$root", "$lock"])

      {:error, incompatibility} ->
        assert [term] = incompatibility.terms
        assert term.positive
        assert term.package_range.name == "$root"
        assert term.package_range.constraint == %Range{}

        incompatibility.cause
    end
  end

  describe "run/4 success" do
    test "no dependencies" do
      assert run([]) == %{}
    end

    test "single fixed dep" do
      Registry.put("foo", "1.0.0", [])

      assert run([{"foo", "1.0.0"}]) == %{"foo" => "1.0.0"}
    end

    test "single loose dep" do
      Registry.put("foo", "1.1.0", [])

      assert run([{"foo", "~> 1.0"}]) == %{"foo" => "1.1.0"}
    end

    test "single loose dep with multiple versions" do
      Registry.put("foo", "1.1.0", [])
      Registry.put("foo", "1.0.0", [])

      assert run([{"foo", "~> 1.0"}]) == %{"foo" => "1.1.0"}
    end

    test "single older dep with multiple versions" do
      Registry.put("foo", "1.1.0", [])
      Registry.put("foo", "1.0.0", [])

      assert run([{"foo", "~> 1.0.0"}]) == %{"foo" => "1.0.0"}
    end

    test "single older dep with dependency and multiple versions" do
      Registry.put("foo", "1.1.0", [])
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.0.0", [])

      assert run([{"foo", "~> 1.0.0"}]) == %{"foo" => "1.0.0", "bar" => "1.0.0"}
    end

    test "prioritize stable versions" do
      Registry.put("foo", "1.0.0", [])
      Registry.put("foo", "1.1.0", [])
      Registry.put("foo", "1.2.0-dev", [])

      assert run([{"foo", "~> 1.0"}]) == %{"foo" => "1.1.0"}
    end

    test "two deps" do
      Registry.put("foo", "1.0.0", [])
      Registry.put("bar", "2.0.0", [])

      assert run([{"foo", "1.0.0"}, {"bar", "2.0.0"}]) == %{"foo" => "1.0.0", "bar" => "2.0.0"}
    end

    test "nested deps" do
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.0.0", [])

      assert run([{"foo", "1.0.0"}]) == %{"foo" => "1.0.0", "bar" => "1.0.0"}
    end

    test "backtrack 1" do
      Registry.put("foo", "1.1.0", [{"bar", "1.1.0"}, {"baz", "1.0.0"}])
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.1.0", [{"baz", "1.1.0"}])
      Registry.put("bar", "1.0.0", [{"baz", "1.0.0"}])
      Registry.put("baz", "1.1.0", [])
      Registry.put("baz", "1.0.0", [])

      assert run([{"foo", "~> 1.0"}]) == %{"foo" => "1.0.0", "bar" => "1.0.0", "baz" => "1.0.0"}
    end

    test "backtrack 2" do
      Registry.put("cowboy", "2.6.0", [{"ranch", "~> 1.7.0"}])
      Registry.put("cowboy", "2.7.0", [{"ranch", "~> 1.7.1"}])
      Registry.put("cowboy", "2.8.0", [{"ranch", "~> 1.7.1"}])
      Registry.put("cowboy", "2.9.0", [{"ranch", "1.8.0"}])
      Registry.put("gen_smtp", "1.1.1", [{"ranch", ">= 1.7.0"}])
      Registry.put("ranch", "1.8.0", [])
      Registry.put("ranch", "2.1.0", [])

      assert run([{"gen_smtp", "~> 1.1.0"}, {"cowboy", "~> 2.7"}]) == %{
               "cowboy" => "2.9.0",
               "gen_smtp" => "1.1.1",
               "ranch" => "1.8.0"
             }
    end

    test "backtrack from unsatisfiable dependency" do
      Registry.put("foo", "1.1.0", [{"bar", "< 0.0.0-0"}])
      Registry.put("foo", "1.0.0", [{"bar", "~> 1.0"}])
      Registry.put("bar", "1.0.0", [])

      assert run([{"foo", "~> 1.0"}]) == %{"foo" => "1.0.0", "bar" => "1.0.0"}
    end

    test "overlapping ranges" do
      Registry.put("phoenix_live_view", "1.0.0", [{"phoenix", "~> 1.0 or ~> 2.0"}])
      Registry.put("phoenix_live_view", "1.1.0", [{"phoenix", "~> 2.1"}])
      Registry.put("phoenix", "1.0.0", [])

      assert run([{"phoenix_live_view", "~> 1.0 or ~> 1.1"}]) == %{
               "phoenix_live_view" => "1.0.0",
               "phoenix" => "1.0.0"
             }
    end

    test "loop" do
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.0.0", [{"foo", "1.0.0"}])

      assert run([{"foo", "1.0.0"}]) == %{"foo" => "1.0.0", "bar" => "1.0.0"}
    end

    test "sub dependencies" do
      Registry.put("foo", "1.0.0", [])
      Registry.put("foo", "2.0.0", [])

      assert {:conflict, _, _} =
               run([
                 {"top1", "1.0.0", dependencies: [{"foo", "~> 1.0"}]},
                 {"top2", "1.0.0", dependencies: [{"foo", "~> 2.0"}]}
               ])
    end
  end

  describe "run/4 failure" do
    test "missing dependency" do
      assert {:conflict, incompatibility, _} = run([{"foo", "1.0.0"}])
      assert [term] = incompatibility.terms
      assert term.package_range.name == "foo"
      assert term.package_range.constraint == %Range{}
      assert incompatibility.cause == :package_not_found
    end

    test "unsatisfied constraint" do
      Registry.put("foo", "2.0.0", [])

      assert {:conflict, incompatibility, _} = run([{"foo", "1.0.0"}])
      assert [term] = incompatibility.terms
      assert term.package_range.name == "foo"
      assert term.package_range.constraint == Version.parse!("1.0.0")
      assert incompatibility.cause == :no_versions
    end

    test "unsatisfiable dependency" do
      Registry.put("foo", "1.0.0", [{"bar", "< 0.0.0-0"}])
      Registry.put("bar", "1.0.0", [])

      assert {:conflict, incompatibility, _} = run([{"foo", "1.0.0"}])
      assert [term] = incompatibility.terms
      assert term.package_range.name == "foo"
      assert {:conflict, %{cause: :dependency}, %{cause: :no_versions}} = incompatibility.cause
    end

    test "no matching transient dependency 1" do
      Registry.put("amqp_client", "3.9.4", [{"rabbit_common", "3.9.4"}])
      Registry.put("amqp_client", "3.9.5", [{"rabbit_common", "3.9.5"}])
      Registry.put("amqp_client", "3.9.8", [{"rabbit_common", "3.9.8"}])
      Registry.put("rabbit_common", "3.8.5-rc.2", [])
      Registry.put("rabbit_common", "3.8.5", [])
      Registry.put("rabbit_common", "3.8.14", [])

      assert {:conflict, _, _} = run([{"amqp_client", "~> 3.6"}, {"rabbit_common", "~> 3.6"}])
    end

    test "no matching transient dependency 2" do
      Registry.put("amqp_client", "3.8.10", [{"rabbit_common", "3.8.10"}])
      Registry.put("amqp_client", "3.8.11", [{"rabbit_common", "3.8.11"}])
      Registry.put("amqp_client", "3.8.14", [{"rabbit_common", "3.8.14"}])
      Registry.put("amqp_client", "3.8.25", [{"rabbit_common", "3.8.25"}])
      Registry.put("consul", "1.1.0", [{"jsx", "~> 2.8.0"}])
      Registry.put("jsx", "2.8.3", [])
      Registry.put("rabbit_common", "3.8.14", [{"jsx", "2.11.0"}])
      Registry.put("rabbit_common", "3.8.25", [{"jsx", "3.1.0"}])
      Registry.put("rabbit_common", "3.8.5-rc.2", [{"jsx", "2.9.0"}])
      Registry.put("rabbit_common", "3.8.5", [{"jsx", "2.9.0"}])

      assert {:conflict, _, _} =
               run([
                 {"amqp_client", "~> 3.6"},
                 {"consul", "~> 1.1"},
                 {"rabbit_common", "~> 3.6"}
               ])
    end

    test "no matching transient dependency 3" do
      Registry.put("amqp_client", "3.8.25", [{"rabbit_common", "3.8.25"}])
      Registry.put("rabbit_common", "3.8.12-rc.3", [{"jsx", "2.11.0"}])
      Registry.put("amqp_client", "3.8.21", [{"rabbit_common", "3.8.21"}])
      Registry.put("rabbit_common", "3.8.19", [{"jsx", "3.1.0"}])
      Registry.put("rabbit_common", "3.8.25", [{"jsx", "3.1.0"}])
      Registry.put("amqp", "1.6.0", [{"amqp_client", "~> 3.8.0"}])
      Registry.put("rabbit_common", "3.8.14", [{"jsx", "2.11.0"}])
      Registry.put("amqp_client", "3.9.8", [{"rabbit_common", "3.9.8"}])
      Registry.put("amqp_client", "3.8.5", [{"rabbit_common", "3.8.5"}])

      Registry.put("amqp", "1.3.2", [
        {"amqp_client", "~> 3.7.11"},
        {"jsx", "~> 2.9"},
        {"rabbit_common", "~> 3.7.11"}
      ])

      assert {:conflict, _, _} =
               run([
                 {"amqp", "~> 1.0 or ~> 1.1"},
                 {"amqp_client", "~> 3.7"},
                 {"rabbit_common", "~> 3.7"}
               ])
    end

    test "no matching dependency of locked package with optional dependency on it" do
      Registry.put("c", "0.9.0", [{"a", "1.0.0", optional: true}])
      Registry.put("f", "1.0.0", [])
      Registry.put("f", "1.2.0", [{"a", "~> 1.0.0"}])
      Registry.put("a", "2.0.0", [])
      Registry.put("p", "1.0.0", [{"f", ">= 1.1.0"}])

      assert {:conflict, _, _} = run([{"p", ">= 0.0.0"}, {"c", "~> 0.9"}], [{"f", "1.2.0"}])
    end
  end

  describe "run/4 locked" do
    test "dependency" do
      Registry.put("foo", "1.0.0", [])

      assert run([{"foo", "1.0.0"}], [{"foo", "1.0.0"}]) == %{"foo" => "1.0.0"}
    end

    test "conflict 1" do
      Registry.put("foo", "1.0.0", [])

      assert {:conflict, incompatibility, _} = run([{"foo", "1.0.0"}], [{"foo", "2.0.0"}])
      assert [term] = incompatibility.terms
      assert term.package_range.name == "foo"
      assert term.package_range.constraint == Version.parse!("2.0.0")
      assert {:conflict, _, _} = incompatibility.cause
    end

    test "conflict 2" do
      Registry.put("foo", "1.0.0", [])

      assert {:conflict, incompatibility, _} = run([{"foo", "2.0.0"}], [{"foo", "1.0.0"}])
      assert [term] = incompatibility.terms
      assert term.package_range.name == "foo"
      assert term.package_range.constraint == Version.parse!("2.0.0")
      assert incompatibility.cause == :no_versions
    end

    test "downgrade" do
      Registry.put("foo", "1.0.0", [])
      Registry.put("foo", "1.1.0", [])
      Registry.put("foo", "1.2.0", [])

      assert run([{"foo", "~> 1.0"}], [{"foo", "1.1.0"}]) == %{"foo" => "1.1.0"}
    end

    test "locked package that doesn't exist" do
      Registry.put("foo", "0.9.0", [])
      Registry.put("foo", "2.0.0", [{"bar", "< 1.1.0"}])

      assert run([{"foo", ">= 0.0.0"}], [{"bar", "1.0.0"}]) == %{"foo" => "0.9.0"}
    end

    test "locked version that doesn't exist" do
      Registry.put("b", "0.9.0", [])
      Registry.put("b", "2.0.0", [{"c", "< 1.1.0"}])
      Registry.put("c", "2.0.0", [])

      assert run([{"b", ">= 0.0.0"}], [{"c", "1.0.0"}]) == %{"b" => "0.9.0"}
    end

    test "skip dependency version that requires locked package outside an optional requirement" do
      Registry.put("c", "0.9.0", [{"a", ">= 0.0.0"}, {"b", "> 1.0.0 and < 2.0.0", optional: true}])

      Registry.put("a", "0.9.0", [])
      Registry.put("a", "1.1.0", [{"b", "~> 1.0"}])

      assert run([{"c", ">= 0.0.0"}], [{"b", "1.0.0"}]) == %{"c" => "0.9.0", "a" => "0.9.0"}
    end

    test "skip root dependency version that requires locked package with disjoint optional" do
      Registry.put("c", "1.0.0-rc.1", [])
      Registry.put("c", "1.1.0", [{"a", ">= 0.0.0"}])
      Registry.put("d", "2.0.0", [{"a", "1.0.0", optional: true}])

      assert run([{"c", ">= 0.0.0"}, {"d", "1.1.0 or 2.0.0"}], [{"a", "0.9.0"}]) == %{
               "c" => "1.0.0-rc.1",
               "d" => "2.0.0"
             }
    end

    test "conflict when optional requirement excludes locked version that a sub dependency requires" do
      Registry.put("a", "1.0.0", [{"c", ">= 0.0.0"}])
      Registry.put("b", "1.0.0-rc.1", [])
      Registry.put("b", "1.1.0", [{"c", "1.1.0 or 2.0.0", optional: true}])
      Registry.put("b", "1.2.0", [{"e", "1.1.0 or 2.0.0"}])
      Registry.put("c", "3.0.0", [])
      Registry.put("e", "2.0.0", [{"f", "~> 1.0"}])

      assert {:conflict, _, _} =
               run(
                 [{"p", ">= 0.0.0", dependencies: [{"a", "1.0.0"}]}, {"b", "~> 1.0"}],
                 [{"c", "3.0.0"}, {"f", "2.0.0"}]
               )
    end
  end

  describe "run/4 optional" do
    test "skip single optional" do
      Registry.put("foo", "1.0.0", [])

      assert run([{"foo", "1.0.0", optional: true}]) == %{}
    end

    test "skip locked optional" do
      Registry.put("foo", "1.0.0", [])

      assert run([{"foo", "1.0.0", optional: true}], [{"foo", "1.0.0"}]) == %{}
    end

    test "skip conflicting optionals" do
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}, {"car", "~> 1.0", optional: true}])
      Registry.put("bar", "1.0.0", [{"car", "~> 2.0", optional: true}])
      Registry.put("car", "1.0.0", [])
      Registry.put("car", "2.0.0", [])

      assert run([{"foo", "1.0.0"}], []) == %{
               "foo" => "1.0.0",
               "bar" => "1.0.0"
             }
    end

    test "skip transitive optionals" do
      # car's fuse dependency needs to be a subset of bar's fuse dependency
      # fuse 1.0.0 ⊃ fuse ~> 1.0

      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}, {"car", "1.0.0"}])
      Registry.put("bar", "1.0.0", [{"fuse", "~> 1.0", optional: true}])
      Registry.put("car", "1.0.0", [{"fuse", "1.0.0", optional: true}])
      Registry.put("fuse", "1.0.0", [])

      assert run([{"foo", "1.0.0"}], []) == %{
               "foo" => "1.0.0",
               "bar" => "1.0.0",
               "car" => "1.0.0"
             }
    end

    test "skip conflicting transitive optionals" do
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}, {"car", "1.0.0"}])
      Registry.put("bar", "1.0.0", [{"fuse", "~> 1.0", optional: true}])
      Registry.put("car", "1.0.0", [{"fuse", "~> 2.0", optional: true}])
      Registry.put("fuse", "1.0.0", [])
      Registry.put("fuse", "2.0.0", [])

      assert run([{"foo", "1.0.0"}], []) == %{
               "foo" => "1.0.0",
               "bar" => "1.0.0",
               "car" => "1.0.0"
             }
    end

    test "locked optional does not conflict" do
      Registry.put("foo", "1.0.0", [])

      assert run([{"foo", "1.0.0", optional: true}], [{"foo", "1.1.0"}]) == %{}
    end

    test "skip optional with backtrack" do
      Registry.put("foo", "1.1.0", [{"bar", "1.1.0"}, {"baz", "1.0.0"}, {"opt", "1.0.0"}])
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}, {"opt", "1.0.0", optional: true}])
      Registry.put("bar", "1.1.0", [{"baz", "1.1.0"}, {"opt", "1.0.0"}])
      Registry.put("bar", "1.0.0", [{"baz", "1.0.0"}, {"opt", "1.0.0", optional: true}])
      Registry.put("baz", "1.1.0", [{"opt", "1.0.0"}])
      Registry.put("baz", "1.0.0", [{"opt", "1.0.0", optional: true}])
      Registry.put("opt", "1.0.0", [])

      assert run([{"foo", "~> 1.0"}]) == %{"foo" => "1.0.0", "bar" => "1.0.0", "baz" => "1.0.0"}
    end

    test "skip optional after backtracking a required dependency on it" do
      Registry.put("foo", "1.0.0", [{"bar", "<= 1.0.0"}, {"opt", "~> 1.0", optional: true}])
      Registry.put("bar", "0.9.0", [])
      Registry.put("bar", "1.0.0", [{"opt", "~> 1.0.0-rc.2"}])
      Registry.put("opt", "1.0.0-rc.2", [])

      assert run([{"foo", "1.0.0"}]) == %{"foo" => "1.0.0", "bar" => "0.9.0"}
    end

    test "skip optional with remaining versions after backtracking a required dependency on it" do
      Registry.put("foo", "1.0.0", [{"bar", "<= 1.0.0"}, {"opt", "~> 1.0", optional: true}])
      Registry.put("bar", "0.9.0", [])
      Registry.put("bar", "1.0.0", [{"opt", "~> 1.0.0-rc.2"}])
      Registry.put("opt", "1.0.0-rc.2", [])
      Registry.put("opt", "1.1.0", [])

      assert run([{"foo", "1.0.0"}]) == %{"foo" => "1.0.0", "bar" => "0.9.0"}
    end

    test "skip optional with no matching versions when a sibling requires it" do
      Registry.put("c", "1.1.0", [{"a", "~> 1.0"}, {"d", "~> 1.0", optional: true}])
      Registry.put("a", "1.0.0", [])
      Registry.put("a", "1.1.0", [{"d", "~> 1.0"}])
      Registry.put("d", "0.1.0", [])

      assert run([{"c", ">= 0.0.0"}]) == %{"c" => "1.1.0", "a" => "1.0.0"}
    end

    test "skip optional with no matching versions when a newer version requires it" do
      Registry.put("foo", "1.1.0", [{"bar", "~> 1.0", optional: true}])
      Registry.put("foo", "2.0.0", [{"bar", "~> 1.0"}])
      Registry.put("bar", "0.1.0", [])

      assert run([{"foo", ">= 0.0.0"}]) == %{"foo" => "1.1.0"}
    end

    test "skip sibling version that requires optional outside its requirement" do
      Registry.put("foo", "1.1.0", [{"bar", "~> 1.0", optional: true}])
      Registry.put("foo", "2.0.0", [{"bar", "~> 1.0"}])
      Registry.put("bar", "0.1.0", [])
      Registry.put("bar", "2.0.0", [])
      Registry.put("qux", "0.9.0", [])
      Registry.put("qux", "1.0.0", [{"bar", "~> 2.0"}])

      assert run([{"foo", ">= 0.0.0"}, {"qux", ">= 0.0.0"}]) == %{
               "foo" => "1.1.0",
               "qux" => "0.9.0"
             }
    end

    test "skip sibling version that requires optional with only a prerelease" do
      Registry.put("a", "1.0.0-rc.1", [])
      Registry.put("b", "2.0.0", [{"a", "~> 1.0", optional: true}])
      Registry.put("c", "0.9.0", [])
      Registry.put("c", "1.0.0", [{"a", "< 1.1.0"}])
      Registry.put("c", "2.0.0", [{"a", "~> 1.0"}])

      assert run([{"c", ">= 0.0.0"}, {"b", ">= 1.1.0"}]) == %{"b" => "2.0.0", "c" => "0.9.0"}
    end

    test "skip sibling version that requires optional with no matching versions" do
      Registry.put("a", "1.1.0", [])
      Registry.put("b", "1.0.0", [{"a", "1.0.0", optional: true}])
      Registry.put("d", "1.0.0", [])
      Registry.put("d", "1.1.0", [{"a", "~> 1.0"}])

      assert run([{"b", "~> 1.0.0"}, {"d", "~> 1.0"}]) == %{"b" => "1.0.0", "d" => "1.0.0"}
    end

    test "skip dependency version that requires optional with no matching versions" do
      Registry.put("a", "1.0.0-rc.1", [])
      Registry.put("a", "1.0.0", [{"d", "~> 1.0.0"}])
      Registry.put("b", "1.0.0", [{"a", "< 1.1.0"}, {"d", "1.0.0", optional: true}])
      Registry.put("d", "2.0.0", [])

      assert run([{"b", "1.0.0"}]) == %{"a" => "1.0.0-rc.1", "b" => "1.0.0"}
    end

    test "don't select dependency of a backtracked version that required the optional" do
      Registry.put("c", "0.9.0", [{"b", "> 1.0.0 and < 2.0.0", optional: true}])
      Registry.put("c", "2.0.0", [{"b", "~> 1.0"}])
      Registry.put("b", "1.0.0", [{"d", "~> 1.0"}])
      Registry.put("d", "1.0.0", [{"c", "< 1.1.0"}])

      assert run([{"c", ">= 0.0.0"}]) == %{"c" => "0.9.0"}
    end

    test "skip sibling version that requires a package with disjoint optional dependencies" do
      Registry.put("bar", "1.0.0", [{"fuse", "~> 1.0", optional: true}])
      Registry.put("car", "1.0.0", [{"fuse", "~> 2.0", optional: true}])
      Registry.put("qux", "0.9.0", [])
      Registry.put("qux", "1.0.0", [{"fuse", ">= 0.0.0"}])
      Registry.put("fuse", "1.0.0", [])
      Registry.put("fuse", "2.0.0", [])

      assert run([{"bar", "1.0.0"}, {"car", "1.0.0"}, {"qux", ">= 0.0.0"}]) == %{
               "bar" => "1.0.0",
               "car" => "1.0.0",
               "qux" => "0.9.0"
             }
    end

    test "don't select optional after backtracking the version that required it" do
      Registry.put("a", "0.9.0", [])
      Registry.put("a", "1.2.0", [])
      Registry.put("b", "2.0.0", [{"f", ">= 0.0.0"}])
      Registry.put("e", "1.1.0", [])
      Registry.put("e", "2.0.0", [{"a", "< 1.1.0"}])
      Registry.put("f", "1.0.0-rc.1", [{"a", "~> 1.0", optional: true}])
      Registry.put("f", "3.0.0", [{"a", "~> 1.0.0-rc.1"}])

      assert run([{"b", "1.1.0 or 2.0.0"}, {"e", ">= 1.1.0"}]) == %{
               "b" => "2.0.0",
               "e" => "1.1.0",
               "f" => "1.0.0-rc.1"
             }
    end

    test "select optional" do
      Registry.put("foo", "1.0.0", [])
      Registry.put("bar", "1.0.0", [{"foo", "1.0.0"}])

      assert run([{"foo", "1.0.0", optional: true}, {"bar", "1.0.0"}]) == %{
               "foo" => "1.0.0",
               "bar" => "1.0.0"
             }
    end

    test "select older optional" do
      Registry.put("foo", "1.0.0", [])
      Registry.put("foo", "1.1.0", [])
      Registry.put("bar", "1.0.0", [{"foo", "~> 1.0"}])

      assert run([{"foo", "~> 1.0.0", optional: true}, {"bar", "1.0.0"}]) == %{
               "foo" => "1.0.0",
               "bar" => "1.0.0"
             }
    end

    test "select optional with backtrack" do
      Registry.put("foo", "1.1.0", [{"bar", "1.1.0"}, {"baz", "1.0.0"}, {"opt", "1.0.0"}])
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}, {"opt", "1.0.0", optional: true}])
      Registry.put("bar", "1.1.0", [{"baz", "1.1.0"}, {"opt", "1.0.0"}])
      Registry.put("bar", "1.0.0", [{"baz", "1.0.0"}, {"opt", "1.0.0", optional: true}])
      Registry.put("baz", "1.1.0", [{"opt", "1.0.0", optional: true}])
      Registry.put("baz", "1.0.0", [{"opt", "1.0.0"}])
      Registry.put("opt", "1.0.0", [])

      assert run([{"foo", "~> 1.0"}]) == %{
               "foo" => "1.0.0",
               "bar" => "1.0.0",
               "baz" => "1.0.0",
               "opt" => "1.0.0"
             }
    end

    test "with conflict" do
      Registry.put("poison", "1.0.0", [{"decimal", "~> 2.0", optional: true}])
      Registry.put("postgrex", "1.0.0", [{"decimal", "~> 1.0"}])
      Registry.put("ex_crypto", "1.0.0", [{"poison", ">= 1.0.0"}])
      Registry.put("decimal", "1.0.0", [])
      Registry.put("decimal", "2.0.0", [])

      assert {:conflict, _, _} = run([{"ex_crypto", ">= 0.0.0"}, {"postgrex", ">= 0.0.0"}])
    end
  end

  describe "run/4 overrides" do
    test "ignores incompatible constraint" do
      Registry.put("foo", "1.0.0", [{"bar", "2.0.0"}])
      Registry.put("bar", "1.0.0", [])
      Registry.put("bar", "2.0.0", [])

      assert run([{"foo", "1.0.0"}, {"bar", "1.0.0"}], [], ["bar"]) == %{
               "foo" => "1.0.0",
               "bar" => "1.0.0"
             }
    end

    test "ignores compatible constraint" do
      Registry.put("foo", "1.0.0", [{"bar", "~> 1.0.0"}])
      Registry.put("bar", "1.0.0", [])
      Registry.put("bar", "1.1.0", [])

      assert run([{"foo", "1.0.0"}, {"bar", "~> 1.0"}], [], ["bar"]) == %{
               "foo" => "1.0.0",
               "bar" => "1.1.0"
             }
    end

    test "skips overridden dependency outside of the root" do
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.0.0", [{"baz", "1.0.0"}])
      Registry.put("baz", "1.0.0", [])

      assert run([{"foo", "1.0.0"}], [], ["baz"]) == %{
               "foo" => "1.0.0",
               "bar" => "1.0.0"
             }
    end

    test "don't skip overridden dependency outside of the root when label doesn't match" do
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.0.0", [{"baz", "1.0.0", label: "not-baz"}])
      Registry.put("baz", "1.0.0", [])

      assert run([{"foo", "1.0.0"}], [], ["baz"]) == %{
               "foo" => "1.0.0",
               "bar" => "1.0.0",
               "baz" => "1.0.0"
             }
    end

    test "overridden dependencies does not unlock" do
      Registry.put("foo", "1.0.0", [])
      Registry.put("foo", "1.1.0", [])

      assert run([{"foo", "~> 1.0"}], [{"foo", "1.0.0"}], ["foo"]) == %{"foo" => "1.0.0"}
    end
  end

  describe "run/4 repo" do
    test "success" do
      Registry.put("foo", "1.0.0", [{"baz", "1.0.0", repo: "a"}])
      Registry.put("bar", "1.0.0", [{"baz", "1.0.0", repo: "a"}])
      Registry.put("a", "baz", "1.0.0", [])

      assert run([{"foo", "1.0.0"}, {"bar", "1.0.0"}]) == %{
               "foo" => "1.0.0",
               "bar" => "1.0.0",
               {"a", "baz"} => "1.0.0"
             }
    end

    test "conflict" do
      Registry.put("foo", "1.0.0", [{"baz", "1.0.0", repo: "a"}])
      Registry.put("bar", "1.0.0", [{"baz", "1.0.0", repo: "b"}])
      Registry.put("a", "baz", "1.0.0", [])
      Registry.put("b", "baz", "1.0.0", [])

      assert {:conflict, incompatibility, _} = run([{"foo", "1.0.0"}, {"bar", "1.0.0"}])

      assert [term] = incompatibility.terms
      assert term.package_range.name == "foo"
    end

    test "versions depending on the same constraint from different repos" do
      Registry.put("foo", "1.0.0", [{"baz", "1.0.0", repo: "b"}])
      Registry.put("foo", "1.1.0", [{"baz", "1.0.0", repo: "a"}])
      Registry.put("bar", "1.0.0", [{"baz", "1.0.0", repo: "b"}])
      Registry.put("a", "baz", "1.0.0", [])
      Registry.put("b", "baz", "1.0.0", [])

      assert run([{"foo", "~> 1.0"}, {"bar", "1.0.0"}]) == %{
               "foo" => "1.0.0",
               "bar" => "1.0.0",
               {"b", "baz"} => "1.0.0"
             }
    end

    test "dependency on the same package from another repo" do
      Registry.put("x", "d", "1.1.0", [{"a", "~> 1.0", repo: nil}])
      Registry.put("a", "1.1.0", [{"d", "< 1.1.0", repo: nil}])

      assert {:conflict, _, _} = run([{"d", ">= 1.1.0", repo: "x"}])
    end

    test "optional dependency on the same package as a locked package from another repo" do
      Registry.put("b", "2.0.0", [{"c", "1.1.0 or 2.0.0", repo: "x"}])
      Registry.put("x", "c", "1.1.0", [{"d", "< 1.1.0", repo: "x"}])
      Registry.put("x", "d", "1.0.0", [{"a", "1.1.0 or 2.0.0", repo: nil}])
      Registry.put("a", "1.1.0", [{"c", ">= 0.0.0", optional: true}])

      assert {:conflict, _, _} = run([{"b", ">= 1.1.0"}], [{"c", "1.1.0", repo: "x"}])
    end

    test "optional dependencies on the same package from different repos" do
      Registry.put("d", "2.0.0", [{"b", "~> 2.0"}, {"c", "1.1.0 or 2.0.0", optional: true}])
      Registry.put("b", "2.0.0", [{"a", "~> 2.0"}, {"c", ">= 1.1.0", repo: "x", optional: true}])
      Registry.put("a", "2.0.0", [{"c", ">= 1.1.0"}])

      assert {:conflict, _, _} = run([{"d", ">= 0.0.0"}])
    end

    test "optional dependencies on the same package from different repos and a requirement from a third repo" do
      Registry.put("d", "2.0.0", [{"b", "~> 2.0"}, {"c", "1.1.0 or 2.0.0", optional: true}])
      Registry.put("b", "2.0.0", [{"a", "~> 2.0"}, {"c", ">= 1.1.0", repo: "x", optional: true}])
      Registry.put("a", "2.1.0", [{"c", ">= 1.1.0"}])
      Registry.put("a", "2.0.0", [{"c", ">= 1.1.0", repo: "y"}])

      assert {:conflict, _, _} = run([{"d", ">= 0.0.0"}])
    end

    test "locked package and a dependency on the same package from another repo" do
      Registry.put("x", "d", "0.9.0", [])
      Registry.put("x", "d", "1.0.0", [{"c", "~> 2.0", repo: nil}])
      Registry.put("x", "d", "1.1.0", [{"c", "~> 1.0", repo: "x"}])
      Registry.put("x", "c", "1.0.0", [])

      assert run([{"d", ">= 0.0.0", repo: "x"}], [{"c", "2.0.0"}]) == %{{"x", "d"} => "0.9.0"}
    end

    test "optional dependency on a missing version of a package required from the same repo" do
      Registry.put("b", "1.1.0", [{"d", "1.0.0", repo: "x", optional: true}])
      Registry.put("b", "2.0.0", [{"d", "1.0.0", repo: nil}])
      Registry.put("x", "d", "1.1.0", [])

      assert {:conflict, _, _} = run([{"b", ">= 1.1.0"}, {"d", "~> 1.0", repo: "x"}])
    end
  end
end
