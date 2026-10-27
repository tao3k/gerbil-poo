(export feedback-closure-test)
(import :std/test :clan/poo/object :clan/poo/mop :clan/poo/brace :clan/poo/lens-laws :clan/poo/generalized-declaration
        :clan/poo/generalized-closure :clan/poo/feedback-closure (prefix-in :clan/poo/generalized-prototype gp.)
        (prefix-in :clan/poo/examples/feedback-services services.))
;; Cyclic global self, component equations, refusal and native FUN composition.
(def feedback-closure-test
  (test-suite "controlled cyclic component feedback closure"
    (test-case "a three-service feedback ring closes before joint approved method calls"
      (def prepared (services.prepare-services))
      (defvalues (closed failure) (publish-feedback #f prepared services.base services.base 5))
      (check-equal? failure #f) (check-equal? (closed-steps closed) 5)
      (check-equal? (services.report closed 2) '(3 3 3 #t 36 audit))
      (check-equal? (services.report closed 3) '(3 3 3 #t 54 audit))
      (check-equal? (closed-raw closed) (step-fragments prepared (closed-raw closed) services.base))
      (check-equal? services.base (vector (vector 0 0 0) #f 'audit))
      (def early (observe-fragments prepared services.base services.base 3))
      (check-equal? (early 'a) 3) (check-equal? (early 'ready) #f)
      (check-exception ((early 'charge) 2) true))
    (test-case "the concrete capped ring settles from a different original seed"
      (def action (.call gp.Observation. .map (lambda (closed) (services.report closed 2))
        (feedback-closure-action (services.prepare-services) services.base 5)))
      (check-equal? (action (vector (vector 100 0 2) #t 'seed)) '(3 3 3 #t 36 audit))
      (defvalues (zero failure) (publish-feedback #f (services.prepare-services 0) services.base services.base 2))
      (check-equal? failure #f) (check-equal? (services.report zero 9) '(0 0 0 #t 0 audit)))
    (test-case "nonlocal declaration finalization runs once before feedback closure"
      (def finalized 0)
      (def expander (.o (:: @ GeneralizedDeclaration.)
        (finalize-declarations (inherited) (lambda (context entries)
          (set! finalized (+ finalized 1)) ((inherited) context entries)))))
      (def focus (lens-of-get-set identity (lambda (value _) value)))
      (def prepared (.prototype expander (.o) identity
        (fragment complete (lens-fragment focus (lambda (value _ inherited) value) 7))))
      (check-equal? finalized 1)
      (defvalues (closed failure) (publish-feedback #f prepared 0 0 2))
      (check-equal? failure #f) (check-equal? (closed-raw closed) 7)
      (check-equal? finalized 1)
      (check-equal? (length (fragment-descriptors prepared)) 1))
    (test-case "whole-program cancellation cannot certify conflicting component equations"
      (def focus (lens-of-get-set identity (lambda (value _) value)))
      (def prepared (.prototype GeneralizedDeclaration. (.o) identity
        (fragment plus (lens-fragment focus (lambda (amount _ parent) (+ amount (parent))) 1))
        (fragment minus (lens-fragment focus (lambda (amount _ parent) (+ amount (parent))) -1))))
      (defvalues (assembled _) (close-fragments prepared 0 0 1))
      (check-equal? (closed-raw assembled) 0)
      (defvalues (held failure) (publish-feedback 'old prepared 0 0 1))
      (check-equal? held 'old) (check (feedback-equation-failure? failure) => #t)
      (check-equal? (feedback-equation-failure-name failure) 'plus))
    (test-case "exhaustion and oscillation publish no prefix and skip Reader suffix"
      (def reached? #f)
      (def action (.call gp.Observation. .map (lambda (_) (set! reached? #t))
        (feedback-closure-action (services.prepare-services) services.base 4)))
      (check-exception (action services.base) true) (check-equal? reached? #f)
      (def focus (lens-of-get-set identity (lambda (value _) value)))
      (def oscillator (.prototype GeneralizedDeclaration. (.o) identity
        (fragment toggle (lens-fragment focus (lambda (_ self inherited) (not (self))) #f))))
      (defvalues (held failure) (publish-feedback 'old oscillator #f #f 6))
      (check-equal? held 'old) (check-equal? (closure-failure-kind failure) 'budget)
      (check-equal? (closure-failure-steps failure) 6))
    (test-case "zero budget runs no wrapper and a false stable raw value remains valid"
      (def calls 0)
      (def focus (lens-of-get-set identity (lambda (value _) value)))
      (def prepared (.prototype GeneralizedDeclaration. (.o) identity
        (fragment stable (lens-fragment focus (lambda (_ self inherited) (set! calls (+ calls 1)) #f) #f))))
      (defvalues (old refused) (publish-feedback 'old prepared #f #f 0))
      (check-equal? old 'old) (check-equal? (closure-failure-steps refused) 0)
      (check-equal? calls 0)
      (defvalues (closed ok) (publish-feedback 'old prepared #f #f 1))
      (check-equal? ok #f) (check-equal? (closed-raw closed) #f)
      (check-equal? calls 2))
    (test-case "stale declarations refuse and fresh revision preserves the old cooked snapshot"
      (def prepared (services.prepare-services))
      (defvalues (old _) (publish-feedback #f prepared services.base services.base 5))
      (.putslot! (car (fragment-descriptors prepared)) 'method ($constant-slot-spec 4))
      (defvalues (held failure) (publish-feedback old prepared services.base services.base 6))
      (check (eq? held old) => #t) (check (not (not failure)) => #t)
      (check-equal? (services.report old 2) '(3 3 3 #t 36 audit))
      (defvalues (next ok) (publish-feedback old (services.prepare-services 4) services.base services.base 6))
      (check-equal? ok #f) (check-equal? (services.report next 2) '(4 4 4 #t 48 audit)))
    (test-case "all supplied check sources stay guarded through residual validation"
      (def source (.o (value 1)))
      (def focus (lens-of-get-set identity (lambda (value _) value)))
      (def calls 0)
      (def prepared (.prototype GeneralizedDeclaration. (.o) identity
        (fragment guarded (lens-fragment focus (lambda (value _ inherited)
          (set! calls (+ calls 1))
          (when (> calls 1) (.putslot! source 'value ($constant-slot-spec 2))) value) 7))))
      (defvalues (held failure) (publish-feedback 'old prepared 7 7 1
        checks: [(lens-check focus '(7) sources: [source])]))
      (check-equal? held 'old) (check (not (not failure)) => #t)
      (check-equal? (.@ source value) 1)
      (check-equal? (active-object-constructions) []))
    (test-case "final cooking and malformed lens refusal retain the exact old publication"
      (def focus (lens-of-get-set identity (lambda (value _) value)))
      (def broken (.prototype GeneralizedDeclaration. (.o) (lambda (_) (error "cook refused"))
        (fragment stable (lens-fragment focus (lambda (value _ inherited) value) 7))))
      (def old (lambda (_) 'old))
      (defvalues (held failure) (publish-feedback old broken 7 7 1))
      (check (eq? held old) => #t) (check-equal? (closure-failure-kind failure) 'source)
      (def bad (lens-of-get-set car (lambda (_ raw) raw)))
      (def invalid (.prototype GeneralizedDeclaration. (.o) identity
        (fragment bad (lens-fragment bad (lambda (value _ inherited) value) 7))))
      (defvalues (same refused) (publish-feedback old invalid '(0 . audit) '(1 . audit) 1))
      (check (eq? same old) => #t) (check-equal? (closure-failure-kind refused) 'lens))))
