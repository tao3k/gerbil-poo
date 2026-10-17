;;; Real Gerbil using controls plus legacy failure and recursive wrapping parity.
(export contract-checks-test)
(import :std/test :std/error ../object ../mop ../type-relation ../type-syntax ../prototype-types
        (only-in ../support/base require-value) ../object-contract ../object-contract-flow ../object-diagnostics
        (prefix-in ../declarative-metadata metadata.)
        (prefix-in ../function-signature signatures.)
        (prefix-in ../examples/row-services rows.)
        (prefix-in ../examples/contract-interop interop.))

;; Capture only the observed exception object for identity and exact payload checks.
(def (caught action)
  (try (action) #f (catch (cause) cause)))
;; Match legacy error messages without accepting changed exception families.
(def (message? expected)
  (lambda (cause) (and (Error? cause) (not (contract-violation-error? cause))
                       (equal? (error-message cause) expected))))
;; All controls use the actual standard using macro from the active Gerbil prelude.
(def contract-checks-test
  (test-suite "Gerbil contracts under POO boundaries"
    (test-case "standard using rejects false and accepts truthy predicate values"
      (check-exception (using (value 1 :~ procedure?) value) contract-violation-error?)
      (check-exception (check-argument #f "a procedure" 1) contract-violation-error?)
      (let* ((value (list 'original)) (calls 0) (refusals 0)
             (actual (require-value value (lambda (_) (set! calls (+ calls 1)) 'accepted)
                       (lambda () (set! refusals (+ refusals 1)) (error "unexpected")))))
        (check (eq? actual value) => #t) (check-equal? calls 1) (check-equal? refusals 0)))
    (test-case "false translates exactly once through the original refusal policy"
      (let* ((cause (list 'legacy)) (calls 0) (refusals 0)
             (observed (caught (lambda ()
               (require-value 'value (lambda (_) (set! calls (+ calls 1)) #f)
                 (lambda () (set! refusals (+ refusals 1)) (raise cause)))))))
        (check (eq? observed cause) => #t) (check-equal? calls 1) (check-equal? refusals 1)))
    (test-case "a predicate ContractViolation is never mistaken for local guard refusal"
      (let* ((cause (caught (lambda () (using (x 1 :~ procedure?) x))))
             (mapped 0)
             (actual (caught (lambda ()
               (require-value 'value (lambda (_) (raise cause))
                 (lambda () (set! mapped (+ mapped 1)) (error "wrong translation")))))))
        (check (contract-violation-error? cause) => #t)
        (check (eq? actual cause) => #t) (check-equal? mapped 0)))
    (test-case "host predicates and ranges reuse core contract rules"
      (check-equal? (require-value '(a b) (list-of? symbol?) (lambda () (error "bad"))) '(a b))
      (check (require-value 'closed (one-of open closed) (lambda () (error "bad"))) => 'closed)
      (check-exception (type-work 0) (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) 'malformed))))
      (check-exception (type-work (expt 2 100)) (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) 'malformed))))
      (let (work (type-work 1))
        (work)
        (check-exception (work) (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) 'exhausted))))))
    (test-case "public constructor messages and TypeError payload stay authoritative"
      (check-exception (checked-action Any #f) (message? "Contract consumer must be a procedure"))
      (check-exception (refine (.cc ObjectContract. responsibilities: (.o)) #f)
                       (message? "Refinement must be a diagnostic procedure"))
      (check-exception (diagnostic-all [identity #f]) (message? "Diagnostic checks must be a list of procedures"))
      (let* ((descriptor (expression-type '(Function (UInt) (Integer))))
             (cause (caught (lambda () (validate descriptor #f)))))
        (check (TypeError? cause) => #t)
        (check (contract-violation-error? cause) => #f)))
    (test-case "initial callee refusal precedes signature metadata forcing"
      (let* ((demanded 0) (cause (list 'callee))
             (signature (.o keywords: (begin (set! demanded (+ demanded 1)) []))))
        (check-exception (signatures.wrap-function 'descriptor #f (list signature) validate
                           (lambda (_descriptor _value) (raise cause)))
                         (lambda (actual) (eq? actual cause)))
        (check-equal? demanded 0)))
    (test-case "structural refusal performs no child normalization or consumption"
      (let* ((normalizations 0)
             (field (.cc Type. .element?: (lambda (_) #t)
                       .validate: (lambda (value) (set! normalizations (+ normalizations 1)) value)))
             (descriptor (.cc ObjectContract. responsibilities: (.o value: field)))
             (action (checked-action descriptor identity)))
        (check-exception (action (.o value: 1 extra: #t)) TypeError?)
        (check-equal? normalizations 0)))
    (test-case "typed Gerbil consumer receives deeply normalized shared service rows once"
      (let* ((instance (instantiate-prototype rows.ServiceType '((Object ((audit Integer)) closed)) 100000))
             (target (interop.make-sink)) (action (interop.admit-to-sink instance target 10)))
        (let-values (((checked count) (action (rows.shared-service))))
          (check-equal? count 1)
          (check-equal? ((.get (car (.get checked roots)) adjust) -4) 4)
          (check-exception ((.get (car (.get checked roots)) adjust) #f) TypeError?))
        (check-exception (action (.o handler: #f roots: [] audit: 1)) TypeError?)
        (check-equal? (interop.sink-count target) 1)
        (check-exception ((interop.admit-to-sink instance target 2) (rows.shared-service)) TypeError?)
        (check-equal? (interop.sink-count target) 1)))
    (test-case "host observation and evidence binding reject stale subject identity"
      (let* ((instance (instantiate-prototype rows.ServiceType '((Object ((audit Integer)) closed)) 100000))
             (target (interop.make-sink)) (raw (rows.shared-service))
             (context (.o revision: 1)) (old (.o revision: 0))
             (actual #f)
             (checked ((rows.admit-service instance 10 identity) raw))
             (evidence (.o bind-these: #f subject: checked descriptor: (.get instance descriptor) context: context)))
        (let-values (((value next refusal) (rows.publish-service instance checked context evidence old)))
          (check (eq? value evidence) => #t) (check (eq? next checked) => #t) (check-equal? refusal #f))
        ;; A fresh normalization is a distinct checked subject; old evidence cannot approve it.
        (let-values (((value next refusal)
                      (interop.publish-from-sink instance target 10 raw context (lambda (_checked _context) evidence) old)))
          (set! actual refusal)
          (check-equal? value #f) (check (eq? next old) => #t) (check (not (not refusal)) => #t))
        (check-equal? (interop.sink-count target) 1)
        (check (not (not actual)) => #t)
        (let-values (((value next refusal)
                      (interop.publish-from-sink instance target 10 raw context
                        (lambda (subject context)
                          (.o bind-these: #f subject: subject descriptor: (.get instance descriptor) context: context)) old)))
          (check-equal? refusal #f) (check (eq? (.get value subject) next) => #t)
          (check-equal? ((.get next handler) -3) 3))
        (check-equal? (interop.sink-count target) 2)))
    (test-case "consumer ContractViolation and multiple values bypass the local guard handler"
      (let* ((cause (caught (lambda () (using (x #f :~ procedure?) x))))
             (action (checked-action Any (lambda (_) (raise cause)))))
        (check-exception (action 3) (lambda (actual) (eq? actual cause))))
      (let-values (((a b c) ((checked-action Any (lambda (_) (values 1 #f 3))) 0)))
        (check-equal? (list a b c) '(1 #f 3))))
    (test-case "Function body ContractViolation cannot trigger CaseFunction fallback"
      (let* ((cause (caught (lambda () (using (x 1 :~ procedure?) x))))
             (calls 0) (descriptor (CaseFunction (Function [Any] [Any]) (Function [Any] [Any])))
             (checked (validate descriptor (lambda (_) (set! calls (+ calls 1)) (raise cause)))))
        (check-exception (checked #t) (lambda (actual) (eq? actual cause)))
        (check-equal? calls 1)))))
