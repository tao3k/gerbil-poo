;;; Type diagnostics below the MOP bootstrap, shared by Class and containers.
(export diagnose-value diagnose-structure)
(import (only-in ./object .o .slot? .get .call))

;; Active structural pairs are per-thread and per-call, not accepted memo entries.
;; Repeated sharing after return is legal; an unannotated active backedge refuses.
(def active-structure (make-parameter '()))

;; Invoke the same Type methods as the MOP generics, without importing their
;; bootstrap module. Recognition never installs a normalized candidate value.
(def (diagnose-value descriptor candidate location)
  (cond
    ((.slot? descriptor '.diagnose) ((.get descriptor .diagnose) candidate location))
    ((.call descriptor .element? candidate) '())
    (else [(.o kind: 'type-rejected path: location expected: descriptor)])))

;; Structural traversal defers whole-object obligations until child normalization;
;; custom Type errors and malformed descriptors retain their original behavior.
(def (diagnose-structure descriptor candidate location)
  (def active (active-structure))
  (if (ormap (lambda (entry) (and (eq? descriptor (car entry)) (eq? candidate (cdr entry)))) active)
    [(.o kind: 'recursive-structure path: location)]
    (parameterize ((active-structure (cons (cons descriptor candidate) active)))
      (if (.slot? descriptor '.diagnose-shape)
        ((.get descriptor .diagnose-shape) candidate location diagnose-structure)
        (diagnose-value descriptor candidate location)))))
