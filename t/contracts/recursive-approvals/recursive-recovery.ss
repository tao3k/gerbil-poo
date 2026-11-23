;;; Explicit post-cleanup recovery with continuing shared recursive publication.



;; Each control owns fresh metadata and graph identities, independent of GC history.
(def (fresh-owner)
  (recursive-recovery.publication.publication (recursive-recovery.topology.initial)
    metadata: (recursive-recovery.service.policy recursive-recovery.topology.original (make-vector 8 'primary) 'ingress 82)))

;; Keep supported guard errors distinct from graph admission and business refusal.
(def (message? text)
  (lambda (cause) (and (Error? cause) (equal? text (error-message cause)))))

;; Preserve the existing typed validation phase instead of treating errors as success.
(def (phase? kind)
  (lambda (cause) (and (graph.validation-failure? cause)
    (eq? kind (graph.validation-failure-kind cause)))))

;; Failed scopes release every escaped operation before exit policy may run.
(def (check-closed operations)
  (check-exception ((car operations) values values) (message? "recursive submission scope is not open"))
  (for-each (lambda (operation)
    (check-exception (operation) (message? "recursive submission scope is not open"))) (cdr operations)))

;; Existing evidence publication succeeds only against the current refined receiver.
(def Call (metadata.contract (metadata.predicate "object" object?)
  (metadata.predicate "evidence" object?) (lambda (_ _request _result) #t) metadata.truth))

;; A normal late effect refusal is retained separately from a thrown coordinator error.
(def Refusing (metadata.contract (metadata.predicate "object" object?)
  (metadata.predicate "evidence" object?) (lambda (_ _request _result) #f) (metadata.atom 'policy)))

;; Run actual SCC closure plus lifecycle controls; no thread scheduling is assumed.
(def recursive-recovery-test
  (test-suite "recursive coordinator recovery"
    (test-case "survivors and recovered coordinators alternate eight actual SCC publications"
      (let* ((owner (fresh-owner)) (first (recursive-recovery.publication.current owner))
             (idle (graph.closed-ref first 'idle)) (idle-type (graph.closed-type first 'idle))
             (before (recursive-recovery.publication.snapshot owner)) (exits 0) (rejoins 0) (wins 0) (observed 0) (refusals 0)
             (contexts (vector (.o commits: 0) (.o commits: 0) (.o commits: 0))))
        (recursive-recovery.workflow.coordinate-recovery! owner (competition.transitions)
          (lambda (round phase)
            (recursive-recovery.service.entry-action (if (eq? phase 'retry) Call Refusing) (vector-ref contexts (modulo round 3))))
          (lambda (round phase outcome operations)
            (check-closed operations)
            (if (eq? phase 'failed)
              (begin (set! exits (+ exits 1))
                (check-exception (outcome) (lambda (cause)
                  (and (pair? cause) (eq? (car cause) 'coordinator-exit) (= (cdr cause) round)))))
              (begin (set! rejoins (+ rejoins 1))
                (let-values (((actual status) (outcome)))
                  (check-equal? actual round) (check-equal? status 'recovered)))))
          (lambda (round label result)
            (case label
              ((winner)
                (let* ((installed (recursive-recovery.publication.snapshot owner)) (old (recursive-recovery.publication.snapshot-graph before)))
                  (check (approvals.attempt-failed? result) => #f)
                  (check (eq? installed (approvals.attempt-snapshot result)) => #t)
                  (check (eq? before installed) => #f)
                  (check-equal? (metadata.failure-phase (caddr (approvals.attempt-values result))) 'logic)
                  (check-exception (validate (graph.closed-type old 'report) (graph.closed-ref old 'report)) (phase? 'stale))
                  (set! before installed) (set! wins (+ wins 1))))
              ((observed)
                (let ((accepted (car result)) (next (cadr result)) (refusal (caddr result))
                      (entry (modulo round 3)))
                  (check refusal => #f)
                  (check-equal? (.get accepted total) (.get (recursive-recovery.publication.snapshot-metadata before) expected))
                  (check-equal? (.get next commits) (+ (.get (vector-ref contexts entry) commits) 1))
                  (vector-set! contexts entry next)
                  (set! observed (+ observed 1))))
              (else
                (check (approvals.attempt-failed? result) => #t)
                (check (eq? before (approvals.attempt-snapshot result)) => #t)
                (check ((case label
                  ((joint-refusal) (phase? 'joint-admission))
                  ((approval-stale) (message? "stale or invalid lens checks"))
                  (else (lambda (cause)
                    (or ((message? "stale recursive approval snapshot") cause)
                        ((message? "stale or invalid lens checks") cause))))) (approvals.attempt-failure result)) => #t)
                (set! refusals (+ refusals 1))))))
        (check-equal? (list exits rejoins wins observed) '(8 8 8 8))
        (check-equal? refusals 248)
        (check-equal? (map (lambda (context) (.get context commits)) (vector->list contexts)) '(3 3 2))
        (check-equal? (.get (graph.closed-ref (recursive-recovery.publication.current owner) 'report) total) 135)
        (check (eq? idle (validate idle-type idle)) => #t)))
    (test-case "normal values and a raised false reach policy only after scope cleanup"
      (let ((owner (fresh-owner)) (operations []) (calls 0))
        (let-values (((left right) (approvals.call-with-submissions owner
          (lambda (enqueue! advance! pending?)
            (set! operations (list enqueue! advance! pending?)) (values #f 'returned))
          on-exit: (lambda (outcome) (set! calls (+ calls 1)) (check-closed operations) (outcome)))))
          (check-equal? (list left right) '(#f returned)))
        (check (approvals.call-with-submissions owner (lambda (_enqueue _advance _pending) (raise #f))
          on-exit: (lambda (outcome)
            (set! calls (+ calls 1)) (check-exception (outcome) (lambda (cause) (eq? cause #f))) 'handled)) => 'handled)
        (check-equal? calls 2)))
    (test-case "exit policy errors propagate once and cannot reopen the old scope"
      (let ((owner (fresh-owner)) (calls 0) (operations []) (cause (cons 'policy 'failed)))
        (check-exception (approvals.call-with-submissions owner
          (lambda (enqueue! advance! pending?) (set! operations (list enqueue! advance! pending?)) (raise 'coordinator))
          on-exit: (lambda (outcome)
            (set! calls (+ calls 1)) (check-closed operations)
            (check-exception (outcome) (lambda (error) (eq? error 'coordinator))) (raise cause)))
          (lambda (error) (eq? error cause)))
        (check-equal? calls 1)
        (check-closed operations)))
    (test-case "invalid handlers preflight and unconsumed exits permit only a fresh scope"
      (let ((owner (fresh-owner)) (ran #f))
        (check-exception (approvals.call-with-submissions owner (lambda (_enqueue _advance _pending) (set! ran #t)) on-exit: #f)
          (message? "recursive submission coordinator and exit handler must be procedures"))
        (check ran => #f)
        (check (approvals.call-with-submissions owner
          (lambda (enqueue! _advance _pending) (enqueue! values values))
          on-exit: (lambda (outcome)
            (check-exception (outcome) (message? "unconsumed recursive submissions"))
            (approvals.call-with-submissions owner (lambda (_ advance! pending?)
              (check (pending?) => #f) (check (advance!) => #f) 'reopened)))) => 'reopened)))
    (test-case "failure after installation retains its prefix before explicit recovery publishes"
      (let* ((owner (fresh-owner)) (before (recursive-recovery.publication.snapshot owner))
             (target (recursive-recovery.service.policy recursive-recovery.topology.original (make-vector 8 'primary) 'delivery 89))
             (winner (recursive-recovery.service.stage-transition owner target)) (saved #f))
        (approvals.call-with-submissions owner
          (lambda (enqueue! advance! _)
            (enqueue! winner values) (check (approvals.attempt-failed? (advance!)) => #f)
            (set! saved (recursive-recovery.publication.snapshot owner))
            (enqueue! winner values) (raise 'after-install))
          on-exit: (lambda (outcome)
            (check-exception (outcome) (lambda (cause) (eq? cause 'after-install)))
            (check (eq? before (recursive-recovery.publication.snapshot owner)) => #f)
            (check (eq? saved (recursive-recovery.publication.snapshot owner)) => #t)
            (approvals.call-with-submissions owner
              (lambda (enqueue! advance! _)
                (let ((fresh (recursive-recovery.service.stage-transition owner
                    (recursive-recovery.service.policy recursive-recovery.topology.original (make-vector 8 'primary) 'ingress 82))))
                  (enqueue! winner values) (enqueue! fresh values)
                  (check ((message? "stale recursive approval snapshot") (approvals.attempt-failure (advance!))) => #t)
                  (check (approvals.attempt-failed? (advance!)) => #f))))))
        (check-equal? (.get (graph.closed-ref (recursive-recovery.publication.current owner) 'report) total) 82)
        (check (eq? saved (recursive-recovery.publication.snapshot owner)) => #f)))))

;; Return the original suites from this lexical scope.
(values recursive-recovery-test)
