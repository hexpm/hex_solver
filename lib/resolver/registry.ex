defmodule Resolver.Registry do
  @type package() :: String.t()

  @callback versions(package()) :: {:ok, [Version.t()]} | :error
  @callback dependencies(package(), Version.t()) :: {:ok, [{Version.t(), Resolver.Constraint.t()}]} | :error
end
