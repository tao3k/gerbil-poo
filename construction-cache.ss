;;; ConstructionCache: source-bound selective materialization; no resolver on hits.
(export Builder. start refresh cache? cache-source cache-ref cache-evaluated cache-reused
        failure? failure-key failure-cause)
(import (only-in :std/hash/misc hash-ref/default) :std/iter ./object (only-in ./mop define-type) ./support/option
        (prefix-in ./generalized-graph graph.) (prefix-in ./dependency-analysis computation.))
(defstruct cache (source lookup evaluated reused scheduled) final: #t)
(defstruct failure (key cause) final: #t)
;; Expose one source-bound lookup; ordinary absence may itself be cached.
(def (cache-ref cache key) ((cache-lookup cache) key))
(define-type (Builder. @ [])
  allow: (lambda (_) #t)
  .run: (lambda (key resolve) (unless (allow key) (error "component builder refused" key)) (resolve)))
;; Refuse malformed resolver outcomes before storing private results.
(def (checked value)
  (unless (or (not value) (and (some? value)
              (or (computation.success? (some-value value)) (computation.error? (some-value value)))))
    (error "component resolver must return an optional outcome")) value)
(def default-builder (.cc Builder.))
;; Reuse clean nodes while the standard table API retains lazy absence semantics.
(def (materialize old scheduled builder)
  (def spec (graph.schedule-source scheduled))
  (def state (make-hash-table-eq))
  (def dirty (make-hash-table-eq))
  (def evaluated [])
  (def reused [])
  (for (key (graph.schedule-order scheduled))
    (def code (.call spec .code key))
    (def deps ((graph.schedule-reads scheduled) key))
    ;; New support may merge/split SCCs. Only an existing slot with identical
    ;; code/base and clean declared readers can survive; new slots always build.
    (def invalid? (or (not old) (not (memq key (.@ (cache-source old) keys)))
      (not (eq? code (.call (cache-source old) .code key)))
      (not (eq? (.call spec .base key) (.call (cache-source old) .base key)))
      (ormap (cut hash-ref dirty <>) deps)))
    (hash-put! dirty key invalid?)
    (if (not invalid?)
      (begin (hash-put! state key (cache-ref old key)) (set! reused (cons key reused)))
      (let (value
        (try (checked (.call builder .run key
          (lambda ()
            (if code (some (.call code .evaluate
              (lambda (dep)
                (unless (memq dep deps) (error "undeclared component read" key dep))
                (hash-ref state dep)))) (.call spec .base key)))))
          (catch (cause) (raise (make-failure key cause)))))
        (hash-put! state key value) (set! evaluated (cons key evaluated)))))
  (make-cache spec (lambda (key) (hash-ref/default state key (lambda () (.call spec .base key))))
    (reverse evaluated) (reverse reused) scheduled))
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
(def (start spec (builder default-builder)) (materialize #f (graph.schedule (freeze spec)) builder))
;; Retain the exact immutable owner or selectively rebuild its changed dependency cone.
(def (refresh old spec (builder default-builder))
  (if (eq? spec (cache-source old))
    ;; Same immutable source: retain lookup and checked schedule, reset work trace.
    (make-cache spec (cache-lookup old) [] (graph.schedule-order (cache-scheduled old)) (cache-scheduled old))
    (materialize old (graph.reschedule (cache-scheduled old) (freeze spec)) builder)))
