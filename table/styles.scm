;;; Interface-passing and receiver-bound collection styles share one backend.

;; A fresh immutable head identifies a generation even when the value returns to
;; an equal snapshot. False denotes consumed ownership, never a stored table value.
(defstruct %table-head (value) final: #t)
;; Constructors and mutable fields remain private to the existing table module.
(defstruct %table-reference (owner style head lock) final: #t)

;; The official Gerbil receiver carries its originating FUN protocol and private
;; state. Neither the constructor nor the state accessors leave this module.
(defstruct %table-object (protocol state) final: #t)

;; Observe through the originating protocol, including metadata and ownership checks.
(defmethod (@@method snapshot %table-object)
  (lambda (self) (.call (%table-object-protocol self) .unap self)))
;; Retain FUN observation without making the private update capability public.
(defmethod (@@method bind %table-object)
  (lambda (self consumer) (.call (%table-object-protocol self) .bind self consumer)))
;; Pure receivers return successors; mutable receivers retain their own identity.
(defmethod (@@method step %table-object)
  (lambda (self transform) (.call (%table-object-protocol self) .step self transform)))
;; Delegate ordered changes to the existing atomic table installer.
(defmethod (@@method apply-delta %table-object)
  (lambda (self delta) (.call (%table-object-protocol self) .apply-delta self delta)))
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
(defmethod (@@method range %table-object)
  (lambda (self lower upper (lower-inclusive? #t) (upper-inclusive? #t))
    (.call (%table-object-protocol self) .range self lower upper lower-inclusive? upper-inclusive?)))
;; Correlated lookups observe the same captured primary/index snapshot.
(defmethod (@@method index-ref/opt %table-object)
  (lambda (self name key) (.call (%table-object-protocol self) .index-ref/opt self name key)))
;; Index comparators and failure classifications remain owned by the backend.
(defmethod (@@method index-range %table-object)
  (lambda (self name lower upper (lower-inclusive? #t) (upper-inclusive? #t))
    (.call (%table-object-protocol self) .index-range self name lower upper lower-inclusive? upper-inclusive?)))

;; Derive all five styles from one persistent table. Operations stage callbacks
;; outside the lock, then compare the captured head before one whole installation.
;; Pure backend callbacks and immutable leaves are explicit ownership premises.
(def (table-styles source)
  (def sources (table-sources source))
  (def versions (map object-revision sources))
  (def owner (list source))
  ;; Retain every backend/converter origin across admission and user callbacks.
  (def (guard action)
    (with-table-sources sources (lambda ()
      (unless (equal? versions (map object-revision sources))
        (error "stale table styles"))
      (action))))
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
        (def admitted (require-table source value))
        (present (if (eq? style 'pure) admitted (reference style admitted))))))
    ;; Snapshot observation never consumes ownership; returned pure roots are shared.
    (def (read input)
      (guard (lambda ()
        (let (state (unwrap input))
          (if (eq? style 'pure) (require-table source state)
            (%table-head-value (capture style state)))))))
    ;; Capture once before invoking a backend observer. Reentrant publication may
    ;; change the owner, but this operation retains one persistent snapshot.
    ;; Unsupported capabilities refuse rather than inventing an ordering policy.
    (def (observe input method args (deferred? #f))
      (guard (lambda ()
        (def snapshot (read input))
        (unless (.slot? source method) (error "unsupported table observation" method))
        (def result (apply (.ref source method) snapshot args))
        (if deferred? (iterator-map identity result guard) result))))
    ;; Fold signatures place the snapshot last, as required by methods.table.
    (def (fold input method f seed)
      (using (f :~ procedure?)
        (guard (lambda () ((.ref source method) f seed (read input))))))
    ;; Stage a single-result pure transformation, then admit without rewrapping.
    ;; Refusal, exception or conflict before installation preserves the old head.
    (def (step input transform)
      (using (transform :~ procedure?)
        (guard (lambda ()
          (def state (unwrap input))
          (def expected (and (not (eq? style 'pure)) (capture style state)))
          (def before (if expected (%table-head-value expected) (require-table source state)))
          (def after (require-table source (transform before)))
          (case style
            ((pure) (present after))
            ((mutable) (install state expected (make-%table-head after)) input)
            ((linear)
             ;; Prepare the successor before consuming; allocation failure cannot
             ;; retire the only reference. A losing staged successor never escapes.
             (let (successor (present (reference 'linear after)))
               (install state expected #f)
               successor)))))))
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
        (def value (if expected (%table-head-value expected) (require-table source state)))
        ;; FUN construction includes receiver allocation and admission before retirement.
        (def result (.call target-protocol .ap value))
        (when expected (install state expected #f))
        result)))
    ;; One protocol identity authenticates its receiver-bound states.
    (def protocol
    (.cc Wrapper.
      Domain: source
      ;; Raw input has a separate normalization boundary; .ap preserves admitted roots.
      .admit: (lambda (value) (guard (lambda () (create (validate source value)))))
      .ap: create .unap: read
      .bind: (lambda (input f) (guard (lambda () (f (read input)))))
      .map: (lambda (f input) (step input f))
      .step: step .convert: convert
      ;; Deferred observations retain source guards through every pull and EOF.
      .iter<-: (lambda (input) (observe input '.iter<- [] #t))
      .foldl: (lambda (f seed input) (fold input '.foldl f seed))
      .foldr: (lambda (f seed input) (fold input '.foldr f seed))
      ;; Capability lifting forwards the backend's own order, bounds and errors.
      .seek<-: (lambda (input lower (inclusive? #t)) (observe input '.seek<- (list lower inclusive?) #t))
      .seek: (lambda (input lower (inclusive? #t)) (observe input '.seek (list lower inclusive?)))
      .range: (lambda (input lower upper (lower-inclusive? #t) (upper-inclusive? #t))
        (observe input '.range (list lower upper lower-inclusive? upper-inclusive?)))
      .index-ref/opt: (lambda (input name key) (observe input '.index-ref/opt (list name key)))
      .index-range: (lambda (input name lower upper (lower-inclusive? #t) (upper-inclusive? #t))
        (observe input '.index-range (list name lower upper lower-inclusive? upper-inclusive?)))
      ;; Read through FUN binding so backend callbacks retain the source guard.
      .ref: (lambda (input key . default)
        (guard (lambda () (apply (.@ source .ref) (read input) key default))))
      .count: (lambda (input) (guard (lambda () (.call source .count (read input)))))
      .list<-: (lambda (input) (guard (lambda () (.call source .list<- (read input)))))
      ;; Point operations reuse the exact staged transformation engine.
      .acons: (lambda (key value input) (step input (cut .call source .acons key value <>)))
      .remove: (lambda (input key) (step input (cut .call source .remove <> key)))
      ;; Whole deltas/batches reuse the original optimistic conflict protocol.
      .apply-delta: (lambda (input delta) (step input (cut .call source .apply-delta <> delta)))
      .apply-batch: (lambda (input batch) (step input (lambda (before)
        (.call source .apply-delta before (.call source .compose-deltas batch)))))))
    protocol)
  ;; Posh/classy attach the existing pure/mutable FUN protocols to host receivers.
  (def family (.cc Type. Pure: (derive 'pure) Mutable: (derive 'mutable)
    Linear: (derive 'linear) Posh: (derive 'pure #t) Classy: (derive 'mutable #t)))
  family)
