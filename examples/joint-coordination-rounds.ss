;;; Continuing cross-service revisions, independent of supervision policy.
(export coordinate-revisions observation observation? make-observation
        observation-receipt observation-snapshot observation-failure)
(import ../object ../mop ../brace
        (prefix-in ../examples/joint-topology service.)
        (prefix-in ../examples/joint-receipts receipts.)
        (prefix-in ../examples/joint-workers workers.)
        (prefix-in ../construction-cache cache.))
;; Never reconstruct the independent shared dependency while revising SCCs.
(def builder (.cc cache.Builder. allow: (lambda (key) (not (eq? key 'stable)))))
;; Preserve receipt identity, whole snapshots and explicit refusal reasons.
(defstruct observation (receipt snapshot failure) final: #t)
;; Every coordinator owns its own installation scope and counter/receive channel.
;; It retains a late worker across concurrent next-round construction and retry.
(def (coordinate-revisions owner exchange)
  (workers.call-with-installations owner (lambda (start receive)
    (let loop ((old-go #f) (old-receipt #f))
      (def command (exchange '(next)))
      (def changes (map (lambda (key) (cons key (.cc service.Change. phase: (car command)))) '(a b)))
      (def bad (car (receipts.approve-revisions owner [changes] (cadr command) builder)))
      (def bad-go (start bad))
      (exchange (list 'approved bad))
      (bad-go) (def refused (receive))
      (def fresh-policy (exchange (list 'refused refused)))
      ;; Both coordinators explicitly capture CURRENT sources again after refusal.
      (def fresh (receipts.approve-revisions owner [changes changes] fresh-policy builder))
      (def primary-go (start (car fresh))) (def later-go (start (cadr fresh)))
      (exchange (list 'ready (car fresh)))
      (when old-go (old-go)) (primary-go)
      (def results (if old-go [(receive) (receive)] [(receive)]))
      (def decision (exchange (list 'published (car fresh) old-receipt results)))
      (if (eq? decision 'finish)
        (begin (later-go) (exchange (list 'drained (receive))) (void))
        (loop later-go (cadr fresh))))) report: make-observation))
