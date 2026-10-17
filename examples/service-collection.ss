;;; Gerbil Iterable classes over checked POO services and source-bound snapshots.
(export make-services observe-services observe-cached-services)
(import :std/iter (prefix-in :std/instance std.)
        (only-in ../table iterator-map)
        ../object ../mop ../object-contract-flow ../support/option
        (prefix-in ../construction-cache cache.)
        (prefix-in ../dependency-analysis code.))

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
