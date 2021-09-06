defmodule Resolver.Registry.Static do
  @behaviour Resolver.Registry

  def versions("$root"), do: [Version.parse!("1.0.0")]
  def dependencies("$root", _), do: []
end
