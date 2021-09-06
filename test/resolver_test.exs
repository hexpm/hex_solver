defmodule ResolverTest do
  use ExUnit.Case, async: true
  doctest Resolver

  test "run/0" do
    assert Resolver.run().solution.decisions == %{"$root" => Version.parse!("1.0.0")}
  end
end
