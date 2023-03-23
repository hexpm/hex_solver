defmodule HexSolver.Registry.Process do
  @behaviour HexSolver.Registry

  def versions(repo, package) do
    unless {repo, package} in Process.get({__MODULE__, :prefetch}, []) do
      raise "not prefetched #{repo}/#{package}"
    end

    case Process.get({__MODULE__, :versions, repo, package}) do
      nil -> :error
      versions -> {:ok, versions}
    end
  end

  def dependencies(repo, package, version) do
    unless {repo, package} in Process.get({__MODULE__, :prefetch}, []) do
      raise "not prefetched #{repo}/#{package}"
    end

    case Process.get({__MODULE__, :dependencies, repo, package, version}) do
      nil -> :error
      dependencies -> {:ok, dependencies}
    end
  end

  def prefetch(packages) do
    Enum.each(packages, fn {repo, package} ->
      prefetch = Process.get({__MODULE__, :prefetch}, [])

      if {repo, package} in prefetch do
        raise "already prefetched #{repo}/#{package}"
      else
        Process.put({__MODULE__, :prefetch}, [{repo, package} | prefetch])
      end
    end)
  end

  def put(repo \\ nil, package, version, dependencies) do
    version = Version.parse!(version)
    versions = Process.get({__MODULE__, :versions, repo, package}, [])
    versions = Enum.sort(Enum.uniq([version | versions]), HexSolver.Util.compare(Version))

    dependencies =
      Enum.map(dependencies, fn
        {package, requirement} ->
          %{
            repo: repo,
            name: package,
            constraint: HexSolver.Requirement.to_constraint!(requirement),
            optional: false,
            label: package,
            dependencies: []
          }

        {package, requirement, opts} ->
          repo = Keyword.get(opts, :repo)
          optional = Keyword.get(opts, :optional, false)
          label = Keyword.get(opts, :label, package)

          %{
            repo: repo,
            name: package,
            constraint: HexSolver.Requirement.to_constraint!(requirement),
            optional: optional,
            label: label,
            dependencies: []
          }
      end)

    Process.put({__MODULE__, :versions, repo, package}, versions)
    Process.put({__MODULE__, :dependencies, repo, package, version}, dependencies)
  end

  def reset_prefetch() do
    Process.delete({__MODULE__, :prefetch})
  end

  def keep(packages) do
    Enum.each(Process.get(), fn
      {{__MODULE__, :versions, repo, package} = key, _versions} ->
        unless {repo, package} in packages do
          Process.delete(key)
        end

      {{__MODULE__, :dependencies, repo, package, _version} = key, dependencies} ->
        if {repo, package} in packages do
          dependencies =
            Enum.filter(dependencies, fn %{repo: repo, name: package} ->
              {repo, package} in packages
            end)

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
      {{__MODULE__, :versions, repo, package} = key, _versions} ->
        if {repo, package} in packages do
          Process.delete(key)
        end

      {{__MODULE__, :dependencies, repo, package, _version} = key, dependencies} ->
        if {repo, package} in packages do
          Process.delete(key)
        else
          dependencies =
            Enum.reject(dependencies, fn %{repo: repo, name: package} ->
              {repo, package} in packages
            end)

          Process.put(key, dependencies)
        end

      _other ->
        :ok
    end)
  end

  def drop_version(repo, package, version) do
    Process.delete({__MODULE__, :dependencies, repo, package, version})
    versions = Process.get({__MODULE__, :versions, repo, package}) -- [version]

    if versions == [] do
      Process.delete({__MODULE__, :versions, repo, package})
    else
      Process.put({__MODULE__, :versions, repo, package}, versions)
    end
  end

  def packages_with_dependencies(packages) do
    Enum.reduce(packages, packages, &package_with_dependencies/2)
  end

  defp package_with_dependencies({repo, package}, acc) do
    versions = Process.get({__MODULE__, :versions, repo, package})

    Enum.reduce(versions, acc, fn version, acc ->
      dependencies =
        Process.get({__MODULE__, :dependencies, repo, package, version})
        |> Enum.map(fn %{repo: repo, name: package} -> {repo, package} end)

      Enum.reduce(dependencies, acc, fn {repo, dependency}, acc ->
        if {repo, dependency} in acc do
          acc
        else
          package_with_dependencies({repo, dependency}, [{repo, dependency} | acc])
        end
      end)
    end)
  end

  def get_state() do
    Enum.flat_map(Process.get(), fn
      {{__MODULE__, :versions, _repo, _package}, _versions} = record ->
        [record]

      {{__MODULE__, :dependencies, _repo, _package, _version}, _dependencies} = record ->
        [record]

      _other ->
        []
    end)
  end

  def restore_state(records) do
    Enum.each(Process.get(), fn
      {{__MODULE__, :versions, _repo, _package} = key, _versions} ->
        Process.delete(key)

      {{__MODULE__, :dependencies, _repo, _package, _version} = key, _dependencies} ->
        Process.delete(key)

      _other ->
        :ok
    end)

    Enum.each(records, fn {key, value} -> Process.put(key, value) end)
  end

  def packages() do
    Enum.flat_map(Process.get(), fn
      {{__MODULE__, :versions, repo, package}, _versions} -> [{repo, package}]
      _other -> []
    end)
  end

  def print_code(dependencies) do
    packages = packages()

    dependencies =
      Enum.filter(dependencies, fn %{repo: repo, name: package} ->
        {repo, package} in packages
      end)

    IO.puts(~s[Registry.put("$root", "1.0.0", #{inspect(dependencies)})])

    Enum.each(Process.get(), fn
      {{__MODULE__, :dependencies, repo, package, version}, dependencies} ->
        dependencies =
          Enum.map(dependencies, fn %{
                                      repo: repo,
                                      name: package,
                                      constraint: constraint,
                                      optional: optional,
                                      label: label
                                    } ->
            {package, to_string(constraint), repo: repo, optional: optional, label: label}
          end)

        IO.puts(
          "Registry.put(#{inspect(repo)}, #{inspect(package)}, #{inspect(to_string(version))}, #{inspect(dependencies)})"
        )

      _other ->
        :ok
    end)
  end
end
