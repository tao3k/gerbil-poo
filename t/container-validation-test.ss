;;; Recursive container wrapping, finite schemas and checked publication.
(export container-validation-test)
(import :std/test ../object ../mop ../number ../object-contract
        (only-in ../type List Tuple)
        (prefix-in ../examples/container-publication batch.)
        (prefix-in ../examples/contract-publication publication.)
        (prefix-in ../examples/object-contracts service.)
        (prefix-in ../declarative-metadata metadata.))

;; The application retains input/output and logical authorization policy.
(def Call
  (metadata.contract (metadata.predicate "object" object?)
    (metadata.predicate "evidence" object?)
    (lambda (_key _request _result) #t) metadata.truth))

;; JSON owns configuration data, while executable task fields are supplied locally.
(def request "{\"host\":\"api\",\"port\":443,\"capacity\":10,\"used\":2,\"secure\":true}")

;; Heterogeneous tuple includes multiple values and a list of transform callbacks.
(def (task)
  (.o tenant: "api" handlers: (vector (lambda (n) (values (+ n 1) #t))
                                     (list (lambda (n) (* n 2)) (lambda (n) (+ n 1))))))

;; Validate every failure boundary and keep raw carrier identities observable.
(def container-validation-test
  (test-suite "recursive List Tuple and named schemas"
    (test-case "List wraps callbacks without mutating or invoking them"
      (def calls 0)
      (def raw (lambda (n) (set! calls (+ calls 1)) n))
      (def source (list raw raw))
      (def descriptor (List (Fun Integer <- Integer)))
      (check-equal? (element? descriptor source) #t)
      (def checked (validate descriptor source))
      (check (eq? checked source) => #f)
      (check (eq? (car source) raw) => #t)
      (check-equal? calls 0)
      (check-exception ((car checked) #f) TypeError?)
      (check-equal? calls 0)
      (check-equal? ((cadr checked) 7) 7)
      (check-equal? calls 1))
    (test-case "unchanged and empty containers keep their original identity"
      (def values-list (list 1 2)) (def values-tuple (vector 1 #t))
      (check (eq? values-list (validate (List Integer) values-list)) => #t)
      (check (eq? values-tuple (validate (Tuple Integer Bool) values-tuple)) => #t)
      (check (eq? '() (validate (List Integer) '())) => #t)
      (def empty (vector))
      (check (eq? empty (validate (Tuple) empty)) => #t))
    (test-case "carrier and tuple arity gate every child validator"
      (def calls 0)
      (def counted (.cc Type. .element?: procedure?
        .validate: (lambda (value) (set! calls (+ calls 1)) value)))
      (check-exception (validate (List counted) (cons values 1)) TypeError?)
      (check-exception (validate (Tuple counted counted) (vector values)) TypeError?)
      (check-exception (validate (Tuple counted) (list values)) TypeError?)
      (check-exception (validate (Tuple) (vector values)) TypeError?)
      (check-equal? calls 0))
    (test-case "structural traversal reaches all containers before wrapping"
      (def calls 0)
      (def counted (.cc Type. .element?: procedure?
        .validate: (lambda (value) (set! calls (+ calls 1)) value)))
      (def descriptor (List (Tuple counted Integer)))
      (def source (list (vector values 1) (vector values #f)))
      (check-exception (validate descriptor source) TypeError?)
      (check-equal? calls 0)
      (check-equal? (.get (car (diagnose descriptor source '(request))) path) '(request 1 1)))
    (test-case "finite schema refinement is deferred through List and Tuple"
      (def raw (lambda (n) n))
      (def schema (refine (.cc ObjectContract. responsibilities: (.o run: (Fun Integer <- Integer)))
        (lambda (value location)
          (if (eq? (.get value run) raw) [(.o kind: 'raw path: location)] '()))))
      (def descriptor (Tuple (List schema)))
      (def source (vector (list (.o run: raw))))
      (check-equal? (element? descriptor source) #f)
      (def checked (validate descriptor source))
      (check-equal? (element? descriptor checked) #t)
      (check-equal? ((.get (car (vector-ref checked 0)) run) 9) 9))
    (test-case "deep diagnostic paths include named fields and zero-based indices"
      (def bad-task (.cc (task) handlers: (vector #f (list values))))
      (def source (.o config: (service.decode-service request) tasks: (list bad-task)))
      (check-equal? (.get (car (diagnose batch.BatchSchema source '(request))) path)
                    '(request tasks 0 handlers 0))
      (check-exception (validate batch.BatchSchema source) TypeError?))
    (test-case "child validation is ordered and preserves the first exception"
      (def seen '()) (def cause (list 'child-failure))
      (def counted (.cc Type. .element?: integer?
        .validate: (lambda (value)
          (set! seen (cons value seen))
          (if (= value 2) (raise cause) (+ value 1)))))
      (check-exception (validate (List counted) '(1 2 3)) (lambda (caught) (eq? caught cause)))
      (check-equal? (reverse seen) '(1 2))
      (set! seen '())
      (check-exception (validate (Tuple counted counted counted) '#(1 2 3))
                       (lambda (caught) (eq? caught cause)))
      (check-equal? (reverse seen) '(1 2)))
    (test-case "container fields preserve returned callback checks and multiple values"
      (def descriptor (Tuple (List (Fun (Fun Bool <- Integer) <- Integer))
                             (Fun Integer Bool <- Integer)))
      (def checked (validate descriptor
        (vector (list (lambda (limit) (lambda (n) (<= n limit))))
                (lambda (n) (values n #t)))))
      (def predicate ((car (vector-ref checked 0)) 10))
      (check-exception (predicate "bad") TypeError?)
      (check-equal? (predicate 3) #t)
      (check-equal? (call-with-values (lambda () ((vector-ref checked 1) 4)) list) '(4 #t)))
    (test-case "JSON FUN chain publishes the normalized nested batch"
      (def context-value (.o commits: 0))
      (def tasks-value (list (task) (task)))
      (def action (batch.batch-action Call context-value tasks-value))
      (defvalues (result state refusal) (action request))
      (check-equal? refusal #f)
      (check-equal? (.get result totals) '(7 7))
      (check-equal? (.get state commits) 1)
      (check (eq? (.get result subject tasks) tasks-value) => #f)
      (check (eq? (.get (car tasks-value) handlers)
                  (.get (car (.get result subject tasks)) handlers)) => #f))
    (test-case "raw and stale evidence refuse and current retry succeeds"
      (def context-value (.o commits: 1)) (def stale (.o commits: 0))
      (def source (.o config: (service.decode-service request) tasks: (list (task))))
      ;; Rebuild the invocation from its current template for each retry.
      (def (action subject-value evidence-context)
        (publication.publication-action batch.BatchSchema Call context-value
          (lambda (checked)
            (values (.o subject: (if subject-value subject-value checked)
                        descriptor: batch.BatchSchema context: evidence-context)
                    (.o commits: 2)))))
      (for-each (lambda (publish)
                  (defvalues (result state refusal) (publish source))
                  (check-equal? result #f)
                  (check (eq? state context-value) => #t)
                  (check-equal? (metadata.failure-phase refusal) 'logic))
                (list (action source context-value) (action #f stale)))
      (defvalues (_ next failure) ((action #f context-value) source))
      (check-equal? failure #f)
      (check-equal? (.get next commits) 2))
    (test-case "callback result failure refuses publication then repaired retry works"
      (def context-value (.o commits: 2))
      (def bad (.cc (task) handlers: (vector (lambda (_) (values "bad" #t)) (list values))))
      (defvalues (result state refusal) ((batch.batch-action Call context-value (list bad)) request))
      (check-equal? result #f)
      (check (eq? state context-value) => #t)
      (check-equal? (metadata.failure-phase refusal) 'source)
      (defvalues (_ next failure) ((batch.batch-action Call context-value (list (task))) request))
      (check-equal? failure #f)
      (check-equal? (.get next commits) 3))))
