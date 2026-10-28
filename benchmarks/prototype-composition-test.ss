;;; Standard focused entry for complete persistent composition uncertainty.
(export prototype-composition-test)
(import :std/test (only-in :clan/poo/benchmarks/collection-paired-benchmark run-composition-study))
;; Increased sample count never removes preparation, negative or GC-history controls.
(def prototype-composition-test
  (test-suite "complete persistent composition paired controls"
    (test-case "higher resolution composition workflow" (check (run-composition-study) => #t))))
