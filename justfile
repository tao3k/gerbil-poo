# Public commands delegate to Gerbil; task recipes retain only deadlines and progress.
set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments
platform-env := if os() == "macos" { "env -u SDKROOT -u CPATH -u LIBRARY_PATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH -u MACOSX_DEPLOYMENT_TARGET COMPILER_PATH=/usr/bin" } else { "env" }
physical-cores := if os() == "macos" { `sysctl -n hw.physicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN` } else { `getconf _NPROCESSORS_ONLN` }
export GERBIL_PATH := env_var_or_default("GERBIL_PATH", justfile_directory() + "/.build/package")
export GERBIL_BUILD_CORES := env_var_or_default("GERBIL_BUILD_CORES", physical-cores)
export GERBIL_BUILD_VERBOSE := env_var_or_default("GERBIL_BUILD_VERBOSE", "3")
test-runtime-options := "-:max-heap=1G,debug=q"
timeout-executable := if os() == "macos" { `command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null || true` } else { `command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true` }

build-core:
    test -n "{{ timeout-executable }}" || { echo "GNU timeout is required" >&2; exit 127; }
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 300s gerbil {{ test-runtime-options }} build

build-shared: build-core
    cd benchmarks/representation-startup && {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gerbil {{ test-runtime-options }} build

# Standalone studies use their ordinary compiler packages only when requested.
build-benchmarks group: build-core
    cd "benchmarks/$1" && {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gerbil {{ test-runtime-options }} build

# Standard package commands preserve the original total job/heap budget.
# Each phase is at most 300 seconds, preserving the 1200-second whole-build bound.
build: build-shared
    #!/usr/bin/env bash
    set -euo pipefail
    [[ "$GERBIL_BUILD_CORES" =~ ^[0-9]+$ ]] || { echo "GERBIL_BUILD_CORES must be a nonnegative integer" >&2; exit 2; }
    cores=$((10#$GERBIL_BUILD_CORES))
    workers=2
    if (( cores < workers )); then workers=1; fi
    budget=$(( cores / workers ))
    # Trade at least one backend slot for one frontend. Both the total process
    # count and the 1G frontend + 2G backend heap bound decrease or stay equal.
    if (( cores >= 6 )); then
      budget=$(( (workers * budget - 1) / 3 ))
      workers=3
    fi
    printf '%s\0' t/*/gerbil.pkg | env GERBIL_BUILD_CORES="$budget" {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 300s xargs -0 -P "$workers" -n 1 sh -c 'cd "$(dirname "$1")" && exec gerbil {{ test-runtime-options }} build' build

# CI has already prepared the shared package; no hidden rebuild or copied view.
build-group group:
    cd "t/$1" && {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 300s gerbil {{ test-runtime-options }} build

test: build
    just _test 300 "$GERBIL_PATH/lib/clan/poo/t/"*/*-test.ssi

test-file file:
    just _test 90 "$1"

test-group group:
    just _test 300 "t/$1"

test-atomic name:
    just _test 90 "$GERBIL_PATH/lib/clan/poo/t/"*/"$1-test.ssi"

# The official runner owns discovery, fixtures, cases and failures. This boundary
# retains its verbose progress and refuses empty or unsuccessful executions.
_test max-seconds +targets:
    #!/usr/bin/env bash
    set -euo pipefail
    seconds="$1"
    shift
    log="$(mktemp "${TMPDIR:-/tmp}/gerbil-poo-test.XXXXXX")"
    trap 'rm -f "$log"' EXIT
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=5s "${seconds}s" gerbil {{ test-runtime-options }} test -v 5 "$@" 2>&1 | tee "$log"
    grep -q '^MODULE-OK ' "$log"
    grep -q '^CASE-OK ' "$log"
    grep -q '^HARNESS-OK ' "$log"
    grep -qx 'OK' "$log"
    if grep -Eq '^ERROR |\*\*\* ERROR|Heap overflow|Stack overflow' "$log"; then exit 1; fi

test-source-file file: build-shared
    just _test 90 "$1"

check width='2' samples='1' pairs='4': build (check-built width samples pairs)

check-built width='2' samples='1' pairs='4':
    just _test 300 "$GERBIL_PATH/lib/clan/poo/t/"*/*-test.ssi
    just _run-collections "$1" "$2" "$3"

_run-collections width samples pairs:
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 300s "$GERBIL_PATH/bin/representation-main" {{ test-runtime-options }} clan/poo/benchmarks/collection-paired-benchmark 'clan/poo/benchmarks/collection-paired-benchmark#main' "$1" "$2" "$3"

clean:
    printf '%s\0' t/*/gerbil.pkg benchmarks/*/gerbil.pkg gerbil.pkg | {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 300s xargs -0 -n 1 sh -c 'cd "$(dirname "$1")" && exec gerbil {{ test-runtime-options }} clean' clean

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
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 300s gerbil {{ test-runtime-options }} test -v 5 benchmarks/representation-startup.ss

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
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gerbil {{ test-runtime-options }} test -v 5 benchmarks/scc-test.ss

# Standard test execution of the fixed higher-resolution offset study.
benchmark-slot-offset: build-shared
    just _test 300 benchmarks/slot-offset-test.ss
