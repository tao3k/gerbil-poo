platform-env := if os() == "macos" { "env -u SDKROOT" } else { "env" }
build-env := platform-env + " GERBIL_BUILD_VERBOSE=9"

[parallel]
test: test-core test-types test-trie

[private]
test-core:
    {{ platform-env }} gerbil test -v 3 t/cli-test.ss t/debug-test.ss t/support-test.ss t/object-test.ss t/mop-test.ss

[private]
test-types:
    {{ platform-env }} gerbil test -v 3 t/number-test.ss t/type-test.ss t/fq-test.ss t/polynomial-test.ss t/rationaldict-test.ss

[private]
test-trie:
    {{ platform-env }} gerbil test -v 3 t/trie-test.ss

clean:
    {{ platform-env }} gxi build.ss clean

build:
    {{ build-env }} gxi build.ss
