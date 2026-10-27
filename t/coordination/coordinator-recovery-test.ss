(export coordinator-recovery-test)
(import :std/test :std/sync/channel :std/sync/threads :clan/poo/object :clan/poo/mop :clan/poo/brace
        (prefix-in :clan/poo/joint-publication joint.)
        (prefix-in :clan/poo/construction-cache cache.)
        (prefix-in :clan/poo/examples/joint-topology service.)
        (prefix-in :clan/poo/examples/joint-receipts receipts.)
        (prefix-in :clan/poo/examples/joint-coordination coordination.)
        :clan/poo/examples/joint-coordination-rounds :clan/poo/t/joint-coordination-cases)
;; Fixed rendezvous bounds detect stalled cleanup without timing-based release.
(def (get channel)
  (def value (channel-get channel 5 'timeout))
  (when (eq? value 'timeout) (error "coordinator recovery rendezvous timed out")) value)
;; Retain actual threads before cleanup; an empty post-cleanup group is no proof.
(def (terminated? thread)
  (def state (thread-state thread))
  (or (thread-state-normally-terminated? state) (thread-state-abnormally-terminated? state)))
;; Start a nested installation that cannot proceed until explicitly released.
;; Neither retirement path releases it: local standard-group cleanup must join it.
;; A failure preserves its original object; normal return preserves multiple values.
(def (retiring name owner receipt ready control failure)
  (def blocked (make-channel)) (def started (make-channel))
  (def worker (make-thread (lambda ()
    (channel-put started 'ready) (get blocked) (joint.install! owner receipt))))
  (thread-start! worker) (get started)
  (channel-put ready (list name (current-thread) worker))
  (get control)
  (if failure (raise failure) (values 'retired 2)))
;; Survivors continue through shared-guard refusal, fresh approval and six SCC
;; phases while local failure and normal exit remove only their own child workers.
(def coordinator-recovery-test
  (test-suite "local coordinator exits preserve continuing joint publication"
    (test-case "failure and normal exit leave two coordinators restaging and competing"
      (def owner (service.start)) (def ready (make-channel))
      (def failed-control (make-channel)) (def normal-control (make-channel))
      (def failure (list 'local-coordinator-failed))
      (def receipt (car (receipts.approve-revisions owner
        [[(cons 'a (.cc service.Change. phase: 'merge))]]
        (.cc (joint.approval (joint.current owner) 'shared) limit: 24 budget: 36) (.cc cache.Builder.))))
      (def retiring-groups []) (def exits []) (def resume #f) (def captured #f) (def round 0)
      (coordination.call-with-coordinators
        [(cons 'a (lambda (exchange) (coordinate-revisions owner exchange)))
         (cons 'b (lambda (exchange) (coordinate-revisions owner exchange)))
         (cons 'failed (lambda (_) (retiring 'failed owner receipt ready failed-control failure)))
         (cons 'returned (lambda (_) (retiring 'returned owner receipt ready normal-control #f)))]
        (lambda (next)
          (set! retiring-groups [(get ready) (get ready)])
          (check-revisions owner next before-release: (lambda (_ release)
            (set! round (+ round 1))
            (if (memv round '(2 4))
              (begin
                (set! captured (joint.current owner)) (set! resume release)
                (channel-put (if (= round 2) failed-control normal-control) 'retire))
              (release)))))
        on-exit: (lambda (name outcome)
          (set! exits (cons name exits))
          (case name
            ((failed returned)
              (check (eq? captured (joint.current owner)) => #t)
              (if (eq? name 'failed)
                (check-exception (outcome) (lambda (caught) (eq? caught failure)))
                (check-equal? (call-with-values outcome list) '(retired 2)))
              ;; Local descendants are terminated and the parent is joined before
              ;; the exit callback can release any surviving installation.
              (check (andmap terminated? (cddr (assq name retiring-groups))) => #t)
              (let ((release resume)) (set! resume #f) (release)))
            (else (outcome)))))
      (for-each (lambda (name)
        (check-equal? (length (filter (lambda (seen) (eq? name seen)) exits)) 1)) '(a b failed returned))
      (check (andmap (lambda (entry) (andmap terminated? (cdr entry))) retiring-groups) => #t)
      (check-equal? (service.value (joint.current owner) 'a) 12))
    (test-case "default exit handler preserves original error and cleans all siblings"
      (def owner (service.start)) (def original (joint.current owner))
      (def ready (make-channel)) (def control (make-channel))
      (def failure (list 'unhandled-coordinator-failed)) (def threads [])
      (check-exception (coordination.call-with-coordinators
        [(cons 'failed (lambda (_)
          (channel-put ready (current-thread)) (get control) (raise failure)))
         (cons 'waiting (lambda (_)
          (channel-put ready (current-thread)) (get (make-channel))))]
        (lambda (next)
          (set! threads [(get ready) (get ready)])
          (channel-put control 'fail)
          (next (lambda _ (error "unexpected checkpoint")))))
        (lambda (caught) (eq? caught failure)))
      (check (andmap terminated? threads) => #t)
      (check (eq? original (joint.current owner)) => #t))))
