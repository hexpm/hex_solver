defmodule Resolver.Registry do
  @type package() :: String.t()
  @type optional() :: boolean()

  @callback versions(package()) :: {:ok, [Version.t()]} | :error
  @callback dependencies(package(), Version.t()) ::
              {:ok, [{Version.t(), Resolver.Constraint.t(), optional()}]} | :error
end
