defmodule HexSolver.Registry.Process do
  @behaviour HexSolver.Registry

  def versions(package) do
    unless package in Process.get({__MODULE__, :prefetch}, []) do
      raise "not prefetched #{package}"
    end

    case Process.get({__MODULE__, :versions, package}) do
      nil -> :error
      versions -> {:ok, versions}
    end
  end

  def dependencies(package, version) do
    unless package in Process.get({__MODULE__, :prefetch}, []) do
      raise "not prefetched #{package}"
    end

    case Process.get({__MODULE__, :dependencies, package, version}) do
      nil -> :error
      dependencies -> {:ok, dependencies}
    end
  end

  def prefetch(packages) do
    Enum.each(packages, fn package ->
      prefetch = Process.get({__MODULE__, :prefetch}, [])

      if package in prefetch do
        raise "already prefetched #{package}"
      else
        Process.put({__MODULE__, :prefetch}, [package | prefetch])
      end
    end)
  end

  def put(package, version, dependencies) do
    version = Version.parse!(version)
    versions = Process.get({__MODULE__, :versions, package}, [])
    versions = Enum.sort(Enum.uniq([version | versions]), Version)

    dependencies =
      Enum.map(dependencies, fn
        {package, requirement} ->
          {package, HexSolver.Requirement.to_constraint!(requirement), false, package}

        {package, requirement, opts} ->
          optional = Keyword.get(opts, :optional, false)
          label = Keyword.get(opts, :label, package)
          {package, HexSolver.Requirement.to_constraint!(requirement), optional, label}
      end)

    Process.put({__MODULE__, :versions, package}, versions)
    Process.put({__MODULE__, :dependencies, package, version}, dependencies)
  end

  def reset_prefetch() do
    Process.delete({__MODULE__, :prefetch})
  end

  def keep(packages) do
    Enum.each(Process.get(), fn
      {{__MODULE__, :versions, package} = key, _versions} ->
        unless package in packages do
          Process.delete(key)
        end

      {{__MODULE__, :dependencies, package, _version} = key, dependencies} ->
        if package in packages do
          dependencies = Enum.filter(dependencies, &(elem(&1, 0) in packages))
          Process.put(key, dependencies)
        else
          Process.delete(key)
        end

      _other ->
        :ok
    end)
  end

  def drop(packages) do
    Enum.each(Process.get(), fn
      {{__MODULE__, :versions, package} = key, _versions} ->
        if package in packages do
          Process.delete(key)
        end

      {{__MODULE__, :dependencies, package, _version} = key, dependencies} ->
        if package in packages do
          Process.delete(key)
        else
          dependencies = Enum.reject(dependencies, &(elem(&1, 0) in packages))
          Process.put(key, dependencies)
        end

      _other ->
        :ok
    end)
  end

  def drop_version(package, version) do
    Process.delete({__MODULE__, :dependencies, package, version})
    versions = Process.get({__MODULE__, :versions, package}) -- [version]

    if versions == [] do
      Process.delete({__MODULE__, :versions, package})
    else
      Process.put({__MODULE__, :versions, package}, versions)
    end
  end

  def packages_with_dependencies(packages) do
    Enum.reduce(packages, packages, &package_with_dependencies/2)
  end

  defp package_with_dependencies(package, acc) do
    versions = Process.get({__MODULE__, :versions, package})

    Enum.reduce(versions, acc, fn version, acc ->
      dependencies =
        Process.get({__MODULE__, :dependencies, package, version})
        |> Enum.map(&elem(&1, 0))

      Enum.reduce(dependencies, acc, fn dependency, acc ->
        if dependency in acc do
          acc
        else
          package_with_dependencies(dependency, [dependency | acc])
        end
      end)
    end)
  end

  def get_state() do
    Enum.flat_map(Process.get(), fn
      {{__MODULE__, :versions, _package}, _versions} = record ->
        [record]

      {{__MODULE__, :dependencies, _package, _version}, _dependencies} = record ->
        [record]

      _other ->
        []
    end)
  end

  def restore_state(records) do
    Enum.each(Process.get(), fn
      {{__MODULE__, :versions, _package} = key, _versions} ->
        Process.delete(key)

      {{__MODULE__, :dependencies, _package, _version} = key, _dependencies} ->
        Process.delete(key)

      _other ->
        :ok
    end)

    Enum.each(records, fn {key, value} -> Process.put(key, value) end)
  end

  def packages() do
    Enum.flat_map(Process.get(), fn
      {{__MODULE__, :versions, package}, _versions} -> [package]
      _other -> []
    end)
  end

  def print_code(dependencies) do
    packages = packages()
    dependencies = Enum.filter(dependencies, &(elem(&1, 0) in packages))
    IO.puts(~s[Registry.put("$root", "1.0.0", #{inspect(dependencies)})])

    Enum.each(Process.get(), fn
      {{__MODULE__, :dependencies, package, version}, dependencies} ->
        dependencies =
          Enum.map(dependencies, fn {package, requirement, optional, label} ->
            {package, to_string(requirement), optional: optional, label: label}
          end)

        IO.puts(
          "Registry.put(#{inspect(package)}, #{inspect(to_string(version))}, #{inspect(dependencies)})"
        )

      _other ->
        :ok
    end)
  end
end
