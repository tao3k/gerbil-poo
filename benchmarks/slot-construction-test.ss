;;; Standard test entry for complete explicit/opaque SlotSpec construction costs.
(export slot-construction-test)
(import :std/test (only-in :clan/poo/benchmarks/collection-paired-benchmark run-chain-study))
;; Every phase keeps its full oracle, AB/BA ordering and A/A/B/B controls.
(def slot-construction-test
  (test-suite "SlotSpec construction and publication costs"
    (test-case "complete paired construction unit" (check (run-chain-study) => #t))))
