(export main workload)
(import ../object (prefix-in ../examples/generalized-checkout checkout.)
        (only-in "metadata-paired-benchmark.ss" run-child) (prefix-in "generalized-cases.ss" study.)
        (prefix-in ../generalized-prototype gp.))
;; Both controls capture the same immutable graph/seed and validate actual price.
;; Cold is deliberately identical: it detects overhead without amortization claims.
(def (workload scenario)
  (map (lambda (mode)
    (def reuse? (memq mode '(hoisted hoisted-aa)))
    (def snapshot (checkout.prepare-checkout))
    (def cooked (gp.observe snapshot checkout.base checkout.base 2))
    (case scenario
      ((cold) (lambda () (= (checkout.total (checkout.prepare-checkout) 2) 33)))
      ((observation) (lambda () (= (checkout.total (if reuse? snapshot (checkout.prepare-checkout)) 2) 33)))
      ((hot) (lambda () (= ((if reuse? cooked
        (gp.observe snapshot checkout.base checkout.base 2)) 'price) 33)))
      (else (error "unknown generalized scenario" scenario)))) study.strategies))
;; Reuse signed byte admission, prefix/GC counters, bounded children and exact oracles.
(def (main scenario-text regime-text side-text)
  (def scenario (string->symbol scenario-text)) (def regime (string->symbol regime-text))
  (def side (string->number side-text))
  (unless (and (memq scenario study.scenarios) (memq regime '(natural collected)) (memv side '(0 1 2 3)))
    (error "invalid generalized study request"))
  (run-child scenario regime side (workload scenario) (study.repetitions scenario) 4))
