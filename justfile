# Homebrew Gerbil is built with GCC on Darwin. Keep Nix SDK/header/library
# variables out of child compilations and make GCC's collect2 select Apple's
# system linker instead of a Nix-provided ld.
platform-env := if os() == "macos" { "env -u SDKROOT -u CPATH -u LIBRARY_PATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH -u MACOSX_DEPLOYMENT_TARGET COMPILER_PATH=/usr/bin" } else { "env" }
physical-cores := if os() == "macos" { `sysctl -n hw.physicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN` } else { `getconf _NPROCESSORS_ONLN` }
export GERBIL_BUILD_CORES := env_var_or_default("GERBIL_BUILD_CORES", physical-cores)
build-verbose := env_var_or_default("GERBIL_BUILD_VERBOSE", "3")
build-env := platform-env + " GERBIL_BUILD_VERBOSE=" + build-verbose

test:
    {{ platform-env }} gerbil test -v 5 t

test-atomic name:
    {{ platform-env }} gerbil test -v 5 "t/{{ name }}-test.ss"

clean:
    {{ platform-env }} gxi build.ss clean

build:
    {{ build-env }} gxi build.ss
