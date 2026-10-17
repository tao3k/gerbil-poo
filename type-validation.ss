;;; Shared structural traversal and persistent validation for existing Types.
(export diagnose-value diagnose-structure list-shape tuple-shape validate-container validate-list validate-tuple)
(import :std/iter
        (only-in :std/list/list map-in-order)
        (only-in :std/vector/vector vector-for-each/index)
        (only-in ./object .o .slot? .get)
        (only-in ./mop element? validate raise-type-error))

;; Dispatch ordinary diagnostics without wrapping a value. Leaf Types preserve
;; membership recognition; custom diagnostic exceptions propagate unchanged.
(def (diagnose-value descriptor candidate location)
  (cond
    ((.slot? descriptor '.diagnose) ((.get descriptor .diagnose) candidate location))
    ((element? descriptor candidate) '())
    (else [(.o kind: 'type-rejected path: location expected: descriptor)])))

;; Structural traversal skips whole-object obligations until recursive wrapping
;; finishes, including inside containers. Leaf Types retain ordinary diagnostics.
(def (diagnose-structure descriptor candidate location)
  (if (.slot? descriptor '.diagnose-shape)
    ((.get descriptor .diagnose-shape) candidate location diagnose-structure)
    (diagnose-value descriptor candidate location)))

;; Shape/arity refusal precedes child checks. Container indices are zero-based;
;; all child diagnostics remain ordered and no malformed list tail is traversed.
(def (list-shape descriptor type candidate location check-field)
  (if (list? candidate)
    (apply append
      (for/collect ((value candidate) (index (in-range (length candidate))))
        (check-field type value (append location [index]))))
    [(.o kind: 'expected-list path: location expected: descriptor)]))

;; Tuple fields have heterogeneous Types and exact vector arity. No child is
;; demanded when the carrier or arity is wrong, including an empty tuple.
(def (tuple-shape descriptor types candidate location check-field)
  (cond
    ((not (vector? candidate)) [(.o kind: 'expected-tuple path: location expected: descriptor)])
    ((not (= (vector-length types) (vector-length candidate)))
     [(.o kind: 'tuple-arity path: location expected: (vector-length types))])
    (else
     (apply append
       (for/collect ((index (in-range (vector-length types))))
         (check-field (vector-ref types index) (vector-ref candidate index)
                      (append location [index])))))))

;; Run a complete structural pass before normalization; final membership checks
;; the returned container. Custom validator/getter effects are not rolled back.
(def (validate-container descriptor candidate normalize)
  (def failures (diagnose-structure descriptor candidate '()))
  (unless (null? failures) (raise-type-error descriptor candidate failures))
  (def checked (normalize candidate))
  (unless (element? descriptor checked) (raise-type-error descriptor checked))
  checked)

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
