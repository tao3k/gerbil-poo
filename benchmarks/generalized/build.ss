#!/usr/bin/env -S gxi -:max-heap=1G,debug=q
;;; Standard executable and library declarations for this benchmark.
(import :std/build-script
        (rename-in (only-in "../../build.ss" project-build-source)
          (project-build-source this-source-file))
        (only-in :std/make pkg-config-libs)
        (only-in "../../support/compile-jobs.ss" call-with-build-jobs))
;; Preserve the compiler backend bound in this standard package entry.
(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT" (string-append (if options (string-append options ",") "") "max-heap=2G,debug=q")))
;; Reuse pkg-config once; std/make owns object reuse, linking and cleanup.
;; Link consumers synchronously through make: concurrent executable requests
;; otherwise regenerate the same dependency C files before their jobs finish.
;; Library and test compilation retain the standard concurrent backend budget.
(def build (let ((links (pkg-config-libs "openssl")))
  (defbuild-script `(
    (gxc: "benchmarks/closure-benchmark-support" "-cc-options" "-O2")
    (gxc: "benchmarks/closure-measure" "-cc-options" "-O2")
    (gxc: "benchmarks/generalized-benchmark" "-cc-options" "-O2")
    (gxc: "benchmarks/generalized-cases" "-cc-options" "-O2")
    (gxc: "benchmarks/generalized-observation-reference" "-cc-options" "-O2")
    (gxc: "benchmarks/generalized-suite" "-cc-options" "-O2")
    (gxc: "benchmarks/metadata-paired-cases" "-cc-options" "-O2")
    (gxc: "benchmarks/metadata-paired-suite" "-cc-options" "-O2")
    (gxc: "examples/generalized-checkout" "-cc-options" "-O2")
    (exe: "benchmarks/generalized/generalized-benchmark-main" bin: "generalized-benchmark" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)
    (exe: "benchmarks/generalized/generalized-suite-main" bin: "generalized-suite" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)) parallelize: #f) main))
;; Close the standard executor on refusal; no project process registry is used.
(def (main . options) (call-with-build-jobs (cut apply build options)))
