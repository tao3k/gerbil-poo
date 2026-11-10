;;; Focused entry for the existing complete object-scale workload.
(export object-scale-test point-index-test)
(import :std/test (only-in :clan/poo/benchmarks/object-scale-benchmark main point-index-study))

(def point-index-test
  (test-suite "ordered contribution index primitive"
    (test-case "same source sparse query with charged preparation"
      (check (point-index-study) => #t))))

;; Keep all original result oracles, repetitions and construction/clone phases.
;; The standard heap-fenced Just test entry permits runtime A/B comparisons
;; without statically linking a different copy of the POO dependency closure.
(def object-scale-test
  (test-suite "complete object construction and first demand costs"
    (test-case "one slot and one layer control"
      (main "natural" "tree" "1" "1"))
    (test-case "256 slots and 32 inherited layers"
      (main "natural" "tree" "256" "32"))))
