;;; Native generalized-hook study, using the shared strict source-bound driver.
(export specification scenarios strategies repetitions)
(import (only-in :std/list/list delete-duplicates/hash) ../object
        (prefix-in "metadata-paired-cases.ss" metadata.))
;; Cold captures construction; repeated finite observation and cooked calls stay distinct.
(def scenarios '(cold observation hot))
;; A/A controls duplicate each implementation in balanced independent processes.
(def strategies '(hoisted fresh hoisted-aa fresh-aa))
;; Fixed before measurement; no best-run or timing-dependent sample counts.
(def (repetitions scenario) (if (eq? scenario 'cold) 32 128))
;; Every runtime/example/driver input participates in source admission; Lean is absent.
(def sources (delete-duplicates/hash (append metadata.sources
  '("generalized-prototype.ss" "examples/generalized-checkout.ss" "t/generalized-cases.ss"
    "t/generalized-benchmark.ss" "t/generalized-suite.ss")) from-end?: #t))
;; ABBA balances process order while warming all four actions identically in each child.
(def (side-order round pair) (if (memv round '(0 3)) pair (reverse pair)))
;; Native descriptor composition shares the existing child protocol and admission checks.
(def specification (.cc (.o) kind: 'generalized-paired label: "GENERALIZED-PAIRED-OK"
  scenarios: scenarios regimes: '(natural collected) strategies: strategies
  pairs: '((1 0) (0 2) (1 3)) rounds: 4 warmups: 4 repetitions: repetitions
  sources: sources side-order: side-order))
