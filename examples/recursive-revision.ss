;;; Revision of a cyclic service pair sharing a checked Function provider.
(export recipes envelope publish-action)
(import ../object ../mop ../number ../object-contract
        (only-in ../type Record)
        (prefix-in ../recursive-validation graph.)
        (prefix-in ../generalized-prototype observation.)
        (prefix-in ./contract-publication publication.))

;; Recipes are immutable revision tokens. Shared changes rebuild both readers,
;; their SCC and the report; changing one peer retains the shared provider/idle.
(def (recipes settings (left-weight 2))
  (def Handler (Fun Integer <- Integer))
  ;; Read watched configuration only through each new final receiver's formula.
  (def shared (graph.validation-node 'shared [] [settings]
    (lambda (_reference _source)
      (def descriptor (Record handler: [Handler compute: (lambda (_self _next)
        (def delta (.get settings delta)) (lambda (value) (+ value delta)))]))
      (list descriptor (.o (:: self (.get descriptor proto)))))))
  ;; Delay the cyclic peer read until every raw receiver has been registered.
  ;; Computed peer-handler captures a checked peer method, not the raw function.
  (def (peer name other weight)
    (graph.validation-node name (list other 'shared) []
      (lambda (reference source)
        (def descriptor (Record peer: [(reference other)] shared: [(reference 'shared)]
          handler: [Handler compute: (lambda (self _next)
            (def checked (.get self shared handler))
            (lambda (value) (+ weight (checked value))))]
          peer-handler: [Any compute: (lambda (self _next) (.get self peer handler))]))
        (list descriptor (.o (:: self (.get descriptor proto))
          peer: (source other) shared: (source 'shared))))))
  (def report (graph.validation-node 'report '(left right shared) []
    (lambda (reference source)
      (def descriptor (Record left: [(reference 'left)] right: [(reference 'right)]
        shared: [(reference 'shared)]
        total: [Integer compute: (lambda (self _next)
          (+ ((.get self left handler) 1) ((.get self right handler) 1)))]))
      (list descriptor (.o (:: self (.get descriptor proto))
        left: (source 'left) right: (source 'right) shared: (source 'shared))))))
  (def idle (graph.validation-node 'idle [] []
    (lambda (_reference _source) (list (Record value: [Integer]) (.o value: 99)))))
  (list shared (peer 'left 'right left-weight) (peer 'right 'left 3) report idle))

;; Refinement observes canonical sharing, the current computed total and rebinding
;; of peer captures. Reference validation reruns reachable final obligations.
(def (envelope graph expected)
  (refine (.cc ObjectContract. responsibilities: (.o report: (graph.closed-type graph 'report)))
    (lambda (candidate location)
      (def report (.get candidate report))
      (if (and (= (.get report total) expected)
               (eq? (.get report left peer) (.get report right))
               (eq? (.get report right peer) (.get report left))
               (eq? (.get report shared) (.get report left shared))
               (eq? (.get report shared) (.get report right shared))
               (eq? (.get report left peer-handler) (.get report right handler))) []
        [(.o kind: 'revision-sharing path: location)]))))

;; Reader composition retains exact checked subject/descriptor/context binding.
;; Graph revision and effect publication remain separate caller-owned boundaries.
(def (publish-action graph expected invocation context-value)
  (.call observation.Observation. .bind
    (lambda (_input) (envelope graph expected))
    (lambda (descriptor-value)
      (publication.publication-action descriptor-value invocation context-value
        (lambda (checked)
          (values (.o subject: checked descriptor: descriptor-value context: context-value
                       total: (.get checked report total))
                  (.cc context-value commits: (+ 1 (.get context-value commits)))))))))
