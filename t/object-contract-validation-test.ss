;;; Nested Function validation, strengthening and exact evidence binding.
(export object-contract-validation-test)
(import :std/test ../object ../mop ../number ../object-contract
        (prefix-in ../examples/function-publication workflow.)
        (prefix-in ../examples/object-contracts service.)
        (prefix-in ../examples/contract-publication publication.)
        (prefix-in ../declarative-metadata metadata.))

;; Application-owned policy; bind-evidence supplies the precise subject/context.
(def Call
  (metadata.contract (metadata.predicate "object" object?)
    (metadata.predicate "evidence" object?)
    (lambda (_key _request _result) #t) metadata.truth))

;; Reusable request contains only JSON data; executable fields enter separately.
(def request
  "{\"host\":\"api\",\"port\":443,\"capacity\":10,\"used\":2,\"secure\":true}")

;; Public contract coverage includes both successful higher-order calls and every
;; refusal boundary: raw recognition cannot promise future procedure behavior.
(def object-contract-validation-test
  (test-suite "nested checked functions and publication"
    (test-case "recursive wrapping is persistent and body calls are deferred"
      (def calls 0)
      (def raw (lambda (x) (set! calls (+ calls 1)) x))
      (def leaf (.cc ObjectContract. responsibilities: (.o run: (Fun Bool <- Bool))))
      (def root (.cc ObjectContract. responsibilities: (.o child: leaf)))
      (def source (.o child: (.o run: raw)))
      (check-equal? (diagnose root source) '())
      (def checked (validate root source))
      (check-equal? calls 0)
      (check (eq? source checked) => #f)
      (check (eq? (.get source child run) raw) => #t)
      (check (eq? (.get checked child run) raw) => #f)
      (check-exception ((.get checked child run) 1) TypeError?)
      (check-equal? calls 0)
      (check-equal? ((.get checked child run) #t) #t)
      (check-equal? calls 1))
    (test-case "multiple values and input/output arity keep upstream semantics"
      (def calls 0)
      (def descriptor (.cc ObjectContract. responsibilities: (.o run: (Fun Integer Bool <- Integer))))
      (def checked (validate descriptor (.o run: (lambda (x) (set! calls (+ calls 1)) (values (+ x 1) #t)))))
      (check-exception ((.get checked run)) TypeError?)
      (check-exception ((.get checked run) 1 2) TypeError?)
      (check-equal? calls 0)
      (defvalues (n ready) ((.get checked run) 4))
      (check-equal? (list n ready calls) '(5 #t 1))
      (def wrong-count (validate descriptor (.o run: (lambda (_) 1))))
      (check-exception ((.get wrong-count run) 4) TypeError?)
      (def wrong-type (validate descriptor (.o run: (lambda (_) (values 1 "bad")))))
      (check-exception ((.get wrong-type run) 4) TypeError?))
    (test-case "returned and incoming callbacks acquire their own checks"
      (def calls 0)
      (def descriptor (.cc ObjectContract. responsibilities:
        (.o factory: (Fun (Fun Bool <- Integer) <- Integer)
            apply: (Fun Bool <- (Fun Bool <- Integer)))))
      (def checked (validate descriptor
        (.o factory: (lambda (limit) (lambda (n) (set! calls (+ calls 1)) (<= n limit)))
            apply: (lambda (predicate) (predicate "bad")))))
      (def predicate ((.get checked factory) 10))
      (check-exception (predicate "bad") TypeError?)
      (check-equal? calls 0)
      (check-equal? (predicate 2) #t)
      (check-exception ((.get checked apply) (lambda (_) (set! calls (+ calls 1)) #t)) TypeError?)
      (check-equal? calls 1))
    (test-case "normalization keeps prototype ancestry and unchanged identity"
      (def source (.o run: (lambda (x) x)))
      (def nominal (.cc ObjectContract. required-prototype: source
        responsibilities: (.o run: (Fun Bool <- Bool))))
      (def checked (validate nominal source))
      (check-equal? (element? nominal checked) #t)
      (check (and (memq source (compute-precedence-list! checked)) #t) => #t)
      (def scalar (.o count: 1))
      (check (eq? scalar (validate (.cc ObjectContract. responsibilities: (.o count: Integer)) scalar)) => #t))
    (test-case "shape failures gate validators and retain nested paths"
      (def calls 0)
      (def counting (.cc Type. .element?: procedure?
        .validate: (lambda (value) (set! calls (+ calls 1)) value)))
      (def leaf (.cc ObjectContract. responsibilities: (.o run: counting)))
      (def root (.cc ObjectContract. responsibilities: (.o child: leaf)))
      (def source (.o child: (.o run: values typo: (error "unknown value forced"))))
      (check-equal? (.get (car (diagnose root source)) path) '(child typo))
      (check-exception (validate root source) TypeError?)
      (check-equal? calls 0))
    (test-case "nested refinement sees wrapped fields and derived validators rebind"
      (def raw (lambda (x) x))
      (def parent (.cc ObjectContract. responsibilities: (.o run: (Fun Bool <- Bool))))
      (def prepared (.get parent prepared-validation))
      (def refined (refine parent
        (lambda (value location)
          (if (eq? (.get value run) raw) [(.o kind: 'raw path: location)] '()))))
      (def root (.cc ObjectContract. responsibilities: (.o child: refined)))
      (check-exception (validate root (.o child: (.o run: #f))) TypeError?)
      (def checked (validate root (.o child: (.o run: raw))))
      (check-equal? ((.get checked child run) #t) #t)
      (def child (.cc parent responsibilities: (.o run: (Fun Integer <- Integer))))
      (check (eq? prepared (.get child prepared-validation)) => #f)
      (check-equal? ((.get (validate child (.o run: raw)) run) 7) 7))
    (test-case "JSON to nested callbacks to bound publication is one FUN chain"
      (def context-value (.o commits: 0))
      (def engine-value (.o tenant: "api" convert: (lambda (n) (values (+ n 1) #t))
                       policy: (lambda (limit) (lambda (n) (<= n limit)))))
      (def action (workflow.workflow-action Call context-value engine-value))
      (defvalues (result state refusal) (action request))
      (check-equal? refusal #f)
      (check-equal? (.get state commits) 1)
      (check-equal? (call-with-values (lambda () ((.get result subject engine convert) 1)) list) '(2 #t))
      (check (eq? (.get result subject engine) engine-value) => #f)
      (check-exception (action "{\"host\":\"other\",\"port\":443,\"capacity\":10,\"used\":2,\"secure\":true}") TypeError?))
    (test-case "normalized subjects reject raw, stale and mismatched evidence"
      (def context-value (.o commits: 0))
      (def stale (.o commits: 0))
      (def engine-value (.o tenant: "api" convert: (lambda (n) (values n #t))
                       policy: (lambda (limit) (lambda (n) (<= n limit)))))
      (def source (.o config: (service.decode-service request) engine: engine-value))
      ;; Rebuild from the current template; existing bindings are not weakened.
      (def (publish subject-value descriptor-value context-result)
        (publication.publication-action workflow.WorkflowContract Call context-value
          (lambda (checked)
            (values (.o subject: (if subject-value subject-value checked)
                        descriptor: descriptor-value context: context-result)
                    (.o commits: 1)))))
      (for-each
        (lambda (action)
          (defvalues (result state refusal) (action source))
          (check-equal? result #f)
          (check (eq? state context-value) => #t)
          (check-equal? (metadata.failure-phase refusal) 'logic))
        (list (publish source workflow.WorkflowContract context-value)
              (publish #f workflow.WorkflowContract stale)
              (publish #f workflow.EngineContract context-value)))
      (defvalues (_ next refusal) ((publish #f workflow.WorkflowContract context-value) source))
      (check-equal? refusal #f)
      (check-equal? (.get next commits) 1))
    (test-case "field and procedure exceptions retain their original cause"
      (def cause (list 'original-cause))
      (def throwing (.cc Type. .element?: procedure? .validate: (lambda (_) (raise cause))))
      (def descriptor (.cc ObjectContract. responsibilities: (.o run: throwing)))
      (def source (.o run: values))
      (check-exception (validate descriptor source) (lambda (caught) (eq? caught cause)))
      (check (eq? (.get source run) values) => #t)
      (def function-descriptor (.cc descriptor responsibilities: (.o run: (Fun Bool <- Bool))))
      (def checked (validate function-descriptor (.o run: (lambda (_) (raise cause)))))
      (check-exception ((.get checked run) #t) (lambda (caught) (eq? caught cause))))
    (test-case "callback refusal preserves state and retry uses fresh validation"
      (def context-value (.o commits: 2))
      (def engine-value (.o tenant: "api" convert: (lambda (_) (values 3 "invalid"))
                       policy: (lambda (limit) (lambda (n) (<= n limit)))))
      (defvalues (result state refusal) ((workflow.workflow-action Call context-value engine-value) request))
      (check-equal? result #f)
      (check (eq? state context-value) => #t)
      (check-equal? (metadata.failure-phase refusal) 'source)
      (def fixed (.cc engine-value convert: (lambda (n) (values n #t))))
      (defvalues (_ next failure) ((workflow.workflow-action Call context-value fixed) request))
      (check-equal? failure #f)
      (check-equal? (.get next commits) 3))))
