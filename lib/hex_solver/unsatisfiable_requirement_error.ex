defmodule HexSolver.UnsatisfiableRequirementError do
  @moduledoc """
  Raised when a version requirement is valid but no version can satisfy it
  because two of its intersected ranges are disjoint.
  """

  defexception [:requirement, :left, :right]

  @impl true
  def message(%__MODULE__{requirement: requirement, left: left, right: right}) do
    "requirement #{inspect(requirement)} is unsatisfiable because " <>
      "#{inspect(left)} and #{inspect(right)} are disjoint"
  end
end
