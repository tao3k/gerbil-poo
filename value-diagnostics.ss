;;; Type diagnostics below the MOP bootstrap, shared by Class and containers.
(export diagnose-value diagnose-structure)
(import (only-in ./object .o .slot? .get .call))

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
  (if (.slot? descriptor '.diagnose-shape)
    ((.get descriptor .diagnose-shape) candidate location diagnose-structure)
    (diagnose-value descriptor candidate location)))
