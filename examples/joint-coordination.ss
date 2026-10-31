;;; Scoped independent coordinators share an owner but not worker-scope counters.
(export call-with-coordinators)
(import :std/sync/channel :std/sync/threads (only-in :std/list/list delete-duplicates/hash))
;; Each named operation receives exchange: send one checkpoint and await a
;; one-shot reply. observe receives next, which skips completed operations and
;; invokes its handler with coordinator name, payload and reply procedure.
;; on-exit receives the name and an outcome thunk, AFTER that coordinator's child
;; threads have stopped. Calling outcome preserves all values or the original
;; exception. The default propagates failure; an explicit handler can isolate it.
;; restart receives a completed name during live next processing, after on-exit.
;; Return a fresh operation or #f; default #f never retries. New incarnations own
;; new child groups/inboxes. Final joins observe outcomes but cannot restart work.
;; Receives/normal joins are bounded; finally cleans the whole detached group.
(def (call-with-coordinators operations observe
       on-exit: (on-exit (lambda (_ outcome) (outcome)))
       restart: (restart (lambda (_) #f)))
  (unless (and (list? operations)
    (andmap (lambda (entry) (and (pair? entry) (symbol? (car entry)) (procedure? (cdr entry)))) operations)
    (= (length operations) (length (delete-duplicates/hash (map car operations)))))
    (error "distinct named coordinator operations required"))
  (def group (make-detached-thread-group 'joint-coordinators))
  (def events (make-channel)) (def running []) (def open? #t) (def accepting? #t)
  ;; Bounded checkpoint receives never turn stalled coordinators into success.
  (def (get channel)
    (def value (channel-get channel 5 'timeout))
    (when (eq? value 'timeout) (error "joint coordinator checkpoint timed out")) value)
  ;; Terminal events are supervised before looking for the next live checkpoint.
  (def (next handler)
    (unless (and open? accepting?) (error "closed joint coordinator scope")) ((get events) handler))
  ;; Only the supervisor launches incarnations, after a previous one has stopped.
  ;; Every generation retains its final join, including replacements launched later.
  (def (launch entry)
    (def scope (make-thread-group (car entry) group))
    (def inbox (make-channel)) (def done (make-channel)) (def observed? #f)
    ;; Exactly one supervisor call observes this outcome, even if its event was
    ;; not consumed before observe returned. Callback errors abort the scope.
    (def (finish (continue? #f))
      (unless observed?
        (set! observed? #t)
        (let ((outcome (get done)))
          (when (eq? (thread-join!/error worker 5 'timeout) 'timeout)
            (error "joint coordinator join timed out"))
          (call-with-values (lambda () (on-exit (car entry) outcome))
            (lambda ignored (void))))
        (when continue?
          (let ((operation (restart (car entry))))
            (when operation
              (unless (procedure? operation) (error "coordinator restart must be an operation or #f"))
              (launch (cons (car entry) operation)))))))
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
      (channel-put events (lambda (handler) (finish #t) (next handler)))) (car entry) scope))
    (set! running (cons finish running)) (thread-start! worker))
  (try
    (for-each launch operations)
    (call-with-values (lambda () (observe next)) (lambda results
      (set! accepting? #f)
      ;; Returning early cannot hide any unobserved coordinator exception.
      (for-each (lambda (finish) (finish)) running)
      (apply values results)))
    (finally (set! open? #f) (thread-group-kill! group))))
