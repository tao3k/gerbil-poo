;; A failed finite law/collision check reports its kind and offending value.
;; No partially converted carrier or change sequence is included in this payload.
(defstruct table-isomorphism-failure (kind value) final: #t)
;; One captured direction uses the existing Wrapper operations with explicit Types.
;; Its inverse swaps descriptors, captured child Types and pure callbacks. Child
;; identities are stable only within the existing complete revision/guard scope;
;; capturing them adds record fields, not four extra converter closures.
(defstruct table-translation (source target source-key target-key source-value target-value
                              key unkey value unvalue) final: #t)

;; Observed execution must demand and deliver the real metadata read. The
;; ordinary unobserved path reuses the guarded child identity without allocating
;; a converter closure or fabricating/replaying a read token.
(defrule (table-child-type direction accessor owner slot)
  (if (%slot-read-active?) (.@ (owner direction) slot) (accessor direction)))

;; Check actual encountered values without normalizing admitted children again.
;; Both callbacks must map admitted values to admitted values and respect equal?.
;; Membership alone cannot establish Function wrapping or universal inverse laws.
(def (translate-table-value source target forward backward input (observe void))
  (def output (forward input))
  (unless (element? target output) (raise-type-error target output 'table-isomorphism))
  (observe output)
  (def recovered (backward output))
  (unless (and (element? source recovered) (equal? recovered input))
    (raise (make-table-isomorphism-failure 'left-inverse input)))
  (unless (equal? (forward recovered) output)
    (raise (make-table-isomorphism-failure 'right-inverse output)))
  output)

;; Check one encountered carrier roundtrip with the original callback order.
;; Admission may raise but cannot normalize or replace the observed output.
;; Both inverse failures keep the exact phase/value; no cross-call memo is kept.
(def (check-table-carrier input forward backward admit)
  (def output (forward input))
  (admit output)
  (def recovered (backward output))
  (unless (equal? recovered input)
    (raise (make-table-isomorphism-failure 'left-inverse input)))
  (unless (equal? (forward recovered) output)
    (raise (make-table-isomorphism-failure 'right-inverse output)))
  output)

;; Explicitly declared payload-parametric backends share this structural key-space
;; constructor. Business-root refinements do not apply to owner/edit records.
(def (table-key-space backend value)
  (def registry (.o (:: @ backend) Value: value
    ;; A private owner/edit registry is not a business-root constructor. Reuse
    ;; the declared raw finite constructor; do not inherit a partial .empty.
    (.empty (.call backend .<-list/key []))
    .element?: (lambda (root) (table-element? registry root))))
  registry)

;; The capability preserves backend key equality while changing only registry
;; payloads. Never infer constructor polymorphism for an arbitrary table family.
(def (table-key-table descriptor value)
  (def build (.@ descriptor .key-table))
  (unless build (error "unsupported table key registry"))
  (using (build :~ procedure?)
    (def registry (build value))
    (unless (and (eq? (.@ registry Key) (.@ descriptor Key)) (eq? (.@ registry Value) value))
      (error "incompatible table key registry")) registry))

;; Each attempt owns one typed persistent key registry using the TARGET backend.
;; It detects the backend's own collisions, including keys deleted in one snapshot
;; and inserted in the next. Repeated occurrences of the same source key are legal.
(def (table-translators direction (initial #f))
  (def source (table-translation-source direction))
  (def target (table-translation-target direction))
  (def owners (table-key-table target (table-child-type direction table-translation-source-key table-translation-source Key)))
  (def seen (if (some? initial) (some-value initial) (.@ owners .empty)))
  ;; Owner identity follows SOURCE lookup equality, independently of the target's
  ;; collision domain. Reuse its declared Unit key space, never payload equality.
  (def keys (table-key-table source Unit))
  (def key-sources (table-sources keys))
  (def key-versions (map object-revision key-sources))
  ;; Both stored keys are admitted already. The existing empty/point protocol
  ;; builds a private probe without public constructor admission or source scans.
  ;; Protect the actual membership read and reject changed registry metadata.
  (def (same-owner? previous incoming)
    (with-table-sources key-sources (lambda ()
      (unless (equal? key-versions (map object-revision key-sources))
        (error "stale table key registry"))
      (or (eq? previous incoming)
        (.call keys .key? (.call keys .acons previous (void) (.@ keys .empty)) incoming)))))
  ;; Register before testing the inverse, so a lossy key map reports collision.
  (def (key input)
    (translate-table-value (table-child-type direction table-translation-source-key table-translation-source Key) (table-child-type direction table-translation-target-key table-translation-target Key)
      (table-translation-key direction) (table-translation-unkey direction) input
      (lambda (output)
        (def previous (.call owners .ref/opt seen output))
        (when (and (some? previous) (not (same-owner? (some-value previous) input)))
          (raise (make-table-isomorphism-failure 'collision output)))
        (set! seen (.call owners .acons output input seen)))))
  ;; Rebuild privately with existing folds/insertion; retained Function leaves
  ;; remain the same admitted procedures in the converter's returned structures.
  (def (table input)
    (require-table source input)
    (require-table target
      (.call target .<-list
        (with-list-builder (emit)
          (.call source .for-each (lambda (k v)
            (let* ((mapped-key (key k))
                   (mapped-value (translate-table-value
                     (table-child-type direction table-translation-source-value table-translation-source Value)
                     (table-child-type direction table-translation-target-value table-translation-target Value)
                     (table-translation-value direction) (table-translation-unvalue direction) v)))
              (emit (cons mapped-key mapped-value)))) input)))))
  (values key table owners (lambda () seen)))

;; Discover child/origin sources under parent/converter protection, then admit
;; all four endpoints before binding callbacks under the complete source scope.
;; Both public transport and fold derivation reuse this preparation; a computed
;; getter cannot revise an earlier participant and certify the new revision stamp.
(def (call-with-table-translations source target key value extra action)
  (with-table-sources (append (list source target key value) extra)
    (lambda ()
      (def sources (delete-duplicates/hash
        (append (table-sources source) (table-sources target) (list key value) extra)
        table: (make-hash-table-eq) from-end?: #t))
      (with-table-sources sources
        (lambda ()
          (unless (and (eq? (.@ key Domain) (.@ source Key))
                       (eq? (.@ key Codomain) (.@ target Key))
                       (eq? (.@ value Domain) (.@ source Value))
                       (eq? (.@ value Codomain) (.@ target Value)))
            (error "incompatible table isomorphism types"))
          ;; Keep endpoint refusal ahead of callback getters; internal definitions
          ;; must not hoist those getters above the compatibility boundary.
          (let ((ka (.@ key .ap)) (ku (.@ key .unap))
                (va (.@ value .ap)) (vu (.@ value .unap)))
            (using ((ka :~ procedure?) (ku :~ procedure?) (va :~ procedure?) (vu :~ procedure?))
              (def sk (.@ source Key)) (def tk (.@ target Key))
              (def sv (.@ source Value)) (def tv (.@ target Value))
              (def forward (make-table-translation source target sk tk sv tv ka ku va vu))
              (def backward (make-table-translation target source tk sk tv sv ku ka vu va))
              (action sources forward backward))))))))

;; Derive a complete persistent table protocol from an existing backend and
;; explicit carrier/key/value isomorphisms. Target supplies shape and child Types,
;; never a second implementation of insertion, balancing, lookup or traversal.
(def (table-wrapper source representation key value)
  (unless (eq? (.@ representation Domain) source)
    (error "incompatible table representation domain"))
  (def target (.@ representation Codomain))
  (call-with-table-translations source target key value (list representation)
    (lambda (sources forward backward)
      (when (.has? source Comparer .seek<-)
        (set! sources (append sources (list (.@ source Comparer)) (.@ (.@ source Comparer) .sources))))
      (set! sources (delete-duplicates/hash sources table: (make-hash-table-eq) from-end?: #t))
      (def admit-source (table-shape-checker source))
      (def versions (map object-revision sources))
      (def wrap (.@ representation .ap)) (def unwrap (.@ representation .unap))
      (def result #f)
      (def protected sources)
      ;; Hold captured sources and the public derived receiver through callbacks.
      ;; Supported source revisions refuse; no old protocol is silently refreshed.
      (def (guard action)
        (with-table-sources protected action sources versions "stale table wrapper"))
      ;; Carrier admission checks shape only. Children are checked at the public
      ;; table boundary; point operations must not enumerate unrelated bindings.
      (def (shape input)
        (unless (element? target input) (raise-type-error target input 'table-wrapper)) input)
      ;; Check encountered carrier inverses without rebuilding or normalizing leaves.
      ;; Share one pure conversion result within this check, never across calls.
      ;; Equality and user conversion costs remain explicit, not constant-time laws.
      (def (encode input (updated? #f))
        ;; Only successful typed point updates may reuse the backend's existing
        ;; persistent-shape law. Other backends still take normal admission.
        ;; Observed execution retains the real validator demand/refusal for
        ;; fresh roots; the law is not a replacement for read authority.
        (when (and updated? (not (%slot-read-active?))) (admit-source input #t))
        (admit-source input)
        (check-table-carrier input wrap unwrap shape))
      ;; Foreign shape precedes unwrap; source admission precedes wrap. The shared
      ;; roundtrip kernel retains left-before-right failure and callback demand.
      (def (decode input)
        (shape input)
        (check-table-carrier input unwrap wrap admit-source))
      ;; Reuse typed inverse/law checks for both key and value directions.
      (def (translate direction key? input)
        (def domain (if key? (table-child-type direction table-translation-source-key table-translation-source Key) (table-child-type direction table-translation-source-value table-translation-source Value)))
        (unless (element? domain input) (raise-type-error domain input 'table-wrapper))
        (translate-table-value domain
          (if key? (table-child-type direction table-translation-target-key table-translation-target Key) (table-child-type direction table-translation-target-value table-translation-target Value))
          (if key? (table-translation-key direction) (table-translation-value direction))
          (if key? (table-translation-unkey direction) (table-translation-unvalue direction)) input))
      ;; Standard Wrap supplies wrap/bind/map and IO; checked conversions retain
      ;; source ownership. Complete table operations share the same outer guard.
      (def checked (.cc Wrapper. Domain: source Codomain: target
        .ap: (lambda (input) (guard (cut encode input)))
        .unap: (lambda (input) (guard (cut decode input)))))
      ;; One higher-order traversal factory preserves the source's two fold orders.
      ;; Reversing keys does not independently reverse or sort the traversal.
      (def (fold method)
        (lambda (f seed input)
          (guard (lambda ()
            (method
              (lambda (k v acc) (f (translate forward #t k) (translate forward #f v) acc))
              seed (decode input))))))
      ;; Snapshot Option shells before typed translation; Function payloads retain
      ;; identity. Both unary and binary binding callbacks use this one boundary.
      (def (binding-result optional? response)
        (map/option (cut translate backward #f <>)
          (require-table-option (.@ result Value)
            (if optional? (map/option identity response) (some response)))))
      ;; Conjugate binding callbacks, not point writes: the source bulk operation
      ;; owns final-state index preparation. Caller-visible keys/values retain
      ;; their declared representation; failed translation exposes no target root.
      (def (binding-map optional? transform input)
        (using (transform :~ procedure?)
          (guard (lambda ()
            (def before (decode input))
            (def after (.call source .filter-map/2 (lambda (k v)
              (def response (transform (translate forward #t k) (translate forward #f v)))
              (binding-result optional? response)) before))
            (if (eq? before after) input (encode after #t))))))
      ;; Conjugate both snapshots into the source merge, preserving its complete
      ;; final-state index installation rather than replaying target point writes.
      (def (binding-merge choose left right)
        (using (choose :~ procedure?)
          (guard (lambda ()
            (def before (decode left))
            (def after (.call source .merge (lambda (k a b)
              (binding-result #t (choose (translate forward #t k)
                (map/option (cut translate forward #f <>) a)
                (map/option (cut translate forward #f <>) b)))) before (decode right)))
            (if (eq? before after) left (encode after #t))))))
      ;; Retain public-key old-value checks and per-entry conversion order while
      ;; delegating one whole source installation. The typed overlay stores both
      ;; views, so expected source values are read/reused, never re-converted.
      (def (install input delta)
        (unless (table-delta? delta) (error "table delta required"))
        (with-table-sources (append protected (table-delta-sources delta)) (lambda ()
          ;; Preserve delta refusal before view freshness/shape diagnostics.
          (require-table-delta result delta)
          (guard (lambda ()
          (def before (decode input))
          (def change-type (.cc Type. .element?: table-change?))
          (def overlay (table-key-table result (Pair change-type change-type)))
          (def pending (.@ overlay .empty))
          (def changes (with-list-builder (emit)
            (for-each (lambda (change)
              (def k (table-change-key change))
              (def mapped-key (translate backward #t k))
              (def prior (.call overlay .ref/opt pending k))
              ;; Prefix edits already own their Options. Capture only a borrowed
              ;; backend response before old-value checks or replacement conversion.
              (def source-before (if (some? prior)
                (table-change-after (cdr (some-value prior)))
                (map/option identity (.call source .ref/opt before mapped-key))))
              (def target-before (if (some? prior)
                (table-change-after (car (some-value prior)))
                (map/option (cut translate forward #f <>) source-before)))
              (unless (table-option=? (table-change-before change) target-before)
                (raise (make-table-conflict k)))
              (let (mapped (make-table-change mapped-key source-before
                    (map/option (cut translate backward #f <>) (table-change-after change))))
                (set! pending (.call overlay .acons k (cons change mapped) pending))
                (emit mapped))) (table-delta-changes delta))))
          (def dependencies (delete-duplicates/hash (append protected (table-delta-sources delta))
            table: (make-hash-table-eq) from-end?: #t))
          (def after (try (.call source .apply-delta before
            (make-table-delta (.@ source Key) (.@ source Value) dependencies
              (map object-revision dependencies) changes))
            (catch (table-conflict? cause)
              (raise (make-table-conflict (translate forward #t (table-conflict-key cause)))))))
          (encode after #t))))))
      ;; Transfer only an explicit backend seek/order capability. The transported
      ;; comparer is shared by identity; callers must not guess numeric target order.
      ;; Capture both child arguments before invoking either converter. The
      ;; source may reuse a Pair shell and key conversion may rewrite that shell;
      ;; value conversion must still receive its original opaque leaf.
      (def (translate-entry direction key value)
        (let* ((k (translate direction #t key)) (v (translate direction #f value)))
          (cons k v)))
      (def ordering (if (.has? source Comparer .seek<-)
        (let (comparer (table-comparer-wrapper (.@ source Comparer) key))
          (.cc Type. Comparer: comparer
            .seek<-: (lambda (input lower inclusive?)
              ;; Own the bound before carrier/inverse callbacks can rewrite it.
              (set! lower (map/option identity lower))
              (guard (lambda ()
                (iterator-map (lambda (entry)
                  (translate-entry forward (car entry) (cdr entry)))
                  (.call source .seek<- (decode input)
                    (map/option (cut translate backward #t <>) lower) inclusive?) guard)))))) Type.))
      (using ((wrap :~ procedure?) (unwrap :~ procedure?))
        (set! result
          (.o (:: @ (.mix methods.table (.cc Wrap. T: source Wrapper: checked .wrap?: (lambda (input) (element? target input))) ordering))
            Key: (.@ target Key) Value: (.@ target Value)
            .sources: sources
            ;; Preserve key equivalence through the existing key Wrapper, using an
            ;; identity carrier and payload map rather than the original row layout.
            .key-table: (lambda (value) (guard (lambda ()
              (def backend (table-key-table source value))
              (def view (.cc Type. Key: (.@ target Key) Value: value
                .element?: (lambda (root) (try (.call backend .validate-shape root) #t
                  (catch (TypeError? _) #f)))))
              (table-wrapper backend
                (.cc Wrapper. Domain: backend Codomain: view .ap: identity .unap: identity)
                key (.cc Wrapper. Domain: value Codomain: value .ap: identity .unap: identity)))))
            ;; Build through the source's complete constructor, not repeated
            ;; checked point updates that could reject valid intermediate roots.
            .<-list/key: (lambda (bindings) (guard (lambda ()
              (encode (.call source .<-list (map (lambda (entry)
                (translate-entry backward (car entry) (cdr entry))) bindings))))))
            ;; Translate one entry and retain the source's own singleton/refusal policy.
            .singleton/key: (lambda (key value) (guard (lambda ()
              (encode (.call source .singleton (translate backward #t key)
                (translate backward #f value))))))
            ;; Delegate FUN operations while protecting the complete user callback.
            .bind/wrap: (lambda (input f) (guard (lambda () (.call checked .bind input f))))
            .map/wrap: (lambda (f input) (guard (lambda () (.call checked .map f input))))
            .validate-shape: (lambda (input) (guard (lambda () (decode input) input)))
            .apply-delta: install
            ;; Derive metadata without demanding a possibly forbidden empty root.
            ;; An explicit request retains the same guarded constructor/admission.
            (.empty (guard (lambda () (encode (require-table source (.@ source .empty))))))
            .empty/key?: (lambda (input) (guard (lambda () (table-empty-key? source (decode input)))))
            .ref: (lambda (input k (missing (lambda () (error "missing key"))))
              (guard (lambda ()
                (def found (.call source .ref/opt (decode input) (translate backward #t k)))
                (if (some? found) (translate forward #f (some-value found)) (missing)))))
            .acons: (lambda (k v input)
              (guard (lambda ()
                (encode (.call source .acons (translate backward #t k)
                  (translate backward #f v) (decode input)) #t))))
            .remove: (lambda (input k)
              (guard (lambda () (encode (.call source .remove (decode input) (translate backward #t k)) #t))))
            ;; Transfer selection as one source operation, preserving final-state
            ;; index installation and source sharing through explicit encodings.
            .filter/key: (lambda (predicate input)
              (guard (lambda () (encode (.call source .filter
                (lambda (k v) (predicate (translate forward #t k) (translate forward #f v)))
                (decode input)) #t))))
            .partition/key: (lambda (predicate input)
              (guard (lambda ()
                (defvalues (yes no) (.call source .partition
                  (lambda (k v) (predicate (translate forward #t k) (translate forward #f v)))
                  (decode input)))
                (def left (encode yes #t)) (def right (encode no #t))
                (values left right))))
            ;; Transfer the standard source iterator; translate only pulled rows.
            ;; Guard before every pull, including repeated EOF, without holding
            ;; metadata protection across suspension in the caller.
            .iter<-: (lambda (input) (guard (lambda ()
              (iterator-map (lambda (entry)
                (translate-entry forward (car entry) (cdr entry)))
                (.call source .iter<- (decode input)) guard))))
            .merge: binding-merge
            .map/2: (cut binding-map #f <> <>)
            .filter-map/2: (cut binding-map #t <> <>)
            .foldl: (fold (.@ source .foldl)) .foldr: (fold (.@ source .foldr))))
        ;; Publish the complete receiver scope once after private construction.
        (set! protected (cons result sources))
        result))))

;; Lift explicit typed Key/Value Wrappers to collection and delta Wrappers.
;; Captured revisions and first-conflict behavior remain owned by this protocol.
(def (table-isomorphism source target key value)
  (call-with-table-translations source target key value []
    (lambda (sources forward backward)
      (def versions (map object-revision sources))
      ;; Own guards across the whole conversion, including delta origin metadata.
      (def (guard dependencies action)
        (with-table-sources dependencies action sources versions "stale table isomorphism"))
      ;; Collection-only conversion has no retained global memo or registry.
      (def (convert direction input)
        (guard sources
          (lambda ()
            (defvalues (_ table _owners _seen) (table-translators direction))
            (table input))))
      ;; The Pair carries admitted base . delta. Install in source first, then
      ;; translate both snapshots through ONE registry, retaining edit order.
      ;; Translate admitted optional payloads directly, retaining intermediate edits.
      (def (changes direction input)
        (unless (and (pair? input) (table-delta? (cdr input)))
          (error "table isomorphism Delta requires base and delta"))
        (def delta (cdr input))
        (def dependencies (delete-duplicates/hash (append sources (table-delta-sources delta))
          table: (make-hash-table-eq) from-end?: #t))
        (guard dependencies
          (lambda ()
            (def from (table-translation-source direction))
            (def to (table-translation-target direction))
            (def after (.call from .apply-delta (car input) delta))
            (defvalues (key table _owners _seen) (table-translators direction))
            (def before* (table (car input)))
            ;; Admit both endpoint domains through the same collision registry.
            ;; Intermediate edits are translated below, never collapsed to endpoints.
            (table after)
            (def (option-value input)
              (map/option (lambda (v)
                (translate-table-value (table-child-type direction table-translation-source-value table-translation-source Value) (table-child-type direction table-translation-target-value table-translation-target Value)
                  (table-translation-value direction) (table-translation-unvalue direction) v)) input))
            (cons before*
              (make-table-delta (.@ to Key) (.@ to Value) dependencies (map object-revision dependencies)
                (map (lambda (change)
                  (def k (key (table-change-key change)))
                  (make-table-change k (option-value (table-change-before change))
                                       (option-value (table-change-after change))))
                  (table-delta-changes delta)))))))
      (.cc Wrapper. Domain: source Codomain: target
        .ap: (cut convert forward <>) .unap: (cut convert backward <>)
        Delta: (.cc Wrapper. .ap: (cut changes forward <>) .unap: (cut changes backward <>))))))
