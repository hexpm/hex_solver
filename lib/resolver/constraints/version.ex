defmodule Resolver.Constraints.Version do
  import Kernel, except: [match?: 2]

  alias Resolver.Constraint

  def any?(%Version{}), do: false
  def empty?(%Version{}), do: false

  def allows?(%Version{} = left, %Version{} = right) do
    compare(left, right) == :eq
  end

  def allows_any?(%Version{} = left, right) do
    Constraint.allows?(right, left)
  end

  def allows_all?(%Version{} = left, right) do
    Constraint.empty?(right) or compare(left, right) == :eq
  end

  def parse!(string) do
    Version.parse!(string)
  end

  def to_string(version) do
    String.Chars.to_string(version)
  end

  def compare(left, right) do
    Version.compare(left, right)
  end

  def match?(version, requirement) do
    Version.match?(version, requirement)
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

  defimpl Resolver.Constraint, for: [Version] do
    alias Resolver.Constraints.Version, as: V

    defdelegate any?(constraint), to: V
    defdelegate empty?(constraint), to: V
    defdelegate allows?(constraint, version), to: V
    defdelegate allows_any?(left, right), to: V
    defdelegate allows_all?(left, right), to: V
    defdelegate compare(left, right), to: V
  end
end
