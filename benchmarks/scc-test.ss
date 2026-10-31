;;; The existing SCC matrix runs inside the official TestSuite lifecycle.
(export scc-benchmark-test)
(import :std/test (prefix-in (only-in :clan/poo/t/feedback/feedback-graph-test main) study.))
;; Retain the complete 320-observation matrix and original failure propagation.
(def scc-benchmark-test
  (test-suite "complete paired SCC workload"
    (test-case "every existing topology and regime" (study.main))))
