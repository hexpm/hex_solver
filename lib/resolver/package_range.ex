defmodule Resolver.PackageRange do
  alias Resolver.PackageRange
  alias Resolver.Constraints.Range

  defstruct name: nil,
            constraint: nil

  def to_string(%PackageRange{name: name, constraint: constraint}) do
    "#{name}#{constraint(constraint)}"
  end

  defp constraint(%Range{min: nil, max: nil}), do: ""
  defp constraint(constraint), do: " #{constraint}"

  defimpl String.Chars do
    defdelegate to_string(package_range), to: Resolver.PackageRange
  end

  defimpl Inspect do
    def inspect(%{name: name, constraint: constraint}, _opts) do
      "#PackageRange<#{name} #{constraint}>"
    end
  end
end
