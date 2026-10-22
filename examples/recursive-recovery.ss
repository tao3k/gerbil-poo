;;; Explicit coordinator recovery shares one recursive graph/approval publication.
(export coordinate-recovery!)
(import ../object
        ../mop
        (runtime: :clan/poo/recursive-approvals)
        (prefix-in (only-in ../recursive-approvals call-with-submissions observe!) approvals.)
        (runtime: :clan/poo/recursive-publication)
        (prefix-in (only-in ../recursive-publication snapshot snapshot-metadata) publication.)
        (prefix-in ./recursive-approvals service.))

;; observer-for receives (round, install/retry) and returns an existing FUN reader.
;; exited receives (round, failed/recovered, outcome-thunk, closed-operations).
;; report receives (round, phase, receipt), or returned values for phase observed.
;; The explicit exit policy handles the first coordinator's failure, permits a
;; survivor to proceed, then opens a fresh recovery scope. No scope is resumed and
;; no failed request is refreshed. All calls share one caller-serialized owner.
(def (coordinate-recovery! owner policies observer-for exited report)
  (let loop ((remaining policies) (round 0) (history []))
    (unless (null? remaining)
      (let* ((proposed (car remaining))
             (future (if (pair? (cdr remaining)) (cadr remaining) proposed))
             (observer (observer-for round 'install))
             (abandoned []) (operations []) (latest #f))
        (approvals.call-with-submissions owner
          (lambda (enqueue! advance! pending?)
            (set! operations (list enqueue! advance! pending?))
            (set! abandoned (list (service.stage-transition owner proposed)
                                 (service.stage-transition owner future)))
            (for-each (lambda (request) (enqueue! request observer)) abandoned)
            (raise (cons 'coordinator-exit round)))
          on-exit: (lambda (outcome)
            ;; This callback runs after closure and queue release. Its policy is
            ;; explicit: a handler error aborts; it is never caught as another exit.
            (exited round 'failed outcome operations)
            (approvals.call-with-submissions owner
              (lambda (enqueue! advance! _pending?)
                ;; Submit one already guarded request and preserve its real receipt.
                (def (attempt! label) (report round label (advance!)))
                (let ((fresh (service.stage-transition owner proposed)))
                  (enqueue! (car abandoned) observer)
                  (enqueue! fresh observer)
                  (.put! proposed 'budget 201)
                  (.put! proposed 'budget 200)
                  (attempt! 'approval-stale)
                  (attempt! 'approval-stale))
                (let* ((installed (publication.snapshot-metadata (publication.snapshot owner)))
                       (current (service.stage-transition owner proposed))
                       (next (service.stage-transition owner future)))
                  (enqueue! current observer)
                  (enqueue! next observer)
                  (.put! installed 'budget 201)
                  (.put! installed 'budget 200)
                  (attempt! 'approval-stale)
                  (attempt! 'approval-stale))
                (for-each (lambda (request) (enqueue! request observer)) history)
                (for-each (lambda (_) (attempt! 'replay)) history)
                (enqueue! (service.stage-transition owner
                  (.cc proposed budget: (- (.get proposed expected) 1))) observer)
                (attempt! 'joint-refusal)
                ;; Alternate the installer: survivors win odd rounds, recovery
                ;; wins even rounds. The loser is never chosen by timing or sleeps.
                (when (odd? round)
                  (let ((winner (service.stage-transition owner proposed))
                        (challenger (service.stage-transition owner future)))
                    (set! latest winner)
                    (enqueue! winner observer)
                    (enqueue! challenger observer)
                    (attempt! 'winner)
                    (attempt! 'replay)))))
            (approvals.call-with-submissions owner
              (lambda (enqueue! advance! pending?)
                ;; Recovery admits new preparation behind retained historical work.
                (def (attempt! label) (report round label (advance!)))
                (set! operations (list enqueue! advance! pending?))
                (let* ((older (append abandoned history))
                       (drifted (service.stage-transition owner proposed))
                       (installed (publication.snapshot-metadata (publication.snapshot owner))))
                  (for-each (lambda (request) (enqueue! request observer)) older)
                  (enqueue! drifted observer)
                  (.put! installed 'budget 201)
                  (.put! installed 'budget 200)
                  (for-each (lambda (_) (attempt! 'replay)) older)
                  (attempt! 'approval-stale))
                (let* ((intent (if (odd? round)
                                  (.cc proposed budget: (- (.get proposed expected) 1)) proposed))
                       (fresh (service.stage-transition owner intent)))
                  (unless (odd? round) (set! latest fresh))
                  (enqueue! fresh observer)
                  (enqueue! (car abandoned) observer)
                  (attempt! (if (odd? round) 'joint-refusal 'winner))
                  (attempt! 'replay))
                (values round 'recovered))
              on-exit: (lambda (outcome) (exited round 'recovered outcome operations)))))
        ;; Current refinement and exact evidence retry follow closed coordinators;
        ;; this observation never rebuilds or rolls back the installed graph.
        (call-with-values (lambda () (approvals.observe! owner (observer-for round 'retry)))
          (lambda returned (report round 'observed returned)))
        (loop (cdr remaining) (+ round 1) (append abandoned (cons latest history)))))))
