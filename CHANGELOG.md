# CHANGELOG

## v0.3.0 (2026-08-27)

### Enhancements

  * Add `HexSolver.constraint_to_requirement!/1` to serialize constraints as
    version requirements.
  * Parse `>= 0.0.0-0` as an unconstrained range and `< 0.0.0-0` as an empty
    constraint.
  * Accept intersections of pessimistic ranges such as `~> 1.0.0 and ~> 1.0`.
  * Raise `HexSolver.UnsatisfiableRequirementError` for requirements with
    disjoint ranges such as `~> 1.0 and >= 2.0.0`.
  * Require Elixir 1.12 or later.

### Bug fixes

  * Fix `FunctionClauseError` when parsing `and` chains with more than two
    terms, two bounds in the same direction, or `==`.
  * Fix infinite loop when a dependency has an empty constraint.

## v0.2.3 (2023-03-25)

### Enhancements

  * Add sub dependencies.

## v0.2.2 (2022-11-12)

### Bug fixes

  * Fix intersection of ranges during parsing.

## v0.2.1 (2022-11-10)

### Bug fixes

  * Do not override locked deps.
  * Change "lock" to "the lock" in failure message.
  * Raise when parsing intersected ranges.
  * Skip unselected optionals during solving.

## v0.2.0 (2022-09-25)

### Enhancements

  * Add support for package repositories (repos). Repos are the package source,
    so that if two packages with the same name but different repos are derived
    they will cause conflict.

### Breaking changes

  * `HexSolver.run/5` expects lists of maps instead of tuples in the
    `dependencies` and `locked` parameters.
  * `HexSolver.run/5` returns `{:ok, %{package() => {Version.t(), repo()}}` for
    for the success case instead of `{:ok, %{package() => Version.t()}}`.

## v0.1.0 (2022-07-20)

Initial version.
