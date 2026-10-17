;;; Full syntax, optional generic forwarding and positional specialization chain.
(export parameters-test)
(import :std/test :std/error (for-syntax :gerbil/expander) ../object ../mop ../number
        (prefix-in ../parameters parameters.)
        (prefix-in ../examples/parameter-service service.)
        (prefix-in ../method-declaration methods.)
        (prefix-in ../method-combination combination.))

;; Expand the real constructor macro, retaining a valid control for the same path.
(defsyntax (rejects? stx)
  (syntax-case stx ()
    ((_ form)
     (try (core-expand #'form) #'#f (catch (_cause) #'#t)))))

;; Defaults resolve once before instance-method dispatch, including false values.
(.defgeneric (collect self required (optional #f) tag: (tag 'default) . rest) slot: collect)
;; Type-provided methods receive the exact receiver followed by resolved arguments.
(.defgeneric (typed self required (optional 2) tag: (tag 'default) . rest) slot: collect from: type)
;; Combination receives the same canonical optional/keyword/rest argument sequence.
(.defgeneric (combined self required (optional 2) tag: (tag 'default) . rest)
  slot: parts combination: (methods.simple-combination combination.collect))
;; Missing-slot default shares the same forwarding path without swallowing body errors.
(.defgeneric (fallback self value (amount 2)) slot: missing default: (lambda (value amount) (+ value amount)))

;; Match exact validation failures rather than accepting any arithmetic exception.
(def (message? text)
  (lambda (cause) (and (Error? cause) (equal? (error-message cause) text))))

;; Exercise complete public APIs, receiver sharing, mutation discipline and effects.
(def parameters-test
  (test-suite "object syntax and positional specialization"
    (test-case "construction option errors refuse during actual macro expansion"
      (check (rejects? (.o self: receiver x: 1)) => #f)
      (check (rejects? (.o self: 1 x: 2)) => #t)
      (check (rejects? (.o self: a self: b x: 2)) => #t)
      (check (rejects? (.o inherit:)) => #t)
      (check (rejects? (.o bind: (1) x: 2)) => #t)
      (check (rejects? (.o bind-these: (+ 1 2) x: 2)) => #t)
      (check (rejects? (.o self: same super: same x: 2)) => #t)
      (check (rejects? (.o self: x x: 2)) => #t)
      (check (rejects? (.o bind-these: #f bind-these: #t x: 2)) => #t))
    (test-case "keyword syntax preserves C3 inherited-thunk and final-self behavior"
      (let* ((partial (parameters.specialize service.Service 10))
             (closed (parameters.specialize partial 3))
             (direct (parameters.specialize service.Service 10 3)))
        (check-equal? (parameters.parameters service.Service) '(capacity tariff))
        (check-equal? (parameters.parameters partial) '(tariff))
        (check-equal? (parameters.parameters closed) [])
        (check-equal? (.get closed fee) 11)
        (check-equal? (.get closed total) 41)
        (check-equal? (.get direct total) 41)
        (check-equal? (.get (.cc closed capacity: 20) total) 71)
        (let-values (((amount currency region notes) (service.quote-service closed 2 1 currency: 'EUR 'review #f)))
          (check-equal? (list amount currency region notes) '(81 EUR global (review #f))))
        (check-exception (.get service.Service capacity) NoApplicableMethod?)
        (check-exception (.get partial tariff) NoApplicableMethod?)))
    (test-case "automatic binding can be disabled independently from explicit imports"
      (let* ((x 100) (external 7) (parent (.o x: 2 y: 3))
             (a (.o self: receiver inherit: (list parent) bind: (y) bind-these: #f
                  x: 4 total: (+ x y external (.get receiver x))))
             (b (.o inherit: (list parent) bind: (y) bind-these: #t x: 4 total: (+ x y external))))
        (check-equal? (.get a total) 114)
        (check-equal? (.get b total) 14)
        (check-equal? (.get (.cc a x: 8) total) 118)))
    (test-case "explicit inherited names defaults shorthand and reserved slot names coexist"
      (let* ((captured 9) (parent (.o n: 3))
             (value (.o self: receiver super: prior inherit: (list parent)
               (n (next) (+ (prior) (next))) (captured) (fallback ? 7)
               (self 'data) (super 'slot))))
        (check-equal? (.get value n) 6)
        (check-equal? (.get value captured) captured)
        (check-equal? (.get value fallback) 7)
        (check-equal? (.get value self) 'data)
        (check-equal? (.get value super) 'slot)))
    (test-case "optional keyword rest and from:type forwarding retain exact values"
      (let* ((self (.o collect: (lambda (required optional tag: tag . rest)
                     (list required optional tag rest))))
             (descriptor (.o collect: (lambda (receiver required optional tag: tag . rest)
                     (list receiver required optional tag rest))))
             (typed-self (.o .type: descriptor))
             (parts (.o parts: (list (combination.item (lambda (required optional tag: tag . rest)
                     (list required optional tag rest)))))))
        (check-equal? (collect self 1) '(1 #f default ()))
        (check-equal? (collect self 1 #f tag: #f 'x 'y) '(1 #f #f (x y)))
        (let ((result (typed typed-self 1)))
          (check (eq? (car result) typed-self) => #t)
          (check-equal? (cdr result) '(1 2 default ())))
        (check-equal? (combined parts 1 4 tag: 'k #f) '((1 4 k (#f))))
        (check-equal? (fallback (.o) 3) 5)
        (check-exception (collect (.o collect: (lambda (_x _y tag: _tag) (raise 'body-error))) 1)
          (lambda (cause) (eq? cause 'body-error)))))
    (test-case "defaults are lazy when supplied and evaluate once in lexical order"
      (let ((calls []))
        (.defgeneric (defaults self value (a (begin (set! calls (cons 'a calls)) value))
                            b: (b (begin (set! calls (cons 'b calls)) a))) slot: values)
        (let ((receiver (.o values: (lambda (value a b: b) (list value a b)))))
          (check-equal? (defaults receiver 5) '(5 5 5))
          (check-equal? (reverse calls) '(a b))
          (set! calls [])
          (check-equal? (defaults receiver 5 7 b: #f) '(5 7 #f))
          (check-equal? calls []))))
    (test-case "specialization refuses malformed metadata excess values and preserves identity"
      (check (eq? service.Service (parameters.specialize service.Service)) => #t)
      (for-each (lambda (names)
        (check-exception (parameters.specialize (.o .parameters: names) 1)
          (message? "invalid positional parameter declaration")))
        '((x x) (.parameters) (1) (x . y)))
      (check-exception (parameters.specialize service.Service 1 2 3) (message? "too many positional arguments"))
      (let* ((names (list 'x 'y)) (source (.o .parameters: names))
             (partial (parameters.specialize source #f)))
        (set-car! (cdr names) 'changed)
        (check-equal? (parameters.parameters partial) '(y))
        (check (.get partial x) => #f)))
    (test-case "FUN admission gates effects and preserves all consumer results"
      (let ((calls 0))
        (let-values (((amount currency region notes)
            ((service.specialize-action '(10 3) (lambda (value)
              (set! calls (+ calls 1)) (service.quote-service value 2))) service.Service)))
          (check-equal? (list amount currency region notes) '(82 USD global ())))
        (check-exception ((service.specialize-action '(-1 3) (lambda (_) (set! calls (+ calls 1)))) service.Service) TypeError?)
        (check-exception ((service.specialize-action '(10 "bad") (lambda (_) (set! calls (+ calls 1)))) service.Service) TypeError?)
        (check-equal? calls 1)))))
