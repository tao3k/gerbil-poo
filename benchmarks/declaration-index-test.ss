;;; Effective declaration indexing uses the existing standard paired runner.
(export declaration-index-test)
(import :std/test (only-in :clan/poo/benchmarks/collection-paired-benchmark run-declaration-study))
;; Retain empty/single, cold/hot/missing, observation and complete publication.
(def declaration-index-test
  (test-suite "effective declaration index costs"
    (test-case "complete paired declaration index unit" (check (run-declaration-study) => #t))))
