;;; Continuing arrivals and explicit retries over one shared recursive publication.
(export publish-continuously!)
(import ../object
        ../mop
        (runtime: :clan/poo/recursive-approvals)
        (prefix-in (only-in ../recursive-approvals call-with-submissions) approvals.)
        (runtime: :clan/poo/recursive-publication)
        (prefix-in (only-in ../recursive-publication snapshot snapshot-metadata) publication.)
        (prefix-in ./recursive-approvals service.))

;; observer-for maps an entry/round to an existing FUN snapshot observer; report
;; receives (round, phase, receipt). New arrivals enter before older work drains.
;; Failed approval is followed by explicit current-snapshot staging, never by
;; refreshing the old request. report may inspect receipts but must serialize use
;; of the shared owner. Successful prefixes remain installed if a callback raises.
(def (publish-continuously! owner policies observer-for report)
  (approvals.call-with-submissions owner
    (lambda (enqueue! advance! pending?)
      ;; Deliver one existing per-attempt receipt without interpreting business values.
      (def (attempt! round label) (report round label (advance!)))
      (let loop ((remaining policies) (round 0) (carried []))
        (if (null? remaining)
          (begin
            (for-each (lambda (_) (attempt! round 'historical)) carried)
            (pending?))
          (let* ((proposed (car remaining))
                 (future (if (pair? (cdr remaining)) (cadr remaining) proposed))
                 (observer (observer-for round))
                 (installed (publication.snapshot-metadata (publication.snapshot owner)))
                 (p0 (service.stage-transition owner proposed))
                 (q0 (service.stage-transition owner future)))
            (enqueue! p0 observer)
            (enqueue! q0 observer)
            (.put! proposed 'budget 201)
            (.put! proposed 'budget 200)
            (for-each (lambda (_) (attempt! round 'historical)) carried)
            (attempt! round 'proposed-stale)
            (let ((p1 (service.stage-transition owner proposed))
                  (q1 (service.stage-transition owner future)))
              (enqueue! p1 observer)
              (enqueue! q1 observer)
              (.put! installed 'budget 201)
              (.put! installed 'budget 200)
              (attempt! round 'installed-stale)
              (attempt! round 'installed-stale)
              (let* ((bad (.cc proposed budget: (- (.get proposed expected) 1)))
                     (refused (service.stage-transition owner bad))
                     (winner (service.stage-transition owner proposed))
                     (challenger (service.stage-transition owner future)))
                (enqueue! refused observer)
                (enqueue! winner observer)
                (enqueue! challenger observer)
                (attempt! round 'installed-stale)
                (attempt! round 'joint-refusal)
                (attempt! round 'winner)
                ;; Keep both a competing future intent and a spent winner queued
                ;; while the next round admits freshly staged requests behind them.
                (enqueue! winner observer)
                (loop (cdr remaining) (+ round 1) '(challenger replay))))))))))
