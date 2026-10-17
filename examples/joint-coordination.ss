;;; Scoped independent coordinators share an owner but not worker-scope counters.
(export call-with-coordinators)
(import :std/sync/channel :std/sync/threads (only-in :std/list/list delete-duplicates/hash))
;; Each named operation receives exchange: send one checkpoint and wait for a
;; one-shot supervisor reply. observe receives next, which invokes a handler with
;; coordinator name, payload and reply procedure. All communication is bounded.
;; A detached standard-library thread group owns coordinators AND their workers.
(def (call-with-coordinators operations observe)
  (unless (and (list? operations)
    (andmap (lambda (entry) (and (pair? entry) (symbol? (car entry)) (procedure? (cdr entry)))) operations)
    (= (length operations) (length (delete-duplicates/hash (map car operations)))))
    (error "distinct named coordinator operations required"))
  (def group (make-detached-thread-group 'joint-coordinators))
  (def events (make-channel)) (def running []) (def open? #t)
  ;; Bounded checkpoint receives never turn stalled coordinators into success.
  (def (get channel)
    (def value (channel-get channel 5 'timeout))
    (when (eq? value 'timeout) (error "joint coordinator checkpoint timed out")) value)
  ;; Supervision consumes an event thunk, preserving the operation's original error.
  (def (next handler)
    (unless open? (error "closed joint coordinator scope")) ((get events) handler))
  (try
    (for-each (lambda (entry)
      (def inbox (make-channel)) (def done (make-channel))
      ;; Only this coordinator calls exchange; replies are one-shot supervisor IO.
      (def (exchange value)
        (channel-put events (lambda (handler)
          (def replied? #f)
          (handler (car entry) value (lambda (reply)
            (unless open? (error "closed joint coordinator reply"))
            (when replied? (error "joint coordinator already replied"))
            (set! replied? #t) (channel-put inbox reply)))))
        (get inbox))
      (def worker (make-thread (lambda ()
        (try
          (call-with-values (lambda () ((cdr entry) exchange))
            (lambda results (channel-put done (lambda () (apply values results)))))
          (catch (failure)
            (channel-put events (lambda (_) (raise failure)))
            (channel-put done (lambda () (raise failure)))))) (car entry) group))
      (set! running (cons (cons worker done) running)) (thread-start! worker)) operations)
    (call-with-values (lambda () (observe next)) (lambda results
      ;; A supervisor cannot conceal a coordinator failure by ignoring its event.
      (for-each (lambda (entry)
        (call-with-values (get (cdr entry)) (lambda ignored (void)))
        (when (eq? (thread-join!/error (car entry) 5 'timeout) 'timeout)
          (error "joint coordinator join timed out"))) running)
      (apply values results)))
    (finally (set! open? #f) (thread-group-kill! group))))
