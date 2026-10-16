# Homebrew Gerbil is built with GCC on Darwin. Keep Nix SDK/header/library
# variables out of child compilations and make GCC's collect2 select Apple's
# system linker instead of a Nix-provided ld.
set shell := ["bash", "-euo", "pipefail", "-c"]

platform-env := if os() == "macos" { "env -u SDKROOT -u CPATH -u LIBRARY_PATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH -u MACOSX_DEPLOYMENT_TARGET COMPILER_PATH=/usr/bin" } else { "env" }
physical-cores := if os() == "macos" { `sysctl -n hw.physicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN` } else { `getconf _NPROCESSORS_ONLN` }
export GERBIL_BUILD_CORES := env_var_or_default("GERBIL_BUILD_CORES", physical-cores)
build-verbose := env_var_or_default("GERBIL_BUILD_VERBOSE", "3")
build-env := platform-env + " GERBIL_BUILD_VERBOSE=" + build-verbose
test-max-heap := env_var_or_default("GERBIL_TEST_MAX_HEAP", "1G")
test-debug := env_var_or_default("GERBIL_TEST_DEBUG", "q")
test-runtime-options := "-:max-heap=" + test-max-heap + ",debug=" + test-debug
closure-ld-options := env_var_or_default("GERBIL_CLOSURE_LD_OPTIONS", if os() == "macos" { "-L/opt/homebrew/opt/openssl@3/lib" } else { "" })
timeout-executable := if os() == "macos" { `command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null || true` } else { `command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true` }

test:
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
    {{ platform-env }} {{ timeout-executable }} --foreground --signal=TERM --kill-after=5s {{ max-seconds }}s gerbil {{ test-runtime-options }} test -v 5 "{{ target }}" 2>&1 | tee "$test_log"
    grep -q '^MODULE-OK ' "$test_log"
    grep -q '^HARNESS-OK ' "$test_log"
    grep -qx 'OK' "$test_log"
    if grep -Eq 'ERROR CASE|ERROR CHECK|ERROR HARNESS|Heap overflow|Stack overflow' "$test_log"; then exit 1; fi

benchmark-class-proto width='1000' samples='3':
    test -n "{{ timeout-executable }}" || { echo "GNU timeout is required" >&2; exit 127; }
    POO_SLOT_BENCH_WIDTH="{{ width }}" POO_SLOT_BENCH_SAMPLES="{{ samples }}" {{ platform-env }} {{ timeout-executable }} --foreground --signal=TERM --kill-after=5s 300s gxi {{ test-runtime-options }} ./t/class-proto-benchmark.ss

benchmark-object-scale:
    #!/usr/bin/env bash
    set -euo pipefail
    if test -z "{{ timeout-executable }}"; then echo "GNU timeout is required" >&2; exit 127; fi
    bench_dir="$(mktemp -d "${TMPDIR:-/tmp}/gerbil-poo-object-scale.XXXXXX")"
    trap 'rm -rf "$bench_dir"' EXIT
    {{ platform-env }} {{ timeout-executable }} --foreground --signal=TERM --kill-after=5s 300s gxc -d "$bench_dir" -exe -o "$bench_dir/object-scale" t/object-scale-benchmark.ss
    {{ platform-env }} {{ timeout-executable }} --foreground --signal=TERM --kill-after=5s 90s "$bench_dir/object-scale"

clean:
    {{ platform-env }} gxi build.ss clean

build:
    {{ build-env }} gxi build.ss

# Standalone native Scheme matrix; no companion checkout is required.
benchmark-closure: build
    test -n "{{ timeout-executable }}" || { echo "GNU timeout is required" >&2; exit 127; }
    mkdir -p .build/closure
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gxc -d .build/closure -exe -ld-options "{{ closure-ld-options }}" -o .build/closure/closure-scale t/closure-scale-benchmark.ss
    {{ platform-env }} gxi {{ test-runtime-options }} t/closure-suite.ss .build/closure/closure-scale "{{ timeout-executable }}" .build/closure/closure-benchmarks.scm

# Same-process warm comparisons with balanced queue order and bounded children.
benchmark-closure-paired: build
    mkdir -p .build/closure
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gxc -d .build/closure -exe -ld-options "{{ closure-ld-options }}" -o .build/closure/closure-paired t/closure-paired-benchmark.ss
    {{ platform-env }} gxi {{ test-runtime-options }} t/closure-paired-suite.ss .build/closure/closure-paired "{{ timeout-executable }}" .build/closure/closure-paired.scm

# Native CPU/GC/allocation phases, with natural and pre-collected controls.
benchmark-closure-phases: build
    mkdir -p .build/closure
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gxc -d .build/closure -exe -ld-options "{{ closure-ld-options }}" -o .build/closure/closure-phases t/closure-phases.ss
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 20s .build/closure/closure-phases -:max-heap=1G .build/closure/closure-phases.scm

# Standalone Scheme signature/negative-watch costs; no Lean checkout required.
benchmark-dispatch: build
    test -n "{{ timeout-executable }}" || { echo "GNU timeout is required" >&2; exit 127; }
    mkdir -p .build/dispatch
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gxc -d .build/dispatch -exe -ld-options "{{ closure-ld-options }}" -o .build/dispatch/dispatch-benchmark t/dispatch-benchmark.ss
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 20s .build/dispatch/dispatch-benchmark -:max-heap=1G .build/dispatch/dispatch-benchmarks.scm .build/dispatch/dispatch-benchmark

# Composed metadata wrappers and complete cooked-family publication costs.
benchmark-metadata:
    mkdir -p .build/metadata
    printf '%s\n' '(metadata-benchmarks (status incomplete))' > .build/metadata/metadata-benchmarks.scm
    test -n "{{ timeout-executable }}" || { echo "GNU timeout is required" >&2; exit 127; }
    just build
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gxc -d .build/metadata -exe -ld-options "{{ closure-ld-options }}" -o .build/metadata/metadata-benchmark t/metadata-benchmark.ss
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 20s .build/metadata/metadata-benchmark -:max-heap=1G .build/metadata/metadata-benchmarks.scm .build/metadata/metadata-benchmark
    {{ platform-env }} gxi {{ test-runtime-options }} t/metadata-report.ss .build/metadata/metadata-benchmarks.scm

benchmark-metadata-paired:
    mkdir -p .build/metadata
    printf '%s\n' '(metadata-paired (status incomplete))' > .build/metadata/metadata-paired.scm
    test -n "{{ timeout-executable }}" || { echo "GNU timeout is required" >&2; exit 127; }
    just build
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gxc -d .build/metadata -exe -ld-options "{{ closure-ld-options }}" -o .build/metadata/metadata-paired t/metadata-paired-benchmark.ss
    {{ platform-env }} {{ timeout-executable }} --signal=TERM --kill-after=3s 90s gxi {{ test-runtime-options }} t/metadata-paired-suite.ss .build/metadata/metadata-paired "{{ timeout-executable }}" .build/metadata/metadata-paired.scm
