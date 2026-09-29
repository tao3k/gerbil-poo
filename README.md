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

### MOP imports

`(import :clan/poo/mop)` remains the full MOP entry, including JSON string
encoding and decoding. Code that uses native type descriptors, `define-type`,
`element?`, or `validate` without JSON string conversion can import
`:clan/poo/mop-core`. Both entries use the same POO type objects, so a process
may import the full entry later. JSON string conversion through a descriptor
requires the full entry to have been imported.

The smaller entry avoids loading Gerbil's JSON reader and writer during module
initialization. It is intended for contract-heavy modules whose normal path
does not serialize JSON; it does not change the behavior of the full entry.

### HACKING

If you'd like to build your own object system, with its own optimized meta-object protocol
to implement objects efficiently, come join the team!

See the [doc/TODO.md](doc/TODO.md) document for projects.
