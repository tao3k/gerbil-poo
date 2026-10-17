;;; Scoped independent coordinators share an owner but not worker-scope counters.
(export call-with-coordinators)
(import :std/sync/channel :std/sync/threads (only-in :std/list/list delete-duplicates/hash))
;; Each named operation receives exchange: send one checkpoint and await a
;; one-shot reply. observe receives next, which skips completed operations and
;; invokes its handler with coordinator name, payload and reply procedure.
;; on-exit receives the name and an outcome thunk, AFTER that coordinator's child
;; threads have stopped. Calling outcome preserves all values or the original
;; exception. The default propagates failure; an explicit handler can isolate it.
;; Receives/normal joins are bounded; finally cleans the whole detached group.
(def (call-with-coordinators operations observe
       on-exit: (on-exit (lambda (_ outcome) (outcome))))
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
  ;; Terminal events are supervised before looking for the next live checkpoint.
  (def (next handler)
    (unless open? (error "closed joint coordinator scope")) ((get events) handler))
  (try
    (for-each (lambda (entry)
      (def scope (make-thread-group (car entry) group))
      (def inbox (make-channel)) (def done (make-channel)) (def observed? #f)
      ;; Exactly one supervisor call observes this outcome, even if its event was
      ;; not consumed before observe returned. Callback errors abort the scope.
      (def (finish)
        (unless observed?
          (set! observed? #t)
          (call-with-values (lambda () (on-exit (car entry) (get done)))
            (lambda ignored (void)))))
      ;; Escaped replies close when their coordinator exits, independently of peers.
      (def alive? #t)
      ;; Only this coordinator calls exchange; replies are one-shot supervisor IO.
      (def (exchange value)
        (channel-put events (lambda (handler)
          (def replied? #f)
          (handler (car entry) value (lambda (reply)
            (unless (and open? alive?) (error "closed joint coordinator reply"))
            (when replied? (error "joint coordinator already replied"))
            (set! replied? #t) (channel-put inbox reply)))))
        (get inbox))
      (def worker (make-thread (lambda ()
        ;; Capture failure as data without dropping multiple normal return values.
        (def outcome (try
          (call-with-values (lambda () ((cdr entry) exchange))
            (lambda results (lambda () (apply values results))))
          (catch (failure) (lambda () (raise failure)))
          (finally (set! alive? #f) (thread-group-kill! scope))))
        (channel-put done outcome)
        (channel-put events (lambda (handler) (finish) (next handler)))) (car entry) scope))
      (set! running (cons (cons worker finish) running)) (thread-start! worker)) operations)
    (call-with-values (lambda () (observe next)) (lambda results
      ;; Returning early cannot hide any unobserved coordinator exception.
      (for-each (lambda (entry)
        ((cdr entry))
        (when (eq? (thread-join!/error (car entry) 5 'timeout) 'timeout)
          (error "joint coordinator join timed out"))) running)
      (apply values results)))
    (finally (set! open? #f) (thread-group-kill! group))))
