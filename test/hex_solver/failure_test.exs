defmodule HexSolver.FailureTest do
  use HexSolver.Case, async: true

  alias HexSolver.Failure
  alias HexSolver.Registry.Process, as: Registry

  defp run(dependencies, locked \\ [], overrides \\ []) do
    assert {:error, incompatibility} =
             HexSolver.Solver.run(
               Registry,
               to_dependencies(dependencies),
               to_locked(locked),
               overrides
             )

    Failure.write(incompatibility)
  end

  test "conflicting constraints 1" do
    Registry.put("foo", "1.0.0", [{"bar", "~> 2.0"}])
    Registry.put("bar", "1.0.0", [])
    Registry.put("bar", "2.0.0", [])

    assert run([{"foo", "1.0.0"}, {"bar", "~> 1.0"}]) == """
           Because every version of "foo" depends on "bar ~> 2.0" and "your app" depends on "bar ~> 1.0", no version of "foo" is allowed.
           So, because "your app" depends on "foo 1.0.0", version solving failed.\
           """
  end

  test "conflicting constraints 2" do
    Registry.put("bar", "1.0.0", [{"foo", "1.0.0"}])
    Registry.put("foo", "1.0.0", [])
    Registry.put("foo", "2.0.0", [])

    assert run([{"bar", "1.0.0"}, {"foo", "~> 2.0"}]) == """
           Because "your app" depends on "bar 1.0.0" which depends on "foo 1.0.0", "foo 1.0.0" is required.
           So, because "your app" depends on "foo ~> 2.0", version solving failed.\
           """
  end

  test "doesn't match any versions" do
    Registry.put("foo", "1.0.0", [{"bar", "~> 2.0"}])
    Registry.put("bar", "1.0.0", [])

    assert run([{"foo", "1.0.0"}]) == """
           Because every version of "foo" depends on "bar ~> 2.0" which doesn't match any versions, no version of "foo" is allowed.
           So, because "your app" depends on "foo 1.0.0", version solving failed.\
           """
  end

  test "linear error reporting" do
    Registry.put("foo", "1.0.0", [{"bar", "~> 2.0"}])
    Registry.put("bar", "2.0.0", [{"baz", "~> 3.0"}])
    Registry.put("baz", "1.0.0", [])
    Registry.put("baz", "3.0.0", [])

    assert run([{"foo", "~> 1.0"}, {"baz", "~> 1.0"}]) == """
           Because every version of "foo" depends on "bar ~> 2.0" which depends on "baz ~> 3.0", "foo" requires "baz ~> 3.0".
           And because "your app" depends on "baz ~> 1.0", no version of "foo" is allowed.
           So, because "your app" depends on "foo ~> 1.0", version solving failed.\
           """
  end

  test "branching error reporting" do
    Registry.put("foo", "1.0.0", [{"a", "~> 1.0"}, {"b", "~> 1.0"}])
    Registry.put("foo", "1.1.0", [{"x", "~> 1.0"}, {"y", "~> 1.0"}])
    Registry.put("a", "1.0.0", [{"b", "~> 2.0"}])
    Registry.put("b", "1.0.0", [])
    Registry.put("b", "2.0.0", [])
    Registry.put("x", "1.0.0", [{"y", "~> 2.0"}])
    Registry.put("y", "1.0.0", [])
    Registry.put("y", "2.0.0", [])

    assert run([{"foo", "~> 1.0"}]) == """
               Because "foo < 1.1.0" depends on "a ~> 1.0" which depends on "b ~> 2.0", "foo < 1.1.0" requires "b ~> 2.0".
           (1) So, because "foo < 1.1.0" depends on "b ~> 1.0", "foo < 1.1.0" is forbidden.

               Because "foo >= 1.1.0" depends on "x ~> 1.0" which depends on "y ~> 2.0", "foo >= 1.1.0" requires "y ~> 2.0".
               And because "foo >= 1.1.0" depends on "y ~> 1.0", "foo >= 1.1.0" is forbidden.
               And because "foo < 1.1.0" is forbidden (1), no version of "foo" is allowed.
               So, because "your app" depends on "foo ~> 1.0", version solving failed.\
           """
  end

  test "locked" do
    Registry.put("foo", "1.0.0", [])
    Registry.put("foo", "2.0.0", [])

    assert run([{"foo", "~> 2.0"}], [{"foo", "1.0.0"}]) == """
           Because "the lock" specifies "foo 1.0.0", "foo 1.0.0" is required.
           So, because "your app" depends on "foo ~> 2.0", version solving failed.\
           """
  end

  test "repo conflict" do
    Registry.put("foo", "1.0.0", [{"baz", "1.0.0", repo: "a"}])
    Registry.put("bar", "1.0.0", [{"baz", "1.0.0", repo: "b"}])
    Registry.put("a", "baz", "1.0.0", [])
    Registry.put("b", "baz", "1.0.0", [])

    assert run([{"foo", "1.0.0"}, {"bar", "1.0.0"}]) == """
           Because every version of "bar" depends on "b/baz 1.0.0" and every version of "foo" depends on "a/baz 1.0.0", "bar" is incompatible with "foo".
           And because "your app" depends on "bar 1.0.0", no version of "foo" is allowed.
           So, because "your app" depends on "foo 1.0.0", version solving failed.\
           """
  end

  test "sub dependencies" do
    Registry.put("foo", "1.0.0", [])
    Registry.put("foo", "2.0.0", [])

    assert run([
             {"top1", nil, dependencies: [{"foo", "~> 1.0"}]},
             {"top2", nil, dependencies: [{"foo", "~> 2.0"}]}
           ]) == """
           Because every version of "top1" depends on "foo ~> 1.0" and every version of "top2" depends on "foo ~> 2.0", "top1" is incompatible with "top2".
           And because "your app" depends on "top1", no version of "top2" is allowed.
           So, because "your app" depends on "top2", version solving failed.\
           """
  end

  # Projects consolidate String.Chars without the impls from archives, such as
  # Hex which vendors the solver, so formatting can't dispatch on solver structs
  test "formats failures without String.Chars dispatch on solver structs" do
    Registry.put("foo", "1.0.0", [{"bar", "~> 2.0 or ~> 3.0"}])
    Registry.put("bar", "1.0.0", [])
    Registry.put("bar", "2.0.0", [{"baz", "~> 2.0"}])
    Registry.put("baz", "1.0.0", [])

    dispatched =
      trace_string_chars(fn ->
        assert {:error, incompatibility} =
                 HexSolver.Solver.run(
                   Registry,
                   to_dependencies([{"foo", "~> 1.0"}, {"baz", "~> 1.0"}]),
                   [],
                   []
                 )

        Failure.write(incompatibility)
        Failure.write(incompatibility, ansi: true)
        inspect(incompatibility)
      end)

    assert dispatched != []
    refute Enum.any?(dispatched, &solver_struct?/1)
  end

  defp trace_string_chars(fun) do
    tracer = spawn_link(fn -> collect_string_chars([]) end)
    :erlang.trace_pattern({String.Chars, :to_string, 1}, true, [])
    :erlang.trace(self(), true, [:call, {:tracer, tracer}])

    try do
      fun.()
    after
      :erlang.trace(self(), false, [:call])
      :erlang.trace_pattern({String.Chars, :to_string, 1}, false, [])
    end

    ref = :erlang.trace_delivered(self())
    assert_receive {:trace_delivered, _pid, ^ref}
    send(tracer, {:values, self()})
    assert_receive {:values, values}
    values
  end

  defp collect_string_chars(values) do
    receive do
      {:trace, _pid, :call, {String.Chars, :to_string, [value]}} ->
        collect_string_chars([value | values])

      {:values, pid} ->
        send(pid, {:values, values})
    end
  end

  defp solver_struct?(%module{}), do: String.starts_with?(inspect(module), "HexSolver.")
  defp solver_struct?(_value), do: false
end
