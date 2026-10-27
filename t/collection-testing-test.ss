;;; Stateful PBT reuses descriptor admission, ordinary shrink reports and std/test.
(export collection-testing-test collection-properties-test)
(import :std/test :std/error :std/iter (only-in :std/list/list take) ../object ../mop ../type ../number
        ../testing/type ../support/option
        (prefix-in ../examples/collection-testing collection.)
        (only-in ../examples/collection-properties collection-properties-test))

;; A small dependency oracle isolates sequence repair from table implementation.
(def Command (Tuple (Enum make use) UInt))
;; Logical handle sets are typed data; they contain no pointers or real receipts.
(def State (List UInt))
;; Consumers require their exact producer; no handle renaming is permitted.
(def model (make-instance TraceGenerator Command: Command State: State Result: Bool Observation: State
  initial: (lambda () [])
  enabled?: (lambda (state command) (match command
    (#('make id) (not (memv id state))) (#('use id) (and (memv id state) #t))))
  advance: (lambda (state command) (match command
    (#('make id) (values (cons id state) #t)) (#('use _id) (values state #t))))
  observe: identity
  draw: (lambda (state random _size)
    (some (if (null? state) (vector 'make (random 8)) (vector 'use (car state)))))
  shrink: (lambda (_) []) measure: (lambda (command) (vector-ref command 1))))
;; Reuse one declared fixture shape; every invocation still owns a fresh instance.
(define-type CounterSystem (TraceSystem State))
;; Each callback receives a fresh logical state and may inject one wrong reply.
(def (with-counter use (wrong? #f))
  (use (make-instance CounterSystem initial: [] observe: identity
    step: (lambda (state command)
      (let-values (((next reply) (.call model advance state command)))
        (values next (if (and wrong? (equal? command #(use 2))) #f reply)))))))
;; Match a protocol diagnostic instead of treating any unrelated exception as success.
(def (message? text)
  (lambda (cause) (and (Error? cause) (equal? (Error-message cause) text))))
;; Supplied samplers fix the witness while retaining normal admission and shrinking.
(def (fixed-trace commands (selected model))
  (.cc (trace-generator (.get selected Command) selected) draw: (lambda (_random _size) commands)))

;; All runs retain the standard suite/fixture lifecycle and process/heap guards.
(def collection-testing-test
  (test-suite "typed state-dependent collection properties"
    (test-case "Type generator extension works through the ordinary runner with a strict trace cap"
      (def sampler (trace-generator Command model steps: 2))
      (def report (check-property (.get sampler descriptor) (trace-property model with-counter)
        seed: 41 cases: 12 size: 20))
      (check-equal? (.get report status) 'passed)
      (check-equal? (length (.get report original)) 2)
      (check-exception (trace-generator Command model steps: -1) contract-violation-error?)
      (check-exception (trace-generator Bool model) (message? "trace command descriptor mismatch")))
    (test-case "dependency retirement preserves independent commands and concrete replay does not draw"
      (def draws 0)
      (def commands '(#(make 1) #(make 2) #(use 1) #(use 2)))
      (def sampler (.cc (fixed-trace commands) draw: (lambda (_random _size) (set! draws (1+ draws)) commands)))
      (def property (trace-property model (lambda (use) (with-counter use #t))))
      (def report (check-property (.get sampler descriptor) property sampler: sampler
        cases: 1 shrink-budget: 80))
      (check-equal? (.get report status) 'failed)
      (check-equal? (.get report counterexample) '(#(make 2) #(use 2)))
      (check (.call sampler .accept? (.get report counterexample)) => #t)
      (check-equal? (.get report minimal?) #t)
      (check (replay-counterexample report) => #f)
      (check-equal? draws 1)
      (check-equal? (.get (replay-property report) counterexample) (.get report counterexample))
      (check-equal? draws 2)
      (def diagnostic (check-trace model commands (lambda (use) (with-counter use #t))))
      (check-equal? (.get diagnostic phase) 'result)
      (check-equal? (.get diagnostic index) 3)
      (check-equal? (.get diagnostic command) (some #(use 2))))
    (test-case "invalid traces and malformed model state refuse before fixture effects"
      (def opened 0)
      (def (fixture use) (set! opened (1+ opened)) (with-counter use))
      (check-exception (check-trace model '(#(use 9)) fixture) (message? "invalid command trace"))
      (check-equal? opened 0)
      (check-exception (check-trace (.cc model initial: (lambda () #f)) [] fixture) TypeError?)
      (check-equal? opened 0)
      (def bad (.cc model draw: (lambda _ (some #(use 9)))))
      (def sampler (trace-generator Command bad))
      (check-equal? (.get (check-property (.get sampler descriptor) true sampler: sampler cases: 1) status) 'error))
    (test-case "zero size still checks initial observations and false commands stay present Options"
      (def false-model (.o bind-these: #f Command: Bool State: UInt Result: Bool Observation: UInt
        initial: (lambda () 0) enabled?: (lambda _ #t)
        advance: (lambda (n command) (values (1+ n) command)) observe: identity
        draw: (lambda _ (some #f)) shrink: (lambda (_) []) measure: (lambda (_) 0)))
      (def sampler (trace-generator Bool false-model))
      (def (fixture use) (use (.o bind-these: #f State: UInt initial: 0 observe: identity
        step: (lambda (n command) (values (1+ n) command)))))
      (def report (check-property (.get sampler descriptor) (trace-property false-model fixture)
        sampler: sampler cases: 1 size: 2))
      (check-equal? (.get report status) 'passed)
      (check-equal? (.get report original) '(#f #f))
      (check-equal? (.get (check-trace false-model [] (lambda (use)
        (use (.o bind-these: #f State: UInt initial: 1 step: values observe: identity)))) phase) 'initial))
    (test-case "fixture callbacks cannot skip overwrite or escape a completed comparison"
      (def escaped #f)
      (check-exception (check-trace model [] (lambda (_use) #t))
        (message? "trace fixture did not return its observation"))
      (check-exception (check-trace model [] (lambda (use) (with-counter use) (with-counter use)))
        (message? "trace fixture callback is not active or was reused"))
      (check-exception (check-trace model [] (lambda (use) (with-counter use) (.o matched?: #t)))
        (message? "trace fixture did not return its observation"))
      (check (.get (check-trace model [] (lambda (use) (set! escaped use) (with-counter use))) matched?) => #t)
      (check-exception (with-counter escaped) (message? "trace fixture callback is not active or was reused")))
    (test-case "unexpected callback causes and non-Boolean comparisons remain errors"
      (def cause (list 'original-step-error))
      (def sampler (fixed-trace '(#(make 1))))
      (def property (trace-property model (lambda (use)
        (use (.o bind-these: #f State: State initial: [] observe: identity step: (lambda _ (raise cause)))))))
      (def report (check-property (.get sampler descriptor) property sampler: sampler cases: 1))
      (check-equal? (.get report status) 'error)
      (check (eq? (.get report cause) cause) => #t)
      (check-exception (check-trace model [] with-counter same?: (lambda _ 1))
        (message? "trace equality must return a boolean")))
    (test-case "specification revision refuses a concrete witness before another fixture is opened"
      (def selected (.cc model revision: 0)) (def opened 0)
      (def sampler (fixed-trace '(#(make 2) #(use 2)) selected))
      (def property (trace-property selected (lambda (use) (set! opened (1+ opened)) (with-counter use #t))))
      (def report (check-property (.get sampler descriptor) property sampler: sampler cases: 1 shrink-budget: 0))
      (check-equal? (.get report status) 'failed)
      (.set! selected revision 1)
      (let (before opened)
        (check-exception (replay-counterexample report) (message? "stale property replay"))
        (check-equal? opened before)))
    (test-case "trial shrink and replay fixtures own distinct instances and always unwind"
      (def opened 0) (def closed 0) (def active 0) (def owners [])
      ;; The fixture owns cleanup; the existing runner only composes its callback.
      (def (fixture use)
        (check-equal? active 0)
        (set! active 1) (set! opened (1+ opened))
        (try
          (with-counter (lambda (system)
            (check (and (memq system owners) #t) => #f)
            (set! owners (cons system owners))
            (use system)) #t)
          (finally (set! active 0) (set! closed (1+ closed)))))
      (def sampler (fixed-trace '(#(make 1) #(make 2) #(use 1) #(use 2))))
      (def property (trace-property model fixture))
      (def report (check-property (.get sampler descriptor) property sampler: sampler cases: 1 shrink-budget: 80))
      (check-equal? (.get report status) 'failed)
      (check (> opened 1) => #t)
      (check (replay-counterexample report) => #f)
      (check-equal? (.get (replay-property report) status) 'failed)
      (check-equal? (list active opened) (list 0 closed))
      (check-equal? (length owners) opened)
      ;; An observation exception must unwind the same fixture boundary too.
      (check-exception (check-trace model [] fixture same?: (lambda _ (error "comparison fault")))
        (message? "comparison fault"))
      (check-equal? (list active opened) (list 0 closed)))
    (test-case "the first divergence prevents later steps and unnecessary observations"
      (for (phase '(initial result state))
        (def calls 0) (def observations 0)
        ;; Later commands deliberately raise: continuing after a mismatch is observable.
        (def (fixture use)
          (use (make-instance CounterSystem initial: (if (eq? phase 'initial) '(9) [])
            observe: (lambda (state) (set! observations (1+ observations)) state)
            step: (lambda (state command)
              (set! calls (1+ calls))
              (when (> calls 1) (error "executed beyond first difference"))
              (let-values (((next reply) (.call model advance state command)))
                (values (if (eq? phase 'state) state next) (if (eq? phase 'result) #f reply)))))))
        (def report (check-trace model '(#(make 1) #(use 1) #(make 2)) fixture))
        (check (.get report matched?) => #f)
        (check-equal? (.get report phase) phase)
        (check-equal? (.get report index) 0)
        (check-equal? calls (if (eq? phase 'initial) 0 1))
        (check-equal? observations (if (eq? phase 'state) 2 1))))
    (test-case "actual state reply and observation contracts reject malformed adapters"
      (for (phase '(state result observation))
        ;; The same Record shape and one transition expose each dependent boundary.
        (def (fixture use)
          (use (make-instance CounterSystem initial: []
            observe: (if (eq? phase 'observation) (lambda (_) #f) identity)
            step: (lambda (state command)
              (let-values (((next reply) (.call model advance state command)))
                (values (if (eq? phase 'state) #f next) (if (eq? phase 'result) 'wrong reply)))))))
        (check-exception (check-trace model '(#(make 1)) fixture) TypeError?)))
    (test-case "nested Function command validation survives the trace boundary"
      (def calls 0) (def callback (Fun UInt <- UInt))
      (def command (Tuple (Exactly 'invoke) callback))
      (def selected (.o bind-these: #f Command: command State: UInt Result: Bool Observation: UInt
        initial: (lambda () 0) enabled?: (lambda _ #t) observe: identity
        advance: (lambda (n _) (values n #t))
        draw: (lambda _ (some (vector 'invoke (lambda (n) (set! calls (1+ calls)) n))))
        shrink: (lambda (_) []) measure: (lambda (_) 0)))
      (def sampler (trace-generator command selected))
      (def property (trace-property selected (lambda (use)
        (use (.o bind-these: #f State: UInt initial: 0 observe: identity step: (lambda (n command)
          ((vector-ref command 1) #f) (values n #t)))))))
      (def report (check-property (.get sampler descriptor) property sampler: sampler cases: 1 size: 1))
      (check-equal? (.get report status) 'error)
      (check (TypeError? (.get report cause)) => #t)
      (check-equal? calls 0))
    (test-case "Record command callbacks remain wrapped across complete prefix admission"
      (def calls 0) (def opened 0) (def closed 0)
      (def command (Record kind: [(Enum make use)] id: [UInt] callback: [(Fun UInt <- UInt)]))
      (def selected (.o bind-these: #f Command: command State: State Result: UInt Observation: State
        initial: (lambda () []) observe: identity
        enabled?: (lambda (state request)
          (def present (and (memv (.get request id) state) #t))
          (if (eq? (.get request kind) 'make) (not present) present))
        advance: (lambda (state request)
          (def id (.get request id))
          (if (eq? (.get request kind) 'make) (values (cons id state) id)
            (values state (1+ id))))))
      ;; Real effects see only the callbacks wrapped by the Command Record.
      (def (fixture invalid-argument?)
        (lambda (use)
          (set! opened (1+ opened))
          (try (use (.o bind-these: #f State: State initial: [] observe: identity
            step: (lambda (state request)
              (def id (.get request id))
              (if (eq? (.get request kind) 'make) (values (cons id state) id)
                (values state (.call request callback (if invalid-argument? #f id)))))))
            (finally (set! closed (1+ closed))))))
      ;; Two consumers share producers; their callbacks are ordinary raw fields.
      (def action (lambda (id) (set! calls (1+ calls)) (1+ id)))
      (def requests (for/collect (entry '((make . 1) (make . 2) (use . 1) (use . 2)))
        (.o bind-these: #f kind: (car entry) id: (cdr entry) callback: action)))
      (check (.get (check-trace selected requests (fixture #f)) matched?) => #t)
      (check-equal? calls 2)
      (check-exception (check-trace selected requests (fixture #t)) TypeError?)
      (check-equal? calls 2)
      (check-equal? opened closed)
      (check-equal? opened 2)
      (check-exception (check-trace selected
        (append requests (list (.o kind: 'use id: 99 callback: action))) (fixture #f))
        (lambda (cause) (and (Error? cause) (equal? (Error-message cause) "invalid command trace"))))
      (check-equal? opened 2))
    (test-case "real unique indexes and deltas agree through conflict inverse stale restaging and retry"
      (for (backend '(rationaldict trie))
        (def sampler (trace-generator collection.Command collection.model steps: 48))
        (def report (check-property (.get sampler descriptor) (collection.collection-property backend)
          seed: 73 cases: 8 size: 32 shrink-budget: 80))
        (check-equal? (list (.get report status) (.get report cause)) '(passed #f))
        (check-equal? (take (.get report original) (length collection.lifecycle)) collection.lifecycle)))
    (test-case "four injected faults on both backends shrink to valid reproducible false witnesses"
      (for* ((backend '(rationaldict trie)) (fault '(stale inverse index atomic)))
        (def sampler (trace-generator collection.Command collection.model steps: 32))
        (def report (check-property (.get sampler descriptor) (collection.collection-property backend fault)
          sampler: sampler seed: 19 cases: 1 size: 24 shrink-budget: 80))
        (check-equal? (list (.get report status) (.get report cause)) '(failed #f))
        (check (.call sampler .accept? (.get report counterexample)) => #t)
        (check (< (length (.get report counterexample)) (length (.get report original))) => #t)
        (check (replay-counterexample report) => #f)
        (check-equal? (.get (replay-property report) counterexample) (.get report counterexample))))
    (test-case "downstream Reader/FUN uses the same typed sampler and delivers one report"
      (def delivered 0)
      (def action (collection.collection-tests (lambda (report) (set! delivered (1+ delivered)) (.get report status))))
      (check-equal? (action (.o seed: 41 cases: 2 size: 24 shrink-budget: 40)) 'passed)
      (check-equal? delivered 1))))
