;;; Prepared Graph revision pairs use the existing official test lifecycle.
(export owned-invalidation-benchmark-test)
(import :std/test
        (only-in "../t/construction/graph-order-repair-test.ss" owned-invalidation-study))
(def owned-invalidation-benchmark-test
  (test-suite "owned inverse continuation"
    (test-case "100K and 1M nodes, same tickets and alternating execution order"
      (owned-invalidation-study))))
