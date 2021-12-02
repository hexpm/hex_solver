defmodule HexSolver.Requirement do
  @moduledoc false

  alias HexSolver.Constraints.{Range, Util, Version}

  @allowed_range_ops [:>, :>=, :<, :<=, :~>]

  def to_constraint(string) when is_binary(string) do
    case Elixir.Version.parse_requirement(string) do
      {:ok, requirement} -> to_constraint(requirement)
      :error -> :error
    end
  end

  def to_constraint(%Elixir.Version{} = version) do
    {:ok, version}
  end

  # TODO: Vendor requirement lexing
  def to_constraint(%Elixir.Version.Requirement{} = requirement) do
    {:ok,
     requirement.lexed
     |> Enum.map(fn
       {major, minor, patch, pre, _} -> {major, minor, patch, pre}
       other -> other
     end)
     |> delex([])}
  end

  def to_constraint!(string) when is_binary(string) do
    string
    |> Elixir.Version.parse_requirement!()
    |> to_constraint!()
  end

  def to_constraint!(%Elixir.Version{} = version) do
    %{version | build: nil}
  end

  def to_constraint!(%Elixir.Version.Requirement{} = requirement) do
    {:ok, constraint} = to_constraint(requirement)
    constraint
  end

  defp delex([], acc) do
    Util.union(acc)
  end

  defp delex([op | rest], acc) when op in [:||, :or] do
    delex(rest, acc)
  end

  defp delex([op1, version1, op, op2, version2 | rest], acc) when op in [:&&, :and] do
    range = to_range(op1, version1, op2, version2)
    delex(rest, [range | acc])
  end

  defp delex([op, version | rest], acc) do
    range = to_range(op, version)
    delex(rest, [range | acc])
  end

  defp to_range(:==, version) do
    to_version(version)
  end

  defp to_range(:~>, {major, minor, nil, pre}) do
    %Range{
      min: to_version({major, minor, 0, pre}),
      max: to_version({major + 1, 0, 0, [0]}),
      include_min: true
    }
  end

  defp to_range(:~>, {major, minor, patch, pre}) do
    %Range{
      min: to_version({major, minor, patch, pre}),
      max: to_version({major, minor + 1, 0, [0]}),
      include_min: true
    }
  end

  defp to_range(:>, version) do
    %Range{min: to_version(version)}
  end

  defp to_range(:>=, version) do
    %Range{min: to_version(version), include_min: true}
  end

  defp to_range(:<, version) do
    %Range{max: to_version(version)}
  end

  defp to_range(:<=, version) do
    %Range{max: to_version(version), include_max: true}
  end

  defp to_range(op1, version1, :~>, version2) do
    to_range(:~>, version2, op1, version1)
  end

  defp to_range(:~>, version1, op2, version2) do
    range1 = to_range(:~>, version1)
    range2 = to_range(op2, version2)

    true = Range.allows_any?(range1, range2)

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
    Map.merge(to_range(op1, version1), to_range(op2, version2), fn
      :__struct__, Range, Range -> Range
      :min, nil, value -> value
      :min, value, nil -> value
      :max, nil, value -> value
      :max, value, nil -> value
      :include_min, value, value -> value
      :include_min, false, value -> value
      :include_min, value, false -> value
      :include_max, value, value -> value
      :include_max, false, value -> value
      :include_max, value, false -> value
    end)
  end

  defp version_min(nil, _right), do: nil
  defp version_min(_left, nil), do: nil
  defp version_min(left, right), do: Version.min(left, right)

  defp version_max(nil, _right), do: nil
  defp version_max(_left, nil), do: nil
  defp version_max(left, right), do: Version.max(left, right)

  defp to_version({major, minor, patch, pre}),
    do: %Elixir.Version{major: major, minor: minor, patch: patch, pre: pre}
end
