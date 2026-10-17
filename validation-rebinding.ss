;;; Receiver-bound recursive validation through ordinary computed Slot composition.
(export rebind-validation)
(import (only-in :std/list/list any)
        (only-in ./object make-object object-override-specifications $computed-slot-spec .ref))

;; Each check receives its inherited raw value and the final receiver. Inherited
;; computed specifications therefore read checked sibling fields through normal
;; dispatch, independent of declaration order. Force every declared check before
;; returning; failures return no partly admitted receiver. Existing object caches
;; share repeated dependencies and CyclicSlot guards active receiver/slot cycles.
;; Ordinary lexical captures cannot be rebound by this protocol.
(def (rebind-validation candidate checks)
  (if (null? checks) candidate
    (let (checked
           (make-object supers: (list candidate)
             slots: (append
                      (object-override-specifications candidate)
                      (map (lambda (entry)
                             (cons (car entry)
                               ($computed-slot-spec
                                 (lambda (receiver inherited)
                                   ((cdr entry) (inherited) receiver))))) checks))))
      (for-each (lambda (entry) (.ref checked (car entry))) checks)
      ;; Preserve unchanged identity only after the whole rebound batch succeeds.
      (if (any (lambda (entry)
                 (not (eq? (.ref checked (car entry)) (.ref candidate (car entry))))) checks)
        checked candidate))))
