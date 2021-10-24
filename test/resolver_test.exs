defmodule ResolverTest do
  use ExUnit.Case, async: true
  doctest Resolver

  alias Resolver.Constraints.Range
  alias Resolver.Registry.Process, as: Registry

  defp run() do
    case Resolver.run(Registry) do
      {:ok, decisions} ->
        Map.new(decisions, fn {package, version} ->
          {package, to_string(version)}
        end)

      {:error, incompatibility} ->
        assert [term] = incompatibility.terms
        assert term.positive
        assert term.package_range.name == "$root"
        assert term.package_range.constraint == Version.parse!("1.0.0")

        incompatibility.cause
    end
  end

  describe "run/0 success" do
    test "only root" do
      Registry.put("$root", "1.0.0", [])
      assert run() == %{"$root" => "1.0.0"}
    end

    test "single fixed dep" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0"}])
      Registry.put("foo", "1.0.0", [])
      assert run() == %{"$root" => "1.0.0", "foo" => "1.0.0"}
    end

    test "single loose dep" do
      Registry.put("$root", "1.0.0", [{"foo", "~> 1.0"}])
      Registry.put("foo", "1.1.0", [])
      assert run() == %{"$root" => "1.0.0", "foo" => "1.1.0"}
    end

    test "single loose dep with multiple versions" do
      Registry.put("$root", "1.0.0", [{"foo", "~> 1.0"}])
      Registry.put("foo", "1.1.0", [])
      Registry.put("foo", "1.0.0", [])
      assert run() == %{"$root" => "1.0.0", "foo" => "1.1.0"}
    end

    test "single older dep with multiple versions" do
      Registry.put("$root", "1.0.0", [{"foo", "~> 1.0.0"}])
      Registry.put("foo", "1.1.0", [])
      Registry.put("foo", "1.0.0", [])
      assert run() == %{"$root" => "1.0.0", "foo" => "1.0.0"}
    end

    test "single older dep with dependency and multiple versions" do
      Registry.put("$root", "1.0.0", [{"foo", "~> 1.0.0"}])
      Registry.put("foo", "1.1.0", [])
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.0.0", [])
      assert run() == %{"$root" => "1.0.0", "foo" => "1.0.0", "bar" => "1.0.0"}
    end

    test "two deps" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0"}, {"bar", "2.0.0"}])
      Registry.put("foo", "1.0.0", [])
      Registry.put("bar", "2.0.0", [])
      assert run() == %{"$root" => "1.0.0", "foo" => "1.0.0", "bar" => "2.0.0"}
    end

    test "nested deps" do
      Registry.put("$root", "1.0.0", [{"foo", "1.0.0"}])
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.0.0", [])
      assert run() == %{"$root" => "1.0.0", "foo" => "1.0.0", "bar" => "1.0.0"}
    end

    test "backtrack" do
      Registry.put("$root", "1.0.0", [{"foo", "~> 1.0"}])
      Registry.put("foo", "1.1.0", [{"bar", "1.1.0"}, {"baz", "1.0.0"}])
      Registry.put("foo", "1.0.0", [{"bar", "1.0.0"}])
      Registry.put("bar", "1.1.0", [{"baz", "1.1.0"}])
      Registry.put("bar", "1.0.0", [{"baz", "1.0.0"}])
      Registry.put("baz", "1.1.0", [])
      Registry.put("baz", "1.0.0", [])
      assert run() == %{"$root" => "1.0.0", "foo" => "1.0.0", "bar" => "1.0.0", "baz" => "1.0.0"}
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
end
