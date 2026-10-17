;;; Receiver-bound recursive validation through ordinary computed Slot composition.
(export prepare-rebinding force-rebinding rebind-validation
        finish-validation with-deferred-validation)
(import (only-in :std/list/list any)
        (only-in ./object make-object object-override-specifications $computed-slot-spec .ref))

;; A dynamically scoped obligation collector belongs to one closure attempt.
;; No pending object or accepted-value memo is retained globally.
(def pending-obligations (make-parameter #f))

;; Ordinary validation checks immediately. Within finite graph normalization,
;; queue this built-in whole-value obligation until every node batch finishes.
(def (finish-validation check)
  (def collect (pending-obligations))
  (if collect (collect check) (check)))

;; The scope never returns before all deferred checks succeed. Nested graph
;; attempts own separate collectors. Failures unwind without running a partly
;; built queue; custom Type effects and retained receivers do not roll back.
(def (with-deferred-validation action)
  (let (checks '())
      (def result (parameterize ((pending-obligations
                                  (lambda (check) (set! checks (cons check checks))))) (action)))
      (for-each (lambda (check) (check)) (reverse checks))
      result))

;; Allocate one private receiver without forcing validators or inherited getters.
;; Each field receives its inherited raw result and the same final receiver; no
;; old computed cache is copied. Explicit instance assignments remain values.
(def (prepare-rebinding candidate checks)
  (make-object supers: (list candidate)
    slots: (append (object-override-specifications candidate)
      (map (lambda (entry)
             (cons (car entry) ($computed-slot-spec
               (lambda (receiver inherited) ((cdr entry) (inherited) receiver))))) checks))))

;; Force every selected field before admission. A graph can allocate all receiver
;; identities first, then use this same cache/cycle protocol for every node.
(def (force-rebinding checked checks)
  (for-each (lambda (entry) (.ref checked (car entry))) checks)
  checked)

;; Dependencies observe checked siblings through inherited computed formulas.
;; Preserve unchanged ordinary validation identity after the complete batch.
;; Ordinary lexical captures cannot be rebound; callback effects do not roll back.
(def (rebind-validation candidate checks)
  (if (null? checks) candidate
    (let (checked (force-rebinding (prepare-rebinding candidate checks) checks))
      (if (any (lambda (entry)
                 (not (eq? (.ref checked (car entry)) (.ref candidate (car entry))))) checks)
        checked candidate))))
