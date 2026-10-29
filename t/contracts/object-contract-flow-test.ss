(export object-contract-flow-test)
(import :std/test :clan/poo/object :clan/poo/mop :clan/poo/brace :clan/poo/io
        (only-in :clan/poo/type String Json)
        :clan/poo/object-contract
        (prefix-in :clan/poo/examples/object-contracts service.))
;; Extract ordered public refusal kinds without depending on slot enumeration.
(def (kinds failures) (map (lambda (failure) (.get failure kind)) failures))
;; Check pure reports separately from the explicit I/O/FUN consumption boundary.
(def object-contract-flow-test
  (test-suite "structural contracts compose through diagnostics and FUN/IO"
    (test-case "independent refusals accumulate in exact declaration order"
      (def left (lambda (_ location) [(.o kind: 'left path: location)]))
      (def right (lambda (_ location) [(.o kind: 'right path: location)]))
      (def combined (diagnostic-all [left right left]))
      (check-equal? (kinds (combined #f '(config))) '(left right left))
      (check-equal? (map (lambda (issue) (.get issue path)) (combined #f '(config)))
                    '((config) (config) (config)))
      (check-equal? ((diagnostic-all []) #f '()) '()))
    (test-case "phase refusal gates the exact next callback"
      (def calls 0) (def refusal [(.o kind: 'shape path: '(service))])
      (def next (lambda (_ __) (set! calls (+ calls 1)) '()))
      (check (eq? ((diagnostic-then (lambda (_ __) refusal) next) #f '()) refusal) => #t)
      (check-equal? calls 0)
      (check-equal? ((diagnostic-then (lambda (_ __) '()) next) #f '()) '())
      (check-equal? calls 1))
    (test-case "callback errors and malformed reports do not become refusals"
      (def cause (list 'original)) (def calls 0)
      (def broken (diagnostic-all [(lambda (_ __) (raise cause))
        (lambda (_ __) (set! calls (+ calls 1)) '())]))
      (check-exception (broken #f '()) (lambda (caught) (eq? caught cause)))
      (check-equal? calls 0)
      (check-exception ((diagnostic-all [(lambda (_ __) #f)]) #f '()) error?)
      (check-exception (diagnostic-all [7]) error?)
      (check-exception (diagnostic-then 7 void) error?))
    (test-case "prepared parent phase does not hide child obligations"
      (def parent (.cc ObjectContract. responsibilities: (.o name: String)))
      (def prepared (.get parent prepared-obligations))
      (def child (.cc parent obligations:
        (lambda (_ location) [(.o kind: 'child-only path: location)])))
      (check-equal? (diagnose parent (.o name: "parent")) '())
      (check-equal? (kinds (diagnose child (.o name: "child"))) '(child-only))
      (check (eq? prepared (.get child prepared-obligations)) => #f))
    (test-case "JSON input preserves unknown fields and gates all consumption"
      (def calls 0)
      (def execute (checked-action service.ServiceContract
        (lambda (value) (set! calls (+ calls 1)) (values 'accepted value))))
      (def decoded (service.decode-service
        "{\"host\":\"api\",\"port\":443,\"capacity\":10,\"used\":2,\"secure\":true}"))
      (defvalues (result current) (execute decoded))
      (check-equal? result 'accepted) (check (eq? current decoded) => #t)
      (def misspelled (.cc decoded prot: 443))
      (check-exception (execute misspelled) TypeError?)
      (check-exception (execute (.cc decoded port: "bad")) TypeError?)
      (check-exception (execute (.cc decoded port: 0)) TypeError?)
      (check-exception (execute (.cc decoded port: 65536)) TypeError?)
      (check-equal? calls 1)
      (check-exception (service.decode-service "{") error?))
    (test-case "two cross-field obligations accumulate after structural success"
      (def decoded (service.decode-service
        "{\"host\":\"api\",\"port\":80,\"capacity\":2,\"used\":3,\"secure\":true}"))
      (def issues (diagnose service.ServiceContract decoded '(service)))
      (check-equal? (kinds issues) '(capacity-exceeded secure-port-required))
      (check-equal? (map (lambda (issue) (.get issue path)) issues)
                    '((service used) (service port)))
      (check-equal? (kinds (diagnose service.ServiceContract (.cc decoded used: -1 port: 443)))
                    '(capacity-exceeded)))
    (test-case "persistent revision validates before JSON output and rechecks each call"
      (def source (service.decode-service
        "{\"host\":\"api\",\"port\":80,\"capacity\":10,\"used\":2,\"secure\":true}"))
      (def writes 0)
      (def action (service.revise-action 3 443
        (lambda (value) (set! writes (+ writes 1))
          (values (json-string<- Json (hash<-object value)) value))))
      (defvalues (encoded updated) (action source))
      (check-equal? (.get updated used) 5) (check-equal? (.get updated port) 443)
      (check-equal? (.get source used) 2) (check-equal? (.get source port) 80)
      (check-equal? (diagnose service.ServiceContract (service.decode-service encoded)) '())
      (check-exception (action (.cc source capacity: 4)) TypeError?)
      (check-exception (action (.cc source used: "bad")) TypeError?)
      (check-equal? writes 1))
    (test-case "checked action preserves Function normalization and multiple values"
      (def wrapped (checked-action (Fun Bool <- Bool)
        (lambda (function) (values (function #t) function))))
      (defvalues (result function) (wrapped identity))
      (check-equal? result #t)
      (check-exception (function 'wrong-input) TypeError?)
      (def cause (list 'validator-cause)) (def calls 0)
      (def descriptor (.cc Type. .element?: true .validate: (lambda (_) (raise cause))))
      (def action (checked-action descriptor (lambda (_) (set! calls (+ calls 1)))))
      (check-exception (action #f) (lambda (caught) (eq? caught cause)))
      (check-equal? calls 0))))
