# Public commands delegate to Gerbil; task recipes retain only deadlines and progress.
set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments
platform-env := if os() == "macos" { "env -u SDKROOT -u CPATH -u LIBRARY_PATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH -u MACOSX_DEPLOYMENT_TARGET COMPILER_PATH=/usr/bin" } else { "env" }
physical-cores := if os() == "macos" { `sysctl -n hw.physicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN` } else { `getconf _NPROCESSORS_ONLN` }
export GERBIL_PATH := env_var_or_default("GERBIL_PATH", justfile_directory() + "/.build/package")
export GERBIL_BUILD_CORES := env_var_or_default("GERBIL_BUILD_CORES", physical-cores)
export GERBIL_BUILD_VERBOSE := env_var_or_default("GERBIL_BUILD_VERBOSE", "3")
test-context-limit := if os() == "macos" { "2" } else { "4" }
test-context-recipe := if os() == "macos" { "_test-shared-packages" } else { "_test-packages" }
test-runtime-options := "-:max-heap=2G,debug=q"
timeout-executable := if os() == "macos" { `command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null || true` } else { `command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true` }

# Packaging assertions belong to task management, not runtime TestSuites.
check-layout:
    #!/usr/bin/env bash
    set -euo pipefail
    for module in testing/type.ss testing/function.ss testing/generation-graph.ss testing/recursive-generation.ss; do test -f "$module"; done
    for retired in property-testing.ss function-testing.ss generation-graph.ss recursive-generation.ss; do test ! -e "$retired"; done
    for module in testing/property.ss testing/property/{generator,model,replay,test}.ss; do test -f "$module"; done
    test ! -e testing/core
    printf 'LAYOUT-OK\n'

build-core: check-layout
    #!/usr/bin/env bash
    set -euo pipefail
    test -n "{{ timeout-executable }}" || { echo "GNU timeout is required" >&2; exit 127; }
    if /usr/bin/time -p {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 300s gerbil -:max-heap=2G,debug=q build; then
        exit 0
    else
        build_status=$?
        # Standard make may publish interface markers before a backend fails.
        # Invalidate its declared outputs so retry cannot admit a partial build.
        printf 'BUILD-CLEANUP root-preparation status=%s\n' "$build_status" >&2
        if ! {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gerbil -:max-heap=2G,debug=q clean; then
            printf 'BUILD-CLEANUP root failed; standard clean is still required\n' >&2
        fi
        exit "$build_status"
    fi

build-shared: build-core
    cd benchmarks/representation-startup && /usr/bin/time -p {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gerbil {{ test-runtime-options }} build

# Standalone studies use their ordinary compiler packages only when requested.
build-benchmarks group: build-core
    cd "benchmarks/$1" && {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gerbil {{ test-runtime-options }} build

# Bounded standard compiler packages reuse imports without retaining every test
# source in one heap. Just owns parallel dependencies; Gerbil owns each make graph.
build: build-shared
    #!/usr/bin/env bash
    set -euo pipefail
    [[ "$GERBIL_BUILD_CORES" =~ ^[0-9]+$ ]] || { echo "GERBIL_BUILD_CORES must be a nonnegative integer" >&2; exit 2; }
    cores=$((10#$GERBIL_BUILD_CORES))
    workers=$((cores / 3))
    if (( workers < 1 )); then workers=1; elif (( workers > 4 )); then workers=4; fi
    backends=$((cores / workers - 1))
    if (( backends < 1 )); then backends=1; fi
    printf 'BUILD-CONCURRENCY cores=%s packages=%s backends=%s\n' "$cores" "$workers" "$backends"
    # Zero disables only the aggregate wall deadline. GNU timeout still owns
    # the process group and forwards cancellation, with the existing kill grace.
    if /usr/bin/time -p env GERBIL_BUILD_CORES="$backends" {{ timeout-executable }} --signal=TERM --kill-after=3s 0 just --jobs "$workers" _build-test-packages; then
        exit 0
    else
        build_status=$?
        # Standard make's interface marker can survive an interrupted backend.
        # Its clean action invalidates the same declared outputs before retry.
        printf 'BUILD-CLEANUP failed-preparation status=%s\n' "$build_status" >&2
        if ! env GERBIL_BUILD_CORES="$backends" {{ timeout-executable }} --signal=TERM --kill-after=3s 90s just --jobs "$workers" _build-test-packages clean; then
            printf 'BUILD-CLEANUP failed; standard clean is still required\n' >&2
        fi
        exit "$build_status"
    fi

# Four standard make graphs reuse shared compiler contexts instead of launching
# two additional frontends. Canonical runtime packages and every source stay fixed.
[parallel]
_build-test-packages action='build': (_build-test-package "contracts" action) (_build-test-package "types" action) (_build-test-package "prototypes" action) (_build-test-package "collections" action)

# The outer signal supervisor owns the compiler process group without a wall
# deadline; nested timeout groups must not outlive cancellation or failure.
_build-test-package part action='build':
    #!/usr/bin/env bash
    set -euo pipefail
    cd "t/build/$1"
    printf 'BUILD-PACKAGE-START %s action=%s\n' "$1" "$2"
    # Bash's built-in time labels each real completion without another watchdog.
    TIMEFORMAT="BUILD-PACKAGE-TIME $1 real=%R user=%U sys=%S"
    time {{ platform-env }} gerbil {{ test-runtime-options }} "$2"

# CI has already prepared the shared package; no hidden rebuild or copied view.
build-group group:
    cd "t/$1" && {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 300s gerbil {{ test-runtime-options }} build

# Test execution runs to completion; compilation keeps its separate deadline.
test: build
    just _test-parallel

# Retain cross-module shared-state admission independently of parallel throughput.
test-single-process: build
    just _test "$GERBIL_PATH/lib/clan/poo/t/"*/*-test.ssi

# Reuse the four established compiler partitions and Just's standard queue.
_test-parallel:
    #!/usr/bin/env bash
    set -euo pipefail
    [[ "$GERBIL_BUILD_CORES" =~ ^[0-9]+$ ]] || { echo "GERBIL_BUILD_CORES must be a nonnegative integer" >&2; exit 2; }
    workers=$((10#$GERBIL_BUILD_CORES))
    if (( workers < 1 )); then workers=1; elif (( workers > {{ test-context-limit }} )); then workers={{ test-context-limit }}; fi
    printf 'TEST-CONCURRENCY cores=%s packages=%s heap=2G\n' "$GERBIL_BUILD_CORES" "$workers"
    /usr/bin/time -p just --jobs "$workers" {{ test-context-recipe }}

[parallel]
_test-packages: (_test-groups "backends" "collection-deltas" "collection-styles" "collections" "coordination" "recovery" "revisions" "publication" "tools") (_test-groups "collection-order" "collection-updates" "closure" "construction" "objects" "generalized" "components" "feedback" "recursion") (_test-groups "contracts" "methods" "signatures") (_test-groups "declarations" "inference" "representations" "scalars")

# Select compiled interfaces only; fixtures and case execution remain in gxtest.
_test-groups +groups:
    #!/usr/bin/env bash
    set -euo pipefail
    targets=()
    for group in "$@"; do targets+=("$GERBIL_PATH/lib/clan/poo/t/$group/"*-test.ssi); done
    just _test-run "${targets[@]}"

test-file file:
    just _test "$1"

# Use the group's prepared interfaces; loading the source directory repeats
# expansion even when CI has already downloaded the complete compiler artifact.
test-group group:
    just _test "$GERBIL_PATH/lib/clan/poo/t/$1/"*-test.ssi

test-atomic name:
    just _test "$GERBIL_PATH/lib/clan/poo/t/"*/"$1-test.ssi"

# The official runner owns discovery, fixtures, cases and failures. This boundary
# retains its verbose progress and refuses empty or unsuccessful executions.
_test +targets:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/time -p just _test-run "$@"

# Serial and parallel official invocations share the same result boundary.
_test-run +targets:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp "${TMPDIR:-/tmp}/gerbil-poo-test.XXXXXX")"
    trap 'rm -f "$log"' EXIT
    {{ platform-env }} gerbil {{ test-runtime-options }} test -v 5 "$@" 2>&1 | tee "$log"
    grep -q '^MODULE-OK ' "$log"
    grep -q '^CASE-OK ' "$log"
    grep -q '^HARNESS-OK ' "$log"
    grep -qx 'OK' "$log"
    if grep -Eq '^ERROR |\*\*\* ERROR|Heap overflow|Stack overflow' "$log"; then exit 1; fi

test-source-file file: build-shared
    just _test "$1"

check width='2' samples='1' pairs='4': build (check-parallel-built width samples pairs)

# CI keeps the whole shared-state harness; throughput does not replace this gate.
check-single-process width='2' samples='1' pairs='4': build (check-built width samples pairs)

check-parallel-built width='2' samples='1' pairs='4': check-layout
    just _test-parallel
    just _test t/build-test.ss
    just _run-collections "$1" "$2" "$3"
    just _run-generators 8 2

check-built width='2' samples='1' pairs='4': check-layout
    just _test "$GERBIL_PATH/lib/clan/poo/t/"*/*-test.ssi
    just _test t/build-test.ss
    just _run-collections "$1" "$2" "$3"
    just _run-generators 8 2

# Shared executable and module-action own loading; no new test or benchmark runner.
benchmark-generators repetitions='20' pairs='4': build-shared
    just _run-generators "$1" "$2"

_run-generators repetitions pairs:
    /usr/bin/time -p {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 300s "$GERBIL_PATH/bin/representation-main" {{ test-runtime-options }} clan/poo/benchmarks/generation-benchmark 'clan/poo/benchmarks/generation-benchmark#main' "$1" "$2"

_run-collections width samples pairs:
    /usr/bin/time -p {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 300s "$GERBIL_PATH/bin/representation-main" {{ test-runtime-options }} clan/poo/benchmarks/collection-paired-benchmark 'clan/poo/benchmarks/collection-paired-benchmark#main' "$1" "$2" "$3"

clean:
    printf '%s\0' t/build/*/gerbil.pkg benchmarks/*/gerbil.pkg gerbil.pkg | {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 300s xargs -0 -n 1 sh -c 'cd "$(dirname "$1")" && exec gerbil {{ test-runtime-options }} clean' clean

benchmark-collections width='64' samples='10' pairs='6': build-shared (_run-collections width samples pairs)

benchmark-class-proto width='1000' samples='3': (build-benchmarks "class-proto")
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=5s 300s "$GERBIL_PATH/bin/class-proto-benchmark" {{ test-runtime-options }} "$1" "$2"

benchmark-object-scale: (build-benchmarks "object-scale")
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=5s 90s "$GERBIL_PATH/bin/object-scale-benchmark" {{ test-runtime-options }}

example-representation: build-shared
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s "$GERBIL_PATH/bin/representation-main" {{ test-runtime-options }} clan/poo/examples/representation-service 'clan/poo/examples/representation-service#main' 64 symbolic
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s "$GERBIL_PATH/bin/representation-main" {{ test-runtime-options }} clan/poo/examples/representation-service 'clan/poo/examples/representation-service#main' 64 indexed
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s "$GERBIL_PATH/bin/representation-main" {{ test-runtime-options }} clan/poo/examples/representation-service 'clan/poo/examples/representation-service#joint-main' 64 symbolic
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s "$GERBIL_PATH/bin/representation-main" {{ test-runtime-options }} clan/poo/examples/representation-service 'clan/poo/examples/representation-service#joint-main' 64 indexed

benchmark-representation-startup: build-shared
    {{ platform-env }} gerbil {{ test-runtime-options }} test -v 5 benchmarks/representation-startup.ss

benchmark-closure: (build-benchmarks "closure")
    mkdir -p .build/closure
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 300s "$GERBIL_PATH/bin/closure-suite" {{ test-runtime-options }} "$GERBIL_PATH/bin/closure-scale-benchmark" "{{ timeout-executable }}" .build/closure/closure-benchmarks.scm

benchmark-closure-paired: (build-benchmarks "closure")
    mkdir -p .build/closure
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 300s "$GERBIL_PATH/bin/closure-paired-suite" {{ test-runtime-options }} "$GERBIL_PATH/bin/closure-paired-benchmark" "{{ timeout-executable }}" .build/closure/closure-paired.scm

benchmark-closure-phases: (build-benchmarks "closure")
    mkdir -p .build/closure
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 20s "$GERBIL_PATH/bin/closure-phases" {{ test-runtime-options }} .build/closure/closure-phases.scm

benchmark-dispatch: (build-benchmarks "dispatch")
    mkdir -p .build/dispatch
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 20s "$GERBIL_PATH/bin/dispatch-benchmark" {{ test-runtime-options }} .build/dispatch/dispatch-benchmarks.scm "$GERBIL_PATH/bin/dispatch-benchmark"

benchmark-metadata: (build-benchmarks "metadata")
    mkdir -p .build/metadata
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 20s "$GERBIL_PATH/bin/metadata-benchmark" {{ test-runtime-options }} .build/metadata/metadata-benchmarks.scm "$GERBIL_PATH/bin/metadata-benchmark"
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s "$GERBIL_PATH/bin/metadata-report" {{ test-runtime-options }} .build/metadata/metadata-benchmarks.scm

benchmark-metadata-paired: (build-benchmarks "metadata")
    mkdir -p .build/metadata
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s "$GERBIL_PATH/bin/metadata-paired-suite" {{ test-runtime-options }} "$GERBIL_PATH/bin/metadata-paired-benchmark" "{{ timeout-executable }}" .build/metadata/metadata-paired.scm

benchmark-combination: (build-benchmarks "combination")
    mkdir -p .build/combination
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=5s 300s "$GERBIL_PATH/bin/combination-suite" {{ test-runtime-options }} "$GERBIL_PATH/bin/combination-benchmark" "{{ timeout-executable }}" .build/combination/results.scm

benchmark-scc: build
    {{ platform-env }} gerbil {{ test-runtime-options }} test -v 5 benchmarks/scc-test.ss

# Standard test execution of the fixed higher-resolution offset study.
benchmark-slot-offset: build-shared
    just _test benchmarks/slot-offset-test.ss

# Fixed indexed-deletion study through the ordinary runner and shared producer.
benchmark-prototype-map: build-shared
    just _test benchmarks/prototype-map-test.ss

# Private traversal and immutable-map composition share the full standard sampler.
benchmark-prototype-traversal: build-shared
    just _test benchmarks/prototype-traversal-test.ss

# Higher-resolution complete publication retains the same paired controls.
benchmark-prototype-composition: build-shared
    just _test benchmarks/prototype-composition-test.ss

# Structural snapshots and private enumeration use the same standard test entry.
benchmark-names: build-shared
    just _test benchmarks/names-test.ss

# Explicit and opaque SlotSpec encodings retain full construction and publication.
benchmark-slot-construction: build-shared
    just _test benchmarks/slot-construction-test.ss

# Catalog capture, clone, reflection and checked module publication remain paired.
benchmark-prototype-catalog: build-shared
    just _test benchmarks/prototype-catalog-test.ss

# Point metadata lookup includes cold preparation, observation and full workflows.
benchmark-declaration-index: build-shared
    just _test benchmarks/declaration-index-test.ss

# Longer cold/full workflow confirmation retains the ordinary bounded test entry.
benchmark-cold-query: build-shared
    just _test benchmarks/cold-query-test.ss

# Darwin shares common module initialization between existing partitions.
# The official runner and each original fixture/case remain unchanged.
[parallel]
_test-shared-packages: (_test-groups "backends" "collection-deltas" "collection-styles" "collections" "coordination" "recovery" "revisions" "publication" "tools" "declarations" "inference" "representations" "scalars") (_test-groups "collection-order" "collection-updates" "closure" "construction" "objects" "generalized" "components" "feedback" "recursion" "contracts" "methods" "signatures")
