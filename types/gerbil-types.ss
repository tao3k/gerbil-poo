;;; Bidirectional bridge between POO Type descriptors and Gerbil v0.19 native types.
;;; Preserves 100% open POO semantics while letting compiled `defstruct final: #t`,
;;; `defclass`, and `interface` descriptors participate as first-class POO Types.

(define-type (ClassType. @ Type. class-type)
  .gerbil-type: class-type
  final?: (class-type-final? class-type)
  slots: (class-type-slot-list class-type)
  .element?: (lambda (x) (class-instance? class-type x))
  .validate: (lambda (x) (if (class-instance? class-type x) x (raise-type-error @ x)))
  .diagnose-shape: (lambda (x location (_check-field diagnose-structure))
                     (if (class-instance? class-type x)
                       '()
                       [(.o kind: 'class-type-mismatch path: location expected: class-type)]))
  .diagnose: (lambda (x location)
               (if (class-instance? class-type x)
                 '()
                 [(.o kind: 'class-type-mismatch path: location expected: class-type)])))

(def (ClassType type-descriptor (sexp #f))
  (using (type-descriptor :~ class-type?)
    (def label (or sexp `(ClassType ,(class-type-id type-descriptor))))
    {(:: @ ClassType.) class-type: type-descriptor sexp: label}))

(define-type (InterfaceType. @ Type. interface-descriptor)
  .gerbil-type: interface-descriptor
  wrapper-type: (interface-descriptor-type interface-descriptor)
  methods: (map cadr (interface-descriptor-methods interface-descriptor))
  .element?: (lambda (x) (satisfies? interface-descriptor x))
  .validate: (lambda (x) (if (satisfies? interface-descriptor x) x (raise-type-error @ x)))
  .diagnose-shape: (lambda (x location (_check-field diagnose-structure))
                     (if (satisfies? interface-descriptor x)
                       '()
                       [(.o kind: 'interface-mismatch path: location expected: interface-descriptor)]))
  .diagnose: (lambda (x location)
               (if (satisfies? interface-descriptor x)
                 '()
                 [(.o kind: 'interface-mismatch path: location expected: interface-descriptor)])))

(def (InterfaceType descriptor (sexp #f))
  (using (descriptor :~ interface-descriptor?)
    (def label (or sexp `(InterfaceType ,(class-type-id (interface-descriptor-type descriptor)))))
    {(:: @ InterfaceType.) interface-descriptor: descriptor sexp: label}))

;; Project a POO Type descriptor to its underlying Gerbil v0.19 native type descriptor,
;; or #f when the Type is purely structural / custom without a native carrier.
(def (type-gerbil-descriptor type)
  (and (object? type)
       (.slot? type '.gerbil-type)
       (.ref type '.gerbil-type)))

;; Project any POO Type (Record, Class, ObjectContract, Sum, Nullable, ClassType, ...)
;; into a predicate suitable for Gerbil v0.19 `:~` contracts (e.g. `(x :~ (type-predicate T))`).
(def (type-predicate type)
  (validate Type type)
  (cut element? type <>))

;; Project any POO Type into a boundary normalizer/validator procedure.
(def (type-contract-validator type)
  (validate Type type)
  (cut validate type <>))
