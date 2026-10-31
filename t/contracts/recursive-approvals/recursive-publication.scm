;;; Shared graph head across independently bound entry-point effects.



;; Require the lifecycle phase so an arbitrary callback exception cannot pass.
(def (phase? expected)
  (lambda (cause) (and (graph.validation-failure? cause)
    (eq? expected (graph.validation-failure-kind cause)))))

;; Keep input/output admission independent of the entry's exact evidence binding.
(def Call (metadata.contract (metadata.predicate "object" object?)
  (metadata.predicate "evidence" object?) (lambda (_ _request _result) #t) metadata.truth))

;; Refuse only after graph installation and successful whole-value refinement.
(def Refusing (metadata.contract (metadata.predicate "object" object?)
  (metadata.predicate "evidence" object?) (lambda (_ _request _result) #f) (metadata.atom 'policy)))

;; Supply the right subject/descriptor but the WRONG entry context to the real
;; bind-evidence gate. This isolates cross-entry context transplant rejection.
(def (foreign-action expected targets providers chosen context foreign)
  (lambda (current)
    (def descriptor (recursive-publication.service.envelope current expected targets providers chosen))
    ((contract.publication-action descriptor Call context
       (lambda (checked)
         (values (.o subject: checked descriptor: descriptor context: foreign)
           (.cc context commits: (+ 1 (.get context commits))))))
      (.o report: (graph.closed-ref current 'report)))))

;; Each round prepares several entry requests before trying old generations,
;; refuses closure, re-stages, installs despite late effect refusal, then retries
;; only the effect. Entry contexts are explicit caller state, not graph metadata.
(def recursive-publication-test
  (test-suite "shared recursive graph publication"
    (test-case "three entries interleave old work across eight graph revisions"
      (let* ((first (recursive-publication.service.initial)) (owner (recursive-publication.publication.publication first))
             (idle (graph.closed-ref first 'idle)) (idle-type (graph.closed-type first 'idle))
             (primary (graph.closed-ref first 'primary)) (primary-type (graph.closed-type first 'primary))
             (contexts (vector (.o entry: 'deploy commits: 0) (.o entry: 'audit commits: 0)
                               (.o entry: 'repair commits: 0)))
             (all-primary (make-vector 8 'primary)) (all-secondary (make-vector 8 'secondary))
             (mixed '#(secondary secondary secondary secondary primary primary primary primary))
             (rounds (list (list recursive-publication.service.merged mixed 'notify 108 2)
               (list recursive-publication.service.split all-secondary 'auth 128 2)
               (list recursive-publication.service.crossed all-secondary 'cache 132 2)
               (list recursive-publication.service.original all-primary 'ingress 82 2)
               (list recursive-publication.service.merged mixed 'notify 108 2)
               (list recursive-publication.service.split all-secondary 'auth 128 2)
               (list recursive-publication.service.original all-secondary 'delivery 134 2)
               (list recursive-publication.service.original all-secondary 'delivery 135 3))))
        (let loop ((rows rounds) (history []) (round 0))
          (if (null? rows)
            (begin
              (check-equal? (map (lambda (value) (.get value commits)) (vector->list contexts)) '(3 3 2))
              (check (eq? idle (validate idle-type idle)) => #t)
              (check-exception (validate primary-type primary) (phase? 'stale)))
            (let* ((row (car rows)) (targets (car row)) (providers (cadr row)) (chosen (caddr row))
                   (expected (cadddr row)) (weight (car (cddddr row)))
                   (current (recursive-publication.publication.current owner))
                   (root (graph.closed-ref current 'report)) (root-type (graph.closed-type current 'report))
                   (prepare (restaging.transition-action targets providers chosen #t weight))
                   (pending (recursive-publication.publication.stage-with owner prepare))
                   (sibling (recursive-publication.publication.stage-with owner prepare))
                   (failed (recursive-publication.publication.stage-with owner
                     (restaging.transition-action targets providers chosen #f weight)))
                   (selected (modulo round 3)) (other (modulo (+ selected 1) 3))
                   (context (vector-ref contexts selected)) (other-context (vector-ref contexts other))
                   (calls 0)
                   (unreachable (lambda (_) (set! calls (+ calls 1)) (raise 'observer-ran))))
              (for-each (lambda (request)
                (check-exception (recursive-publication.publication.submit! owner request unreachable) (phase? 'stale))) history)
              (check-exception (recursive-publication.publication.submit! owner failed unreachable) (phase? 'admission))
              (check (eq? current (recursive-publication.publication.current owner)) => #t)
              (check (eq? root (validate root-type root)) => #t)
              (let* ((retry (recursive-publication.publication.stage-with owner prepare)))
                (let-values (((_ kept refusal)
                    (recursive-publication.publication.submit! owner retry
                      (entry.entry-action expected targets providers chosen Refusing context))))
                  (check (eq? kept context) => #t)
                  (check-equal? (metadata.failure-phase refusal) 'logic)
                  (let* ((installed (recursive-publication.publication.current owner)))
                    (check-equal? (.get (graph.closed-ref installed 'report) total) expected)
                    (check-exception (validate root-type root) (phase? 'stale))
                    (for-each (lambda (request)
                      (check-exception (recursive-publication.publication.submit! owner request unreachable) (phase? 'stale)))
                      (cons pending (cons sibling (cons failed history))))
                    (check-equal? calls 0)
                    (let-values (((_ same foreign-refusal)
                        (recursive-publication.publication.observe! owner
                          (foreign-action expected targets providers chosen other-context context))))
                      (check (eq? same other-context) => #t)
                      (check-equal? (metadata.failure-phase foreign-refusal) 'logic))
                    (let-values (((accepted next-context refusal)
                        (recursive-publication.publication.observe! owner
                          (entry.entry-action expected targets providers chosen Call context))))
                      (check refusal => #f)
                      (check-equal? (.get accepted total) expected)
                      (vector-set! contexts selected next-context))
                    (check (eq? installed (recursive-publication.publication.current owner)) => #t)
                    (check (eq? other-context (vector-ref contexts other)) => #t)
                    (loop (cdr rows) (cons pending (cons sibling history)) (+ round 1))))))))))
    (test-case "refinement and observer exceptions retain the installed head for retry"
      (let* ((owner (recursive-publication.publication.publication (recursive-publication.service.initial)))
             (providers (make-vector 8 'primary))
             (request (recursive-publication.publication.stage-with owner
               (restaging.transition-action recursive-publication.service.original providers 'delivery)))
             (context (.o commits: 0)))
        (check-exception (recursive-publication.publication.submit! owner request
          (entry.entry-action 90 recursive-publication.service.original providers 'delivery Call context)) TypeError?)
        (check-exception (recursive-publication.publication.observe! owner (lambda (_) (raise 'observer-refusal)))
          (lambda (cause) (eq? cause 'observer-refusal)))
        (check-equal? (.get (graph.closed-ref (recursive-publication.publication.current owner) 'report) total) 89)
        (let-values (((accepted next refusal) (recursive-publication.publication.observe! owner
            (entry.entry-action 89 recursive-publication.service.original providers 'delivery Call context))))
          (check refusal => #f)
          (check-equal? (.get accepted total) 89)
          (check-equal? (.get next commits) 1))))
    (test-case "reentrant entry preparation refuses and releases the operation guard"
      (let* ((owner (recursive-publication.publication.publication (recursive-publication.service.initial)))
             (previous (recursive-publication.publication.current owner))
             (prepare (restaging.transition-action recursive-publication.service.original (make-vector 8 'primary) 'delivery)))
        (check-exception (recursive-publication.publication.observe! owner
          (lambda (_) (recursive-publication.publication.stage-with owner prepare)))
          (lambda (cause) (and (Error? cause)
            (equal? (error-message cause) "recursive publication is already active"))))
        (check (eq? previous (recursive-publication.publication.current owner)) => #t)
        (let* ((request (recursive-publication.publication.stage-with owner prepare)))
          (recursive-publication.publication.submit! owner request values)
          (check-equal? (.get (graph.closed-ref (recursive-publication.publication.current owner) 'report) total) 89))))))

;; Return the original suites from this lexical scope.
(values recursive-publication-test)
