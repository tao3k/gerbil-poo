# Homebrew Gerbil is built with GCC on Darwin. Keep Nix SDK/header/library
# variables out of child compilations and make GCC's collect2 select Apple's
# system linker instead of a Nix-provided ld.
set shell := ["bash", "-euo", "pipefail", "-c"]

platform-env := if os() == "macos" { "env -u SDKROOT -u CPATH -u LIBRARY_PATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH -u MACOSX_DEPLOYMENT_TARGET COMPILER_PATH=/usr/bin" } else { "env" }
physical-cores := if os() == "macos" { `sysctl -n hw.physicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN` } else { `getconf _NPROCESSORS_ONLN` }
# Keep package compilation in this project's managed output unless explicitly selected.
export GERBIL_PATH := env_var_or_default("GERBIL_PATH", justfile_directory() + "/.build/package")
export GERBIL_BUILD_CORES := env_var_or_default("GERBIL_BUILD_CORES", physical-cores)
export GERBIL_BUILD_VERBOSE := env_var_or_default("GERBIL_BUILD_VERBOSE", "3")
test-max-heap := "1G"
test-debug := "q"
test-runtime-options := "-:max-heap=" + test-max-heap + ",debug=" + test-debug
timeout-executable := if os() == "macos" { `command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null || true` } else { `command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true` }

test: build
    just _test t 300

test-atomic name:
    just test-file "t/{{ name }}-test.ss"

test-file file:
    test -f "{{ file }}"
    just _test "{{ file }}" 90

_test target max-seconds:
    #!/usr/bin/env bash
    set -euo pipefail
    if test -z "{{ timeout-executable }}"; then echo "GNU timeout is required (install Homebrew coreutils on macOS)" >&2; exit 127; fi
    test_log="$(mktemp "${TMPDIR:-/tmp}/gerbil-poo-test.XXXXXX")"
    trap 'rm -f "$test_log"' EXIT
    {{ platform-env }} {{ timeout-executable }} --foreground --signal=TERM --kill-after=5s {{ max-seconds }}s gxi {{ test-runtime-options }} t/test-runner.ss "{{ target }}" 2>&1 | tee "$test_log"
    grep -q '^MODULE-OK ' "$test_log"
    grep -q '^HARNESS-OK ' "$test_log"
    grep -qx 'OK' "$test_log"
    if grep -Eq 'ERROR CASE|ERROR CHECK|ERROR HARNESS|Heap overflow|Stack overflow' "$test_log"; then exit 1; fi

benchmark-class-proto width='1000' samples='3':
    test -n "{{ timeout-executable }}" || { echo "GNU timeout is required" >&2; exit 127; }
    {{ platform-env }} {{ timeout-executable }} --foreground --signal=TERM --kill-after=5s 300s gxi {{ test-runtime-options }} ./t/class-proto-benchmark.ss "{{ width }}" "{{ samples }}"

benchmark-object-scale: (build "library")
    just _build-benchmark object-scale-benchmark 300
    {{ platform-env }} {{ timeout-executable }} --foreground --signal=TERM --kill-after=5s 90s "$GERBIL_PATH/bin/object-scale-benchmark"

# Use the same standard graph and default executable directory for every study.
# Retain each recipe's compiler deadline and the shared 1 GiB expansion bound.
_build-benchmark target max-seconds='90':
    test -n "{{ timeout-executable }}" || { echo "GNU timeout is required" >&2; exit 127; }
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s {{ max-seconds }}s gxi {{ test-runtime-options }} build.ss benchmark "{{ target }}"

clean:
    {{ platform-env }} gxi build.ss clean

build *selection:
    test -n "{{ timeout-executable }}" || { echo "GNU timeout is required" >&2; exit 127; }
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 1200s gxi {{ test-runtime-options }} t/build.ss "{{ timeout-executable }}" "{{ test-runtime-options }}" {{ selection }}

# Compile disjoint test roots into a separate artifact, retaining the shared imports.
build-group group:
    just build tests "{{ group }}" "$PWD/.ci-tests/{{ group }}/lib"

# Standalone Scheme matrix; no companion checkout is required.
benchmark-closure: build
    test -n "{{ timeout-executable }}" || { echo "GNU timeout is required" >&2; exit 127; }
    mkdir -p .build/closure
    just _build-benchmark closure-scale-benchmark
    {{ platform-env }} gxi {{ test-runtime-options }} t/closure-suite.ss "$GERBIL_PATH/bin/closure-scale-benchmark" "{{ timeout-executable }}" .build/closure/closure-benchmarks.scm

# Same-process warm comparisons with balanced queue order and bounded children.
benchmark-closure-paired: build
    mkdir -p .build/closure
    just _build-benchmark closure-paired-benchmark
    {{ platform-env }} gxi {{ test-runtime-options }} t/closure-paired-suite.ss "$GERBIL_PATH/bin/closure-paired-benchmark" "{{ timeout-executable }}" .build/closure/closure-paired.scm

# Gambit CPU/GC/allocation phases, with natural and pre-collected controls.
benchmark-closure-phases: build
    mkdir -p .build/closure
    just _build-benchmark closure-phases
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 20s "$GERBIL_PATH/bin/closure-phases" -:max-heap=1G .build/closure/closure-phases.scm

# Standalone Scheme signature/negative-watch costs; no Lean checkout required.
benchmark-dispatch: build
    test -n "{{ timeout-executable }}" || { echo "GNU timeout is required" >&2; exit 127; }
    mkdir -p .build/dispatch
    just _build-benchmark dispatch-benchmark
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 20s "$GERBIL_PATH/bin/dispatch-benchmark" -:max-heap=1G .build/dispatch/dispatch-benchmarks.scm "$GERBIL_PATH/bin/dispatch-benchmark"

# Composed metadata wrappers and complete cooked-family publication costs.
benchmark-metadata:
    mkdir -p .build/metadata
    printf '%s\n' '(metadata-benchmarks (status incomplete))' > .build/metadata/metadata-benchmarks.scm
    test -n "{{ timeout-executable }}" || { echo "GNU timeout is required" >&2; exit 127; }
    just build
    just _build-benchmark metadata-benchmark
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 20s "$GERBIL_PATH/bin/metadata-benchmark" -:max-heap=1G .build/metadata/metadata-benchmarks.scm "$GERBIL_PATH/bin/metadata-benchmark"
    {{ platform-env }} gxi {{ test-runtime-options }} t/metadata-report.ss .build/metadata/metadata-benchmarks.scm

benchmark-metadata-paired:
    mkdir -p .build/metadata
    printf '%s\n' '(metadata-paired (status incomplete))' > .build/metadata/metadata-paired.scm
    test -n "{{ timeout-executable }}" || { echo "GNU timeout is required" >&2; exit 127; }
    just build
    just _build-benchmark metadata-paired-benchmark
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gxi {{ test-runtime-options }} t/metadata-paired-suite.ss "$GERBIL_PATH/bin/metadata-paired-benchmark" "{{ timeout-executable }}" .build/metadata/metadata-paired.scm

# Whole continuation preparation and reused calls, with fresh-process ABBA/A-A controls.
benchmark-combination: build
    mkdir -p .build/combination
    just _build-benchmark combination-benchmark
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=5s 300s gxi {{ test-runtime-options }} t/combination-suite.ss "$GERBIL_PATH/bin/combination-benchmark" "{{ timeout-executable }}" .build/combination/results.scm

# Standard source harness against the current shared library, before compiling
# the test group. Use the configured Gerbil installation without load-path edits.
test-source-file file: (build "library")
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp "${TMPDIR:-/tmp}/poo-source-test.XXXXXX")"
    trap 'rm -f "$log"' EXIT
    {{ platform-env }} {{ timeout-executable }} --foreground --signal=TERM --kill-after=5s 90s gerbil {{ test-runtime-options }} test "{{ file }}" 2>&1 | tee "$log"
    grep -F 'MODULE-OK {{ file }}' "$log"
    grep -F 'HARNESS-OK' "$log"
    grep -x 'OK' "$log"
    if grep -Eq 'ERROR (CASE|CHECK|HARNESS)|Heap overflow|Stack overflow' "$log"; then exit 1; fi

# Reuse the compiled feedback test module; avoid static relinking and repeated
# interpreter startup. This uses the existing focused-test heap/deadline bounds.
benchmark-scc: build
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gxi {{ test-runtime-options }} :clan/poo/t/feedback-graph-test
