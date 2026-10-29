;;; Focused paired performance unit uses the standard test runner and producer.
(export slot-offset-test)
(import :std/test (only-in :clan/poo/benchmarks/collection-paired-benchmark run-offset-study run-values-study))
;; Fixed prepare/hot/switch/churn/workflow matrix, including every paired control.
(def slot-offset-test
  (test-suite "bounded descriptor offset costs"
    (test-case "complete paired unit with allocation GC and workflow costs"
      (check (run-offset-study) => #t))
    (test-case "single-authority value storage with full paired controls"
      (check (run-values-study) => #t))))
