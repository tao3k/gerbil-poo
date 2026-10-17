;;; Structural value contracts over the existing POO Type protocol.
;;; No configuration domain, module publication or admission context belongs here.
(export ObjectContract. TypeContract. diagnose as-value-contract refine)
(import ./contract-adapter (only-in :std/list/list foldl append-map filter-map)
        (only-in ./value-diagnostics diagnose-structure)
        ./object-diagnostics
        ./object-contract-validation
        (only-in ./object .o .cc .get .ref .slot? .all-slots object?
                 compute-precedence-list!)
        (only-in ./mop Type Type. define-type .defgeneric element? validate))

;; Return POO diagnostic values. An empty list means the value conforms.
;; Context-dependent admission and authorization are separate consumers.
(.defgeneric (diagnose constraint candidate (path '())) slot: .diagnose)

;; Adapt membership without inventing another Type. Validation delegates too:
;; Function Types must retain their existing input/output wrapper behavior.
(define-type (TypeContract. @ Type. expected-type)
  .element?: (cut element? expected-type <>)
  .validate: (cut validate expected-type <>)
  .diagnose-shape: (lambda (value location (check-field diagnose-structure))
                     (check-field expected-type value location))
  .diagnose:
  (lambda (value location)
    (if (element? expected-type value)
      '()
      (list (.o kind: 'type-rejected path: location expected: expected-type)))))

;; Keep an existing diagnostic Type unchanged; otherwise wrap its Type methods.
;; A malformed descriptor is a programming error, not an invalid user field.
(def (as-value-contract descriptor-value)
  (validate Type descriptor-value)
  (if (.slot? descriptor-value '.diagnose)
    (begin
      (unless (procedure? (.get descriptor-value .diagnose))
        (error "Type diagnostic method must be a procedure" descriptor-value))
      descriptor-value)
    (.cc TypeContract. 'expected-type descriptor-value)))

;; Construct a POO issue without retaining the candidate or introducing a registry.
(def (issue kind-value location)
  (.o kind: kind-value path: location))

;; Adapt required field Types once per effective descriptor, in slot order.
(def (prepare-responsibilities declared-fields)
  (unless (object? declared-fields)
    (error "Object responsibilities must be a POO object"))
  (foldl (lambda (name prepared-fields)
           (.cc prepared-fields name (as-value-contract (.ref declared-fields name))))
         (.o) (.all-slots declared-fields)))

;; Prepare whole-value Types without changing their diagnostic or validation methods.
(def (prepare-constraints declarations)
  (unless (list? declarations) (error "Object constraints must be a list of Types"))
  (map as-value-contract declarations))

;; Inspect names before unknown values. Only declared fields and explicit
;; constraints demand values; ancestry refusal never demands candidate fields.
(def (object-shape-issues descriptor-value value location check-field)
  (cond
    ((not (object? value)) (list (issue 'expected-object location)))
    ((let (prototype (.get descriptor-value required-prototype))
       (and prototype (not (memq prototype (compute-precedence-list! value)))))
     (list (issue 'prototype-mismatch location)))
    (else
     (let* ((fields (.get descriptor-value prepared-responsibilities))
            (names (.all-slots fields))
            (extra-errors
              (if (eq? (.get descriptor-value extra-fields) 'reject)
                (filter-map
                  (lambda (name)
                    (and (not (memq name names))
                         (issue 'unknown-field (append location (list name)))))
                  (.all-slots value))
                '()))
            (field-errors
              (append-map
                (lambda (name)
                  (let (field-path (append location (list name)))
                    (if (.slot? value name)
                      (checked-issues (check-field (.ref fields name) (.ref value name) field-path))
                      (list (issue 'missing-field field-path)))))
                names))
            (structural-errors (append extra-errors field-errors)))
       structural-errors))))

;; Responsibilities are required fields. Optional/default policy can instead be
;; owned by a Schema Type in constraints; it is not guessed from absent slots.
;; Prepared slots are lazy and receiver-local, so a derived descriptor prepares
;; its effective declarations even after the parent's map was already forced.
(define-type (ObjectContract. @ Type.
                            identity responsibilities required-prototype
                            extra-fields constraints obligations
                            prepared-responsibilities prepared-constraints prepared-obligations
                            prepared-validation .diagnose-shape .diagnose)
  identity: 'object
  responsibilities: (.o)
  required-prototype: #f
  extra-fields: 'reject
  constraints: '()
  obligations: (lambda (_value _path) '())
  prepared-responsibilities: (prepare-responsibilities responsibilities)
  prepared-constraints: (prepare-constraints constraints)
  prepared-validation: (prepare-validation prepared-responsibilities)
  ;; Finite recursive graph closure shares this exact effective field selection.
  .validation-fields: (lambda (_value) (validation-fields prepared-responsibilities))
  prepared-obligations:
  (diagnostic-then
    (diagnostic-all (map (lambda (constraint) (cut diagnose constraint <> <>)) prepared-constraints))
    obligations)
  .element?: (lambda (value) (null? (.diagnose value '())))
  .validate: (lambda (value) (validate-object @ value))
  .diagnose-shape:
  (lambda (value location (check-field diagnose))
    (unless (list? location) (error "Diagnostic path must be a list"))
    (unless (or (not required-prototype) (object? required-prototype))
      (error "Required prototype must be a POO object or false" identity))
    (unless (and (procedure? obligations)
                 (or (eq? extra-fields 'reject)
                     (and (eq? extra-fields 'delegate) (pair? prepared-constraints))))
      (error "Invalid object contract policy" identity))
    (object-shape-issues @ value location check-field))
  .diagnose:
  (lambda (value location)
    (def failures (.diagnose-shape value location))
    (if (pair? failures) failures (prepared-obligations value location))))

;; Strengthen the effective obligations without overriding the parent checks.
;; The inherited-computation syntax keeps the parent callback receiver-aware:
;; later descriptor derivation does not capture a previously prepared parent.
;; Existing refusals gate the added callback and retain their exact issue list.
(def (refine descriptor additional)
  (validate Type descriptor)
  ;; .cc copies metadata rather than adding nominal ancestry. Check the existing
  ;; structural descriptor protocol without forcing its prepared callbacks.
  (unless (andmap (cut .slot? descriptor <>)
            '(responsibilities required-prototype extra-fields constraints obligations
              prepared-responsibilities prepared-constraints prepared-obligations
              prepared-validation .diagnose-shape))
    (error "Refinement requires an ObjectContract descriptor"))
  (check-contract additional procedure? (lambda () (error "Refinement must be a diagnostic procedure")))
  (.o (:: @ descriptor)
    obligations: => (lambda (previous) (diagnostic-then previous additional))))
