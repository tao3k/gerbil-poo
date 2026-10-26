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

`just build library` and package installation compile the reusable library roots.
`gxi build.ss qualification` retains the complete library, example and benchmark
support inventory. On macOS, `test-program` puts that inventory and the executable
in one standard `defbuild-script` graph. This lets the released SDK reuse the same
compiled objects for loadable modules and the linked program. The complete
`just build` then compiles all eight disjoint test batches. Other platforms keep
their qualified-library and dynamically loaded runtime path.

`:std/build-script` owns dependency checks, caching and compiler scheduling.
`GERBIL_BUILD_CORES` keeps its standard machine-derived budget. The 1 GiB heap,
300-second compiler/runtime stages, complete inventory and process-group cleanup
remain unchanged. `just test-file` selects the standard harness with its 90-second
limit. Functional CI groups and the additional single-process job retain every
classified test; `t/test-groups.ss` owns the checked inventory.

One build job explicitly compiles the complete qualification inventory and publishes
this run's shared library. Independent compilation jobs
verify that artifact and compile disjoint test roots. Independent semantic jobs
and the complete single-process job then run concurrently against admitted
artifacts. Exact shared/test caches skip compilation only; checks always run. See [CI checks](doc/ci-checks.md).
Linux uses a SHA-256 pinned, already compiled gerbil-bazel release with verified
upstream revision. Darwin development uses its compatible installed compiler.
No compiler source build, companion Lean checkout or repository shell wrapper is
required. Compiler downloads and build artifacts stay outside Git. A PR commit
triggers one matrix run.

Standalone benchmark executables query `pkg-config --libs openssl` for the
released runtime's link dependencies, using Gerbil's `:std/make` helper in
`build.ss`. Install OpenSSL development metadata for that runtime and configure
`PKG_CONFIG_PATH` or `PKG_CONFIG_LIBDIR` when it is outside the toolchain's normal
search path. No Homebrew prefix or OpenSSL version is assumed. Executables use
the standard `$GERBIL_PATH/bin` destination. Ordinary library and test
builds do not need this executable-only discovery.
