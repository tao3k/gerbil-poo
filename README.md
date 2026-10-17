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

`bazel test //:test` builds the declared `build.ss` modules and runs every test
module in a separate standard Scheme harness process, with its own failure status
and 90-second limit. Seventeen functional groups run as independent GitHub jobs;
`bazel test //:recovery` selects one group, and `bazel test //:coordinator-prepared_test`
selects a single module. The declaration checks that every test belongs to exactly
one group, so new modules cannot silently escape CI.

One build job publishes this run's compiled library to the dependent test jobs.
Each job verifies the producer revision and restores that declared artifact;
test jobs contain no library compilation action. See [CI checks](doc/ci-checks.md).
Linux uses a SHA-256 pinned, already compiled gerbil-bazel release with verified
upstream revision. Darwin development uses its compatible installed compiler.
No compiler source build, companion Lean checkout or repository shell wrapper is
required. Generated outputs and dependency lockfiles are ignored; toolchain and
build caches stay outside Git. A PR commit triggers one matrix run.
