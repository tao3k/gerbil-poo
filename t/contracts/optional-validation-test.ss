;;; Optional sentinels, dependent Type payloads and exact publication binding.
(export optional-validation-test)
(import :std/test :clan/poo/object :clan/poo/mop :clan/poo/number :clan/poo/object-contract
        (only-in :clan/poo/type Maybe Maybe. OrFalse OrFalse. TypeValuePair List Tuple String)
        (prefix-in :clan/poo/examples/optional-publication pipeline.)
        (prefix-in :clan/poo/examples/object-contracts service.)
        (prefix-in :clan/poo/examples/contract-publication publication.)
        (prefix-in :clan/poo/declarative-metadata metadata.))

;; Consumer authorization remains distinct from normalized subject binding.
(def Call
  (metadata.contract (metadata.predicate "object" object?)
    (metadata.predicate "evidence" object?)
    (lambda (_key _request _result) #t) metadata.truth))

;; Only data is decoded; callable plugins are supplied through existing Types.
(def request "{\"host\":\"api\",\"port\":443,\"capacity\":10,\"used\":2,\"secure\":true}")

;; Declared interfaces travel with each value; every checked cdr is a wrapper.
(def (make-plugins)
  (list (vector "api" (cons pipeline.Transform (lambda (n) (+ n 1))))
        (vector "api" (cons pipeline.Transform (lambda (n) (* n 2))))))

;; Positive and negative controls preserve each optional and dependent boundary.
(def optional-validation-test
  (test-suite "Maybe OrFalse and TypeValuePair recursion"
    (test-case "absent values bypass child descriptor lookup and validation"
      (.def (missing-maybe @ Maybe.) type: (error "absent Maybe demanded child"))
      (.def (missing-false @ OrFalse.) type: (error "absent OrFalse demanded child"))
      (check (eq? (validate missing-maybe (void)) (void)) => #t)
      (check-equal? (validate missing-false #f) #f)
      (check-equal? (diagnose missing-maybe (void)) '())
      (check-equal? (diagnose missing-false #f) '()))
    (test-case "Maybe false is a present Boolean and both sentinels remain distinct"
      (check-equal? (validate (Maybe Bool) #f) #f)
      (check (void? (validate (Maybe Bool) (void))) => #t)
      (check-exception (validate (Maybe (Fun Integer <- Integer)) #f) TypeError?)
      (check-exception (validate (OrFalse (Fun Integer <- Integer)) (void)) TypeError?)
      (check-equal? (validate (Maybe (OrFalse pipeline.Transform)) #f) #f)
      (check (void? (validate (OrFalse (Maybe pipeline.Transform)) (void))) => #t))
    (test-case "present optional Functions are wrapped without invocation"
      (def calls 0)
      (def raw (lambda (n) (set! calls (+ calls 1)) n))
      (def checked (validate (Maybe (OrFalse pipeline.Transform)) raw))
      (check (eq? checked raw) => #f)
      (check-equal? calls 0)
      (check-exception (checked #f) TypeError?)
      (check-equal? calls 0)
      (check-equal? (checked 4) 4)
      (check-equal? calls 1))
    (test-case "present branch cannot erase an invalid Function into a sentinel"
      (def to-void (.cc Type. .element?: procedure? .validate: (lambda (_) (void))))
      (def to-false (.cc Type. .element?: procedure? .validate: (lambda (_) #f)))
      (check-exception (validate (Maybe to-void) values) TypeError?)
      (check-exception (validate (OrFalse to-false) values) TypeError?)
      (def broad (.cc Any .validate: (lambda (_) #f)))
      (check-equal? (validate (OrFalse broad) 1) #f))
    (test-case "TypeValuePair validates payload instead of pair and retains its Type"
      (def source (cons Integer 7))
      (check (eq? source (validate TypeValuePair source)) => #t)
      (def raw (lambda (n) n))
      (def typed (cons pipeline.Transform raw))
      (def checked (validate TypeValuePair typed))
      (check (eq? (car checked) pipeline.Transform) => #t)
      (check (eq? (cdr checked) raw) => #f)
      (check (eq? (cdr typed) raw) => #t)
      (check-exception ((cdr checked) #f) TypeError?)
      (check-equal? ((cdr checked) 6) 6))
    (test-case "invalid carried Types refuse before payload calls and keep paths"
      (def calls 0)
      (def source (cons #f (lambda (_) (set! calls (+ calls 1)) #t)))
      (check-exception (validate TypeValuePair source) TypeError?)
      (check-equal? (.get (car (diagnose TypeValuePair source '(request))) path) '(request car))
      (check-equal? calls 0)
      (check-exception (validate TypeValuePair #f) TypeError?)
      (check-exception (validate TypeValuePair (cons Integer #f)) TypeError?)
      (check-equal? (.get (car (diagnose TypeValuePair (cons Integer #f) '(request))) path) '(request cdr)))
    (test-case "carried refined schemas see normalized callbacks through optional Types"
      (def raw (lambda (n) n))
      (def schema (refine (.cc ObjectContract. responsibilities: (.o run: pipeline.Transform))
        (lambda (candidate location)
          (if (eq? (.get candidate run) raw) [(.o kind: 'raw path: location)] '()))))
      (def checked (validate (Maybe TypeValuePair) (cons schema (.o run: raw))))
      (check (eq? (car checked) schema) => #t)
      (check (eq? (.get (cdr checked) run) raw) => #f)
      (check-equal? ((.get (cdr checked) run) 5) 5))
    (test-case "complete outer shape gates all optional validators"
      (def calls 0)
      (def counted (.cc Type. .element?: procedure?
        .validate: (lambda (value) (set! calls (+ calls 1)) value)))
      (def descriptor (List (Tuple (Maybe counted) TypeValuePair)))
      (check-exception (validate descriptor (list (vector values (cons Integer 1))
                                                (vector values (cons Integer #f)))) TypeError?)
      (check-equal? calls 0))
    (test-case "TypeValuePair preserves original child exceptions and refuses bad normalized values"
      (def cause (list 'original-child))
      (def broken (.cc Type. .element?: procedure? .validate: (lambda (_) (raise cause))))
      (check-exception (validate TypeValuePair (cons broken values)) (lambda (caught) (eq? caught cause)))
      (def invalid-result (.cc Type. .element?: procedure? .validate: (lambda (_) #f)))
      (check-exception (validate TypeValuePair (cons invalid-result values)) TypeError?))
    (test-case "nested optional containers preserve higher-order and multiple-value checks"
      (def descriptor (Maybe TypeValuePair))
      (def carried (Fun (Fun Bool <- Integer) Integer <- Integer))
      (def checked (validate descriptor
        (cons carried (lambda (limit) (values (lambda (n) (<= n limit)) limit)))))
      (defvalues (predicate limit) ((cdr checked) 10))
      (check-equal? limit 10)
      (check-equal? (predicate 2) #t)
      (check-exception (predicate "bad") TypeError?))
    (test-case "JSON FUN pipeline publishes actual normalized typed plugin payloads"
      (def context-value (.o commits: 0)) (def source-plugins (make-plugins))
      (defvalues (result state refusal)
        ((pipeline.pipeline-action Call context-value source-plugins (lambda (n) (+ n 1))) request))
      (check-equal? refusal #f)
      (check-equal? (.get result total) 7)
      (check-equal? (.get state commits) 1)
      (check (eq? (.get result subject plugins) source-plugins) => #f))
    (test-case "absent plugin list and both fallback sentinels skip invocation"
      (def context-value (.o commits: 0))
      (for-each (lambda (fallback-value)
                  (defvalues (result state refusal)
                    ((pipeline.pipeline-action Call context-value (void) fallback-value) request))
                  (check-equal? refusal #f)
                  (check-equal? (.get result total) 2)
                  (check-equal? (.get state commits) 1)) (list #f (void))))
    (test-case "root refinement refuses unrelated carried interfaces before consumption"
      (def context-value (.o commits: 0))
      (check-exception ((pipeline.pipeline-action Call context-value
        (list (vector "api" (cons Any values))) #f) request) TypeError?))
    (test-case "raw and stale evidence fail and current typed pipeline retry succeeds"
      (def context-value (.o commits: 1)) (def stale (.o commits: 0))
      (def source-plugins (make-plugins))
      (def source (.o config: (service.decode-service request) plugins: source-plugins fallback: #f))
      ;; Each retry binds the newly normalized root from the current template.
      (def (action raw-subject evidence-context)
        (publication.publication-action pipeline.PipelineSchema Call context-value
          (lambda (checked)
            (values (.o subject: (if raw-subject raw-subject checked)
                        descriptor: pipeline.PipelineSchema context: evidence-context)
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
    (test-case "callback refusal retains state and repaired typed payloads retry"
      (def context-value (.o commits: 2))
      (def bad (list (vector "api" (cons pipeline.Transform (lambda (_) #f)))))
      (defvalues (result state refusal) ((pipeline.pipeline-action Call context-value bad #f) request))
      (check-equal? result #f)
      (check (eq? state context-value) => #t)
      (check-equal? (metadata.failure-phase refusal) 'source)
      (defvalues (_ next failure) ((pipeline.pipeline-action Call context-value (make-plugins) #f) request))
      (check-equal? failure #f)
      (check-equal? (.get next commits) 3))))
