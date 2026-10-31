;;; Pair → Map → Sum → Union → refined Function fields in one FUN workflow.
(export TransformSchema Operation RoutingSchema routing-action)
(import ../object
        ../mop
        ../number
        ../object-contract
        (only-in ../type Pair Map Sum Union String)
        (runtime: :clan/poo/fun)
        (prefix-in ./object-contracts service.)
        (prefix-in ./contract-publication publication.)
        (prefix-in (only-in :clan/poo/fun Observation.) fun.))

;; A named callback schema keeps its normal field/refinement protocol when used
;; as an untagged Union alternative inside a tagged Sum and a Map value.
(def TransformSchema
  (refine (.cc ObjectContract. responsibilities: (.o tenant: String run: (Fun Integer <- Integer)))
    (lambda (candidate location)
      (if (positive? (string-length (.get candidate tenant))) '()
        [(.o kind: 'empty-tenant path: (append location '(tenant)))]))))

;; The first structurally matching Union branch owns its validation. Function
;; invocation errors never select another branch or a different Sum payload.
(def Operation (Sum active: (Union TransformSchema (Fun Integer <- Integer)) disabled: Integer))

;; Pair preserves an audit callback separately from the Map's tagged operations.
;; Whole-root refinement observes only fully normalized selected branches.
(def RoutingSchema
  (refine (.cc ObjectContract. responsibilities:
            (.o config: publication.CapacityContract routes: (Pair (Map Operation <- String)
                                                                 (Fun Bool <- Integer))))
    (lambda (candidate location)
      (if (andmap (lambda (operation)
                    (or (not (eq? (.get operation tag) 'active))
                        (procedure? (.get operation value))
                        (equal? (.get operation value tenant) (.get candidate config host))))
                  (hash-values (car (.get candidate routes)))) '()
        [(.o kind: 'tenant-mismatch path: (append location '(routes car)))]))))

;; Execute deterministic route names through the existing checked callbacks;
;; hash traversal order never becomes an application scheduling policy.
(def (produce context-value checked-value)
  (def routes-value (.get checked-value routes))
  (def used (.get checked-value config used))
  (def totals-value
    (map (lambda (name)
           (def operation (hash-ref (car routes-value) name))
           (def payload (.get operation value))
           (if (eq? (.get operation tag) 'disabled) payload
             ((if (procedure? payload) payload (.get payload run)) used)))
         '("primary" "secondary")))
  (def approval-value ((cdr routes-value) (apply + totals-value)))
  (values (.o subject: checked-value descriptor: RoutingSchema context: context-value
              totals: totals-value approved: approval-value)
          (.cc context-value commits: (+ 1 (.get context-value commits)))))

;; Compose JSON configuration with supplied executable routes through Reader/FUN,
;; then bind evidence to the returned normalized root and current context.
(def (routing-action invocation context-value routes-value)
  (def publish (publication.publication-action RoutingSchema invocation context-value
                 (cut produce context-value <>)))
  (.call fun.Observation. .bind
    (lambda (text) (.o config: (service.decode-service text) routes: routes-value))
    (lambda (candidate) (lambda (_text) (publish candidate)))))
