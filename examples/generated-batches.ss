;;; Downstream typed batch properties use the ordinary generator and FUN protocols.
(export make-batch-domain generated-batches-test)
(import (prefix-in ../support/testing pbt.)
        (only-in ../debug property-debug-action)
        (prefix-in :clan/property-testing/property policy.)
        (prefix-in :clan/property-testing/replay corpus.)
        :std/test :std/error ../object ../mop ../type ../number ../testing/type ../testing/function
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
    (test-case "Record dependency revisions stop construction and require explicit fresh preparation"
      (let*-values (((descriptor configuration) (make-batch-domain)))
        (def constructions 0) (def properties 0)
        ;; Fresh preparation captures current typed sources; an old sampler never
        ;; silently refreshes a source revision encountered in its selector.
        (def (prepare revise?)
          (def pipeline (core.generator-bind (generator-core (generator descriptor))
            (lambda (batch)
              (when revise? (.putslot! configuration 'maximum ($constant-slot-spec 8)))
              (core.make-generator (lambda (_random _size)
                (set! constructions (1+ constructions))
                (make-instance Batch count: (.get batch count) payload: (.get batch payload)
                  route: (.get batch route) handler: (.@ batch handler))) (lambda (_) [])))))
          (from-generator descriptor pipeline (lambda (batch) (.get batch count)) dependencies: (list configuration)))
        ;; The requested FUN action returns refusal data without opening the property.
        (def (run sampler)
          ((property-debug-action #f descriptor (lambda (batch)
            (set! properties (1+ properties)) (batch-correct? batch)) sampler: sampler)
            (make-instance PropertyConfiguration seed: 41 cases: 1 size: 3)))
        (def stale (run (prepare #t)))
        (check-eq? (.get stale status) 'stale)
        (check-equal? (list constructions properties) '(0 0))
        (check-exception (replay-property stale) Error?)
        (def fresh (run (prepare #f)))
        (check-eq? (.get fresh status) 'failed)
        (check (> (.get fresh steps) 0) => #t)
        (check-equal? (.get (.get fresh counterexample) count) 2)
        ;; Parent shrinking regenerates dependent children. Concrete replay draws
        ;; none; seed replay must repeat the entire same construction schedule.
        (let ((before constructions) (trials properties))
          (check-eq? (replay-counterexample fresh) #f)
          (check-equal? constructions before)
          (check-equal? properties (1+ trials))
          (check-eq? (.get (replay-property fresh) status) 'failed)
          (check-equal? constructions (* 2 before))
          (check-equal? properties (1+ (* 2 trials))))))
    (test-case "typed corpus policy admits wrapped Record functions without coverage callbacks"
      (let*-values (((descriptor configuration) (make-batch-domain)))
        (def sampler (generator descriptor))
        (def report ((property-debug-action #f descriptor batch-correct? sampler: sampler)
          (make-instance PropertyConfiguration seed: 41 cases: 1 size: 3)))
        ;; Store all logical fields; ordinary construction restores the known handler.
        (def codec (corpus.make-codec '(batch-policy 1)
          (lambda (batch) (list (.get batch count) (.get batch payload) (.get batch route)))
          (lambda (row) (make-instance Batch count: (car row) payload: (cadr row)
            route: (caddr row) handler: abs))))
        (def output (open-output-string))
        (write-counterexample report codec output)
        (def text (get-output-string output))
        (def calls 0)
        (def policy (policy.make-policy precondition: (lambda (batch)
          (and (= ((.@ batch handler) -7) 7) (>= (.get batch count) 2)))
          labels: (lambda (_) (error "replay must not classify coverage")) required: '((batch . 100))))
        (check-eq? (read-counterexample sampler codec (open-input-string text)
          (lambda (batch) (set! calls (1+ calls)) (batch-correct? batch)) policy: policy) #f)
        (check-equal? calls 1)
        (check-exception (read-counterexample sampler codec (open-input-string text)
          (lambda (_) (set! calls (1+ calls)) #f)
          policy: (policy.make-policy precondition: (lambda (_)
            (.putslot! configuration 'maximum ($constant-slot-spec 8)) #t))) Error?)
        (check-equal? calls 1)))
    (test-case "typed Record corpus replay brackets decoding with source revisions"
      (let*-values (((descriptor configuration) (make-batch-domain)))
        (def sampler (generator descriptor))
        (def report ((property-debug-action #f descriptor batch-correct? sampler: sampler)
          (make-instance PropertyConfiguration seed: 41 cases: 1 size: 3)))
        ;; Codecs retain logical data; the normal constructor restores Function wrapping.
        (def (decode payload) (make-instance Batch count: (length payload) payload: payload route: 'put handler: abs))
        (def codec (corpus.make-codec '(batch 1) (lambda (batch) (.get batch payload)) decode))
        (def output (open-output-string))
        (write-counterexample report codec output)
        (def text (get-output-string output))
        (check-eq? (read-counterexample sampler codec (open-input-string text) batch-correct?) #f)
        (def calls 0)
        (def stale-codec (corpus.make-codec '(batch 1) (lambda (batch) (.get batch payload))
          (lambda (payload) (.putslot! configuration 'maximum ($constant-slot-spec 8)) (decode payload))))
        (check-exception (read-counterexample sampler stale-codec (open-input-string text)
          (lambda (_) (set! calls (1+ calls)) #f)) Error?)
        (check-equal? calls 0)
        (def refused (open-output-string))
        (check-exception (write-counterexample report codec refused) Error?)
        (check-equal? (get-output-string refused) "")))
    (test-case "Record FUN shrinking removes middle payloads and retains wrapped callbacks"
      (def generation (core.generator-map
        (core.make-tree-generator (lambda (_random _size)
          (core.sample-sequence (map (lambda (value) (core.make-sample value (lambda () []))) '(11 99 22)))))
        (lambda (payload) (make-instance Batch count: (length payload) payload: payload route: 'put handler: abs))))
      (def sampler (from-generator Batch generation
        (lambda (batch) (+ (.get batch count) (apply + (.get batch payload))))))
      (def action (property-debug-action #f Batch (lambda (batch)
        (not (and (memv 11 (.get batch payload)) (memv 22 (.get batch payload))))) sampler: sampler))
      (def report (action (make-instance PropertyConfiguration seed: 42 cases: 1 shrink-budget: 32)))
      (check-eq? (.get report status) 'failed)
      (check-equal? (.get (.get report counterexample) payload) '(11 22))
      (check-equal? (.get (.get report counterexample) count) 2)
      (check-equal? ((.@ (.get report counterexample) handler) -7) 7)
      (check-eq? (replay-counterexample report) #f)
      (check-equal? (.get (.get (replay-property report) counterexample) payload) '(11 22)))
    (test-case "Reader configuration revisions refuse successful-looking callbacks"
      (def configured (make-instance PropertyConfiguration cases: 2))
      (def calls 0)
      (def action (property-debug-action #f UInt (lambda (_)
        (set! calls (1+ calls)) (.put! configured 'cases 3) #t)))
      (def report (action configured))
      (check-eq? (.get report status) 'stale)
      (check-equal? calls 1)
      (check-exception (replay-property report) Error?))
    (test-case "default POO test support derives fixed named Type products"
      (defvalues (descriptor configuration) (make-batch-domain))
      (pbt.define-property coherent-batch ((batch descriptor) (row UInt) (options UInt))
        (and (= (.get batch count) (length (.get batch payload)))
          (= ((.@ batch handler) -7) 7) (>= (+ row options) row)))
      (coherent-batch seed: 41 cases: 4 size: 3
        policy: (policy.make-policy name: 'external labels: (lambda (_) '(batch)) required: '((batch . 4))))
      (pbt.check-property descriptor (lambda (batch) (= (.get batch count) (length (.get batch payload))))
        seed: 7 cases: 3 size: 4)
      (check-exception (make-instance PropertyConfiguration seed: -1) TypeError?))
    (test-case "Record configuration drives the existing FUN debug and replay workflow"
      (defvalues (descriptor configuration) (make-batch-domain))
      (def calls 0)
      (def output (open-output-string))
      (def configured (make-instance PropertyConfiguration seed: 41 cases: 3 size: 3))
      (def action (property-debug-action 'batch-debug descriptor
        (lambda (batch) (set! calls (1+ calls)) (= (.get batch count) (length (.get batch payload))))))
      (def report (parameterize ((current-error-port output)) (action configured)))
      (check-equal? calls 3)
      (check-eq? (.get report status) 'passed)
      (check (string-prefix? "batch-debug\n" (get-output-string output)) => #t)
      (def failed ((property-debug-action #f descriptor batch-correct?) configured))
      (check-eq? (.get failed status) 'failed)
      (check-equal? (.get (.get failed counterexample) count) 2)
      (check-eq? (replay-counterexample failed) #f)
      (.putslot! configuration 'maximum ($constant-slot-spec 8))
      (check-exception (replay-counterexample failed) Error?))
    (test-case "disabled rendering still executes once and scheduled sizes require bounds"
      (def calls 0)
      (def output (open-output-string))
      (def action (property-debug-action #f UInt (lambda (_) (set! calls (1+ calls)) #t)))
      (def configured (make-instance PropertyConfiguration cases: 3 size: (lambda (trial) trial) size-limit: 3))
      (def report (parameterize ((current-error-port output)) (action configured)))
      (check-equal? calls 3)
      (check-eq? (.get report status) 'passed)
      (check-equal? (get-output-string output) "")
      (check-exception (action (make-instance PropertyConfiguration size: (lambda (trial) trial))) Error?)
      (check-equal? calls 3))
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
