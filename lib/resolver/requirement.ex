defmodule Resolver.Requirement do
  alias Resolver.Version
  alias __MODULE__.{Range, Union}

  @allowed_range_ops [:>, :>=, :<, :<=, :~>]

  def parse!(string) do
    string
    |> Elixir.Version.parse_requirement!()
    |> requirement_to_union_of_ranges()
  end

  defp requirement_to_union_of_ranges(requirement) do
    requirement.lexed
    |> Enum.map(fn
      {major, minor, patch, pre, _} -> {major, minor, patch, pre}
      other -> other
    end)
    |> delex(%Union{})
  end

  defp delex([], union) do
    ranges =
      Enum.sort_by(union.ranges, & &1.min, fn
        nil, _version -> true
        _version, nil -> false
        left, right -> Version.compare(left, right) in [:lt, :eq]
      end)

    %{union | ranges: ranges}
  end

  defp delex([:|| | rest], union) do
    delex(rest, union)
  end

  defp delex([op1, version1, :&&, op2, version2 | rest], union) do
    range = to_range(op1, version1, op2, version2)
    delex(rest, %{union | ranges: [range | union.ranges]})
  end

  defp delex([op, version | rest], union) do
    range = to_range(op, version)
    delex(rest, %{union | ranges: [range | union.ranges]})
  end

  defp to_range(:==, version) do
    %Range{min: version, max: version, include_min: true, include_max: true}
  end

  defp to_range(:~>, {major, minor, nil, pre}) do
    %Range{min: {major, minor, 0, pre}, max: {major + 1, 0, 0, [0]}, include_min: true}
  end

  defp to_range(:~>, {major, minor, patch, pre}) do
    %Range{min: {major, minor, patch, pre}, max: {major, minor + 1, 0, [0]}, include_min: true}
  end

  defp to_range(:>, version) do
    %Range{min: version}
  end

  defp to_range(:>=, version) do
    %Range{min: version, include_min: true}
  end

  defp to_range(:<, version) do
    %Range{max: version}
  end

  defp to_range(:<=, version) do
    %Range{max: version, include_max: true}
  end

  defp to_range(op1, version1, :~>, version2) do
    to_range(:~>, version2, op1, version1)
  end

  defp to_range(:~>, version1, op2, version2) do
    range1 = to_range(:~>, version1)
    range2 = to_range(op2, version2)

    true = Range.overlapping?(range1, range2)

    range = %Range{
      min: version_min(range1.min, range2.min),
      max: version_max(range1.max, range2.max),
      include_min: range1.include_min or range2.include_min,
      include_max: range1.include_max or range2.include_max
    }

    true = Range.valid?(range)
    range
  end

  defp to_range(op1, version1, op2, version2)
       when op1 in @allowed_range_ops and op2 in @allowed_range_ops do
    Map.merge(to_range(op1, version1), to_range(op2, version2))
  end

  defp version_min(nil, _right), do: nil
  defp version_min(_left, nil), do: nil
  defp version_min(left, right), do: Version.min(left, right)

  defp version_max(nil, _right), do: nil
  defp version_max(_left, nil), do: nil
  defp version_max(left, right), do: Version.max(left, right)
end
