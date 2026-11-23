# Standard compilation and CI

CI builds the production libraries with `just build-core` and shares them with
the tests. The representation job prepares the linked programs for the runtime
checks and benchmark studies.

Each test group runs its sources through `gerbil test`. The shared build
job also checks the build declarations and runs `gerbil test examples/t/...` through `just test-examples`. The
representation and benchmark jobs retain their separate workloads and
resource limits. The test matrix runs on cache hits as well.
The SCC benchmark compiles its timed test modules with their declared
compiler options before Gerbil runs the suites.

The official runner owns discovery, initialization, fixtures and case order.
Test modules with setup or cleanup retain their own boundaries. Failure checks
require successful case, module and harness markers and natural process exit.

The [test entrypoints](test-execution.md) describe local commands. The
[workflow](../.github/workflows/test.yml) declares artifact transfer, job
dependencies and compiler settings. The
[LeanPoo regrouping model](https://github.com/tao3k/lean-poo/blob/2652a2a531a6eec321f0d0665b5a5647d997cc07/LeanPoo/Prototype/BuildPreparation.lean#L140)
states the fixture-free composition contract.
