(export focused-closure-test)
(import :std/test :clan/poo/object :clan/poo/mop :clan/poo/brace :clan/poo/lens-laws :clan/poo/focused-closure :clan/poo/generalized-closure
        :clan/poo/generalized-declaration (prefix-in :clan/poo/generalized-prototype gp.)
        (prefix-in :clan/poo/examples/closed-declarations service.)
        (prefix-in :clan/poo/examples/focused-services family.))
;; Actual joint closure, overlapping lawful lenses and whole-chain source guards.
(def focused-closure-test
  (test-suite "focused recursive component closure and joint publication"
    (test-case "two services close within a wider vector before final method cooking"
      (defvalues (view failure) (family.publish #f))
      (check-equal? failure #f)
      (check-equal? (view 2) '(96 176 272 (tenant audit)))
      (check-equal? (view 3) '(116 216 332 (tenant audit)))
      (check-equal? family.base (vector service.base service.base '(tenant audit)))
      (def action (.call gp.Observation. .map (lambda (view) (view 2))
        (focused-closures-action (family.stages) family.cook)))
      (check-equal? (action family.base) '(96 176 272 (tenant audit))))
    (test-case "a narrow Reader update preserves sibling and shared audit identity"
      (def action (focus-closure-action (car (family.stages))))
      (def changed (action family.base))
      (check-equal? (vector-ref changed 0) (vector (vector 10 13 15) 'audit))
      (check (eq? (vector-ref changed 1) (vector-ref family.base 1)) => #t)
      (check (eq? (vector-ref changed 2) (vector-ref family.base 2)) => #t))
    (test-case "heterogeneous vector service and scalar component share final admission"
      (def scalar (lens-of-get-set identity (lambda (value _) value)))
      (def prepared (.prototype GeneralizedDeclaration. (.o) identity
        (fragment scalar (lens-fragment scalar (lambda (value _ inherited) value) 7))))
      (def stage (closure-focus prepared (lens-check family.right-focus '(0 7)) 0 2))
      (def seed (vector service.base 0 'audit))
      (defvalues (whole failure) (publish-focused-closures 'old
        [(car (family.stages)) stage] seed identity))
      (check-equal? failure #f)
      (check-equal? whole (vector (vector (vector 10 13 15) 'audit) 7 'audit))
      (check-equal? seed (vector service.base 0 'audit)))
    (test-case "conflicting lawful overlapping foci cannot invalidate an earlier equation"
      (def left (car (family.stages)))
      (def other (closure-focus (service.prepare-service 20)
        (lens-check family.left-focus [service.base]) service.base 4))
      (def cooked? #f)
      (def old (lambda (_) 'old))
      (defvalues (held failure) (publish-focused-closures old [left other] family.base
        (lambda (_) (set! cooked? #t))))
      (check (eq? held old) => #t) (check (not (not failure)) => #t)
      (check-equal? cooked? #f)
      (defvalues (agreed ok) (publish-focused-closures old [left left] family.base identity))
      (check-equal? ok #f)
      (check-equal? (vector-ref agreed 0) (vector (vector 10 13 15) 'audit)))
    (test-case "second budget refusal retains old publication and skips downstream Reader"
      (def second (closure-focus (service.prepare-service 20)
        (lens-check family.right-focus [service.base]) service.base 0))
      (def reached? #f)
      (def action (.call gp.Observation. .map (lambda (_) (set! reached? #t))
        (focused-closures-action [(car (family.stages)) second] family.cook)))
      (check-exception (action family.base) true)
      (check-equal? reached? #f)
      (def old (lambda (_) 'old))
      (defvalues (held failure) (publish-focused-closures old [(car (family.stages)) second]
        family.base family.cook))
      (check (eq? held old) => #t) (check-equal? (closure-failure-kind failure) 'budget))
    (test-case "actual closed child joins the law domain even when user samples passed"
      (def bad (lens-of-get-set (lambda (whole) (vector-ref whole 0))
        (lambda (_ whole) whole)))
      (check-equal? (check-lens-laws bad [family.base] [service.base]) #t)
      (def stage (closure-focus (service.prepare-service) (lens-check bad [service.base]) service.base 4))
      (defvalues (old failure) (publish-focused-closures 'old [stage] family.base identity))
      (check-equal? old 'old) (check-equal? (lens-law-failure-law failure) 'put-get))
    (test-case "all stage dependencies stay guarded during later updates and final cooking"
      (def source (.o (value 1)))
      (def first (closure-focus (service.prepare-service)
        (lens-check family.left-focus [service.base] sources: [source]) service.base 4))
      (def focus (lens-of-get-set identity (lambda (value _) value)))
      (def mutating (.prototype GeneralizedDeclaration. (.o) identity
        (fragment mutation (lens-fragment focus (lambda (value _ inherited)
          (.putslot! source 'value ($constant-slot-spec 2)) value) 7))))
      (def last (closure-focus mutating (lens-check family.right-focus [service.base]) service.base 2))
      (defvalues (held failure) (publish-focused-closures 'old [first last] family.base identity))
      (check-equal? held 'old) (check-equal? (closure-failure-kind failure) 'source)
      (check-equal? (.@ source value) 1)
      (defvalues (same refused) (publish-focused-closures 'old [first] family.base
        (lambda (_) (.putslot! source 'value ($constant-slot-spec 3)))))
      (check-equal? same 'old) (check (not (not refused)) => #t)
      (check-equal? (.@ source value) 1)
      (.putslot! source 'value ($constant-slot-spec 4))
      (defvalues (stale cause) (publish-focused-closures 'old [first] family.base identity))
      (check-equal? stale 'old) (check (not (not cause)) => #t)
      (check-equal? (active-object-constructions) []))
    (test-case "future stage sources are protected before the first stage executes"
      (def future (.o (value 1)))
      (def focus (lens-of-get-set identity (lambda (value _) value)))
      (def prepared (.prototype GeneralizedDeclaration. (.o) identity
        (fragment mutation (lens-fragment focus (lambda (value _ inherited)
          (.putslot! future 'value ($constant-slot-spec 2)) value) 7))))
      (def first (closure-focus prepared (lens-check family.left-focus [service.base]) service.base 2))
      (def last (closure-focus (service.prepare-service)
        (lens-check family.right-focus [service.base] sources: [future]) service.base 4))
      (defvalues (held failure) (publish-focused-closures 'old [first last] family.base identity))
      (check-equal? held 'old) (check-equal? (closure-failure-kind failure) 'source)
      (check-equal? (.@ future value) 1)
      (check-equal? (active-object-constructions) []))
    (test-case "empty composition cooks the original seed and failed final cooking retains old"
      (check-equal? ((focused-closures-action [] identity) family.base) family.base)
      (defvalues (held failure) (publish-focused-closures 'old (family.stages) family.base
        (lambda (_) (error "family cooking refused"))))
      (check-equal? held 'old) (check (not (not failure)) => #t)) ))
