defmodule Resolver.Constraint.Impl do
  defmacro __using__(_opts) do
    quote do
      defimpl Resolver.Constraint do
        def allows_any?(left, right),
          do: unquote(__CALLER__.module).allows_any?(left, right)

        def allows_higher?(left, right),
          do: unquote(__CALLER__.module).allows_higher?(left, right)

        def strictly_lower?(left, right),
          do: unquote(__CALLER__.module).strictly_lower?(left, right)

        def strictly_higher?(left, right),
          do: unquote(__CALLER__.module).strictly_higher?(left, right)

        def difference(left, right),
          do: unquote(__CALLER__.module).difference(left, right)

        def intersect(left, right),
          do: unquote(__CALLER__.module).intersect(left, right)

        def union(left, right),
          do: unquote(__CALLER__.module).union(left, right)
      end
    end
  end
end
