ExUnit.start()

defmodule Resolver.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  def requirements() do
    StreamData.member_of(:persistent_term.get({:resolver_test, :requirements}))
  end

  def versions() do
    StreamData.member_of(:persistent_term.get({:resolver_test, :versions}))
  end

  def init_registry() do
    registry =
      "priv/registry.term"
      |> File.read!()
      |> :zlib.gunzip()
      |> :erlang.binary_to_term()

    versions =
      registry
      |> Enum.flat_map(fn {_package, versions} ->
        Enum.map(versions, & &1.version)
      end)
      |> Enum.uniq()
      # |> Enum.sort(Resolver.Version)
      |> Enum.shuffle()
      |> Enum.map(&Version.parse!/1)

    requirements =
      registry
      |> Enum.flat_map(fn {_package, versions} ->
        Enum.flat_map(versions, fn version ->
          Enum.map(version.dependencies, & &1.requirement)
        end)
      end)
      |> Enum.uniq()
      # |> Enum.sort()
      |> Enum.shuffle()
      |> Enum.map(&Version.parse_requirement!/1)

    :persistent_term.put({:resolver_test, :versions}, versions)
    :persistent_term.put({:resolver_test, :requirements}, requirements)
  end
end

Resolver.Case.init_registry()
