;;; ConstructionCache: source-bound selective materialization; no resolver on hits.
(export Builder. start refresh cache? cache-source cache-ref cache-evaluated cache-reused
        start-owned revision refresh-revision cache-work
        %revise-with-builder %rebuild-owned-support
        cache-invalidation cache-invalidate!
        failure? failure-key failure-cause)
(import (only-in :std/hash/misc hash-ref/default)
        (only-in :std/struct/rbtree RBTree rbtree-copy rbtree-ref rbtree-put!)
        :std/iter ./object (only-in ./mop define-type) ./support/option
        (only-in ./support/base %compare-symbol-identity)
        (only-in ./lens-laws with-lens-checks)
        (only-in ./slot-observation %call-with-recorded-slot-reads)
        (prefix-in ./generalized-graph graph.) (prefix-in ./dependency-analysis computation.))
(defstruct cache (source lookup evaluated retained scheduled base patch guards owned-run work) final: #t)
(defstruct failure (key cause) final: #t)
;; Expose one source-bound lookup; ordinary absence may itself be cached.
(def (cache-ref cache key) ((cache-lookup cache) key))
(def (cache-reused cache) (force (cache-retained cache)))
(define-type (Builder. @ [])
  allow: (lambda (_) #t)
  .run: (lambda (key resolve) (unless (allow key) (error "component builder refused" key)) (resolve)))
;; Refuse malformed resolver outcomes before storing private results.
(def (checked value)
  (unless (or (not value) (and (some? value)
              (or (computation.success? (some-value value)) (computation.error? (some-value value)))))
    (error "component resolver must return an optional outcome")) value)
(def default-builder (.cc Builder.))
(def missing-value (gensym 'missing-component-value))
(def pending-value (gensym 'pending-component-value))
(def (make-materialized scheduled state patch evaluated retained guards owned-run work)
  (def spec (graph.schedule-source scheduled))
  (def (lookup-base key)
    (if (and guards (not (symbol? key))) (.call spec .base key)
      (hash-ref/default state key (lambda () (.call spec .base key)))))
  (def lookup
    (if patch
      (lambda (key)
        (let (value (if (symbol? key) (rbtree-ref patch key missing-value) missing-value))
          (if (eq? value missing-value) (lookup-base key) value)))
      lookup-base))
  (make-cache spec lookup evaluated retained scheduled state patch guards owned-run work))
(def (evaluate-one spec run key code deps lookup)
  (try (checked (run key
    (lambda ()
      (if code (some (.call code .evaluate
        (lambda (dep)
          (unless (memq dep deps) (error "undeclared component read" key dep))
          (lookup dep)))) (.call spec .base key)))))
    (catch (cause) (raise (make-failure key cause)))))
;; Reuse the existing source guards. Check again on successful return before
;; exposing the candidate. An error keeps its original owner and cause.
(def (with-cache-guards guards action)
  (let (result (with-lens-checks guards action))
    (with-lens-checks guards (lambda () result))))
;; Reuse clean nodes while the standard table API retains lazy absence semantics.
(def (materialize old scheduled run (guards #f) (owned-run #f))
  (def spec (graph.schedule-source scheduled))
  (def state (if guards (make-hash-table-symbolic) (make-hash-table-eq)))
  (def dirty (and old (make-hash-table-eq)))
  (def evaluated [])
  (def reused [])
  (for (key (graph.schedule-order scheduled))
    (def deps ((graph.schedule-reads scheduled) key))
    ;; New support may merge/split SCCs. Only an existing slot with identical
    ;; code/base and clean declared readers can survive; new slots always build.
    (def invalid? (or (not old) (not (graph.schedule-supports? (cache-scheduled old) key))
      (not (graph.%schedule-same-program? (cache-scheduled old) scheduled key))
      (not (eq? (.call spec .base key) (.call (cache-source old) .base key)))
      (ormap (cut hash-ref dirty <>) deps)))
    (when dirty (hash-put! dirty key invalid?))
    (if (not invalid?)
      (begin (hash-put! state key (cache-ref old key)) (set! reused (cons key reused)))
      (let (value (evaluate-one spec run key (.call spec .code key) deps (cut hash-ref state <>)))
        (hash-put! state key value) (set! evaluated (cons key evaluated)))))
  (make-materialized scheduled state #f (reverse evaluated) (delay (reverse reused)) guards owned-run #f))
;; Snapshot declared source entries, including false; fallback only for unknown keys.
(def (freeze spec)
  (def programs (make-hash-table-eq))
  (def values (make-hash-table-eq))
  (for (key (.@ spec keys))
    (hash-put! programs key (.call spec .code key))
    (hash-put! values key (.call spec .base key)))
  (.cc spec
    .code: (lambda (key) (hash-ref/default programs key (lambda () (.call spec .code key))))
    .base: (lambda (key) (hash-ref/default values key (lambda () (.call spec .base key))))))
;; Freeze and schedule one cold declaration before materialization.
(def (builder-run builder) (lambda (key resolve) (.call builder .run key resolve)))
(def (start spec (builder default-builder))
  (materialize #f (graph.schedule (freeze spec)) (builder-run builder)))
;; Retain the exact immutable owner or selectively rebuild its changed dependency cone.
(def (refresh old spec (builder default-builder))
  (def guards (cache-guards old))
  (def owned-run (cache-owned-run old))
  (cond
   ((eq? spec (cache-source old))
    (def scheduled (cache-scheduled old))
    (def (retain)
      (make-cache spec (cache-lookup old) [] (delay (graph.schedule-order scheduled)) scheduled
        (cache-base old) (cache-patch old) guards owned-run #f))
    (if guards (with-cache-guards guards (lambda () (owned-run (lambda (_) (retain)))))
      (retain)))
   ;; A different source gives no authority to inherit an owned value snapshot.
   (guards (start spec builder))
   (else (materialize old (graph.reschedule (cache-scheduled old) (freeze spec)) (builder-run builder)))))

;; The owned lane uses the same materializer and builder contract. Opaque
;; external source/effect dependencies remain subject to the owner's guards.
(def (record-builder builder)
  (defvalues (run support) (%call-with-recorded-slot-reads (lambda () (.get builder .run))))
  (lambda (action) (call-with-current-slot-reads support (lambda (_) (action run)))))
(def (start-owned scheduled (builder default-builder) guards: (guards []))
  (unless (graph.schedule-owned? scheduled) (error "owned schedule required"))
  (with-cache-guards guards
    (lambda ()
      (def owned-run (record-builder builder))
      (owned-run (lambda (run) (materialize #f scheduled run (list-copy guards) owned-run))))))
(def (owned-guards old)
  (or (cache-guards old) (error "owned construction cache required")))
;; Feedback publication supplies a fresh Builder per request. It runs only
;; the affected values, preserving the established reuse contract.
(def (%revise-with-builder old codes builder added: (added []) retired: (retired []) before?: (before? #f))
  (def guards (owned-guards old))
  (with-cache-guards guards
    (lambda ()
      (def owned-run (record-builder builder))
      (def ticket (owned-run (lambda (_)
        (if before?
          (graph.%schedule-support-revision (cache-scheduled old) codes added retired before?)
          (graph.schedule-revision (cache-scheduled old) codes)))))
      (refresh-with-run old ticket guards owned-run))))
(def (%rebuild-owned-support old keys codes builder)
  (def guards (owned-guards old))
  (with-cache-guards guards
    (lambda ()
      (def owned-run (record-builder builder))
      (owned-run (lambda (run)
        (def next (graph.%reschedule-owned-support (cache-scheduled old) keys codes))
        (materialize old next run guards owned-run))))))
(def (revision old codes (bases []))
  (with-cache-guards (owned-guards old)
    (lambda () ((cache-owned-run old) (lambda (_) (graph.schedule-revision (cache-scheduled old) codes bases))))))
(def (refresh-revision old ticket)
  (def guards (owned-guards old))
  (def owned-run (cache-owned-run old))
  (with-cache-guards guards (lambda () (refresh-with-run old ticket guards owned-run))))
(def (refresh-with-run old ticket guards owned-run)
  (defvalues (scheduled affected inverse-work)
    (graph.apply-schedule-revision (cache-scheduled old) ticket affected?: #t))
  (def retired (graph.%schedule-revision-retirements ticket))
  (def spec (graph.schedule-source scheduled))
  (def prior-patch (cache-patch old))
  (def patch (if prior-patch (rbtree-copy prior-patch) (RBTree %compare-symbol-identity)))
  (for (key retired) (rbtree-put! patch key #f))
  (def pending (make-hash-table-eq))
  (for (key affected) (hash-put! pending key pending-value))
  (def (resolve key)
    (let (value (hash-ref pending key missing-value))
      (cond
       ((eq? value missing-value) (cache-ref old key))
       ((eq? value pending-value) (error "affected provider not built" key))
       (else value))))
  (owned-run
    (lambda (run)
      (for (key affected)
        (def value (evaluate-one spec run key (.call spec .code key)
                      ((graph.schedule-reads scheduled) key) resolve))
        (hash-put! pending key value)
        (rbtree-put! patch key value))))
  (def width (length affected))
  (def receipt (.o graph: (graph.schedule-work scheduled)
    inverse-buckets: (vector-ref inverse-work 0) inverse-edges: (vector-ref inverse-work 1)
    evaluated-owners: width value-patch-writes: (+ width (length retired))))
  (make-materialized scheduled (cache-base old) patch affected
    (delay (filter (lambda (key) (not (hash-key? pending key))) (graph.schedule-order scheduled)))
    guards owned-run receipt))

;; Reuse the cache's admitted condensation schedule. Never expose its table.
(def (cache-invalidation current) (graph.schedule-invalidation (cache-scheduled current)))
(def (cache-invalidate! current work roots)
  (graph.schedule-invalidate! (cache-scheduled current) work roots))
