defmodule Resolver.Version do
  import Kernel, except: [match?: 2]

  def parse!(string) do
    Version.parse!(string)
  end

  def to_string(version) do
    String.Chars.to_string(to_version(version))
  end

  def compare(left, right) do
    Version.compare(to_version(left), to_version(right))
  end

  def match?(version, requirement) do
    Version.match?(to_version(version), requirement)
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

  defp to_version(%Version{} = version), do: version

  defp to_version({major, minor, patch, pre}),
    do: %Version{major: major, minor: minor, patch: patch, pre: pre}
end
