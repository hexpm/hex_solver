defmodule ResolverTest do
  use ExUnit.Case, async: true
  doctest Resolver

  alias Resolver.Constraints.Range
  alias Resolver.Registry.Process, as: Registry

  defp run(locked \\ %{}, overrides \\ []) do
    locked = Map.new(locked, fn {package, version} -> {package, Version.parse!(version)} end)

    case Resolver.run(Registry, locked, MapSet.new(overrides)) do
      {:ok, decisions} ->
        result =
          Map.new(decisions, fn {package, version} ->
            {package, to_string(version)}
          end)

        assert result["$root"] == "1.0.0"
        Map.delete(result, "$root")

      {:error, incompatibility} ->
        assert [term] = incompatibility.terms
        assert term.positive
        assert term.package_range.name == "$root"
        assert term.package_range.constraint == %Range{}

        incompatibility.cause
    end
  end

  describe "run/0 success" do
    test "only root" do
      Registry.put("$root", "1.0.0", [])

      assert run() == %{}
    end

    test "single fixed dep" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0"}])
      Registry.put("foo", "1.0.0", [])

      assert run() == %{"foo" => "1.0.0"}
    end

    test "single loose dep" do
      Registry.put("$root", "1.0.0", [{"foo", "~> 1.0"}])
      Registry.put("foo", "1.1.0", [])

      assert run() == %{"foo" => "1.1.0"}
    end

    test "single loose dep with multiple versions" do
      Registry.put("$root", "1.0.0", [{"foo", "~> 1.0"}])
      Registry.put("foo", "1.1.0", [])
      Registry.put("foo", "1.0.0", [])

      assert run() == %{"foo" => "1.1.0"}
    end

    test "single older dep with multiple versions" do
      Registry.put("$root", "1.0.0", [{"foo", "~> 1.0.0"}])
      Registry.put("foo", "1.1.0", [])
      Registry.put("foo", "1.0.0", [])

      assert run() == %{"foo" => "1.0.0"}
    end

    test "single older dep with dependency and multiple versions" do
      Registry.put("$root", "1.0.0", [{"foo", "~> 1.0.0"}])
      Registry.put("foo", "1.1.0", [])
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.0.0", [])

      assert run() == %{"foo" => "1.0.0", "bar" => "1.0.0"}
    end

    test "two deps" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0"}, {"bar", "2.0.0"}])
      Registry.put("foo", "1.0.0", [])
      Registry.put("bar", "2.0.0", [])

      assert run() == %{"foo" => "1.0.0", "bar" => "2.0.0"}
    end

    test "nested deps" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0"}])
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.0.0", [])

      assert run() == %{"foo" => "1.0.0", "bar" => "1.0.0"}
    end

    test "backtrack 1" do
      Registry.put("$root", "1.0.0", [{"foo", "~> 1.0"}])
      Registry.put("foo", "1.1.0", [{"bar", "1.1.0"}, {"baz", "1.0.0"}])
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.1.0", [{"baz", "1.1.0"}])
      Registry.put("bar", "1.0.0", [{"baz", "1.0.0"}])
      Registry.put("baz", "1.1.0", [])
      Registry.put("baz", "1.0.0", [])

      assert run() == %{"foo" => "1.0.0", "bar" => "1.0.0", "baz" => "1.0.0"}
    end

    test "backtrack 2" do
      Registry.put("$root", "1.0.0", [{"gen_smtp", "~> 1.1.0"}, {"cowboy", "~> 2.7"}])
      Registry.put("cowboy", "2.6.0", [{"ranch", "~> 1.7.0"}])
      Registry.put("cowboy", "2.7.0", [{"ranch", "~> 1.7.1"}])
      Registry.put("cowboy", "2.8.0", [{"ranch", "~> 1.7.1"}])
      Registry.put("cowboy", "2.9.0", [{"ranch", "1.8.0"}])
      Registry.put("gen_smtp", "1.1.1", [{"ranch", ">= 1.7.0"}])
      Registry.put("ranch", "1.8.0", [])
      Registry.put("ranch", "2.1.0", [])

      assert run() == %{"cowboy" => "2.9.0", "gen_smtp" => "1.1.1", "ranch" => "1.8.0"}
    end

    test "loop" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0"}])
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.0.0", [{"foo", "1.0.0"}])

      assert run() == %{"foo" => "1.0.0", "bar" => "1.0.0"}
    end
  end

  describe "run/0 failure" do
    test "missing dependency" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0"}])

      assert {:conflict, incompatibility, _} = run()
      assert [term] = incompatibility.terms
      assert term.package_range.name == "foo"
      assert term.package_range.constraint == %Range{}
      assert incompatibility.cause == :package_not_found
    end

    test "unsatisfied constraint" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0"}])
      Registry.put("foo", "2.0.0", [])

      assert {:conflict, incompatibility, _} = run()
      assert [term] = incompatibility.terms
      assert term.package_range.name == "foo"
      assert term.package_range.constraint == Version.parse!("1.0.0")
      assert incompatibility.cause == :no_versions
    end
  end

  describe "run/0 locked" do
    test "dependency" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0"}])
      Registry.put("foo", "1.0.0", [])

      assert run(%{"foo" => "1.0.0"}) == %{"foo" => "1.0.0"}
    end

    test "conflict" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0"}])
      Registry.put("foo", "1.0.0", [])

      assert {:conflict, incompatibility, _} = run(%{"foo" => "2.0.0"})
      assert [term] = incompatibility.terms
      assert term.package_range.name == "foo"
      assert term.package_range.constraint == Version.parse!("1.0.0")
      assert incompatibility.cause == :no_versions
    end

    test "downgrade" do
      Registry.put("$root", "1.0.0", [{"foo", "~> 1.0"}])
      Registry.put("foo", "1.0.0", [])
      Registry.put("foo", "1.1.0", [])
      Registry.put("foo", "1.2.0", [])

      assert run(%{"foo" => "1.1.0"}) == %{"foo" => "1.1.0"}
    end
  end

  describe "run/0 optional" do
    test "skip single optional" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0", :optional}])
      Registry.put("foo", "1.0.0", [])

      assert run() == %{}
    end

    test "skip locked optional" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0", :optional}])
      Registry.put("foo", "1.0.0", [])

      assert run(%{"foo" => "1.1.0"}) == %{}
    end

    test "skip optional with backtrack" do
      Registry.put("$root", "1.0.0", [{"foo", "~> 1.0"}])
      Registry.put("foo", "1.1.0", [{"bar", "1.1.0"}, {"baz", "1.0.0"}, {"opt", "1.0.0"}])
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}, {"opt", "1.0.0", :optional}])
      Registry.put("bar", "1.1.0", [{"baz", "1.1.0"}, {"opt", "1.0.0"}])
      Registry.put("bar", "1.0.0", [{"baz", "1.0.0"}, {"opt", "1.0.0", :optional}])
      Registry.put("baz", "1.1.0", [{"opt", "1.0.0"}])
      Registry.put("baz", "1.0.0", [{"opt", "1.0.0", :optional}])
      Registry.put("opt", "1.0.0", [])

      assert run() == %{"foo" => "1.0.0", "bar" => "1.0.0", "baz" => "1.0.0"}
    end

    test "select optional" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0", :optional}, {"bar", "1.0.0"}])
      Registry.put("foo", "1.0.0", [])
      Registry.put("bar", "1.0.0", [{"foo", "1.0.0"}])

      assert run() == %{"foo" => "1.0.0", "bar" => "1.0.0"}
    end

    test "select older optional" do
      Registry.put("$root", "1.0.0", [{"foo", "~> 1.0.0", :optional}, {"bar", "1.0.0"}])
      Registry.put("foo", "1.0.0", [])
      Registry.put("foo", "1.1.0", [])
      Registry.put("bar", "1.0.0", [{"foo", "~> 1.0"}])

      assert run() == %{"foo" => "1.0.0", "bar" => "1.0.0"}
    end

    test "select optional with backtrack" do
      Registry.put("$root", "1.0.0", [{"foo", "~> 1.0"}])
      Registry.put("foo", "1.1.0", [{"bar", "1.1.0"}, {"baz", "1.0.0"}, {"opt", "1.0.0"}])
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}, {"opt", "1.0.0", :optional}])
      Registry.put("bar", "1.1.0", [{"baz", "1.1.0"}, {"opt", "1.0.0"}])
      Registry.put("bar", "1.0.0", [{"baz", "1.0.0"}, {"opt", "1.0.0", :optional}])
      Registry.put("baz", "1.1.0", [{"opt", "1.0.0", :optional}])
      Registry.put("baz", "1.0.0", [{"opt", "1.0.0"}])
      Registry.put("opt", "1.0.0", [])

      assert run() == %{"foo" => "1.0.0", "bar" => "1.0.0", "baz" => "1.0.0", "opt" => "1.0.0"}
    end

    test "with conflict" do
      Registry.put("$root", "1.0.0", [{"ex_crypto", ">= 0.0.0"}, {"postgrex", ">= 0.0.0"}])
      Registry.put("poison", "1.0.0", [{"decimal", "~> 2.0", :optional}])
      Registry.put("postgrex", "1.0.0", [{"decimal", "~> 1.0"}])
      Registry.put("ex_crypto", "1.0.0", [{"poison", ">= 1.0.0"}])
      Registry.put("decimal", "1.0.0", [])
      Registry.put("decimal", "2.0.0", [])

      assert {:error, _} = Resolver.run(Registry, %{}, MapSet.new())
    end
  end

  describe "run/0 overrides" do
    test "ignores incompatible constraint" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0"}, {"bar", "1.0.0"}])
      Registry.put("foo", "1.0.0", [{"bar", "2.0.0"}])
      Registry.put("bar", "1.0.0", [])
      Registry.put("bar", "2.0.0", [])

      assert run(%{}, ["bar"]) == %{"foo" => "1.0.0", "bar" => "1.0.0"}
    end

    test "ignores compatible constraint" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0"}, {"bar", "~> 1.0"}])
      Registry.put("foo", "1.0.0", [{"bar", "~> 1.0.0"}])
      Registry.put("bar", "1.0.0", [])
      Registry.put("bar", "1.1.0", [])

      assert run(%{}, ["bar"]) == %{"foo" => "1.0.0", "bar" => "1.1.0"}
    end
  end
end
