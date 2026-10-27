(export joint-coordination-test)
(import :std/test :std/sync/threads :clan/poo/object :clan/poo/mop :clan/poo/brace :clan/poo/feedback-graph
        (prefix-in :clan/poo/joint-publication joint.) (prefix-in :clan/poo/construction-cache cache.)
        (prefix-in :clan/poo/examples/joint-topology service.) (prefix-in :clan/poo/examples/joint-receipts receipts.)
        (prefix-in :clan/poo/examples/joint-workers workers.) (prefix-in :clan/poo/examples/joint-coordination coordination.)
        :clan/poo/examples/joint-coordination-rounds :clan/poo/t/joint-coordination-cases)
;; Independent feedback never rebuilds while coordinators create competing heads.
(def builder (.cc cache.Builder. allow: (lambda (key) (not (eq? key 'stable)))))
;; Pre-cook immutable proposed metadata before sharing it across coordinator threads.
(def (policy owner ceiling budget)
  (def value (.cc (joint.approval (joint.current owner) 'shared) limit: ceiling budget: budget))
  (instantiate-object! value) value)
;; Native source construction and publication genuinely occur on two coordinators.
(def joint-coordination-test
  (test-suite "independent coordinators restage and publish through six SCC rounds"
    (test-case "shared refusal then parallel fresh approvals race while older workers remain pending"
      (def owner (service.start))
      (coordination.call-with-coordinators
        [(cons 'a (lambda (exchange) (coordinate-revisions owner exchange)))
         (cons 'b (lambda (exchange) (coordinate-revisions owner exchange)))]
        (lambda (next)
          (check-revisions owner next)))
      (check-equal? (service.value (joint.current owner) 'a) 12))
    (test-case "standard thread-group cleanup includes pending workers on supervisor failure"
      (def owner (service.start)) (def before (joint.current owner)) (def group #f)
      (def receipt (car (receipts.approve-revisions owner
        [[(cons 'a (.cc service.Change. phase: 'merge))]] (policy owner 24 36) builder)))
      (def failure (list 'supervisor-refused))
      (check-exception (coordination.call-with-coordinators
        [(cons 'a (lambda (exchange)
          (workers.call-with-installations owner (lambda (start _)
            (start receipt) (exchange (current-thread-group))))))]
        (lambda (next) (next (lambda (_ value __)
          (set! group value) (check (>= (length (thread-group->thread-list* group)) 2) => #t)
          (raise failure))))) (lambda (caught) (eq? caught failure)))
      (check (eq? before (joint.current owner)) => #t)
      (check (andmap (lambda (thread)
        (def state (thread-state thread))
        (or (thread-state-normally-terminated? state) (thread-state-abnormally-terminated? state)))
        (thread-group->thread-list* group)) => #t))))
