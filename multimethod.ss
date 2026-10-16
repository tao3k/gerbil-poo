;;; Executable counterpart of Object.Multimethod and its sparse MethodIndex.
(export make standard simple forwarding-standard inner simula multimethod? prototype any register contribute register-when erase
        call reference-call cache-size cache-capacity index-shared? prototype-precedence
        dispatch-error? dispatch-error-kind dispatch-error-expected dispatch-error-actual
        inspect)
(import :std/iter (only-in :std/list/list-builder with-list-builder)
        (only-in ./mop Type validate)
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
(defstruct multimethod (arity inputs output precedence combine method-type index cache) final: #t)
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
  (make-multimethod arity (map identity inputs) output precedence combine method-type empty-index []))
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
      (lambda (old) (if candidate (cons candidate (if replace? [] old)) []))) []))
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
      (unless (boolean? accepted) (error "method predicate must return a Boolean"))
      accepted)))
;; Filter ordered candidates by current guards, preserving their carrier data and order.
(def (select candidates args)
  (with-list-builder (add)
    (for (candidate candidates)
      (when (applies? candidate args) (add (method-candidate-method candidate))))))
;; Retain signature/carrier/index identity while replacing bounded candidate-cache state.
(def (with-cache generic cache)
  (make-multimethod (multimethod-arity generic) (multimethod-inputs generic) (multimethod-output generic)
    (multimethod-precedence generic) (multimethod-combine generic) (multimethod-method-type generic) (multimethod-index generic) cache))
;; Resolve a complete shape with bounded move-to-front caching; return candidates and updated generic.
(def (resolve generic args)
  (def shape (shape! generic ((multimethod-precedence generic) args)))
  (def cache (multimethod-cache generic))
  (def entry (assoc shape cache))
  (cond
   ((and entry (eq? entry (car cache))) (values (cdr entry) generic))
   (else
    (def candidates (if entry (cdr entry) (collect generic shape)))
    (def key (if entry (car entry) (map (lambda (order) (map identity order)) shape)))
    (def recent (cons (cons key candidates) (filter (lambda (pair) (not (equal? (car pair) shape))) cache)))
    (values candidates (with-cache generic (take recent (min cache-capacity (length recent))))))))
;; Validate inputs, select current guards, combine and validate output; return result plus updated generic.
(def (call generic . args)
  (def checked (arguments! generic args))
  (defvalues (candidates next) (resolve generic checked))
  (def result ((multimethod-combine generic) (select candidates checked) checked))
  (values (validate (multimethod-output generic) result) next))
;; Uncached semantic control: validate, collect, select and combine without retaining a cache.
(def (reference-call generic . args)
  (def checked (arguments! generic args))
  (def shape (shape! generic ((multimethod-precedence generic) checked)))
  (validate (multimethod-output generic) ((multimethod-combine generic) (select (collect generic shape) checked) checked)))
;; Report current retained shape count, not hit rate or invocation-result count.
(def (cache-size generic) (length (multimethod-cache generic)))
;; Check persistent index identity across two generics, independent of shape-cache state.
(def (index-shared? first second) (eq? (multimethod-index first) (multimethod-index second)))
;; Inspect current-definition candidates for negative watches; never invoke a body or combiner.
;; Call watches run guards; shape watches conservatively retain every registered guard.
(def (inspect generic kind value)
  ;; Negative checking reads the definition, never cached selections/combine/bodies.
  (def args (if (eq? kind 'call) (arguments! generic value) #f))
  (def shape (shape! generic (if args ((multimethod-precedence generic) args) value)))
  (def candidates (collect generic shape))
  (if args (select candidates args) (map method-candidate-method candidates)))
