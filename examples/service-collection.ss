;;; Gerbil Iterable classes over checked POO services and source-bound snapshots.
(export approved-ledger-action ledger-action make-services observe-services observe-cached-services prepare-ledger-revision apply-ledger-revision transport-ledger-action)
(import :std/iter (prefix-in :std/instance std.)
        (only-in ../table iterator-map)
        ../object ../mop ../object-contract ../object-contract-flow ../support/option
        (prefix-in ../construction-cache cache.)
        (prefix-in ../dependency-analysis code.)
        (only-in ../generalized-prototype Observation.))

;; Host ownership uses generated class fields; POO retains descriptor semantics.
(defstruct %services (descriptor rows) final: #t)
;; Delegate interface registration and class-aware receiver binding to std/instance.
;; The existing Iterator mapper validates one row per pull, without a new iterator engine.
(std.instance Iterable (self %services)
  ((iter) (iterator-map (checked-action self.descriptor identity) self.rows)))

;; Require finite host input while keeping descriptor validation in the POO protocol.
;; Creating the collection or its iterator does not normalize any service row.
(def (make-services descriptor rows)
  (validate Type descriptor)
  (using (rows :~ list?) (make-%services descriptor rows)))

;; Each ordered pull completes recursive wrapping/refinement before this IO consumer.
;; Return one observation per row; callback failures propagate, with prior effects retained.
(def (observe-services descriptor rows consume)
  (using (consume :~ procedure?)
    (for/collect (checked (make-services descriptor rows)) (consume checked))))

;; Observe a completed source-bound cache entry; absence and source failure refuse.
;; Cached raw rows are freshly admitted for each observation, never cached approvals.
(def (observe-cached-services snapshot key descriptor consume)
  (let (entry (cache.cache-ref snapshot key))
    (unless (and (some? entry) (code.success? (some-value entry)))
      (error "required service collection unavailable" key))
    (observe-services descriptor (code.success-value (some-value entry)) consume)))

;; Consume a normalized ledger without validating it again. The callback completes
;; before IO; its error suppresses consume and preserves prior external effects.
(def (consume-ledger descriptor key argument consume ledger)
  (let* ((callback (vector-ref (car (.call descriptor .ref ledger key)) 0))
         (result (callback argument)))
    (consume result)
    (values result (.call descriptor .count ledger))))

;; FUN passes a recursively normalized List/Tuple/Function table into lookup once.
;; Source remains persistent; a fresh invocation can retry after a refused request.
(def (ledger-action descriptor key argument consume)
  (checked-action descriptor (cut consume-ledger descriptor key argument consume <>)))

;; Named-schema refinement observes a normalized persistent table before IO. The
;; same consumer receives its already wrapped callbacks, without revalidating the
;; ledger. A false approval or bad callback result cannot reach the IO consumer.
(def (approved-ledger-action descriptor key argument consume)
  ;; Use the existing ObjectContract/refine chain; no table-specific approval API.
  (def submission (refine
    (.cc ObjectContract. responsibilities: (.o approved: Bool ledger: descriptor))
    (lambda (candidate location)
      (if (.@ candidate approved) '()
        [(.o kind: 'approval-refused path: (append location '(approved)))]))))
  (checked-action submission
    (lambda (candidate)
      (consume-ledger descriptor key argument consume (.@ candidate ledger)))))

;; Admit a proposed ledger through Reader/FUN once, retaining recursive Function
;; wrappers inside the generated delta. Before is a previously admitted snapshot.
;; Full admission may create fresh wrapper identities; use .diff directly between
;; admitted snapshots when unchanged callbacks must retain identity. Discovery
;; failure suppresses the consumer; no IO or source mutation occurs here.
(def (prepare-ledger-revision descriptor before)
  (checked-action descriptor (cut .call descriptor .diff before <>)))

;; Compose optimistic installation with an IO consumer through the existing FUN
;; map. The supplied current ledger is already admitted; revalidation here would
;; create new Function identities and invalidate legitimate captured expectations.
;; A conflict suppresses IO, leaving callers free to rediscover against the winner.
(def (apply-ledger-revision descriptor delta consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (cut .call descriptor .apply-delta <> delta))))

;; Compose explicit collection/delta conversion, target installation and IO through
;; the existing Reader/FUN maps. Input is an admitted (base . delta) pair; every
;; conversion/law/conflict refusal suppresses consume, and no Function is rewrapped.
(def (transport-ledger-action mapping consume)
  (using (consume :~ procedure?)
    (def target (.@ mapping Codomain))
    (def changes (.@ mapping Delta))
    (.call Observation. .map consume
      (.call Observation. .map
        (lambda (staged) (.call target .apply-delta (car staged) (cdr staged)))
        (cut .call changes .ap <>)))))
