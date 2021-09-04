defmodule Resolver.Constraint.Version do
  import Kernel, except: [match?: 2]

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
end
