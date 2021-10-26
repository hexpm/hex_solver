defmodule Resolver.Registry do
  @type package() :: String.t()
  @type optional() :: boolean()

  @callback versions(package()) :: {:ok, [Version.t()]} | :error
  @callback dependencies(package(), {Version.t(), optional()}) ::
              {:ok, [{Version.t(), Resolver.Constraint.t()}]} | :error
end
