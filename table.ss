;;; Common declarations and methods for tables

(export methods.table Set<-Table. PreZipping. Zipping. FocusableZipping.
        with-set-tables iterator-map table-element? validate-table table-for-each-change table-styles set-styles table-indexes
        table-comparer table-comparer-wrapper table-order
        table-key-space table-index-conflict? table-index-conflict-name table-index-conflict-key
        table-index-conflict-existing table-index-conflict-incoming
        table-delta? table-delta-count invert-table-delta table-isomorphism table-fold table-group-fold table-projection table-group-join table-lookup-join set-image set-combination table-combination table-wrapper
        table-projection-compose
        table-isomorphism-failure? table-isomorphism-failure-kind table-isomorphism-failure-value
        table-conflict? table-conflict-key)

(import
  (only-in ./variant-validation validate-bindings)
  (only-in ./slot-observation %slot-read-active?)
  (only-in :gerbil/runtime/thread with-lock)
  :std/interface
  :std/iter
  (only-in :std/list/list-builder with-list-builder)
  (only-in :std/list/list delete-duplicates/hash append-map find)
  (only-in :std/list/alist acons)
  (only-in :std/func compose)
  (only-in :std/number/misc uint?)
  (only-in ./support/option some some? option-ref option-get/default map/option some-value)
  (only-in ./brace @method @@method)
  (only-in ./io marshal)
  (only-in ./mop define-type Type. Function. Any validate element? raise-type-error TypeError? lens-of-get-set)
  (only-in ./fun Wrapper. Wrap.)
  (only-in ./function-signature signature-shape?)
  (only-in ./object .o object<-alist .all-slots .@ .ref .slot? .call .cc .mix .has? object-revision active-object-constructions instantiate-object!)
  (only-in ./type List Pair Sum Unit Bool))

(defstruct %mapped-iterator (source transform guard) final: #t)
;; Pull through the standard Iterator exactly once; preserve EOF without mapping it.
(def (%mapped-next source transform)
  (using (source :- Iterator)
    (def value (source.next!))
    (if (eq? value #!eof) #!eof (transform value))))
(implement Iterator %mapped-iterator
  (next! (lambda (self)
    (if self.guard (self.guard (lambda () (%mapped-next self.source self.transform)))
      (%mapped-next self.source self.transform)))))

;; Optional guards cover the complete pull, even EOF. Ordinary iterator mapping
;; keeps its original unguarded path and allocates no per-pull guard thunk.
(def (iterator-map transform source (guard #f))
  (Iterator (%mapped-iterator (iter source) transform guard)))

;; Persistent seek backends admit roots by identity. Point-update outputs may be
;; recorded only under the explicit .shape-preserving? law, after an admitted input
;; and Key. Weak keys retain no snapshots; failures and arbitrary inputs never gain
;; provenance. Callers guard metadata before either admission or output recording.
(def (table-shape-checker source)
  (if (.has? source Comparer .seek<-)
    (let ((admitted (make-table test: eq? weak-keys: #t))
          (preserves? (and (.has? source .shape-preserving?) (eq? (.@ source .shape-preserving?) #t))))
      (lambda (root (updated? #f))
        (cond
          (updated? (when preserves? (table-set! admitted root #t)))
          ((not (table-ref admitted root #f))
            (.call source .validate-shape root)
            (table-set! admitted root #t))) root))
    (lambda (root (updated? #f)) (if updated? root (.call source .validate-shape root)))))

;; Recognize carrier and child membership without constructing normalized wrappers.
;; Catch only typed refusal; user/backend exceptions preserve their original cause.
(def (table-element? descriptor source)
  (try
    (.call descriptor .validate-shape source)
    ;; Recognition must not reenter the public query's complete-root admission.
    (not (table-entry-match descriptor
      (lambda (key value)
        (and (element? (.@ descriptor Key) key) (element? (.@ descriptor Value) value))) source #f #f))
    (catch (TypeError? _) #f)))

;; Validate a persistent table through its current public representation protocol.
;; Admit the carrier, normalize children, then privately rebuild and recognize the result.
(def (validate-table descriptor source)
  (.call descriptor .validate-shape source)
  ;; Post-recognition checks the normalized result without wrapping children again.
  (def checked (validate-bindings descriptor (.@ descriptor Key) (.@ descriptor Value) source
    (.call descriptor .list<- source) (lambda () (.@ descriptor .empty))
    (.@ descriptor .key?) (.@ descriptor .acons)))
  (unless (element? descriptor checked) (raise-type-error descriptor checked))
  checked)

;; Changes retain admitted values, including Function wrappers. Missing is #f;
;; a stored false is (some #f). Neither constructors nor mutable edit lists escape.
(defstruct table-change (key before after) final: #t)
;; Bind a finite delta to its source protocol and child descriptor revisions.
(defstruct table-delta (key value sources versions changes) final: #t)
;; A conflict reports the first changed key whose expected old value disagrees.
(defstruct table-conflict (key) final: #t)

;; Match the existing .update/opt equality: structural data and opaque procedure
;; identities, without requiring every type to implement an equality method.
(def (table-option=? left right)
  (if (some? left)
    (and (some? right) (equal? (some-value left) (some-value right)))
    (not (some? right))))

;; Protect supported descriptor writes for the whole operation, including user
;; recognizers/backend callbacks. Mutable leaf data remains a caller premise.
(def (with-table-sources sources action)
  ;; Keep every instantiation check, including recursive-construction refusal.
  ;; Reuse exact list identity or an empty outer scope; do not scan membership
  ;; on hot calls. Partial overlaps retain the original complete protection.
  (for-each instantiate-object! sources)
  (def active (active-object-constructions))
  (if (eq? sources active) (action)
    (parameterize ((active-object-constructions (if (null? active) sources (append sources active))))
      (action))))

;; Recognition does not normalize again: callers admit snapshots through validate
;; or checked-action first, and deltas retain those exact normalized child values.
(def (require-table descriptor source)
  (unless (element? descriptor source) (raise-type-error descriptor source))
  source)

;; Close an operation's metadata scope over explicitly derived table origins.
;; Raw target shape Types have no extra origins; ordinary tables inherit [].
(def (table-sources descriptor)
  (append (list descriptor (.@ descriptor Key) (.@ descriptor Value))
    (if (.has? descriptor .sources) (.@ descriptor .sources) [])))

;; The generic ordered change stream visits old updates/deletions first, then
;; new insertions. Payloads are admitted already and are never normalized here.
;; Backends may override this traversal, preserving exact order and Option values.
(def (table-for-each-change descriptor emit before after)
  (.call descriptor .for-each
    (lambda (key value)
      (def next (.call descriptor .ref/opt after key))
      (unless (table-option=? (some value) next) (emit key (some value) next))) before)
  (.call descriptor .for-each
    (lambda (key value)
      (unless (.call descriptor .key? before key) (emit key #f (some value)))) after))

;; Complete admission and origins are independent of change discovery. Even
;; identical/shared roots undergo both checks; empty deltas retain their lineage.
(def (diff-table descriptor before after)
  (def sources (table-sources descriptor))
  (with-table-sources sources
    (lambda ()
      (require-table descriptor before)
      (require-table descriptor after)
      (make-table-delta (.@ descriptor Key) (.@ descriptor Value) sources (map object-revision sources)
        (with-list-builder (emit)
          (.call descriptor .for-each-change
            (lambda (key old next) (emit (make-table-change key old next))) before after))))))

;; Capture a single optional update without constructing a trial table or scanning
;; for differences. Admission is non-normalizing; callback/typed refusal produces
;; no delta, writes no carrier and retains the original cause. No-op deltas still
;; carry every source revision, exactly as ordinary .diff does.
(def (update-table-delta descriptor key transform before)
  (using (transform :~ procedure?)
    (def sources (table-sources descriptor))
    (with-table-sources sources (lambda ()
      (require-table descriptor before)
      (require-table-key descriptor key)
      (def old (.call descriptor .ref/opt before key))
      ;; Option boxes are callback-owned; copy their shells, retaining exact leaves.
      ;; Mutating an argument/result box cannot rewrite a captured expectation.
      (def response (transform (map/option identity old)))
      (require-table-option (.@ descriptor Value) response)
      (def after (map/option identity response))
      (make-table-delta (.@ descriptor Key) (.@ descriptor Value) sources (map object-revision sources)
        (if (table-option=? old after) [] (list (make-table-change key old after))))))))

;; Report edit count without exposing the owned edit list or its constructors.
(def (table-delta-count delta) (length (table-delta-changes delta)))

;; Undo in reverse order, retaining the exact callbacks and descriptor provenance.
;; Stable values and pure backend callbacks are required for reversible observations.
(def (invert-table-delta delta)
  (make-table-delta (table-delta-key delta) (table-delta-value delta)
    (table-delta-sources delta) (table-delta-versions delta)
    (map (lambda (change)
      (make-table-change (table-change-key change) (table-change-after change)
                         (table-change-before change)))
      (reverse (table-delta-changes delta)))))

;; Share descriptor identity and complete origin checks across installation and
;; composition. Empty deltas still carry dependencies and may become stale.
(def (require-table-delta descriptor delta)
  (unless (table-delta? delta) (error "table delta required"))
  (unless (and (equal? (table-delta-versions delta)
                      (map object-revision (table-delta-sources delta)))
               (eq? (.@ descriptor Key) (table-delta-key delta))
               (eq? (.@ descriptor Value) (table-delta-value delta)))
    (error "stale or incompatible table delta")))

;; Compose ordered revisions without enumerating snapshots or invoking projections.
;; Retain intermediate writes: cancelling edits still carry their conflict checks.
;; Installation decides base compatibility atomically; no intermediate result escapes.
(def (compose-table-deltas descriptor deltas)
  (using (deltas :~ list?)
    (for-each (lambda (delta)
      (unless (table-delta? delta) (error "table delta required"))) deltas)
    (def sources (delete-duplicates/hash
      (append (table-sources descriptor)
              (apply append (map table-delta-sources deltas)))
      table: (make-hash-table-eq) from-end?: #t))
    (with-table-sources sources
      (lambda ()
        (for-each (cut require-table-delta descriptor <>) deltas)
        (make-table-delta (.@ descriptor Key) (.@ descriptor Value)
          sources (map object-revision sources)
          (apply append (map table-delta-changes deltas)))))))

;; Portable across persistent carriers with identical Key/Value descriptors.
;; Refuse stale metadata before lookup; stage all writes privately, so a conflict
;; exposes no partial table. Unrelated bindings may be rebased and remain intact.
;; Source is admitted; shape checks retain their cost without repeated wrapping.
(def (apply-table-delta descriptor source delta)
  (unless (table-delta? delta) (error "table delta required"))
  (def sources (table-delta-sources delta))
  (with-table-sources (append (table-sources descriptor) sources)
    (lambda ()
      (require-table-delta descriptor delta)
      (.call descriptor .validate-shape source)
      (foldl
        (lambda (change staged)
          (def key (table-change-key change))
          (unless (table-option=? (table-change-before change)
                    (.call descriptor .ref/opt staged key))
            (raise (make-table-conflict key)))
          (match (table-change-after change)
            (#f (.call descriptor .remove staged key))
            ((some value) (.call descriptor .acons key value staged))))
        source (table-delta-changes delta)))))

(include "table/fold.scm")

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
  ;; Register before testing the inverse, so a lossy key map reports collision.
  (def (key input)
    (translate-table-value (table-child-type direction table-translation-source-key table-translation-source Key) (table-child-type direction table-translation-target-key table-translation-target Key)
      (table-translation-key direction) (table-translation-unkey direction) input
      (lambda (output)
        (def previous (.call owners .ref/opt seen output))
        (when (and (some? previous) (not (equal? input (some-value previous))))
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
        (with-table-sources protected
          (lambda ()
            (unless (equal? versions (map object-revision sources))
              (error "stale table wrapper"))
            (action))))
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
        (let* ((output (shape (wrap input))) (recovered (unwrap output)))
          (unless (equal? recovered input)
            (raise (make-table-isomorphism-failure 'left-inverse input)))
          (unless (equal? (wrap recovered) output)
            (raise (make-table-isomorphism-failure 'right-inverse output))) output))
      ;; Explicit lets retain refusal order: foreign shape precedes unwrap, source
      ;; admission precedes wrap, and a failed left inverse suppresses the right.
      (def (decode input)
        (shape input)
        (let (output (unwrap input))
          (admit-source output)
          (let (encoded (wrap output))
            (unless (equal? encoded input)
              (raise (make-table-isomorphism-failure 'left-inverse input)))
            (unless (equal? (unwrap encoded) output)
              (raise (make-table-isomorphism-failure 'right-inverse output))) output)))
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
              (def source-before (if (some? prior)
                (table-change-after (cdr (some-value prior))) (.call source .ref/opt before mapped-key)))
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
      (def ordering (if (.has? source Comparer .seek<-)
        (let (comparer (table-comparer-wrapper (.@ source Comparer) key))
          (.cc Type. Comparer: comparer
            .seek<-: (lambda (input lower inclusive?)
              (guard (lambda ()
                (iterator-map (lambda (entry)
                  (cons (translate forward #t (car entry)) (translate forward #f (cdr entry))))
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
                (let* ((k (translate backward #t (car entry)))
                       (v (translate backward #f (cdr entry)))) (cons k v))) bindings))))))
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
                (let* ((k (translate forward #t (car entry)))
                       (v (translate forward #f (cdr entry)))) (cons k v)))
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
        (with-table-sources dependencies
          (lambda ()
            (unless (equal? versions (map object-revision sources))
              (error "stale table isomorphism"))
            (action))))
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

;; Select admitted bindings with the backend fold and insertion protocol. The
;; predicate runs once per visited binding, in fold order, and must return Bool.
;; Both branches remain private until complete recognition succeeds; Function
;; keys/values retain identity. Callback effects themselves cannot be rolled back.
;; TODO: have APIs look more like LIL, less like OCaml?
;; Especially since we may (1) use similar metaprogramming for OO style (?), and
;; (2) distinguish between for-each / foldl / foldr (iterating over pairs)
;; vs for-each* / foldl* / afoldr (iterating with two separate arguments for k v)
;; (3) explicit conversion is provided by Wrappers/styles; take/drop reuse selection below.
;; We could also reorder the arguments between object vs typeclass styles,
;; so the object is moved first in OO style, but at whatever "usual" place in the other style.

;; NB: General methods for maps, that are not trie-specific
(define-type (methods.table @ Type.
       .validate-shape ;; carrier-only admission, raises TypeError before enumeration
       Key ;; : Type
       Value ;; : Type
       .empty ;; : @
       .acons ;; : @ <- Key Value @
       .ref ;; : Value <- @ Key ?(Value <-)
       .remove ;; : @ <- @ Key
       .foldl ;; : (Fun o <- (Fun o <- Key Value o) o @)
       .foldr) ;; : (Fun o <- (Fun o <- Key Value o) o @)

  ;; Derived protocols publish their complete explicit origins to deltas and folds.
  .sources: []

  ;; This is an explicit backend capability. Closed families delegate it;
  ;; unknown/custom backends must declare its equality and payload laws.
  .key-table: #f

  ;; Recognition never normalizes children. This keeps nested List/Schema shape
  ;; checks and postconditions from constructing or discarding Function wrappers.
  ;; Typed refusal is false; unexpected user/backend exceptions remain observable.
  .element?: (lambda (source) (table-element? @ source))

  ;; Both Key and Value recursively normalize after complete carrier admission.
  ;; Persistent reconstruction retains every replacement and rejects key collisions.
  .validate: (lambda (source) (validate-table @ source))

  ;; Selection shares the same admitted binding traversal, without normalization.
  .filter: (lambda (predicate input) (car (select-table @ predicate input #f)))
  ;; Two-argument callbacks transform values at the original keys; FUN .map
  ;; remains a whole-root operation on style protocols.
  .map/2: (lambda (transform input) (map-table-bindings @ transform input #f))
  ;; Optional results can remove bindings, but cannot introduce or relabel keys.
  .filter-map/2: (lambda (transform input) (map-table-bindings @ transform input #t))
  ;; Explicit heterogeneous entry maps stage once and never overwrite collisions.
  .map/into: (lambda (target transform input) (map-table-into @ target transform input #f))
  .filter-map/into: (lambda (target transform input) (map-table-into @ target transform input #t))
  ;; Finite prefixes use the existing checked selection algorithm and backend order.
  .take: (lambda (count input) (select-table-prefix @ count input #t))
  .drop: (lambda (count input) (select-table-prefix @ count input #f))
  ;; Partition prepares and recognizes both branches before exposing either root.
  .partition: (lambda (predicate input)
    (def branches (select-table @ predicate input #t))
    (values (car branches) (cdr branches)))

  ;; Explicit order is required; both persistent sides are admitted before return.
  .split: (lambda (key input) (split-table @ key input))

  ;; : (Fun Bool <- @)
  ;; Logical observation never evaluates an unrelated empty constructor.
  .empty?: (cut empty-table? @ <>)

  ;; : (Fun Bool <- @ Key)
  .key?: (lambda (t key) (let/cc ret (.ref t key (lambda _ (ret #f))) #t))

  ;; : (Fun (Option Value) <- @ Key)
  .ref/opt: (lambda (t key) (let/cc ret (some (.ref t key (lambda _ (ret #f))))))

  ;; : Unit <- (Fun Unit <- Key Value) @
  .for-each: (lambda (f t) (.foldl (lambda (k v a) (void (f k v))) (void) t))

  ;; : Unit <- (Fun Unit <- Key Value) @
  .for-each/reverse: (lambda (f t) (.foldr (lambda (k v a) (void (f k v))) (void) t))

  ;; : @ <- Key (Option Value) @
  ;; Absence keeps the old binding but still checks the key, root and origins.
  .acons/opt: (lambda (k ov t) (.update/opt k (table-association-update @ ov) t))

  ;; : @ <- Key Value
  .singleton: (lambda (k v) (construct-table @ (list (cons k v)) #t))

  ;; Merge visits the union domain and validates private callback results before
  ;; one final-state installation; Trie retains its declared paired traversal.
  .merge: (lambda (choose left right) (merge-table-bindings @ choose left right))

  ;; Ordered callbacks let persistent backends skip shared subtrees while keeping
  ;; .diff admission, metadata protection and private delta construction centralized.
  .for-each-change: (lambda (emit before after) (table-for-each-change @ emit before after))

  ;; Finite differences and optimistic persistent installation share this backend.
  .diff: (lambda (before after) (diff-table @ before after))
  ;; Capture one .update/opt request for later batch, transport, fold or installation.
  ;; The callback runs once now; subsequent application never replays it.
  .delta/opt: (lambda (key transform before) (update-table-delta @ key transform before))
  .apply-delta: (lambda (source delta) (apply-table-delta @ source delta))
  ;; Ordered batches retain all origins and first-conflict semantics, including undo.
  .compose-deltas: (lambda (deltas) (compose-table-deltas @ deltas))

  ;; Optional focus is total at missing keys and uses the existing Lens protocol.
  ;; The setter receives value before state, as Lens.modify/compose require.
  .lens/opt: (lambda (key) (table-key-focus @ key #t))

  ;; : Nat <- @
  .count: (lambda (t) (.foldl (lambda (_1 _2 a) (1+ a)) 0 t))

  ;; : Bool <- (Fun Bool <- Key Value) @
  .every: (lambda (pred t) (not (find-table-entry @ pred t #f #f)))

  ;; : Bool <- (Fun Bool <- Key Value) @
  .any: (lambda (pred t) (and (find-table-entry @ pred t #f #t) #t))

  ;; : (List (Pair Key Value)) <- @
  .list<-: (lambda (t) (.foldr acons [] t))

  ;; : @ <- (List (Pair Key Value))
  .<-list: (lambda (rows) (construct-table @ rows #f))

  ;; Default persistent backend construction retains its original first-write
  ;; precedence. Specialized bulk builders declare their own existing policy.
  .<-list/key: (lambda (rows) (foldr (lambda (row root)
    (.acons (car row) (cdr row) root)) .empty rows))

  ;; Complete admission precedes the first forward/reverse binding observation.
  ;; The existing short-circuit query preserves leaves and declared backend order.
  ;; : (Option (Pair Key Value)) <- @
  .min-binding/opt: (cut find-table-entry @ true <> #f #t)

  ;; : (Option (Pair Key Value)) <- @
  .max-binding/opt: (cut find-table-entry @ true <> #t #t)

  ;; : (Pair Key Value) <- @
  .min-binding: (lambda (t) (option-ref (.min-binding/opt t)))

  ;; : (Pair Key Value) <- @
  .max-binding: (lambda (t) (option-ref (.max-binding/opt t)))

  ;; : (Option (Pair Key Value)) <- @
  .choose/opt: .min-binding/opt

  ;; : (Pair Key Value) <- @
  .choose: .min-binding

  ;; Extract the backend's chosen binding and an admitted persistent remainder.
  ;; Optional extraction returns Option Pair; required extraction refuses empty.
  .decons/opt: (lambda (input) (decons-table @ input #f))
  .decons: (lambda (input) (decons-table @ input #t))

  ;; First match in declared forward traversal; no monotonicity is inferred.
  ;; : (Option (Pair Key Value)) <- (Fun Bool <- Key Value) @
  .find-first/opt:
  (lambda (p t) (find-table-entry @ p t #f #t))

  ;; First match in declared reverse traversal, including nonmonotone predicates.
  ;; : (Option (Pair Key Value)) <- (Fun Bool <- Key Value) @
  .find-last/opt:
  (lambda (p t) (find-table-entry @ p t #t #t))

  ;; : (Pair Key Value) <- (Fun Bool <- Key Value) @
  .find-first: (lambda (p t) (option-ref (.find-first/opt p t)))

  ;; : (Pair Key Value) <- (Fun Bool <- Key Value) @
  .find-last: (lambda (p t) (option-ref (.find-last/opt p t)))

  ;; : @ <- Key (Fun (Option Value) <- (Option Value)) @
  .update/opt: (lambda (key transform input) (update-table-focus @ key transform input))

  ;; : @ <- Key (Fun Value <- Value) @ ?(Fun Value <-)
  .update: (lambda (k f t (default false))
             (.update/opt k (lambda (vo) (some (f (option-get/default vo default)))) t))
  ;; NB: For a handful of flat datastructures that don't have deep traversals, this could be better:
  ;;.update: (lambda (k f t (default false)) (.acons k (f (.ref t k (lambda _ (default)))) t))

  ;; : @ <- (Fun (Option Value) <- Key Value Value) @ @
  .union:
  (lambda (f a b)
    (using (f :~ procedure?)
      (.merge (lambda (key left right)
        (if (and left right) (f key (some-value left) (some-value right)) (or left right))) a b)))

  ;; Left-biased join retains false payloads because presence is an Option shell.
  .join: (lambda (a b) (.merge (lambda (_ left right) (or left right)) a b))

  ;; Retain foldl's existing later-source priority. Nonempty batches start at
  ;; their first admitted root, never an invented empty
  ;; seed that could violate a custom refinement. Empty batches admit .empty.
  .join/list: (lambda (roots)
    (using (roots :~ list?)
      (with-table-sources (table-sources @) (lambda ()
        (for-each (cut require-table @ <>) roots)
        (if (null? roots) (require-table @ .empty) (foldl .join (car roots) (cdr roots)))))))

  ;; Equality observes admitted roots instead of constructing a throwaway merged
  ;; empty root, which may be forbidden by the table's own refinement.
  .=?: (lambda (a b) (equal-table-bindings? @ a b))

  ;; Explicit order and value comparison supply nonconstructive map comparison.
  .compare: (lambda (compare left right) (compare-table-bindings @ compare left right))

  ;; Complete optional nonempty parts share one checked division boundary.
  ;; : (OrFalse @) (OrFalse @) <- @
  .divide: (lambda (input) (table-division-values (divide-table @ input)))

  ;; Empty and singleton roots require no invented empty result or point writes.
  ;; : (List @) <- @
  .divide/list: (cut divide-table @ <>)

  ;; : @ <- (Iterator (Pair Key Value)) ?@
  .<-iter: (case-lambda
    ((sequence) (table-from-iter @ sequence []))
    ((sequence seed) (table-from-iter @ sequence (list seed))))

  ;; : (Iterator (Pair Key Value)) <- @
  .iter<-: (lambda (x) (iter (.list<- x)))

  ;; : (Lens Value <- @) <- Key
  .lens: (lambda (key) (table-key-focus @ key #f))

  .Binding: (Pair Key Value)
  .Bindings: (List .Binding)
  ;; All formats share complete admission; the List/Pair codecs remain authoritative.
  .json<-: (cut collection-codec @ #f '.json<- <>) ;; : Json <- @
  .<-json: (cut collection-codec @ #f '.<-json <>) ;; : @ <- Json
  .bytes<-: (cut collection-codec @ #f '.bytes<- <>) ;; : Bytes <- @
  .<-bytes: (cut collection-codec @ #f '.<-bytes <>) ;; : @ <- Bytes
  .marshal: (cut collection-codec @ #f '.marshal <> <>)
  .unmarshal: (cut collection-codec @ #f '.unmarshal <>))

;; Set presentation and algebra remain in the existing table module.
(include "table/sets.scm")
(include "table/io.scm")

(define-type (PreZipping. @ [Type.]
  ;; StepF :: Type <- Type
  ;; PathF :: Type <- Type
  .path-step ;; (OrFalse (Pair (StepF a) (PathF a))) <- (PathF a)
  .step-down)) ;; (PathF a) <- (StepF a) (PathF a)

(define-type (Zipping. @ [PreZipping.]
  ;; Zipper = (Pair Node (PathF Node))
  .zipper<- ;; Zipper <- T
  .<-top-zipper ;; T <- Zipper
  .stepUp)) ;; node <- (StepF Node) Node

(define-type (FocusableZipping. @ [Zipping.]
  .refocus)) ;; Zipper <- FocusKey Zipper

(include "table/focus.scm")
(include "table/mapping.scm")

;; Derive style ownership in the existing interface; .admit normalizes raw input,
;; whereas .ap and transitions retain admitted Function wrappers and batch ordering.
(include "table/styles.scm")

;; Correlated indexes share the same public table namespace and backend contracts.
(include "table/indexes.scm")

(include "table/order.scm")
