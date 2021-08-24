defmodule Resolver.Requirement.Range do
  alias __MODULE__
  alias Resolver.Version

  defstruct min: nil,
            max: nil,
            include_min: false,
            include_max: false

  def valid?(%Range{min: min, max: max, include_min: include_min, include_max: include_max}) do
    case version_compare(min, max) do
      :lt -> true
      :eq -> include_min and include_max
      :gt -> false
    end
  end

  def overlapping?(%Range{} = left, %Range{} = right) do
    case version_compare(left.min, right.max) do
      :lt ->
        case version_compare(right.min, left.max) do
          :lt -> true
          :eq -> right.include_min or left.include_max
          :gt -> false
        end

      :eq ->
        (left.include_min or right.include_max) and
          case version_compare(right.min, left.max) do
            :lt -> true
            :eq -> right.include_min or left.include_max
            :gt -> false
          end

      :gt ->
        false
    end
  end

  def allows_all?(left, right) do
    not allows_lower?(right, left) and not allows_higher?(right, left)
  end

  def allows_lower?(left, right) do
    cond do
      is_nil(left.min) ->
        not is_nil(right.min)

      is_nil(right.min) ->
        false

      true ->
        case Version.compare(left.min, right.min) do
          :lt -> true
          :gt -> false
          :eq -> left.include_min and not right.include_min
        end
    end
  end

  def allows_higher?(left, right) do
    cond do
      is_nil(left.max) ->
        not is_nil(right.max)

      is_nil(right.max) ->
        false

      true ->
        case Version.compare(left.max, right.max) do
          :lt -> false
          :gt -> true
          :eq -> left.include_max and not right.include_max
        end
    end
  end

  defp version_compare(nil, _right), do: :lt
  defp version_compare(_left, nil), do: :lt
  defp version_compare(left, right), do: Version.compare(left, right)
end
