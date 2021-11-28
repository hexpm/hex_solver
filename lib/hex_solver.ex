defmodule HexSolver do
  alias HexSolver.{Failure, Solver}

  def run(registry, dependencies, locked, overrides) do
    case Solver.run(registry, dependencies, locked, overrides) do
      {:ok, solution} -> {:ok, solution}
      {:error, incompatibility} -> {:error, Failure.write(incompatibility)}
    end
  end
end
