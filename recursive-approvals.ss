;;; Joint revisions of one recursive graph and shared approval metadata.
(export stage-with submit! observe! submit-sequence! call-with-submissions
        attempt-request attempt-snapshot attempt-values attempt-failed? attempt-failure)
(import (only-in :std/list/list foldl) (prefix-in :std/struct/queue queue.) ./object ./mop ./lens-laws
        (prefix-in ./recursive-publication publication.))

;; Capture native supported revisions of installed/proposed metadata. Existing
;; lens guards reject ABA writes and protect both objects throughout callbacks.
(def (guards metadata proposed)
  (unless (and (object? metadata) (object? proposed))
    (error "recursive approval metadata must be objects"))
  (map (lambda (value) (lens-check (.lens) [value] sources: [value]))
    (if (eq? metadata proposed) [metadata] (list metadata proposed))))

;; Prepare graph edits from the current WHOLE snapshot and proposed approvals.
;; prepare receives (current-graph, final-admission) and returns an existing guarded
;; graph request. final-admission runs after local normalization/admission but before
;; old graph retirement. Every entry's approval and the joint rule belong there.
;; Freeze both installed/proposed metadata using existing lens revision guards.
(def (stage-with owner proposed prepare admit)
  (publication.stage-joint-with owner
    (lambda (expected)
      (def installed (publication.snapshot-metadata expected))
      (def checks (guards installed proposed))
      (def request (with-lens-checks checks
        (lambda () (prepare (publication.snapshot-graph expected)
          (lambda (candidate) (admit installed proposed candidate))))))
      (lambda (actual)
        (unless (eq? actual expected) (error "stale recursive approval snapshot"))
        (with-lens-checks checks
          (lambda () (values (request (publication.snapshot-graph actual)) proposed)))))))

;; Guard the metadata of one captured snapshot through its complete observer.
(def (observe-state state observer)
  (def metadata (publication.snapshot-metadata state))
  (with-lens-checks (guards metadata metadata) (lambda () (observer state))))

;; Install the admitted whole pair, then run the entry's guarded observer. Late
;; effect refusal/exception keeps the new pair, matching ordinary graph publication.
(def (submit! owner request observer)
  (publication.submit-joint! owner request (lambda (state) (observe-state state observer))))

;; Observe one consistent installed graph/approval pair. Existing supported-write
;; guards keep metadata immutable during refinement and exact evidence publication.
;; Failure retains installed state; explicit staging captures any newer revisions.
(def (observe! owner observer)
  (publication.observe-joint! owner
    (lambda (state) (observe-state state observer))))

;; One immutable observation belongs to its exact request. Returned effect refusal
;; remains in values; failure records only an exception, including observer errors.
(defstruct %attempt (request snapshot values failed? failure) final: #t)
;; Retain request identity so historical attempts can be attributed across rounds.
(def attempt-request %attempt-request)
;; Each attempt records its own post-attempt snapshot, not the batch's final head.
(def attempt-snapshot %attempt-snapshot)
;; Preserve all observer values, including #f and ordinary returned policy refusal.
(def attempt-values %attempt-values)
;; Separate normal #f/zero values from an exception whose original payload is #f.
(def attempt-failed? %attempt-failed?)
;; Preserve the original exception payload; consult attempt-failed? for its presence.
(def attempt-failure %attempt-failure)

;; Observe one existing submission without inventing a success or a new request.
;; An observer exception can follow installation: capture the actual current pair
;; AFTER guard cleanup, so the receipt never pretends that graph was rolled back.
(def (submit-attempt owner submission)
  (try
    (call-with-values (lambda () (submit! owner (car submission) (cdr submission)))
      (lambda returned
        (make-%attempt (car submission) (publication.snapshot owner) returned #f #f)))
    (catch (cause)
      (make-%attempt (car submission) (publication.snapshot owner) [] #t cause))))

;; Preflight/copy the entire ordered (request . observer) stream before publishing.
;; Standard foldl continues after refusal and retains every per-attempt outcome.
;; No automatic restaging/reapproval or transaction across the sequence occurs;
;; callers explicitly prepare fresh work between sequences against the current pair.
(def (submit-sequence! owner submissions)
  (unless (list? submissions) (error "proper recursive submission list required"))
  (def queue (map (lambda (submission)
    (unless (and (pair? submission) (procedure? (car submission)) (procedure? (cdr submission)))
      (error "recursive submission requires request and observer procedures"))
    (cons (car submission) (cdr submission))) submissions))
  (reverse (foldl (lambda (submission outcomes)
    (cons (submit-attempt owner submission) outcomes)) [] queue)))

;; Supply scoped enqueue!, advance! and pending? procedures to one coordinator.
;; Standard FIFO storage allows new arrivals and explicit restaging between
;; attempts without draining older work. Only advance! installs; each call returns
;; the existing lossless receipt, or #f for an empty queue. Requests are never
;; refreshed implicitly. Caller serialization and complete guards remain premises.
;; Normal return requires a drained queue; exceptional exit releases pending work,
;; closes escaped operations and keeps every already installed prefix. A scope
;; cannot be reentered through a captured continuation after cleanup. on-exit
;; follows the existing coordinator outcome-thunk convention: after cleanup it
;; receives a thunk returning all values or raising the exact original payload.
;; Its default propagates that outcome. An explicit handler may open a new scope;
;; handler failures propagate once and do not trigger this handler recursively.
(def (call-with-submissions owner coordinate
       on-exit: (on-exit (lambda (outcome) (outcome))))
  (unless (and (procedure? coordinate) (procedure? on-exit))
    (error "recursive submission coordinator and exit handler must be procedures"))
  (def pending (queue.make-Queue))
  (def phase 'new)
  ;; Callbacks cannot consume or extend the queue while its current attempt runs.
  (def (check-open)
    (unless (eq? phase 'open) (error "recursive submission scope is not open")))
  ;; Copy one checked pair before admitting it; no caller-owned list is retained.
  (def (enqueue! request observer)
    (check-open)
    (unless (and (procedure? request) (procedure? observer))
      (error "recursive submission requires request and observer procedures"))
    (queue.enqueue! pending (cons request observer)))
  ;; Remove exactly one request and reuse ordinary guarded publication/receipts.
  (def (advance!)
    (check-open)
    (if (queue.queue-empty? pending) #f
      (dynamic-wind
        (lambda () (check-open) (set! phase 'advancing))
        (lambda () (submit-attempt owner (queue.dequeue! pending)))
        (lambda () (set! phase 'open)))))
  ;; Querying the queue also requires the active, non-reentrant coordinator scope.
  (def (pending?)
    (check-open)
    (not (queue.queue-empty? pending)))
  ;; Complete cleanup before capturing the outcome or invoking recovery policy.
  (def (run)
    (dynamic-wind
      (lambda ()
        (unless (eq? phase 'new) (error "recursive submission scope cannot be resumed"))
        (set! phase 'open))
      (lambda ()
        (call-with-values (lambda () (coordinate enqueue! advance! pending?))
          (lambda returned
            (unless (queue.queue-empty? pending) (error "unconsumed recursive submissions"))
            (apply values returned))))
      (lambda () (set! phase 'closed) (set! pending (queue.make-Queue)))))
  ;; Catch only the completed coordinator. Never catch an error from on-exit.
  (def outcome
    (try (call-with-values run (lambda returned (lambda () (apply values returned))))
      (catch (cause) (lambda () (raise cause)))))
  (on-exit outcome))
