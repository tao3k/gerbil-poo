;;; Checked key-preserving maps reuse persistent folds and declared Trie traversal.

;; Visit the original snapshot once in backend order. Optional callbacks return
;; #f or (some value); required callbacks return Value, including stored false.
;; Only admitted leaves are accepted, never normalized or silently coerced.
(def (map-table-bindings descriptor transform input optional?)
  (using (transform :~ procedure?)
    (def sources (table-sources descriptor))
    (with-table-sources sources (lambda ()
      (require-table descriptor input)
      (def changed? #f)
      ;; Snapshot the callback-owned Option shell before recognizing its payload.
      ;; A later callback may reuse/mutate that shell without rewriting prior rows.
      (def (project key value)
        (def response (transform key value))
        (def next (require-table-option (.@ descriptor Value)
          (if optional? (map/option identity response) (some response))))
        (unless (table-option=? (some value) next) (set! changed? #t))
        next)
      ;; The declared specialized traversal retains its original left-to-right
      ;; callbacks. Otherwise capture changed bindings through the standard list
      ;; builder, then let the existing batch installer prepare ALL correlated
      ;; indexes against the final primary root (including unique-value swaps).
      (def result (if (.has? descriptor .map/key/opt)
        (.call descriptor .map/key/opt project input)
        (let (changes (with-list-builder (emit)
          (.call descriptor .for-each (lambda (key value)
            (def next (project key value))
            (unless (table-option=? (some value) next)
              (emit (make-table-change key (some value) next)))) input)))
          (if (null? changes) input
            (.call descriptor .apply-delta input
              (make-table-delta (.@ descriptor Key) (.@ descriptor Value)
                sources (map object-revision sources) changes))))))
      ;; No-op identity does not mean zero work: a specialized backend may already
      ;; have built temporary nodes. Complete custom recognition still runs.
      (require-table descriptor (if changed? result input))))))

;; Capture caller-owned shells before child predicates run; checked Function leaves
;; retain identity. Required and optional projections share this admission boundary.
(def (require-table-entry binding response)
  (require-table-option binding
    (map/option (lambda (row) (if (pair? row) (cons (car row) (cdr row)) row)) response)))

;; Reserve a target logical key using its declared backend equality. Every old
;; affected owner is removed before warm reservations, permitting final-state swaps.
(def (claim-table-entry owners seen row key)
  (def previous (.call owners .ref/opt seen (car row)))
  (when (some? previous)
    (raise (make-table-index-conflict 'primary (car row) (some-value previous) key)))
  (.call owners .acons (car row) key seen))

;; Explicit entry projection can change both child Types without claiming an
;; inverse. One shared boundary admits input, Option/Pair responses and the final
;; target. The target's key registry, not host equal?, decides collisions.
(def (map-table-into source target transform input optional?)
  (using (transform :~ procedure?)
    (with-table-sources (list source target) (lambda ()
      (with-table-sources (append (table-sources source) (table-sources target)) (lambda ()
        (require-table source input)
        (def owners (table-key-table target (.@ source Key)))
        (with-table-sources (table-sources owners) (lambda ()
          (def seen (.@ owners .empty))
          (def binding (Pair (.@ target Key) (.@ target Value)))
          (def rows (with-list-builder (emit)
            (.call source .for-each (lambda (key value)
              (def response (transform key value))
              ;; Copy callback-owned shells BEFORE child recognition. A child
              ;; predicate may mutate the original response, never this decision.
              (def next (require-table-entry binding (if optional? response (some response))))
              (when (some? next)
                (let (output (some-value next))
                  (set! seen (claim-table-entry owners seen output key))
                  (emit output)))) input)))
          ;; Construct only the complete target. Empty and partial target roots
          ;; need not satisfy a business refinement or final unique index family.
          (require-table target (.call target .<-list rows))))))))))

;; Merge both original snapshots, never newly staged bindings. Callback options
;; are fresh shells; neither mutating an input Option nor reusing an output shell
;; may rewrite another decision or an optimistic old-value expectation.
(def (merge-table-bindings descriptor choose left right)
  (using (choose :~ procedure?)
    (def sources (table-sources descriptor))
    (with-table-sources sources (lambda ()
      (require-table descriptor left)
      (require-table descriptor right)
      ;; Backend callbacks must describe actual admitted keys and optional values.
      ;; The specialized traversal's visitation order remains its own contract.
      (def (project key a b)
        (require-table-key descriptor key)
        (require-table-option (.@ descriptor Value) a)
        (require-table-option (.@ descriptor Value) b)
        (require-table-option (.@ descriptor Value)
          (map/option identity (choose key (map/option identity a) (map/option identity b)))))
      (def result (if (.has? descriptor .merge/key/opt)
        (.call descriptor .merge/key/opt project left right)
        (let (changes (with-list-builder (emit)
          ;; Preserve generic left order, then visit only right-exclusive keys.
          ;; Capture changes before any index writes so unique swaps are legal.
          (def (visit key a b)
            (def next (project key a b))
            (unless (table-option=? a next) (emit (make-table-change key a next))))
          (.call descriptor .for-each (lambda (key value)
            (visit key (some value) (.call descriptor .ref/opt right key))) left)
          (.call descriptor .for-each (lambda (key value)
            (unless (.call descriptor .key? left key) (visit key #f (some value)))) right)))
          (if (null? changes) left
            (.call descriptor .apply-delta left
              (make-table-delta (.@ descriptor Key) (.@ descriptor Value)
                sources (map object-revision sources) changes))))))
      (require-table descriptor result)))))

;; A read relation must not require an unrelated empty output to be admitted.
;; Two-sided domain inclusion plus matching left values establish equality under
;; the persistent backend's distinct-key law; callbacks remain guarded.
(def (equal-table-bindings? descriptor left right)
  (with-table-sources (table-sources descriptor) (lambda ()
    (require-table descriptor left)
    (require-table descriptor right)
    (and (.call descriptor .every (lambda (key value)
        (def found (.call descriptor .ref/opt right key))
        (and found (.call (.@ descriptor Value) .=? value (some-value found)))) left)
      (.call descriptor .every (lambda (key _) (.call descriptor .key? left key)) right)))))

;; Select from one admitted snapshot. Shared validation surrounds declared
;; structural capabilities; generic tables stage only removals, then reuse their
;; final-state delta installer. No empty seed or partial indexed root is required.
(def (select-table descriptor predicate input split?)
  (using (predicate :~ procedure?)
    (def sources (table-sources descriptor))
    (with-table-sources sources (lambda ()
      (require-table descriptor input)
      ;; Every backend observes the same strict Bool boundary and exact failure.
      (def (classify key value)
        (def selected? (predicate key value))
        (using (selected? :~ boolean?) selected?))
      ;; Each side starts at the original root; unchanged selections retain it.
      ;; All decisions precede installation, and no predicate is replayed.
      (def (generic)
        (def removals (.call descriptor .foldl (lambda (key value sides)
          (def selected? (classify key value))
          (if selected?
            (if split? (cons (car sides)
              (cons (make-table-change key (some value) #f) (cdr sides))) sides)
            (cons (cons (make-table-change key (some value) #f) (car sides)) (cdr sides)))) (cons [] []) input))
        ;; Capture ordered deletions using the existing optimistic delta format.
        (def (install changes)
          (if (null? changes) input
            (.call descriptor .apply-delta input
              (make-table-delta (.@ descriptor Key) (.@ descriptor Value)
                sources (map object-revision sources) (reverse changes)))))
        (def yes (install (car removals)))
        (cons yes (and split? (install (cdr removals)))))
      (def roots (cond
        ((and split? (.has? descriptor .partition/key))
          (let-values (((yes no) (.call descriptor .partition/key classify input))) (cons yes no)))
        ((and (not split?) (.has? descriptor .filter/key))
          (cons (.call descriptor .filter/key classify input) #f))
        (else (generic))))
      (require-table descriptor (car roots))
      (when split? (require-table descriptor (cdr roots)))
      roots))))


;; Immutable, protocol-owned snapshots retain both logical-key registries. No
;; state constructor or cache accessor is exported, and no prior-state chain is kept.
(defstruct table-projection-state (owner sources versions source target ledger owners) final: #t)

;; Incremental optional entry projection: .ap scans once, .unap observes the source,
;; .get observes the target, and .apply-delta returns a new state atomically. Stable
;; pure callbacks and persistent carriers are premises; explicit origins invalidate
;; all states when projection metadata changes. No inverse projection is inferred.
(def (table-projection source target transform (origins []))
  (using ((transform :~ procedure?) (origins :~ list?))
    (with-table-sources (append (list source target) origins) (lambda ()
      (def binding (Pair (.@ target Key) (.@ target Value)))
      (def ledger (table-key-table source binding))
      (def owners (table-key-table target (.@ source Key)))
      (def touched (table-key-table source Unit))
      (def sources (delete-duplicates/hash
        (append (table-sources source) (table-sources target) origins
          (table-sources ledger) (table-sources owners) (table-sources touched))
        table: (make-hash-table-eq) from-end?: #t))
      (with-table-sources sources (lambda ()
        (def versions (map object-revision sources))
        (def owner (list source target transform))
        ;; Check stamps before callbacks; hold every inherited delta origin during
        ;; preparation. Failed attempts cannot publish roots, caches or new stamps.
        (def (guard dependencies action)
          (with-table-sources dependencies (lambda ()
            (unless (equal? versions (map object-revision sources))
              (error "stale table projection"))
            (action))))
        ;; State ownership is independent of backend carrier identity and lineage.
        (def (check state)
          (unless (and (table-projection-state? state)
                       (eq? owner (table-projection-state-owner state)))
            (error "incompatible table projection state"))
          (unless (equal? (table-projection-state-versions state)
                         (map object-revision (table-projection-state-sources state)))
            (error "stale table projection state")))
        ;; One shared read boundary covers the source, target and inherited origins.
        (def (observe state access)
          (check state)
          (guard (table-projection-state-sources state) (lambda () (check state) (access state))))
        ;; Cold preparation visits the original source once. Only the complete row
        ;; list reaches target construction; no refined empty/prefix is required.
        (def (initialize input)
          (guard sources (lambda ()
            (require-table source input)
            (def cache (.@ ledger .empty)) (def seen (.@ owners .empty))
            (def rows (with-list-builder (emit)
              (.call source .for-each (lambda (key value)
                (def next (require-table-entry binding (transform key value)))
                (when (some? next)
                  (let (row (some-value next))
                    (set! seen (claim-table-entry owners seen row key))
                    (set! cache (.call ledger .acons key row cache))
                    (emit row)))) input)))
            (def result (require-table target (.call target .<-list rows)))
            (make-table-projection-state owner sources versions input result cache seen))))
        ;; Admit ALL source conflicts and the complete source before projection.
        ;; Coalesce by source equality, preserving first-touch order; project only
        ;; final present values, once per touched key, never deleted/intermediate rows.
        ;; The optional standard continuation receives the admitted successor and
        ;; the EXACT delta just installed, with no diff scan or retained history.
        ;; values delivers two results; the default keeps ordinary state-only use.
        (def (update state delta (receive (lambda (next _delta) next)))
          (using (receive :~ procedure?)
            (check state)
            (unless (table-delta? delta) (error "table delta required"))
            (def dependencies (delete-duplicates/hash
              (append sources (table-projection-state-sources state) (table-delta-sources delta))
              table: (make-hash-table-eq) from-end?: #t))
            (guard dependencies (lambda ()
              (check state)
              (def next-source (require-table source
                (.call source .apply-delta (table-projection-state-source state) delta)))
              (def seen-keys (.@ touched .empty))
              (def keys (with-list-builder (emit)
                (for-each (lambda (change)
                  (def key (table-change-key change))
                  (unless (.call touched .key? seen-keys key)
                    (set! seen-keys (.call touched .acons key (void) seen-keys))
                    (emit key))) (table-delta-changes delta))))
              (def cache (table-projection-state-ledger state))
              (def seen (table-projection-state-owners state))
              ;; Retract every affected old owner before any new claim. Target edits
              ;; are private ordinary deltas; indexes inspect only the final root.
              (def removals (with-list-builder (emit)
                (for-each (lambda (key)
                  (def old (.call ledger .ref/opt cache key))
                  (when (some? old)
                    (let (row (some-value old))
                      (set! cache (.call ledger .remove cache key))
                      (set! seen (.call owners .remove seen (car row)))
                      (emit (make-table-change (car row) (some (cdr row)) #f))))) keys)))
              (def additions (with-list-builder (emit)
                (for-each (lambda (key)
                  (def final (.call source .ref/opt next-source key))
                  (when (some? final)
                    (let (next (require-table-entry binding (transform key (some-value final))))
                      (when (some? next)
                        (let (row (some-value next))
                          (set! seen (claim-table-entry owners seen row key))
                          (set! cache (.call ledger .acons key row cache))
                          (emit (make-table-change (car row) #f (some (cdr row))))))))) keys)))
              (def output-delta (make-table-delta (.@ target Key) (.@ target Value) dependencies
                (map object-revision dependencies) (append removals additions)))
              (def result (require-table target
                (.call target .apply-delta (table-projection-state-target state) output-delta)))
              (def next (make-table-projection-state owner dependencies (map object-revision dependencies)
                next-source result cache seen))
              (receive next output-delta)))))
        (.cc Wrapper. Domain: source Value: target .sources: sources
          .ap: initialize .unap: (cut observe <> table-projection-state-source)
          .get: (cut observe <> table-projection-state-target) .apply-delta: update)))))))

;; A lookup join keeps independent immutable source heads and the existing
;; projection state. No mutable ambient right-hand context is shared by branches.
(defstruct %table-lookup-join (owner indexed right projection sources versions) final: #t)

;; Maintain an explicit many-to-one foreign-key lookup. Existing grouped indexes
;; find right-side dependents; a typed Sum distinguishes absence from stored false.
;; Existing table-projection owns output claims, key swaps, final admission and
;; exact delta delivery. classify/project are stable pure callbacks with origins.
(def (table-lookup-join left right target classify project (origins []))
  (using ((classify :~ procedure?) (project :~ procedure?) (origins :~ list?))
    (with-table-sources (append (list left right target) origins) (lambda ()
      (def primary (table-key-table left (.@ left Value)))
      (def groups (table-key-table right primary))
      (def indexed-type (table-indexes primary
        (list (.o name: 'lookup table: groups unique?: #f project: classify))))
      (def presence (Sum present: (.@ right Value) missing: Unit))
      (def row-type (Pair (.@ left Value) presence))
      (def joined (table-key-table left row-type))
      (def touched (table-key-table left Unit))
      (def dependencies (delete-duplicates/hash
        (append (table-sources left) (table-sources right) (table-sources target)
          (table-sources joined) (table-sources touched) (.@ indexed-type .sources)
          (list indexed-type presence row-type) origins)
        table: (make-hash-table-eq) from-end?: #t))
      ;; Convert only the private presence tag to a fresh public Option shell.
      ;; Child Functions remain the already admitted leaves in both directions.
      (def projection (table-projection joined target
        (lambda (key row)
          (def found (cdr row))
          (project key (car row) (and (eq? (.@ found tag) 'present) (some (.@ found value))))) dependencies))
      (def sources (cons projection dependencies))
      (with-table-sources sources (lambda ()
        (def versions (map object-revision sources))
        (def owner (list left right target classify project))
        ;; Protect the complete preparation/delivery scope and captured metadata.
        (def (guard live action)
          (with-table-sources live (lambda ()
            (unless (equal? versions (map object-revision sources)) (error "stale table lookup join"))
            (action))))
        ;; Historical source origins are retained even by zero-edit successors.
        (def (observe state action)
          (unless (and (%table-lookup-join? state) (eq? owner (%table-lookup-join-owner state)))
            (error "incompatible table lookup join"))
          (guard (%table-lookup-join-sources state) (lambda ()
            (unless (equal? (%table-lookup-join-versions state)
              (map object-revision (%table-lookup-join-sources state))) (error "stale table lookup join state"))
            (action))))
        ;; Read the declared foreign key without coercing it or cooking payloads.
        (def (enrich key row context)
          (def foreign (classify key row))
          (require-table-key right foreign)
          (def found (.call right .ref/opt context foreign))
          (cons row (if (some? found) (.call presence make 'present (some-value found))
                      (.call presence make 'missing (void)))))
        ;; Capture the caller's Pair before recognizers can mutate its shell.
        ;; Both complete sources precede any indexing or user projection callback.
        (def (initialize input)
          (using (input :~ pair?)
            (def l (car input)) (def r (cdr input))
            (guard sources (lambda ()
              (require-table left l) (require-table right r)
              (def indexed (.call indexed-type .wrap l))
              (def rows (.call primary .foldl
                (lambda (key row rows) (cons (cons key (enrich key row r)) rows)) [] l))
              (def state (.call projection .ap (.call joined .<-list (reverse rows))))
              (make-%table-lookup-join owner indexed r state sources versions)))))
        ;; The index admission continuation stages the right source after complete
        ;; left admission but before any classification. Each source delta installs
        ;; once. All caches remain private if either source or projection refuses.
        (def (update state delta-left delta-right (receive (lambda (next _delta) next)))
          (using (receive :~ procedure?)
            (unless (and (table-delta? delta-left) (table-delta? delta-right)) (error "table deltas required"))
            (observe state (lambda ()
              (def live (delete-duplicates/hash
                (append (%table-lookup-join-sources state) (table-delta-sources delta-left)
                  (table-delta-sources delta-right)) table: (make-hash-table-eq) from-end?: #t))
              (guard live (lambda ()
                (def next-right #f)
                (def indexed (.call indexed-type .apply-delta (%table-lookup-join-indexed state) delta-left
                  (lambda (next-left)
                    (require-table left next-left)
                    (set! next-right (require-table right
                      (.call right .apply-delta (%table-lookup-join-right state) delta-right))))))
                (def next-left (.call indexed-type .unwrap indexed))
                (def seen (.@ touched .empty))
                ;; One backend-owned key registry coalesces left edits and both
                ;; old/final dependency buckets, including deletion and migration.
                (def keys (with-list-builder (emit)
                  ;; This callback is local to one immutable revision attempt.
                  (def (visit key)
                    (unless (.call touched .key? seen key)
                      (set! seen (.call touched .acons key (void) seen)) (emit key)))
                  (for-each (lambda (change) (visit (table-change-key change))) (table-delta-changes delta-left))
                  (for-each (lambda (change)
                    (for-each (lambda (snapshot)
                      (def bucket (.call indexed-type .index-ref/opt snapshot 'lookup (table-change-key change)))
                      (when (some? bucket) (.call primary .for-each (lambda (key _row) (visit key)) (some-value bucket))))
                      (list (%table-lookup-join-indexed state) indexed))) (table-delta-changes delta-right))))
                (def before (.call projection .unap (%table-lookup-join-projection state)))
                (def edits (map (lambda (key)
                  (def old (map/option identity (.call joined .ref/opt before key)))
                  (def row (.call primary .ref/opt next-left key))
                  (make-table-change key old (map/option (lambda (row) (enrich key row next-right)) row))) keys))
                (def delta (make-table-delta (.@ joined Key) row-type live (map object-revision live) edits))
                (.call projection .apply-delta (%table-lookup-join-projection state) delta
                  (lambda (next output)
                    (receive (make-%table-lookup-join owner indexed next-right next live
                      (map object-revision live)) output)))))))))
        (.cc Wrapper. Domain: (Pair left right) Value: target .sources: sources .ap: initialize
          .unap: (lambda (state) (observe state (lambda ()
            (cons (.call indexed-type .unwrap (%table-lookup-join-indexed state)) (%table-lookup-join-right state)))))
          .get: (lambda (state) (observe state (lambda () (.call projection .get (%table-lookup-join-projection state)))))
          .apply-deltas: update)))))))
