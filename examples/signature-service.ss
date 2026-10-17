;;; Seeded service checks combine nested callbacks, optional and keyword defaults.
(export Callback ServiceSignature service checked-service service-property service-tests)
(import ../object ../mop ../type ../number ../function-testing ../property-testing)

;; Function values require explicit semantic generation: arbitrary native closures
;; cannot be synthesized from recognition alone. This fixture generates identity.
(def Callback
  (.o self: callback inherit: [(Function [Integer] [Integer])]
      .generator: (lambda () (make-generator callback
        (lambda (_random _size) identity) (lambda (_value) []) (lambda (_value) 0)
        dependencies: [Integer]))))
;; The container's callbacks acquire recursive wrappers before target execution.
(def ServiceSignature
  (Function [Integer] [Integer] optional: [(List Callback)]
            keywords: (list (cons scale: Integer) (cons offset: Integer))))
;; Omitted callbacks and keywords retain the host's ordinary default semantics.
(def (service value (callbacks []) scale: (scale 1) offset: (offset 0))
  (+ (* scale (foldl (lambda (callback result) (callback result)) value callbacks)) offset))
;; The same descriptor used for generated calls also checks actual invocations.
(def checked-service (validate ServiceSignature service))
;; Compare wrapped calls against the original at every generated supplied shape.
(def (service-property arguments)
  (= (apply checked-service arguments) (apply service arguments)))
;; One Reader/FUN chain runs the property and passes its report to an IO consumer.
(def (service-tests consume)
  (property-action (FunctionArguments ServiceSignature) service-property consume))
