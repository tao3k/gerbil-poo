#!/usr/bin/env -S gxi -:max-heap=1G,debug=q
;;; Standard executable and library declarations for this benchmark.
(import :std/build-script
        (rename-in (only-in "../../build.ss" project-build-source)
          (project-build-source this-source-file))
        (only-in :std/make pkg-config-libs)
        (only-in "../../t/build.ss" call-with-build-jobs))
;; Preserve the compiler backend bound in this standard package entry.
(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT" (string-append (if options (string-append options ",") "") "max-heap=2G,debug=q")))
;; Reuse pkg-config once; std/make owns object reuse, linking and cleanup.
;; Link consumers synchronously through make: concurrent executable requests
;; otherwise regenerate the same dependency C files before their jobs finish.
;; Library and test compilation retain the standard concurrent backend budget.
(def build (let ((links (pkg-config-libs "openssl")))
  (defbuild-script `(
    (gxc: "benchmarks/count-performance-benchmark" "-cc-options" "-O2")
    (gxc: "benchmarks/enum-performance-benchmark" "-cc-options" "-O2")
    (gxc: "benchmarks/iterator-performance-benchmark" "-cc-options" "-O2")
    (gxc: "benchmarks/object-performance-benchmark" "-cc-options" "-O2")
    (gxc: "benchmarks/rationaldict-performance-benchmark" "-cc-options" "-O2")
    (exe: "benchmarks/performance/count-performance-benchmark-main" bin: "count-performance-benchmark" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)
    (exe: "benchmarks/performance/enum-performance-benchmark-main" bin: "enum-performance-benchmark" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)
    (exe: "benchmarks/performance/iterator-performance-benchmark-main" bin: "iterator-performance-benchmark" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)
    (exe: "benchmarks/performance/object-performance-benchmark-main" bin: "object-performance-benchmark" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)
    (exe: "benchmarks/performance/rationaldict-performance-benchmark-main" bin: "rationaldict-performance-benchmark" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)) parallelize: #f) main))
;; Close the standard executor on refusal; no project process registry is used.
(def (main . options) (call-with-build-jobs (cut apply build options)))
