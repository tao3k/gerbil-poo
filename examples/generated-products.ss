;;; Typed products inherit the enclosing run's admission through ordinary modules.
(export generated-products-test service-classification-action service-corpus-action)
(import :std/test :std/error :std/iter ../object ../mop ../type ../number ../testing/type
        (prefix-in :clan/poo/testing/property/generator core.)
        (prefix-in :clan/poo/testing/property property.)
        (prefix-in :clan/poo/testing/property/replay corpus.)
        (prefix-in (only-in ../fun Observation.) fun.))

;; A downstream error policy is separate from the typed request domain. Capture
;; recipe authority once, derive/wrap service Records through POO, and deliver the
;; generic report with the ordinary Reader/FUN bind. Retry explicitly prepares a
;; new action; neither a classifier nor seed replay renews the old recipe.
(def (service-classification-action recipe classify consume)
  (def schema (Record count: [UInt] handler: [(Function [Integer] [Integer])]))
  (def stamp (object-revision recipe))
  (def sampler (make-generator schema
    (lambda (_random _size)
      (if (.get recipe blocked?) (raise (.get recipe cause))
        (make-instance schema count: 2 handler: abs)))
    (lambda (value) (if (zero? (.get value count)) [] (list (.cc value count: 0))))
    (cut .get <> count) dependencies: (list recipe)))
  (def domain (property.make-specification (cut element? schema <>) (.@ sampler measure)
    current?: (lambda () (= stamp (object-revision recipe)))))
  (.call fun.Observation. .bind
    (lambda (configuration)
      (property.check-property (generator-core sampler)
        (lambda (value) (= ((.@ value handler) -1) 0)) domain
        seed: (.get configuration seed) cases: (.get configuration cases)
        size: (.get configuration size)
        size-limit: (or (.get configuration size-limit)
          (and (not (procedure? (.get configuration size))) (.get configuration size)))
        shrink-budget: (.get configuration shrink-budget) policy: (.get configuration policy)
        classify-error: classify))
    (lambda (report) (lambda (_configuration) (consume report)))))

;; Compose the existing typed property Reader with portable export. Validation,
;; Function wrapping, generation, shrinking and replay keep their existing owners;
;; the consumer receives one confirmed report and one complete corpus string.
(def (service-corpus-action schema sampler codec consume)
  (property-action schema (lambda (value) (= ((.@ value handler) -1) 0))
    (lambda (report)
      (def output (open-output-string))
      (write-counterexample report codec output)
      (consume report (get-output-string output))) sampler: sampler))

;; The standard suite owns registration; every case uses ordinary public actions.
(def generated-products-test
  (test-suite "nested typed product admission"
    (test-case "service corpus scopes stop obsolete Record packing and retry through FUN"
      (for (stage '(encode decode))
        (def schema (Record count: [UInt] zone: [(Enum east west)] handler: [(Function [Integer] [Integer])]))
        (def bundle (Record report: [Object] wire: [String]))
        (def settings (.o epoch: 0))
        (def nested 0) (def delivered 0) (def properties 0) (def decoded #f)
        (def sampler (make-generator schema
          (lambda (_random _size) (make-instance schema count: 2 zone: 'east handler: abs))
          (lambda (value) (if (zero? (.get value count)) [] (list (.cc value count: 0)))) (cut .get <> count)))
        (def configuration (make-instance PropertyConfiguration seed: 31 cases: 1 size: 3 shrink-budget: 10))
        ;; Each codec captures its own revision. Nested map owns the ordinary
        ;; representation transformation, including checked Function construction.
        (def (prepare fault)
          (def stamp (object-revision settings))
          ;; This controlled change is observed before any nested map callback.
          (def (transform phase value pack)
            (when (eq? fault phase)
              (.putslot! settings 'epoch ($constant-slot-spec (1+ (.get settings epoch)))))
            (core.sample-value (core.generate (core.generator-map (core.generator-unit value)
              (lambda (value) (set! nested (1+ nested)) (pack value))) (core.random-at 31) 0)))
          (corpus.make-codec '(service 1)
            (lambda (value) (transform 'encode value (lambda (value) (list (.get value count) (.get value zone)))))
            (lambda (value) (transform 'decode value (lambda (row)
              (set! decoded (make-instance schema count: (car row) zone: (cadr row) handler: abs)) decoded)))
            current?: (lambda () (= stamp (object-revision settings)))))
        ;; POO Record bundles retain named outputs instead of positional progress data.
        (def (consume report wire)
          (set! delivered (1+ delivered)) (make-instance bundle report: report wire: wire))
        (def bad (prepare stage))
        (if (eq? stage 'encode)
          (begin
            (check-exception ((service-corpus-action schema sampler bad consume) configuration) Error?)
            (check-equal? (list nested delivered) '(0 0)))
          (let (published ((service-corpus-action schema sampler bad consume) configuration))
            (set! nested 0)
            (check-exception (read-counterexample sampler bad (open-input-string (.get published wire))
              (lambda (_) (set! properties (1+ properties)) #f)) Error?)
            (check-equal? (list nested properties) '(0 0))
            (check-eq? decoded #f)))
        (def codec (prepare 'none))
        (def fresh ((service-corpus-action schema sampler codec consume) configuration))
        (check-equal? (.get (.get (.get fresh report) counterexample) count) 0)
        (check (read-counterexample sampler codec (open-input-string (.get fresh wire))
          (lambda (value) (= ((.@ value handler) -1) 0))) => #f)
        (check-exception ((.@ decoded handler) 'invalid) TypeError?)
        (check (replay-counterexample (.get fresh report)) => #f)
        (check-eq? (.get (replay-property (.get fresh report)) status) 'failed)
        (check-equal? delivered (if (eq? stage 'encode) 1 2))
        (check-exception (write-counterexample (.get fresh report) bad (open-output-string)) Error?)))
    (test-case "Record Function service classification retires its recipe then retries through FUN"
      (def cause (cons 'service 'unavailable))
      (def recipe (.o bind-these: #f blocked?: #t cause: cause))
      (def classified 0) (def delivered 0)
      (def configuration (make-instance PropertyConfiguration seed: 23 cases: 1 size: 3 shrink-budget: 10))
      ;; Negotiation replaces the declared recipe: its normal unsupported result
      ;; is obsolete, and the original service failure stays available for diagnosis.
      (def (classify original)
        (check-eq? original cause)
        (set! classified (1+ classified))
        (.putslot! recipe 'blocked? ($constant-slot-spec #f))
        'unsupported)
      ;; Reader composition delivers exactly one completed report per action.
      (def (consume report) (set! delivered (1+ delivered)) report)
      (def old-action (service-classification-action recipe classify consume))
      (def old (old-action configuration))
      (check-eq? (property.report-status old) 'stale)
      (check-eq? (property.report-cause old) cause)
      (check-equal? (list classified delivered) '(1 1))
      (check-exception (property.replay-property old) Error?)
      (let (fresh ((service-classification-action recipe classify consume) configuration))
        (check-eq? (property.report-status fresh) 'failed)
        (check-equal? (.get (property.report-counterexample fresh) count) 0)
        (check-exception ((.@ (property.report-counterexample fresh) handler) 'invalid) TypeError?)
        (check (property.replay-counterexample fresh) => #f)
        (check-eq? (property.report-status (property.replay-property fresh)) 'failed))
      (check-equal? (list classified delivered) '(1 2))
      (check-eq? (property.report-status (old-action configuration)) 'stale)
      (check-equal? (list classified delivered) '(1 3))
      (check-exception (property.replay-property old) Error?))
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
