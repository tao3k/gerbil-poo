;;; Interface-passing and receiver-bound collection styles share one backend.

;; A fresh immutable head identifies a generation even when the value returns to
;; an equal snapshot. False denotes consumed ownership, never a stored table value.
(defstruct %table-head (value) final: #t)
;; Constructors and mutable fields remain private to the existing table module.
(defstruct %table-reference (owner style head lock) final: #t)

;; The official Gerbil receiver carries its originating FUN protocol and private
;; state. Neither the constructor nor the state accessors leave this module.
(defstruct %table-object (protocol state) final: #t)

;; Codec receivers are ordinary nonconsuming reads through their FUN protocol.
(defmethod (@@method json<- %table-object)
  (lambda (self) (.call (%table-object-protocol self) .json<- self)))
;; Byte encoding retains the standard complete-consumption wire format.
(defmethod (@@method bytes<- %table-object)
  (lambda (self) (.call (%table-object-protocol self) .bytes<- self)))
;; Port writes retain their original effects if a child codec later refuses.
(defmethod (@@method marshal %table-object)
  (lambda (self port) (.call (%table-object-protocol self) .marshal self port)))

;; Observe through the originating protocol, including metadata and ownership checks.
(defmethod (@@method snapshot %table-object)
  (lambda (self) (.call (%table-object-protocol self) .unap self)))
;; Table receivers accept a value comparator; Set receivers compare membership.
(defmethod (@@method compare %table-object)
  (case-lambda
    ((self other) (.call (%table-object-protocol self) .compare self other))
    ((self compare other) (.call (%table-object-protocol self) .compare compare self other))))
;; Stream updates reuse the receiver's captured-generation installer exactly once.
(defmethod (@@method <-iter %table-object)
  (lambda (self sequence) (.call (%table-object-protocol self) .<-iter sequence self)))
;; Return the first admitted binding as an Option, without consuming the owner.
(defmethod (@@method min-binding/opt %table-object)
  (lambda (self) (.call (%table-object-protocol self) .min-binding/opt self)))

;; Require the first admitted binding through the same nonconsuming protocol.
(defmethod (@@method min-binding %table-object)
  (lambda (self) (.call (%table-object-protocol self) .min-binding self)))

;; Return the last binding in the declared traversal, retaining an Option shell.
(defmethod (@@method max-binding/opt %table-object)
  (lambda (self) (.call (%table-object-protocol self) .max-binding/opt self)))

;; Require the last admitted binding; absence keeps the ordinary failure.
(defmethod (@@method max-binding %table-object)
  (lambda (self) (.call (%table-object-protocol self) .max-binding self)))

;; Choose through the originating Table or Set protocol without installing state.
(defmethod (@@method choose/opt %table-object)
  (lambda (self) (.call (%table-object-protocol self) .choose/opt self)))

;; Required choice preserves the backend observation and its absence failure.
(defmethod (@@method choose %table-object)
  (lambda (self) (.call (%table-object-protocol self) .choose self)))

;; Project the first Set element while preserving a selected false value.
(defmethod (@@method min-elt/opt %table-object)
  (lambda (self) (.call (%table-object-protocol self) .min-elt/opt self)))

;; Require the first Set element with the existing Set refinement.
(defmethod (@@method min-elt %table-object)
  (lambda (self) (.call (%table-object-protocol self) .min-elt self)))

;; Project the last Set element through the same snapshot read.
(defmethod (@@method max-elt/opt %table-object)
  (lambda (self) (.call (%table-object-protocol self) .max-elt/opt self)))

;; Require the last Set element without retiring the receiver.
(defmethod (@@method max-elt %table-object)
  (lambda (self) (.call (%table-object-protocol self) .max-elt self)))

;; Logical emptiness is a nonconsuming observation of the originating protocol.
(defmethod (@@method empty? %table-object)
  (lambda (self) (.call (%table-object-protocol self) .empty? self)))

;; Predicate receivers retain the originating protocol and observe one snapshot.
(defmethod (@@method find-first/opt %table-object)
  (lambda (self predicate) (.call (%table-object-protocol self) .find-first/opt predicate self)))
;; Required forward search keeps the existing Option absence failure.
(defmethod (@@method find-first %table-object)
  (lambda (self predicate) (.call (%table-object-protocol self) .find-first predicate self)))
;; Reverse search follows the backend's declared reverse visitation.
(defmethod (@@method find-last/opt %table-object)
  (lambda (self predicate) (.call (%table-object-protocol self) .find-last/opt predicate self)))
;; Required reverse search does not consume the receiver's ownership.
(defmethod (@@method find-last %table-object)
  (lambda (self predicate) (.call (%table-object-protocol self) .find-last predicate self)))
;; Universal queries stop at the first false decision on the retained snapshot.
(defmethod (@@method every %table-object)
  (lambda (self predicate) (.call (%table-object-protocol self) .every predicate self)))
;; Existential queries stop at the first true decision, without publishing a root.
(defmethod (@@method any %table-object)
  (lambda (self predicate) (.call (%table-object-protocol self) .any predicate self)))
;; Retain FUN observation without making the private update capability public.
(defmethod (@@method bind %table-object)
  (lambda (self consumer) (.call (%table-object-protocol self) .bind self consumer)))
;; Pure receivers return successors; mutable receivers retain their own identity.
(defmethod (@@method step %table-object)
  (lambda (self transform) (.call (%table-object-protocol self) .step self transform)))
;; Delegate ordered changes to the existing atomic table installer.
(defmethod (@@method apply-delta %table-object)
  (lambda (self delta) (.call (%table-object-protocol self) .apply-delta self delta)))
;; Split returns two owners and a non-owning Option value (Bool for sets).
(defmethod (@@method split %table-object)
  (lambda (self key) (.call (%table-object-protocol self) .split key self)))
;; Return the selected binding/element only after the original owner's commit.
(defmethod (@@method decons/opt %table-object)
  (lambda (self) (.call (%table-object-protocol self) .decons/opt self)))
;; Required extraction shares the same single-generation boundary and empty refusal.
(defmethod (@@method decons %table-object)
  (lambda (self) (.call (%table-object-protocol self) .decons self)))
;; A whole batch stages before the shared ownership commit.
(defmethod (@@method apply-batch %table-object)
  (lambda (self batch) (.call (%table-object-protocol self) .apply-batch self batch)))
;; Conversion prepares the complete target representation before retiring aliases.
(defmethod (@@method convert %table-object)
  (lambda (self target) (.call (%table-object-protocol self) .convert self target)))

;; Lookup preserves the backend's missing-key/default convention.
(defmethod (@@method ref %table-object)
  (lambda (self key . default)
    (apply (.@ (%table-object-protocol self) .ref) self key default)))
;; Optional lookup preserves absence versus a stored false through the same guard.
(defmethod (@@method ref/opt %table-object)
  (lambda (self key) (.call (%table-object-protocol self) .ref/opt self key)))
;; Optional modification stages exactly one callback before the ownership commit.
(defmethod (@@method update/opt %table-object)
  (lambda (self key transform) (.call (%table-object-protocol self) .update/opt key transform self)))
;; Optional association retains the same captured-generation update as modifiers.
(defmethod (@@method acons/opt %table-object)
  (lambda (self key response) (.call (%table-object-protocol self) .acons/opt key response self)))
;; Required modification retains the existing missing/default thunk convention.
(defmethod (@@method update %table-object)
  (lambda (self key transform . default)
    (apply (.@ (%table-object-protocol self) .update) key transform self default)))
;; Delta discovery captures a snapshot but does not install or consume its owner.
(defmethod (@@method delta/opt %table-object)
  (lambda (self key transform) (.call (%table-object-protocol self) .delta/opt key transform self)))
;; Required key focuses compose with the existing Lens protocol over receivers.
(defmethod (@@method lens %table-object)
  (lambda (self key) (.call (%table-object-protocol self) .lens key)))
;; Optional receiver focuses support insertion and deletion without changing arity.
(defmethod (@@method lens/opt %table-object)
  (lambda (self key) (.call (%table-object-protocol self) .lens/opt key)))
;; Count observes the current generation, never a cached receiver field.
(defmethod (@@method count %table-object)
  (lambda (self) (.call (%table-object-protocol self) .count self)))
;; Materialize the backend's own iteration order without sorting again.
(defmethod (@@method list<- %table-object)
  (lambda (self) (.call (%table-object-protocol self) .list<- self)))
;; Point insertion shares the same validation and commit path as whole batches.
(defmethod (@@method acons %table-object)
  (lambda (self key value) (.call (%table-object-protocol self) .acons key value self)))
;; Point deletion retains the backend's absent-key semantics.
(defmethod (@@method remove %table-object)
  (lambda (self key) (.call (%table-object-protocol self) .remove self key)))

;; Required bulk mapping retains keys and validates the complete staged root.
(defmethod (@@method map/2 %table-object)
  (lambda (self transform) (.call (%table-object-protocol self) .map/2 transform self)))
;; Optional bulk mapping can remove keys; one shared owner installation commits it.
(defmethod (@@method filter-map/2 %table-object)
  (lambda (self transform) (.call (%table-object-protocol self) .filter-map/2 transform self)))
;; Heterogeneous projection observes this receiver and returns a raw target root.
(defmethod (@@method map/into %table-object)
  (lambda (self target transform) (.call (%table-object-protocol self) .map/into target transform self)))
;; Optional projection shares that nonconsuming source observation protocol.
(defmethod (@@method filter-map/into %table-object)
  (lambda (self target transform) (.call (%table-object-protocol self) .filter-map/into target transform self)))
;; Filtering keeps the receiver's style and original predicate arity.
(defmethod (@@method filter %table-object)
  (lambda (self predicate) (.call (%table-object-protocol self) .filter predicate self)))
;; Prefix methods reuse the source algorithm and the existing one-owner commit.
(defmethod (@@method take %table-object)
  (lambda (self count) (.call (%table-object-protocol self) .take count self)))
;; Dropping follows the same backend order as take, without repeated extraction.
(defmethod (@@method drop %table-object)
  (lambda (self count) (.call (%table-object-protocol self) .drop count self)))
;; Division exposes only complete optional parts after one ownership installation.
(defmethod (@@method divide %table-object)
  (lambda (self) (.call (%table-object-protocol self) .divide self)))
;; List division can expose zero, one or two fully prepared receiver capabilities.
(defmethod (@@method divide/list %table-object)
  (lambda (self) (.call (%table-object-protocol self) .divide/list self)))
;; Predicate partition remains a fixed two-result specialization.
(defmethod (@@method partition %table-object)
  (lambda (self predicate) (.call (%table-object-protocol self) .partition predicate self)))

;; Register the receiver directly with Gerbil's Iterable protocol. Standard for
;; and iter use the same snapshot-bound cursor as explicit FUN observation.
(implement Iterable %table-object
  (iter (lambda (self) (iter (.call (%table-object-protocol self) .iter<- self)))))

;; Explicit cursor construction shares the standard Iterable implementation.
(defmethod (@@method iter<- %table-object)
  (lambda (self) (.call (%table-object-protocol self) .iter<- self)))
;; Left folds delegate backend traversal and keep its callback/result convention.
(defmethod (@@method foldl %table-object)
  (lambda (self f seed) (.call (%table-object-protocol self) .foldl f seed self)))
;; Visits use the same receiver provenance and snapshot boundary as folds.
(defmethod (@@method for-each %table-object)
  (lambda (self f) (.call (%table-object-protocol self) .for-each f self)))
;; Reverse visits retain backend direction and the original callback failure.
(defmethod (@@method for-each/reverse %table-object)
  (lambda (self f) (.call (%table-object-protocol self) .for-each/reverse f self)))
;; Right folds retain backend order rather than reversing a materialized list.
(defmethod (@@method foldr %table-object)
  (lambda (self f seed) (.call (%table-object-protocol self) .foldr f seed self)))
;; Ordered positioning is an explicit backend capability, never inferred by style.
(defmethod (@@method seek<- %table-object)
  (lambda (self lower (inclusive? #t))
    (.call (%table-object-protocol self) .seek<- self lower inclusive?)))
;; Single binding lookup retains the backend's Option and bound semantics.
(defmethod (@@method seek %table-object)
  (lambda (self lower (inclusive? #t))
    (.call (%table-object-protocol self) .seek self lower inclusive?)))
;; Range observation forwards inclusive/exclusive bounds without another sort.
(defmethod (@@method range<- %table-object)
  (lambda (self lower upper (lower-inclusive? #t) (upper-inclusive? #t))
    (.call (%table-object-protocol self) .range<- self lower upper lower-inclusive? upper-inclusive?)))
;; Materialized range observation retains the same bounds as deferred traversal.
(defmethod (@@method range %table-object)
  (lambda (self lower upper (lower-inclusive? #t) (upper-inclusive? #t))
    (.call (%table-object-protocol self) .range self lower upper lower-inclusive? upper-inclusive?)))
;; Correlated lookups observe the same captured primary/index snapshot.
(defmethod (@@method index-ref/opt %table-object)
  (lambda (self name key) (.call (%table-object-protocol self) .index-ref/opt self name key)))
;; Index comparators and failure classifications remain owned by the backend.
(defmethod (@@method index-fold %table-object)
  (lambda (self name f seed) (.call (%table-object-protocol self) .index-fold self name f seed)))
;; Ordinary named index traversal returns its backend's admitted bindings.
(defmethod (@@method index-iter<- %table-object)
  (lambda (self name) (.call (%table-object-protocol self) .index-iter<- self name)))
;; Named positioning retains the selected index's declared comparator.
(defmethod (@@method index-seek<- %table-object)
  (lambda (self name lower (inclusive? #t))
    (.call (%table-object-protocol self) .index-seek<- self name lower inclusive?)))
;; Named bounded streaming shares ordinary deferred style observation.
(defmethod (@@method index-range<- %table-object)
  (lambda (self name lower upper (lower-inclusive? #t) (upper-inclusive? #t))
    (.call (%table-object-protocol self) .index-range<- self name lower upper lower-inclusive? upper-inclusive?)))
;; Eager named ranges keep the existing complete result convention.
(defmethod (@@method index-range %table-object)
  (lambda (self name lower upper (lower-inclusive? #t) (upper-inclusive? #t))
    (.call (%table-object-protocol self) .index-range self name lower upper lower-inclusive? upper-inclusive?)))

;; Set membership observes an element through the receiver's originating protocol.
(defmethod (@@method elt? %table-object)
  (lambda (self element) (.call (%table-object-protocol self) .elt? self element)))
;; Set insertion uses the same staged update and ownership commit as table writes.
(defmethod (@@method cons %table-object)
  (lambda (self element) (.call (%table-object-protocol self) .cons element self)))
;; Tables pass an overlap resolver; sets retain their two-operand union protocol.
(defmethod (@@method union %table-object)
  (case-lambda
    ((self other) (.call (%table-object-protocol self) .union self other))
    ((self choose other) (.call (%table-object-protocol self) .union choose self other))))
;; Binary merging stages a complete same-style result, consuming only the left.
(defmethod (@@method merge %table-object)
  (lambda (self choose other) (.call (%table-object-protocol self) .merge choose self other)))
;; Left-biased joins use the same typed merge without inventing callback values.
(defmethod (@@method join %table-object)
  (lambda (self other) (.call (%table-object-protocol self) .join self other)))
;; Batch joining snapshots all right inputs before entering the persistent fold.
(defmethod (@@method join/list %table-object)
  (lambda (self others) (.call (%table-object-protocol self) .join/list self others)))
;; Intersection retains admitted elements without another normalization boundary.
(defmethod (@@method inter %table-object)
  (lambda (self other) (.call (%table-object-protocol self) .inter self other)))
;; Set difference is distinct from the backing table's delta-discovery operation.
(defmethod (@@method diff %table-object)
  (lambda (self other) (.call (%table-object-protocol self) .diff self other)))
;; Symmetric difference delegates the existing finite set merge selector.
(defmethod (@@method symdiff %table-object)
  (lambda (self other) (.call (%table-object-protocol self) .symdiff self other)))
;; Relations observe two compatible live states without transferring ownership.
(defmethod (@@method subset? %table-object)
  (lambda (self other) (.call (%table-object-protocol self) .subset? self other)))
;; Disjointness preserves the original backend's short-circuit behavior.
(defmethod (@@method disjoint? %table-object)
  (lambda (self other) (.call (%table-object-protocol self) .disjoint? self other)))
;; Equality delegates the originating Table/Set protocol without consuming owners.
(defmethod (@@method =? %table-object)
  (lambda (self other) (.call (%table-object-protocol self) .=? self other)))

;; Derive all five styles from one persistent table. Operations stage callbacks
;; outside the lock, then compare the captured head before one whole installation.
;; Pure backend callbacks and immutable leaves are explicit ownership premises.
(def (derive-table-styles source (set #f))
  ;; Ordering is an explicit origin even when the raw backend has not repeated
  ;; Comparer in .sources. Deduplicate the union once, not on each observation.
  (def sources (delete-duplicates/hash (append
    (if set (cons set (if (.has? set .sources) (.@ set .sources) [])) [])
    (table-sources source)
    (if (.has? source Comparer)
      (cons (.@ source Comparer) (.@ (.@ source Comparer) .sources)) []))
    table: (make-hash-table-eq) from-end?: #t))
  (def versions (map object-revision sources))
  (def owner (list source))
  ;; Retain every backend/converter origin across admission and user callbacks.
  (def (guard action)
    (with-table-sources sources (lambda ()
      (unless (equal? versions (map object-revision sources))
        (error "stale table styles"))
      (action))))
  ;; A customized set recognizer may refine its backing carrier. Keep both
  ;; obligations without normalizing keys or trusting a broader custom predicate.
  (def (admitted value)
    (require-table source value)
    (when set (require-table set value))
    value)
  ;; Allocate one private capability; no capability constructor is public.
  (def (reference style value)
    (make-%table-reference owner style (make-%table-head value) (make-mutex 'table-reference)))
  ;; Foreign styles/factories refuse before any user callback or ownership change.
  (def (check style input)
    (unless (and (%table-reference? input) (eq? (%table-reference-owner input) owner)
                 (eq? (%table-reference-style input) style))
      (error "incompatible table reference")))
  ;; Capture one live generation under the official runtime lock mechanism.
  (def (capture style input)
    (check style input)
    (with-lock (%table-reference-lock input) (lambda ()
      (or (%table-reference-head input) (error "consumed table reference")))))
  ;; Commit only the exact captured generation. Reentrant/competing installations
  ;; may win, but an older callback can never overwrite their result or resurrect it.
  (def (install input expected next)
    (with-lock (%table-reference-lock input) (lambda ()
      (unless (eq? (%table-reference-head input) expected)
        (error "stale table reference"))
      (set! (%table-reference-head input) next))))
  ;; One higher-order constructor supplies the same complete API for every style.
  (def (derive style (receiver? #f))
    ;; Authenticate receiver provenance by its private protocol, not public fields.
    (def (unwrap input)
      (if receiver?
        (if (and (%table-object? input) (eq? (%table-object-protocol input) protocol))
          (%table-object-state input) (error "incompatible table receiver"))
        input))
    ;; Presentation is staged before any ownership commit; no detached cache exists.
    (def (present state)
      (if receiver? (make-%table-object protocol state) state))
    ;; Wrap an already admitted snapshot without replacing Function identities.
    (def (create value)
      (guard (lambda ()
        (def snapshot (admitted value))
        (present (if (eq? style 'pure) snapshot (reference style snapshot))))))
    ;; Snapshot observation never consumes ownership; returned pure roots are shared.
    (def (read input)
      (guard (lambda ()
        (let (state (unwrap input))
          (if (eq? style 'pure) (admitted state)
            (%table-head-value (capture style state)))))))
    ;; Capture once before invoking a backend observer. Reentrant publication may
    ;; change the owner, but this operation retains one persistent snapshot.
    ;; Unsupported capabilities refuse rather than inventing an ordering policy.
    (def (observe input method args (deferred? #f) (descriptor source))
      (guard (lambda ()
        (def snapshot (read input))
        (unless (.slot? descriptor method) (error "unsupported table observation" method))
        (def result (apply (.ref descriptor method) snapshot args))
        (if deferred? (iterator-map identity result guard) result))))
    ;; Cross-type output cannot replace a source owner. Capture one source root,
    ;; delegate under its guard and let the caller choose a target presentation.
    (def (map-into method target transform input)
      (guard (lambda () ((.ref source method) target transform (read input)))))
    ;; Fold signatures place the snapshot last, as required by methods.table.
    (def (fold input method f seed (descriptor source))
      (using (f :~ procedure?)
        (guard (lambda () ((.ref descriptor method) f seed (read input))))))
    ;; Callback-first observations retain custom delegates, element arity and
    ;; the existing owner/delegate admission order for predicate queries.
    (def (query input method callback)
      (guard (lambda () ((.ref (or set source) method) callback (read input)))))
    ;; Capture two roots before user comparison. Reentrant publication remains
    ;; visible on owners without changing either immutable observed snapshot.
    (def (compare-roots left right compare)
      (guard (lambda ()
        (let* ((a (read left)) (b (read right)))
          (if set (.call set .compare a b) (.call source .compare compare a b))))))
    ;; Commit an already prepared result once. This shared boundary never calls
    ;; user code while holding the lock and never exposes a losing successor.
    (def (publish state expected first result)
      (unless (eq? style 'pure)
        (install state expected (and (eq? style 'mutable) (make-%table-head first))))
      result)
    ;; Stage a private list of roots. All roots, capabilities and receiver
    ;; presentations are ready before the single head comparison/installation.
    ;; Mutable style retains input as the first result; extra owners are fresh.
    ;; Linear style retires input once and returns only fresh live successors.
    (def (stage input transform)
      (guard (lambda ()
        (def state (unwrap input))
        (def expected (and (not (eq? style 'pure)) (capture style state)))
        (def before (if expected (%table-head-value expected) (admitted state)))
        (def roots (map admitted (transform before)))
        ;; Empty division publishes the original empty root for mutable owners;
        ;; linear owners retire once even though no successor capability exists.
        (def first (if (pair? roots) (car roots) before))
        (def results (if (null? roots) [] (cons
          (case style
            ((pure) (present first))
            ((mutable) input)
            ((linear) (present (reference style first))))
          (map (lambda (root)
            (present (if (eq? style 'pure) root (reference style root)))) (cdr roots)))))
        (publish state expected first results))))
    ;; Single-result writes retain their direct path: partition's root/result lists
    ;; are not allocated for ordinary point updates, deltas or FUN mapping.
    (def (step input transform)
      (using (transform :~ procedure?)
        (guard (lambda ()
          (def state (unwrap input))
          (def expected (and (not (eq? style 'pure)) (capture style state)))
          (def before (if expected (%table-head-value expected) (admitted state)))
          (def after (admitted (transform before)))
          (def result (case style
            ((pure) (present after)) ((mutable) input)
            ((linear) (present (reference style after)))))
          (publish state expected after result)))))
    ;; Reuse the checked root transformation within the captured owner generation.
    ;; Callback/refinement refusal leaves it live; a reentrant winner stays visible.
    (def (update-opt key transform input)
      (using (transform :~ procedure?)
        (step input (cut update-table-focus source key transform <>))))
    ;; Focus creation retains this factory's guard and never leaks a raw setter.
    (def (focus key optional?)
      (make-table-key-focus source key optional?
        (lambda (input) ((.ref source (if optional? '.ref/opt '.ref)) (read input) key))
        (lambda (input transform) (update-opt key transform input)) guard))
    ;; Set descriptors change predicate arity only. Backend traversal and both
    ;; return values are retained; stage authenticates input before any callback.
    (def (select method predicate input)
      (using (predicate :~ procedure?)
        (def descriptor (or set source))
        (if (eq? method '.filter)
          (step input (lambda (before) (.call descriptor .filter predicate before)))
          (apply values (stage input (lambda (before)
            (defvalues (yes no) (.call descriptor .partition predicate before))
            (list yes no)))))))
    ;; Retain the pivot observation privately while the common stage prepares both
    ;; successor capabilities. A refused right side never consumes the predecessor.
    (def (split key input)
      (def middle #f)
      (def roots (stage input (lambda (before)
        (defvalues (left found right) (.call (or set source) .split key before))
        (set! middle found)
        (list left right))))
      (values (car roots) middle (cadr roots)))
    ;; Preserve the selected public result protocol before staging capabilities.
    ;; Wrong backend value arity must refuse before the ownership commit.
    (def (divide input list?)
      (def descriptor (or set source))
      (def roots (stage input (lambda (before)
        (if list? (.call descriptor .divide/list before)
          (let-values (((left right) (.call descriptor .divide before)))
            (filter identity (list left right)))))))
      (if list? roots (table-division-values roots)))
    ;; Keep the non-owning observation private until step has prepared the successor
    ;; capability and committed once. Reentrant winners cannot leak a losing choice.
    (def (decons input required?)
      (def observed #f)
      (def next (step input (lambda (before)
        (defvalues (found rest)
          ((.ref (or set source) (if required? '.decons '.decons/opt)) before))
        (set! observed found)
        rest)))
      (values observed next))
    ;; Capture the left generation before observing the right snapshot. Aliases
    ;; use that exact left snapshot; distinct right owners are observed, not spent.
    (def (merge-with input right combine)
      (step input (lambda (before)
        (combine before (if (eq? input right) before (read right))))))
    ;; Stage all right snapshots before any batch installation. The persistent
    ;; source owns intermediate root admission; only the left owner commits once.
    (def (join-many input others)
      (using (others :~ list?)
        ;; Capture owner identities before left admission can reuse caller cells.
        (set! others (map identity others))
        (step input (lambda (before)
          (.call source .join/list (cons before (map (lambda (other)
            (if (eq? input other) before (read other))) others)))))))
    ;; Observe a compatible right state before beginning the left update callback.
    ;; Captured immutable roots remain stable; only the left capability commits.
    (def (combine method left right)
      (guard (lambda ()
        (def other (read right))
        (step left (lambda (before) ((.ref set method) before other))))))
    ;; Decoders create a fresh presentation only after complete codec admission.
    ;; No existing owner is replaced or retired by a factory constructor.
    (def (decode method input)
      (guard (lambda () (create ((.ref (or set source) method) input)))))
    ;; Relations share complete guards and never install or retire either owner.
    (def (relate method left right)
      (guard (lambda () ((.ref (or set source) method) (read left) (read right)))))
    ;; Conversion transfers owned references, including same-style conversion.
    ;; Use .unap for a nonconsuming snapshot; pure sources need no retirement.
    (def (convert input target)
      (def target-protocol (case target
        ((pure) (.@ family Pure)) ((mutable) (.@ family Mutable))
        ((linear) (.@ family Linear)) ((posh) (.@ family Posh))
        ((classy) (.@ family Classy)) (else (error "unknown table style" target))))
      (guard (lambda ()
        (def state (unwrap input))
        (def expected (and (not (eq? style 'pure)) (capture style state)))
        (def value (if expected (%table-head-value expected) (admitted state)))
        ;; FUN construction includes receiver allocation and admission before retirement.
        (def result (.call target-protocol .ap value))
        (when expected (install state expected #f))
        result)))
    ;; One protocol identity authenticates its receiver-bound states.
    (def protocol
    (let (base (.cc Wrapper.
      Domain: (or set source)
      ;; Raw input has a separate normalization boundary; .ap preserves admitted roots.
      .admit: (lambda (value) (guard (lambda () (create (validate (or set source) value)))))
      .ap: create .unap: read
      .bind: (lambda (input f) (guard (lambda () (f (read input)))))
      .map: (lambda (f input) (step input f))
      .step: step .convert: convert
      ;; Constructors allocate a fresh presentation through the ordinary creator;
      ;; they neither consume an existing owner nor normalize admitted leaves.
      .<-list: (lambda (rows)
        ;; Set elements are opaque leaves, so only their outer spine is owned.
        ;; Table rows additionally own Pair shells before any custom delegate.
        ;; Defer malformed outer requests to their existing guarded delegate:
        ;; stale factories still refuse before the constructor's list contract.
        (def captured (if (list? rows)
          (if set (map identity rows) (capture-table-bindings rows)) rows))
        (guard (lambda () (create (.call (or set source) .<-list captured)))))
      .singleton: (if set
        (lambda (elt) (guard (lambda () (create (.call set .singleton elt)))))
        (lambda (key value) (guard (lambda () (create (.call source .singleton key value))))))
      .compare: (if set (lambda (left right) (compare-roots left right #f))
        (lambda (compare left right) (compare-roots left right compare)))
      ;; Equal observations authenticate both owners and never install a successor.
      .=?: (cut relate '.=? <> <>)
      ;; Encoding is a snapshot read; decoding reuses the ordinary fresh creator.
      .json<-: (lambda (input) (observe input '.json<- [] #f (or set source)))
      .bytes<-: (lambda (input) (observe input '.bytes<- [] #f (or set source)))
      .marshal: (lambda (input port) (observe input '.marshal (list port) #f (or set source)))
      .<-json: (cut decode '.<-json <>) .<-bytes: (cut decode '.<-bytes <>)
      .unmarshal: (cut decode '.unmarshal <>)
      ;; Fresh imports reuse normal owner creation; seeded imports use the same
      ;; optimistic step as all other updates, including reentrant-winner refusal.
      .<-iter: (case-lambda
        ((sequence) (guard (lambda () (create (.call (or set source) .<-iter sequence)))))
        ((sequence input) (step input (cut .call (or set source) .<-iter sequence <>))))
      ;; Binding callbacks remain distinct from FUN's whole-root .map operation.
      .map/2: (lambda (transform input) (step input (cut .call source .map/2 transform <>)))
      .filter-map/2: (lambda (transform input) (step input (cut .call source .filter-map/2 transform <>)))
      .map/into: (cut map-into '.map/into <> <> <>)
      .filter-map/into: (cut map-into '.filter-map/into <> <> <>)
      .merge: (lambda (choose input right) (merge-with input right (cut .call source .merge choose <> <>)))
      .union: (lambda (choose input right) (merge-with input right (cut .call source .union choose <> <>)))
      .join: (lambda (input right) (merge-with input right (.@ source .join)))
      .join/list: join-many
      .ref/opt: (lambda (input key) (guard (lambda ()
        (require-table-key source key) (.call source .ref/opt (read input) key))))
      .update/opt: update-opt
      ;; Share captured Option admission; a successful linear no-op still retires.
      .acons/opt: (lambda (key response input)
        (update-opt key (table-association-update source response) input))
      .update: (lambda (key transform input (default false))
        (using (transform :~ procedure?)
          (update-opt key (lambda (old) (some (transform (option-get/default old default)))) input)))
      .delta/opt: (lambda (key transform input)
        (guard (lambda () (.call source .delta/opt key transform (read input)))))
      .lens: (cut focus <> #f) .lens/opt: (cut focus <> #t)
      .filter: (cut select '.filter <> <>)
      ;; Complete source selection precedes the existing single-generation commit.
      .take: (lambda (count input) (step input (cut .call (or set source) .take count <>)))
      .drop: (lambda (count input) (step input (cut .call (or set source) .drop count <>)))
      .split: split
      .decons/opt: (cut decons <> #f) .decons: (cut decons <> #t)
      .divide/list: (cut divide <> #t) .divide: (cut divide <> #f)
      .partition: (cut select '.partition <> <>)
      ;; Deferred observations retain source guards through every pull and EOF.
      .iter<-: (lambda (input) (observe input '.iter<- [] #t))
      .foldl: (lambda (f seed input) (fold input '.foldl f seed))
      .foldr: (lambda (f seed input) (fold input '.foldr f seed))
      ;; New visit entries check callbacks even for empty backing snapshots.
      .for-each: (lambda (f input) (using (f :~ procedure?) (query input '.for-each f)))
      .for-each/reverse: (lambda (f input) (using (f :~ procedure?) (query input '.for-each/reverse f)))
      .find-first/opt: (lambda (p input) (query input '.find-first/opt p))
      .find-first: (lambda (p input) (query input '.find-first p))
      .find-last/opt: (lambda (p input) (query input '.find-last/opt p))
      .find-last: (lambda (p input) (query input '.find-last p))
      .every: (lambda (p input) (query input '.every p))
      .any: (lambda (p input) (query input '.any p))
      ;; Endpoints share the existing guarded snapshot observer, never step/install.
      .min-binding/opt: (lambda (input) (observe input '.min-binding/opt []))
      .min-binding: (lambda (input) (observe input '.min-binding []))
      .max-binding/opt: (lambda (input) (observe input '.max-binding/opt []))
      .max-binding: (lambda (input) (observe input '.max-binding []))
      .choose/opt: (lambda (input) (observe input '.choose/opt [] #f (or set source)))
      .choose: (lambda (input) (observe input '.choose [] #f (or set source)))
      ;; Capture bound cells before snapshot admission and computed method lookup;
      ;; capability lifting retains the backend's own order, flags and errors.
      .seek<-: (lambda (input lower (inclusive? #t)) (observe input '.seek<- (list (map/option identity lower) inclusive?) #t))
      .seek: (lambda (input lower (inclusive? #t)) (observe input '.seek (list (map/option identity lower) inclusive?)))
      .range: (lambda (input lower upper (lower-inclusive? #t) (upper-inclusive? #t))
        (observe input '.range (list (map/option identity lower) (map/option identity upper) lower-inclusive? upper-inclusive?)))
      .range<-: (lambda (input lower upper (lower-inclusive? #t) (upper-inclusive? #t))
        (observe input '.range<- (list (map/option identity lower) (map/option identity upper) lower-inclusive? upper-inclusive?) #t))
      .index-ref/opt: (lambda (input name key) (observe input '.index-ref/opt (list name key)))
      .index-fold: (lambda (input name f seed) (observe input '.index-fold (list name f seed)))
      .index-iter<-: (lambda (input name) (observe input '.index-iter<- (list name) #t))
      .index-seek<-: (lambda (input name lower (inclusive? #t))
        (observe input '.index-seek<- (list name (map/option identity lower) inclusive?) #t))
      .index-range<-: (lambda (input name lower upper (lower-inclusive? #t) (upper-inclusive? #t))
        (observe input '.index-range<- (list name (map/option identity lower) (map/option identity upper) lower-inclusive? upper-inclusive?) #t))
      .index-range: (lambda (input name lower upper (lower-inclusive? #t) (upper-inclusive? #t))
        (observe input '.index-range (list name (map/option identity lower) (map/option identity upper) lower-inclusive? upper-inclusive?)))
      ;; Read through FUN binding so backend callbacks retain the source guard.
      .ref: (lambda (input key . default)
        (guard (lambda () (apply (.@ source .ref) (read input) key default))))
      ;; Reuse the existing snapshot reader, including Set constraints and ownership.
      .empty?: (lambda (input) (observe input '.empty? [] #f (or set source)))
      .count: (lambda (input) (guard (lambda () (.call source .count (read input)))))
      .list<-: (lambda (input) (guard (lambda () (.call source .list<- (read input)))))
      ;; Point operations reuse the exact staged transformation engine.
      .acons: (lambda (key value input) (step input (cut .call source .acons key value <>)))
      .remove: (lambda (input key) (step input (cut .call source .remove <> key)))
      ;; Whole deltas/batches reuse the original optimistic conflict protocol.
      .apply-delta: (lambda (input delta) (step input (cut .call source .apply-delta <> delta)))
      .apply-batch: (lambda (input batch) (step input (lambda (before)
        (.call source .apply-delta before (.call source .compose-deltas batch)))))))
      (if (not set) base
        ;; Presentation changes callback/element arity, never the installation engine.
        (.cc base
          .list<-: (lambda (input) (observe input '.list<- [] #f set))
          .iter<-: (lambda (input) (observe input '.iter<- [] #t set))
          .foldl: (lambda (f seed input) (fold input '.foldl f seed set))
          .foldr: (lambda (f seed input) (fold input '.foldr f seed set))
          ;; Ordered capabilities belong to the backing table; project entries only.
          .seek<-: (lambda (input lower (inclusive? #t))
            (iterator-map car (observe input '.seek<- (list (map/option identity lower) inclusive?) #t)))
          .seek: (lambda (input lower (inclusive? #t))
            (map/option car (observe input '.seek (list (map/option identity lower) inclusive?))))
          .range: (lambda (input lower upper (lower-inclusive? #t) (upper-inclusive? #t))
            (map car (observe input '.range (list (map/option identity lower) (map/option identity upper) lower-inclusive? upper-inclusive?))))
          .range<-: (lambda (input lower upper (lower-inclusive? #t) (upper-inclusive? #t))
            (iterator-map car (observe input '.range<- (list (map/option identity lower) (map/option identity upper) lower-inclusive? upper-inclusive?) #t)))
          ;; Set presentation reuses the same observer with element-level results.
          .min-elt/opt: (lambda (input) (observe input '.min-elt/opt [] #f set))
          .min-elt: (lambda (input) (observe input '.min-elt [] #f set))
          .max-elt/opt: (lambda (input) (observe input '.max-elt/opt [] #f set))
          .max-elt: (lambda (input) (observe input '.max-elt [] #f set))
          .elt?: (lambda (input element) (guard (lambda () (.call set .elt? (read input) element))))
          .cons: (lambda (element input) (step input (cut .call set .cons element <>)))
          .remove: (lambda (input element) (step input (cut .call set .remove <> element)))
          .union: (cut combine '.union <> <>) .inter: (cut combine '.inter <> <>)
          .diff: (cut combine '.diff <> <>) .symdiff: (cut combine '.symdiff <> <>)
          .subset?: (cut relate '.subset? <> <>) .disjoint?: (cut relate '.disjoint? <> <>)))))
    protocol)
  ;; Posh/classy attach the existing pure/mutable FUN protocols to host receivers.
  (def family (.cc Type. Pure: (derive 'pure) Mutable: (derive 'mutable)
    Linear: (derive 'linear) Posh: (derive 'pure #t) Classy: (derive 'mutable #t)))
  family)

;; Public table derivation retains the existing signature and exact protocol shape.
(def (table-styles source) (derive-table-styles source))

;; Set styles reuse the Unit-valued backing carrier and the same ownership family.
;; Explicit descriptor identities prevent a forged Elt from changing admission.
(def (set-styles descriptor)
  (def source (.@ descriptor Table))
  (with-table-sources (append (list descriptor)
    (if (.has? descriptor .sources) (.@ descriptor .sources) []) (table-sources source)) (lambda ()
    (unless (and (eq? (.@ source Value) Unit) (eq? (.@ descriptor Elt) (.@ source Key)))
      (error "incompatible set style descriptor"))
    (derive-table-styles source descriptor))))
