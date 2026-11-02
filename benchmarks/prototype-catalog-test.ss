;;; Catalog ownership and complete publication costs use the standard test runner.
(export prototype-catalog-test)
(import :std/test (only-in :clan/poo/benchmarks/collection-paired-benchmark run-catalog-study))
;; No independent timer, loader or process harness is introduced.
(def prototype-catalog-test
  (test-suite "persistent declaration catalog costs"
    (test-case "complete paired catalog unit" (check (run-catalog-study) => #t))))
