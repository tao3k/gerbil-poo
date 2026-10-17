;;; Scoped native installation workers with explicit coordinator-controlled release.
(export call-with-installations)
(import :std/sync/channel (prefix-in ../joint-publication joint.))
;; The coordinator receives start and receive procedures. start waits for one
;; worker's readiness and returns its one-shot release procedure; receive observes
;; one completed install. New receipts may be prepared while older workers wait.
;; All coordination is single-caller IO; report is pure and outside the owner lock.
;; Successful scope exit requires every started result to have been observed.
(def (call-with-installations owner use report: (report (lambda (_ snapshot failure) (cons snapshot failure))))
  (def ready (make-channel)) (def output (make-channel))
  (def workers []) (def open? #t) (def outstanding 0)
  ;; Escaped coordinator procedures cannot create work after resource cleanup.
  (def (ensure-open!) (unless open? (error "closed joint installation scope")))
  ;; Preserve fixed bounds and original exceptions instead of partial results.
  (def (get channel)
    (def value (channel-get channel 5 'timeout))
    (when (eq? value 'timeout) (error "joint worker rendezvous timed out")) value)
  ;; Each receipt owns a release channel; ready acknowledgement precedes return.
  (def (start receipt)
    (ensure-open!)
    (def release (make-channel)) (def released? #f)
    (def worker (make-thread (lambda ()
      (try
        (channel-put ready 'ready)
        (unless (eq? (get release) 'go) (error "invalid joint release"))
        (call-with-values (lambda () (joint.install! owner receipt))
          (lambda (snapshot failure) (channel-put output (lambda () (report receipt snapshot failure)))))
        (catch (failure) (channel-put output (lambda () (raise failure))))))))
    (set! workers (cons worker workers)) (set! outstanding (+ outstanding 1))
    (thread-start! worker) (get ready)
    (lambda ()
      (ensure-open!)
      (when released? (error "joint worker already released"))
      (set! released? #t) (channel-put release 'go)))
  ;; Receiving consumes exactly one result; no implicit retry or reapproval occurs.
  (def (receive)
    (ensure-open!)
    (unless (> outstanding 0) (error "no outstanding joint installation"))
    (def result (get output)) (set! outstanding (- outstanding 1)) (result))
  (try
    (call-with-values (lambda () (use start receive)) (lambda results
      (unless (= outstanding 0) (error "unobserved joint installation results"))
      (for-each (lambda (worker)
        (when (eq? (thread-join! worker 5 'timeout) 'timeout) (error "joint worker join timed out"))) workers)
      (apply values results)))
    (finally (set! open? #f) (for-each thread-terminate! workers))))
