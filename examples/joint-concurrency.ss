;;; Bounded native thread composition for already-approved joint receipts.
(export install-concurrently)
(import :std/sync/channel (prefix-in ../joint-publication joint.))
;; Standard channels form a ready/release rendezvous AFTER all approval calls.
;; before-release may coordinate declared external changes while workers wait;
;; it must return locally. Results retain completion order, not input order.
;; Each worker uses existing install!, so the owner lock remains the only
;; publication critical section. No approval or automatic retry happens here.
(def (install-concurrently owner receipts before-release: (before-release void))
  (unless (list? receipts) (error "proper joint receipt list required"))
  (def ready (make-channel)) (def release (make-channel)) (def output (make-channel))
  (def workers [])
  ;; Bounded receives turn broken coordination into failure, never a partial pass.
  (def (receive channel)
    (def value (channel-get channel 5 'timeout))
    (when (eq? value 'timeout) (error "joint installation rendezvous timed out")) value)
  (try
    (for-each (lambda (receipt)
      ;; Retain each handle immediately, including if later thread setup fails.
      (def worker (make-thread (lambda ()
        (try
          (channel-put ready 'ready)
          (unless (eq? (receive release) 'go) (error "invalid joint release"))
          (call-with-values (lambda () (joint.install! owner receipt))
            (lambda (snapshot failure) (channel-put output (lambda () (cons snapshot failure)))))
          ;; Transport the original exception to the caller through a thunk.
          (catch (failure) (channel-put output (lambda () (raise failure))))))))
      (set! workers (cons worker workers)) (thread-start! worker)) receipts)
    (for-each (lambda (_) (receive ready)) receipts)
    (before-release)
    (for-each (lambda (_) (channel-put release 'go)) receipts)
    (def outcomes (map (lambda (_) ((receive output))) receipts))
    (for-each (lambda (worker)
      (when (eq? (thread-join! worker 5 'timeout) 'timeout) (error "joint installation worker join timed out"))) workers)
    outcomes
    (finally (for-each thread-terminate! workers))))
