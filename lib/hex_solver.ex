defmodule HexSolver do
  @moduledoc """
  A version solver.
  """

  @type dependency() :: {package(), constraint(), optional()}
  @type locked() :: {package(), Version.t()}
  @type package() :: String.t()
  @type optional() :: boolean()
  @opaque constraint() :: HexSolver.Requirement.t()

  alias HexSolver.{Failure, Requirement, Solver}

  @doc """
  Runs the version solver.

  Takes a `HexSolver.Registry` implementation, a list of root dependencies, a list of locked
  package versions, and a list of packages that are overridden by the root dependencies.

  Returns a map of packages and their selected versions or an human readable explanation of
  why a solution could not be found.
  """
  @spec run(module(), [dependency()], [locked()], [package()]) ::
          {:ok, %{package() => Version.t()}} | {:error, String.t()}
  def run(registry, dependencies, locked, overrides) do
    case Solver.run(registry, dependencies, locked, overrides) do
      {:ok, solution} -> {:ok, Map.drop(solution, ["$root", "$lock"])}
      {:error, incompatibility} -> {:error, Failure.write(incompatibility)}
    end
  end

  @doc """
  Parses or converts a SemVer version or Elixir version requirement to an internal solver constraint
  that can be returned by the `HexSolver.Registry` or passed to `HexSolver.run/4`.
  """
  @spec parse_constraint(String.t() | Version.t() | Version.Requirement.t()) ::
          {:ok, constraint()} | :error
  def parse_constraint(string) do
    Requirement.to_constraint(string)
  end

  @doc """
  Parses or converts a SemVer version or Elixir version requirement to an internal solver constraint
  that can be returned by the `HexSolver.Registry` or passed to `HexSolver.run/4`.
  """
  @spec parse_constraint!(String.t() | Version.t() | Version.Requirement.t()) :: constraint()
  def parse_constraint!(string) do
    Requirement.to_constraint!(string)
  end
end
