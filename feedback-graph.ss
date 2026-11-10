;;; Automatic SCC condensation feeding existing whole-group closure and caching.
(export graph-cache? graph-cache-partition graph-cache-values graph-cache-source
        graph-cache-ref graph-cache-current! feedback-graph-action publish-feedback-graph publish-owned-feedback-graph
        feedback-graph-revision-action publish-feedback-graph-revision
        reconfigure-components feedback-component-revision-action %feedback-component-revision-action)
(import :std/iter (only-in :std/list/list filter append-map delete-duplicates/hash)
        (only-in :std/list/list-builder with-list-builder)
        ./object ./mop ./support/option ./feedback-cache ./lens-laws
        (prefix-in ./strong-components scc.) (prefix-in ./generalized-graph graph.)
        (prefix-in ./construction-cache cache.) (prefix-in ./dependency-analysis code.)
        (prefix-in (only-in ./fun Observation.) fun.))
;; Keep the frozen node source, admitted partition, builder identity and group DAG.
(defstruct graph-cache (source partition build values owned group-keys guard) final: #t)
(def (graph-cache-current! graph)
  (let (owned (graph-cache-owned graph))
    (when owned (graph.%component-source-current! owned)))
  (let (guard (graph-cache-guard graph))
    (if guard (%feedback-guard-current! guard)
      (%feedback-cache-current! (graph-cache-values graph) (graph-cache-group-keys graph)))))
;; Resolve a node through its current SCC; no caller-maintained grouping is needed.
(def (graph-cache-ref current key)
  (feedback-cache-ref (graph-cache-values current) ((scc.partition-owner (graph-cache-partition current)) key)))
;; Freeze code/base identities before partitioning; arbitrary mutable callbacks
;; still require the same pure/extensional source discipline as ConstructionCache.
(def (freeze source)
  (def keys (.@ source keys))
  (graph.declaration keys (map (lambda (key) (cons key (.call source .code key))) keys)
    (map (lambda (key) (cons key (.call source .base key))) keys)))
;; External footprints are expressed in SCC representatives and deduplicated.
(def (dependencies partition members)
  (delete-duplicates/hash
    (with-list-builder (add)
      (for (member members)
        (for (node ((scc.partition-reads partition) member))
          (let (owner ((scc.partition-owner partition) node))
            (unless (eq? owner (car members)) (add owner))))))))
;; A group resolver supplies ONLY declared external node reads. Its builder must
;; close every member equation on the shared carrier using existing lens closure.
;; Internal reads belong to cooked self, not to partially constructed cache slots.
(def (group-code partition members source build)
  (def deps (dependencies partition members))
  (def allowed (make-hash-table-eq))
  (for (member members)
    (for (node ((scc.partition-reads partition) member))
      (unless (eq? ((scc.partition-owner partition) node) (car members))
        (hash-put! allowed node #t))))
  (.cc code.Computation. reads: deps .evaluate: (lambda (provider)
    (code.make-success (build members source (lambda (node)
      (def owner ((scc.partition-owner partition) node))
      (unless (hash-key? allowed node) (error "undeclared external SCC read" node))
      (def found (provider owner))
      (unless (and (some? found) (code.success? (some-value found)))
        (error "external feedback group unavailable" node))
      (code.success-value (some-value found))))))))
;; Join all services before construction: reject duplicate or stale membership
;; edits, forbid remove/re-add ambiguity, and delegate provider conflict checks to
;; graph.reconfigure. Unedited survivors keep identity; additions have no latent
;; providers. The ordered union determines the final deterministic SCC key order.
;; Descriptors/lists and callbacks obey the existing immutable-source discipline.
(def (component-edits fragments)
  ;; Preserve contribution AND member order; Gerbil append-map reverses each
  ;; mapped row, so reverse restores the former apply-append semantics.
  (def (collect field) (append-map (lambda (part) (reverse (.ref part field))) fragments))
  (def (bindings field)
    (map (lambda (entry) (if (pair? entry) (cons (car entry) (cdr entry)) entry)) (collect field)))
  (values (collect 'added) (collect 'removed) (bindings 'codes) (bindings 'bases)))
(def (component-source-edit spec added removed codes bases)
  (def old-keys (.@ spec keys))
  (def old-index (make-hash-table-eq))
  (def removed-index (make-hash-table-eq))
  (for-each (lambda (key) (hash-put! old-index key #t)) old-keys)
  ;; Membership validation applies across all services, not just each descriptor.
  (def (distinct-symbols? names)
    (and (list? names) (andmap symbol? names)
      (= (length names) (length (delete-duplicates/hash names)))))
  (unless (and (distinct-symbols? added) (distinct-symbols? removed)
               (andmap (lambda (key) (not (hash-key? old-index key))) added)
               (andmap (cut hash-key? old-index <>) removed))
    (error "conflicting or stale component membership contributions"))
  (for-each (lambda (key) (hash-put! removed-index key #t)) removed)
  (def source
    (graph.reconfigure spec
      (append (filter (lambda (key) (not (hash-key? removed-index key))) old-keys) added)
      codes bases))
  (values source (append removed (map car codes) (map car bases))))

(def (reconfigure-components spec fragments)
  (defvalues (added removed codes bases) (component-edits fragments))
  (defvalues (source _roots) (component-source-edit spec added removed codes bases))
  source)

;; Retain a resolver only when its complete membership, footprints, member source
;; identities and builder are unchanged. Merge/split changes therefore dirty the
;; new groups even when a representative survives. Downstream dirtiness is then
;; propagated by ConstructionCache on the NEW condensation DAG.
(def (condense old source partition build affected?)
  (def groups (scc.partition-groups partition))
  (def old-partition (and old (graph-cache-partition old)))
  (def old-source (and old (graph-cache-source old)))
  (graph.declaration (map car groups)
    (map (lambda (members)
      (def key (car members))
      (def prior (and old (scc.partition-members old-partition key)))
      (def same?
        (and prior (eq? build (graph-cache-build old)) (equal? members prior)
             (or (and affected? (not (affected? key)))
                 (and (equal? (dependencies partition members) (dependencies old-partition prior))
                      (andmap (lambda (node)
                        (and (equal? (map (scc.partition-owner partition) ((scc.partition-reads partition) node))
                                     (map (scc.partition-owner old-partition) ((scc.partition-reads old-partition) node)))
                             (eq? (.call source .code node) (.call old-source .code node))
                             (eq? (.call source .base node) (.call old-source .base node)))) members)))))
      (cons key (if same? (.call (cache.cache-source (graph-cache-values old)) .code key)
        (group-code partition members source build)))) groups)))
;; Gerbil FUN Reader composes partition, whole-group reconstruction and current
;; cross-service approval. Guard admission spans preparation through publication.
;; build is pure/locally total and must honor the declared component equations;
;; automatic dependency discovery inside arbitrary Scheme closures is out of scope.
(def (admit-graph old source partition build ownership values keys guard admit)
  (def prior (and old (graph-cache-values old)))
  (def candidate (make-graph-cache source partition build values ownership (and (not guard) keys) guard))
  (def (approve _ __) (admit old candidate))
  (if guard (%admit-guarded-feedback-cache prior values guard approve)
    (%admit-feedback-cache prior values keys approve))
  candidate)
(def (register-directly action) (action))
(def (start-guard candidate keys partition register)
  (%start-feedback-guard candidate keys (cut scc.%partition-key-position partition <>)
    (scc.%partition-source-count partition) register))
(def (start-owned-quotient source partition build builder)
  (def groups (scc.partition-groups partition))
  (def keys (map car groups))
  (def codes (map (lambda (members) (cons (car members) (group-code partition members source build))) groups))
  (values (cache.start-owned (graph.schedule-owned keys codes) builder) keys))
(def (graph-action source build admit guards builder affected? owned?: (owned? #f)
                   register-guards: (register register-directly))
  (lambda (old)
    (unless (or (not old) (graph-cache? old)) (error "feedback graph cache required"))
    (with-lens-checks guards (lambda ()
      (def same-source? (and old (eq? source (graph-cache-source old))))
      (def previous (and old (graph-cache-owned old)))
      (def ownership (or (and same-source? previous)
                        (and owned? (graph.%capture-component-source source register))))
      (def (prepare)
        (def frozen
          (cond (same-source? source)
                (ownership (graph.%component-source-view ownership))
                (else (freeze source))))
        (def partition
          (cond (same-source? (graph-cache-partition old))
                (ownership (scc.partition-owned frozen))
                (else (scc.partition frozen))))
        (def same-quotient? (and same-source? (eq? build (graph-cache-build old))))
        (defvalues (outcomes keys guard)
          (cond
           ((and ownership same-quotient?)
            (values (cache.%revise-with-builder (graph-cache-values old) [] builder) #f (graph-cache-guard old)))
           (ownership
            (defvalues (cache keys) (start-owned-quotient frozen partition build builder))
            (values cache #f (start-guard cache keys partition register)))
           (else
            ;; An arbitrary replacement of an owned graph acquires a fresh
            ;; schedule and values on the ordinary full path.
            (def reuse (and (not previous) old))
            (def prior (and reuse (graph-cache-values reuse)))
            (def candidate-source
              (if same-quotient? (cache.cache-source prior)
                (condense reuse frozen partition build affected?)))
            (values (if prior (cache.refresh prior candidate-source builder)
                      (cache.start candidate-source builder))
              (.get candidate-source keys) #f))))
        (admit-graph old frozen partition build ownership outcomes keys guard admit))
      (if ownership (graph.%with-component-source ownership prepare) (prepare))))))
(def (feedback-graph-action source build admit guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (graph-action source build admit guards builder #f))

(def (owned-component-revision old codes bases build admit builder register invalidation)
  (def changed (graph.%edit-component-source (graph-cache-owned old) codes bases register))
  (def next (vector-ref changed 0))
  (graph.%with-component-source next
    (lambda ()
      (def source (graph.%component-source-view next))
      (defvalues (partition seeds support)
        (scc.revise-partition (graph-cache-partition old) (vector-ref changed 1) quotient?: #t))
      (def complete? (eq? support 'complete))
      (def complete-keys (and complete? (scc.%partition-representatives partition)))
      (def edited-keys
        (if complete? complete-keys
          (let ()
            (for (node (vector-ref changed 2))
              (hash-put! seeds ((scc.partition-owner partition) node) #t))
            (scc.%partition-order-keys partition (hash-keys seeds)))))
      (def edited
        (for/collect (key edited-keys)
          (cons key (group-code partition (scc.partition-members partition key) source build))))
      (def prior (graph-cache-values old))
      (def candidate
        (cond (complete? (cache.%rebuild-owned-support prior complete-keys edited builder))
              (support (cache.%revise-with-builder prior edited builder
                         added: (scc.quotient-support-added support)
                         retired: (scc.quotient-support-retired support)
                         before?: (scc.%partition-key-before partition)))
              (else (cache.%revise-with-builder prior edited builder
                      invalidation: (and invalidation (invalidation))))))
      (def guard
        (if complete? (start-guard candidate complete-keys partition register)
          (%revise-feedback-guard (graph-cache-guard old) candidate
            (cut scc.%partition-key-position partition <>)
            (if support (scc.quotient-support-retired support) []) register)))
      (admit-graph old source partition build next candidate #f guard admit))))

;; The invalidation state supplies work for the exact old schedule only.
;; A caller cannot provide clean-owner claims. The real editor determines roots.
(def (feedback-component-revision-action fragments build admit guards: (guards [])
                                         builder: (builder (.cc cache.Builder.))
                                         invalidation: (invalidation #f))
  (%feedback-component-revision-action fragments build admit guards builder invalidation register-directly))
(def (%feedback-component-revision-action fragments build admit guards builder invalidation register)
  (lambda (old)
    (unless (graph-cache? old) (error "published feedback graph required for revision"))
    (with-lens-checks guards (lambda ()
      (def previous (graph-cache-owned old))
      (def (prepare)
        (defvalues (added removed codes bases) (component-edits fragments))
        (cond
         ((and previous (null? added) (null? removed) (eq? build (graph-cache-build old)))
          (owned-component-revision old codes bases build admit builder register invalidation))
         (else
          (def old-source (if previous (graph.%component-source-view previous raw?: #t)
                            (graph-cache-source old)))
          (defvalues (source edited) (component-source-edit old-source added removed codes bases))
          (def affected?
            (and invalidation (not previous) (eq? build (graph-cache-build old))
                 (let* ((partition (graph-cache-partition old))
                        (groups (with-list-builder (add)
                                  (for (node edited)
                                    (let (members (scc.partition-group-of partition node))
                                      (when members (add (car members))))))))
                   (cache.%cache-replacement-invalidate! (graph-cache-values old) (invalidation) groups))))
          ((graph-action source build admit guards builder affected? owned?: (and previous #t)
             register-guards: register) old))))
      (if previous (graph.%with-component-source previous prepare) (prepare))))))
;; Any partition, closure, source or joint-approval failure retains EXACT old state.
(def (publish-feedback-graph old source build admit guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (try (values ((feedback-graph-action source build admit guards: guards builder: builder) old) #f)
    (catch (failure) (values old failure))))

;; Explicit entry for a source whose subsequent edits use the publisher's
;; structured fragments. Arbitrary replacement sources remain on the cold path.
(def (publish-owned-feedback-graph source build admit guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (try (values ((graph-action source build admit guards builder #f owned?: #t) #f) #f)
    (catch (failure) (values #f failure))))

;; Compose a revision of the CURRENT published source with reconstruction on the
;; SAME old Reader input. Guards cover revision preparation and final approval;
;; the callback returns one final source, never a sequence of published stages.
(def (feedback-graph-revision-action revise build admit guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (lambda (old)
    (unless (graph-cache? old) (error "published feedback graph required for revision"))
    (with-lens-checks guards (lambda ()
      ((.call fun.Observation. .bind (.call fun.Observation. .ap (graph-cache-source old))
        (lambda (source) (feedback-graph-action (revise source) build admit guards: guards builder: builder))) old)))))
;; Preparation exceptions share the same publication boundary as closure and
;; admission: any refusal returns the exact original graph cache and exception.
(def (publish-feedback-graph-revision old revise build admit guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (try (values ((feedback-graph-revision-action revise build admit guards: guards builder: builder) old) #f)
    (catch (failure) (values old failure))))
