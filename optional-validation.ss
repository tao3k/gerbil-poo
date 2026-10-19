;;; Existing Maybe/OrFalse sentinels and dependent TypeValuePair validation.
(export optional-shape validate-optional type-value-shape validate-type-value type-value-catalog)
(import (only-in ./object .o .cc .ref)
        ./slot-observation ./value-diagnostics
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

;; Restrict the existing dependent carrier, not a second pair validator. Record
;; actual descriptor reads through the existing observation protocol: edits to
;; inherited sources also make replay refuse. Catalog tags use eq? identities;
;; an unlisted Type cannot run a payload callback by forging public metadata.
(def (type-value-catalog base types syntax)
  (unless (and (list? types) (<= (length types) 64)) (error "invalid finite Type catalog"))
  ;; Capture membership before Type admission can run a caller-defined getter.
  (def captured (map identity types))
  (validate Type base)
  (for-each (cut validate Type <>) captured)
  ;; Reissuing ordinary reads also exposes every captured source to enclosing
  ;; observers, including catalog members not selected by this payload.
  (def (read-catalog)
    (for-each (lambda (type) (.ref type '.element?)) captured)
    (.ref base '.validate))
  (defvalues (_ reads) (%call-with-recorded-slot-reads read-catalog))
  ;; Replay refuses old sources before getters; final replay also rejects edits
  ;; made by an enclosing observer. This never caches a successful approval.
  (def (current!)
    (replay-slot-reads! reads void)
    (read-catalog)
    (replay-slot-reads! reads void))
  ;; Retain malformed carrier/invalid Type diagnostics before catalog membership;
  ;; the ordinary dependent checker alone owns selected payload traversal.
  (def (shape value location check-field)
    (current!)
    (def result (if (and (pair? value) (element? Type (car value)) (not (memq (car value) captured)))
      [(.o kind: 'type-outside-catalog path: (append location '(car)) expected: descriptor)]
      (type-value-shape descriptor value location check-field)))
    (current!)
    result)
  (def descriptor (.cc base sexp: syntax
    .element?: (lambda (value)
      (current!)
      (def accepted (and (pair? value) (memq (car value) captured) (element? (car value) (cdr value)) #t))
      (current!)
      accepted)
    .diagnose: (lambda (value location) (shape value location diagnose-value))
    .diagnose-shape: (lambda (value location (check-field diagnose-structure))
                       (shape value location check-field))))
  descriptor)
