;;; Multiple SCC merges/splits, shared migration and computed-reader changes.
(export names original merged split crossed primary secondary peer-recipes report initial envelope publish-action)
(import :std/iter (only-in :std/list/list foldl filter)
        ../object ../mop ../number ../object-contract (only-in ../type Record Tuple)
        (prefix-in ../recursive-validation graph.)
        (prefix-in ../generalized-prototype observation.)
        (prefix-in ./recursive-migration service.)
        (prefix-in ./contract-publication publication.))

;; All service keys remain stable while their peer SCCs and shared providers change.
(def names '(ingress auth billing ledger index cache notify delivery))
;; Four independent two-service cycles.
(def original '#(auth ingress ledger billing cache index delivery notify))
;; Merge both pairs of cycles at once, changing only selected consumer recipes.
(def merged '#(auth billing ledger ingress cache notify delivery index))
;; Split both quartets into different pairs.
(def split '#(billing ledger ingress auth notify delivery index cache))
;; Merge across the former quartet boundary into two alternating four-node cycles.
(def crossed '#(billing ledger index cache notify delivery ingress auth))
;; The original provider can later be removed after all consumers migrate.
(def primary (service.provider 'primary 3))
;; A second provider changes checked Function results without changing service names.
(def secondary (service.provider 'secondary 8))

;; Submit only actual recipe edits; unchanged members are rebuilt by dependency
;; propagation, including old SCC partners after edges disappear during a split.
(def (peer-recipes targets providers (weight-zero 2) (selected names))
  (filter values (map (lambda (name index)
    (and (memq name selected) (service.peer name (vector-ref targets index)
      (vector-ref providers index) (if (= index 0) weight-zero (+ index 2))))) names (iota 8))))

;; Existing Tuple normalization wraps all named references before computed report
;; evaluation. This one recipe is retained across topology and provider edits.
(def report (graph.validation-node 'report (append names '(summary)) [] (lambda (reference source)
  (def descriptor (Record services: [(apply Tuple (map reference names))]
    summary: [(reference 'summary)] total: [Integer compute: (lambda (self _next)
      (+ (foldl + 0 (map (lambda (service) ((.get service handler) 1)) (vector->list (.get self services))))
         (.get self summary total)))]))
  (list descriptor (.o (:: self (.get descriptor proto))
    services: (list->vector (map source names)) summary: (source 'summary))))))

;; Build a starting graph through the existing finite closure engine and recipes.
(def (initial)
  (graph.revise-validation #f (append [primary]
    (peer-recipes original (make-vector 8 'primary))
    [(service.summary 'ingress) report service.idle service.meter])))

;; Refinement checks actual canonical peers, shared providers, chosen computed
;; reader and checked peer-method capture. Numeric totals alone cannot prove this.
(def (envelope current expected targets providers chosen)
  (refine (.cc ObjectContract. responsibilities: (.o report: (graph.closed-type current 'report)))
    (lambda (candidate location)
      (def root (.get candidate report))
      (if (and (= (.get root total) expected)
        (eq? (.get root summary reader) (graph.closed-ref current chosen))
        (andmap (lambda (node index)
          (and (eq? (.get node peer) (graph.closed-ref current (vector-ref targets index)))
               (eq? (.get node shared) (graph.closed-ref current (vector-ref providers index)))
               (eq? (.get node peer-handler) (.get node peer handler))))
          (vector->list (.get root services)) (iota 8))) []
        [(.o kind: 'recursive-topology path: location)]))))

;; FUN Reader refinement composes the existing exact bound-evidence effect gate.
;; Graph revision and effect publication remain separate sequential boundaries.
(def (publish-action current expected targets providers chosen invocation context-value)
  (.call observation.Observation. .bind
    (lambda (_) (envelope current expected targets providers chosen))
    (lambda (descriptor-value)
      (publication.publication-action descriptor-value invocation context-value
        (lambda (checked)
          (values (.o subject: checked descriptor: descriptor-value context: context-value
                       total: (.get checked report total))
                  (.cc context-value commits: (+ 1 (.get context-value commits)))))))))
