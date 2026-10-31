;;; Focused paired performance unit uses the standard test runner and producer.
(export slot-offset-test shape-growth-test)
(import :std/test (only-in :clan/poo/benchmarks/collection-paired-benchmark run-offset-study run-values-study run-shape-study))
;; Fixed prepare/hot/switch/churn/workflow matrix, including every paired control.
(def slot-offset-test
  (test-suite "bounded descriptor offset costs"
    (test-case "complete paired unit with allocation GC and workflow costs"
      (check (run-offset-study) => #t))
    (test-case "single-authority value storage with full paired controls"
      (check (run-values-study) => #t))))

;; Selectable standard suite; the complete source entry still discovers both.
(def shape-growth-test
  (test-suite "ordered shape growth costs"
    (test-case "complete preparation and publication keep every paired control"
      (check (run-shape-study) => #t))))
