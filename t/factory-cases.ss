;;; Qualified versus statically item-only raw method representation.
(export specification scenarios repetitions sources)
(import (only-in :std/list/list delete-duplicates/hash)
        ../object
        (runtime: :clan/poo/t/metadata-paired-cases)
        (prefix-in (only-in "metadata-paired-cases.ss" sources) metadata.))
;; Keep fresh factory, raw construction, warm dependency cooking and cache phases distinct.
(def scenarios '(factory factory-history preparation binding construction cooking
  item-construct item-cold item-warm revision factory-allocation construction-allocation cooking-allocation))
;; Fix counts before three complete runs; one-shot bytes stay separate from throughput.
(def (repetitions scenario)
  (case scenario ((factory-allocation construction-allocation cooking-allocation) 1)
    ((item-warm binding) 4096) ((item-construct item-cold) 128)
    ((factory factory-history preparation) 16) (else 64)))
;; Reuse the native source manifest, covering every new entry point and runtime input.
(def sources (delete-duplicates/hash (append metadata.sources
  '("generalized-prototype.ss" "examples/generalized-checkout.ss" "t/factory-cases.ss"
    "t/factory-benchmark.ss" "t/factory-suite.ss")) from-end?: #t))
;; Alternate direct and exact duplicate controls in ABBA order across four rounds.
(def (side-order round pair) (if (memv round '(0 3)) pair (reverse pair)))
;; The shared I/O interpreter owns caps, EOF, source identity and paired admission.
(def specification (.cc (.o) kind: 'factory-paired label: "FACTORY-PAIRED-OK"
  scenarios: scenarios regimes: '(natural collected)
  strategies: '(items qualified items-aa qualified-aa) pairs: '((1 0) (0 2) (1 3))
  rounds: 4 warmups: 4 repetitions: repetitions sources: sources side-order: side-order))
