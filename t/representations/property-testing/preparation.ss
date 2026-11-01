;;; Typed preparation suites share the caller's original deterministic fixtures.
(export make-preparation-suites)
(import :std/test :std/error :std/iter :clan/poo/object :clan/poo/mop
        :clan/poo/type :clan/poo/number :clan/poo/testing/type :clan/poo/testing/function
        (prefix-in :clan/poo/testing/property/generator core.)
        (prefix-in :clan/poo/testing/property property.)
        (prefix-in :clan/poo/testing/property/replay replay.)
        (prefix-in (only-in :clan/poo/support/testing require-property-passed) standard.)
        (only-in :clan/poo/support/option some)
        (only-in :clan/poo/testing/generation-graph generation-refusal?))

;; Build the four original suites in order, retaining the supplied fixture
;; procedures rather than copying generators or replacing any test callback.
(def (make-preparation-suites fixed-integer integer-trace-model)
(def sampler-binding-test
  (test-suite "typed sampler declaration bindings"
    (test-case "raw recursive and trace samplers reject inherited descriptor retargeting"
      (for (kind '(raw recursive trace))
        (def calls 0)
        (def original (case kind
          ((raw) (make-generator Integer (lambda (_random _size) 0) (lambda (_) []) abs))
          ((recursive) (generator Integer))
          ((trace) (trace-generator Integer (make-instance TraceGenerator Command: Integer State: Integer
            Result: Integer Observation: Integer initial: (lambda () 0)
            enabled?: (lambda (_state _command) #t) advance: (lambda (state _command) (values state 0))
            observe: identity draw: (lambda (_state _random _size) #f) shrink: (lambda (_) []) measure: abs)))))
        (def target (Exactly 999))
        (def changed (.cc original descriptor: target sources: []))
        (def report (check-property target (lambda (_) (set! calls (1+ calls)) #t) sampler: changed cases: 1 size: 0))
        (check-eq? (.get report status) 'error)
        (check (.get report replayable?) => #f)
        (check-equal? calls 0)
        (check-exception (generator-core changed) Error?)
        (check-exception (inspect-generator changed count: 1) Error?)
        (check-exception (replay-property report) Error?)))
    (test-case "declared dependency replacement cannot erase the actual descriptor source"
      (for (stage '(draw property measure shrink))
        (def descriptor (.cc Integer epoch: 0))
        ;; Change one real source at the selected checked action boundary.
        (def (revise phase) (when (eq? stage phase) (.putslot! descriptor 'epoch ($constant-slot-spec 1))))
        (def sampler (.cc (make-generator descriptor
          (lambda (_random _size) (revise 'draw) 2)
          (lambda (_) (revise 'shrink) [0])
          (lambda (value) (revise 'measure) (abs value))) sources: []))
        (def report (check-property descriptor (lambda (_) (revise 'property) (eq? stage 'property))
          sampler: sampler cases: 1 shrink-budget: 10))
        (check-eq? (.get report status) 'stale)
        (check (and (assq descriptor (.get report sources)) #t) => #t)
        (check-exception (replay-property report) Error?)))
    (test-case "diagnostic labels retain mandatory Type ownership with empty dependencies"
      (def descriptor (.cc Integer epoch: 0)) (def draws 0)
      (def sampler (.cc (make-generator descriptor (lambda (_random _size) (set! draws (1+ draws)) 1)
        (lambda (_) []) abs) sources: []))
      (def result (inspect-generator sampler count: 2 labels: (lambda (_)
        (.putslot! descriptor 'epoch ($constant-slot-spec 1)) [])))
      (check-eq? (property.inspection-status result) 'stale)
      (check-equal? draws 1)
      (check (property.inspection-current? result) => #f))
    (test-case "portable binding refusal consumes no input and invokes no generator factory"
      (def decodes 0) (def properties 0) (def bindings 0)
      (def target (Exactly 999))
      (def changed (.cc (generator Integer) descriptor: target))
      (def codec (replay.make-codec 'strict identity (lambda (value) (set! decodes (1+ decodes)) value)))
      (def input (open-input-string "#(property-counterexample 1 strict 999)"))
      (check-exception (read-counterexample changed codec input (lambda (_) (set! properties (1+ properties)) #f)) Error?)
      (check-eq? (peek-char input) #\#)
      (check-equal? (list decodes properties) '(0 0))
      (def fresh (.cc (from-generator target (core.generator-unit 999) (lambda (_) 0))
        generation: (lambda (_owner) (set! bindings (1+ bindings)) (core.generator-unit 999))))
      (check (read-counterexample fresh codec input (lambda (_) (set! properties (1+ properties)) #f)) => #f)
      (check-equal? (list decodes properties bindings) '(1 1 0)))
    (test-case "products Maps and Function inputs reject mismatched child declarations"
      (def supplied #f) (def properties 0)
      (def target (.cc (Exactly 999) .generator: (lambda () supplied)))
      (set! supplied (.cc (generator Integer) descriptor: target))
      (check-exception (product-generator (Tuple target) (list supplied) vector->list list->vector) Error?)
      (check-exception (map-generator (Map Symbol -> target) [] supplied) Error?)
      (def report (check-property (FunctionArguments (Function [Integer] (list target)))
        (lambda (_) (set! properties (1+ properties)) #t) cases: 1 size: 0))
      (check-eq? (.get report status) 'error)
      (check-equal? properties 0))
    (test-case "trace model and List declaration changes retire the compiled acceptance protocol"
      (for (owner '(model descriptor))
        (def draws 0) (def properties 0)
        (def model (make-instance TraceGenerator Command: Integer State: Integer Result: Integer Observation: Integer
          initial: (lambda () 0) enabled?: (lambda (_state _command) #t)
          advance: (lambda (state _command) (values state 0)) observe: identity
          draw: (lambda (_state _random _size) (set! draws (1+ draws))
            (some (if (eq? (.get model Command) String) "changed" 1)))
          shrink: (lambda (_) []) measure: (lambda (_) 1)))
        (def sampler (trace-generator Integer model steps: 1))
        (def descriptor (.get sampler descriptor))
        (if (eq? owner 'model)
          (.putslot! model 'Command ($constant-slot-spec String))
          (.putslot! descriptor 'type ($constant-slot-spec String)))
        (def old (check-property descriptor (lambda (_) (set! properties (1+ properties)) #t)
          sampler: (.cc sampler sources: []) cases: 1 size: 1))
        (check-eq? (.get old status) 'stale)
        (check-equal? (list draws properties) '(0 0))
        (check-exception (replay-property old) Error?)
        (def fresh (trace-generator (.get model Command) model steps: 1))
        (def report (check-property (.get fresh descriptor) (lambda (_) (set! properties (1+ properties)) #t)
          sampler: (.cc fresh sources: []) cases: 1 size: 1))
        (check-eq? (.get report status) 'passed)
        (check-equal? (list draws properties) '(1 1))))
    (test-case "same-descriptor draw and shrink overrides use the declared replacement protocol"
      (def old-draws 0) (def new-draws 0)
      (def original (from-generator Integer (core.make-generator
        (lambda (_random _size) (set! old-draws (1+ old-draws)) 2) (lambda (_) (error "old tree forced"))) abs))
      (def changed (.cc original sources: [] draw: (lambda (_random _size) (set! new-draws (1+ new-draws)) 4)
        shrink: (lambda (value) (if (zero? value) [] [0]))))
      (def report (check-property Integer (lambda (_) #f) sampler: changed cases: 1 shrink-budget: 10))
      (check-eq? (.get report status) 'failed)
      (check-equal? (list (.get report original) (.get report counterexample) old-draws new-draws) '(4 0 0 1))
      (check (replay-counterexample report) => #f)
      (check-eq? (.get (replay-property report) status) 'failed)
      (check-equal? (list old-draws new-draws) '(0 2)))))


;; Preparation is one protocol across all typed model entrypoints. These controls
;; isolate metadata reads from draws, fixtures and later Type validators.
(def trace-preparation-test
  (test-suite "typed trace declaration preparation"
    (test-case "all typed trace entrypoints capture computed metadata before later fields"
      (for (operation '(valid repair check generator))
        (for (retire-at '(1 2))
          (def command-type (.cc Integer epoch: 0)) (def reads 0) (def later 0) (def opened 0)
          (def subject (.o Command: command-type
            State: (begin (set! reads (1+ reads))
              (when (= reads retire-at) (.set! command-type epoch 1)) Integer)
            Result: Integer Observation: (begin (set! later (1+ later)) Integer)
            initial: (lambda () 0) enabled?: (lambda (_state _command) #t)
            advance: (lambda (state command) (values (+ state command) command)) observe: identity
            draw: (lambda (_state _random _size) (some 1)) shrink: (lambda (_) []) measure: abs))
          (check-exception (case operation
            ((valid) (valid-trace? subject '(1))) ((repair) (repair-trace subject '(1)))
            ((check) (check-trace subject '(1) (lambda (_) (set! opened (1+ opened)))))
            ((generator) (trace-generator command-type subject steps: 1))) generation-refusal?)
          (check-equal? reads retire-at)
          ;; First-read refusal cannot enter the next metadata getter or fixture.
          (when (= retire-at 1) (check-equal? later 0))
          (check-equal? opened 0))))
    (test-case "trace preparation retains Type errors and restores nested scope on failure"
      (for (bad (list #f (.o) (.cc (integer-trace-model) Command: #f)))
        (check-exception (valid-trace? bad []) TypeError?)
        (check-exception (repair-trace bad []) TypeError?)
        (check-exception (check-trace bad [] (lambda (_) (error "fixture must not open"))) TypeError?))
      (check-equal? (core.sample-value (core.generate (core.generator-unit 7) (core.random-at 0) 0)) 7))
    (test-case "pure admission and repair stop between state and reply validation"
      (for (operation '(valid repair))
        (def result-type (.cc Integer epoch: 0)) (def later 0) (def initial? #t)
        (def state-type (.cc Integer .validate: (lambda (value)
          (unless initial? (.set! reply-type epoch 1)) value)))
        (def reply-type (.cc result-type .validate: (lambda (value) (set! later (1+ later)) value)))
        (def subject (make-instance TraceModel Command: Integer State: state-type Result: reply-type Observation: Integer
          initial: (lambda () 0) enabled?: (lambda (_state _command) #t)
          advance: (lambda (state command) (set! initial? #f) (values (+ state command) command)) observe: identity))
        (check-exception (if (eq? operation 'valid) (valid-trace? subject '(1)) (repair-trace subject '(1)))
          generation-refusal?)
        (check-equal? later 0)))
    (test-case "computed metadata exceptions remain exact after earlier declaration retirement"
      (def command-type (.cc Integer epoch: 0)) (def cause (cons 'metadata 'fault))
      (def subject (.o Command: command-type State: (begin (.set! command-type epoch 1) (raise cause))
        Result: Integer Observation: Integer initial: (lambda () 0)
        enabled?: (lambda (_state _command) #t)
        advance: (lambda (state command) (values state command)) observe: identity))
      (check-eq? (with-catch identity (lambda () (valid-trace? subject []))) cause)
      (check-equal? (core.sample-value (core.generate (core.generator-unit 9) (core.random-at 0) 0)) 9))))


;; Product preparation uses standard argument contracts and one transient owner
;; scope; no child factory may outlive a revision of another known participant.
(def product-preparation-test
  (test-suite "typed fixed product preparation"
    (test-case "typed topology and representation contracts precede custom factories"
      (def calls 0)
      (def child (.cc (make-generator Integer (lambda (_r _s) 1) (lambda (_) []) abs)
        generation: (lambda (_) (set! calls (1+ calls)) (core.generator-unit 1))))
      (def cycle (list child)) (set-cdr! cycle cycle)
      (for (bad (list #f (cons child 'tail) cycle))
        (check-exception (product-generator (Tuple Integer) bad vector->list list->vector) Error?))
      (check-exception (product-generator (Tuple Integer) (list child) #f list->vector) Error?)
      (check-exception (product-generator (Tuple Integer) (list child) vector->list #f) Error?)
      (check-equal? calls 0))
    (test-case "a factory revision refuses before preparing another known child"
      (for (target '(sampler descriptor dependency hook))
        (def later 0) (def packed 0) (def live #t)
        (def descriptor (.cc Integer epoch: 0)) (def dependency (.o epoch: 0))
        (def last (.cc (make-generator descriptor (lambda (_r _s) 2) (lambda (_) []) abs
          dependencies: (list dependency)) epoch: 0 .current?: (lambda () live)
          generation: (lambda (_) (set! later (1+ later)) (core.generator-unit 2))))
        ;; Both children own this source; sharing may not renew its first epoch.
        (def first (.cc (fixed-integer 1 (lambda (_) [])) sources: (list dependency)
          generation: (lambda (_)
            (case target ((sampler) (.set! last epoch 1)) ((descriptor) (.set! descriptor epoch 1))
              ((dependency) (.set! dependency epoch 1)) ((hook) (set! live #f)))
            (core.generator-unit 1))))
        (check-exception (product-generator (Tuple Integer descriptor) (list first last) vector->list
          (lambda (row) (set! packed (1+ packed)) (list->vector row))) generation-refusal?)
        (check-equal? (list later packed) '(0 0))))
    (test-case "a preparation exception retains its exact cause and restores source scope"
      (def cause (cons 'product 'preparation)) (def later 0)
      (def last (.cc (fixed-integer 2 (lambda (_) [])) epoch: 0
        generation: (lambda (_) (set! later (1+ later)) (core.generator-unit 2))))
      (def first (.cc (fixed-integer 1 (lambda (_) []))
        generation: (lambda (_) (.set! last epoch 1) (raise cause))))
      (check-eq? (with-catch identity (lambda ()
        (product-generator (Tuple Integer Integer) (list first last) vector->list list->vector))) cause)
      (check-equal? later 0)
      (check-equal? (core.sample-value (core.generate (core.generator-unit 9) (core.random-at 0) 0)) 9))))


;; Typed report assertions delegate execution authority to the generic standard
;; check; preparation refusals cannot be promoted by a diagnostic projection.
(def assertion-admission-test
  (test-suite "typed report assertion admission"
    (test-case "typed formatters cannot promote falsification or preparation failure"
      (def report (check-property Integer (lambda (_) #f)
        sampler: (fixed-integer 1 (lambda (_) [])) cases: 1 shrink-budget: 0))
      (def rejected (with-catch values (lambda () (standard.require-property-passed report
        diagnostics: (lambda (_) '((status . passed) (cause . invented)))))))
      (check-eq? (cdr (assq 'status (Error-irritants rejected))) 'failed)
      (check-eq? (cdr (assq 'cause (Error-irritants rejected))) #f)
      (define-type Missing (.cc Type. .element?: exact-integer?))
      (def refused (check-property Missing (lambda (_) #t) cases: 1))
      (def absent (with-catch values (lambda () (standard.require-property-passed refused
        diagnostics: (lambda (_) '((status . passed)))))))
      (check-eq? (cdr (assq 'status (Error-irritants absent))) 'error))
    (test-case "typed rendering inherits actual execution source ownership"
      (def owner (.o epoch: 0)) (def mapped 0)
      (def report (check-property Integer positive? sampler: (fixed-integer 1 (lambda (_) []))
        dependencies: (list owner) cases: 1))
      (def rejected (with-catch values (lambda () (standard.require-property-passed report
        diagnostics: (lambda (_)
          (.set! owner epoch 1)
          (core.generate (core.generator-map (core.generator-unit 1)
            (lambda (value) (set! mapped (1+ mapped)) value)) (core.random-at 0) 0)
          '((status . passed)))))))
      (check-eq? (cdr (assq 'status (Error-irritants rejected))) 'stale)
      (check-equal? mapped 0))
    (test-case "typed preparation refusal preserves its exact cause under rendering failure"
      (def original (cons 'prepare 'fault)) (def secondary (cons 'render 'fault))
      (define-type Refused (.cc Type. .element?: exact-integer? .generator: (lambda () (raise original))))
      (def report (check-property Refused (lambda (_) #t) cases: 1))
      (def rejected (with-catch values (lambda () (standard.require-property-passed report
        diagnostics: (lambda (_) (raise secondary))))))
      (check-eq? (cdr (assq 'cause (Error-irritants rejected))) original)
      (check-eq? (cdr (assq 'diagnostic-cause (Error-irritants rejected))) secondary)
      (def truthful (with-catch values (lambda () (standard.require-property-passed report))))
      (check-eq? (cdr (assq 'cause (Error-irritants truthful))) original))))

  (values sampler-binding-test trace-preparation-test product-preparation-test assertion-admission-test))
