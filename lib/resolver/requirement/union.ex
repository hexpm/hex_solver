defmodule Resolver.Requirement.Union do
  alias Resolver.Requirement.{Range, Union}

  defstruct ranges: []

  def allows_all?(%Union{ranges: left}, %Union{ranges: right}) do
    do_allows_all?(left, right)
  end

  # We can recurse left and right together since they are
  # sorted on minimum version
  defp do_allows_all?([left | lefts], [right | rights]) do
    if Range.allows_all?(left, right) do
      do_allows_all?([left | lefts], rights)
    else
      do_allows_all?(lefts, [right | rights])
    end
  end

  defp do_allows_all?(_lefts, []), do: true
  defp do_allows_all?([], _rights), do: false

  def allows_any?(%Union{ranges: left}, %Union{ranges: right}) do
    do_allows_any?(left, right)
  end

  # We can recurse left and right together since they are
  # sorted on minimum version
  defp do_allows_any?([left | lefts], [right | rights]) do
    cond do
      Range.allows_any?(left, right) ->
        true

      # Move forward with the range with the lower max value
      Range.allows_higher?(right, left) ->
        do_allows_any?(lefts, [right | rights])

      true ->
        do_allows_any?([left | lefts], rights)
    end
  end

  defp do_allows_any?(_lefts, _rights), do: false
end
