;;; Fixed recursive study descriptor for the shared strict native paired harness.
(export specification scenarios strategies repetitions workload-sources)
(import (only-in :std/list/list delete-duplicates/hash)
        ../object
        (runtime: :clan/poo/t/metadata-paired-cases)
        (prefix-in (only-in "metadata-paired-cases.ss" sources) metadata.))
;; Keep complete calls, source failures, cyclic revocation and current re-admission separate.
(def scenarios '(attestation catalog source-error output-refusal batch-resume publication))
;; Fresh recomputation is the control; A/A duplicates have the exact same semantics.
(def strategies '(memo fresh memo-aa fresh-aa))
;; Fixed counts, no timing-dependent adaptation or best-run selection.
(def (repetitions scenario) (if (eq? scenario 'publication) 32 128))
;; Bind runtime, examples, shared driver and native worker identity; no Lean input.
(def workload-sources
  (delete-duplicates/hash (append metadata.sources '("recursive.ss" "recursive-cache.ss" "recursive-handling.ss"
    "proto.ss" "fun.ss" "examples/recursive-catalog.ss" "t/recursive-cases.ss"
    "t/recursive-benchmark.ss" "t/recursive-suite.ss")) from-end?: #t))
;; Balanced ABBA across independent fresh children; every child warms all four controls.
(def (side-order round pair) (if (memv round '(0 3)) pair (reverse pair)))
;; Supply the existing strict harness via native POO descriptor composition.
(def specification (.cc (.o)
  kind: 'recursive-paired label: "RECURSIVE-PAIRED-OK"
  scenarios: scenarios regimes: '(natural collected) strategies: strategies
  pairs: '((1 0) (0 2) (1 3)) rounds: 4 warmups: 4
  repetitions: repetitions sources: workload-sources side-order: side-order))
