;;; Descriptor-driven finite testing; pseudo-random sources belong to one run.
(export write-counterexample read-counterexample PropertyConfiguration inspect-generator report-diagnostics make-generator from-generator generator-core generator product-generator map-generator check-property replay-property replay-counterexample trace-generator valid-trace? repair-trace check-trace trace-property property-action TraceModel TraceGenerator TraceSystem)
(import (only-in :std/func compose) (only-in ../support/base require-value) :std/error :std/iter (only-in :std/list/list map-in-order delete-duplicates/hash)
        ../object ../mop (only-in ../type Rational String Symbol Keyword Bytes BytesN. Exactly. Enum. List Record OrFalse Or Map.)
        ./generation-graph ./recursive-generation ../support/option
        (only-in ../number Integer UInt IntegerRange. Z/.)
        (prefix-in :clan/poo/testing/property testing.)
        (prefix-in :clan/poo/testing/property/replay replay.)
        (prefix-in :clan/poo/testing/property/generator core.)
        (prefix-in (only-in :clan/poo/testing/property/generator make-generator) testing.)
        (only-in :clan/poo/testing/property/generator integer-shrinks)
        (prefix-in :clan/poo/testing/property/model model.)
        (prefix-in (only-in ../fun Observation.) fun.))
;; Recognition-only callable fields deliberately do not wrap shrink callbacks:
;; invalid proposals must reach the existing attempt-budget/domain gate, rather
;; than become premature Function output errors. No arity/termination is inferred.
(define-type Procedure (.cc Type. .element?: procedure?))
;; One existing Record contract owns sampler shape and source-list admission.
(define-type GeneratorRecord
  (Record descriptor: [Type] bound-descriptor: [Type] draw: [Procedure] shrink: [Procedure]
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
  (make-instance GeneratorRecord descriptor: descriptor bound-descriptor: descriptor draw: draw shrink: shrink
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

;; One preparation boundary owns the constructor's declaration binding. Retarget
;; through a fresh constructor, never by inheriting a different Type's parser/tree.
;; Mandatory identities cannot be removed by replacing application dependencies.
(def (generator-sources sampler)
  (def descriptor (.get sampler descriptor))
  (unless (eq? descriptor (.get sampler bound-descriptor))
    (error "sampler descriptor binding changed; construct a new sampler"))
  (cons sampler (cons descriptor (.get sampler sources))))
;; Capture mutable sources once; non-generator observations supply explicit owners.
(def (snapshot sampler dependencies)
  (map (lambda (source) (cons source (object-revision source)))
       (delete-duplicates/hash (append (if sampler (generator-sources sampler) []) dependencies))))
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
  ;; Preparation is one inherited action: custom factories cannot end their
  ;; parent's authority and then let a caller bind the next field.
  (core.with-sources []
    (def sources (snapshot sampler []))
    (def owned (.get sampler generation))
    (core.generator-map (or (and owned (owned sampler))
      (core.make-generator (.@ sampler draw) (cut sampler-children sampler <>))) identity
      current?: (source-guard sources sampler))))
;; Measures are natural numbers; malformed callbacks cannot admit shrink steps.
(def (weight sampler value)
  ;; The shared primitive also protects Map folds and trace command costs. A
  ;; whole-aggregate check alone is too late to suppress later user callbacks.
  (core.with-sources []
    (def n (.call sampler measure value))
    (unless (and (exact-integer? n) (>= n 0)) (error "invalid shrink measure" n))
    n))
;; Replace one coordinate using the product's shared checked action. A revised
;; shrink callback cannot reach packing or a later child's shrink callback.
(def (coordinate-shrinks children values pack call)
  (let loop ((children children) (values values) (before []))
    (if (null? children) []
      (append
        (map-in-order (lambda (smaller) (call pack (append (reverse before) (cons smaller (cdr values)))))
             (call (.@ (car children) shrink) (car values)))
        (loop (cdr children) (cdr values) (cons (car values) before))))))
;; Identity sharing retains first-observation stamps. Product and Map factories
;; use the same standard hash policy; rediscovery never refreshes old authority.
(def (retain-source-stamps! ledger stamps)
  (delete-duplicates/hash stamps table: ledger key: car from-end?: #t))
;; Products share draw/shrink/measure composition for tuples, pairs and call rows.
(def (product-generator descriptor (children :~ list?) (unpack : :procedure) (pack : :procedure))
  (set! children (list-copy children))
  (unless (object? descriptor) (validate Type descriptor))
  (for (child children) (unless (object? child) (validate GeneratorRecord child)))
  ;; Keep the earliest epoch for each identity. Repeated coordinates and shared
  ;; dependencies need one pure revision read, never a refreshed later snapshot.
  ;; Per-coordinate domain/current hooks remain separate and run as before.
  (def owner-ledger (make-hash-table-eq))
  (def owners (retain-source-stamps! owner-ledger (snapshot #f (cons descriptor children))))
  ;; All known participants precede metadata/factory reads, even if a later child
  ;; has not yet supplied its additional dependencies. This checker is transient.
  (def admission (lambda () (current? owners)))
  (def (check!) (unless (admission) (refuse-generation 'stale)))
  (core.with-generation-check check!
    (core.with-sources []
      (validate Type descriptor)
      (def domain (testing.make-product-specification
        (map-in-order (lambda (child) (core.with-sources []
          (def captured (snapshot child []))
          (def added (retain-source-stamps! owner-ledger captured))
          (unless (null? added) (set! owners (append owners added)))
          (property-specification child captured))) children)
        current?: (lambda () (current? owners))))
      ;; The generic product owns all field/owner stamps, including an empty product.
      ;; One boundary also protects representation callbacks and value-only shrinking.
      (def (current) (testing.specification-current? domain))
      ;; Once all domains exist, their captured Type/dependency/hook judgments
      ;; join the SAME checker before any factory runs; no new scope is layered.
      (set! admission current)
      (def (checked action . arguments)
        (core.with-sources []
          (unless (current) (refuse-generation 'stale))
          (begin0 (apply action arguments) (unless (current) (refuse-generation 'stale)))))
      (.cc (from-generator descriptor
        (core.generator-map (core.generator-sequence (map generator-core children)) pack current?: current)
        (lambda (value) (testing.specification-weight domain (checked unpack value)))
        shrink: (lambda (value) (coordinate-shrinks children (checked unpack value) pack checked))
        dependencies: (apply append (map generator-sources children))) .current?: current))))

;; Finite-key Maps reuse their existing validation/wrapping protocol once per
;; materialized node. Key validation must preserve the supplied representation;
;; callers normalize keys explicitly before declaring this finite domain.
(def (map-generator descriptor keys value-sampler domain-limit: (limit 256) dependencies: (dependencies []))
  (unless (object? descriptor) (validate Type descriptor))
  (unless (object? value-sampler) (validate GeneratorRecord value-sampler))
  ;; Freeze request spines before validators/getters can change caller-owned data.
  (unless (list? keys) (error "finite Map keys required"))
  (unless (and (list? dependencies) (every object? dependencies)) (error "Map sources required"))
  (def domain (list-copy keys)) (def declared (list-copy dependencies))
  (def ledger (make-hash-table-eq))
  (def owners (retain-source-stamps! ledger (snapshot #f (append (list descriptor value-sampler) declared))))
  ;; Capture each newly discovered participant immediately, before a later getter.
  (def (capture! stamps)
    (def added (retain-source-stamps! ledger stamps))
    (unless (null? added) (set! owners (append owners added))))
  ;; Keep the transient checker pure: callback observers run only at explicit
  ;; checked actions, never recursively inside their own generation checker.
  (def (check!) (unless (current? owners) (refuse-generation 'stale)))
  (core.with-generation-check check!
    (core.with-sources []
      (validate Type descriptor)
      (unless (memq Map. (compute-precedence-list! descriptor)) (error "Map descriptor required"))
      (set! value-sampler (validate GeneratorRecord value-sampler))
      (capture! (snapshot value-sampler []))
      (def hook (and (.has? value-sampler .current?) (.@ value-sampler .current?)))
      ;; This one retained guard sees the growing ledger during preparation and
      ;; the closed ledger afterwards. No factory callback can mutate it later.
      (def (guard)
        (and (current? owners) (or (not hook) (and (core.live? hook) (current? owners)))))
      ;; Admit each preparation action once; original exceptions bypass normal
      ;; post-return admission, while successful actions must retain authority.
      (def (checked action . arguments)
        (core.with-sources []
          (unless (core.live? guard) (refuse-generation 'stale))
          (begin0 (apply action arguments)
            (unless (core.live? guard) (refuse-generation 'stale)))))
      (def key-type (checked (lambda () (.get descriptor Key))))
      (unless (object? key-type) (validate Type key-type))
      (capture! (snapshot #f (list key-type)))
      (checked validate Type key-type)
      (def value-type (checked (lambda () (.get descriptor Value))))
      (unless (object? value-type) (validate Type value-type))
      (capture! (snapshot #f (list value-type)))
      (checked validate Type value-type)
      (unless (eq? value-type (.get value-sampler descriptor)) (error "Map value sampler descriptor mismatch"))
      (def sources (append (list descriptor key-type value-type) declared))
      ;; Generic finite-domain admission precedes application key validators.
      (def generation (checked (lambda ()
        (core.generator-hash domain (generator-core value-sampler) domain-limit: limit current?: guard))))
      (for (key domain)
        (unless (eq? (checked validate key-type key) key)
          (error "finite Map key validation must preserve representation" key)))
      (checked (lambda ()
        (.cc (from-generator descriptor (core.generator-map generation (cut validate descriptor <>))
          (lambda (table) (+ (hash-length table)
            (hash-fold (lambda (_key value total) (+ total (weight value-sampler value))) 0 table)))
          dependencies: (append sources (generator-sources value-sampler))) .current?: guard))))))
;; Standard data Types reuse the independent algebra, including its lazy shrink tree.
;; Content weight permits same-length coordinate shrinking; required byte lengths
;; remain explicit rather than silently falling back to a different Type.
(def (data-generator descriptor (length #f))
  (def bytes? (or length (eq? descriptor Bytes)))
  ;; One standard representation pair serves every text carrier. Mapping the
  ;; character-list tree once retains provenance without a second wrapper chain.
  (defvalues (pack unpack)
    (cond (bytes? (values list->u8vector u8vector->list))
      ((eq? descriptor Symbol)
       (values (compose string->symbol list->string) (compose string->list symbol->string)))
      ((eq? descriptor Keyword)
       (values (compose string->keyword list->string) (compose string->list keyword->string)))
      (else (values list->string string->list))))
  (def code (if bytes? identity char->integer))
  (def lower (or length 0))
  (def generation (core.generator-map
    (core.generator-list (if bytes? (core.generator-byte) (core.generator-character))
      min-length: lower max-length: (or length 128)) pack))
  (from-generator descriptor generation
    (lambda (value) (foldl (lambda (item total) (+ total 1 (code item))) 0 (unpack value)))
    shrink: (lambda (value) (map pack (core.data-list-shrinks (unpack value)
      (if bytes? integer-shrinks core.character-shrinks) lower)))))

;; Empty finite numeric declarations share the existing uninhabited-leaf policy.
;; Their absence is not a generator exception or a reason to use another Type.
(def (empty-generator descriptor)
  (.cc (make-generator descriptor (lambda (_random _size) (refuse-generation 'empty))
    (lambda (_) []) (lambda (_) 0)) .inhabited?: #f))
;; Capture effective bounds under the enclosing graph's checked source scope.
;; Omitted endpoints are admitted only for IntegerRange; fixed/modular carriers
;; must expose exact finite endpoints. Custom predicates must faithfully admit
;; their declared interval or supply their own .generator override.
(def (integer-range-generator descriptor finite?)
  (def lower (core.with-sources [] (.get descriptor .most-negative)))
  (def upper (core.with-sources [] (.get descriptor .most-positive)))
  (unless (and (or (exact-integer? lower) (and (not finite?) (not lower)))
               (or (exact-integer? upper) (and (not finite?) (not upper))))
    (error "exact integer carrier bounds required"))
  (if (and lower upper (> lower upper)) (empty-generator descriptor)
    (let (anchor (core.integer-range-anchor lower upper))
      (from-generator descriptor (core.generator-integer-range lower upper)
        (lambda (value) (abs (- value anchor)))
        shrink: (cut core.integer-range-shrinks anchor <>)))))

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
    ;; Rational's default drawing profile is exact and bounded. Value-only
    ;; policies also admit finite inexact rationals by their exact numeric value;
    ;; Float/Real representation coverage still requires an explicit sampler.
    ((eq? descriptor Rational)
     (from-generator descriptor (core.generator-rational) core.rational-weight
       shrink: core.rational-shrinks))
    ((or (eq? descriptor String) (eq? descriptor Symbol) (eq? descriptor Keyword) (eq? descriptor Bytes))
     (data-generator descriptor))
    (else
      (def ancestors (compute-precedence-list! descriptor))
      (cond
        ((memq BytesN. ancestors) (data-generator descriptor (.get descriptor n)))
        ((memq Exactly. ancestors)
         (make-generator descriptor (lambda (_random _size) (.get descriptor value)) (lambda (_) []) (lambda (_) 0)))
        ((memq Enum. ancestors)
         (def values (.get descriptor vals))
         ;; Empty Enum is an uninhabited leaf, so a viable Union can bypass it.
         ;; Nonempty domains reuse Enum's first-index metadata for strict descent;
         ;; equal duplicate payloads may be proposed but never falsely decrease.
         (if (null? values)
           (empty-generator descriptor)
           (let ((rank (.@ descriptor .uint<-)) (value (.@ descriptor .<-uint)))
             (from-generator descriptor (core.generator-elements values) rank
               shrink: (lambda (item) (map value (integer-shrinks (rank item))))))))
        ((or (memq IntegerRange. ancestors) (memq Z/. ancestors))
         (integer-range-generator descriptor (and (memq Z/. ancestors) #t)))
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

;; Typed export preserves the existing report and generic source authority.
;; Only completed executions have a portable core witness to admit.
(def (write-counterexample report codec port)
  (unless (.get report replayable?) (error "property report has no replayable generator"))
  (unless (current? (.get report sources) (.get report sampler)) (error "stale property replay"))
  (replay.write-counterexample (.get report execution) codec port))
;; Reuse the sampler's bounded domain without drawing or opening a new runner.
;; Application codecs reconstruct ordinary validated Record/Function carriers.
(def (read-counterexample sampler codec port property policy: (policy (testing.make-policy)))
  (def sources (snapshot sampler []))
  (replay.read-counterexample codec port (property-specification sampler sources) property policy: policy))

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


;; Trace preparation observes each declaration before requesting the next one.
;; The same private scope serves generation, repair and differential execution;
;; a later computed field must never refresh an earlier Type's revision stamp.
(defrule (with-trace-model model contract (sources retain! checked) body ...)
  (let (schema contract)
    (unless (object? model) (validate schema model))
    (def sources (make-parameter (snapshot #f (list model schema))))
    ;; Append stamps without replacing an earlier observation of the same owner.
    (def (retain! owners) (sources (append (sources) (snapshot #f owners))))
    ;; Dynamic admission also reaches nested generator/iterator operations.
    (def (check!) (unless (current? (sources)) (refuse-generation 'stale)))
    ;; One existing action boundary preserves values and exact callback causes.
    (def (checked action . arguments) (core.with-sources [] (apply action arguments)))
    ;; Record validation can force computed metadata, so capture raw fields first,
    ;; then retain any normalized owners returned by the ordinary Record protocol.
    (def (capture! owner)
      (retain! (list owner))
      (for (name '(Command State Result Observation))
        (unless (.slot? owner name) (checked validate schema owner))
        (let (descriptor (checked .ref owner name))
          (unless (object? descriptor) (checked validate Type descriptor))
          (retain! (list descriptor)))))
    (core.with-generation-check check!
      (capture! model)
      (set! model (checked validate schema model))
      (capture! model)
      (checked (lambda () body ...)))))

;; Shared callback lifting keeps validation/transition stages separate under the
;; active declaration scope, including pure admission and dependency repair.
(def (trace-callback action)
  (lambda arguments (core.with-sources [] (apply action arguments))))

;; Type preparation is a domain layer over the ordinary Gerbil model protocol.
;; Capture declarations once. A scoped observation can bracket each callback with
;; the same wrapper; pure generation/repair keep identity and the same evaluator.
(def (prepare-model model (normalize identity) (wrap trace-callback))
  (def state (wrap (cut validate (.get model State) <>)))
  (def result (wrap (cut validate (.get model Result) <>)))
  (def initial (wrap (.@ model initial)))
  (def advance (wrap (.@ model advance)))
  (model.make-model
    (lambda () (state (initial)))
    (wrap (.@ model enabled?))
    (lambda (previous command)
      (defvalues (next reply) (advance previous command))
      (values (state next) (result reply)))
    (wrap (.@ model observe))
    (wrap (cut element? (.get model Command) <>)) (wrap normalize)))
;; Prefix admission and dependency repair share the generic fold; neither owns a
;; second traversal or invokes an actual backend during model validation.
(def (valid-trace? model commands)
  (with-trace-model model TraceModel (sources retain! checked)
    (model.valid-trace? (prepare-model model) commands)))
;; The domain normalizer preserves nested Function wrapping while retiring dependents.
(def (repair-trace model commands)
  (with-trace-model model TraceModel (sources retain! checked)
    (model.repair-trace (prepare-model model (cut validate (.get model Command) <>)) commands)))

;; Build an ordinary List sampler; the existing runner owns random sources,
;; report stamps, proposal budgets and strict decrease/falsity admission.
;; Only the bounded command spine is specialized, not the generation framework.
(def (trace-generator command-type model steps: (steps 64) dependencies: (dependencies []))
  (def source model)
  (with-trace-model model TraceGenerator (sources retain! checked)
    (unless (eq? command-type (.get model Command)) (error "trace command descriptor mismatch"))
    (using (steps :~ (lambda (n) (and (fixnum? n) (<= 0 n 65536))))
      ;; Compile the captured callbacks once. Guarded invocations still acquire
      ;; fresh model state; admission does not revalidate metadata per proposal.
      (def admission (checked prepare-model model))
      (def prepared (checked prepare-model model (cut validate command-type <>)))
      (def result #f)
      ;; The Type's existing .generator extension makes this sampler usable by
      ;; ordinary check-property/property-action without a parallel dispatch path.
      (def descriptor (.cc (List command-type)
        .generator: (lambda () (or result (error "trace generator not initialized")))))
      (def sampler (make-generator descriptor
        (lambda (random size)
          (model.draw-trace prepared
            (lambda (state random size)
              (match (.call model draw state random size)
                (#f (values #f #f)) ((some command) (values #t command))
                (else (error "trace draw requires Option")))) steps random size))
        (lambda (commands)
          (model.shrink-trace prepared
            commands (.@ model shrink)))
        (lambda (commands)
          (+ (length commands) (apply + (map (lambda (command) (weight model command)) commands))))
        dependencies: (append (list source TraceGenerator command-type (.get model State)
          (.get model Result) (.get model Observation)) dependencies)))
      ;; The bounded trace predicate is compiled against this model/declaration.
      ;; Capture now, outside the lazy slot expression, just as Map/products do;
      ;; later model or List metadata cannot silently retarget that predicate.
      (def own (source-guard (snapshot sampler []) sampler))
      (def stamps (sources))
      (def guard (lambda () (and (current? stamps) (own))))
      (set! result (.cc sampler .current?: guard .accept?: (lambda (commands)
        (and (list? commands) (<= (length commands) steps) (model.valid-trace? admission commands)))
        limits: (.o bind-these: #f steps: steps)))
      result)))

;; Validate observed replies and snapshots at ONE comparison boundary. A declared
;; equality relation must return Boolean; an exception is an error, never a pass.
(def (trace-equal? descriptor same? expected actual call)
  (def left (call validate descriptor expected)) (def right (call validate descriptor actual))
  (call same? left right))

;; Preflight the whole normalized command list before opening a fresh scoped
;; fixture. Compare initial state, then each reply/state exactly once; stop on
;; first divergence. Reports contain observations, never actual fixture owners.
(def (check-trace model commands with-system same?: (same? equal?))
  (require-value with-system procedure? (lambda () (error "trace fixture must be a procedure")))
  (require-value same? procedure? (lambda () (error "trace equality must be a procedure")))
  (with-trace-model model TraceModel (sources retain! checked)
    ;; Prepare method wrappers once; the shared scope owns their declarations.
    (def (wrap action) (lambda arguments (apply checked action arguments)))
    (def normalized (checked validate (List (.get model Command)) commands))
    (def reference (checked prepare-model model identity wrap))
    (def execution (model.check-trace reference normalized
      (lambda (use)
        (checked with-system (lambda (system)
          ;; Fixture declarations belong to use, not to teardown. Restore model
          ;; ownership before user cleanup; model edits still refuse factory return.
          (parameterize ((sources (sources)))
            (retain! (list system))
            (def state-type (checked (lambda () (.get system State))))
            (unless (object? state-type) (checked validate Type state-type))
            (retain! (list state-type))
            (def schema (checked TraceSystem state-type))
            (retain! (list schema))
            (set! system (checked validate schema system))
            (retain! (list system))
            (def step (checked (lambda () (.@ system step))))
            (def observe (checked (lambda () (.@ system observe))))
            (use (model.make-system (checked (lambda () (.get system initial)))
              (lambda (state command)
                (let-values (((next result) (checked step state command)))
                  (values (checked validate state-type next) result))) (wrap observe)))))))
      same?: (wrap (lambda (phase left right)
        (trace-equal? (if (eq? phase 'result) (.get model Result) (.get model Observation)) same? left right checked)))))
    (.o bind-these: #f matched?: (model.trace-report-matched? execution) phase: (model.trace-report-phase execution)
      index: (model.trace-report-index execution)
      command: (and (model.trace-report-has-command? execution) (some (model.trace-report-command execution)))
      expected: (model.trace-report-expected execution) actual: (model.trace-report-actual execution))))

;; This is only the Boolean projection expected by check-property. Fresh-fixture
;; lifetime and exact step diagnostics remain in the existing callback/IO layer.
(def (trace-property model with-system same?: (same? equal?))
  (lambda (commands) (.get (check-trace model commands with-system same?: same?) matched?)))
