;;; Existing Maybe/OrFalse sentinels and dependent TypeValuePair validation.
(export optional-shape validate-optional type-value-shape validate-type-value)
(import (only-in ./object .o)
        (only-in ./mop Type element? validate raise-type-error)
        (only-in ./type-validation validate-container))

;; Absent values bypass even child descriptor lookup. Present values keep the
;; supplied recursive checker, so nested refinements wait until wrapping.
(def (optional-shape absent? type-thunk candidate location check-field)
  (if (absent? candidate) '() (check-field (type-thunk) candidate location)))

;; Lock the present child Type. A bad validator cannot erase a Function by
;; returning an outer sentinel unless that child Type itself accepts the result.
;; Absent source values retain exact identity and do not demand the child Type.
(def (validate-optional descriptor absent? type-thunk candidate)
  (if (absent? candidate) candidate
    (let (child (type-thunk))
      (validate-container descriptor candidate
        (lambda (source)
          (def checked (validate child source))
          (unless (element? child checked) (raise-type-error child checked))
          checked)))))

;; Check the carried Type before inspecting its dependent value. Paths retain
;; car/cdr roles; neither an invalid Type nor a malformed carrier invokes payload checks.
(def (type-value-shape descriptor candidate location check-field)
  (cond
    ((not (pair? candidate)) [(.o kind: 'expected-type-value-pair path: location expected: descriptor)])
    ((not (element? Type (car candidate)))
     [(.o kind: 'invalid-type path: (append location '(car)) expected: Type)])
    (else (check-field (car candidate) (cdr candidate) (append location '(cdr))))))

;; Validate the dependent payload rather than the whole pair. Retain the exact
;; carried Type and original pair when unchanged; otherwise install a checked cdr.
;; Final membership checks that same Type, not an unrelated fallback descriptor.
(def (validate-type-value descriptor candidate)
  (validate-container descriptor candidate
    (lambda (source)
      (def carried-type (car source))
      (validate Type carried-type)
      (def original (cdr source))
      (def checked (validate carried-type original))
      (if (eq? original checked) source (cons carried-type checked)))))
