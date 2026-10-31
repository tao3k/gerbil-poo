;;; Standard test entry for ordered private traversal and persistent composition.
(export prototype-traversal-test)
(import :std/test (only-in :clan/poo/benchmarks/collection-paired-benchmark run-traversal-study))
;; All result/effect oracles, control orders and collection regimes remain enabled.
(def prototype-traversal-test
  (test-suite "persistent map traversal and composition costs"
    (test-case "complete paired traversal unit" (check (run-traversal-study) => #t))))
