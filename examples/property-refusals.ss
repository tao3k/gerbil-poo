;;; Intentionally failing PBT checks; run explicitly through the standard CLI.
(export failing-properties-test)
(import :std/test
 (prefix-in :clan/poo/support/testing typed.)
 (only-in :clan/poo/mop Type. define-type)
 (only-in :clan/poo/type Exactly)
 (only-in :clan/poo/object .cc)
 (prefix-in :clan/property-testing/generator g.)
 (prefix-in :clan/property-testing/property p.)
 (prefix-in :clan/property-testing/test pbt.))
;; A fixed scalar domain isolates refusal classes from random distribution.
(def domain (p.make-specification exact-integer? abs))
;; Dependent shrinking preserves the relation while naming both reduced values.
(pbt.define-property bad-join ((left (g.make-generator (lambda (_random _size) 4) g.integer-shrinks) domain)
                             (right (g.generator-unit (1+ left)) domain)) (< (+ left right) 3))
;; Typed declaration checks use the same standard failure boundary and source name.
(typed.define-property typed-fault ((input (Exactly 4)) (limit (Exactly 3))) (< input limit))
;; Unsupported preparation remains a named diagnostic error, never an implicit pass.
(define-type Opaque (.cc Type. .element?: exact-integer?))
;; All eight outcomes must be standard test failures with distinct PBT statuses.
(def failing-properties-test
 (test-suite "PBT refusal integration"
  (test-case "typed named failure" (typed-fault seed: 42 cases: 1))
  (test-case "typed preparation error" (typed.check-property Opaque (lambda (_) #t) name: 'typed-opaque cases: 1))
  (test-case "falsified property" (bad-join seed: 42 cases: 1 shrink-budget: 32))
  (test-case "coverage refusal"
   (pbt.check-property (p.check-property (g.generator-unit 1) (lambda (_) #t) domain
     cases: 1 policy: (p.make-policy name: 'missing-coverage required: '((missing . 1))))))
  (test-case "discard exhaustion"
   (pbt.check-property (p.check-property (g.generator-unit 1) (lambda (_) #t) domain
     cases: 1 policy: (p.make-policy name: 'discarded precondition: (lambda (_) #f)))))
  (test-case "stale source"
   (pbt.check-property (p.check-property (g.make-generator (lambda (_random _size) 1)
     (lambda (_) []) current?: (lambda () #f)) (lambda (_) #t) domain cases: 1 name: 'stale-source)))
  (test-case "callback error"
   (pbt.check-property (p.check-property (g.generator-unit 1) (lambda (_) (raise #f))
     domain cases: 1 name: 'false-cause)))
  (test-case "unsupported generator"
   (pbt.check-property (p.check-property (g.generator-unit 1) (lambda (_) (error "unsupported fixture"))
     domain cases: 1 name: 'unsupported classify-error: (lambda (_) 'unsupported))))))
