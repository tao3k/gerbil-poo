;;; Persistent field validation through the existing POO Type protocol.
(export prepare-validation validate-object)
(import (only-in ./value-diagnostics diagnose-structure)
        (only-in :std/list/list foldl)
        (only-in ./object .all-slots .ref .get object<-alist .slot?)
        (only-in ./mop validate raise-type-error))

;; Prepare field validators once per effective descriptor. Validate in declaration
;; order against the original candidate, then install changed fields in one copy.
;; No function body is called by Function.validate; its wrapper defers checks to
;; invocation. Custom validators/getters retain their ordinary effects/errors.
(def (prepare-validation fields)
  (def entries (map (lambda (name) (cons name (.ref fields name))) (.all-slots fields)))
  (lambda (candidate)
    (def replacements
      (foldl (lambda (entry reversed)
               (def original (.ref candidate (car entry)))
               (def checked (validate (cdr entry) original))
               (if (eq? original checked) reversed
                 (cons (cons (car entry) checked) reversed)))
             '() entries))
    (if (null? replacements) candidate (object<-alist (reverse replacements) supers: (list candidate)))))

;; Gate wrapping on structural success, then recheck the final checked object.
;; Constraints/refinements observe wrapped fields, never an intermediate copy.
;; Recognition stays separate: diagnose does not wrap or cache accepted values.
(def (validate-object descriptor candidate)
  (def shape (diagnose-structure descriptor candidate '()))
  (unless (null? shape) (raise-type-error descriptor candidate shape))
  (def checked ((.get descriptor prepared-validation) candidate))
  (def failures ((.get descriptor .diagnose) checked '()))
  (unless (null? failures) (raise-type-error descriptor checked failures))
  checked)
