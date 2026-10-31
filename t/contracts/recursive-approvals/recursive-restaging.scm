;;; Current-catalog preparation with multiple generations of pending requests.



;; Match the actual validation boundary, not an unrelated preparation exception.
(def (phase? expected)
  (lambda (cause) (and (graph.validation-failure? cause)
    (eq? expected (graph.validation-failure-kind cause)))))

;; Reuse exact evidence binding with an independent always-admitting call policy.
(def Call (metadata.contract (metadata.predicate "object" object?)
  (metadata.predicate "evidence" object?) (lambda (_ _request _result) #t) metadata.truth))

;; Eight rounds deliberately revisit old memberships and SCC layouts. Each round
;; prepares fresh work BEFORE draining historical requests, refuses late admission,
;; explicitly prepares again, and publishes through refine/bind-evidence.
(def recursive-restaging-test
  (test-suite "cross-round recursive restaging"
    (test-case "pending generations cannot revive after provider and SCC restoration"
      (let* ((first (recursive-restaging.service.initial))
             (old-root (graph.closed-ref first 'report))
             (old-type (graph.closed-type first 'report))
             (idle (graph.closed-ref first 'idle))
             (idle-type (graph.closed-type first 'idle))
             (primary (make-vector 8 'primary))
             (secondary (make-vector 8 'secondary))
             (mixed '#(secondary secondary secondary secondary primary primary primary primary))
             (rounds (list
               (list recursive-restaging.service.merged mixed 'notify 108 2)
               (list recursive-restaging.service.split secondary 'auth 128 2)
               (list recursive-restaging.service.crossed secondary 'cache 132 2)
               (list recursive-restaging.service.original primary 'ingress 82 2)
               (list recursive-restaging.service.merged mixed 'notify 108 2)
               (list recursive-restaging.service.split secondary 'auth 128 2)
               (list recursive-restaging.service.original secondary 'delivery 134 2)
               (list recursive-restaging.service.original secondary 'delivery 135 3))))
        (let loop ((rounds rounds) (current first) (history []) (context-value (.o commits: 0)))
          (if (null? rounds)
            (begin
              (check-equal? (.get context-value commits) 8)
              (check (eq? idle (validate idle-type idle)) => #t)
              (check-exception (validate old-type old-root) (phase? 'stale)))
            (let* ((round (car rounds)) (targets (car round)) (providers (cadr round))
                   (chosen (caddr round)) (expected (cadddr round)) (weight (car (cddddr round)))
                   (prepare (restaging.transition-action targets providers chosen #t weight))
                   (fresh (prepare current))
                   (failed ((restaging.transition-action targets providers chosen #f weight) current))
                   (previous-root (graph.closed-ref current 'report))
                   (previous-type (graph.closed-type current 'report))
                   (partition (recursive-restaging.topology.partition current)))
              (for-each (lambda (request) (check-exception (request current) (phase? 'stale))) history)
              (check-exception (failed current) (phase? 'admission))
              (check (eq? previous-root (validate previous-type previous-root)) => #t)
              (check-equal? (recursive-restaging.topology.changed-members partition (recursive-restaging.topology.partition current)) [])
              ;; Re-preparation is explicit and observes the still-current catalog.
              (let* ((retry (prepare current)))
                (let-values (((next evidence state refusal)
                    ((recursive-restaging.workflow.publication-action retry expected targets providers chosen Call context-value) current)))
                  (check refusal => #f)
                  (check-equal? (.get evidence total) expected)
                  (check-exception (validate previous-type previous-root) (phase? 'stale))
                  (check-exception (fresh next) (phase? 'stale))
                  (check-exception (failed next) (phase? 'stale))
                  (for-each (lambda (request) (check-exception (request next) (phase? 'stale))) history)
                  (loop (cdr rounds) next (cons fresh (cons failed history)) state))))))))
    (test-case "failed preparation returns no request and leaves the current graph valid"
      (let* ((current (recursive-restaging.service.initial)) (root (graph.closed-ref current 'report))
             (type (graph.closed-type current 'report))
             (prepare (staging.restaging-action (lambda (_) (raise 'preparation-refusal)))))
        (check-exception (prepare current) (lambda (cause) (eq? cause 'preparation-refusal)))
        (check (eq? root (validate type root)) => #t)))))

;; Return the original suites from this lexical scope.
(values recursive-restaging-test)
