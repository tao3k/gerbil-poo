;;; Dedicated scale controls for the standard Slot value stores and shape index.
(export slot-index-test)
(import :std/test (only-in :clan/poo/benchmarks/collection-paired-benchmark run-slot-index-study))
;; Every width retains AB/BA and both same-side controls.
(def slot-index-test
  (test-suite "Slot indexes and symbolic hash stores"
    (test-case "small sparse layouts" (check (run-slot-index-study "8") => #t))
    (test-case "service-width sparse layouts" (check (run-slot-index-study "64") => #t))
    (test-case "wide sparse layouts" (check (run-slot-index-study "256") => #t))))
