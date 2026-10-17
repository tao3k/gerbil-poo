;;; Recursive Class validation through its current effective Slot protocols.
(export class-diagnostics class-shape class-slot-shape class-slot-validate validate-class)
(import (only-in :std/list/list append-map filter-map)
        (only-in ./object .o .slot? .get .ref .call .all-slots object? object<-alist)
        (only-in ./value-diagnostics diagnose-structure diagnose-value))

;; A standard Slot checks required/optional presence and constants before its
;; declared child Type. Missing optional fields never demand their child Type.
;; Custom Slot classes may override this method along with their validator.
(def (class-slot-shape slot name candidate location check-field)
  (def field-path (append location (list name)))
  (cond
    ((not (.slot? candidate name))
     (if (.get slot optional) '() [(.o kind: 'missing-field path: field-path)]))
    (else
     (def value (.ref candidate name))
     (cond
       ((and (.slot? slot 'constant) (not (equal? (.get slot constant) value)))
        [(.o kind: 'constant-mismatch path: field-path)])
       ((.slot? slot 'type) (check-field (.get slot type) value field-path))
       (else '())))))

;; Only present fields reach this method; Class owns optional absence handling.
;; Delegate actual normalization to the declared Type, preserving custom errors.
(def (class-slot-validate slot name candidate)
  (def original (.ref candidate name))
  (if (.slot? slot 'type) (.call (.get slot type) .validate original) original))

;; Inspect only inventory names for sealed extras; do not force unknown values.
;; Each effective Slot dispatches through its own metaclass's shape method.
(def (class-shape descriptor candidate location check-field)
  (if (not (object? candidate)) [(.o kind: 'expected-object path: location)]
    (let* ((slots (.get descriptor effective-slots)) (names (.all-slots slots)))
      (append
        (if (.get descriptor sealed)
          (filter-map (lambda (name) (and (not (memq name names))
                         (.o kind: 'unknown-field path: (append location (list name)))))
                      (.all-slots candidate)) '())
        (append-map (lambda (name)
                      (def slot (.ref slots name))
                      (.call (.get slot .type) .slot.shape slot name candidate location check-field)) names)))))

;; Full diagnostics retain custom Class membership and Slot checker refusals.
;; Structural traversal alone remains available for wrapping nested refinements.
(def (class-diagnostics descriptor candidate location)
  (def failures (class-shape descriptor candidate location diagnose-value))
  (cond ((pair? failures) failures)
        ((.call descriptor .element? candidate) '())
        (else [(.o kind: 'class-rejected path: location)])))

;; Complete shape admission precedes every Slot validator. Build one persistent
;; replacement only after the whole batch succeeds, inheriting original ancestry.
;; Final current membership retains custom Slot checks and constant constraints.
(def (validate-class descriptor candidate refuse)
  (def shape (diagnose-structure descriptor candidate '()))
  (unless (null? shape) (refuse descriptor candidate shape))
  (def slots (.get descriptor effective-slots))
  (def updates
    (append-map (lambda (name)
                  (if (.slot? candidate name)
                    (let* ((slot (.ref slots name))
                           (original (.ref candidate name))
                           (checked (.call (.get slot .type) .slot.validate slot name candidate)))
                      (if (eq? original checked) '() (list (cons name checked)))) '()))
                (.all-slots slots)))
  (def checked (if (null? updates) candidate (object<-alist updates supers: (list candidate))))
  (unless (.call descriptor .element? checked) (refuse descriptor checked 'class-rejected))
  checked)
