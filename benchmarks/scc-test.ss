;;; The existing SCC matrix runs inside the official TestSuite lifecycle.
(export scc-benchmark-test)
(import :std/test (prefix-in (only-in :clan/poo/t/feedback/feedback-graph-test main) study.)
        (prefix-in (only-in :clan/poo/t/feedback/graph-algorithms-test main) scale.))
;; Existing construction module owns the same DAG update workload as its tests.
(import (prefix-in (only-in :clan/poo/t/construction/graph-order-repair-test main) rank.))
;; Retain the complete 320-observation matrix and original failure propagation.
(def scc-benchmark-test
  (test-suite "complete paired SCC workload"
    (test-case "every existing topology and regime" (study.main))
    (test-case "10000/100000-owner indexed Graph with bounded original-production controls" (scale.main))
    (test-case "local and full DAG updates with the same prepared source" (rank.main))))
