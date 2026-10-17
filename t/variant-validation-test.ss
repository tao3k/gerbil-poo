;;; Recursive Pair/Map/Sum/Union validation and bound routing publication.
(export variant-validation-test)
(import :std/test ../object ../mop ../number ../object-contract
        (only-in ../type Pair Map Sum Union String)
        (prefix-in ../examples/variant-publication routing.)
        (prefix-in ../examples/object-contracts service.)
        (prefix-in ../examples/contract-publication publication.)
        (prefix-in ../declarative-metadata metadata.))

;; Application-owned admission remains independent of subject/context binding.
(def Call
  (metadata.contract (metadata.predicate "object" object?)
    (metadata.predicate "evidence" object?)
    (lambda (_key _request _result) #t) metadata.truth))

;; Data-only configuration enters through the existing JSON/FUN path.
(def request "{\"host\":\"api\",\"port\":443,\"capacity\":10,\"used\":2,\"secure\":true}")

;; A mixed tagged route table contains both named-schema and bare Function Union
;; branches; the Pair tail supplies an independently checked approval Function.
(def (make-routes)
  (cons (hash ("primary" (.call routing.Operation make 'active
                          (.o tenant: "api" run: (lambda (n) (+ n 1)))))
              ("secondary" (.call routing.Operation make 'active (lambda (n) (* n 2)))))
        (lambda (total) (< total 10))))

;; Check each carrier, selection and publication boundary with negative controls.
(def variant-validation-test
  (test-suite "recursive Pair Map Sum and committed Union"
    (test-case "Pair wraps both positions without invoking or mutating source"
      (def calls 0)
      (def raw (lambda (n) (set! calls (+ calls 1)) n))
      (def source (cons raw raw))
      (def checked (validate (Pair (Fun Integer <- Integer) (Fun Integer <- Integer)) source))
      (check (eq? source checked) => #f)
      (check (eq? (car source) raw) => #t)
      (check-equal? calls 0)
      (check-exception ((car checked) #f) TypeError?)
      (check-equal? ((cdr checked) 3) 3)
      (check-equal? calls 1)
      (check-exception (validate (Pair Integer Integer) '()) TypeError?))
    (test-case "Map wraps values and retains the source key comparison policy"
      (def first (string-copy "same")) (def second (string-copy "same"))
      (def source (make-hash-table-eq))
      (hash-put! source first values) (hash-put! source second values)
      (def checked (validate (Map (Fun Integer <- Integer) <- String) source))
      (check-equal? (hash-length checked) 2)
      (check (eq? source checked) => #f)
      (check-exception ((hash-ref checked first) #f) TypeError?)
      (check-equal? ((hash-ref checked second) 4) 4)
      (check (eq? (hash-ref source first) values) => #t))
    (test-case "Map Function keys are normalized too without changing the source"
      (def raw (lambda (n) n)) (def source (make-hash-table-eq))
      (hash-put! source raw #t)
      (def checked (validate (Map Bool <- (Fun Integer <- Integer)) source))
      (def key (car (hash-keys checked)))
      (check (eq? key raw) => #f)
      (check-equal? (key 3) 3)
      (check-exception (key #f) TypeError?)
      (check-equal? (hash-ref source raw) #t))
    (test-case "Map normalized-key collisions reject instead of overwriting"
      (def key-type (.cc Type. .element?: string? .validate: string-downcase))
      (def source (hash ("A" 1) ("a" 2)))
      (check-exception (validate (Map Integer <- key-type) source) TypeError?)
      (check-equal? (hash-length source) 2)
      (check-equal? (hash-ref source "A") 1)
      (check-equal? (hash-ref source "a") 2))
    (test-case "Sum installs the returned wrapper and preserves ancestry and extras"
      (def descriptor (Sum active: (Fun Integer <- Integer) disabled: Integer))
      (def raw (lambda (n) n))
      (def source (.o tag: 'active value: raw extra: (error "extra slot demanded")))
      (def checked (validate descriptor source))
      (check-equal? (.get checked tag) 'active)
      (check (and (memq source (compute-precedence-list! checked)) #t) => #t)
      (check (eq? (.get source value) raw) => #t)
      (check-exception ((.get checked value) #f) TypeError?)
      (check-equal? ((.get checked value) 5) 5)
      (def dependent (.o value: raw tag: (if (eq? value raw) 'active 'disabled)))
      (def normalized (validate descriptor dependent))
      (check-equal? (.get normalized tag) 'active)
      (check-equal? (.get dependent tag) 'active)
      (check (eq? (.get normalized value) raw) => #f))
    (test-case "unknown Sum tags gate payload demand and all validators"
      (def calls 0)
      (def counted (.cc Type. .element?: procedure?
        .validate: (lambda (value) (set! calls (+ calls 1)) value)))
      (def descriptor (Sum active: counted))
      (check-exception (validate descriptor (.o tag: 'unknown value: (error "payload demanded"))) TypeError?)
      (check-exception (validate descriptor (.o tag: 3 value: (error "payload demanded"))) TypeError?)
      (check-exception (validate descriptor (.o tag: 'active)) TypeError?)
      (check-equal? (element? descriptor (.o tag: 3 value: (error "payload demanded"))) #f)
      (check-equal? calls 0))
    (test-case "Union uses declared structural order for overlapping Functions"
      (def descriptor (Union (Fun Bool <- Bool) (Fun Integer <- Integer)))
      (def calls 0)
      (def checked (validate descriptor (lambda (n) (set! calls (+ calls 1)) n)))
      (check-equal? calls 0)
      (check-equal? (checked #t) #t)
      (check-exception (checked 3) TypeError?)
      (check-equal? calls 1)
      (check-exception (validate (Union) values) TypeError?))
    (test-case "Union committed branch errors do not fall through to Any"
      (def cause (list 'selected-error)) (def calls 0)
      (def selected (.cc Type. .element?: procedure? .validate: (lambda (_) (raise cause))))
      (def fallback (.cc Any .validate: (lambda (value) (set! calls (+ calls 1)) value)))
      (check-equal? (element? (Union selected fallback) values) #t)
      (check-exception (validate (Union selected fallback) values) (lambda (caught) (eq? caught cause)))
      (check-equal? calls 0))
    (test-case "Union checks its selected normalized branch rather than any later Type"
      (def broken (.cc Type. .element?: integer? .validate: (lambda (_) "wrong branch")))
      (check-exception (validate (Union broken String) 1) TypeError?))
    (test-case "Union defers nested refinement but never bypasses a rejected selected obligation"
      (def raw (lambda (n) n))
      (def schema (refine (.cc ObjectContract. responsibilities: (.o run: (Fun Integer <- Integer)))
        (lambda (value location)
          (if (eq? (.get value run) raw) [(.o kind: 'raw path: location)] '()))))
      (def checked (validate (Union schema Any) (.o run: raw)))
      (check (eq? (.get checked run) raw) => #f)
      (def denied (refine schema (lambda (_ location) [(.o kind: 'denied path: location)])))
      (check-exception (validate (Union denied Any) (.o run: raw)) TypeError?))
    (test-case "complete structural Map check gates earlier successful entries"
      (def calls 0)
      (def counted (.cc Type. .element?: integer?
        .validate: (lambda (value) (set! calls (+ calls 1)) value)))
      (check-exception (validate (Map counted <- String) (hash ("good" 1) ("bad" #f))) TypeError?)
      (check-equal? calls 0)
      (check-exception (validate (Map Integer <- String) '()) TypeError?))
    (test-case "scalar and empty carrier normalization preserves identity"
      (def pair-value (cons 1 #t)) (def map-value (hash ("one" 1)))
      (def sum-type (Sum count: Integer)) (def sum-value (.call sum-type make 'count 1))
      (check (eq? pair-value (validate (Pair Integer Bool) pair-value)) => #t)
      (check (eq? map-value (validate (Map Integer <- String) map-value)) => #t)
      (check (eq? sum-value (validate sum-type sum-value)) => #t)
      (check-equal? (validate (Union Integer String) 2) 2)
      (def empty (make-hash-table-eq))
      (check (eq? empty (validate (Map Integer <- String) empty)) => #t))
    (test-case "diagnostics compose Pair Map and Sum paths without raw keys"
      (def descriptor (Pair (Map (Sum active: (Fun Integer <- Integer)) <- String) Bool))
      (def source (cons (hash ("private-key" (.o tag: 'active value: #f))) #t))
      (check-equal? (.get (car (diagnose descriptor source '(request))) path)
                    '(request car 0 value value)))
    (test-case "JSON FUN routing publishes normalized selected branches"
      (def context-value (.o commits: 0)) (def source-routes (make-routes))
      (defvalues (result state refusal) ((routing.routing-action Call context-value source-routes) request))
      (check-equal? refusal #f)
      (check-equal? (.get result totals) '(3 4))
      (check-equal? (.get result approved) #t)
      (check-equal? (.get state commits) 1)
      (check (eq? (.get result subject routes) source-routes) => #f))
    (test-case "raw and stale evidence refuse then current retry publishes"
      (def context-value (.o commits: 1)) (def stale (.o commits: 0))
      (def source (.o config: (service.decode-service request) routes: (make-routes)))
      ;; Retry always binds the actual newly normalized subject and current context.
      (def (action raw-subject evidence-context)
        (publication.publication-action routing.RoutingSchema Call context-value
          (lambda (checked)
            (values (.o subject: (if raw-subject raw-subject checked)
                        descriptor: routing.RoutingSchema context: evidence-context)
                    (.o commits: 2)))))
      (for-each (lambda (publish)
                  (defvalues (result state refusal) (publish source))
                  (check-equal? result #f)
                  (check (eq? state context-value) => #t)
                  (check-equal? (metadata.failure-phase refusal) 'logic))
                (list (action source context-value) (action #f stale)))
      (defvalues (_ next refusal) ((action #f context-value) source))
      (check-equal? refusal #f)
      (check-equal? (.get next commits) 2))
    (test-case "selected callback failure preserves state and repaired routes retry"
      (def context-value (.o commits: 2)) (def source-routes (make-routes))
      (hash-put! (car source-routes) "secondary" (.call routing.Operation make 'active (lambda (_) "bad")))
      (defvalues (result state refusal) ((routing.routing-action Call context-value source-routes) request))
      (check-equal? result #f)
      (check (eq? state context-value) => #t)
      (check-equal? (metadata.failure-phase refusal) 'source)
      (defvalues (_ next failure) ((routing.routing-action Call context-value (make-routes)) request))
      (check-equal? failure #f)
      (check-equal? (.get next commits) 3))))
