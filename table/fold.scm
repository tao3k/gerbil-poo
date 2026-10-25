;;; Owner-bound incremental folds and final-state representation transfer.

;; One fold kernel serves whole-table and per-group preparation. The enclosing
;; protocol owns complete admission/metadata; checked recognizes contributions and
;; intermediate aggregates without wrapping them a second time.
(def (fold-table descriptor zero add project checked table)
  (.call descriptor .foldl
    (lambda (key row acc) (checked (add acc (checked (project key row))))) zero table))

;; Owned aggregate states retain admitted snapshots and all revision dependencies.
;; Only the creating Wrapper can inspect/update them; no constructor is exported.
(defstruct table-fold-state (owner sources versions table value) final: #t)

;; Lift a retractable fold through existing Wrapper and numeric/algebra methods.
;; Aggregate supplies .zero/.add/.sub and recognition; project maps admitted k/v
;; to admitted contributions. Pure stable operations and the optional-write fold
;; law are caller premises, not inferred from these method names or membership.
(def (table-fold descriptor aggregate project)
  (defvalues (folding _adopt _read) (make-table-fold descriptor aggregate project []))
  folding)

;; Keep aggregate adoption and the checked state reader private to fold derivation.
;; Extra dependencies bind a derived contribution to its explicit inverse maps.
(def (make-table-fold descriptor aggregate project extra-sources)
  (using (project :~ procedure?)
    (def sources (delete-duplicates/hash
      (append (table-sources descriptor) (list aggregate) extra-sources)
      table: (make-hash-table-eq) from-end?: #t))
    (with-table-sources sources
      (lambda ()
        (def versions (map object-revision sources))
        (def owner (list descriptor aggregate project))
        (def add (.@ aggregate .add))
        (def sub (.@ aggregate .sub))
        ;; Recognition preserves admitted aggregate leaves instead of rewrapping.
        (def (checked value)
          (unless (element? aggregate value) (raise-type-error aggregate value 'table-fold)) value)
        (def zero (checked (.@ aggregate .zero)))
        ;; Guard all captured metadata over callbacks and private construction.
        (def (guard dependencies action)
          (with-table-sources dependencies (lambda ()
            (unless (equal? versions (map object-revision sources)) (error "stale table fold"))
            (action))))
        ;; A foreign or stale state never supplies an aggregate or source snapshot.
        (def (require-state state)
          (unless (and (table-fold-state? state) (eq? owner (table-fold-state-owner state)))
            (error "incompatible table fold state"))
          (unless (equal? (table-fold-state-versions state)
                          (map object-revision (table-fold-state-sources state)))
            (error "stale table fold state")))
        ;; Fresh initialization scans the admitted table once, without normalization.
        (def (initialize table)
          (guard sources (lambda ()
            (require-table descriptor table)
            (def value (fold-table descriptor zero add project checked table))
            (make-table-fold-state owner sources versions table value))))
        ;; Read either part under the same freshness/owner checks as installation.
        (def (observe state access)
          (unless (table-fold-state? state) (error "incompatible table fold state"))
          (guard (table-fold-state-sources state) (lambda () (require-state state) (access state))))
        ;; Complete old-value and origin checks before any contribution callback.
        ;; A later projection/arithmetic failure exposes neither staged result.
        (def (update state delta)
          (unless (and (table-fold-state? state) (table-delta? delta))
            (error "table fold state and delta required"))
          (def dependencies (delete-duplicates/hash
            (append sources (table-fold-state-sources state) (table-delta-sources delta))
            table: (make-hash-table-eq) from-end?: #t))
          (guard dependencies (lambda ()
            (require-state state)
            ;; Compatible deltas may come from a less constrained descriptor.
            ;; Admit the complete final root before any aggregate projection.
            (let (next (require-table descriptor
                        (.call descriptor .apply-delta (table-fold-state-table state) delta)))
              (def value (foldl (lambda (change acc)
                (def k (table-change-key change))
                (def before (table-change-before change))
                (def after (table-change-after change))
                (def removed (if (some? before)
                  (checked (sub acc (checked (project k (some-value before))))) acc))
                (if (some? after)
                  (checked (add removed (checked (project k (some-value after))))) removed))
                (table-fold-state-value state) (table-delta-changes delta)))
              (make-table-fold-state owner dependencies (map object-revision dependencies) next value)))))
        ;; Trusted conversion has already constructed the admitted carrier; retain
        ;; its source lineage while reusing an admitted aggregate without refolding.
        (def (adopt table value origins)
          (def dependencies (delete-duplicates/hash (append sources origins)
            table: (make-hash-table-eq) from-end?: #t))
          (guard dependencies (lambda ()
            (make-table-fold-state owner dependencies (map object-revision dependencies)
              table (checked value)))))
        ;; The checked reader never escapes through the public fold Wrapper.
        (def (read-state state) (observe state identity))
        (using ((add :~ procedure?) (sub :~ procedure?))
          (def folding (.cc Wrapper. Domain: descriptor Value: aggregate .ap: initialize
            .unap: (cut observe <> table-fold-state-table)
            .get: (cut observe <> table-fold-state-value) .apply-delta: update
            .isomorphism: (lambda (target key value)
              (guard sources (lambda ()
                (make-table-fold-isomorphism folding descriptor aggregate project
                  adopt read-state update target key value))))))
          (values folding adopt read-state))))))

;; One private pairing per transport, including only the currently live key owners.
;; Replacing the pairing never retains a chain of prior snapshots or global memo.
(defstruct table-fold-pair (source target owners) final: #t)

;; Derive the target contribution by pullback, then reuse the source aggregate.
;; The paired-state invariant is target = map(source), with equal fold values.
;; Cold/foreign-state recovery may scan; hits and warm edits do not enumerate.
(def (make-table-fold-isomorphism folding source aggregate project
       adopt-source read-source update-source target key value)
  (call-with-table-translations source target key value (list folding aggregate)
    (lambda (base-sources forward backward)
      (def ku (table-translation-unkey forward))
      (def va (table-translation-value forward)) (def vu (table-translation-unvalue forward))
      (defvalues (target-fold adopt-target read-target)
        (make-table-fold target aggregate (lambda (k v) (project (ku k) (vu v))) base-sources))
      (def sources (cons target-fold base-sources))
      (instantiate-object! target-fold)
      (def versions (map object-revision sources))
      (def paired #f)
      ;; Hold common metadata and the particular input's origins for the entire use.
      ;; A stale old cache cannot poison a different, independently fresh input.
      (def (guard origins action)
        (with-table-sources (append sources origins) (lambda ()
          (unless (equal? versions (map object-revision sources))
            (error "stale table fold isomorphism"))
          (action))))
      ;; Unforgeable fold ownership is checked by the creating protocol's reader.
      (def (origins state)
        (unless (table-fold-state? state) (error "table fold state required"))
        (table-fold-state-sources state))
      ;; Prepare a pairing privately: commit it only after the complete caller succeeds.
      (def (prepare state)
        (def original (read-source state))
        (if (and paired (eq? state (table-fold-pair-source paired)))
          (begin (read-target (table-fold-pair-target paired)) paired)
          (if (and paired (eq? (table-fold-state-table original)
                               (table-fold-state-table (table-fold-pair-source paired))))
            ;; Fresh independent admission of the SAME immutable source root can
            ;; rebind the representation, even if old origin stamps expired. Never
            ;; copy the old aggregate or accept an expired input state to do this.
            (make-table-fold-pair original
              (adopt-target (table-fold-state-table (table-fold-pair-target paired))
                (table-fold-state-value original) (origins original))
              (table-fold-pair-owners paired))
            (let ()
              (defvalues (_ convert _owners seen) (table-translators forward))
              (def converted (convert (table-fold-state-table original)))
              (def result (adopt-target converted (table-fold-state-value original) (origins original)))
              (make-table-fold-pair original result (seen))))))
      ;; Identical source-state hits reuse target identity, without reinitializing it.
      (def (convert state)
        (guard (origins state) (lambda ()
          (def next (prepare state))
          (set! paired next)
          (table-fold-pair-target next))))
      ;; A paired inverse recovers the exact original source state. A valid target
      ;; updated outside this transport uses checked full conversion, but never refolds.
      (def (recover state)
        (guard (origins state) (lambda ()
          (def original (read-target state))
          (if (and paired (eq? state (table-fold-pair-target paired)))
            (begin (read-source (table-fold-pair-source paired)) (table-fold-pair-source paired))
            (let ()
              (defvalues (_key convert _backward-owners _backward-seen) (table-translators backward))
              (def converted (convert (table-fold-state-table original)))
              (def result (adopt-source converted (table-fold-state-value original) (origins original)))
              ;; A cold inverse reconstructs only key ownership after conversion.
              ;; It retains incoming lineage rather than laundering stale provenance.
              (defvalues (translate _table _owners seen) (table-translators forward))
              (.call source .for-each (lambda (k _v) (translate k)) converted)
              (set! paired (make-table-fold-pair result original (seen)))
              result)))))
      ;; Source installation checks every conflict before conversion or publication.
      ;; Warm translation uses the cached bijection and touches only changed bindings.
      ;; Failed callbacks discard local registry/writes, preserving the prior pairing.
      (def (update state delta)
        (unless (table-delta? delta) (error "table delta required"))
        (guard (append (origins state) (table-delta-sources delta)) (lambda ()
          (read-source state)
          (def next-source (update-source state delta))
          (def previous (prepare state))
          (def current (read-target (table-fold-pair-target previous)))
          (defvalues (translate _table owners seen)
            (table-translators forward (some (table-fold-pair-owners previous))))
          ;; A key-space overlay remembers only the last translated edit at each
          ;; key. Before expectations come from this overlay or the admitted pair;
          ;; no old value is re-converted and no target point write is performed.
          (def overlay (table-key-table target (.cc Type. .element?: table-change?)))
          (def pending (.@ overlay .empty))
          (def changes (with-list-builder (emit)
            (for-each (lambda (change)
              (def k (translate (table-change-key change)))
              (def prior (.call overlay .ref/opt pending k))
              (def before (if (some? prior) (table-change-after (some-value prior))
                (.call target .ref/opt (table-fold-state-table current) k)))
              (def after (map/option (lambda (v)
                (translate-table-value
                  (table-child-type forward table-translation-source-value table-translation-source Value)
                  (table-child-type forward table-translation-target-value table-translation-target Value) va vu v))
                (table-change-after change)))
              (def translated (make-table-change k before after))
              (set! pending (.call overlay .acons k translated pending))
              (emit translated)) (table-delta-changes delta))))
          ;; Retain every intermediate expectation and original dependency. The
          ;; target's existing installer owns atomic final-state index preparation.
          (def dependencies (delete-duplicates/hash (append sources (origins next-source))
            table: (make-hash-table-eq) from-end?: #t))
          (def installed (.call target .apply-delta (table-fold-state-table current)
            (make-table-delta (.@ target Key) (.@ target Value) dependencies
              (map object-revision dependencies) changes)))
          ;; A key deleted then reinserted in this batch is still a live owner.
          (def live-owners (foldl (lambda (k registry)
            (if (.call target .key? installed k) registry (.call owners .remove registry k)))
            (seen) (map table-change-key (filter (lambda (change) (not (table-change-after change))) changes))))
          ;; Sparse replay preserves bindings, not arbitrary target refinements.
          ;; Recognition retains checked leaves; only full success replaces paired.
          (def result (adopt-target (require-table target installed)
            (table-fold-state-value next-source) (origins next-source)))
          (set! paired (make-table-fold-pair next-source result live-owners))
          result)))
      (.cc Wrapper. Domain: folding Codomain: target-fold
        .ap: convert .unap: recover .apply-delta: update))))


;; A grouped summary retains one indexed source, one public target and every
;; historical delta origin. Only the creating protocol can use this snapshot.
(defstruct %table-group-fold (owner indexed target sources versions) final: #t)

;; Maintain a typed aggregate per nonempty group through existing grouped indexes
;; and the common fold kernel. Recompute complete affected buckets, not untouched
;; groups; no retraction law or automatic dependency discovery is assumed.
(def (table-group-fold source target aggregate classify project (origins []) multiple?: (multiple? #f))
  (using ((classify :~ procedure?) (project :~ procedure?) (origins :~ list?) (multiple? :~ boolean?))
    (with-table-sources (append (list source target aggregate) origins) (lambda ()
      (unless (eq? (.@ target Value) aggregate) (error "incompatible grouped aggregate type"))
      (def primary (table-key-table source (.@ source Value)))
      (def groups (table-key-table target primary))
      (def touched (table-key-table target Unit))
      ;; A single list-valued key remains one key. Only explicit multiple? opens
      ;; finite membership; the existing index owns deduplication and buckets.
      (def group-keys (if multiple? classify (lambda (key row) (list (classify key row)))))
      (def indexed-type (table-indexes primary
        (list (.o name: 'aggregate table: groups unique?: #f multiple?: #t project: group-keys))))
      (def sources (delete-duplicates/hash
        (append (table-sources source) (table-sources target) (table-sources touched)
          (list aggregate indexed-type) (.@ indexed-type .sources) origins)
        table: (make-hash-table-eq) from-end?: #t))
      (with-table-sources sources (lambda ()
        (def versions (map object-revision sources))
        (def owner (list source target aggregate classify project))
        (def add (.@ aggregate .add))
        ;; Recognize aggregate leaves without normalizing admitted Functions.
        (def (checked value)
          (unless (element? aggregate value) (raise-type-error aggregate value 'table-group-fold)) value)
        (def zero (checked (.@ aggregate .zero)))
        ;; The original protocol metadata and all inherited origins stay protected
        ;; across classification, aggregation, final admission and delivery.
        (def (guard dependencies action)
          (with-table-sources dependencies (lambda ()
            (unless (equal? versions (map object-revision sources)) (error "stale table group fold"))
            (action))))
        ;; Refuse foreign or stale successors before reading either private cache.
        (def (observe state action)
          (unless (and (%table-group-fold? state) (eq? owner (%table-group-fold-owner state)))
            (error "incompatible table group fold"))
          (guard (%table-group-fold-sources state) (lambda ()
            (unless (equal? (%table-group-fold-versions state)
              (map object-revision (%table-group-fold-sources state))) (error "stale table group fold state"))
            (action))))
        ;; Share the ordinary fold algorithm; only structural buckets face this
        ;; fold, while the full source refinement belongs to the complete primary.
        (def (summarize bucket) (fold-table primary zero add project checked bucket))
        ;; One complete target constructor permits jointly valid group summaries
        ;; without requiring an empty seed or each singleton to satisfy refinements.
        (def (initialize input)
          (guard sources (lambda ()
            (require-table source input)
            (def indexed (.call indexed-type .wrap input))
            (def entries (.call indexed-type .index-fold indexed 'aggregate
              (lambda (key bucket entries) (cons (cons key (summarize bucket)) entries)) []))
            (def output (require-table target (.call target .<-list (reverse entries))))
            (make-%table-group-fold owner indexed output sources versions))))
        ;; Install and admit the complete source first; then coalesce original and
        ;; final group keys, refold each affected surviving bucket once and deliver
        ;; one exact target delta. No target snapshot diff is rediscovered.
        (def (update state delta (receive (lambda (next _delta) next)))
          (using (receive :~ procedure?)
            (unless (table-delta? delta) (error "table delta required"))
            (observe state (lambda ()
              (def dependencies (delete-duplicates/hash
                (append (%table-group-fold-sources state) (table-delta-sources delta))
                table: (make-hash-table-eq) from-end?: #t))
              (guard dependencies (lambda ()
                (def before (.call indexed-type .unwrap (%table-group-fold-indexed state)))
                (def indexed (.call indexed-type .apply-delta (%table-group-fold-indexed state) delta
                  (cut require-table source <>)))
                (def after (.call indexed-type .unwrap indexed))
                (def seen (.@ touched .empty))
                (def keys (with-list-builder (emit)
                  (for-each (lambda (change)
                    (def key (table-change-key change))
                    (for-each (lambda (root)
                      (def row (.call primary .ref/opt root key))
                      (when (some? row)
                        (for-each (lambda (bucket)
                          (unless (.call touched .key? seen bucket)
                            (set! seen (.call touched .acons bucket (void) seen)) (emit bucket)))
                          (require-table-index-keys (.@ target Key)
                            (group-keys key (some-value row)) 'table-group-fold))))
                      (list before after))) (table-delta-changes delta))))
                (def edits (with-list-builder (emit)
                  (for-each (lambda (key)
                    (def old (map/option identity (.call target .ref/opt (%table-group-fold-target state) key)))
                    (def bucket (.call indexed-type .index-ref/opt indexed 'aggregate key))
                    (def next (map/option summarize bucket))
                    (unless (table-option=? old next) (emit (make-table-change key old next)))) keys)))
                (def delivered (make-table-delta (.@ target Key) aggregate
                  dependencies (map object-revision dependencies) edits))
                (def output (require-table target (.call target .apply-delta (%table-group-fold-target state) delivered)))
                (receive (make-%table-group-fold owner indexed output dependencies
                  (map object-revision dependencies)) delivered)))))))
        (using (add :~ procedure?)
          (.cc Wrapper. Domain: source Value: target .sources: sources .ap: initialize
            .unap: (lambda (state) (observe state (lambda () (.call indexed-type .unwrap (%table-group-fold-indexed state)))))
            .get: (lambda (state) (observe state (lambda () (%table-group-fold-target state))))
            .apply-delta: update))))))))
