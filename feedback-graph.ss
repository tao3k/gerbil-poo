;;; Automatic SCC condensation feeding existing whole-group closure and caching.
(export graph-cache? graph-cache-partition graph-cache-values graph-cache-source
        graph-cache-ref feedback-graph-action publish-feedback-graph)
(import :std/iter (only-in :std/list/list filter find delete-duplicates/hash)
        ./object ./mop ./support/option ./feedback-cache ./lens-laws
        (prefix-in ./strong-components scc.) (prefix-in ./generalized-graph graph.)
        (prefix-in ./construction-cache cache.) (prefix-in ./dependency-analysis code.)
        (prefix-in ./generalized-prototype gp.))
;; Keep the frozen node source, admitted partition, builder identity and group DAG.
(defstruct graph-cache (source partition build values) final: #t)
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
  (delete-duplicates/hash (filter (lambda (key) (not (eq? key (car members))))
    (map (scc.partition-owner partition)
      (apply append (map (scc.partition-reads partition) members))))))
;; A group resolver supplies ONLY declared external node reads. Its builder must
;; close every member equation on the shared carrier using existing lens closure.
;; Internal reads belong to cooked self, not to partially constructed cache slots.
(def (group-code partition members source build)
  (def deps (dependencies partition members))
  (.cc code.Computation. reads: deps .evaluate: (lambda (provider)
    (code.make-success (build members source (lambda (node)
      (def owner ((scc.partition-owner partition) node))
      (unless (and (memq owner deps) (ormap (lambda (member)
        (memq node ((scc.partition-reads partition) member))) members)) (error "undeclared external SCC read" node))
      (def found (provider owner))
      (unless (and (some? found) (code.success? (some-value found)))
        (error "external feedback group unavailable" node))
      (code.success-value (some-value found))))))))
;; Retain a resolver only when its complete membership, footprints, member source
;; identities and builder are unchanged. Merge/split changes therefore dirty the
;; new groups even when a representative survives. Downstream dirtiness is then
;; propagated by ConstructionCache on the NEW condensation DAG.
(def (condense old source partition build)
  (def old-partition (and old (graph-cache-partition old)))
  (def old-source (and old (graph-cache-source old)))
  (graph.declaration (map car (scc.partition-groups partition))
    (map (lambda (members)
      (def key (car members))
      (def prior (and old (find (lambda (group) (eq? (car group) key))
                           (scc.partition-groups old-partition))))
      (def same? (and prior (eq? build (graph-cache-build old)) (equal? members prior)
        (equal? (dependencies partition members) (dependencies old-partition prior))
        (andmap (lambda (node)
          (and (equal? (map (scc.partition-owner partition) ((scc.partition-reads partition) node))
                       (map (scc.partition-owner old-partition) ((scc.partition-reads old-partition) node)))
               (eq? (.call source .code node) (.call old-source .code node))
               (eq? (.call source .base node) (.call old-source .base node)))) members)))
      (cons key (if same? (.call (cache.cache-source (graph-cache-values old)) .code key)
        (group-code partition members source build)))) (scc.partition-groups partition))))
;; Native FUN Reader composes partition, whole-group reconstruction and current
;; cross-service approval. Guard admission spans preparation through publication.
;; build is pure/locally total and must honor the declared component equations;
;; automatic dependency discovery inside arbitrary Scheme closures is out of scope.
(def (feedback-graph-action source build admit guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (lambda (old)
    (unless (or (not old) (graph-cache? old)) (error "feedback graph cache required"))
    (with-lens-checks guards (lambda ()
      (def frozen (freeze source))
      (def partition (scc.partition frozen))
      (def candidate-source (condense old frozen partition build))
      (def keys (map car (scc.partition-groups partition)))
      ;; Allocate exactly one candidate inside the guarded approval boundary.
      ;; Returning a second equal wrapper would break publication identity.
      (def candidate #f)
      (def action (feedback-cache-action candidate-source keys (lambda (_ values)
        (set! candidate (make-graph-cache frozen partition build values))
        (admit old candidate)) builder: builder))
      ((.call gp.Observation. .map (lambda (_) candidate) action)
        (and old (graph-cache-values old)))))))
;; Any partition, closure, source or joint-approval failure retains EXACT old state.
(def (publish-feedback-graph old source build admit guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (try (values ((feedback-graph-action source build admit guards: guards builder: builder) old) #f)
    (catch (failure) (values old failure))))
