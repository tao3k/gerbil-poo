# Independent Scheme checks

CI compiles `//:library` once, then runs every `t/*-test.ss` module in its own
Bazel test process across the existing seventeen functional groups. The exact
partition check rejects missing or duplicate modules. Failed groups do not cancel
their siblings; the harness exit status, per-module timeout and diagnostics remain
in force.

Test runners consume the successful build job's compiled project, build receipt
and log through an ephemeral artifact named for the checked commit. Before Bazel
analysis, each runner verifies the producer revision against its actual checkout.
`scheme-build.bzl` supplies the existing `GerbilProjectInfo` provider by extracting
that declared archive input. The test graph contains no compiler action in this
mode; a missing artifact fails instead of silently recompiling. All runners use
the same pinned Linux compiler artifact and Ubuntu platform. This is per-run
artifact transport, not cross-revision admission or a portable binary release.

The previous disk-cache transport could miss because the upstream compile action
includes host environment and toolchain receipts (including host capacity). A
cache miss therefore cannot reliably mean that project source changed. Passing
the successful producer's output directly removes that repeated compilation
without falsifying host metadata or weakening the upstream resource guard.

Local `bazel test //:test` still compiles normally. Compilation inputs exclude
standalone `*-test.ss` files; compiled test-support modules declared by `build.ss`
remain inputs. Test runfiles retain all source files used by report validation
and examples. Thus changing a test still reruns its test action without forcing
library recompilation.

The downloaded `.ci-library/` directory is ignored. Archives, generated receipts
and full logs are short-lived Actions artifacts and are never committed.
