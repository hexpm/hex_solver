defmodule HexSolver.Incompatibility do
  @moduledoc false

  import Kernel, except: [to_string: 1]
  alias HexSolver.{Constraint, Incompatibility, PackageRange, Term}
  alias HexSolver.Constraints.Range

  defstruct terms: [], cause: nil

  # Causes:
  # * {:conflict, incompatibility, cause}
  # * :root
  # * :dependency
  # * :no_versions
  # * :package_not_found

  def new(terms, cause) do
    terms =
      if length(terms) != 1 and match?({:conflict, _, _}, cause) and
           Enum.any?(terms, &(&1.positive or &1.package_range.name == "$root")) do
        Enum.filter(terms, &(not &1.positive or &1.package_range.name != "$root"))
      else
        terms
      end

    case terms do
      [_first] ->
        %Incompatibility{terms: terms, cause: cause}

      [first, second] when first.package_range.name != second.package_range.name ->
        %Incompatibility{terms: terms, cause: cause}

      _ ->
        terms =
          Enum.reduce(terms, %{}, fn term, map ->
            Map.update(map, term.package_range.name, term, &Term.intersect(&1, term))
          end)

        %Incompatibility{terms: Map.values(terms), cause: cause}
    end
  end

  def failure?(%Incompatibility{terms: []}), do: true

  def failure?(%Incompatibility{terms: [term]}) when term.package_range.name == "$root",
    do: true

  def failure?(%Incompatibility{}), do: false

  def to_string(%Incompatibility{
        cause: :dependency,
        terms: [%Term{positive: true} = depender, %Term{positive: false} = dependee]
      })
      when depender.package_range.name == "$lock" do
    "lock specifies #{term_abs(dependee)}"
  end

  def to_string(%Incompatibility{
        cause: :dependency,
        terms: [%Term{positive: true} = depender, %Term{positive: false} = dependee]
      }) do
    "#{terse_every(depender)} depends on #{term_abs(dependee)}"
  end

  def to_string(%Incompatibility{cause: :no_versions, terms: terms}) do
    [%Term{positive: true} = term] = terms
    "no versions of #{package_name(term)} match #{term.package_range.constraint}"
  end

  def to_string(%Incompatibility{cause: :package_not_found, terms: terms}) do
    [%Term{positive: true} = term] = terms
    "#{package_name(term)} doesn't exist"
  end

  def to_string(%Incompatibility{cause: :root, terms: terms}) do
    [%Term{positive: false} = term] = terms
    "#{package_name(term)} is #{term.package_range.constraint}"
  end

  def to_string(%Incompatibility{terms: []}) do
    "version solving failed"
  end

  def to_string(%Incompatibility{terms: [%Term{package_range: %PackageRange{name: "$root"}}]}) do
    "version solving failed"
  end

  def to_string(%Incompatibility{
        terms: [
          %Term{
            positive: true,
            package_range: %PackageRange{constraint: %Range{min: nil, max: nil}}
          } = term
        ]
      }) do
    "no version of #{package_name(term)} is allowed"
  end

  def to_string(%Incompatibility{terms: [%Term{positive: true} = term]}) do
    "#{terse_name(term)} is forbidden"
  end

  def to_string(%Incompatibility{terms: [%Term{positive: false} = term]}) do
    "#{terse_name(%Term{term | positive: true})} is required"
  end

  def to_string(%Incompatibility{terms: [left, right]}) when left.positive == right.positive do
    if left.positive do
      "#{terse_name(%Term{left | positive: true})} is incompatible with #{terse_name(%Term{right | positive: true})}"
    else
      "either #{term_abs(left)} or #{term_abs(right)}"
    end
  end

  def to_string(%Incompatibility{terms: terms}) do
    {positive, negative} = Enum.split_with(terms, & &1.positive)

    cond do
      positive != [] and negative != [] ->
        case positive do
          [term] ->
            "#{term_abs(term)} requires #{Enum.map_join(negative, " or ", &term_abs/1)}"

          _ ->
            "if #{Enum.map_join(positive, " and ", &term_abs/1)} then #{Enum.map_join(negative, " or ", &term_abs/1)}"
        end

      positive != [] ->
        "one of #{Enum.map_join(positive, " or ", &term_abs/1)} must be false"

      negative != [] ->
        "one of #{Enum.map_join(negative, " or ", &term_abs/1)} must be true"
    end
  end

  def to_string_and(left, right, left_line \\ nil, right_line \\ nil)

  def to_string_and(
        %Incompatibility{terms: [lock, _dependency], cause: :dependency} = left,
        %Incompatibility{terms: [root, lock_dependency], cause: :dependency},
        _left_line,
        _right_line
      )
      when root.package_range.name == "$root" and lock_dependency.package_range.name == "$lock" and
             lock.package_range.name == "$lock" do
    to_string(left)
  end

  def to_string_and(%Incompatibility{} = left, %Incompatibility{} = right, left_line, right_line) do
    cond do
      requires_both = try_requires_both(left, right, left_line, right_line) ->
        requires_both

      requires_through = try_requires_through(left, right, left_line, right_line) ->
        requires_through

      requires_forbidden = try_requires_forbidden(left, right, left_line, right_line) ->
        requires_forbidden

      true ->
        [
          to_string(left),
          maybe_line(left_line),
          " and ",
          to_string(right),
          maybe_line(right_line)
        ]
    end
    |> IO.chardata_to_string()
  end

  defp try_requires_both(left, right, left_line, right_line) do
    if length(left.terms) == 1 or length(right.terms) == 1 do
      throw({__MODULE__, :try_requires_both})
    end

    left_positive = single_term(left, & &1.positive)
    right_positive = single_term(right, & &1.positive)

    if !left_positive || !right_positive ||
         left_positive.package_range != right_positive.package_range do
      throw({__MODULE__, :try_requires_both})
    end

    left_negatives =
      left.terms
      |> Enum.reject(& &1.positive)
      |> Enum.map_join(" or ", &term_abs/1)

    right_negatives =
      right.terms
      |> Enum.reject(& &1.positive)
      |> Enum.map_join(" or ", &term_abs/1)

    dependency? = left.cause == :dependency and right.cause == :dependency

    [
      terse_every(left_positive),
      " ",
      cause_verb(dependency?),
      " both ",
      left_negatives,
      maybe_line(left_line),
      " and ",
      right_negatives,
      maybe_line(right_line)
    ]
  catch
    {__MODULE__, :try_requires_both} -> nil
  end

  defp try_requires_through(right, left, left_line, right_line) do
    if length(left.terms) == 1 or length(right.terms) == 1 do
      throw({__MODULE__, :try_requires_through})
    end

    left_negative = single_term(left, &(not &1.positive))
    right_negative = single_term(right, &(not &1.positive))
    left_positive = single_term(left, & &1.positive)
    right_positive = single_term(right, & &1.positive)

    if !left_negative && !right_negative do
      throw({__MODULE__, :try_requires_through})
    end

    {prior, prior_negative, prior_line, latter, latter_line} =
      cond do
        left_negative && right_positive &&
          left_negative.package_range.name == right_positive.package_range.name &&
            Term.satisfies?(Term.inverse(left_negative), right_positive) ->
          {left, left_negative, left_line, right, right_line}

        right_negative && left_positive &&
          right_negative.package_range.name == left_positive.package_range.name &&
            Term.satisfies?(Term.inverse(right_negative), left_positive) ->
          {right, right_negative, right_line, left, left_line}

        true ->
          throw({__MODULE__, :try_requires_through})
      end

    prior_positives = Enum.filter(prior.terms, & &1.positive)

    buffer =
      if length(prior_positives) > 1 do
        prior_string = Enum.map_join(prior_positives, " or ", &term_abs/1)
        "if #{prior_string} then "
      else
        "#{terse_every(List.first(prior_positives))} #{cause_verb(prior)} "
      end

    buffer = [
      buffer,
      term_abs(prior_negative),
      maybe_line(prior_line),
      " which ",
      cause_verb(latter)
    ]

    latter_string =
      latter.terms
      |> Enum.reject(& &1.positive)
      |> Enum.map_join(" or ", &term_abs/1)

    [buffer, " ", latter_string, maybe_line(latter_line)]
  catch
    {__MODULE__, :try_requires_through} -> nil
  end

  defp try_requires_forbidden(left, right, left_line, right_line) do
    if length(left.terms) != 1 and length(right.terms) != 1 do
      throw({__MODULE__, :try_requires_forbidden})
    end

    {prior, prior_line, latter, latter_line} =
      if length(left.terms) == 1 do
        {right, right_line, left, left_line}
      else
        {left, left_line, right, right_line}
      end

    negative = single_term(prior, &(not &1.positive))

    unless negative do
      throw({__MODULE__, :try_requires_forbidden})
    end

    unless Term.satisfies?(Term.inverse(negative), List.first(latter.terms)) do
      throw({__MODULE__, :try_requires_forbidden})
    end

    positives = Enum.filter(prior.terms, & &1.positive)

    buffer =
      case positives do
        [positive] ->
          [terse_every(positive), " ", cause_verb(prior), " "]

        _ ->
          ["if ", Enum.map_join(positives, " or ", &term_abs/1), " then "]
      end

    buffer = [buffer, term_abs(List.first(latter.terms)), maybe_line(prior_line), " "]

    buffer =
      case latter.cause do
        :no_versions -> [buffer, "which doesn't match any versions"]
        :package_not_found -> [buffer, "which doesn't exist"]
        _ -> [buffer, "which is forbidden"]
      end

    [buffer, maybe_line(latter_line)]
  catch
    {__MODULE__, :try_requires_forbidden} -> nil
  end

  defp cause_verb(true), do: "depends on"
  defp cause_verb(false), do: "requires"
  defp cause_verb(%Incompatibility{cause: :dependency}), do: "depends on"
  defp cause_verb(%Incompatibility{cause: _}), do: "requires"

  defp maybe_line(nil), do: ""
  defp maybe_line(line), do: " (#{line})"

  defp single_term(%Incompatibility{terms: terms}, fun) do
    Enum.reduce_while(terms, nil, fn term, found ->
      if fun.(term) do
        if found do
          {:halt, nil}
        else
          {:cont, term}
        end
      else
        {:cont, found}
      end
    end)
  end

  defp package_name(%Term{package_range: %PackageRange{name: "$root"}}), do: "myapp"
  defp package_name(%Term{package_range: %PackageRange{name: "$lock"}}), do: "lock"
  defp package_name(%Term{package_range: %PackageRange{name: name}}), do: name

  defp terse_name(term) do
    if Constraint.any?(term.package_range.constraint) do
      package_name(term)
    else
      PackageRange.to_string(term.package_range)
    end
  end

  defp terse_every(%Term{package_range: %PackageRange{name: "$root"}}), do: "myapp"
  defp terse_every(%Term{package_range: %PackageRange{name: "$lock"}}), do: "lock"

  defp terse_every(term) do
    if Constraint.any?(term.package_range.constraint) do
      "every version of #{package_name(term)}"
    else
      PackageRange.to_string(term.package_range)
    end
  end

  defp term_abs(term), do: Term.to_string(%Term{term | positive: true})

  defimpl String.Chars do
    defdelegate to_string(incompatibility), to: HexSolver.Incompatibility
  end

  defimpl Inspect do
    def inspect(%{terms: terms, cause: cause}, _opts) do
      "#Incompatibility<#{Enum.map_join(terms, ", ", &Kernel.inspect/1)}#{maybe(", cause: ", cause)}>"
    end

    defp maybe(_prefix, nil), do: ""
    defp maybe(prefix, value), do: "#{prefix}#{inspect(value)}"
  end
end
