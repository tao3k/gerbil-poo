;;; Matched callback/tree strategies with AB/BA and identical-strategy controls.
(export main)
(import :std/iter ../object ../mop ../type ../number ../testing/type
        (prefix-in :clan/property-testing/generator core.)
        (only-in ./closure-measure measure measure-pair))

;; This finite injective product admits both value-only and provenance shrinking.
;; Fixed draws give both strategies identical values and shrink frontiers/seeds.
(def Descriptor (Tuple UInt UInt))
;; Preparation is included by the workflow action and measured separately too.
;; Both strategies perform the same receiver derivation; only tree ownership differs.
(def (prepare strategy)
  (def children (map (lambda (n)
    (make-generator UInt (lambda (_random _size) n) core.integer-shrinks identity)) '(9 5)))
  (def sampler (product-generator Descriptor children vector->list list->vector))
  (.cc sampler generation: (if (eq? strategy 'callbacks) #f (.get sampler generation))))
;; One independent mathematical oracle is shared by both full check actions.
(def (property value) (< (+ (vector-ref value 0) (vector-ref value 1)) 3))
;; Counters, status and exact witness are checked inside each measured workflow.
(def (run sampler)
  (def report (check-property Descriptor property sampler: sampler cases: 1 seed: 41 shrink-budget: 96))
  (unless (and (eq? (.get report status) 'failed)
    (equal? (.get report counterexample) '#(0 3)) (.get report minimal?)
    (= (.get report attempts) 10) (= (.get report steps) 3)) (error "generator strategy oracle" report)) #t)
;; One matched workload covers preparation, reused drawing and complete shrinking.
(def (action phase strategy)
  (case phase
    ((prepare) (lambda () (object? (prepare strategy))))
    ((draw)
     (let (sampler (generator-core (prepare strategy)))
       (lambda () (equal? (core.sample-value (core.generate sampler (core.random-at 41) 8)) '#(9 5)))))
    ((workflow) (lambda () (run (prepare strategy))))
    (else (error "unknown generator benchmark phase" phase))))
;; The existing process-statistics helper owns CPU, wall, GC, counts and allocation.
;; Explicit post-GC preparation and the first call are charged, not silently warmed.
(def (capture thunk repetitions regime)
  (def (sample operation count)
    (defvalues (ok metrics) (measure operation count))
    (unless ok (error "generation benchmark oracle refused")) metrics)
  (def preparation (and (eq? regime 'post-gc) (sample (lambda () (##gc) #t) 1)))
  (def first (and preparation (sample thunk 1)))
  (vector (sample thunk repetitions) first preparation))
;; Report only after the complete pair, preserving the measured inter-sample gap.
(def (report phase regime order samples)
  (displayln "GENERATOR-PAIR " phase " " regime " " order " " samples))
;; Full entries include library/module startup; the measured actions contain all
;; strategy-specific preparation. Reversed and identical pairs expose ordering noise.
(def (main (repetitions-text "20") (pairs-text "4"))
  (def repetitions (string->number repetitions-text)) (def pairs (string->number pairs-text))
  (unless (and (exact-integer? repetitions) (> repetitions 0) (exact-integer? pairs) (> pairs 0))
    (error "positive benchmark counts required"))
  (for* ((phase '(prepare draw workflow)) (regime '(natural post-gc)))
    (def callbacks (action phase 'callbacks)) (def tree (action phase 'tree))
    ;; Admit both complete oracles before collecting comparative timing evidence.
    (unless (and (run (prepare 'callbacks)) (run (prepare 'tree))) (error "strategy admission"))
    (for (pair (in-range pairs))
      (for (order (list (if (even? pair) '(callbacks tree) '(tree callbacks))
                       '(callbacks callbacks) '(tree tree)))
        (measure-pair order
          (lambda (strategy) (capture (if (eq? strategy 'callbacks) callbacks tree) repetitions regime))
          (lambda (samples) (report phase regime order samples))))))
  (displayln "GENERATOR-PAIRED-OK"))
