;;; Immutable-source context binding and Reader composition study.
(export specification scenarios repetitions sources)
(import (only-in :std/list/list delete-duplicates/hash)
        ../object
        (runtime: :clan/poo/t/metadata-paired-cases)
        (prefix-in (only-in "metadata-paired-cases.ss" sources) metadata.))
;; Separate pure projection, binder construction, full observation and preparation.
(def scenarios '(map map-allocation binding binding-allocation nested nested-history revision factory preparation
  nested-allocation revision-allocation factory-allocation))
;; Fixed before measurement; single-batch bytes stay distinct from throughput.
(def (repetitions scenario)
  (case scenario ((nested-allocation revision-allocation factory-allocation) 1) ((map) 65536) ((map-allocation binding-allocation) 64)
    ((binding) 16384) ((factory preparation) 16) (else 64)))
;; Cover all added runtime, examples, source controls and standalone entry points.
(def sources (delete-duplicates/hash (append metadata.sources
  '("generalized-prototype.ss" "examples/generalized-checkout.ss"
    "t/binding-cases.ss" "t/binding-benchmark.ss" "t/binding-suite.ss")) from-end?: #t))
;; ABBA alternation is shared by direct and exact duplicate A/A controls.
(def (side-order round pair) (if (memv round '(0 3)) pair (reverse pair)))
;; Reuse native source admission, bounded children and signed GC-free allocations.
(def specification (.cc (.o) kind: 'binding-paired label: "BINDING-PAIRED-OK"
  scenarios: scenarios regimes: '(natural collected)
  strategies: '(composed reference composed-aa reference-aa) pairs: '((1 0) (0 2) (1 3))
  rounds: 4 warmups: 4 repetitions: repetitions sources: sources side-order: side-order))
