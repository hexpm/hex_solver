defmodule Resolver.Constraints.Range do
  use Resolver.Constraints.Impl

  alias Resolver.Constraints.{Empty, Range, Union, Util, Version}

  # NOTE: %Range{min: nil, max: nil} allows any version.
  # NOTE: %Range{min: min, max: max, include_min: true, include_max: true}
  #       when min == max is a single version.
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

  def any?(%Range{min: nil, max: nil}), do: true
  def any?(%Range{}), do: false

  def empty?(%Range{}), do: false

  def allows?(%Range{} = range, %Elixir.Version{} = version) do
    compare_min = version_compare(range.min, version)

    if compare_min == :lt or (compare_min == :eq and range.include_min) do
      compare_max = version_compare(version, range.max)
      compare_max == :lt or (compare_max == :eq and range.include_max)
    else
      false
    end
  end

  def allows_all?(%Range{} = left, %Range{} = right) do
    not allows_lower?(right, left) and not allows_higher?(right, left)
  end

  def allows_any?(%Range{}, %Empty{}), do: true
  def allows_any?(%Range{} = range, %Elixir.Version{} = version), do: allows?(range, version)

  def allows_any?(%Range{} = left, %Range{} = right) do
    not strictly_lower?(right, left) and not strictly_higher?(right, left)
  end

  def allows_any?(%Range{} = range, %Union{ranges: ranges}) do
    Enum.any?(ranges, &allows_any?(range, &1))
  end

  def allows_lower?(%Range{} = left, %Range{} = right) do
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

  def allows_higher?(%Range{} = left, %Range{} = right) do
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

  def strictly_lower?(%Range{} = left, %Range{} = right) do
    if is_nil(left.max) or is_nil(right.min) do
      false
    else
      case Version.compare(left.max, right.min) do
        :lt -> true
        :gt -> false
        :eq -> not left.include_max or not right.include_min
      end
    end
  end

  def strictly_higher?(%Range{} = left, %Range{} = right) do
    strictly_lower?(right, left)
  end

  def difference(%Range{} = left, %Range{} = right) do
    if allows_any?(left, right) do
      before_range =
        cond do
          not allows_lower?(left, right) ->
            nil

          left.min == right.min ->
            true = left.include_min and not right.include_min
            true = not is_nil(left.min)
            left.min

          true ->
            %Range{
              min: left.min,
              max: right.min,
              include_min: left.include_min,
              include_max: not right.include_min
            }
        end

      after_range =
        cond do
          not allows_higher?(left, right) ->
            nil

          left.max == right.max ->
            true = left.include_max and not right.include_max
            true = not is_nil(left.max)
            left.max

          true ->
            %Range{
              min: right.max,
              max: left.max,
              include_min: not right.include_min,
              include_max: not left.include_max
            }
        end

      cond do
        is_nil(before_range) and is_nil(after_range) -> %Empty{}
        is_nil(before_range) -> after_range
        is_nil(after_range) -> before_range
        true -> %Union{ranges: [before_range, after_range]}
      end
    else
      left
    end
  end

  def intersect(%Range{} = left, %Range{} = right) do
    if strictly_lower?(left, right) or strictly_lower?(right, left) do
      %Empty{}
    else
      {intersect_min, intersect_include_min} =
        if allows_lower?(left, right) do
          {right.min, right.include_min}
        else
          {left.min, left.include_min}
        end

      {intersect_max, intersect_include_max} =
        if allows_higher?(left, right) do
          {right.max, right.include_max}
        else
          {left.max, left.include_max}
        end

      cond do
        is_nil(intersect_min) and is_nil(intersect_max) ->
          # Open range
          %Range{}

        intersect_min == intersect_max ->
          # There must be overlap since we already checked none of
          # the ranges are strictly lower
          true = intersect_include_min and intersect_include_max
          intersect_min

        true ->
          %Range{
            min: intersect_min,
            max: intersect_max,
            include_min: intersect_include_min,
            include_max: intersect_include_max
          }
      end
    end
  end

  def union(%Range{} = range, %Elixir.Version{} = version) do
    if allows?(range, version) do
      range
    else
      case range do
        %Range{min: ^version} -> %{range | include_min: true}
        %Range{max: ^version} -> %{range | include_max: true}
        _ -> Util.union([range, version])
      end
    end
  end

  def union(%Range{} = left, %Range{} = right) do
    if not edges_touch?(left, right) and not Range.allows_any?(left, right) do
      Util.union([left, right])
    else
      min = if allows_lower?(left, right), do: left, else: right
      max = if allows_higher?(left, right), do: left, else: right

      %Range{
        min: min.min,
        max: max.max,
        include_min: min.include_min,
        include_max: max.include_max
      }
    end
  end

  def union(%Range{} = left, right) do
    Util.union([left, right])
  end

  defp edges_touch?(left, right) do
    (left.max != nil and left.max == right.min and (left.include_max or right.include_min)) or
      (left.min != nil and left.min == right.max and (left.include_min or right.include_max))
  end

  def compare(%Range{min: min, include_min: include_min}, %Elixir.Version{} = version) do
    if is_nil(min) do
      :lt
    else
      case Version.compare(min, version) do
        :eq when include_min -> :eq
        :eq -> :gt
        :lt -> :lt
        :gt -> :gt
      end
    end
  end

  def compare(%Range{} = left, %Range{} = right) do
    cond do
      is_nil(left.min) and is_nil(right.min) ->
        :eq

      is_nil(left.min) ->
        :lt

      is_nil(right.min) ->
        :gt

      true ->
        case Version.compare(left.min, right.min) do
          :eq when left.include_min == right.include -> :eq
          :eq when left.include_min -> :lt
          :eq when right.include_min -> :gt
          :lt -> :lt
          :gt -> :gt
        end
    end
  end

  def compare(%Range{} = left, %Union{ranges: [right | _]}) do
    compare(left, right)
  end

  def single_version?(%Range{min: min, max: max, include_min: true, include_max: true}) do
    min == max
  end

  def single_version?(%Range{}) do
    false
  end

  defp version_compare(nil, _right), do: :lt
  defp version_compare(_left, nil), do: :lt
  defp version_compare(left, right), do: Version.compare(left, right)
end
