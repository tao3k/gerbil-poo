# Standard build and test entrypoints

Run `gerbil build` or `just build` for the production libraries.
Run `just test-examples` for the `examples/*-test.ss` suites or pass a test file
to the same recipe. `just test-group methods` runs a directory.
Both delegate discovery and execution to `gerbil test` with the existing
2 GiB VM limit. `just test` runs the test groups using Just's parallel queue.

The representation benchmark package declares the artifacts used to test
compiled module loading. Gerbil owns compilation, runtime loading and cleanup.

The following policy records an earlier test configuration.

## Test execution policy, 2026-11-01

The user removed fixed test-runner wall deadlines. `test`, `test-group`,
`test-file`, `check` and `check-built` now run the official harness to natural
completion, retaining verbose progress, error checks and the 2-GiB heap limit.
CI semantic jobs use GitHub's platform default instead of a project job timeout.
Compilation still retains its 300-second deadline;
program builds and workload-specific negative controls keep their own bounds.

Descriptor intrinsic and scalar Union fixtures compile as ordinary internal
modules. Their original aggregate modules re-export the same suites. There are
66 declared compilation units and the same 62 discovered test roots. The two
private fixture scopes, every case and the aggregate export order are retained.
These are standard module dependencies, with included source bodies explicitly
tracked by `std/make`, rather than a new scheduler or test framework.
