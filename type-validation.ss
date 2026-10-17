;;; Shared structural traversal and persistent validation for existing Types.
(export list-shape tuple-shape validate-container validate-list validate-tuple)
(import (only-in :std/list/list-builder with-list-builder) :std/iter
        (only-in :std/list/list map-in-order)
        (only-in :std/vector/vector vector-for-each/index)
        ./value-diagnostics
        (only-in ./object .o .slot? .get)
        (only-in ./mop element? validate raise-type-error))

;; Shape/arity refusal precedes child checks. Container indices are zero-based;
;; all child diagnostics remain ordered and no malformed list tail is traversed.
(def (list-shape descriptor type candidate location check-field)
  (if (list? candidate)
    (with-list-builder (issue!)
      (for ((value candidate) (index (in-range (length candidate))))
        (for-each issue! (check-field type value (append location [index])))))
    [(.o kind: 'expected-list path: location expected: descriptor)]))

;; Tuple fields have heterogeneous Types and exact vector arity. No child is
;; demanded when the carrier or arity is wrong, including an empty tuple.
(def (tuple-shape descriptor types candidate location check-field)
  (cond
    ((not (vector? candidate)) [(.o kind: 'expected-tuple path: location expected: descriptor)])
    ((not (= (vector-length types) (vector-length candidate)))
     [(.o kind: 'tuple-arity path: location expected: (vector-length types))])
    (else
     (with-list-builder (issue!)
       (vector-for-each/index
         (lambda (index value)
           (for-each issue! (check-field (vector-ref types index) value
                                        (append location [index])))) candidate)))))

;; Run a complete structural pass before normalization; final membership checks
;; the returned container. Custom validator/getter effects are not rolled back.
(def (validate-container descriptor candidate normalize)
  (def failures (diagnose-structure descriptor candidate '()))
  (unless (null? failures) (raise-type-error descriptor candidate failures))
  (let (checked (normalize candidate))
    (unless (element? descriptor checked) (raise-type-error descriptor checked))
    checked))

;; Reuse the standard left-to-right map for child validation. Unchanged elements
;; preserve the original list identity; a changed batch returns only its full list.
(def (validate-list descriptor type candidate)
  (validate-container descriptor candidate
    (lambda (source)
      (def checked (map-in-order (cut validate type <>) source))
      (if (andmap eq? source checked) source checked))))

;; Normalize into a private vector in index order; never mutate the source. No
;; partial vector escapes on failure. The original identity survives no changes.
(def (validate-tuple descriptor types candidate)
  (validate-container descriptor candidate
    (lambda (source)
      (def checked (make-vector (vector-length source)))
      (def changed? #f)
      (vector-for-each/index
        (lambda (index value)
          (def normalized (validate (vector-ref types index) value))
          (unless (eq? value normalized) (set! changed? #t))
          (vector-set! checked index normalized)) source)
      (if changed? checked source))))
