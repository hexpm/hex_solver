defmodule ResolverTest do
  use ExUnit.Case, async: true
  doctest Resolver

  alias Resolver.Registry.Process, as: Registry

  defp run() do
    Map.new(Resolver.run(Registry).solution.decisions, fn {package, version} ->
      {package, to_string(version)}
    end)
  end

  describe "run/0" do
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
  end
end
