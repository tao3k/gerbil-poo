;;; Standard test entry for indexed deletion, full construction and publication.
(export prototype-map-test)
(import :std/test (only-in :clan/poo/benchmarks/collection-paired-benchmark run-map-study))
;; Retain AB/BA, A/A/B/B, snapshot copies, setup, cold and post-GC controls.
(def prototype-map-test
  (test-suite "persistent contribution index costs"
    (test-case "complete paired deletion unit" (check (run-map-study) => #t))))
