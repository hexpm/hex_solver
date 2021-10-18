defmodule Resolver.Incompatibility do
  alias Resolver.{Incompatibility, PackageRange, Term}

  defstruct terms: [], cause: nil

  def new(terms, cause) do
    terms =
      if length(terms) != 1 and match?({:conflict, _, _}, cause) and Enum.any?(terms, &(&1.positive or &1.package_range.name == "$root")) do
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

  def failure?(%Incompatibility{terms: [%Term{package_range: %PackageRange{name: "$root"}}]}),
    do: true

  def failure?(%Incompatibility{}), do: false

  defimpl String.Chars do
    # TODO: Use cause to improve this
    def to_string(%{terms: [term]}) do
      "#{term(term)} is #{positive(term.positive)}"
    end

    def to_string(%{terms: [left, right]}) when left.positive == right.positive do
      if left.positive do
        "#{term(left)} is incompatible with #{term(right)}"
      else
        "either #{term(left)} or #{term(right)}"
      end
    end

    def to_string(%{terms: terms}) do
      {positive, negative} = Enum.split_with(terms, & &1.positive)

      cond do
        positive != [] and negative != [] ->
          case positive do
            [term] ->
              "#{term(term)} requires #{Enum.map_join(negative, " or ", &term/1)}"

            _ ->
              "if #{Enum.map_join(positive, " and ", &term/1)} then #{Enum.map_join(negative, " or ", &term/1)}"
          end

        positive != [] ->
          "one of #{Enum.map_join(positive, " or ", &term/1)} must be false"

        negative != [] ->
          "one of #{Enum.map_join(negative, " or ", &term/1)} must be true"
      end
    end

    defp term(term), do: "#{term.package_range.name} #{term.package_range.constraint}"

    defp positive(true), do: "forbidden"
    defp positive(false), do: "required"
  end

  defimpl Inspect do
    def inspect(%{terms: terms, cause: cause}, _opts) do
      "#Incompatibility<#{Enum.map_join(terms, ", ", &Kernel.inspect/1)}#{maybe(", cause: ", cause)}>"
    end

    defp maybe(_prefix, nil), do: ""
    defp maybe(prefix, value), do: "#{prefix}#{inspect(value)}"
  end
end
