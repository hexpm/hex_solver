defmodule Resolver do
  alias Resolver.{Failure, Resolver}

  def run(registry, dependencies, locked, overrides) do
    case Resolver.run(registry, dependencies, locked, overrides) do
      {:ok, solution} -> {:ok, solution}
      {:error, incompatibility} -> {:error, Failure.write(incompatibility)}
    end
  end
end
