;;; Standard paired entries retain complete construction, publication and controls.
(export prototype-map-test)
(import :std/test (only-in :clan/poo/benchmarks/collection-paired-benchmark
                           run-map-study run-shape-revision-study))
;; Both studies keep AB/BA, A/A/B/B, snapshots, setup, GC and tail reports.
(def prototype-map-test
  (test-suite "persistent contribution and shape costs"
    (test-case "complete paired deletion unit" (check (run-map-study) => #t))
    (test-case "complete paired batch shape revision" (check (run-shape-revision-study) => #t))))
