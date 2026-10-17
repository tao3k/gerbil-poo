;;; Finite named schemas, heterogeneous tuples and lists in one FUN workflow.
(export TaskSchema BatchSchema batch-action)
(import (only-in :std/list/list foldl)
        ../object ../mop ../number ../object-contract
        (only-in ../type String List Tuple)
        (prefix-in ../generalized-prototype observation.)
        (prefix-in ./object-contracts service.)
        (prefix-in ./contract-publication publication.))

;; A finite named-field schema uses the existing structural descriptor. Its
;; obligation sees the normalized callback; no separate schema DSL is needed.
(def TaskSchema
  (refine (.cc ObjectContract. responsibilities:
            (.o tenant: String handlers: (Tuple (Fun Integer Bool <- Integer)
                                               (List (Fun Integer <- Integer)))))
    (lambda (task location)
      (if (positive? (length (vector-ref (.get task handlers) 1))) '()
        [(.o kind: 'missing-transform path: (append location '(handlers 1)))]))))

;; Compose container nesting in both directions: each tuple contains a list of
;; functions, and the root list contains refined named-field schemas.
(def BatchSchema
  (refine (.cc ObjectContract. responsibilities:
            (.o config: publication.CapacityContract tasks: (List TaskSchema)))
    (lambda (candidate location)
      (if (andmap (lambda (task) (equal? (.get task tenant) (.get candidate config host)))
                  (.get candidate tasks)) '()
        [(.o kind: 'tenant-mismatch path: (append location '(tasks)))]))))

;; Preserve multiple returned values and order the downstream transforms through
;; ordinary foldl. Bind only the final root, never raw containers or source refs.
(def (produce context-value checked-value)
  (def used (.get checked-value config used))
  (def totals-value
    (map (lambda (task)
           (def handlers-value (.get task handlers))
           (defvalues (units ready) ((vector-ref handlers-value 0) used))
           (if ready
             (foldl (lambda (transform value) (transform value)) units (vector-ref handlers-value 1))
             units))
         (.get checked-value tasks)))
  (values (.o subject: checked-value descriptor: BatchSchema context: context-value totals: totals-value)
          (.cc context-value commits: (+ 1 (.get context-value commits)))))

;; Existing JSON I/O and Observation Reader/FUN compose before checked publication.
;; Every request validates its own containers; no accepted-value cache is shared.
(def (batch-action invocation context-value tasks-value)
  (def publish (publication.publication-action BatchSchema invocation context-value
                 (cut produce context-value <>)))
  (.call observation.Observation. .bind
    (lambda (text) (.o config: (service.decode-service text) tasks: tasks-value))
    (lambda (candidate) (lambda (_text) (publish candidate)))))
