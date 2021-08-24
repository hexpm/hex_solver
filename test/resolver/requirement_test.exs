defmodule Resolver.VersionTest do
  use Resolver.Case, async: true
  use ExUnitProperties

  alias Resolver.Requirement
  alias Resolver.Requirement.Union

  describe "parse!/" do
    property "always parses" do
      check all(requirement <- requirements()) do
        assert %Union{} = Requirement.parse!(requirement.source)
      end
    end
  end
end
