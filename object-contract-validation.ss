;;; Persistent field validation through the existing POO Type protocol.
(export validation-fields prepare-validation validate-object)
(import (only-in ./value-diagnostics diagnose-structure)
        (only-in ./validation-rebinding rebind-validation finish-validation)
        (only-in ./object .all-slots .ref .get)
        (only-in ./mop validate raise-type-error))

;; Prepare the selected Type validators once per descriptor. Rebind inherited
;; computations to the checked receiver rather than freezing raw getter results.
;; Every check finishes before obligations; Function bodies remain deferred.
(def (validation-fields fields)
  (map (lambda (name)
         (def type (.ref fields name))
         (cons name (lambda (original _receiver) (validate type original))))
       (.all-slots fields)))

;; Capture selected checks once; ordinary validation retains its no-change path.
(def (prepare-validation fields)
  (def checks (validation-fields fields))
  (lambda (candidate) (rebind-validation candidate checks)))

;; Gate wrapping on structural success, then recheck the final checked object.
;; Constraints/refinements observe wrapped fields, never an intermediate copy.
;; Recognition stays separate: diagnose does not wrap or cache accepted values.
(def (validate-object descriptor candidate)
  (def shape (diagnose-structure descriptor candidate '()))
  (unless (null? shape) (raise-type-error descriptor candidate shape))
  (def checked ((.get descriptor prepared-validation) candidate))
  (finish-validation (lambda ()
    (def failures ((.get descriptor .diagnose) checked '()))
    (unless (null? failures) (raise-type-error descriptor checked failures))))
  checked)
