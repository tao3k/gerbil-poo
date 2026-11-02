;;; Focused confirmation complements, never replaces, the complete paired suite.
(export cold-query-test)
(import :std/test (only-in :clan/poo/benchmarks/collection-paired-benchmark run-cold-query-study))
;; The existing sampler owns AB/BA, A/A, B/B, forced-GC and first-call accounting.
(def cold-query-test
  (test-suite "cold declaration query and complete publication tails"
    (test-case "longer matched cold and workflow batches" (check (run-cold-query-study) => #t))))
