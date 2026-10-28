;;; Downstream typed batch properties use the ordinary generator and FUN protocols.
(export make-batch-domain generated-batches-test)
(import :std/test :std/error ../object ../mop ../type ../number ../testing/type ../testing/function
        (prefix-in :clan/property-testing/generator core.))

;; Record construction owns nested Function wrapping; the property runner does
;; not invent a second record recognizer or procedure representation.
(define-type Batch
  (Record count: [UInt] payload: [(List UInt)] route: [(Enum put remove)]
          handler: [(Function [Integer] [Integer])]))

;; Each application owns its mutable generation configuration. The derived Type
;; and sampler declare it as a source, so stale reports cannot silently rebind it.
(def (make-batch-domain)
  (def configuration (.o maximum: 5))
  (def counts (core.make-generator
    (lambda (_random size) (min size (.get configuration maximum))) core.integer-shrinks))
  (def elements (core.generator-map
    (core.make-generator (lambda (random _size) (- (1+ (random 8)))) core.integer-shrinks) abs))
  (def batches
    (core.bind-generators
      ((count counts)
       (route (core.generator-frequency
         (list (cons 3 (core.generator-unit 'put)) (cons 1 (core.generator-unit 'remove)))))
       (payload (core.generator-sequence (make-list count elements))))
      (make-instance Batch count: count payload: payload route: route handler: abs)))
  (def descriptor
    (.o self: domain inherit: [Type.]
      .element?: (lambda (value) (and (element? Batch value)
        (= (.get value count) (length (.get value payload)))
        (<= (.get value count) (.get configuration maximum))))
      .generator: (lambda () (from-generator domain batches (lambda (value) (.get value count))
        dependencies: (list Batch configuration)))))
  (values descriptor configuration))

;; One callback represents an injected application fault. Valid construction and
;; Function wrapping are checked even when the selected route is not faulty.
(def (batch-correct? batch)
  (and (= ((.@ batch handler) -7) 7) (< (.get batch count) 2)))

;; These are ordinary exported suites discovered by Gerbil's standard runner.
(def generated-batches-test
  (test-suite "composed typed batch generation"
    (test-case "sized weighted batches shrink through Reader FUN and replay"
      (defvalues (descriptor configuration) (make-batch-domain))
      (def deliveries 0)
      (def action (property-action descriptor batch-correct?
        (lambda (report) (set! deliveries (1+ deliveries)) report)))
      (def report (action (.o seed: 41 cases: 8 size: (lambda (trial) trial) size-limit: 8 shrink-budget: 96)))
      (check-equal? (list (.get report status) (.get report trial) (.get report trial-size) deliveries)
        '(failed 2 2 1))
      (def witness (.get report counterexample))
      (check (element? descriptor witness) => #t)
      (check-equal? (.get witness count) 2)
      (check-equal? (length (.get witness payload)) 2)
      (check-exception ((.@ witness handler) "wrong") TypeError?)
      (check (replay-counterexample report) => #f)
      (check-equal? (.get (replay-property report) status) 'failed)
      (.putslot! configuration 'maximum ($constant-slot-spec 8))
      (check-exception (replay-counterexample report) Error?))
    (test-case "bounded recursive containers retain custom leaf sample trees"
      (defvalues (descriptor configuration) (make-batch-domain))
      (def container (Tuple descriptor (Pair descriptor Bool)))
      (def report (check-property container
        (lambda (value) (batch-correct? (vector-ref value 0)))
        cases: 1 size: 5 seed: 7 shrink-budget: 96))
      (check-equal? (.get report status) 'failed)
      (check (element? container (.get report counterexample)) => #t)
      (check-equal? (.get (vector-ref (.get report counterexample) 0) count) 2)
      (check (replay-counterexample report) => #f))
    (test-case "Function call rows share typed product provenance"
      (defvalues (descriptor configuration) (make-batch-domain))
      (def arguments (FunctionArguments (Function [UInt] [descriptor])))
      (def report (check-property arguments (lambda (row) (batch-correct? (car row)))
        cases: 1 size: 5 seed: 83 shrink-budget: 96))
      (check-equal? (.get report status) 'failed)
      (check-equal? (.get (car (.get report counterexample)) count) 2)
      (check (element? arguments (.get report counterexample)) => #t)
      (check (replay-counterexample report) => #f))))
