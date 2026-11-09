;;; Receiver-bound read issuance, replay and explicit dependency registration.
;;; Included by object.ss in its original namespace; no extra runtime image.
;; MOP read records live on the receiver and are cleared with its receiver-local cache.
;; A retained record may retain its receiver; no global registry retains either.
(def (object-read-table self)
  (or (object-%reads self)
      (let (table (make-hash-table)) (set! (object-%reads self) table) table)))
;; Authenticate issuance and the pinned route before checking receiver freshness.
(def (object-read-current? read)
  (and (object-read-issued? read)
       (begin (require-object-read-route! read)
              (object-issued-read-current? read))))
;; Inspect only receiver-owned state after the caller has authenticated the record.
(def (object-issued-read-current? read)
  (def self (slot-read-receiver read))
  (def key (read-runtime.slot-ref read 'key))
  (and (= (slot-read-revision read) (object-revision self))
       (cond
         ((and (pair? key) (eq? (car key) 'bootstrap))
          (let (anchor (bootstrap-anchor self (cadr key)))
            (and anchor (eq? (cdr anchor) (slot-read-value read)))))
         ((not (eq? (slot-read-instance read) (object-%instance self))) #f)
         ((and (pair? key) (eq? (car key) 'cache-miss))
          (not (hash-key? (object-%instance self) (cadr key))))
         (else
          (and (object-%reads self) (eq? read (hash-get (object-%reads self) key))
               (or (pair? key)
                   (eq? (slot-read-value read)
                        (hash-ref (object-%instance self) key absent-value))))))))
(defvalues (issue-object-read object-read-issued? object-read-issuance) (make-read-issuer))
;; Capture source state and preserve preparation parents at this one boundary.
;; The existing read module owns provenance, without receiver-accessor callbacks.
(def (object-record-read self key value dependencies)
  (def preparation (and (object-%reads self) (hash-get (object-%reads self) '(preparation))))
  (def parents
    (if (and preparation (not (and (pair? key) (memq (car key) '(preparation bootstrap)))))
      (cons preparation dependencies) dependencies))
  (issue-object-read self key (object-revision self) (object-%instance self) value parents object-read-current?))

;; Reject a replaced receiver route before accepting its captured value.
(def (require-object-read-route! read)
  (def receiver (slot-read-receiver read))
  (require-read-route! (read-runtime.slot-ref read 'key)
    (object-%reads receiver) (object-%instance receiver)))

;; Detect constructor replacement before an internal projection can allocate a receiver.
(def object-construction-current?
  (let* ((object-init (read-runtime.find-method object::t #f ':init!))
         (state-class (read-runtime.object-class (make-object-state)))
         (state-init (read-runtime.find-method state-class #f ':init!)))
    (lambda ()
      (and (eq? object-init (read-runtime.find-method object::t #f ':init!))
           (eq? state-init (read-runtime.find-method state-class #f ':init!))))))
;; Share authenticated finite traversal structure; each call owns fresh source guards.
(def call-with-issued-reads
  (let ()
    ;; The index owns neither roots nor cache receivers. A live projection keeps
    ;; its ordinary receiver-local cache owner alive; GC eviction is always a cold miss.
    ;; No mutable visitation set or successful validation result is retained.
    (def owners (make-table test: eq? weak-keys: #t weak-values: #t))
    (defstruct projection (owner roots reads receivers) final: #t)
    ;; A cold cache owner must not dispatch an injected CLOS initializer during
    ;; authentication. Changed constructor metadata keeps the original DFS path.
    (def construction-current? object-construction-current?)
    (def (require-issued! read)
      (unless (object-read-issued? read) (error "unissued slot dependency")))
    (def (require-live! read)
      (require-object-read-route! read)
      (unless (object-issued-read-current? read)
        (error "stale slot dependency" (slot-read-key read))))
    (def (require-current! read)
      (require-issued! read)
      (require-live! read))
    (def (same-roots? roots saved)
      (if (null? saved) (null? roots)
        (and (pair? roots) (eq? (car roots) (car saved))
             (same-roots? (cdr roots) (cdr saved)))))
    (def (build owner roots)
      (def seen (make-hash-table-eq))
      (def receivers (make-hash-table-eq))
      (def ordered '())
      (def (collect read)
        (unless (hash-key? seen read)
          (require-issued! read)
          (hash-put! seen read #t)
          (hash-put! receivers (slot-read-receiver read) #t)
          (set! ordered (cons read ordered))
          (for-each collect (read-runtime.slot-ref read 'dependencies))))
      ;; The cold selector admits a finite root spine before entering this DFS.
      ;; Preserve full issuance preflight and its order for every admitted root.
      ;; Only successful traversal copies roots and publishes a cached value.
      (for-each collect roots)
      (make-projection owner (map values roots) (reverse ordered) receivers))
    (def (obtain roots)
      (def owner (table-ref owners roots #f))
      (def instance (and owner (object-%instance owner)))
      (def cached (if instance (hash-ref instance 'projection absent-value) absent-value))
      (cond
       ((and (not (eq? cached absent-value))
             (same-roots? roots (projection-roots cached)))
        (begin
          ;; Signed dependency sequences are reauthenticated on EVERY hit.
          ;; Their equality proves this exact preorder remains complete; it
          ;; does not prove live revisions, values or external sources current.
          (for-each require-issued! (projection-reads cached))
          cached))
       (else
        ;; A warm signature already proves exact finite membership. On a miss,
        ;; reject improper/cyclic caller spines before allocation or traversal;
        ;; successful validation itself is never stored as a reusable verdict.
        (using (roots :~ list?)
          (if (construction-current?)
            (let* ((owner (make-object slots:
                            (list (cons 'projection
                              ($self-slot-spec (lambda (self) (build self roots)))))))
                   (next (.ref owner 'projection)))
              ;; Existing slot computation owns success/failure caching.
              ;; Do not install a failed or partially authenticated projection.
              (table-set! owners roots owner)
              next)
            (build #f roots))))))
    (lambda (roots consume retain? (fixed-result? #f))
      ;; Replay callers can retain roots; a fresh capture has no future lookup
      ;; identity. Reuse the SAME finite DFS without a cache owner or weak entry.
      (def selected (without-observation
        (lambda () (if retain? (obtain roots) (using (roots :~ list?) (build #f roots))))))
      (def traversal (projection-reads selected))
      ;; The receiver set is private/read-only. Nested frames and unwind remain
      ;; per call; sharing structure never shares a populated DFS seen table.
      (if fixed-result?
        ;; Selection already authenticated the whole issued traversal. The
        ;; fixed result has no callback before or after this live check.
        (consume traversal require-live! (projection-receivers selected))
        (parameterize ((active-read-replays
                        (cons (projection-receivers selected) (active-read-replays))))
          (begin0 (consume traversal require-current! (projection-receivers selected))
            (without-observation (lambda () (for-each require-current! traversal)))))))))

;; Opt in to invalidation from actual observed Slot reads, not hidden callback
;; state. Run once, admit the complete captured graph before registering edges,
;; then reuse ordinary weak source dependencies. Failed work retains its exact
;; cause and publishes no value; old edges remain conservatively registered.
(def (with-slot-dependencies self action)
  (using ((self :~ object?) (action :~ procedure?))
    (def revision (object-revision self))
    (defvalues (value roots) (%call-with-recorded-slot-reads action))
    (unless (= revision (object-revision self)) (error "object changed during dependency capture"))
    (if (null? roots) value
      (call-with-issued-reads roots
        (lambda (reads current! receivers)
          ;; Whole-graph admission precedes every new source registration.
          (for-each current! reads)
          ;; The existing traversal already owns the distinct receiver set.
          ;; Admission still visits EVERY read, including different keys/epochs.
          (for (([source . _] receivers))
            (unless (eq? source self) (depend-on-object! self source)))
          ;; Preserve original dependency occurrences in the enclosing getter.
          ;; Their observers already ran during action; do not deliver them twice.
          (%record-slot-reads! roots)
          value) #f))))

;; Replay authenticated reads under the same guarded source set and final check.
(def (replay-slot-reads! roots observe)
  (call-with-issued-reads roots
    (lambda (reads current! _receivers)
      (without-observation
        (lambda ()
          (for-each
            (lambda (read)
              (current! read)
              (observe (slot-read-receiver read) (slot-read-key read))) reads)))) #t))

;; A protected checkpoint authenticates the complete live traversal before
;; calling action once. Its native frame verifies the same support at return.
;; This operation does not deliver semantic slot reads to an outer observer.
(def (call-with-current-slot-reads roots action)
  (unless (procedure? action) (error "expected a slot-read checkpoint procedure"))
  (without-observation
    (lambda ()
      (call-with-issued-reads roots
        (lambda (reads current! _receivers)
          (for-each current! reads)
          (action (length reads)))
        #t (or (eq? action values) (eq? action void))))))

;; The Type catalog's warm path delivers ORIGINAL records into its caller's
;; frame. Keep the same selected write protection across work and delivery, not
;; only the initial check. Metadata inspection itself remains unobserved.
(def (reobserve-slot-reads! roots (work void))
  (call-with-issued-reads roots
    (lambda (reads current! _receivers)
      (without-observation (lambda () (for-each current! reads)))
      (for-each
        (lambda (read)
          (work)
          ;; Work may edit the presented record after the initial graph check.
          ;; Keep the same immediate admission used by ordinary replay.
          (without-observation (cut current! read))
          (%deliver-slot-read read (read-runtime.slot-ref read 'value))) reads)) #t))

;; Deliver computed provenance or mint a record for an exact explicit assignment.
(def (object-deliver-value self slot value)
  (def table (object-read-table self))
  (def read
    (or (hash-get table slot)
        ;; Explicit instance writes are values, never inferred computed traces.
        (and (object-%overrides self) (hash-key? (object-%overrides self) slot)
             (eq? value (hash-ref (object-%overrides self) slot))
             (let (read (object-record-read self slot value '()))
               (hash-put! table slot read) read))))
  (unless read (error "unrecorded cached slot" slot))
  (%deliver-slot-read read value))
;; Expose pinned bootstrap values without demanding recursive object construction.
(def (object-read-bootstrap self slot anchor)
  (def key (list 'bootstrap slot))
  (%slot-read-demand! self key)
  (def table (object-read-table self))
  (def saved (hash-get table key))
  (def read (or (and saved (or (not (%slot-read-active?)) (object-read-issued? saved)) saved)
               (let (read (object-record-read self key (cdr anchor) '()))
                 (hash-put! table key read) read)))
  (%deliver-slot-read read (cdr anchor)))
;; Structural preparation can itself read MOP configuration. Retain its FIRST
;; preparation dependencies even when later name/presence queries are hot.
(def (object-read-query self key action cache?: (cache? #t))
  (%slot-read-demand! self key)
  (def revision (object-revision self))
  (defvalues (value dependencies) (%call-with-recorded-slot-reads action))
  (unless (= revision (object-revision self)) (error "object changed during query" key))
  (def table (object-read-table self))
  (def saved (and cache? (hash-get table key)))
  ;; Unobserved queries consume their actual result. Observed queries authenticate
  ;; the saved record and replace a damaged presentation through the same issuer.
  ;; A detached index key keeps the old record reachable for replacement.
  (def read (or (and saved
                    (or (not (%slot-read-active?))
                        (object-read-issued? saved)) saved)
               (let (read (object-record-read self key value dependencies))
                 (when cache? (hash-put! table key read)) read)))
  (%deliver-slot-read read value))
