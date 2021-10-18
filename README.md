# Resolver

PubGrub based version solver.

To be used by [Hex](https://github.com/hexpm/hex).

**Still in development!**

### TODO

* Missing packages
* Package repositories
* Optional dependencies
* Overridden dependencies
* Locked dependencies
* Error reporting

### To investigate

* Handling of adjacent versions, specifically relating to pre-releases, see:
  https://github.com/dart-lang/pub/blob/205ea58cffe58feae757a99e382d0b8a5a11e3fa/lib/src/solver/reformat_ranges.dart#L20.
  May have to change `~>` to include pre-releases at the lower limit, so that
  `~> 1.0` would be equivalent to `>= 1.0.0-0 and < 2.0.0-0`, which means
  `~> 1.0 or ~> 2.0` would be equivalent to `>= 1.0.0-0 and < 3.0.0-0` with no
  gaps in the middle. The implications of this would be minimized if we sort by
  "best version" instead of "latest version", the "best version" would sort pre-releases
  (and possibly retired versions) last, see:
  https://github.com/dart-lang/pub/blob/f7fdcdd/lib/src/solver/package_lister.dart#L147.

### References

* [PubGrub: Next-Generation Version Solving](https://nex3.medium.com/pubgrub-2fb6470504f)
* [Solver documentation](https://github.com/dart-lang/pub/blob/master/doc/solver.md)
* [Dart solver implementation](https://github.com/dart-lang/pub)
* [Dart semver implementation](https://github.com/dart-lang/pub-semver)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `resolver` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:resolver, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/resolver>.

