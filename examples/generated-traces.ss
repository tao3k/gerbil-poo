;;; Typed finite shrinking composes existing Record contracts and FUN actions.
(export generated-traces-test)
(import :std/test :std/error :std/iter
        ../object ../mop ../type ../number ../testing/type ../support/option
        (only-in ../testing/generation-graph generation-refusal?)
        (only-in ../debug property-debug-action)
        (prefix-in :clan/poo/testing/property/generator core.))

;; Both malformed forms are finite graphs, detected by Gerbil's standard list?.
(def (malformed-spine item cyclic?)
  (let (head (list item)) (set-cdr! head (if cyclic? head 'malformed)) head))

(def generated-traces-test
  (test-suite "finite typed trace and data preparation"
    (test-case "malformed Record parameter lists cannot publish repaired trace prefixes"
      (for (cyclic? '(#f #t))
        (def command (Record kind: [(Enum open use)] key: [UInt] handler: [(Function [Integer] [Integer])]))
        (def state (List UInt))
        (def draws 0) (def parameters 0) (def opened 0) (def closed 0)
        ;; Oracle replies are independent of the actual wrapped Function field.
        (def (advance previous next)
          (values (if (eq? (.get next kind) 'open) (cons (.get next key) previous) previous)
            (1+ (.get next key))))
        ;; Record initialization alone supplies the Function boundary.
        (def (emit kind)
          (make-instance command kind: kind key: 1 handler: (lambda (value) (1+ value))))
        (def subject (make-instance TraceGenerator Command: command State: state Result: Integer Observation: state
          initial: (lambda () []) enabled?: (lambda (previous next)
            (if (eq? (.get next kind) 'open) (not (memv (.get next key) previous))
              (and (memv (.get next key) previous) #t)))
          advance: advance observe: identity draw: (lambda (previous _random _size)
            (set! draws (1+ draws)) (some (emit (if (null? previous) 'open 'use))))
          shrink: (lambda (item) (set! parameters (1+ parameters)) (malformed-spine item cyclic?))
          measure: (lambda (_) 0)))
        (def system-type (TraceSystem state))
        ;; Scope cleanup remains owned by the real differential fixture.
        (def (fixture use)
          (set! opened (1+ opened))
          (try (use (make-instance system-type initial: [] observe: identity step: (lambda (previous next)
            (values (if (eq? (.get next kind) 'open) (cons (.get next key) previous) previous)
              (+ ((.@ next handler) (.get next key)) (if (eq? (.get next kind) 'use) 1 0))))))
            (finally (set! closed (1+ closed)))))
        ;; Fresh preparation changes the callback explicitly; it never salvages a tail.
        (def (prepare model)
          (let (sampler (trace-generator command model steps: 3))
            (property-debug-action #f (.get sampler descriptor) (trace-property model fixture) sampler: sampler)))
        (def configuration (make-instance PropertyConfiguration seed: 7 cases: 1 size: 3 shrink-budget: 64))
        (def report ((prepare subject) configuration))
        (check-eq? (.get report status) 'error)
        ;; Returned structural proposals remain charged before a demanded
        ;; parameter spine refuses. The refusal itself returns no proposal.
        (check-equal? (list parameters draws opened closed (.get report attempts) (.get report steps)) '(1 3 7 7 6 1))
        (check-equal? (map (cut .get <> kind) (.get report original)) '(open use use))
        (check-equal? (map (cut .get <> kind) (.get report counterexample)) '(open use))
        (check (valid-trace? subject (.get report counterexample)) => #t)
        (check (.get report minimal?) => #f)
        (check-exception ((.@ (cadr (.get report counterexample)) handler) 'invalid) TypeError?)
        ;; A diagnostic retained value does not authorize replay of an error
        ;; report or another fixture entry, even when that value was confirmed.
        (check-exception (replay-counterexample report) Error?)
        (check-equal? (list parameters draws opened closed) '(1 3 7 7))
        ;; Full replay reconstructs the same trace, proposal prefix and refusal.
        (def replayed (replay-property report))
        (check-eq? (.get replayed status) 'error)
        (check-equal? (map (cut .get <> kind) (.get replayed counterexample)) '(open use))
        (check-equal? (list (.get replayed attempts) (.get replayed steps)) '(6 1))
        (check-equal? (list parameters draws opened closed) '(2 6 14 14))
        (def fresh ((prepare (.cc subject shrink: (lambda (_) []))) configuration))
        (check-eq? (.get fresh status) 'failed)
        (check-equal? (map (cut .get <> kind) (.get fresh counterexample)) '(open use))
        (check-exception ((.@ (cadr (.get fresh counterexample)) handler) 'invalid) TypeError?)
        (let (before draws)
          (check (replay-counterexample fresh) => #f)
          (check-equal? draws before)
          (check-eq? (.get (replay-property fresh) status) 'failed)
          (check-equal? draws (+ 3 before)))
        (check-equal? opened closed)))
    (test-case "service retry owns fixture declarations through shrinking and both replays"
      (def command (Record key: [UInt] handler: [(Function [Integer] [Integer])]))
      (def opened 0) (def closed 0) (def mapped 0)
      ;; The oracle never invokes the implementation's Function-valued field.
      (def subject (make-instance TraceGenerator Command: command State: Integer Result: Integer Observation: Integer
        initial: (lambda () 0) observe: identity
        enabled?: (lambda (state next) (= state (.get next key)))
        advance: (lambda (state next) (values (1+ state) (1+ (.get next key))))
        draw: (lambda (state _random _size)
          (some (make-instance command key: state handler: (lambda (value) (1+ value)))))
        shrink: (lambda (_) []) measure: (lambda (_) 0)))
      ;; A fresh actual State declaration is acquired per fixture, independently
      ;; of the model. Cleanup retires it only after use has restored its scope.
      (def (fixture retire? use)
        (def state-type (.cc Integer epoch: 0))
        (set! opened (1+ opened))
        (try (use (make-instance (TraceSystem state-type) initial: 0 observe: identity
          step: (lambda (state next)
            (when retire?
              (.set! state-type epoch 1)
              (core.generate (core.generator-map (core.generator-unit 0)
                (lambda (value) (set! mapped (1+ mapped)) value)) (core.random-at 0) 0))
            (values (1+ state) (+ ((.@ next handler) (.get next key))
              (if (= (.get next key) 1) 1 0))))))
          (finally (.set! state-type epoch 2) (set! closed (1+ closed)))))
      ;; The debug action is the existing FUN report boundary, not a new runner.
      (def (prepare retire?)
        (let (sampler (trace-generator command subject steps: 3))
          (property-debug-action #f (.get sampler descriptor)
            (trace-property subject (cut fixture retire? <>)) sampler: sampler)))
      (def options (make-instance PropertyConfiguration seed: 31 cases: 1 size: 3 shrink-budget: 64))
      (def refused ((prepare #t) options))
      (check-eq? (.get refused status) 'stale)
      (check-equal? (list mapped opened closed) '(0 1 1))
      (def fresh ((prepare #f) options))
      (check-eq? (.get fresh status) 'failed)
      (check-equal? (map (cut .get <> key) (.get fresh counterexample)) '(0 1))
      (check-exception ((.@ (car (.get fresh counterexample)) handler) 'invalid) TypeError?)
      (check (replay-counterexample fresh) => #f)
      (check-eq? (.get (replay-property fresh) status) 'failed)
      (check-equal? opened closed)
      (check-equal? mapped 0))
    (test-case "computed service declarations reject mixed epochs before FUN preparation"
      (def command (.cc (Record kind: [(Enum open use)] key: [UInt]
        handler: [(Function [Integer] [Integer])]) epoch: 0))
      (def draws 0) (def opened 0) (def closed 0)
      ;; Declared dependencies make a use command meaningful only after open.
      (def (advance state next)
        (values (if (eq? (.get next kind) 'open) (cons (.get next key) state) state)
          (1+ (.get next key))))
      ;; Computed Type metadata may discover a revision during preparation.
      ;; Fresh preparation is explicit; it does not renew an older action.
      (def (subject retire?)
        (.o bind-these: #f Command: command State: (begin (when retire? (.set! command epoch 1)) (List UInt))
          Result: Integer Observation: (List UInt) initial: (lambda () []) observe: identity
          enabled?: (lambda (state next)
            (if (eq? (.get next kind) 'open) (not (memv (.get next key) state))
              (and (memv (.get next key) state) #t)))
          advance: advance draw: (lambda (state _random _size)
            (set! draws (1+ draws))
            (some (make-instance command kind: (if (null? state) 'open 'use) key: 1 handler: (lambda (n) (1+ n)))))
          shrink: (lambda (_) []) measure: (lambda (_) 0)))
      ;; Actual execution owns one fixture per observation and closes on failure.
      (def (fixture use)
        (set! opened (1+ opened))
        (try (use (make-instance (TraceSystem (List UInt)) initial: [] observe: identity
          step: (lambda (state next)
            (let-values (((updated _reply) (advance state next)))
              (values updated (+ ((.@ next handler) (.get next key))
                (if (eq? (.get next kind) 'use) 1 0)))))))
          (finally (set! closed (1+ closed)))))
      ;; The existing Reader/FUN debug action owns checking, shrinking and replay.
      (def (prepare retire?)
        (let* ((model (subject retire?)) (sampler (trace-generator command model steps: 3)))
          (property-debug-action #f (.get sampler descriptor) (trace-property model fixture) sampler: sampler)))
      (def options (make-instance PropertyConfiguration seed: 41 cases: 1 size: 3 shrink-budget: 64))
      (def old (prepare #f))
      (check-exception (prepare #t) generation-refusal?)
      (check-equal? (list draws opened closed) '(0 0 0))
      (check-eq? (.get (old options) status) 'stale)
      (def fresh ((prepare #f) options))
      (check-eq? (.get fresh status) 'failed)
      (check-equal? (map (cut .get <> kind) (.get fresh counterexample)) '(open use))
      (check-exception ((.@ (car (.get fresh counterexample)) handler) 'invalid) TypeError?)
      (check (replay-counterexample fresh) => #f)
      (check-eq? (.get (replay-property fresh) status) 'failed)
      (check-equal? opened closed))
    (test-case "String Symbol and Bytes share finite preparation and source refusal"
      ;; One codec-parametric fixture exercises all standard carriers. Every value
      ;; field keeps its exact descriptor; no unconstrained element fallback exists.
      (def (exercise descriptor pack unpack items marker)
        (def payload (Record value: [descriptor] handler: [(Function [Integer] [Integer])]))
        (def configuration (.o epoch: 0))
        (def packs 0) (def parameters 0)
        ;; Mapping and Function wrapping start only after the complete policy returns.
        (def (packet rows)
          (set! packs (1+ packs)) (make-instance payload value: (pack rows) handler: abs))
        ;; The same shared value policy supplies finite proper candidates to every codec.
        (def (prepare mode)
          (let (sampler (make-generator payload (lambda (_random _size) (packet items))
            (lambda (value)
              (map packet (core.data-list-shrinks (unpack (.get value value)) (lambda (item)
                (set! parameters (1+ parameters))
                (case mode
                  ((improper) (malformed-spine item #f)) ((cycle) (malformed-spine item #t))
                  ((revise) (.putslot! configuration 'epoch ($constant-slot-spec (1+ (.get configuration epoch)))) [])
                  ((proper) []) (else (error "unknown preparation mode" mode)))) 0)))
            (lambda (value) (length (unpack (.get value value)))) dependencies: (list configuration)))
            (property-debug-action #f payload (lambda (value)
              (check-equal? ((.@ value handler) -3) 3)
              (not (member marker (unpack (.get value value))))) sampler: sampler)))
        (def options (make-instance PropertyConfiguration seed: 11 cases: 1 size: 2 shrink-budget: 32))
        (for (mode '(improper cycle revise))
          (set! packs 0) (set! parameters 0)
          (let (report ((prepare mode) options))
            (check-eq? (.get report status) (if (eq? mode 'revise) 'stale 'error))
            (check-equal? (list packs parameters (.get report attempts) (.get report steps)) '(1 1 0 0))
            (check-equal? (unpack (.get (.get report counterexample) value)) items)
            (check-exception (replay-counterexample report) Error?)))
        (let (fresh ((prepare 'proper) options))
          (check-eq? (.get fresh status) 'failed)
          (check-equal? (unpack (.get (.get fresh counterexample) value)) (list marker))
          (check-exception ((.@ (.get fresh counterexample) handler) 'invalid) TypeError?)
          (let (before packs)
            (check (replay-counterexample fresh) => #f)
            (check-equal? packs before))
          (check-eq? (.get (replay-property fresh) status) 'failed)))
      (exercise String list->string string->list '(#\b #\b) #\b)
      (exercise Symbol (lambda (rows) (string->symbol (list->string rows)))
        (lambda (value) (string->list (symbol->string value))) '(#\b #\b) #\b)
      (exercise Bytes list->u8vector u8vector->list '(2 2) 2))
    (test-case "Record trace revisions stop before dependent actions and fresh FUN preparation retries"
      (for (target '(initial draw enabled advance))
        (def command (Record key: [UInt] handler: [(Function [Integer] [Integer])]))
        (def owner (.o epoch: 0))
        (def calls []) (def checked 0)
        ;; A declared owner revision is separate from the model's UInt state.
        (def (touch phase revise?)
          (set! calls (append calls (list phase)))
          (when (and revise? (eq? target phase))
            (.putslot! owner 'epoch ($constant-slot-spec (1+ (.get owner epoch))))))
        ;; The same Record/FUN protocol handles stale refusal and fresh preparation.
        (def (prepare revise?)
          (let* ((model (make-instance TraceGenerator Command: command State: UInt Result: Integer Observation: UInt
                    initial: (lambda () (touch 'initial revise?) 0)
                    enabled?: (lambda (state item) (touch 'enabled revise?) (= state (.get item key)))
                    advance: (lambda (state item) (touch 'advance revise?)
                      (values (1+ state) ((.@ item handler) state)))
                    observe: identity measure: (lambda (_) 0)
                    draw: (lambda (state _random _size) (touch 'draw revise?)
                      (some (make-instance command key: state handler: abs))) shrink: (lambda (_) [])))
                 (sampler (trace-generator command model steps: 2 dependencies: (list owner))))
            (property-debug-action #f (.get sampler descriptor) (lambda (commands)
              (set! checked (1+ checked))
              (check-equal? (map (cut .get <> key) commands) '(0 1))
              (check-exception ((.@ (car commands) handler) 'invalid) TypeError?) #t) sampler: sampler)))
        (def configuration (make-instance PropertyConfiguration seed: 23 cases: 1 size: 2 shrink-budget: 0))
        (def old-action (prepare #t))
        (let (report (old-action configuration))
          (check-eq? (.get report status) 'stale)
          (check-eq? (.get report cause) #f)
          (check-eq? (last calls) target)
          (check-equal? checked 0))
        (set! calls [])
        ;; Construction already captured the retired declaration/dependency epoch.
        ;; Reusing this action must refuse before any model callback runs again.
        (check-eq? (.get (old-action configuration) status) 'stale)
        (check-equal? calls [])
        (check-equal? checked 0)
        (check-eq? (.get ((prepare #f) configuration) status) 'passed)
        (check-equal? checked 1)))))
