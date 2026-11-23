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
(def with-table-sources
  (case-lambda
    ;; Keep the ordinary protection path free of revision-check closures.
    ((sources action)
      (for-each instantiate-object! sources)
      (def active (active-object-constructions))
      (if (eq? sources active) (action)
        (parameterize ((active-object-constructions (if (null? active) sources (append sources active))))
          (action))))
    ;; Captured revision families share one check under the exact same protected
    ;; scope. Check only after instantiation; retain each caller's original cause.
    ((sources action watched versions failure)
      (for-each instantiate-object! sources)
      (def active (active-object-constructions))
      (if (eq? sources active)
        (begin
          (unless (equal? versions (map object-revision watched)) (error failure))
          (action))
        (parameterize ((active-object-constructions (if (null? active) sources (append sources active))))
          (unless (equal? versions (map object-revision watched)) (error failure))
          (action))))))

;; Recognition does not normalize again: callers admit snapshots through validate
;; or checked-action first, and deltas retain those exact normalized child values.
(def (require-table descriptor source)
  (unless (element? descriptor source) (raise-type-error descriptor source))
  source)

;; Close an operation's metadata scope over explicitly derived table origins.
;; Raw target shape Types have no extra origins; ordinary tables inherit [].
(def (table-sources descriptor)
  (def origins (if (.has? descriptor .sources) (.@ descriptor .sources) []))
  (using (origins :~ list?)
    ;; Own the declaration before later getters can reuse the caller's spine.
    (def captured (map identity origins))
    (with-table-sources (cons descriptor captured) (lambda ()
      (append (list descriptor (.@ descriptor Key) (.@ descriptor Value)) captured)))))

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
            (lambda (key old next)
              ;; Own BOTH producer shells before child recognition or another emit.
              (def prior (map/option identity old))
              (def following (map/option identity next))
              (require-table-key descriptor key)
              (require-table-option (.@ descriptor Value) prior)
              (require-table-option (.@ descriptor Value) following)
              (emit (make-table-change key prior following))) before after))))))

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
      (def old (map/option identity (.call descriptor .ref/opt before key)))
      ;; Option boxes are callback-owned; copy their shells, retaining exact leaves.
      ;; Mutating an argument/result box cannot rewrite a captured expectation.
      (def after (map/option identity (transform (map/option identity old))))
      (require-table-option (.@ descriptor Value) after)
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
    ;; Metadata discovery must not replace already admitted batch requests.
    (set! deltas (map identity deltas))
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
