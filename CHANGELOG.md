# CHANGELOG

## v0.2.0

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
