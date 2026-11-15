#!/usr/bin/env -S gxi -:max-heap=1G,debug=q
;;; Standard executable and library declarations for this benchmark.
(import :std/build-script
        (rename-in (only-in "../../build.ss" project-build-source)
          (project-build-source this-source-file))
        (only-in :std/list/list filter)
        (only-in :std/make pkg-config-libs)
        (only-in "../../t/build.ss" call-with-build-jobs test-build-spec prefix-test-spec))
;; Preserve the compiler backend bound in this standard package entry.
(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT" (string-append (if options (string-append options ",") "") "max-heap=2G,debug=q")))
;; Reuse pkg-config once; std/make owns object reuse, linking and cleanup.
;; Link consumers synchronously through make: concurrent executable requests
;; otherwise regenerate the same dependency C files before their jobs finish.
;; Library and test compilation retain the standard concurrent backend budget.
(def build (let ((links (pkg-config-libs "openssl")))
  ;; Keep the timed SCC references on their declared AOT compiler policies.
  (def studies '("feedback/feedback-graph-test" "feedback/graph-algorithms-test"
                 "construction/graph-order-repair-test"))
  (def study-specs
    (filter (lambda (spec) (member (cadr spec) studies)) (test-build-spec)))
  (unless (= (length study-specs) (length studies))
    (error "missing Graph benchmark build input" studies))
  (defbuild-script `(
    ,@(map (cut prefix-test-spec "t" <>) study-specs)
    (gxc: "examples/closed-declarations" "-cc-options" "-O2")
    (gxc: "examples/component-services" "-cc-options" "-O2")
    (gxc: "benchmarks/closure-benchmark-support" "-cc-options" "-O2")
    (gxc: "benchmarks/closure-cases" "-cc-options" "-O2")
    (gxc: "benchmarks/closure-measure" "-cc-options" "-O2")
    (gxc: "benchmarks/closure-paired-benchmark" "-cc-options" "-O2")
    (gxc: "benchmarks/closure-paired-suite" "-cc-options" "-O2")
    (gxc: "benchmarks/closure-parity" "-cc-options" "-O2")
    (gxc: "benchmarks/closure-phases" "-cc-options" "-O2")
    (gxc: "benchmarks/closure-report" "-cc-options" "-O2")
    (gxc: "benchmarks/closure-scale-benchmark" "-cc-options" "-O2")
    (gxc: "benchmarks/closure-suite" "-cc-options" "-O2")
    (gxc: "benchmarks/cold-handoff-test" "-cc-options" "-O2")
    (gxc: "benchmarks/dense-repair-test" "-cc-options" "-O2")
    (gxc: "benchmarks/ordered-scc-study" "-cc-options" "-O2")
    (exe: "benchmarks/closure/closure-paired-benchmark-main" bin: "closure-paired-benchmark" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)
    (exe: "benchmarks/closure/closure-paired-suite-main" bin: "closure-paired-suite" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)
    (exe: "benchmarks/closure/closure-parity-main" bin: "closure-parity" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)
    (exe: "benchmarks/closure/closure-phases-main" bin: "closure-phases" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)
    (exe: "benchmarks/closure/closure-report-main" bin: "closure-report" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)
    (exe: "benchmarks/closure/closure-scale-benchmark-main" bin: "closure-scale-benchmark" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)
    (exe: "benchmarks/closure/closure-suite-main" bin: "closure-suite" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)) parallelize: #f) main))
;; Close the standard executor on refusal; no project process registry is used.
(def (main . options) (call-with-build-jobs (cut apply build options)))
