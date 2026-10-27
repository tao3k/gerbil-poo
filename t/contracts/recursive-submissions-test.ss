;;; Continuing arrivals, repeated guard expiry and scoped FIFO lifecycle controls.
(export recursive-submissions-test)
(import :std/test :std/error :clan/poo/object :clan/poo/mop
        (prefix-in :clan/poo/recursive-approvals approvals.)
        (prefix-in :clan/poo/recursive-publication publication.)
        (prefix-in :clan/poo/recursive-validation graph.)
        (prefix-in :clan/poo/examples/recursive-topology topology.)
        (prefix-in :clan/poo/examples/recursive-approvals service.)
        (prefix-in :clan/poo/examples/recursive-competition competition.)
        (prefix-in :clan/poo/examples/recursive-submissions workflow.)
        (prefix-in :clan/poo/declarative-metadata metadata.))

;; Build an independent owner for each lifecycle control; no fixture state leaks.
(def (fresh-owner)
  (publication.publication (topology.initial)
    metadata: (service.policy topology.original (make-vector 8 'primary) 'ingress 82)))

;; Match supported guard errors without confusing admission or business refusal.
(def (message? text)
  (lambda (cause) (and (Error? cause) (equal? text (error-message cause)))))

;; Match the existing typed recursive validation phase, retaining original errors.
(def (phase? kind)
  (lambda (cause) (and (graph.validation-failure? cause)
    (eq? kind (graph.validation-failure-kind cause)))))

;; Accepted effects bind current refinement and exact evidence at each entry.
(def Call (metadata.contract (metadata.predicate "object" object?)
  (metadata.predicate "evidence" object?) (lambda (_ _request _result) #t) metadata.truth))

;; A late business refusal must preserve the newly installed graph/approval pair.
(def Refusing (metadata.contract (metadata.predicate "object" object?)
  (metadata.predicate "evidence" object?) (lambda (_ _request _result) #f) (metadata.atom 'policy)))

;; Exercise actual SCC closure alongside queue ownership, not synthetic callbacks.
(def recursive-submissions-test
  (test-suite "continuing recursive submissions"
    (test-case "fresh arrivals precede draining old competitors through eight SCC rounds"
      (let* ((owner (fresh-owner)) (initial (publication.current owner))
             (idle (graph.closed-ref initial 'idle)) (idle-type (graph.closed-type initial 'idle))
             (before (publication.snapshot owner)) (attempts 0) (wins 0)
             (contexts (vector (.o commits: 0) (.o commits: 0) (.o commits: 0))))
        (check (workflow.publish-continuously! owner (competition.transitions)
          (lambda (round) (service.entry-action Refusing (vector-ref contexts (modulo round 3))))
          (lambda (round label receipt)
            (set! attempts (+ attempts 1))
            (case label
              ((winner)
                (let* ((installed (publication.snapshot owner))
                       (old (publication.snapshot-graph before))
                       (entry (modulo round 3)))
                  (check (approvals.attempt-failed? receipt) => #f)
                  (check-equal? (length (approvals.attempt-values receipt)) 3)
                  (check-equal? (metadata.failure-phase (caddr (approvals.attempt-values receipt))) 'logic)
                  (check (eq? installed (approvals.attempt-snapshot receipt)) => #t)
                  (check (eq? installed before) => #f)
                  (check-exception (validate (graph.closed-type old 'report) (graph.closed-ref old 'report))
                    (phase? 'stale))
                  (let-values (((accepted next refusal) (approvals.observe! owner
                      (service.entry-action Call (vector-ref contexts entry)))))
                    (check refusal => #f)
                    (check-equal? (.get accepted total) (.get (publication.snapshot-metadata installed) expected))
                    (vector-set! contexts entry next))
                  (set! wins (+ wins 1))
                  (set! before installed)))
              (else
                (check (approvals.attempt-failed? receipt) => #t)
                (check (eq? before (approvals.attempt-snapshot receipt)) => #t)
                (check ((case label
                  ((historical) (message? "stale recursive approval snapshot"))
                  ((joint-refusal) (phase? 'joint-admission))
                  (else (message? "stale or invalid lens checks")))
                  (approvals.attempt-failure receipt)) => #t))))) => #f)
        (check-equal? attempts 64)
        (check-equal? wins 8)
        (check-equal? (map (lambda (context) (.get context commits)) (vector->list contexts)) '(3 3 2))
        (check (eq? idle (validate idle-type idle)) => #t)
        (check-equal? (.get (graph.closed-ref (publication.current owner) 'report) total) 135)))
    (test-case "empty, invalid enqueue, multiple values and escaped operations"
      (let ((owner (fresh-owner)) (escaped #f))
        (let-values (((left right) (approvals.call-with-submissions owner
            (lambda (enqueue! advance! pending?)
              (set! escaped (list enqueue! advance! pending?))
              (check (pending?) => #f)
              (check (advance!) => #f)
              (check-exception (enqueue! 'invalid values)
                (message? "recursive submission requires request and observer procedures"))
              (check (pending?) => #f)
              (values 'left 'right)))))
          (check-equal? (list left right) '(left right)))
        (check-exception ((car escaped) values values) (message? "recursive submission scope is not open"))
        (for-each (lambda (operation)
          (check-exception (operation) (message? "recursive submission scope is not open"))) (cdr escaped))))
    (test-case "unconsumed work refuses normal return without installing"
      (let* ((owner (fresh-owner)) (before (publication.snapshot owner))
             (proposed (service.policy topology.original (make-vector 8 'primary) 'delivery 89)))
        (check-exception (approvals.call-with-submissions owner
          (lambda (enqueue! _advance! _pending?) (enqueue! (service.stage-transition owner proposed) values)))
          (message? "unconsumed recursive submissions"))
        (check (eq? before (publication.snapshot owner)) => #t)))
    (test-case "observer reentrancy refuses without losing a queued receipt"
      (let* ((owner (fresh-owner))
             (proposed (service.policy topology.original (make-vector 8 'primary) 'delivery 89)))
        (approvals.call-with-submissions owner
          (lambda (enqueue! advance! pending?)
            (let ((winner (service.stage-transition owner proposed))
                  (loser (service.stage-transition owner proposed)))
              (enqueue! winner (lambda (_)
                (check-exception (enqueue! values values) (message? "recursive submission scope is not open"))
                (check-exception (pending?) (message? "recursive submission scope is not open"))
                (advance!)))
              (enqueue! loser values)
              (let ((receipt (advance!)))
                (check (eq? winner (approvals.attempt-request receipt)) => #t)
                (check ((message? "recursive submission scope is not open") (approvals.attempt-failure receipt)) => #t)
                (check (eq? (publication.snapshot owner) (approvals.attempt-snapshot receipt)) => #t))
              (check (pending?) => #t)
              (let ((receipt (advance!)))
                (check (eq? loser (approvals.attempt-request receipt)) => #t)
                (check ((message? "stale recursive approval snapshot") (approvals.attempt-failure receipt)) => #t))
              (check (pending?) => #f))))))
    (test-case "coordinator failure closes pending work and keeps its installed prefix"
      (let* ((owner (fresh-owner)) (before (publication.snapshot owner)) (escaped #f)
             (proposed (service.policy topology.original (make-vector 8 'primary) 'delivery 89)))
        (check-exception (approvals.call-with-submissions owner
          (lambda (enqueue! advance! _pending?)
            (set! escaped advance!)
            (enqueue! (service.stage-transition owner proposed) (lambda (_) (values)))
            (check (approvals.attempt-failed? (advance!)) => #f)
            (enqueue! (service.stage-transition owner proposed) values)
            (raise 'coordinator-failed))) (lambda (cause) (eq? cause 'coordinator-failed)))
        (check (eq? before (publication.snapshot owner)) => #f)
        (check-exception (escaped) (message? "recursive submission scope is not open"))
        (let-values (((accepted _next refusal) (approvals.observe! owner (service.entry-action Call (.o commits: 0)))))
          (check refusal => #f)
          (check-equal? (.get accepted total) 89))))))
