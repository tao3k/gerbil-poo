;;; Refinement, receiver-local preparation and exact publication boundaries.
(export contract-publication-test)
(import :std/test ../object ../mop ../number ../object-contract
        (prefix-in ../examples/object-contracts service.)
        (prefix-in ../examples/contract-publication publication.)
        (prefix-in ../declarative-metadata metadata.))

;; Ordinary invocation policy: the application owns both result and authorization.
(def Call
  (metadata.contract (metadata.predicate "object" object?)
    (metadata.predicate "evidence" object?)
    (lambda (_key _request _result) #t) metadata.truth))

;; Stable fixture uses the existing JSON input path and all five service fields.
(def (candidate)
  (service.decode-service
    "{\"host\":\"api\",\"port\":443,\"capacity\":10,\"used\":2,\"secure\":true}"))

;; Every negative control checks the boundary it is meant to protect.
(def contract-publication-test
  (test-suite "strengthened contracts and bound publication"
    (test-case "refinement preserves parent refusals and gates the new phase"
      (def calls 0)
      (def refined (refine service.ServiceContract
        (lambda (_ location) (set! calls (+ calls 1)) [(.o kind: 'extra path: location)])))
      (def bad (.cc (candidate) used: 20))
      (check-equal? (map (lambda (issue) (.get issue kind)) (diagnose refined bad)) '(capacity-exceeded))
      (check-equal? calls 0)
      (check-equal? (.get (car (diagnose refined (candidate) '(request))) path) '(request))
      (check-equal? calls 1)
      (check-exception (refine (.o) void) error?)
      (check-exception (refine service.ServiceContract #f) error?))
    (test-case "later derivation rebinds the inherited obligation receiver"
      (.def (parent @ ObjectContract.)
        responsibilities: (.o used: Integer)
        limit: 10
        obligations: (lambda (value location)
          (if (<= (.get value used) limit) '() [(.o kind: 'limit path: location)])))
      (def prepared (.get parent prepared-obligations))
      (def refined (refine parent (lambda (_ __) '())))
      (check-equal? (diagnose refined (.o used: 5)) '())
      (def child (.cc refined limit: 1))
      (check-equal? (map (lambda (issue) (.get issue kind)) (diagnose child (.o used: 5))) '(limit))
      (check (eq? prepared (.get child prepared-obligations)) => #f))
    (test-case "a current accepted request publishes its exact state"
      (def current (.o revision: 1)) (def next (.o revision: 2))
      (def value (candidate))
      (def action (publication.publication-action publication.CapacityContract Call current
        (lambda (request) (values (.o subject: request descriptor: publication.CapacityContract context: current) next))))
      (defvalues (result state refusal) (action value))
      (check-equal? refusal #f)
      (check (eq? (.get result subject) value) => #t)
      (check (eq? state next) => #t))
    (test-case "structural refusal suppresses execution; stale context retains old state"
      (def current (.o revision: 2)) (def stale (.o revision: 1)) (def calls 0)
      (def action (publication.publication-action publication.CapacityContract Call current
        (lambda (request) (set! calls (+ calls 1))
          (values (.o subject: request descriptor: publication.CapacityContract context: stale) (.o revision: 3)))))
      (check-exception (action (.cc (candidate) capacity: 101)) TypeError?)
      (check-equal? calls 0)
      (defvalues (result state refusal) (action (candidate)))
      (check-equal? result #f) (check (eq? state current) => #t)
      (check-equal? (metadata.failure-phase refusal) 'logic)
      (check-equal? calls 1))
    (test-case "rebinding to the current immutable context enables retry"
      (def current (.o revision: 2)) (def next (.o revision: 3))
      (def action (publication.publication-action publication.CapacityContract Call current
        (lambda (request) (values (.o subject: request descriptor: publication.CapacityContract context: current) next))))
      (defvalues (_ state refusal) (action (candidate)))
      (check-equal? refusal #f) (check (eq? state next) => #t))))
