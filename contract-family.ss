;;; ContractFamily: closed contract inputs and late-bound invocation wrappers.
(export Source. PreparationCosts. SelectionCache. choose-preparation cached-choice methods.inputs<-cached-selection methods.inputs<-selection methods.inputs<-shared prepare refresh family? family-keys family-ref family-invoker
        family-built family-bound family-reused family-prepared? family-preparation)
(import :std/iter (only-in :std/func compose1) ./object (only-in ./mop define-type .defgeneric)
        (prefix-in ./declarative-metadata metadata.))
;; Private tables/records never escape. Pure immutable source/input premises are
;; the same as GenericFamily; labels and sampled outputs cannot authorize reuse.
;; Closed preparation result: context is the reuse premise; lookup exposes only
;; prepared inputs. prepared? records this revision's real preparation, strategy
;; records independent/shared/direct/retained execution, not an approval decision.
(defstruct input-batch (context lookup prepared? strategy) final: #t)
;; A privately staged family and its actual built/bound/reused key traces.
;; Descriptor and invoker tables use copy-on-write; public accessors expose values,
;; never mutable tables. execute is compared by identity before reusing wrappers.
(defstruct family (source keys batch inputs contracts invokers execute built bound reused) final: #t)
;; Return this revision's selected preparation path; this is a trace label,
;; not proof of lower wall time, fewer collections or valid application metadata.
(def (family-preparation current) (input-batch-strategy (family-batch current)))
;; Return whether this revision actually executed shared preparation.
;; A retained lookup and a direct projection both report false.
(def (family-prepared? current) (input-batch-prepared? (family-batch current)))
;; Find the descriptor for key, or #f when absent. Does not construct, bind
;; or invoke a service; availability is enforced during prepare/refresh.
(def (family-ref current key) (hash-get (family-contracts current) key))
;; Find key's checked wrapper, or #f when absent. The caller must pass the
;; current view on every invocation; a reused wrapper never supplies old state.
(def (family-invoker current key) (hash-get (family-invokers current) key))
;; Stage a complete family from closed per-key inputs. Validate all keys and
;; service availability before preparation; raise on duplicates/missing services
;; or invalid descriptors. Reuse requires the identical source and equal inputs;
;; wrapper reuse also requires identical execute. Failure returns no partial family;
;; callbacks must be pure because arbitrary callback side effects are not rolled back.
(def (materialize source keys prepare-inputs construct previous policy view execute available)
  (unless (and (list? keys) (andmap symbol? keys)) (error "contract keys must be symbols"))
  (def prior (and previous (eq? source (family-source previous)) previous))
  ;; Validate the entire support before any shared preparation or construction.
  (def seen (make-hash-table-eq))
  (for (key keys)
    (when (hash-key? seen key) (error "duplicate contract binding" key))
    (unless (available key) (error "contract without service" key))
    (hash-put! seen key #t))
  (def batch (prepare-inputs (and prior (family-batch prior)) policy view keys))
  (def shared? (and prior (equal? keys (family-keys prior))))
  (def contracts (if shared? (family-contracts prior) (make-hash-table-eq)))
  (def invokers (if shared? (family-invokers prior) (make-hash-table-eq)))
  (def inputs seen)
  (def contracts-copied? (not shared?))
  (def invokers-copied? (not shared?))
  (def built [])
  (def bound [])
  (def reused [])
  (for (key keys)
    (let* ((input ((input-batch-lookup batch) key))
           (retained? (and prior (hash-key? (family-inputs prior) key)
                           (equal? input (hash-ref (family-inputs prior) key))))
           (contract (if retained? (family-ref prior key) (construct key input)))
           (binding-retained? (and retained? (eq? execute (family-execute prior)))))
      (unless (metadata.contract? contract) (error "expected contract descriptor" key))
      (hash-put! inputs key input)
      (if retained? (set! reused (cons key reused)) (set! built (cons key built)))
      (unless binding-retained? (set! bound (cons key bound)))
      (unless (and shared? retained?)
        (unless contracts-copied? (set! contracts (hash-copy contracts)) (set! contracts-copied? #t))
        (hash-put! contracts key contract))
      (unless (and shared? binding-retained?)
        (unless invokers-copied? (set! invokers (hash-copy invokers)) (set! invokers-copied? #t))
        (hash-put! invokers key
          (if binding-retained? (family-invoker prior key)
            (metadata.wrap contract (lambda (args current) (execute key args current))))))))
  (make-family source keys batch inputs contracts invokers execute (reverse built) (reverse bound) (reverse reused)))
;; Derived protocol: expensive preparation can observe ONLY its closed context.
;; The retained lookup captures prepared immutable values, never the old snapshot.
;; Prices are explicit nonnegative operation weights supplied by the model.
;; They are not sampled timings, trust flags, or permissions to skip metadata.
;; Immutable nonnegative operation weights for shared/direct projection.
;; The choose callback takes a support count; direct wins only if its saving
;; strictly pays selection-cost. Ties use shared, which still executes selection.
;; Invalid weights raise when the callback is first forced, not an approval bypass.
(define-type (PreparationCosts. @ [] prepare-cost shared-cost direct-cost)
  selection-cost: 0
  .choose:
  (begin
    (unless (andmap (lambda (cost) (and (exact-integer? cost) (>= cost 0)))
                   (list prepare-cost shared-cost direct-cost selection-cost)) (error "invalid preparation costs"))
    (lambda (count) (if (< (+ selection-cost (* count direct-cost)) (+ prepare-cost (* count shared-cost))) 'direct 'shared))))
;; Run the cost object's ordinary selector for a nonnegative support count.
;; Returns direct/shared; callers remain responsible for coherent projection semantics.
(.defgeneric (choose-preparation costs count) slot: .choose)
;; Cache the choice once for stable support; changed arity falls back to ordinary selection.
;; Lazily compute one choice from immutable prices and the canonical keys.
;; Identity/equal-arity hits reuse that choice; changed arity runs ordinary selection.
;; No graph, descriptor or approval is stored here. New prices require a derived
;; cache; setup, first selection and support checks still have real costs.
(define-type (SelectionCache. @ [] preparation-costs keys)
  .choose:
  (let* ((count (length keys)) (selected (choose-preparation preparation-costs count)))
    (lambda (current)
      (if (eq? current keys) selected
        (let (size (length current))
          (if (= size count) selected (choose-preparation preparation-costs size)))))))
;; Select for current keys through the cache, falling back on arity changes.
;; The result chooses projection work only and cannot authorize metadata reuse.
(.defgeneric (cached-choice cache keys) slot: .choose)
;; Derive closed shared-input preparation for Source. Equal complete contexts
;; retain the old prepared lookup; otherwise prepare once or use direct projection.
;; The retained lookup cannot observe ambient policy or a previous snapshot.
;; Raise for unknown strategies or an unavailable direct implementation.
(define-type (methods.inputs<-shared @ [] shared-input prepare-shared project-shared)
  .select: (lambda (_) 'shared)
  .direct: (lambda (_ __) (error "direct projection unavailable"))
  .inputs: (lambda (previous policy view keys)
    (def context (shared-input policy view))
    (if (and previous (equal? context (input-batch-context previous)))
      (make-input-batch context (input-batch-lookup previous) #f 'retained)
      (case (.select keys)
        ((shared) (let (prepared (prepare-shared context))
                    (make-input-batch context (cut project-shared <> prepared) #t 'shared)))
        ((direct) (make-input-batch context (cut .direct <> context) #f 'direct))
        (else (error "invalid preparation strategy"))))))
;; Compose the immutable cost callback with length using unary compose1.
;; Avoid per-revision generic lookup while retaining ordinary selection on misses
;; of the shared-context cache; project-direct must match shared projection meaning.
(define-type (methods.inputs<-selection @ [methods.inputs<-shared] preparation-costs project-direct)
  .select: (compose1 (.@ preparation-costs .choose) length)
  .direct: project-direct)
;; Install the cached selector as the shared-input strategy callback.
;; This derives the same input protocol and validation path as dynamic selection;
;; only strategy-choice work changes, not contract/approval safety premises.
(define-type (methods.inputs<-cached-selection @ [methods.inputs<-shared] selection-cache project-direct)
  .select: (.@ selection-cache .choose)
  .direct: project-direct)
;; Pure contract source with keys, per-key project and descriptor construct.
;; Default inputs prepare independently; mixins replace only that input protocol.
;; prepare stages cold support; refresh may retain descriptors/wrappers under
;; materialize's identity/equality premises. All preparation errors propagate.
(define-type (Source. @ [] keys project construct)
  .inputs: (lambda (_ policy view __) (make-input-batch #f (cut project <> policy view) #f 'independent))
  .prepare: (lambda (policy view execute available) (materialize @ (keys policy view) .inputs construct #f policy view execute available))
  .refresh: (lambda (previous policy view execute available) (materialize @ (keys policy view) .inputs construct previous policy view execute available)))
;; Construct a cold complete family from policy/view and the current executor.
;; The optional availability predicate defaults true; supply it when services
;; can disappear. Raises on invalid support or failed preparation/construction.
(.defgeneric (prepare source policy view execute (available (lambda (_) #t))) slot: .prepare)
;; Stage a revision using previous only when its source and closed inputs match.
;; Return the complete candidate with exact work traces, or propagate failure.
;; Joint application approval/publication is performed by the existing publisher.
(.defgeneric (refresh source previous policy view execute (available (lambda (_) #t))) slot: .refresh)
