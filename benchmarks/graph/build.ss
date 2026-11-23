#!/usr/bin/env -S gxi -:max-heap=1G,debug=q
(import :std/build-script
        (rename-in (only-in "../../build.ss" project-build-source)
          (project-build-source this-source-file))
        (only-in :std/list/list filter)
        (only-in "../../t/build.ss" test-build-spec prefix-test-spec)
        (only-in "../../support/compile-jobs.ss" call-with-build-jobs))

(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT" (string-append (if options (string-append options ",") "") "max-heap=2G,debug=q")))

(def studies '("feedback/feedback-graph-test" "feedback/graph-algorithms-test"
               "construction/graph-order-repair-test"))
(def study-specs
  (filter (lambda (spec) (member (cadr spec) studies)) (test-build-spec)))
(unless (= (length study-specs) (length studies))
  (error "missing Graph benchmark build input" studies))

(def build
  (let ()
    (defbuild-script `(
      ,@(map (cut prefix-test-spec "t" <>) study-specs)
      (gxc: "benchmarks/closure-measure" "-cc-options" "-O2")
      (gxc: "benchmarks/cold-handoff-test" "-cc-options" "-O2")
      (gxc: "benchmarks/dense-repair-test" "-cc-options" "-O2")
      (gxc: "benchmarks/ordered-scc-study" "-cc-options" "-O2")
      (gxc: "benchmarks/scc-test" "-cc-options" "-O2")) parallelize: #f)
    main))

(def (main . options) (call-with-build-jobs (cut apply build options)))
