;;; Joint revisions of one recursive graph and shared approval metadata.
(export stage-with submit! observe!)
(import ./object ./mop ./lens-laws
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
