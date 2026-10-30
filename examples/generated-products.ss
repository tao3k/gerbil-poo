;;; Typed products inherit the enclosing run's admission through ordinary modules.
(export generated-products-test)
(import :std/test :std/error :std/iter ../object ../mop ../type ../number ../testing/type
        (prefix-in :clan/poo/testing/property/generator core.))

;; The standard suite owns registration; every case uses ordinary public actions.
(def generated-products-test
  (test-suite "nested typed product admission"
    (test-case "Record Function products refuse ancestor revision before packing and retry through FUN"
      (def schema (Record count: [UInt] handler: [(Function [Integer] [Integer])]))
      (def descriptor (Tuple schema schema))
      (def owner (.o epoch: 0))
      (def packs 0) (def later 0)
      ;; Each preparation captures its own fault policy and the same declared owner.
      ;; The inner product deliberately has no owner edge: it must inherit the run.
      (def (workflow revise?)
        (def first (make-generator schema
          (lambda (_random _size) (make-instance schema count: 2 handler: abs))
          (lambda (value) (if (zero? (.get value count)) []
            (begin (when revise? (.putslot! owner 'epoch ($constant-slot-spec (1+ (.get owner epoch)))))
              (list (.cc value count: 0))))) (cut .get <> count)))
        (def second (make-generator schema
          (lambda (_random _size) (make-instance schema count: 2 handler: abs))
          (lambda (value) (set! later (1+ later))
            (if (zero? (.get value count)) [] (list (.cc value count: 0)))) (cut .get <> count)))
        (def product (product-generator descriptor (list first second) vector->list
          (lambda (row) (set! packs (1+ packs)) (list->vector row))))
        (def outer (make-generator descriptor
          (lambda (_random _size) (vector (make-instance schema count: 2 handler: abs)
            (make-instance schema count: 2 handler: abs)))
          (cut .call product shrink <>) (cut .call product measure <>) dependencies: (list owner)))
        (property-action descriptor (lambda (row) (= ((.@ (vector-ref row 0) handler) -1) 0)) identity sampler: outer))
      (def configuration (make-instance PropertyConfiguration seed: 13 cases: 1 size: 2 shrink-budget: 20))
      (def old ((workflow #t) configuration))
      (check-eq? (.get old status) 'stale)
      (check-equal? (list packs later (.get old attempts) (.get old steps)) '(0 0 0 0))
      (check-exception (replay-property old) Error?)
      (let (fresh ((workflow #f) configuration))
        (check-eq? (.get fresh status) 'failed)
        (check-equal? (map (cut .get <> count) (vector->list (.get fresh counterexample))) '(0 0))
        (check-exception ((.@ (vector-ref (.get fresh counterexample) 0) handler) 'invalid) TypeError?)
        (check (replay-counterexample fresh) => #f)
        (check-eq? (.get (replay-property fresh) status) 'failed))
      (check-exception (replay-property old) Error?))
    (test-case "unpack field measure and pack share inherited producer ownership"
      (for (stage '(unpack measure pack))
        (def owner (.o epoch: 0)) (def measured 0) (def packs 0) (def later 0)
        ;; Explicit revision identity is captured once by the enclosing producer.
        (def stamp (object-revision owner))
        ;; A selected callback changes only the explicitly registered epoch.
        (def (revise phase)
          (when (eq? stage phase) (.putslot! owner 'epoch ($constant-slot-spec (1+ (.get owner epoch))))))
        (def first (make-generator UInt (lambda (_random _size) 2) (lambda (_) [0])
          (lambda (_) (set! measured (1+ measured)) (revise 'measure) 1)))
        (def second (make-generator UInt (lambda (_random _size) 2)
          (lambda (_) (set! later (1+ later)) [0])
          (lambda (_) (set! later (1+ later)) 1)))
        (def product (product-generator (Tuple UInt UInt) (list first second)
          (lambda (row) (revise 'unpack) (vector->list row))
          (lambda (row) (set! packs (1+ packs)) (revise 'pack) (list->vector row))))
        (def parent (core.make-generator (lambda (_random _size)
          (if (eq? stage 'pack) (.call product shrink #(2 2)) (.call product measure #(2 2))))
          (lambda (_) []) current?: (lambda () (= stamp (object-revision owner)))))
        (check-exception (core.generate parent (core.random-at 1) 0) core.stale-generation?)
        (check-equal? later 0)
        (check-equal? measured (if (eq? stage 'measure) 1 0))
        (check-equal? packs (if (eq? stage 'pack) 1 0))))))
