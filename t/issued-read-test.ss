;;; Native producer-owned issuance tests; no Core fixtures or dependencies.
(export issued-read-test test-cleanup!)
(import :std/test ../object ../slot-observation
        (prefix-in (only-in :gerbil/runtime/mop slot-ref slot-set!) runtime.)
        (only-in :gerbil/expander current-expander-context make-top-context
                 core-import-module module-context-export module-export-name)
        (only-in :std/error Error? Error-message))
(def completed 0)
(def (test-cleanup!)
  (check-equal? completed 13)
  (displayln "ISSUED-READ: 13 cases completed"))
(def (recorded action)
  (def reads '())
  (call-with-slot-read-observer (lambda (r) (set! reads (cons r reads))) action)
  (reverse reads))
(def (refuses message action)
  (def failure (with-catch values action))
  (unless (Error? failure) (error "expected native refusal" message failure))
  (check-equal? (Error? failure) #t)
  (check-equal? (Error-message failure) message))
(def (selected roots key)
  (car (filter (lambda (r) (equal? (slot-read-key r) key)) roots)))
(def (copy-read read)
  (make-slot-read (slot-read-receiver read) (slot-read-key read)
    (slot-read-revision read) (slot-read-instance read) (slot-read-value read)
    (slot-read-dependencies read) object-read-current?))
(def (miss-witness receiver)
  (def watcher (make-hash-table test: eq? weak-keys: #t))
  (for-each (lambda (read) (hash-put! watcher read #t))
    (recorded (cut .ref/cached receiver 'missing (lambda () #f))))
  watcher)
(def issued-read-test
 (test-suite "Native issuance with transient tokens and guarded replay"
  (test-case "the SDK export interface does not expose native mint helpers"
    (def names
      (parameterize ((current-expander-context (make-top-context)))
        (map module-export-name
          (module-context-export (core-import-module ':clan/poo/object)))))
    (for-each (lambda (name) (check-equal? (memq name names) #f))
      '(object-record-read object-read-query object-read-bootstrap
        object-deliver-value object-issued-read-current? require-object-read-route!
        call-with-issued-reads active-read-replays))
    (check-equal? (and (memq 'object-read-issued? names) #t) #t)
    (set! completed (+ completed 1)))
  (test-case "real persistent records authenticate but public copies do not"
    (.def Root port: 5432 unused: (error "unselected branch forced"))
    (def roots (recorded (cut .get Root port)))
    (def genuine (selected roots 'port))
    (def forged (copy-read genuine))
    (check-equal? (object-read-issued? genuine) #t)
    (check-equal? (object-read-issued? forged) #f)
    (check-equal? (object-read-current? forged) #f)
    (refuses "unissued slot dependency"
      (cut replay-slot-reads! (list forged) (lambda (_r _k) (error "must not observe"))))
    (replay-slot-reads! roots (lambda (_r _k) (void)))
    (set! completed (+ completed 1)))
  (test-case "transient miss is issued without being put in the receiver cache"
    (.def Root port: 5432)
    (def roots (recorded (cut .ref/cached Root 'missing (lambda () #f))))
    (def key '(cache-miss missing))
    (def genuine (selected roots key))
    (check-equal? (hash-key? (object-%instance Root) 'missing) #f)
    (check-equal? (hash-get (object-%reads Root) key) #f)
    (check-equal? (object-read-issued? genuine) #t)
    (check-equal? (object-read-current? genuine) #t)
    (check-equal? (object-read-issued? (copy-read genuine)) #f)
    (replay-slot-reads! roots (lambda (_r _k) (void)))
    (set! completed (+ completed 1)))
  (test-case "a borrowed birth cannot authorize a copy or a changed payload"
    (.def Root port: 5432)
    (def genuine (selected (recorded (cut .get Root port)) 'port))
    (def forged (copy-read genuine))
    (runtime.slot-set! forged 'birth (runtime.slot-ref genuine 'birth))
    (check-equal? (object-read-issued? forged) #f)
    (runtime.slot-set! genuine 'value 5440)
    (check-equal? (object-read-issued? genuine) #f)
    (check-equal? (object-read-current? genuine) #f)
    (set! completed (+ completed 1)))
  (test-case "the entire dependency closure is authenticated before observing any root"
    (.def External port: 5432)
    (.get External port)
    (def calls 0)
    (def forged (make-slot-read External 'port (object-revision External)
      (object-%instance External) 5432 '() (lambda (_read) (set! calls (+ calls 1)) #t)))
    (.def Root port: (begin (%deliver-slot-read forged #t) 5432))
    (def roots (recorded (cut .get Root port)))
    (def observed 0)
    (refuses "unissued slot dependency"
      (cut replay-slot-reads! roots (lambda (_r _k) (set! observed (+ observed 1)))))
    (check-equal? calls 0)
    (check-equal? observed 0)
    (set! completed (+ completed 1)))
  (test-case "native replay refuses a changed metadata method before executing it"
    (.def Root port: 5432)
    (def roots (recorded (cut .get Root port)))
    (def calls 0)
    (runtime.slot-set! (object-%reads Root) 'ref
      (lambda (_self _key _default) (set! calls (+ calls 1)) #f))
    (refuses "changed metadata ref"
      (cut replay-slot-reads! roots (lambda (_r _k) (void))))
    (check-equal? calls 0)
    (set! completed (+ completed 1)))
  (test-case "callback edits of checker payload are refused in the final native sweep"
    (.def Root port: 5432)
    (def roots (recorded (cut .get Root port)))
    (def genuine (selected roots 'port))
    (def calls 0)
    (refuses "unissued slot dependency"
      (lambda ()
        (replay-slot-reads! roots
          (lambda (_r key)
            (when (eq? key 'port)
              (runtime.slot-set! genuine 'current?
                (lambda (_read) (set! calls (+ calls 1)) #t)))))))
    (check-equal? calls 0)
    (set! completed (+ completed 1)))
  (test-case "replacing birth cannot execute a foreign authenticator"
    (.def Root port: 5432)
    (def genuine (selected (recorded (cut .get Root port)) 'port))
    (def calls 0)
    (runtime.slot-set! genuine 'birth
      (lambda (_read) (set! calls (+ calls 1)) #t))
    (check-equal? (object-read-issued? genuine) #f)
    (check-equal? calls 0)
    (set! completed (+ completed 1)))
  (test-case "a live miss survives GC while dead transient records are not rooted"
    (.def Root port: 5432)
    (def live (selected (recorded (cut .ref/cached Root 'live-missing (lambda () #f)))
                        '(cache-miss live-missing)))
    (def watcher (miss-witness Root))
    (##gc)
    (##gc)
    (check-equal? (object-read-issued? live) #t)
    (check-equal? (object-read-current? live) #t)
    (check-equal? (hash-length watcher) 0)
    (check-equal? (hash-get (object-%reads Root) '(cache-miss missing)) #f)
    (check-equal? (.get Root port) 5432)
    (set! completed (+ completed 1)))

  (test-case "metadata replaced inside an observer is refused before later dispatch"
    (.def Root port: 5432)
    (def roots (recorded (cut .get Root port)))
    (def calls 0)
    (refuses "changed metadata ref"
      (lambda ()
        (replay-slot-reads! roots
          (lambda (_receiver key)
            (when (eq? key 'port)
              (runtime.slot-set! (object-%reads Root) 'ref
                (lambda (_self _key _default) (set! calls (+ calls 1)) #f)))))))
    (check-equal? calls 0)
    (set! completed (+ completed 1)))

  (test-case "warm reobservation forwards the original issued graph"
    (.def Root port: 5432 unused: (error "unselected field forced"))
    (def roots (recorded (cut .get Root port)))
    (def original (selected roots 'port))
    (def forwarded (recorded (cut reobserve-slot-reads! roots)))
    (check-equal? (and (memq original forwarded) #t) #t)
    (check-equal? (andmap object-read-issued? forwarded) #t)
    (set! completed (+ completed 1)))
  (test-case "warm reobservation authenticates before work and protects delivery"
    (.def Root port: 5432)
    (def genuine (selected (recorded (cut .get Root port)) 'port))
    (def calls 0)
    (refuses "unissued slot dependency"
      (cut reobserve-slot-reads! (list (copy-read genuine))
        (lambda () (set! calls (+ calls 1)))))
    (check-equal? calls 0)
    (refuses "object mutation during read replay"
      (cut reobserve-slot-reads! (list genuine) (lambda () (.put! Root 'port 5440))))
    (check-equal? (.get Root port) 5432)
    (refuses "object mutation during read replay"
      (lambda ()
        (call-with-slot-read-observer
          (lambda (_read) (.put! Root 'port 5440))
          (cut reobserve-slot-reads! (list genuine)))))
    (check-equal? (.get Root port) 5432)
    (set! completed (+ completed 1)))
  (test-case "warm reobservation reauthenticates after delivery callbacks"
    (.def Root port: 5432)
    (def genuine (selected (recorded (cut .get Root port)) 'port))
    (def calls 0)
    (refuses "unissued slot dependency"
      (lambda ()
        (call-with-slot-read-observer
          (lambda (read)
            (when (eq? read genuine)
              (runtime.slot-set! read 'current?
                (lambda (_read) (set! calls (+ calls 1)) #t))))
          (cut reobserve-slot-reads! (list genuine)))))
    (check-equal? calls 0)
    (set! completed (+ completed 1)))
))
