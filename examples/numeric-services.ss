;;; Intrinsic numeric views in qualified declarations and FUN/IO publication.
(export numeric-input numeric-output infer-numeric-service
        residue-input residue-output infer-residue-service real-batch-input real-batch-output infer-real-batch-service)
(import (only-in :std/func compose)
        (only-in :std/hash/misc hash-key-value-map)
        (runtime: :clan/poo/examples/polymorphic-services)
        (prefix-in (only-in ./polymorphic-services infer-descriptor-service) service.))

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

;; One complete signature observation is shared by all numeric batch services.
;; Keep parameter specialization, qualified fragments and recursive wrapping in
;; the existing factory; reuse the actual producer for the returned callback.
(def (infer-batch-service input output candidates cook record)
  (service.infer-descriptor-service (list input) candidates
    (list (list [] (list input) (list output `(Function (,output) (,input)))))
    (lambda (batch) (values (cook batch) cook)) record))

;; Explicit flonum conversion feeds the same complete declaration chain.
;; descriptor-service-action supplies refinement, bound evidence and FUN/IO.
(def (infer-numeric-service candidates (record void))
  (infer-batch-service numeric-input numeric-output candidates cook-measurements record))

;; Rational readings include finite flonums; input checking rejects nonfinite
;; values before the producer performs its explicit floor/modulo conversion.
(def residue-input '(Pair (Map Rational <- UInt) (Function (Rational) (Rational))))
;; Preserve the original modulus descriptor in values and nested callback results.
;; The shared syntax admission checks literal metadata before any builder runs.
(def (residue-output modulus)
  `(Pair (Map (Z/ ,modulus) <- UInt) (Function ((Z/ ,modulus)) (Rational))))

;; Conversion belongs to this producer, never to descriptor inclusion/validation.
;; Reuse the standard table mapper and compose the checked calibrator with the
;; same explicit reducer; original readings and callbacks are not mutated.
(def (cook-residues modulus batch)
  (def reduce (compose (cut modulo <> modulus) inexact->exact floor))
  (cons (hash-key-value-map (lambda (key value) (cons key (reduce value))) (car batch))
        (compose reduce (cdr batch))))

;; Prefix specialization, whole-candidate inference and qualified declarations
;; are the existing descriptor service chain. Publication uses its FUN action,
;; refine and bind-evidence; unsupported moduli refuse before host conversion.
(def (infer-residue-service modulus candidates (record void))
  (infer-batch-service residue-input (residue-output modulus) candidates
    (cut cook-residues modulus <>) record))

;; A real relay has a jointly covering ordered input view, including exceptional
;; flonums via Float. No branch order or numeric value is changed by inference.
(def real-batch-input
  '(Pair (Map (Union Rational Float) <- UInt) (Function ((Union Rational Float)) (Real))))
;; The producer keeps the real-valued view. Function input contravariance and
;; result covariance require the same Real-to-Union proof as the table values.
(def real-batch-output '(Pair (Map Real <- UInt) (Function (Real) (Real))))

;; Reuse complete inference and recursive wrapper publication even for a relay;
;; identity is actual producer behavior, not an unchecked declaration shortcut.
(def (infer-real-batch-service candidates (record void))
  (infer-batch-service real-batch-input real-batch-output candidates identity record))
