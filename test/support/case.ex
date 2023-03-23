defmodule HexSolver.Case do
  use ExUnit.CaseTemplate
  alias HexSolver.Case.Store
  alias HexSolver.{Incompatibility, Requirement}
  alias HexSolver.Constraints.{Empty, Range, Union}
  alias HexSolver.Registry.Process, as: Registry

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  def requirement() do
    StreamData.member_of(Store.get({:resolver_test, :requirements}))
  end

  def constraint() do
    StreamData.member_of(Store.get({:resolver_test, :constraints}))
  end

  def range() do
    StreamData.member_of(Store.get({:resolver_test, :ranges}))
  end

  def union() do
    StreamData.member_of(Store.get({:resolver_test, :unions}))
  end

  def version() do
    StreamData.member_of(Store.get({:resolver_test, :versions}))
  end

  def release() do
    StreamData.member_of(Store.get({:resolver_test, :releases}))
  end

  def init_registry() do
    Store.start()

    registry =
      "test/fixtures/registry.json"
      |> File.read!()
      |> Jason.decode!()

    releases =
      for {package, versions} <- registry,
          {version, dependencies} <- versions do
        dependencies =
          Enum.map(dependencies, fn {package, dependency} ->
            optional = Map.get(dependency, "optional", false)
            label = Map.get(dependency, "app", package)
            {package, dependency["requirement"], optional: optional, label: label}
          end)

        {package, version, dependencies}
      end
      |> Enum.shuffle()

    versions =
      for(
        {_package, versions} <- registry,
        {version, _dependencies} <- versions,
        do: Version.parse!(version)
      )
      |> Enum.uniq()
      |> Enum.shuffle()

    requirements =
      for {_package, versions} <- registry,
          {_version, dependencies} <- versions,
          {_package, dependency} <- dependencies do
        {:ok, requirement} = Version.parse_requirement(dependency["requirement"])
        requirement
      end
      |> Enum.uniq()
      |> Enum.shuffle()

    constraints = Enum.map(requirements, &Requirement.to_constraint!/1)
    constraints = [%Empty{}, %Range{}] ++ constraints
    ranges = Enum.filter(constraints, &match?(%Range{}, &1))
    unions = Enum.filter(constraints, &match?(%Union{}, &1))

    Store.put({:resolver_test, :releases}, releases)
    Store.put({:resolver_test, :versions}, versions)
    Store.put({:resolver_test, :requirements}, requirements)
    Store.put({:resolver_test, :constraints}, constraints)
    Store.put({:resolver_test, :ranges}, ranges)
    Store.put({:resolver_test, :unions}, unions)
  end

  def load_registry() do
    releases = Store.get({:resolver_test, :releases})

    Enum.each(releases, fn {package, version, dependencies} ->
      Registry.put(nil, package, version, dependencies)
    end)
  end

  def registry_release(package, version) do
    releases = Store.get({:resolver_test, :releases})

    Enum.find_value(releases, fn
      {^package, ^version, dependencies} -> dependencies
      {_package, _version, _dependencies} -> nil
    end)
  end

  def packages_in_incompatibility(incompatibility) do
    incompatibility
    |> do_packages_in_incompatibility()
    |> Enum.uniq()
  end

  defp do_packages_in_incompatibility(%Incompatibility{terms: terms, cause: cause}) do
    packages = Enum.map(terms, & &1.package_range.name)

    case cause do
      {:conflict, left, right} ->
        packages ++ do_packages_in_incompatibility(left) ++ do_packages_in_incompatibility(right)

      _other ->
        packages
    end
  end

  def incompatibility_no_versions?(%Incompatibility{cause: :no_versions}), do: true

  def incompatibility_no_versions?(%Incompatibility{cause: {:conflict, left, right}}),
    do: incompatibility_no_versions?(left) or incompatibility_no_versions?(right)

  def incompatibility_no_versions?(%Incompatibility{cause: _other}), do: false

  def v(string) do
    Version.parse!(string)
  end

  def to_dependencies(dependencies) do
    Enum.map(dependencies, fn
      {package, requirement} ->
        %{
          repo: nil,
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
        dependencies = Keyword.get(opts, :dependencies, [])

        %{
          repo: repo,
          name: package,
          constraint: HexSolver.Requirement.to_constraint!(requirement),
          optional: optional,
          label: label,
          dependencies: to_dependencies(dependencies)
        }
    end)
  end

  def to_locked(locked) do
    Enum.map(locked, fn
      {package, version} ->
        %{
          repo: nil,
          name: package,
          version: HexSolver.Requirement.to_constraint!(version),
          label: package
        }

      {package, version, opts} ->
        repo = Keyword.get(opts, :repo)
        label = Keyword.get(opts, :label, package)

        %{
          repo: repo,
          name: package,
          version: HexSolver.Requirement.to_constraint!(version),
          label: label
        }
    end)
  end

  def inspect_incompatibility(incompatibility) do
    inspect_incompatibility(incompatibility, "")
  end

  defp inspect_incompatibility(incompatibility, indent) do
    case incompatibility.cause do
      {:conflict, left, right} ->
        IO.puts("#{indent}* #{incompatibility} (conflict)")
        inspect_incompatibility(left, "  #{indent}")
        inspect_incompatibility(right, "  #{indent}")

      _ ->
        IO.puts("#{indent}* #{incompatibility} (#{incompatibility.cause})")
    end
  end

  def shrink(dependencies, fun) do
    fun = fn ->
      packages = Registry.packages()
      dependencies = Enum.filter(dependencies, &(elem(&1, 0) in packages))
      Registry.put(nil, "$root", "1.0.0", dependencies)
      fun.()
    end

    shrink_packages(fun)
    shrink_versions(fun)
    Registry.print_code(dependencies)
    assert {:ok, _} = fun.()
  end

  defp shrink_packages(fun) do
    Enum.each(Registry.packages(), fn package ->
      registry = Registry.get_state()

      task =
        Task.async(fn ->
          Registry.restore_state(registry)
          Registry.drop([package])

          try do
            case fun.() do
              {:ok, _result} ->
                true

              {:error, _incompatibility} ->
                false
            end
          rescue
            _exception ->
              false
          end
        end)

      case Task.yield(task, 100) || Task.shutdown(task) do
        {:ok, true} ->
          IO.puts("FAILED SHRINK #{package}")

        {:ok, false} ->
          IO.puts("SUCCEED SHRINK #{package}")
          Registry.drop([package])

        nil ->
          IO.puts("FAILED SHRINK TIMEOUT #{package}")
          Registry.drop([package])
      end
    end)
  end

  defp shrink_versions(fun) do
    Enum.each(Registry.packages(), fn {repo, package} ->
      {:ok, versions} = Registry.versions(repo, package)

      Enum.each(versions, fn version ->
        registry = Registry.get_state()

        task =
          Task.async(fn ->
            Registry.restore_state(registry)
            Registry.drop_version(repo, package, version)

            try do
              case fun.() do
                {:ok, _result} ->
                  true

                {:error, _incompatibility} ->
                  false
              end
            rescue
              _exception ->
                false
            end
          end)

        case Task.yield(task, 100) || Task.shutdown(task) do
          {:ok, true} ->
            IO.puts("FAILED SHRINK #{package} #{version}")

          {:ok, false} ->
            IO.puts("SUCCEED SHRINK #{package} #{version}")
            Registry.drop_version(repo, package, version)

          nil ->
            IO.puts("FAILED SHRINK TIMEOUT #{package} #{version}")
            Registry.drop_version(repo, package, version)
        end
      end)
    end)
  end

  defmodule Store do
    if Code.ensure_loaded?(:persistent_term) do
      def start(), do: :ok
      defdelegate put(key, value), to: :persistent_term
      defdelegate get(key), to: :persistent_term
    else
      def start(), do: :ets.new(__MODULE__, [:named_table, :public, read_concurrency: true])
      def put(key, value), do: :ets.insert(__MODULE__, {key, value})
      def get(key), do: :ets.lookup_element(__MODULE__, key, 2)
    end
  end
end
