defmodule Resolver.PackageRange do
  defstruct name: nil,
            constraint: nil

  defimpl String.Chars do
    def to_string(%{name: name, constraint: constraint}) do
      "#{name} #{constraint}"
    end
  end

  defimpl Inspect do
    def inspect(%{name: name, constraint: constraint}, _opts) do
      "#PackageRange<#{name} #{constraint}>"
    end
  end
end
