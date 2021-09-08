defmodule Resolver.Constraints.Version do
  use Resolver.Constraints.Impl, for: Version

  import Kernel, except: [match?: 2]

  alias Resolver.Constraint
  alias Resolver.Constraints.{Empty, Range, Union}

  def any?(%Version{}), do: false

  def empty?(%Version{}), do: false

  def allows?(%Version{} = left, %Version{} = right) do
    compare(left, right) == :eq
  end

  def allows_any?(%Version{} = left, right) do
    Constraint.allows?(right, left)
  end

  def allows_all?(%Version{}, %Empty{}) do
    true
  end

  def allows_all?(%Version{} = left, %Version{} = right) do
    compare(left, right) == :eq
  end

  def allows_all?(%Version{} = version, %Range{min: min, max: max, include_min: true, include_max: true}) do
    compare(version, min) == :eq and compare(version, max) == :eq
  end

  def allows_all?(%Version{}, %Range{}) do
    false
  end

  def allows_all?(%Version{} = version, %Union{ranges: ranges}) do
    Enum.all?(ranges, &allows_all?(version, &1))
  end

  def compare(left, right) do
    Version.compare(left, right)
  end

  def min(left, right) do
    case compare(left, right) do
      :lt -> left
      :eq -> left
      :gt -> right
    end
  end

  def max(left, right) do
    case compare(left, right) do
      :lt -> right
      :eq -> left
      :gt -> left
    end
  end

  def to_range(%Version{} = version) do
    %Range{min: version, max: version, include_min: true, include_max: true}
  end

  def to_range(%Range{} = range) do
    range
  end
end
