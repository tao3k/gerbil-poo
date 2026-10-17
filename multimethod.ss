;;; Executable counterpart of Object.Multimethod and its sparse MethodIndex.
(export make standard simple forwarding-standard inner simula multimethod? prototype any register contribute register-when erase
        prepared prepared-standard prepared-simple prepared-forwarding-standard prepared-inner prepared-simula nested nested-state
        prepared-context bind-context prepare-shape call reference-call cache-size effective-cache-size cache-capacity index-shared? prototype-precedence
        dispatch-error? dispatch-error-kind dispatch-error-expected dispatch-error-actual
        inspect)
(import (only-in :std/list/alist arem) (only-in ./support/base require-value) :std/iter (only-in :std/list/list-builder with-list-builder)
        (only-in ./mop Type validate define-type) ./object
        (only-in ./object compute-precedence-list!) (only-in ./type Unit)
        (prefix-in ./method-combination combination.))

;; All index/cache records and their mutators remain private. Names are symbols,
;; so lazy POO object caches never enter structural hash/equality keys.
(defstruct specializer (name) final: #t)
;; Universal axis specializer; distinct from every named prototype.
(def any (make-specializer #f))
;; Validate a symbol name and construct a named axis specializer.
(def (prototype name)
  (unless (symbol? name) (error "prototype name must be a symbol" name))
  (make-specializer name))
;; Immutable method payload and optional per-call Boolean applicability guard.
(defstruct method-candidate (predicate method) final: #t)
;; Persistent sparse tuple tree; children preserve lexicographic C4 traversal.
(defstruct method-index (values children) final: #t)
;; Maximum retained shape entries; caching retains candidates, never invocation results.
(def cache-capacity 8)
;; Shared empty persistent method tree for fresh generics.
(def empty-index (make-method-index [] []))
;; Private generic signature, carrier validator, persistent index and bounded candidate cache.
(defstruct multimethod (arity inputs output precedence combine method-type index cache invocation) final: #t)
;; Typed dispatch refusal with its expected/actual diagnostic values.
(defstruct dispatch-error (kind expected actual) final: #t)
;; Raise dispatch refusal; callers retain the unpublished generic on failure.
(def (fail kind expected actual) (raise (make-dispatch-error kind expected actual)))
;; Default combiner invokes the first applicable procedure with all original arguments.
(def (first-method methods args)
  (if (null? methods) (fail 'no-applicable-method #f #f) (apply (car methods) args)))
;; Build a typed generic with an optional combiner, dispatch arity and strict carrier validator.
;; Arity may differ from the typed argument row; malformed signatures raise at construction.
(def (make inputs output precedence (combine first-method) (arity (length inputs)) (method-type procedure?))
  (unless (and (list? inputs) (exact-integer? arity) (<= 0 arity) (procedure? precedence) (procedure? combine) (procedure? method-type))
    (error "invalid multimethod signature"))
  (for-each (cut validate Type <>) (cons output inputs))
  (make-multimethod arity (map identity inputs) output precedence combine method-type empty-index [] #f))
;; Construct Appendix B standard qualified dispatch over the EXISTING sparse
;; index/cache/type/guard machinery. Contributions retain C4 order; missing primary
;; invokes on-missing with the original argument row. No parallel dispatcher exists.
(def (standard inputs output precedence
               (on-missing (lambda (_) (fail 'no-applicable-method #f #f))) (arity (length inputs)))
  (make inputs output precedence
    (lambda (methods args) (combination.effective methods args on-missing))
    arity combination.standard-contribution?))
;; Construct nonstandard simple combination with items and around qualifiers.
;; The policy controls short-circuiting/empty/finalization; output still passes
;; the generic's native Type validator. Invalid qualifier bodies fail registration.
(def (simple inputs output precedence policy (arity (length inputs)))
  (make inputs output precedence
    (lambda (methods args) (combination.simple-effective policy methods args))
    arity combination.simple-contribution?))
;; Forward one typed dispatch value and one typed payload through existing C4
;; selection. Only the initial dispatch determines candidates; replacements pass
;; payload Type validation and cannot replace dispatch or bypass output validation.
;; Guards run against the initial typed pair, before around/primary enrichment.
(def (forwarding-standard dispatch-type payload-type output precedence
                         (on-missing (lambda (_) (fail 'no-applicable-method #f #f))) (arity 1))
  (make (list dispatch-type payload-type) output (lambda (args) (precedence (car args)))
    (lambda (methods args) (combination.forward-effective methods args on-missing (cut validate payload-type <>)))
    arity combination.forward-contribution?))
;; General-first superclass-controlled inner over the same sparse index and guards.
;; Methods use (inner . original-args); inner is a zero-argument continuation.
(def (inner inputs output precedence terminal (arity (length inputs)))
  (make inputs output precedence
    (lambda (methods args) (combination.inner-chain methods args terminal)) arity))
;; Simula automatic-inner combination returns the native Unit value. Prefix/suffix
;; parts share typed arguments; cache and negative watches retain body data only.
(def (simula inputs precedence (arity (length inputs)))
  (make inputs Unit precedence combination.simula-effective arity combination.simula-body?))
;; Compute existing object C4 order and map identities to stable symbolic dispatch names.
(def (prototype-precedence object name)
  ;; name must be a stable, injective map from this C4 graph to symbols.
  (map name (compute-precedence-list! object)))
;; Validate dispatch axis count and symbol-only precedence rows; reject malformed shapes.
(def (shape! generic shape)
  (unless (and (list? shape) (= (length shape) (multimethod-arity generic)))
    (fail 'arity (multimethod-arity generic) (if (list? shape) (length shape) shape)))
  (for (order shape)
    (unless (and (list? order) (andmap symbol? order)) (error "invalid dispatch precedence" order)))
  shape)
;; Validate fixed input row length and each native Type before any candidate/body runs.
(def (arguments! generic args)
  (unless (= (length args) (length (multimethod-inputs generic)))
    (fail 'arity (length (multimethod-inputs generic)) (length args)))
  (map validate (multimethod-inputs generic) args))
;; Path-copy sparse index branches, sharing unaffected subtrees; apply change at exact path.
(def (alter index path change)
  (if (null? path)
    (make-method-index (change (method-index-values index)) (method-index-children index))
    (let* ((key (car path)) (children (method-index-children index)) (entry (assq key children))
           (child (alter (if entry (cdr entry) empty-index) (cdr path) change)))
      (make-method-index (method-index-values index)
        (if entry (map (lambda (pair) (if (eq? (car pair) key) (cons key child) pair)) children)
            (cons (cons key child) children))))))
;; Build a fresh generic after a validated edit; invalidate all shape-cache entries.
(def (edit generic path predicate method replace?)
  (unless (and (list? path) (andmap specializer? path)) (error "invalid specializer tuple" path))
  (unless (= (length path) (multimethod-arity generic))
    (fail 'arity (multimethod-arity generic) (length path)))
  (when predicate (unless (procedure? predicate) (error "predicate must be a procedure")))
  (def candidate (and method (make-method-candidate predicate method)))
  (make-multimethod (multimethod-arity generic) (multimethod-inputs generic) (multimethod-output generic)
    (multimethod-precedence generic) (multimethod-combine generic) (multimethod-method-type generic)
    (alter (multimethod-index generic) (map specializer-name path)
      (lambda (old) (if candidate (cons candidate (if replace? [] old)) []))) [] (multimethod-invocation generic)))
;; Validate the generic's actual method carrier before registration. Ordinary
;; generics require procedures; qualified constructors admit native contributions.
;; The predicate validates data only and must return Boolean, never execute a body.
(def (method! generic method)
  (def accepted ((multimethod-method-type generic) method))
  (unless (and (boolean? accepted) accepted) (error "invalid generic method" method)) method)
;; Replace exact-path contributions after validating the method carrier.
(def (register generic path method) (edit generic path #f (method! generic method) #t))
;; Prepend a validated method at one exact path without replacing earlier contributions.
(def (contribute generic path method) (edit generic path #f (method! generic method) #f))
;; Prepend a guarded contribution; guard decisions are Boolean and rerun on every call.
(def (register-when generic path predicate method)
  (unless (procedure? predicate) (error "predicate must be a procedure"))
  (edit generic path predicate (method! generic method) #f))
;; Remove contributions at one exact path and invalidate candidate caches.
(def (erase generic path) (edit generic path #f #f #t))
;; Traverse only existing sparse C4 branches in order; never run guards or method bodies.
(def (collect generic shape)
  ;; Only descend through existing sparse branches. No Cartesian tuple list.
  (def orders (map (lambda (order) (append order '(#f))) shape))
  (with-list-builder (add)
    (let visit ((index (multimethod-index generic)) (orders orders))
      (if (null? orders)
        (for-each add (method-index-values index))
        (for (name (car orders))
          (def child (assq name (method-index-children index)))
          (when child (visit (cdr child) (cdr orders))))))))
;; Run a candidate guard with original arguments; non-Boolean decisions raise.
(def (applies? candidate args)
  (def predicate (method-candidate-predicate candidate))
  (if (not predicate) #t
    (let (accepted (apply predicate args))
      (require-value accepted boolean? (lambda () (error "method predicate must return a Boolean")))
      accepted)))
;; Filter ordered candidates by current guards, preserving their carrier data and order.
(def (select candidates args)
  (with-list-builder (add)
    (for (candidate candidates)
      (when (applies? candidate args) (add (method-candidate-method candidate))))))
;; Retain signature/carrier/index identity while replacing bounded candidate-cache state.
(def (with-cache generic cache)
  (make-multimethod (multimethod-arity generic) (multimethod-inputs generic) (multimethod-output generic)
    (multimethod-precedence generic) (multimethod-combine generic) (multimethod-method-type generic) (multimethod-index generic) cache (multimethod-invocation generic)))
;; A cached resolution retains candidate data and, only for unconditional
;; shapes, a compiled effective method. Both share one bounded LRU entry/key.
(defstruct resolution (candidates effective) final: #t)
;; Compact private execution state. Published definitions retain immutable callback
;; identities; cache transport allocates this record rather than a new POO descriptor.
(defstruct invocation (prepare invoke state) final: #t)
;; Private typed, immutable invocation context; callers cannot fabricate its tag.
;; Unlike a nested child it contains no evolving cache, method index or certificate.
(defstruct context-state (type value) final: #t)
;; Open native invoker descriptor, specialized at construction like FUN/IO wrapper
;; methods. The two shared descriptors below own calling conventions; runtime
;; successors carry only compiled callbacks and explicit state, not lazy slot maps.
(define-type (Invocation. @ [] invoke)
  .specialize: (lambda (prepare state) (make-invocation prepare invoke state)))
;; Stateless effective-method invoker; shared by every prepared constructor.
(def prepared-invocation (.cc Invocation.
  invoke: (lambda (effective args state) (values (effective args) state))))
;; Select the ordinary most-specific nested body, retaining missing-method refusal.
(def (prepare-nested methods)
  (if (null? methods) (lambda _ (fail 'no-applicable-method #f #f)) (car methods)))
;; Child-cache transport accepts only the same definition and invoker callbacks.
;; A child edit must pass ordinary negative-watch publication instead.
(def (invoke-nested method args current)
  (defvalues (result next) (apply method current args))
  (unless (and (multimethod? next) (index-shared? current next))
    (error "nested invocation changed method definitions"))
  ;; Bound context changes belong to reconstruction/publication, not cache-only
  ;; child transport. Keep its exact private context owner during a warm call.
  (def invocation (multimethod-invocation current))
  (when (and invocation (context-state? (invocation-state invocation)))
    (unless (eq? (invocation-state invocation) (invocation-state (multimethod-invocation next)))
      (error "nested invocation changed bound context")))
  (values result next))
;; Reusable stateful invoker descriptor; specialization binds only the child owner.
(def nested-invocation (.cc Invocation. invoke: invoke-nested))
;; Reuse Invocation.'s ordinary state-specialization protocol. The effective method
;; receives current validated args and this owner's bound data, never an old result.
(def context-invocation (.cc Invocation.
  invoke: (lambda (effective args state)
    (values (effective (context-state-value state) args) state))))
;; Replace invocation state without changing definition/index identity. A hot
;; nested hit returns the exact owner; no global or hidden mutable cache exists.
(def (with-invocation generic invocation)
  (make-multimethod (multimethod-arity generic) (multimethod-inputs generic) (multimethod-output generic)
    (multimethod-precedence generic) (multimethod-combine generic) (multimethod-method-type generic)
    (multimethod-index generic) (multimethod-cache generic) invocation))
;; Opt into precompiled effective methods over the existing typed sparse generic.
;; prepare must be pure and agree with its combiner. Edits invalidate the shared
;; resolution cache; guarded shapes reselect AND prepare for every invocation.
(def (prepared generic prepare)
  (unless (procedure? prepare) (error "effective preparation must be a procedure"))
  (with-invocation (with-cache generic [])
    (.call prepared-invocation .specialize prepare #f)))
;; Construct explicit-context prepared dispatch. Preparation sees only method
;; definitions; applicability/precedence still see typed Args, not context state.
;; The immutable context Type is checked here and every time bind-context runs.
;; Effective code and its negative applicability can therefore survive rebinding.
;; Context-sensitive dispatch must stay in Args; state is an invocation parameter.
(def (prepared-context generic prepare context-type context)
  (unless (procedure? prepare) (error "effective preparation must be a procedure"))
  (validate Type context-type)
  (def state (make-context-state context-type (validate context-type context)))
  (with-invocation (with-cache generic []) (.call context-invocation .specialize prepare state)))
;; Rebind only typed context DATA, retaining the exact index, candidate/effective
;; cache, signature, precedence and invoker callbacks. Guards still run per call
;; against Args. Definitions cannot use this operation as a registration shortcut.
;; It accepts only the private context invoker; nested/stateless owners are refused.
(def (bind-context generic context)
  (def invocation (multimethod-invocation generic))
  (unless (and invocation (context-state? (invocation-state invocation)))
    (error "expected prepared context generic"))
  (def previous (invocation-state invocation))
  (def current (validate (context-state-type previous) context))
  (if (eq? current (context-state-value previous)) generic
    (with-invocation generic (make-invocation (invocation-prepare invocation) (invocation-invoke invocation)
      (make-context-state (context-state-type previous) current)))))
;; Standard qualified prepared constructor, corresponding to preparedStandard.
(def (prepared-standard inputs output precedence
                        (on-missing (lambda (_) (fail 'no-applicable-method #f #f))) (arity (length inputs)))
  (prepared (standard inputs output precedence on-missing arity) (cut combination.prepare-standard <> on-missing)))
;; Specialize the native simple policy once per unconditional shape.
(def (prepared-simple inputs output precedence policy (arity (length inputs)))
  (prepared (simple inputs output precedence policy arity) (cut combination.prepare-simple policy <>)))
;; Forwarding preparation retains initial dispatch and validates every replacement.
(def (prepared-forwarding-standard dispatch-type payload-type output precedence
                                   (on-missing (lambda (_) (fail 'no-applicable-method #f #f))) (arity 1))
  (prepared (forwarding-standard dispatch-type payload-type output precedence on-missing arity)
    (cut combination.prepare-forwarding <> on-missing (cut validate payload-type <>))))
;; Compile the reversed superclass-controlled continuation skeleton once.
(def (prepared-inner inputs output precedence terminal (arity (length inputs)))
  (prepared (inner inputs output precedence terminal arity) (cut combination.prepare-inner <> terminal)))
;; Compile Simula prefix/suffix callbacks once per unconditional shape.
(def (prepared-simula inputs precedence (arity (length inputs)))
  (prepared (simula inputs precedence arity) combination.prepare-simula))
;; A nested generic owns ONE child generic, which can itself own a child. Methods
;; receive (child . current-args), return result/child-successor, and may compose
;; arbitrary native calls with let-values. Only cache transport is accepted: a
;; method edit to the child must instead pass the ordinary checked publication.
;; This is an explicit stateful invoker, not a standard side-method combiner.
(def (nested inputs output precedence child (arity (length inputs)))
  (unless (multimethod? child) (error "nested state must be a generic"))
  (with-invocation (make inputs output precedence first-method arity)
    (.call nested-invocation .specialize prepare-nested child)))
;; Read the immutable child snapshot for diagnostics/tests; ordinary generics have
;; no child. Updating this value requires a successful call and owner successor.
(def (nested-state generic)
  (def invocation (multimethod-invocation generic))
  (and invocation (invocation-state invocation)))
;; Resolve an already validated shape. Explicit preparation refuses guarded or
;; ordinary nonprepared shapes without evaluating a guard/body or changing state.
;; Ordinary calls still retain guarded candidates and select with current args.
;; Private cache construction keeps shape keys unique. Standard arem removes the
;; sole old entry on promotion; the retained key and untouched payloads are shared.
(def (resolve-shape generic shape (prepare-only? #f))
  (def cache (multimethod-cache generic))
  (def entry (assoc shape cache))
  (cond
   ((and entry (or (eq? entry (car cache)) (and prepare-only? (not (resolution-effective (cdr entry))))))
    (values (cdr entry) generic))
   (else
    (def resolved (if entry (cdr entry)
      (let* ((candidates (collect generic shape)) (invocation (multimethod-invocation generic))
             (unconditional? (and invocation (andmap (lambda (candidate) (not (method-candidate-predicate candidate))) candidates))))
        (and (or (not prepare-only?) unconditional?)
          (make-resolution candidates
            (and unconditional? ((invocation-prepare invocation) (map method-candidate-method candidates))))))))
    (def key (if entry (car entry) (map (lambda (order) (map identity order)) shape)))
    (def recent (cons (cons key resolved) (arem shape cache)))
    (values resolved (if resolved (with-cache generic (take recent (min cache-capacity (length recent)))) generic)))))
;; Ordinary resolution derives/validates C4 from current typed arguments before
;; reusing the shared shape resolver. No declared shape substitutes for this step.
(def (resolve generic args)
  (resolve-shape generic (shape! generic ((multimethod-precedence generic) args))))
;; Precompile a declared unconditional effective method before admission probes.
;; This does NOT invoke methods, guards, precedence or Type validators on invented
;; arguments. Real calls still validate actual arguments and derive their own C4.
;; Guards/nonprepared generics remain exact unchanged owners; edits invalidate as
;; usual. Allocated entries are visible to the existing publication cache budget.
(def (prepare-shape generic shape)
  (defvalues (_ next) (resolve-shape generic (shape! generic shape) #t))
  next)
;; Invoke one resolved computation with current typed arguments. Child successors
;; are installed only after successful output validation; failure leaves the old
;; owner accessible, without promising rollback of external body effects.
(def (invoke-resolved generic resolved checked)
  (def invocation (multimethod-invocation generic))
  (if invocation
    (let* ((effective (or (resolution-effective resolved)
             ((invocation-prepare invocation) (select (resolution-candidates resolved) checked))))
           (state (invocation-state invocation)))
      (defvalues (result next-state) ((invocation-invoke invocation) effective checked state))
      (def valid (validate (multimethod-output generic) result))
      (values valid (if (eq? state next-state) generic
        (with-invocation generic (make-invocation (invocation-prepare invocation) (invocation-invoke invocation) next-state)))))
    (values (validate (multimethod-output generic)
      ((multimethod-combine generic) (select (resolution-candidates resolved) checked) checked)) generic)))
;; Validate inputs before resolution or effective-cache hits, then return result
;; and the complete immutable successor (outer resolution plus nested caches).
(def (call generic . args)
  (def checked (arguments! generic args))
  (defvalues (resolved next) (resolve generic checked))
  (invoke-resolved next resolved checked))
;; Uncached semantic control: reselect/prepare with current args and retain no
;; successor. For prepared generics this still compiles anew on each reference call.
(def (reference-call generic . args)
  (def checked (arguments! generic args))
  (def shape (shape! generic ((multimethod-precedence generic) checked)))
  (let-values (((result _) (invoke-resolved generic (make-resolution (collect generic shape) #f) checked))) result))
;; Report current retained shape count, not hit rate or invocation-result count.
(def (cache-size generic) (length (multimethod-cache generic)))
;; Count compiled shapes, independently of guarded candidate-only entries.
(def (effective-cache-size generic)
  (length (filter (lambda (entry) (resolution-effective (cdr entry))) (multimethod-cache generic))))
;; Check definition AND invoker callback identity, independent of cache/child state.
;; An arbitrary new preparer cannot borrow a prior negative-watch certificate.
(def (index-shared? first second)
  (def left (multimethod-invocation first))
  (def right (multimethod-invocation second))
  (and (eq? (multimethod-index first) (multimethod-index second))
    (or (eq? left right)
      (and left right (eq? (invocation-prepare left) (invocation-prepare right)) (eq? (invocation-invoke left) (invocation-invoke right))))))
;; Inspect current-definition candidates for negative watches; never invoke a body or combiner.
;; Call watches run guards; shape watches conservatively retain every registered guard.
(def (inspect generic kind value)
  ;; Negative checking reads the definition, never cached selections/combine/bodies.
  (def args (if (eq? kind 'call) (arguments! generic value) #f))
  (def shape (shape! generic (if args ((multimethod-precedence generic) args) value)))
  (def candidates (collect generic shape))
  (if args (select candidates args) (map method-candidate-method candidates)))
