;;; Membership edits, shared-provider migration and computed-reader replacement.
(export provider peer summary report meter idle envelope publish-action)
(import ../object
        ../mop
        ../number
        ../object-contract
        (only-in ../type Record)
        (runtime: :clan/poo/recursive-validation)
        (prefix-in (only-in ../recursive-validation closed-ref closed-type
                   validation-node) graph.)
        (runtime: :clan/poo/fun)
        (prefix-in ./contract-publication publication.)
        (prefix-in (only-in :clan/poo/fun Observation.) fun.))

;; A provider recipe may be removed and later resubmitted with the SAME identity.
;; Reclosure must still allocate a new receiver and Reference capability for it.
(def (provider name delta)
  (graph.validation-node name [] [] (lambda (_reference _source)
    (def descriptor (Record handler: [(Fun Integer <- Integer)
      compute: (lambda (_self _next) (lambda (value) (+ value delta)))]))
    (list descriptor (.o (:: self (.get descriptor proto)))))))

;; Peer links form an SCC; the shared provider is an explicit declared dependency.
;; Final-self computation captures the newly checked provider Function each round.
(def (peer name other provider-name weight)
  (graph.validation-node name (list other provider-name) [] (lambda (reference source)
    (def descriptor (Record peer: [(reference other)] shared: [(reference provider-name)]
      handler: [(Fun Integer <- Integer) compute: (lambda (self _next)
        (def checked (.get self shared handler)) (lambda (value) (+ weight (checked value))))]
      peer-handler: [Any compute: (lambda (self _next) (.get self peer handler))]))
    (list descriptor (.o (:: self (.get descriptor proto)) peer: (source other) shared: (source provider-name))))))

;; This computed reader chooses one service. Replacing its recipe changes the
;; declared footprint and rebinds the checked target even if the numeric result is
;; unchanged. Optional final refusal tests complete normalization before failure.
(def (summary target (accept? #t))
  (graph.validation-node 'summary [target] [] (lambda (reference source)
    (def base (Record reader: [(reference target)]
      total: [Integer compute: (lambda (self _next) ((.get self reader handler) 1))]))
    (def descriptor (if accept? base (.cc base .element?: (lambda (_) #f))))
    (list descriptor (.o (:: self (.get descriptor proto)) reader: (source target))))))

;; One report recipe survives every round: declared readers, not manual revision
;; labels, cause its computed total to rebuild when either peer or summary changes.
(def report (graph.validation-node 'report '(left right summary) [] (lambda (reference source)
  (def descriptor (Record left: [(reference 'left)] right: [(reference 'right)]
    summary: [(reference 'summary)] total: [Integer compute: (lambda (self _next)
      (+ ((.get self left handler) 1) ((.get self right handler) 1) (.get self summary total)))]))
  (list descriptor (.o (:: self (.get descriptor proto))
    left: (source 'left) right: (source 'right) summary: (source 'summary))))))

;; A newly added downstream observer follows report identity across later rounds.
(def meter (graph.validation-node 'meter '(report) [] (lambda (reference source)
  (def descriptor (Record report: [(reference 'report)]
    total: [Integer compute: (lambda (self _next) (.get self report total))]))
  (list descriptor (.o (:: self (.get descriptor proto)) report: (source 'report))))))

;; The independent node must retain canonical identity and cache across all edits.
(def idle (graph.validation-node 'idle [] [] (lambda (_reference _source)
  (list (Record value: [Integer]) (.o value: 99)))))

;; Current root refinement checks shared aliases, checked peer capture and computed
;; results. The report Reference additionally checks its reachable final obligations.
(def (envelope graph expected target)
  (refine (.cc ObjectContract. responsibilities: (.o report: (graph.closed-type graph 'report)))
    (lambda (candidate location)
      (def root (.get candidate report))
      (if (and (= (.get root total) expected)
               (eq? (.get root left shared) (.get root right shared))
               (eq? (.get root left peer) (.get root right))
               (eq? (.get root right peer) (.get root left))
               (eq? (.get root summary reader) (graph.closed-ref graph target))
               (eq? (.get root left peer-handler) (.get root right handler))) []
        [(.o kind: 'migration-refinement path: location)]))))

;; Existing FUN Reader and publication actions bind actual checked subject,
;; descriptor and context. Membership commit precedes this separate effect gate.
(def (publish-action graph expected target invocation context-value)
  (.call fun.Observation. .bind
    (lambda (_) (envelope graph expected target))
    (lambda (descriptor-value)
      (publication.publication-action descriptor-value invocation context-value
        (lambda (checked)
          (values (.o subject: checked descriptor: descriptor-value context: context-value
                       total: (.get checked report total))
                  (.cc context-value commits: (+ 1 (.get context-value commits)))))))))
