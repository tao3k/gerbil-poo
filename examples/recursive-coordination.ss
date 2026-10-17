;;; Multiple named coordinators recover repeatedly around one continuing publication.
(export coordinate-interleaving!)
(import ../object ../mop (prefix-in ../recursive-coordination coordination.)
        (prefix-in ../recursive-approvals approvals.)
        (prefix-in ../recursive-publication publication.)
        (prefix-in ./recursive-approvals service.))

;; Reuse the existing service staging Reader; the coordinator adds only its fence.
(def (stage prepare! policy)
  (prepare! (lambda (owner) (service.stage-transition owner policy))))

;; observer-for maps (round, install/retry) to existing FUN readers. exited receives
;; (round, name, phase, generation, outcome-thunk, escaped-operations), AFTER cleanup.
;; report receives (round, phase, receipt), or result values for phase observed.
;; One survivor scope stays live across eight rounds; deploy/repair each fail three
;; times per round, including nested recovery and failure after a winning install.
;; All publication remains caller-serialized. Explicit handlers decide continuation.
(def (coordinate-interleaving! owner policies observer-for exited report)
  (def registry (coordination.coordination owner))
  (def history [])
  ;; Preserve externally retained requests only after their incarnation has closed.
  (def (scope round name phase body)
    (def requests [])
    (def operations [])
    (def generation #f)
    (coordination.call-with-coordinator registry name
      (lambda (current prepare! enqueue! advance! pending?)
        (set! generation current)
        (set! operations (list prepare! enqueue! advance! pending?))
        ;; Record requests for explicit old-generation replay, never automatic reuse.
        (def (prepare factory)
          (def request (prepare! factory))
          (set! requests (cons request requests)) request)
        (body prepare enqueue! advance! pending?))
      on-exit: (lambda (outcome)
        (set! history (append requests history))
        (exited round name phase generation outcome operations))))
  (coordination.call-with-coordinator registry 'survivor
    (lambda (generation prepare! enqueue! advance! pending?)
      (let loop ((remaining policies) (round 0))
        (unless (null? remaining)
          (let* ((policy (car remaining))
                 (future (if (pair? (cdr remaining)) (cadr remaining) policy))
                 (observer (observer-for round 'install)))
            ;; Each first failure abandons staged current/future work at the same head.
            (for-each (lambda (name)
              (scope round name 'initial
                (lambda (prepare enqueue! _advance! _pending?)
                  (enqueue! (stage prepare policy) observer)
                  (enqueue! (stage prepare future) observer)
                  (raise (list name round 'initial))))) '(deploy repair))
            (scope round 'deploy 'recovering
              (lambda (prepare-a enqueue-a advance-a pending-a?)
                (enqueue-a (stage prepare-a policy) observer)
                (scope round 'repair 'recovering
                  (lambda (prepare-b enqueue-b advance-b _pending-b?)
                    (enqueue-b (stage prepare-b policy) observer)
                    (.put! policy 'budget 201) (.put! policy 'budget 200)
                    (report round 'approval-stale (advance-a))
                    (report round 'approval-stale (advance-b))
                    (enqueue-a (stage prepare-a policy) observer)
                    (enqueue-b (stage prepare-b future) observer)
                    (let ((installed (publication.snapshot-metadata (publication.snapshot owner))))
                      (.put! installed 'budget 201) (.put! installed 'budget 200))
                    (report round 'approval-stale (advance-a))
                    (report round 'approval-stale (advance-b))
                    (raise (list 'repair round 'recovering))))
                (report round 'survivor-open (pending-a?))
                (raise (list 'deploy round 'recovering))))
            (scope round 'deploy 'competing
              (lambda (prepare-a enqueue-a advance-a _pending-a?)
                (scope round 'repair 'competing
                  (lambda (prepare-b enqueue-b advance-b _pending-b?)
                    ;; Old generations refuse even before topology or approval changes.
                    (for-each (lambda (request) (enqueue! request observer)) history)
                    (for-each (lambda (_) (report round 'generation-stale (advance!))) history)
                    (enqueue-a (stage prepare-a (.cc policy budget: (- (.get policy expected) 1))) observer)
                    (report round 'joint-refusal (advance-a))
                    (enqueue-a (stage prepare-a policy) observer)
                    (enqueue-b (stage prepare-b policy) observer)
                    (let ((installed (publication.snapshot-metadata (publication.snapshot owner))))
                      (.put! installed 'budget 201) (.put! installed 'budget 200))
                    (report round 'approval-stale (advance-a))
                    (report round 'approval-stale (advance-b))
                    (enqueue-a (stage prepare-a policy) observer)
                    (enqueue-b (stage prepare-b policy) observer)
                    (report round 'winner ((if (even? round) advance-a advance-b)))
                    (report round 'head-stale ((if (even? round) advance-b advance-a)))
                    (let ((prepare-loser (if (even? round) prepare-b prepare-a))
                          (enqueue-loser (if (even? round) enqueue-b enqueue-a))
                          (advance-loser (if (even? round) advance-b advance-a)))
                      (enqueue-loser (stage prepare-loser (.cc policy budget: (- (.get policy expected) 1))) observer)
                      (report round 'joint-refusal (advance-loser))
                      (enqueue-loser (stage prepare-loser future) observer)
                      (.put! policy 'budget 201) (.put! policy 'budget 200)
                      (report round 'approval-stale (advance-loser)))
                    (raise (list 'repair round 'competing))))
                (raise (list 'deploy round 'competing))))
            (for-each (lambda (request) (enqueue! request observer)) history)
            (for-each (lambda (_) (report round 'generation-stale (advance!))) history)
            (call-with-values (lambda () (approvals.observe! owner (observer-for round 'retry)))
              (lambda returned (report round 'observed returned)))
            (loop (cdr remaining) (+ round 1)))))
      (values generation 'finished))
    on-exit: (lambda (outcome) (exited (length policies) 'survivor 'finished 1 outcome []))))
