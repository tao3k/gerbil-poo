(export coordinator-interleaving-test)
(import :std/test :std/sync/channel :std/sync/threads
        (prefix-in ../joint-publication joint.)
        (prefix-in ../examples/joint-topology service.)
        ../examples/joint-coordination-rounds ../examples/coordinator-rejoining
        ./joint-coordination-cases)
;; Private named state belongs to the supervisor; workers communicate by channel.
(defstruct recovery (gate receipts threads failures restarts exits) final: #t)
;; Bounded handshakes expose stalled or misrouted recovery instead of sleeping.
(def (get channel)
  (def value (channel-get channel 5 'timeout))
  (when (eq? value 'timeout) (error "interleaved recovery rendezvous timed out")) value)
;; Keep actual handles across incarnations, including children awaiting installation.
(def (terminated? thread)
  (def state (thread-state thread))
  (or (thread-state-normally-terminated? state) (thread-state-abnormally-terminated? state)))
;; Two independent failed names interleave, then fail in one wave in either order.
;; Restarted d remains paused while c rejoins, fails again and rejoins alongside d.
(def (check-interleaved order)
  (def owner (service.start)) (def prepared (make-channel)) (def joined (make-channel))
  (def states (map (lambda (name) (cons name (make-recovery (make-channel) [] [] 0 0 0))) '(c d)))
  (def failures (map (lambda (name) (cons name (list name 'failed))) '(c d)))
  (def round 0) (def waiting []) (def release-ready #f) (def before-exit #f)
  ;; State lookup is only for recovering names, never for the persistent peers.
  (def (state name) (cdr (assq name states)))
  ;; Rejoin rounds differ from launch rounds: replacement operations may wait.
  (def (rejoining)
    (case round ((2 5) '(c)) ((3) '(d)) ((6) order) (else [])))
  ;; Initial and restored four-way competition alternates with partial failures.
  (def (failing)
    (case round ((1 5) '(c)) ((2) '(d)) ((4) order) (else [])))
  ;; d's second replacement is intentionally absent from the fifth round.
  (def (active) (if (= round 5) '(a b c) '(a b c d)))
  ;; A replacement explicitly refuses all historical receipts before construction.
  ;; Per-phase worker handles are sent to the supervisor before its ready checkpoint.
  (def (operation name recovered?)
    (lambda (exchange)
      (when recovered?
        (let ((receipts (get (recovery-gate (state name)))) (before (joint.current owner)))
          (for-each (lambda (receipt)
            (call-with-values (lambda () (joint.install! owner receipt))
              (lambda (snapshot failure)
                (check (not (not failure)) => #t) (check (eq? snapshot before) => #t)))) receipts))
        (channel-put joined name))
      (coordinate-revisions owner (lambda (message)
        (when (eq? (car message) 'ready)
          (channel-put prepared (cons name (thread-group->thread-list* (current-thread-group)))))
        (exchange message)))))
  ;; Resume all selected names before consuming unordered ready acknowledgements.
  (def (resume-recovered)
    (def names (rejoining))
    (for-each (lambda (name)
      (channel-put (recovery-gate (state name)) (recovery-receipts (state name)))) names)
    (let ((arrivals (map (lambda (_) (get joined)) names)))
      (for-each (lambda (name)
        (check-equal? (length (filter (lambda (seen) (eq? name seen)) arrivals)) 1)) names)))
  ;; Release one failing incarnation at a time; only after all exits are observed
  ;; may live peers publish. Winning order among live primaries remains unrestricted.
  (def (advance)
    (if (pair? waiting)
      (release-ready (lambda (name receipt)
        (def item (state name))
        (recovery-receipts-set! item (cons receipt (recovery-receipts item)))
        (cdr (assq name failures))) [(car waiting)])
      (release-ready (lambda (_ __) 'install)
        (filter (lambda (name) (not (memq name (failing)))) (active)))))
  (call-with-rejoining-coordinators
    [(cons 'a (lambda (exchange) (coordinate-revisions owner exchange)))
     (cons 'b (lambda (exchange) (coordinate-revisions owner exchange)))
     (cons 'c (operation 'c #f)) (cons 'd (operation 'd #f))]
    (lambda (next)
      (check-revisions owner next
        participants: (lambda (_ phase)
          (when (eq? phase 'next) (set! round (+ round 1)) (resume-recovered))
          (if (eq? phase 'published)
            (filter (lambda (name) (not (memq name (failing)))) (active)) (active)))
        before-release: (lambda (_ release)
          (for-each (lambda (_)
            (def entry (get prepared)) (def item (state (car entry)))
            (recovery-threads-set! item (append (cdr entry) (recovery-threads item))))
            (filter (lambda (name) (memq name '(c d))) (active)))
          (set! release-ready release) (set! waiting (failing))
          (set! before-exit (joint.current owner)) (advance))))
    (lambda (name outcome)
      (if (memq name '(c d))
        (let ((item (state name)))
          (recovery-exits-set! item (+ 1 (recovery-exits item)))
          (try (outcome) #f (catch (failure)
            (check (eq? failure (cdr (assq name failures))) => #t)
            (check-equal? (car waiting) name)
            (check (eq? before-exit (joint.current owner)) => #t)
            (check (andmap terminated? (recovery-threads item)) => #t)
            (recovery-failures-set! item (+ 1 (recovery-failures item)))
            (recovery-restarts-set! item (+ 1 (recovery-restarts item)))
            (set! waiting (cdr waiting)) (advance)
            (operation name #t))))
        (begin (outcome) #f))))
  (for-each (lambda (entry)
    (def item (cdr entry)) (def expected (if (eq? (car entry) 'c) 3 2))
    (check-equal? (recovery-failures item) expected)
    (check-equal? (recovery-restarts item) expected)
    (check-equal? (recovery-exits item) (+ expected 1))
    (check (andmap terminated? (recovery-threads item)) => #t)) states)
  (check-equal? (service.value (joint.current owner) 'a) 12))
;; Opposite joint-exit orders exercise name routing; rejoin arrivals and winners are free.
(def coordinator-interleaving-test
  (test-suite "multiple failed coordinators interleave recovery and publication"
    (test-case "c then d exit order" (check-interleaved '(c d)))
    (test-case "d then c exit order" (check-interleaved '(d c)))
    (test-case "a later recovery failure cleans another name's live replacement"
      (def failure (list 'recovery-failed)) (def replies []) (def threads [])
      (check-exception (call-with-rejoining-coordinators
        (map (lambda (name) (cons name (lambda (exchange)
          (exchange (list (current-thread))) (raise name)))) '(c d))
        (lambda (next)
          (for-each (lambda (_)
            (next (lambda (name handles reply)
              (set! threads (append handles threads))
              (set! replies (cons (cons name reply) replies))))) '(c d))
          ((cdr (assq 'c replies)) 'fail)
          (next (lambda (name handles _)
            (check-equal? name 'c) (check-equal? (length handles) 2)
            (set! threads (append handles threads))))
          ((cdr (assq 'd replies)) 'fail)
          (next (lambda _ (error "unexpected checkpoint after recovery failure"))))
        (lambda (name outcome)
          (check-exception (outcome) (lambda (caught) (eq? caught name)))
          (if (eq? name 'd) (raise failure)
            (lambda (exchange)
              (def ready (make-channel)) (def blocked (make-channel))
              (def child (make-thread (lambda () (channel-put ready 'ready) (get blocked))))
              (thread-start! child) (get ready)
              (exchange (list (current-thread) child))))))
        (lambda (caught) (eq? caught failure)))
      (check (andmap terminated? threads) => #t))
    (test-case "malformed recovery is rejected even during final joins"
      (check-exception (call-with-rejoining-coordinators
        [(cons 'c (lambda (_) 'done))] (lambda (_) 'finished)
        (lambda (_ outcome) (outcome) 42)) true))))
