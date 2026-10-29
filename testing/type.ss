;;; Descriptor-driven finite testing; pseudo-random sources belong to one run.
(export PropertyConfiguration inspect-generator report-diagnostics make-generator from-generator generator-core generator product-generator check-property replay-property replay-counterexample trace-generator check-trace trace-property property-action TraceModel TraceGenerator TraceSystem)
(import (only-in ../support/base require-value) :std/error :std/iter (only-in :std/list/list map-in-order delete-duplicates/hash take drop)
        ../object ../mop (only-in ../type String Symbol Bytes BytesN. Exactly. Enum. List Record OrFalse Or)
        ./generation-graph ./recursive-generation ../support/option
        (only-in ../number Integer UInt)
        (prefix-in :clan/property-testing/property testing.)
        (prefix-in :clan/property-testing/generator core.)
        (prefix-in (only-in :clan/property-testing/generator make-generator) testing.)
        (only-in :clan/property-testing/generator integer-shrinks)
        (prefix-in :clan/property-testing/model model.)
        (prefix-in (only-in ../fun Observation.) fun.))
;; Recognition-only callable fields deliberately do not wrap shrink callbacks:
;; invalid proposals must reach the existing attempt-budget/domain gate, rather
;; than become premature Function output errors. No arity/termination is inferred.
(define-type Procedure (.cc Type. .element?: procedure?))
;; One existing Record contract owns sampler shape and source-list admission.
(define-type GeneratorRecord
  (Record descriptor: [Type] draw: [Procedure] shrink: [Procedure]
          measure: [Procedure] sources: [(List Object)] generation: [(OrFalse Procedure) default: #f]))
;; Generic policy recognition stays with the independent library's record type.
(define-type PropertyPolicy (.cc Type. .element?: testing.policy?))
;; Standard Record defaults make one bounded configuration usable by FUN actions.
;; Procedure-valued sizes require an explicit size-limit at the runner boundary.
(define-type PropertyConfiguration
  (Record seed: [UInt default: 0] cases: [UInt default: 100]
    size: [(Or UInt Procedure) default: 20] shrink-budget: [UInt default: 100]
    size-limit: [(OrFalse UInt) default: #f] policy: [PropertyPolicy default: (testing.make-policy)]
    depth: [UInt default: 32] node-budget: [UInt default: 256]
    descriptor-budget: [UInt default: 256] search-budget: [UInt default: 8192]))
;; Public samplers retain ordinary Record/Class initialization and validation.
;; Additional mutable callback dependencies remain explicit source objects.
(def (make-generator descriptor draw shrink measure dependencies: (dependencies []) generation: (generation #f))
  (unless (or (not generation) (core.generator? generation)) (error "generic generator required"))
  (make-instance GeneratorRecord descriptor: descriptor draw: draw shrink: shrink
    measure: measure sources: (cons descriptor dependencies)
    ;; A derived sampler that replaces a value callback owns a new protocol.
    ;; Do not keep using the inherited sample tree after that override.
    generation: (and generation (lambda (owner)
      (and (eq? (.get owner draw) draw) (eq? (.get owner shrink) shrink) generation)))))
;; Type metadata and measures stay in POO; sample provenance stays in the generic
;; generator. Value-only shrinking, when needed by a domain, is explicitly supplied.
(def (from-generator descriptor generation measure dependencies: (dependencies [])
                     shrink: (shrink (lambda (_) (error "value-only shrink callback required"))))
  (unless (core.generator? generation) (error "generic generator required"))
  (make-generator descriptor (lambda (random size) (core.sample-value (core.generate generation random size)))
    shrink measure dependencies: dependencies generation: generation))

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
;; Prepare the optional hook once. Source revisions are still checked before
;; every call, so a replaced/inherited hook cannot acquire fresh authority.
(def (source-guard sources sampler)
  (def hook (and (.has? sampler .current?) (.@ sampler .current?)))
  (lambda () (and (every (lambda (entry) (= (cdr entry) (object-revision (car entry)))) sources)
    (or (not hook) (hook)))))
;; Capture one typed boundary without dismantling the generator's lazy tree.
;; Raw callback samplers are lifted once here; sample-tree compositions stay intact.
(def (generator-core sampler)
  (def sources (snapshot sampler []))
  (def owned (.get sampler generation))
  (core.generator-map (or (and owned (owned sampler))
    (core.make-generator (.@ sampler draw) (cut sampler-children sampler <>))) identity
    current?: (source-guard sources sampler)))
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
  (from-generator descriptor
    (core.generator-map (core.generator-sequence (map generator-core children)) pack)
    (lambda (value) (apply + (map weight children (unpack value))))
    shrink: (lambda (value) (coordinate-shrinks children (unpack value) pack))
    dependencies: (apply append (map generator-sources children))))

;; Standard data Types reuse the independent algebra, including its lazy shrink tree.
;; Content weight permits same-length coordinate shrinking; required byte lengths
;; remain explicit rather than silently falling back to a different Type.
(def (data-generator descriptor (length #f))
  (def bytes? (or length (eq? descriptor Bytes)))
  (def symbol? (eq? descriptor Symbol))
  (def unpack (cond (bytes? u8vector->list) (symbol? (lambda (value) (string->list (symbol->string value))))
                    (else string->list)))
  (def pack (cond (bytes? list->u8vector) (symbol? (lambda (value) (string->symbol (list->string value))))
                  (else list->string)))
  (def code (if bytes? identity char->integer))
  (def lower (or length 0))
  (def generation (cond (bytes? (core.generator-bytes min-length: lower max-length: (or length 128)))
                       (symbol? (core.generator-symbol)) (else (core.generator-string))))
  (from-generator descriptor generation
    (lambda (value) (foldl (lambda (item total) (+ total 1 (code item))) 0 (unpack value)))
    shrink: (lambda (value) (map pack (core.data-list-shrinks (unpack value)
      (if bytes? integer-shrinks core.character-shrinks) lower)))))

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
    ((or (eq? descriptor String) (eq? descriptor Symbol) (eq? descriptor Bytes))
     (data-generator descriptor))
    (else
      (def ancestors (compute-precedence-list! descriptor))
      (cond
        ((memq BytesN. ancestors) (data-generator descriptor (.get descriptor n)))
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
  (recursive-generator descriptor depth nodes descriptors search make-generator scalar-generator generator-core))

;; Recognition uses the sampler's bounded grammar when present, avoiding an unbounded
;; recursive Type predicate on cyclic carriers or unguarded descriptor aliases.
(def (accepts-value? sampler value)
  (if (.has? sampler .accept?) (.call sampler .accept? value)
    (element? (.get sampler descriptor) value)))

;; Compile the typed domain boundary once. The independent kernel receives only
;; admission/cost/current callbacks, never a Type, Record or object-revision API.
(def (property-specification sampler sources)
  (testing.make-specification (cut accepts-value? sampler <>) (.@ sampler measure)
    current?: (source-guard sources sampler)))
;; Typed diagnostics reuse the existing sampler bridge and captured Type sources.
;; Preparation errors remain ordinary Type errors; execution refusals retain the
;; generic inspection status/cause. No property, assertion or coverage is run.
(def (inspect-generator sampler seed: (seed 0) count: (count 10) size: (size 20)
                       depth: (depth 0) proposal-budget: (budget 0) labels: (labels (lambda (_) [])))
  (def sources (snapshot sampler []))
  (testing.inspect-generator (generator-core sampler) (property-specification sampler sources)
    seed: seed count: count size: size depth: depth proposal-budget: budget
    labels: labels classify-error: generation-status))

;; Interpret only POO's own generation refusal categories. All other exceptions
;; keep their original cause and the kernel owns ordinary failure/error reporting.
(def (generation-status cause)
  (cond ((and (generation-refusal? cause) (eq? (generation-refusal-kind cause) 'stale)) 'stale)
        ((and (generation-refusal? cause) (eq? (generation-refusal-kind cause) 'unguarded)) 'unsupported)
        ((generation-refusal? cause) 'exhausted) (else 'error)))
;; POO-derived shrink callbacks retain their proper-list contract at one boundary.
;; The generic kernel itself consumes standard iterators and knows no POO grammar.
(def (sampler-children sampler value)
  (require-value (.call sampler shrink value) list?
    (lambda () (error "shrinker must return a finite proper list"))))
;; This layer owns Type compilation and the POO report projection. Trial execution,
;; PRNG ownership, bounded shrinking and both replay algorithms have one generic owner.
(def (check-property descriptor property seed: (seed 0) cases: (cases 100)
                     size: (size 20) shrink-budget: (shrink-budget 100) sampler: (supplied #f)
                     size-limit: (size-limit (and (not (procedure? size)) size))
                     policy: (policy (testing.make-policy)) name: (name #f)
                     dependencies: (dependencies []) depth: (depth 32) node-budget: (nodes 256)
                     descriptor-budget: (descriptors 256) search-budget: (search 8192))
  (unless (and (procedure? property) (every (lambda (n) (and (exact-integer? n) (>= n 0)))
    (list seed shrink-budget)) (or (procedure? size) (and (exact-integer? size) (>= size 0)))
    (exact-integer? cases) (> cases 0)
    (list? dependencies) (every object? dependencies)) (error "invalid property testing configuration"))
  (def sampler #f) (def sources [])
  ;; Initialization can fail before a complete snapshot exists; those reports
  ;; remain explicitly non-replayable. Successful executions retain opaque provenance.
  (def (report status original counterexample attempts steps minimal? cause execution)
    (.o bind-these: #f status: status descriptor: descriptor property: property sampler: sampler
      seed: seed cases: cases size: size size-limit: size-limit shrink-budget: shrink-budget sources: sources
      name: (if execution (testing.report-name execution) name)
      accepted: (if execution (testing.report-accepted execution) 0)
      discarded: (if execution (testing.report-discarded execution) 0)
      labels: (if execution (testing.report-labels execution) [])
      trial: (if execution (testing.report-trial execution) 0)
      trial-size: (and execution (testing.report-trial-size execution)) original: original counterexample: counterexample
      attempts: attempts steps: steps minimal?: minimal? cause: cause dependencies: dependencies
      replayable?: (and execution #t) execution: execution
      depth: depth node-budget: nodes descriptor-budget: descriptors search-budget: search
      limits: (and sampler (.has? sampler limits) (.get sampler limits))))
  (with-catch
    (lambda (cause) (report (if (not (current? sources sampler)) 'stale (generation-status cause))
      #f #f 0 0 #f cause #f))
    (lambda ()
      (set! sampler (or supplied (generator descriptor depth node-budget: nodes
        descriptor-budget: descriptors search-budget: search)))
      (unless (eq? (.get sampler descriptor) descriptor) (error "sampler descriptor mismatch"))
      (set! sources (snapshot sampler dependencies))
      (def execution (testing.check-property
        (generator-core sampler) property
        (property-specification sampler sources) seed: seed cases: cases size: size
        size-limit: size-limit
        shrink-budget: shrink-budget classify-error: generation-status policy: policy name: name))
      (report (testing.report-status execution) (testing.report-original execution)
        (testing.report-counterexample execution) (testing.report-attempts execution)
        (testing.report-steps execution) (testing.report-minimal? execution)
        (testing.report-cause execution) execution))))

;; Project generic replay back to the same POO metadata, retaining the exact
;; originally captured sources rather than taking a permissive fresh snapshot.
(def (replayed-report report execution)
  (.cc report name: (testing.report-name execution) accepted: (testing.report-accepted execution)
    discarded: (testing.report-discarded execution) labels: (testing.report-labels execution)
    status: (testing.report-status execution) trial: (testing.report-trial execution)
    trial-size: (testing.report-trial-size execution)
    original: (testing.report-original execution) counterexample: (testing.report-counterexample execution)
    attempts: (testing.report-attempts execution) steps: (testing.report-steps execution)
    minimal?: (testing.report-minimal? execution) cause: (testing.report-cause execution) execution: execution))
;; Standard test integration consumes the same generic report when preparation
;; succeeded. Early Type/generator refusals retain their own cause and phase.
(def (report-diagnostics report bindings: (names []))
  (def execution (.get report execution))
  (if execution (testing.report-diagnostics execution bindings: names)
    (list (cons 'status (.get report status)) (cons 'property (.get report name))
      (cons 'phase 'preparation) (cons 'seed (.get report seed))
      (cons 'trial (.get report trial)) (cons 'cause (.get report cause)))))
;; Seeded replay delegates to the independent kernel's captured provenance.
(def (replay-property report)
  (unless (.get report replayable?) (error "property report has no replayable generator"))
  (unless (current? (.get report sources) (.get report sampler)) (error "stale property replay"))
  (replayed-report report (testing.replay-property (.get report execution))))

;; Reader/FUN composition makes the test run one observation followed by the
;; supplied consumer, which may be an existing IO action or an evidence gate.
;; The configuration is itself a revision source, including callback-driven edits.
(def (property-action descriptor property consume sampler: (sampler #f) dependencies: (dependencies []))
  (.call fun.Observation. .bind
    (lambda (configuration) (check-property descriptor property
      sampler: sampler dependencies: (cons configuration dependencies)
      policy: (if (.has? configuration policy) (.get configuration policy)
        (testing.make-policy))
      seed: (.get configuration seed) cases: (.get configuration cases)
      size: (.get configuration size) shrink-budget: (.get configuration shrink-budget)
      size-limit: (or (and (.has? configuration size-limit) (.get configuration size-limit))
        (and (not (procedure? (.get configuration size))) (.get configuration size)))
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
  (unless (current? (.get report sources) (.get report sampler)) (error "stale property replay"))
  (testing.replay-counterexample (.get report execution)))


;; Normalize each pure reference successor through its declared State descriptor.
;; Result admission is shared by generation, repair and differential execution.
(def (advance-trace model state command)
  (defvalues (next result) (.call model advance state command))
  (values (validate (.get model State) next) (validate (.get model Result) result)))

;; Type preparation is a domain layer over the ordinary Gerbil model protocol.
;; Every normalized reference successor still uses the declared State/Result Types.
(def (prepare-model model (normalize identity))
  (model.make-model
    (lambda () (validate (.get model State) (.call model initial)))
    (.@ model enabled?) (cut advance-trace model <> <>) (.@ model observe)
    (cut element? (.get model Command) <>) normalize))
;; Prefix admission and dependency repair share the generic fold; neither owns a
;; second traversal or invokes an actual backend during model validation.
(def (valid-trace? model commands) (model.valid-trace? (prepare-model model) commands))
;; The domain normalizer preserves nested Function wrapping while retiring dependents.
(def (repair-trace model commands) (model.repair-trace (prepare-model model (cut validate (.get model Command) <>)) commands))

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
        (model.draw-trace (prepare-model model (cut validate (.get model Command) <>))
          (lambda (state random size)
            (match (.call model draw state random size)
              (#f (values #f #f)) ((some command) (values #t command))
              (else (error "trace draw requires Option")))) steps random size))
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
  (same? left right))

;; Preflight the whole normalized command list before opening a fresh scoped
;; fixture. Compare initial state, then each reply/state exactly once; stop on
;; first divergence. Reports contain observations, never actual fixture owners.
(def (check-trace model commands with-system same?: (same? equal?))
  (set! model (validate TraceModel model))
  (require-value with-system procedure? (lambda () (error "trace fixture must be a procedure")))
  (require-value same? procedure? (lambda () (error "trace equality must be a procedure")))
  (def normalized (validate (List (.get model Command)) commands))
  (def execution (model.check-trace (prepare-model model) normalized
    (lambda (use)
      (with-system (lambda (system)
        (set! system (validate (TraceSystem (.get system State)) system))
        (use (model.make-system (.get system initial)
          (lambda (state command)
            (let-values (((next result) (.call system step state command)))
              (values (validate (.get system State) next) result))) (.@ system observe))))))
    same?: (lambda (phase left right)
      (trace-equal? (if (eq? phase 'result) (.get model Result) (.get model Observation)) same? left right))))
  (.o bind-these: #f matched?: (model.trace-report-matched? execution) phase: (model.trace-report-phase execution)
    index: (model.trace-report-index execution)
    command: (and (model.trace-report-has-command? execution) (some (model.trace-report-command execution)))
    expected: (model.trace-report-expected execution) actual: (model.trace-report-actual execution)))

;; This is only the Boolean projection expected by check-property. Fresh-fixture
;; lifetime and exact step diagnostics remain in the existing callback/IO layer.
(def (trace-property model with-system same?: (same? equal?))
  (lambda (commands) (.get (check-trace model commands with-system same?: same?) matched?)))
