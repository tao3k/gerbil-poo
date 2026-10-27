;;; Descriptor-driven finite testing; pseudo-random sources belong to one run.
(export make-generator generator product-generator check-property replay-property replay-counterexample trace-generator check-trace trace-property property-action TraceModel TraceGenerator TraceSystem)
(import (only-in ./support/base require-value) :std/error :std/iter (only-in :std/list/list map-in-order delete-duplicates/hash take drop)
        ./object ./mop (only-in ./type String Exactly. Enum. List Record)
        ./generation-graph ./recursive-generation ./support/option
        (only-in ./number Integer UInt)
        (prefix-in ./generalized-prototype observation.))
;; Gambit's SRFI-27 operations are host builtins, kept local to this module.
(extern namespace: #f make-random-source random-source-pseudo-randomize! random-source-make-integers)

;; Recognition-only callable fields deliberately do not wrap shrink callbacks:
;; invalid proposals must reach the existing attempt-budget/domain gate, rather
;; than become premature Function output errors. No arity/termination is inferred.
(define-type Procedure (.cc Type. .element?: procedure?))
;; One existing Record contract owns sampler shape and source-list admission.
(define-type GeneratorRecord
  (Record descriptor: [Type] draw: [Procedure] shrink: [Procedure]
          measure: [Procedure] sources: [(List Object)]))
;; Public samplers retain ordinary Record/Class initialization and validation.
;; Additional mutable callback dependencies remain explicit source objects.
(def (make-generator descriptor draw shrink measure dependencies: (dependencies []))
  (make-instance GeneratorRecord descriptor: descriptor draw: draw shrink: shrink
    measure: measure sources: (cons descriptor dependencies)))

;; The core model and generation hooks share ordinary Record inheritance. Types
;; describe the domains; the evaluator alone handles their dependent transitions.
(define-type TraceModel
  (Record Command: [Type] State: [Type] Result: [Type] Observation: [Type]
          initial: [Procedure] enabled?: [Procedure] advance: [Procedure] observe: [Procedure]))
;; This extends the SAME model contract, not a parallel state-machine framework.
(define-type TraceGenerator
  (Record [TraceModel] draw: [Procedure] shrink: [Procedure] measure: [Procedure]))
;; Initial actual state is declared by the fixture, including retired cache data.
;; Callers may name/reuse this Record descriptor through their own define-type.
(def (TraceSystem state-type)
  (Record State: [Type constant: state-type] initial: [state-type]
          step: [Procedure] observe: [Procedure]))

;; Snapshot both descriptor and sampler identities; prototype revisions propagate
;; through object-revision, including inherited declaration changes.
(def (generator-sources sampler)
  (cons sampler (.get sampler sources)))
;; Capture mutable sources once before the first trial.
(def (snapshot sampler dependencies)
  (map (lambda (source) (cons source (object-revision source)))
       (delete-duplicates/hash (append (generator-sources sampler) dependencies))))
;; Refuse result admission after any declared source changed, including callbacks.
(def (current? sources (sampler #f))
  (and (every (lambda (entry) (= (cdr entry) (object-revision (car entry)))) sources)
       (or (not sampler) (not (.has? sampler .current?)) (.call sampler .current?))))
;; Measures are natural numbers; malformed callbacks cannot admit shrink steps.
(def (weight sampler value)
  (def n (.call sampler measure value))
  (unless (and (exact-integer? n) (>= n 0)) (error "invalid shrink measure" n))
  n)
;; Replace one coordinate through a persistent reconstruction callback.
(def (coordinate-shrinks children values pack)
  (let loop ((children children) (values values) (before []))
    (if (null? children) []
      (append
        (map (lambda (smaller) (pack (append (reverse before) (cons smaller (cdr values)))))
             (.call (car children) shrink (car values)))
        (loop (cdr children) (cdr values) (cons (car values) before))))))
;; Products share draw/shrink/measure composition for tuples, pairs and call rows.
(def (product-generator descriptor children unpack pack)
  (make-generator descriptor
    (lambda (random size) (pack (map-in-order (lambda (child) (.call child draw random size)) children)))
    (lambda (value) (coordinate-shrinks children (unpack value) pack))
    (lambda (value) (apply + (map weight children (unpack value))))
    dependencies: (apply append (map generator-sources children))))

;; Integer shrinking decreases absolute magnitude and reaches zero without using
;; floating point. The runner independently enforces domain and strict descent.
(def (integer-shrinks value)
  (if (zero? value) []
    (delete-duplicates/hash (list 0 (quotient value 2) (- value (if (> value 0) 1 -1))))))
;; Custom scalar callbacks retain explicit obligations; standard exact/enumerated
;; Types are finite leaves and never require recursive data predicates.
(def (scalar-generator descriptor)
  (cond
    ((.has? descriptor .generator)
     (let (sampler (.call descriptor .generator))
       (unless (and (object? sampler) (eq? (.get sampler descriptor) descriptor))
         (error "generator descriptor mismatch")) sampler))
    ((eq? descriptor Bool)
     (make-generator descriptor (lambda (random _) (= (random 2) 1))
       (lambda (x) (if x [#f] [])) (lambda (x) (if x 1 0))))
    ((or (eq? descriptor Integer) (eq? descriptor UInt))
     (make-generator descriptor
       (lambda (random size) (if (eq? descriptor UInt) (random (+ size 1)) (- (random (+ (* 2 size) 1)) size)))
       integer-shrinks abs))
    ((eq? descriptor String)
     (make-generator descriptor
       (lambda (random size) (list->string (map (lambda (_) (integer->char (+ 97 (random 26)))) (iota (random (+ size 1))))))
       (lambda (x) (if (zero? (string-length x)) [] (list "" (substring x 0 (quotient (string-length x) 2)))))
       string-length))
    (else
      (def ancestors (compute-precedence-list! descriptor))
      (cond
        ((memq Exactly. ancestors)
         (make-generator descriptor (lambda (_random _size) (.get descriptor value)) (lambda (_) []) (lambda (_) 0)))
        ((memq Enum. ancestors)
         (def values (.get descriptor vals))
         (.cc (make-generator descriptor (lambda (random _size)
           (when (null? values) (refuse-generation 'empty))
           (list-ref values (random (length values)))) (lambda (_) []) (lambda (_) 0))
           .inhabited?: (and (pair? values) #t)))
        (else (error "descriptor requires an explicit .generator" descriptor))))))

;; Recursive carrier graphs share one bounded compiler, including mutually
;; recursive/shared Types and deterministic invocation-local scalar draws.
(def (generator descriptor (depth 32) node-budget: (nodes 256)
                descriptor-budget: (descriptors 256) search-budget: (search 8192))
  (validate Type descriptor)
  (recursive-generator descriptor depth nodes descriptors search make-generator scalar-generator))

;; Recognition uses the sampler's bounded grammar when present, avoiding a native
;; recursive Type predicate on cyclic carriers or unguarded descriptor aliases.
(def (accepts-value? sampler value)
  (if (.has? sampler .accept?) (.call sampler .accept? value)
    (element? (.get sampler descriptor) value)))

;; Shrink a witnessed false result. Every proposed candidate consumes one unit,
;; even if invalid/nondecreasing; restart only on a smaller valid false result.
;; The callbacks must terminate and return finite proper lists. External process
;; watchdogs bound arbitrary host callbacks; fuel bounds this algorithm's attempts.
(def (shrink-failure sampler property original budget sources)
  (let/cc return
    (let loop ((best original) (remaining budget) (attempts 0) (steps 0))
      (unless (current? sources sampler) (return (list 'stale best attempts steps #f)))
      (def candidates (.call sampler shrink best))
      (require-value candidates list? (lambda () (error "shrinker must return a finite proper list")))
      (let scan ((rest candidates) (remaining remaining) (attempts attempts))
        (unless (current? sources sampler) (return (list 'stale best attempts steps #f)))
        (cond
          ((null? rest) (list 'failed best attempts steps #t))
          ((zero? remaining) (list 'failed best attempts steps #f))
          (else
            (def value (car rest))
            (def eligible (and (accepts-value? sampler value)
                               (< (weight sampler value) (weight sampler best))))
            (unless (current? sources sampler) (return (list 'stale best (+ attempts 1) steps #f)))
            (def outcome (if eligible (property value) #t))
            (unless (boolean? outcome) (error "property must return a boolean" outcome))
            (unless (current? sources sampler) (return (list 'stale best (+ attempts 1) steps #f)))
            (if (not outcome) (loop value (- remaining 1) (+ attempts 1) (+ steps 1))
              (scan (cdr rest) (- remaining 1) (+ attempts 1)))))))))

;; Finite seeded testing is evidence, not universal verification. Errors retain
;; their cause; neither generation errors nor property exceptions become passes.
;; minimal? means no smaller failing immediate supplied candidate, never global.
(def (check-property descriptor property seed: (seed 0) cases: (cases 100)
                     size: (size 20) shrink-budget: (shrink-budget 100) sampler: (supplied #f)
                     dependencies: (dependencies []) depth: (depth 32) node-budget: (nodes 256)
                     descriptor-budget: (descriptors 256) search-budget: (search 8192))
  (unless (and (procedure? property) (every (lambda (n) (and (exact-integer? n) (>= n 0)))
                          (list seed size shrink-budget)) (exact-integer? cases) (> cases 0)
               (list? dependencies) (every object? dependencies))
    (error "invalid property testing configuration"))
  (def sampler supplied)
  (def sources [])
  (def trial 0)
  (def original #f)
  ;; Initialization failures retain configuration and cause. An incomplete graph
  ;; has no complete dependency snapshot, so its report explicitly refuses replay.
  (def (report status counterexample attempts steps minimal? (cause #f))
    (.o bind-these: #f status: status descriptor: descriptor property: property sampler: sampler
        seed: seed cases: cases size: size shrink-budget: shrink-budget sources: sources
        trial: trial original: original counterexample: counterexample attempts: attempts
        steps: steps minimal?: minimal? cause: cause dependencies: dependencies
        replayable?: (and sampler #t)
        depth: depth node-budget: nodes descriptor-budget: descriptors search-budget: search
        limits: (and sampler (.has? sampler limits) (.get sampler limits))))
  (with-catch
    (lambda (cause) (report
      (cond ((or (not (current? sources sampler))
                 (and (generation-refusal? cause) (eq? (generation-refusal-kind cause) 'stale))) 'stale)
            ((and (generation-refusal? cause) (eq? (generation-refusal-kind cause) 'unguarded)) 'unsupported)
            ((generation-refusal? cause) 'exhausted) (else 'error)) original 0 0 #f cause))
    (lambda ()
      (set! sampler (or supplied (generator descriptor depth node-budget: nodes
                                               descriptor-budget: descriptors search-budget: search)))
      (unless (eq? (.get sampler descriptor) descriptor) (error "sampler descriptor mismatch"))
      (set! sources (snapshot sampler dependencies))
      (def source (make-random-source))
      (random-source-pseudo-randomize! source 0 seed)
      (def random (random-source-make-integers source))
      (let/cc return
        (for (_ (in-range cases))
          (unless (current? sources sampler) (return (report 'stale #f 0 0 #f)))
          (set! trial (+ trial 1))
          ;; A failed draw has no candidate for this trial; never reuse a previous
          ;; successful trial as the reported error's original/counterexample.
          (set! original #f)
          (set! original (.call sampler draw random size))
          (unless (accepts-value? sampler original) (error "generator produced a value outside its descriptor" original))
          (unless (current? sources sampler) (return (report 'stale original 0 0 #f)))
          (def outcome (property original))
          (unless (boolean? outcome) (error "property must return a boolean" outcome))
          (unless (current? sources sampler) (return (report 'stale original 0 0 #f)))
          (unless outcome
            (let (result (shrink-failure sampler property original shrink-budget sources))
              (return (apply report result)))))
        (report 'passed #f 0 0 #f)))))

;; Replay the exact configuration only while descriptor and callback revisions
;; remain current. Repeatability assumes stable callback behavior and host PRNG.
(def (replay-property report)
  (unless (.get report sampler) (error "generation compilation did not produce a replayable sampler"))
  (unless (current? (.get report sources) (.get report sampler)) (error "stale property replay"))
  (check-property (.get report descriptor) (.get report property)
    seed: (.get report seed) cases: (.get report cases) size: (.get report size)
    shrink-budget: (.get report shrink-budget) sampler: (.get report sampler)
    dependencies: (.get report dependencies) depth: (.get report depth)
    node-budget: (.get report node-budget) descriptor-budget: (.get report descriptor-budget)
    search-budget: (.get report search-budget)))

;; Reader/FUN composition makes the test run one observation followed by the
;; supplied consumer, which may be an existing IO action or an evidence gate.
(def (property-action descriptor property consume sampler: (sampler #f) dependencies: (dependencies []))
  (.call observation.Observation. .bind
    (lambda (configuration) (check-property descriptor property
      sampler: sampler dependencies: dependencies
      seed: (.get configuration seed) cases: (.get configuration cases)
      size: (.get configuration size) shrink-budget: (.get configuration shrink-budget)
      depth: (if (.has? configuration depth) (.get configuration depth) 32)
      node-budget: (if (.has? configuration node-budget) (.get configuration node-budget) 256)
      descriptor-budget: (if (.has? configuration descriptor-budget) (.get configuration descriptor-budget) 256)
      search-budget: (if (.has? configuration search-budget) (.get configuration search-budget) 8192)))
    (lambda (report) (lambda (_configuration) (consume report)))))


;; Concrete replay reuses revision/domain admission but consumes no PRNG draws.
;; A passing/error/stale report cannot impersonate a valid false witness. Source
;; currentness is checked again after successful execution; callback errors escape.
(def (replay-counterexample report)
  (unless (eq? (.get report status) 'failed) (error "failed property report required"))
  (def sampler (.get report sampler)) (def sources (.get report sources))
  (unless (and sampler (current? sources sampler)) (error "stale property replay"))
  (def witness (.get report counterexample))
  (unless (accepts-value? sampler witness) (error "invalid property witness"))
  (unless (current? sources sampler) (error "stale property replay"))
  (def outcome ((.get report property) witness))
  (unless (current? sources sampler) (error "stale property replay"))
  (require-value outcome boolean? (lambda () (error "property must return a boolean" outcome))))


;; Preconditions are Boolean judgments, not truthy evidence or caught exceptions.
(def (trace-enabled? model state command)
  (require-value (.call model enabled? state command) boolean?
    (lambda () (error "trace precondition must return a boolean"))))

;; Normalize each pure reference successor through its declared State descriptor.
;; Result admission is shared by generation, repair and differential execution.
(def (advance-trace model state command)
  (defvalues (next result) (.call model advance state command))
  (values (validate (.get model State) next) (validate (.get model Result) result)))

;; Fold one selected reference prefix. Selection is an ordinary higher-order
;; policy: strict admission exits on a disabled command; repair omits it. Both
;; share typed transition semantics and preserve the order of retained commands.
(def (fold-trace model commands select)
  (foldl (lambda (raw progress)
    (match (select (car progress) raw)
      (#f progress)
      ((some command)
       (let-values (((next _reply) (advance-trace model (car progress) command)))
         (cons next (cons command (cdr progress)))))))
    (cons (validate (.get model State) (.call model initial)) []) commands))

;; Whole-prefix membership checks no fixture. Invalid logical dependencies leave
;; through the standard escape continuation, not a second recursive validator.
(def (valid-trace? model commands)
  (let/cc invalid
    (unless (list? commands) (invalid #f))
    (fold-trace model commands (lambda (state command)
      (unless (and (element? (.get model Command) command) (trace-enabled? model state command))
        (invalid #f))
      (some command)))
    #t))

;; Retirement is a selection over the SAME typed fold. It preserves independent
;; suffixes without renaming handles, inventing producers or drawing random data.
(def (repair-trace model commands)
  (reverse (cdr (fold-trace model commands (lambda (state raw)
    (and (element? (.get model Command) raw)
      (let (command (validate (.get model Command) raw))
        (and (trace-enabled? model state command) (some command)))))))))

;; Build an ordinary List sampler; the existing runner owns random sources,
;; report stamps, proposal budgets and strict decrease/falsity admission.
;; Only the bounded command spine is specialized, not the generation framework.
(def (trace-generator command-type model steps: (steps 64) dependencies: (dependencies []))
  (def source model)
  (set! model (validate TraceGenerator model))
  (unless (eq? command-type (.get model Command)) (error "trace command descriptor mismatch"))
  (using (steps :~ (lambda (n) (and (fixnum? n) (<= 0 n 65536))))
    (def result #f)
    ;; The Type's existing .generator extension makes this sampler usable by
    ;; ordinary check-property/property-action without a parallel dispatch path.
    (def descriptor (.cc (List command-type)
      .generator: (lambda () (or result (error "trace generator not initialized")))))
    (def sampler (make-generator descriptor
      (lambda (random size)
        (let/cc done
          (def progress (for/fold (progress (cons (validate (.get model State) (.call model initial)) []))
              (_ (in-range (min steps size)))
            (match (.call model draw (car progress) random size)
              (#f (done (reverse (cdr progress))))
              ((some raw)
               (def command (validate command-type raw))
               (unless (trace-enabled? model (car progress) command) (error "disabled generated command" command))
               (let-values (((next _reply) (advance-trace model (car progress) command)))
                 (cons next (cons command (cdr progress)))))
              (else (error "trace draw requires Option")))))
          (reverse (cdr progress))))
      (lambda (commands)
        (append
          (for/collect (index (in-range (length commands)))
            (repair-trace model (append (take commands index) (drop commands (1+ index)))))
          (coordinate-shrinks (make-list (length commands) model) commands
            (cut repair-trace model <>))))
      (lambda (commands)
        (+ (length commands) (apply + (map (lambda (command) (weight model command)) commands))))
      dependencies: (append (list source TraceGenerator command-type (.get model State)
        (.get model Result) (.get model Observation)) dependencies)))
    (set! result (.cc sampler .accept?: (lambda (commands)
      (and (list? commands) (<= (length commands) steps) (valid-trace? model commands)))
      limits: (.o bind-these: #f steps: steps)))
    result))

;; Validate observed replies and snapshots at ONE comparison boundary. A declared
;; equality relation must return Boolean; an exception is an error, never a pass.
(def (trace-equal? descriptor same? expected actual)
  (def left (validate descriptor expected)) (def right (validate descriptor actual))
  (require-value (same? left right) boolean? (lambda () (error "trace equality must return a boolean"))))

;; Preflight the whole normalized command list before opening a fresh scoped
;; fixture. Compare initial state, then each reply/state exactly once; stop on
;; first divergence. Reports contain observations, never actual fixture owners.
(def (check-trace model commands with-system same?: (same? equal?))
  (set! model (validate TraceModel model))
  (require-value (list with-system same?) (list-of? procedure?) (lambda () (error "invalid trace consumer")))
  (def normalized (validate (List (.get model Command)) commands))
  (unless (valid-trace? model normalized) (error "invalid command trace"))
  ;; A false command remains present through Option; initial mismatch has no command.
  (def (report matched? phase index command expected actual)
    (.o bind-these: #f matched?: matched? phase: phase index: index command: command
        expected: expected actual: actual))
  ;; One scoped callback cannot overwrite a mismatch, escape, or be replayed.
  (def (run system)
    (set! system (validate (TraceSystem (.get system State)) system))
    (let/cc different
      ;; Comparison is composed once, then reused for initial/result/state phases.
      (def (compare phase index command descriptor expected actual)
        (unless (trace-equal? descriptor same? expected actual)
          (different (report #f phase index command expected actual))))
      (def reference (validate (.get model State) (.call model initial)))
      (def actual (.get system initial))
      (compare 'initial 0 #f (.get model Observation) (.call model observe reference) (.call system observe actual))
      ;; One higher-order state fold owns both transitions and stops at the first
      ;; difference. Every actual step and every observation executes once.
      (for/fold (states (cons reference actual)) ((command normalized) (index (in-range (length normalized))))
        (let*-values (((next expected) (advance-trace model (car states) command))
                      ((raw found) (.call system step (cdr states) command))
                      ((updated) (validate (.get system State) raw)))
          (compare 'result index (some command) (.get model Result) expected found)
          (compare 'state index (some command) (.get model Observation)
            (.call model observe next) (.call system observe updated))
          (cons next updated)))
      (report #t 'complete (length normalized) #f #f #f)))
  (def active? #t) (def entered? #f) (def result #f)
  (try
    (let (returned (with-system (lambda (system)
      (unless (and active? (not entered?)) (error "trace fixture callback is not active or was reused"))
      (set! entered? #t)
      (set! result (run system)) result)))
      (unless (and entered? result (eq? returned result)) (error "trace fixture did not return its observation"))
      result)
    (finally (set! active? #f))))

;; This is only the Boolean projection expected by check-property. Fresh-fixture
;; lifetime and exact step diagnostics remain in the existing callback/IO layer.
(def (trace-property model with-system same?: (same? equal?))
  (lambda (commands) (.get (check-trace model commands with-system same?: same?) matched?)))
