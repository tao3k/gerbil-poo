;;; Focused-assembly study: current fused versus current per-fragment construction.
(export specification scenarios repetitions sources)
(import (only-in :std/list/list delete-duplicates/hash) ../object
        (prefix-in "metadata-paired-cases.ss" metadata.))
;; Keep complete observations, controlled heap history and isolated phases separate.
(def scenarios '(nested nested-history cold construction hook cooking binding envelope revision
  nested-allocation construction-allocation envelope-allocation))
;; Counts are fixed before all three complete runs, not chosen from observed timings.
(def (repetitions scenario)
  (case scenario ((nested-allocation construction-allocation envelope-allocation) 1)
    ((cold envelope revision) 32) (else 128)))
;; Source identities cover runtime, native examples, shared I/O driver and this study.
(def sources (delete-duplicates/hash (append metadata.sources
  '("generalized-prototype.ss" "examples/generalized-checkout.ss" "t/focused-cases.ss"
    "t/focused-benchmark.ss" "t/focused-suite.ss")) from-end?: #t))
;; Balanced ABBA process order; exact A/A duplicates share the same action closure.
(def (side-order round pair) (if (memv round '(0 3)) pair (reverse pair)))
;; Reuse the strict native paired harness and its complete EOF/source/GC admission.
(def specification (.cc (.o) kind: 'focused-paired label: "FOCUSED-PAIRED-OK"
  scenarios: scenarios regimes: '(natural collected)
  strategies: '(fused unfused fused-aa unfused-aa) pairs: '((1 0) (0 2) (1 3))
  rounds: 4 warmups: 4 repetitions: repetitions sources: sources side-order: side-order))
