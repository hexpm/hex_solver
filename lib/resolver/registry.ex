defmodule Resolver.Registry do
  @type package() :: String.t()

  @callback versions(package()) :: [Version.t()]
  @callback dependencies(package(), Version.t()) :: [{String.t(), Resolver.Constraint.t()}]
end
