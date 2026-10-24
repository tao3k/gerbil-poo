;;; Named-generation isolation and repeated multi-coordinator recovery controls.
(export recursive-coordination-test)
(import :std/test :std/error ../object ../mop
        (prefix-in ../recursive-coordination coordination.)
        (prefix-in ../recursive-approvals approvals.)
        (prefix-in ../recursive-publication publication.)
        (prefix-in ../recursive-validation graph.)
        (prefix-in ../examples/recursive-topology topology.)
        (prefix-in ../examples/recursive-approvals service.)
        (prefix-in ../examples/recursive-competition competition.)
        (prefix-in ../examples/recursive-coordination workflow.)
        (prefix-in ../declarative-metadata metadata.))

;; Each control owns its own graph, policies and per-name registry.
(def (fresh-owner)
  (publication.publication (topology.initial)
    metadata: (service.policy topology.original (make-vector 8 'primary) 'ingress 82)))
;; Preserve exact guard categories, including lifecycle versus approval/head staleness.
(def (message? text)
  (lambda (cause) (and (Error? cause) (equal? text (error-message cause)))))
;; Retain the existing typed local/joint admission failure boundary.
(def (phase? kind)
  (lambda (cause) (and (graph.validation-failure? cause)
    (eq? kind (graph.validation-failure-kind cause)))))
;; Valid invocation/evidence obligations reuse the original contract publication chain.
(def Call (metadata.contract (metadata.predicate "object" object?)
  (metadata.predicate "evidence" object?) (lambda (_ _request _result) #t) metadata.truth))
;; Late business refusal is an ordinary observer result, not coordinator failure.
(def Refusing (metadata.contract (metadata.predicate "object" object?)
  (metadata.predicate "evidence" object?) (lambda (_ _request _result) #f) (metadata.atom 'policy)))

;; Test the complete continuing workflow and isolated lifecycle preconditions.
(def recursive-coordination-test
  (test-suite "named recursive coordinator incarnations"
    (test-case "two names each fail recover compete and exit again across eight SCC rounds"
      (let* ((owner (fresh-owner)) (first (publication.current owner))
             (idle (graph.closed-ref first 'idle)) (idle-type (graph.closed-type first 'idle))
             (before (publication.snapshot owner)) (exits 0) (wins 0) (observed 0)
             (generations (make-hash-table-eq)) (phases (make-hash-table-eq))
             (contexts (vector (.o commits: 0) (.o commits: 0) (.o commits: 0))))
        (workflow.coordinate-interleaving! owner (competition.transitions)
          (lambda (round phase) (service.entry-action (if (eq? phase 'retry) Call Refusing)
            (vector-ref contexts (modulo round 3))))
          (lambda (round name phase generation outcome operations)
            (set! exits (+ exits 1))
            (check-equal? generation (+ 1 (hash-ref generations name 0)))
            (hash-put! generations name generation)
            (if (eq? name 'survivor)
              (let-values (((actual status) (outcome)))
                (check-equal? actual 1) (check-equal? status 'finished))
              (begin
                (check-exception (outcome) (lambda (cause) (equal? cause (list name round phase))))
                (check-exception ((car operations) (lambda (_) (raise 'factory-ran)))
                  (message? "stale recursive coordinator"))
                (check-exception ((cadr operations) values values)
                  (message? "recursive submission scope is not open"))
                (for-each (lambda (operation)
                  (check-exception (operation) (message? "recursive submission scope is not open"))) (cddr operations)))))
          (lambda (round label result)
            (hash-put! phases label (+ 1 (hash-ref phases label 0)))
            (case label
              ((winner)
                (let* ((installed (publication.snapshot owner)) (old (publication.snapshot-graph before)))
                  (check (approvals.attempt-failed? result) => #f)
                  (check (eq? installed (approvals.attempt-snapshot result)) => #t)
                  (check (eq? installed before) => #f)
                  (check-equal? (metadata.failure-phase (caddr (approvals.attempt-values result))) 'logic)
                  (check-exception (validate (graph.closed-type old 'report) (graph.closed-ref old 'report)) (phase? 'stale))
                  (set! before installed) (set! wins (+ wins 1))))
              ((observed)
                (let ((entry (modulo round 3)))
                  (check (caddr result) => #f)
                  (check-equal? (.get (car result) total) (.get (publication.snapshot-metadata before) expected))
                  (check-equal? (.get (cadr result) commits) (+ 1 (.get (vector-ref contexts entry) commits)))
                  (vector-set! contexts entry (cadr result)) (set! observed (+ observed 1))))
              ((survivor-open) (check result => #f))
              (else
                (check (approvals.attempt-failed? result) => #t)
                (check (eq? before (approvals.attempt-snapshot result)) => #t)
                (check ((case label
                  ((generation-stale) (message? "stale recursive coordinator"))
                  ((approval-stale) (message? "stale or invalid lens checks"))
                  ((head-stale) (message? "stale recursive approval snapshot"))
                  ((joint-refusal) (phase? 'joint-admission))
                  (else (lambda (_cause) #f))) (approvals.attempt-failure result)) => #t)))))
        (check-equal? (list exits wins observed) '(49 8 8))
        (check-equal? (map (lambda (name) (hash-ref generations name 0)) '(deploy repair survivor)) '(24 24 1))
        (check-equal? (map (lambda (phase) (hash-ref phases phase 0))
          '(generation-stale approval-stale joint-refusal winner head-stale survivor-open observed)) '(1024 56 16 8 8 8 8))
        (check-equal? (map (lambda (context) (.get context commits)) (vector->list contexts)) '(3 3 2))
        (check (eq? idle (validate idle-type idle)) => #t)
        (check-equal? (.get (graph.closed-ref (publication.current owner) 'report) total) 135)))
    (test-case "same head and stamps cannot reactivate an exited request or factory"
      (let* ((owner (fresh-owner)) (registry (coordination.coordination owner))
             (before (publication.snapshot owner)) (calls 0) (saved-prepare #f)
             (policy (service.policy topology.original (make-vector 8 'primary) 'delivery 89))
             (old (coordination.call-with-coordinator registry 'deploy
               (lambda (_generation prepare! _enqueue! _advance! _pending?)
                 (set! saved-prepare prepare!)
                 (prepare! (lambda (actual)
                   (let ((request (service.stage-transition actual policy)))
                     (lambda (state) (set! calls (+ calls 1)) (request state)))))))))
        (let ((receipt (car (approvals.submit-sequence! owner [(cons old values)]))))
          (check ((message? "stale recursive coordinator") (approvals.attempt-failure receipt)) => #t)
          (check (eq? before (approvals.attempt-snapshot receipt)) => #t))
        (check-equal? calls 0)
        (coordination.call-with-coordinator registry 'deploy
          (lambda (generation prepare! enqueue! advance! _pending?)
            (check-equal? generation 2)
            (check-exception (saved-prepare (lambda (_) (raise 'unexpected))) (message? "stale recursive coordinator"))
            (enqueue! old values)
            (enqueue! (prepare! (lambda (actual) (service.stage-transition actual policy))) values)
            (check ((message? "stale recursive coordinator") (approvals.attempt-failure (advance!))) => #t)
            (check (approvals.attempt-failed? (advance!)) => #f)))
        (check-equal? calls 0)))
    (test-case "duplicate names refuse while another name can fail without closing a survivor"
      (let* ((owner (fresh-owner)) (registry (coordination.coordination owner)) (ran #f))
        (coordination.call-with-coordinator registry 'survivor
          (lambda (_generation prepare! enqueue! advance! pending?)
            (check-exception (coordination.call-with-coordinator registry 'survivor
              (lambda (_g _p _e _a _q) (set! ran #t))) (message? "recursive coordinator is already active"))
            (coordination.call-with-coordinator registry 'repair
              (lambda (_g _p _e _a _q) (raise 'repair-failed))
              on-exit: (lambda (outcome) (check-exception (outcome) (lambda (cause) (eq? cause 'repair-failed)))))
            (check (pending?) => #f)
            (enqueue! (prepare! (lambda (actual) (service.stage-transition actual
              (service.policy topology.original (make-vector 8 'primary) 'delivery 89)))) values)
            (check (approvals.attempt-failed? (advance!)) => #f)))
        (check ran => #f)))
    (test-case "exit policy can replace the same name and its own error is not caught twice"
      (let* ((owner (fresh-owner)) (registry (coordination.coordination owner)) (calls 0) (old-prepare #f))
        (check-exception (coordination.call-with-coordinator registry 'deploy
          (lambda (_generation prepare! _enqueue! _advance! _pending?) (set! old-prepare prepare!) (raise #f))
          on-exit: (lambda (outcome)
            (set! calls (+ calls 1))
            (check-exception (outcome) (lambda (cause) (eq? cause #f)))
            (coordination.call-with-coordinator registry 'deploy
              (lambda (generation _prepare! _enqueue! _advance! pending?)
                (check-equal? generation 2) (check (pending?) => #f)
                (check-exception (old-prepare values) (message? "stale recursive coordinator"))))
            (raise 'policy-failed))) (lambda (cause) (eq? cause 'policy-failed)))
        (check-equal? calls 1)
        (coordination.call-with-coordinator registry 'deploy
          (lambda (generation _p _e _a _q) (check-equal? generation 3)))))
    (test-case "invalid names callbacks and staging readers refuse before work is admitted"
      (let* ((owner (fresh-owner)) (registry (coordination.coordination owner)) (before (publication.snapshot owner)))
        (check-exception (coordination.call-with-coordinator registry '(not-a-name) values)
          (message? "recursive coordinator requires a symbol and procedure callbacks"))
        (check-exception (coordination.call-with-coordinator registry 'deploy values on-exit: #f)
          (message? "recursive coordinator requires a symbol and procedure callbacks"))
        (coordination.call-with-coordinator registry 'deploy
          (lambda (_generation prepare! _e _a pending?)
            (check-exception (prepare! #f) (message? "recursive coordinator requires a staging reader"))
            (check-exception (prepare! (lambda (_) #f)) (message? "recursive staging reader must return a request"))
            (check (pending?) => #f)))
        (check (eq? before (publication.snapshot owner)) => #t)))))
