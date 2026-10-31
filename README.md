# Gerbil-POO

Gerbil-POO is an implementation of Prototype Object Orientation for Gerbil.
This object model is directly inspired by that of Nix, isomorphic to that of Jsonnet.

### Copyright and License

Copyright 2020 François-René Rideau
Gerbil-POO is distributed under the Apache License, version 2.0. See the file [LICENSE](LICENSE).

### Documentation

The [Scheme Workshop 2021 video](https://youtu.be/2szKoUQoNm8) and the
[associated paper](https://github.com/metareflection/poof).

[Prototype Object Orientation in Gerbil Scheme](doc/poo.md),
a document explaining Gerbil-POO.

[Prototype Object Programming in Gerbil Scheme](doc/prototypes.md),
notes from a talk at LispNYC in November 2020.

### Property testing and debugging

PBT is included in the default `gerbil build` and complete project checks.
Use the existing POO test helper with ordinary Gerbil modules and `:std/test`:

```scheme
(export service-test)
(import :std/test
        (prefix-in :clan/poo/support/testing pbt.)
        (only-in :clan/poo/type List)
        (only-in :clan/poo/number UInt))

;; Fixed Type arguments use the same bounded generator and shrinking protocol.
(pbt.define-property reverse-roundtrip ((payload (List UInt)))
  (equal? (reverse (reverse payload)) payload))

;; Gerbil owns test discovery, reporting and execution.
(def service-test
  (test-suite "service properties"
    (test-case "reverse roundtrip" (reverse-roundtrip seed: 42 cases: 100))))
```

Build your module with standard `defbuild-script`, then use `gerbil test` for its
suite. `just check` retains this project's complete bounded acceptance. Named
properties and `pbt.check-property` raise standard test failures for every
non-passing result; report data remain available from `testing/type`.

`debug` also provides `property-debug-action`, composed with the existing FUN
Reader and DDT renderer. Configure it with
`(make-instance PropertyConfiguration seed: 42 cases: 20)` from `testing/type`.
A false debug tag disables rendering while still executing the explicitly called
action. Configuration revisions are captured as sources, so edits during a run
refuse admission. Loading a module defines these tools; generation starts at the
explicit test/action call. See [the downstream guide](doc/property-kernel.md),
[Record/FUN examples](examples/generated-batches.ss), and the
[PBT design RFC](doc/pbt-design-rfc.md).

### HACKING

If you'd like to build your own object system, with its own optimized meta-object protocol
to implement objects efficiently, come join the team!

See the [doc/TODO.md](doc/TODO.md) document for projects.

### Structural value contracts

[`object-contract`](doc/object-contracts.md) adds structural responsibilities and
diagnostics over existing POO Types, with optional prototype requirements and
reuse of the existing checked invocation Contract. It is independent of any
configuration framework; Schema adapters remain separate libraries.

### Finite cyclic construction

[`closure`](doc/closure.md) provides positive Boolean closure with private compiled
metadata, owned byte state, allocation-aware queue selection, immutable public
snapshots, retained-topology revisions, POO workflow controls and Scheme benchmarks.
This advances generalized-prototype future work with a bounded Lean cost-model
companion; it does not change ordinary prototype recursion.

### Scheme CI

Use `gerbil build`, `gerbil clean` and `gerbil test`. Each `build.ss` declares its
inputs with `defbuild-script`; `std/make` owns dependency order, timestamps,
compilation and artifact reuse. There is no additional source scanner, hash
ledger, manifest parser, copied source view or test runner.

`just build` prepares the root library package, the benchmark executable package

See [test execution](doc/test-execution.md) and [CI checks](doc/ci-checks.md).

Standalone executables use `pkg-config --libs openssl` through `std/make`.
Configure the toolchain’s standard pkg-config search path for your installation;
no platform-specific OpenSSL prefix is embedded.
