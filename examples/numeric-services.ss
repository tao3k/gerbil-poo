;;; Intrinsic numeric views in qualified declarations and FUN/IO publication.
(export numeric-input numeric-output infer-numeric-service)
(import (only-in :std/func compose)
        (only-in :std/hash/misc hash-key-value-map)
        (prefix-in ./polymorphic-services service.))

;; A readable measurement batch preserves its UInt keys and accepts real results
;; from calibrators whose inputs are flonums. No wire or descriptor cast is implied.
(def numeric-input '(Pair (Map Real <- UInt) (Function (Real) (Float))))
;; The producer explicitly converts measurements and calibrator boundaries to
;; flonums. Function variance then permits this precise output as the input view.
(def numeric-output '(Pair (Map Float <- UInt) (Function (Float) (Real))))

;; Use the standard table mapper and higher-order composition for actual value
;; conversion. Type inference itself neither coerces data nor calls calibrators.
(def (cook-measurements batch)
  (cons (hash-key-value-map (lambda (key value) (cons key (exact->inexact value))) (car batch))
        (compose exact->inexact (cdr batch) exact->inexact)))

;; One existing whole-candidate solver owns prefix specialization, qualified
;; method fragments, recursive callback wrapping and failure classification.
;; descriptor-service-action supplies refinement, bound evidence and FUN/IO.
(def (infer-numeric-service candidates (record void))
  (service.infer-descriptor-service (list numeric-input) candidates
    (list (list [] (list numeric-input)
      (list numeric-output `(Function (,numeric-output) (,numeric-input)))))
    (lambda (batch) (values (cook-measurements batch) cook-measurements)) record))
