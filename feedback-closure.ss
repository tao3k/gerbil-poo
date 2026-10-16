;;; Controlled cyclic component equations on one comparable wider raw carrier.
(export feedback-closure-action publish-feedback feedback-equation-failure? feedback-equation-failure-name)
(import ./object ./mop ./lens-laws ./generalized-declaration ./generalized-closure
        (prefix-in ./generalized-prototype gp.))
;; A whole assembled fixed point may hide cancelling overlapping contributions.
;; Preserve the declared name of a component whose independent equation refuses.
(defstruct feedback-equation-failure (name) final: #t)
;; Validate complete component equations against the SAME cooked final self and
;; original base, never re-elaborating singleton declaration streams. Lens checks
;; include actual replacements; whole raw equality cannot certify arbitrary laws.
(def (check-feedback-equations prepared base closed)
  (def raw (closed-raw closed))
  (def self (lambda () (closed-interface closed)))
  (for-each (lambda (name part)
    (def focus (.@ part focus))
    (def get (.@ focus .get)) (def put (.@ focus .set))
    (def produced ((.@ part .compile) self (lambda () base)))
    (check-lens-laws focus [base raw] [(get base) (get raw) (get produced)])
    (unless (equal? produced (put (get raw) base))
      (raise (make-feedback-equation-failure name))))
    (fragment-names prepared) (fragment-descriptors prepared)))
;; Native FUN Reader closes one whole feedback state using the existing bounded
;; raw search, then checks EVERY component residual before exposing its receipt.
;; Each fragment denotes a complete component equation; intentional same-focus
;; incremental method contributions belong INSIDE one component or its cooking.
;; Pure callbacks/immutable raw data and explicit registered sources are premises.
(def (feedback-closure-action prepared base budget checks: (checks []))
  (lambda (seed)
    (with-fragment-sources prepared (lambda ()
      (def automatic (map (lambda (part)
        (def focus (.@ part focus))
        (lens-check focus [((.@ focus .get) base)])) (fragment-descriptors prepared)))
      (def all (append automatic checks))
      (with-lens-checks all (lambda ()
        ((.call gp.Observation. .map (lambda (closed)
          (check-feedback-equations prepared base closed) closed)
          (closure-action prepared base budget checks: all)) seed)))))))
;; Only a completely closed and residual-checked receipt replaces publication.
;; Budget/lens/source errors keep their original types; residual errors name the
;; component. Cooking may have run in the staged local search; effects do not roll back.
(def (publish-feedback old prepared base seed budget checks: (checks []))
  (try (values ((feedback-closure-action prepared base budget checks: checks) seed) #f)
    (catch (failure) (values old failure))))
