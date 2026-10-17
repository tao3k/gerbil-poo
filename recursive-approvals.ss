;;; Joint revisions of one recursive graph and shared approval metadata.
(export stage-with submit! observe! submit-sequence!
        attempt-request attempt-snapshot attempt-values attempt-failed? attempt-failure)
(import (only-in :std/list/list foldl) ./object ./mop ./lens-laws
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
