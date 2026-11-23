# Standard build and test entrypoints

Run `gerbil build` or `just build` for the production libraries.
Run `just test-examples` for the `examples/*-test.ss` suites or pass a test file
to the same recipe. `just test-group methods` runs a directory.
Both delegate discovery and execution to `gerbil test` with the existing
2 GiB VM limit. `just test` runs the test groups using Just's parallel queue.

The representation benchmark package declares the artifacts used to test
compiled module loading. Gerbil owns compilation, runtime loading and cleanup.

## Property checks

Run `just test-group property` for generated checks of prototype overlays,
CLOS reconfiguration and typed packet encoding, plus the property workflow
and replay regressions. CI runs this package through the standard Gerbil runner.
Failures report the seed and shrunk inputs through the existing property helper.
