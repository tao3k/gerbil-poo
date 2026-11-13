;;; Recursive Class validation through its current effective Slot protocols.
(export class-diagnostics class-shape class-slot-shape class-slot-validate class-validation-fields validate-class
        with-present-slot required-slots?)
(import (only-in :std/list/list filter-map)
        (only-in ./object .o .slot? .get .ref .call .all-slots object?)
        (only-in ./slot-observation %slot-read-active?)
        (only-in ./validation-rebinding rebind-validation finish-validation)
        (only-in ./value-diagnostics diagnose-structure diagnose-value))

(extern namespace: clan/poo/object %prepared-slot-present?)

;; Query POO's prepared method table. Cold and bootstrap receivers, observed
;; checks and unknown table adapters use the ordinary reflective path.
(def (%prepared-local-slot? receiver key)
  (and (symbol? key)
       (not (%slot-read-active?))
       (%prepared-slot-present? receiver key)))

;; Default Slot membership and fixed field contracts share ordinary POO reads.
;; Prepared local presence can use the existing Slot index when unobserved.
(defrule (with-present-slot (value candidate name) present absent)
  (let ((receiver candidate) (key name))
    (if (or (%prepared-local-slot? receiver key) (.slot? receiver key))
      (let (value (.ref receiver key)) present)
      absent)))

;; Keep declaration order, short-circuit, and return a Boolean like andmap.
(defrule (required-slots? candidate (name predicate) ...)
  (let (receiver candidate)
    (and (with-present-slot (value receiver 'name) (predicate value) #f) ... #t)))

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
;; The inherited raw value is explicit so custom validators can read other checked
;; receiver fields without recursively demanding their own active field.
(def (class-slot-validate slot _name original _receiver)
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
        ;; Keep append-map's callback order and final fold, but allocate its
        ;; immutable group spine only for non-empty results. A mutable builder
        ;; would share that spine across captured continuation re-entry.
        (let collect ((remaining names) (groups '()))
          (if (pair? remaining)
            (let* ((name (car remaining))
                   (rest (cdr remaining))
                   (slot (.ref slots name))
                   (group (.call (.get slot .type) .slot.shape slot name candidate location check-field)))
              (collect rest (if (null? group) groups (cons group groups))))
            (foldl (lambda (group result) (foldl cons result group)) remaining groups)))))))

;; Full diagnostics retain custom Class membership and Slot checker refusals.
;; Structural traversal alone remains available for wrapping nested refinements.
(def (class-diagnostics descriptor candidate location)
  (def failures (class-shape descriptor candidate location diagnose-value))
  (cond ((pair? failures) failures)
        ((.call descriptor .element? candidate) '())
        (else [(.o kind: 'class-rejected path: location)])))

;; Expose receiver-bound checks for ordinary validation and finite graph closure.
;; Only present effective fields participate; optional absence remains untouched.
(def (class-validation-fields descriptor candidate)
  (def slots (.get descriptor effective-slots))
  (filter-map (lambda (name)
                (and (.slot? candidate name)
                  (let (slot (.ref slots name))
                    (cons name (lambda (original receiver)
                      (.call (.get slot .type) .slot.validate slot name original receiver))))))
              (.all-slots slots)))

;; Complete shape admission precedes receiver-bound Slot normalization. All
;; checks finish before final membership; computed dependencies use the rebound
;; receiver and ordinary inherited specification/override/cache semantics.
(def (validate-class descriptor candidate refuse)
  (def shape (diagnose-structure descriptor candidate '()))
  (unless (null? shape) (refuse descriptor candidate shape))
  (let* ((checks (class-validation-fields descriptor candidate))
         (checked (rebind-validation candidate checks)))
    (finish-validation (lambda ()
      (unless (.call descriptor .element? checked) (refuse descriptor checked 'class-rejected))))
    checked))
