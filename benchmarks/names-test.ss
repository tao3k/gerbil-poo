;;; Standard test entry retains all safe-copy/borrowed and observed controls.
(export names-test)
(import :std/test (only-in :clan/poo/benchmarks/collection-paired-benchmark run-names-study))
;; Complete preparation, snapshots, authentication and publication stay charged.
(def names-test
  (test-suite "owned names and borrowed enumeration costs"
    (test-case "complete paired names unit" (check (run-names-study) => #t))))
