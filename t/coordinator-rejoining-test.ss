(export coordinator-rejoining-test)
(import :std/test :std/sync/channel :std/sync/threads ../object ../mop ../brace
        (prefix-in ../joint-publication joint.) (prefix-in ../construction-cache cache.)
        (prefix-in ../examples/joint-topology service.) (prefix-in ../examples/joint-receipts receipts.)
        (prefix-in ../examples/joint-workers workers.) (prefix-in ../examples/joint-coordination coordination.)
        ../examples/joint-coordination-rounds ./joint-coordination-cases)
;; Fixed bounds fail stalled recovery without substituting sleeps for progress.
(def (get channel)
  (def value (channel-get channel 5 'timeout))
  (when (eq? value 'timeout) (error "coordinator rejoining rendezvous timed out")) value)
;; Keep saved thread handles: cleanup must terminate actual old workers.
(def (terminated? thread)
  (def state (thread-state thread))
  (or (thread-state-normally-terminated? state) (thread-state-abnormally-terminated? state)))
;; Rejoining creates a new operation, then explicitly checks old capabilities and
;; enters the SAME ongoing service-revision workflow as the other coordinators.
(def coordinator-rejoining-test
  (test-suite "failed coordinators rejoin continuing joint publication"
    (test-case "three recoveries interleave old-receipt refusal and six SCC rounds"
      (def owner (service.start)) (def spawned (make-channel))
      (def initial-go (make-channel)) (def resume-go (make-channel)) (def joined (make-channel))
      (def failure (list 'restart-coordinator))
      (def policy (.cc (joint.approval (joint.current owner) 'shared) limit: 24 budget: 36))
      (def initial (car (receipts.approve-revisions owner
        [[(cons 'a (.cc service.Change. phase: 'merge))]] policy (.cc cache.Builder.))))
      (def archived [initial]) (def saved []) (def round 0) (def restarts 0) (def exits 0)
      (def failed? #f) (def release-survivors #f) (def before-exit #f)
      ;; Every new incarnation waits for a later round's actual owner, not an old
      ;; failed capture. Old receipts must refuse before any new candidate is built.
      (def (recovered exchange)
        (channel-put spawned (current-thread))
        (def receipts (get resume-go)) (def before (joint.current owner))
        (for-each (lambda (receipt)
          (call-with-values (lambda () (joint.install! owner receipt))
            (lambda (snapshot refused)
              (check (not (not refused)) => #t) (check (eq? snapshot before) => #t)))) receipts)
        (channel-put joined 'rejoined)
        (coordinate-revisions owner (lambda (message)
          (when (eq? (car message) 'ready)
            (set! saved (append (thread-group->thread-list* (current-thread-group)) saved)))
          (exchange message))))
      (coordination.call-with-coordinators
        [(cons 'a (lambda (exchange) (coordinate-revisions owner exchange)))
         (cons 'b (lambda (exchange) (coordinate-revisions owner exchange)))
         (cons 'c (lambda (_)
           (workers.call-with-installations owner (lambda (start __)
             (start initial)
             (channel-put spawned (thread-group->thread-list* (current-thread-group)))
             (get initial-go) (raise failure)))))]
        (lambda (next)
          (set! saved (get spawned))
          (check-revisions owner next
            participants: (lambda (_ phase)
              (when (eq? phase 'next)
                (set! round (+ round 1))
                (when (memv round '(2 4 6))
                  (set! saved (cons (get spawned) saved))
                  (channel-put resume-go archived) (check-equal? (get joined) 'rejoined)))
              (if (or (= round 1) (and (memv round '(3 5)) (eq? phase 'published))) '(a b) '(a b c)))
            before-release: (lambda (_ release)
              (if (memv round '(1 3 5))
                (begin
                  (set! before-exit (joint.current owner))
                  (set! release-survivors (lambda () (release (lambda (_ __) 'install) '(a b))))
                  (if (= round 1)
                    (begin
                      ;; Equal-value round trips invalidate the original shared guard.
                      (.putslot! policy 'budget ($constant-slot-spec 37))
                      (.putslot! policy 'budget ($constant-slot-spec 36))
                      (channel-put initial-go 'fail))
                    (release (lambda (_ receipt)
                      (set! archived (cons receipt archived)) failure) '(c))))
                (release)))))
        on-exit: (lambda (name outcome)
          (if (eq? name 'c)
            (begin
              (set! exits (+ exits 1)) (set! failed? #f)
              (try (outcome) (catch (caught)
                (check (eq? caught failure) => #t) (set! failed? #t)))
              (when failed?
                (check (eq? before-exit (joint.current owner)) => #t)
                (check (andmap terminated? saved) => #t)
                (let ((release release-survivors)) (set! release-survivors #f) (release))))
            (outcome)))
        restart: (lambda (name)
          (and (eq? name 'c) failed?
            (begin (set! restarts (+ restarts 1)) recovered))))
      (check-equal? restarts 3) (check-equal? exits 4)
      (check (andmap terminated? saved) => #t)
      (check-equal? (service.value (joint.current owner) 'a) 12))
    (test-case "old checkpoint replies cannot reach the replacement incarnation"
      (def failure (list 'old-incarnation)) (def old-reply #f) (def count 0) (def restarts 0)
      (coordination.call-with-coordinators
        [(cons 'c (lambda (exchange) (exchange 'old) (raise failure)))]
        (lambda (next)
          (next (lambda (_ payload reply)
            (check-equal? payload 'old) (set! old-reply reply) (reply 'fail)))
          (next (lambda (_ payload reply)
            (check-equal? payload 'new)
            (check-exception (old-reply 'escaped) true) (reply 'finish))))
        on-exit: (lambda (_ outcome)
          (set! count (+ count 1))
          (if (= count 1) (check-exception (outcome) (lambda (caught) (eq? caught failure))) (outcome)))
        restart: (lambda (_)
          (set! restarts (+ restarts 1))
          (lambda (exchange) (exchange 'new))))
      (check-equal? count 2) (check-equal? restarts 1))
    (test-case "unhandled original failure prevents a configured restart"
      (def failure (list 'unhandled-before-restart)) (def restarts 0)
      (check-exception (coordination.call-with-coordinators
        [(cons 'c (lambda (_) (raise failure)))]
        (lambda (next) (next (lambda _ (error "unexpected checkpoint"))))
        restart: (lambda (_) (set! restarts (+ restarts 1)) (lambda (_) 'unexpected)))
        (lambda (caught) (eq? caught failure)))
      (check-equal? restarts 0))
    (test-case "final joins observe exits without launching unsupervised replacements"
      (def exits 0) (def restarts 0)
      (check-equal? (call-with-values (lambda () (coordination.call-with-coordinators
        [(cons 'c (lambda (_) (values 'done 2)))]
        (lambda (_) (values 'supervised 'return))
        on-exit: (lambda (_ outcome)
          (set! exits (+ exits 1)) (check-equal? (call-with-values outcome list) '(done 2)))
        restart: (lambda (_) (set! restarts (+ restarts 1)) (lambda (_) 'unexpected)))) list)
        '(supervised return))
      (check-equal? exits 1) (check-equal? restarts 0))))
