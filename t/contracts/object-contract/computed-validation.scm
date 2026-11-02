;;; Rebound computed dependencies, inheritance, hooks and exact evidence controls.



;; Policy admission remains distinct from exact normalized-subject association.
(def Call (metadata.contract (metadata.predicate "object" object?)
  (metadata.predicate "evidence" object?) (lambda (_key _request _result) #t) metadata.truth))

;; Parsing introduces no executable values into the service fixture.
(def request "{\"host\":\"api\",\"port\":443,\"capacity\":100,\"used\":2,\"secure\":true}")

;; Focus on observable dependency rebinding rather than wrapper implementation.
(def computed-validation-test
  (test-suite "computed recursive validation rebinding"
    (test-case "captured dependency is the final normalized Function"
      (def source (instance pipeline.BaseRecord))
      (def raw (.get source backend))
      (.get source captured) (.get source run)
      (def checked (validate pipeline.BaseRecord source))
      (check (eq? (.get checked captured) (.get checked backend)) => #t)
      (check (eq? (.get checked captured) raw) => #f)
      (check (eq? (.get source captured) raw) => #t)
      (check (and (memq source (compute-precedence-list! checked)) #t) => #t))
    (test-case "computed captures cannot call a raw backend before its guard"
      (def calls 0)
      (def descriptor (Record backend: [pipeline.Transform]
        run: [(Fun Integer <-) compute: (lambda (self _next)
               (def dependency (.get self backend)) (lambda () (dependency #f)))]))
      (def checked (make-instance descriptor backend: (lambda (_) (set! calls (+ calls 1)) 1)))
      (check-equal? calls 0)
      (check-exception ((.get checked run)) TypeError?)
      (check-equal? calls 0))
    (test-case "checked dependencies are shared despite reverse field order"
      (def visits 0)
      (def counted (.cc Type. .element?: procedure?
        .validate: (lambda (value) (set! visits (+ visits 1)) (validate pipeline.Transform value))))
      (def descriptor (Record first: [Any compute: (lambda (self _next) (.get self last))]
        second: [Any compute: (lambda (self _next) (.get self last))]
        last: [counted default: values]))
      (def checked (make-instance descriptor))
      (check-equal? visits 1)
      (check (eq? (.get checked first) (.get checked second)) => #t)
      (check (eq? (.get checked first) (.get checked last)) => #t)
      (.get checked first) (.get checked second)
      (check-equal? visits 1))
    (test-case "inherited super computation uses derived receiver after hook"
      (.get pipeline.BaseRecord proto) (.get pipeline.ServiceRecord proto)
      (def checked (make-instance pipeline.InitializedRecord))
      (check (eq? (.get checked captured) (.get checked backend)) => #t)
      (check-equal? ((.get checked run) 2) 10)
      (check-equal? (((.get checked maker) 1) 2) 8)
      (check-exception (((.get checked maker) 1) #f) TypeError?))
    (test-case "computed lists carry checked dependencies through a second admission"
      (def first (make-instance pipeline.InitializedRecord))
      (def checked (validate pipeline.InitializedRecord first))
      (check (eq? (.get checked captured) (.get checked backend)) => #t)
      (check-equal? ((car (.get checked callbacks)) 2) 4)
      (check-equal? ((cadr (.get checked callbacks)) 2) 10)
      (check-exception ((car (.get checked callbacks)) #f) TypeError?))
    (test-case "explicit instance assignments survive rebinding"
      (def source (instance pipeline.BaseRecord))
      (.put! source 'backend (lambda (n) (* n 4)))
      (def checked (validate pipeline.BaseRecord source))
      (check-equal? ((.get checked run) 2) 9)
      (check (eq? (.get checked captured) (.get checked backend)) => #t))
    (test-case "hook mutation returning the same object rebinds dependencies"
      (def descriptor (.cc pipeline.BaseRecord .instantiate:
        (lambda (checked) (.put! checked 'backend (lambda (n) (* n 5))) checked)))
      (def checked (make-instance descriptor))
      (check-equal? ((.get checked run) 2) 11)
      (check (eq? (.get checked captured) (.get checked backend)) => #t))
    (test-case "ObjectContract responsibilities rebind computed schema fields"
      (def raw values)
      (def descriptor (refine (.cc ObjectContract. responsibilities:
        (.o backend: pipeline.Transform captured: Any))
        (lambda (candidate path)
          (if (eq? (.get candidate backend) (.get candidate captured)) '()
            [(.o kind: 'capture path: path)]))))
      (def source (.o (:: self []) backend: raw captured: (.get self backend)))
      (def checked (validate descriptor source))
      (check (eq? (.get checked captured) (.get checked backend)) => #t)
      (check (eq? (.get checked backend) raw) => #f))
    (test-case "shape refusal precedes all rebound normalizers"
      (def calls 0)
      (def counted (.cc Integer .validate: (lambda (value) (set! calls (+ calls 1)) value)))
      (def descriptor (Record first: [counted] last: [pipeline.Transform]))
      (check-exception (make-instance descriptor first: 1 last: #f) TypeError?)
      (check-equal? calls 0))
    (test-case "custom Slot validator reads checked sibling through explicit receiver"
      (def increment (.cc Integer .validate: (lambda (n) (+ n 1))))
      (define-type (AddingSlot @ Slot)
        .slot.validate: (lambda (_ _name original receiver) (+ original (.get receiver bias))))
      (def descriptor (.cc Class. slots:
        (.o total: (.new AddingSlot type: Integer) bias: (.new Slot type: increment))))
      (def checked (validate descriptor (.o total: 1 bias: 1)))
      (check-equal? (.get checked bias) 2)
      (check-equal? (.get checked total) 3))
    (test-case "new normalization cycles retain CyclicSlot rather than partial success"
      (def looping (.cc Integer .validate: (lambda (_) 1)))
      (define-type (LoopSlot @ Slot)
        .slot.validate: (lambda (_ _name _original receiver) (.get receiver loop)))
      (def descriptor (.cc Class. slots: (.o loop: (.new LoopSlot type: looping))))
      (check-exception (validate descriptor (.o loop: 1)) CyclicSlot?))
    (test-case "full FUN factory refinement and publication share final dependencies"
      (def context-value (.o commits: 0))
      (defvalues (result state failure) ((pipeline.service-action Call context-value) request))
      (check-equal? failure #f)
      (check-equal? (.get result total) 46)
      (check-equal? (.get result nested) 8)
      (check-equal? (.get state commits) 1)
      (check (eq? (.get result subject processor backend)
                  (.get result subject processor captured)) => #t))
    (test-case "computed callback refusal retains context and repaired dependency retries"
      (def context-value (.o commits: 0))
      (def source (.o config: (config.decode-service request)
        processor: (make-instance pipeline.ServiceRecord backend: (lambda (_n) #f))))
      (def publish (computed-validation.publication.publication-action pipeline.EnvelopeContract Call context-value
        (lambda (checked)
          (def total-value ((.get checked processor run) 2))
          (values (.o subject: checked descriptor: pipeline.EnvelopeContract context: context-value
                      total: total-value) (.o commits: 1)))))
      (defvalues (result state failure) (publish source))
      (check-equal? result #f)
      (check (eq? state context-value) => #t)
      (check-equal? (metadata.failure-phase failure) 'source)
      (def repaired (.cc source processor: (make-instance pipeline.InitializedRecord)))
      (defvalues (next next-state next-failure) (publish repaired))
      (check-equal? next-failure #f)
      (check-equal? (.get next total) 10)
      (check-equal? (.get next-state commits) 1))
    (test-case "raw or stale evidence refuse and current retry remains independent"
      (def context-value (.o commits: 1)) (def stale (.o commits: 0))
      (def source (.o config: (config.decode-service request)
                         processor: (make-instance pipeline.InitializedRecord)))
      ;; Every attempt normalizes a fresh root; evidence must identify that root.
      (def (action raw-subject evidence-context)
        (computed-validation.publication.publication-action pipeline.EnvelopeContract Call context-value
          (lambda (checked)
            (values (.o subject: (or raw-subject checked) descriptor: pipeline.EnvelopeContract
                        context: evidence-context) (.o commits: 2)))))
      (for-each (lambda (publish)
                  (defvalues (result state failure) (publish source))
                  (check-equal? result #f)
                  (check (eq? state context-value) => #t)
                  (check-equal? (metadata.failure-phase failure) 'logic))
                (list (action source context-value) (action #f stale)))
      (defvalues (_ next failure) ((action #f context-value) source))
      (check-equal? failure #f)
      (check-equal? (.get next commits) 2))))

;; Return the original suites from this lexical scope.
(values computed-validation-test)
