;;; The existing SCC matrix runs inside the official TestSuite lifecycle.
(export scc-benchmark-test reachability-benchmark-test compact-benchmark-test)
(import :std/test (prefix-in (only-in :clan/poo/t/feedback/feedback-graph-test main) study.)
        (prefix-in (only-in :clan/poo/t/feedback/graph-algorithms-test main small-reachability-study compact-study shared-cyclic-study) scale.))
;; Existing construction module owns the same DAG update workload as its tests.
(import (prefix-in (only-in :clan/poo/t/construction/graph-order-repair-test main) rank.))
;; Retain the complete 320-observation matrix and original failure propagation.
(def scc-benchmark-test
  (test-suite "complete paired SCC workload"
    (test-case "every existing topology and regime" (study.main))
    (test-case "100000/1000000 Graph nodes with bounded semantic controls" (scale.main))
    (test-case "local and full DAG updates with the same prepared source" (rank.main))))

;; The official suite filter can run this bounded setup study independently.
;; Full benchmark-scc still runs every original suite plus this one.
(def reachability-benchmark-test
  (test-suite "prepared small reachability index costs"
    (test-case "same captured rows, list versus indexed membership"
      (scale.small-reachability-study))))

(def compact-benchmark-test
  (test-suite "compact Graph storage and complete cold query costs"
    (test-case "same input rows, charged CSR encoding and ordered traversal"
      (scale.compact-study))
    (test-case "million-node cyclic band with independent fixture lifetime"
      (scale.shared-cyclic-study))))
