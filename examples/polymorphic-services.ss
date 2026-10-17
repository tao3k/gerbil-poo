;;; Explicit bounded Self/Super polymorphism through existing FUN and contracts.
(export FunctionPrototypeType Service ServiceType service-action publish-service)
(import ../object ../mop ../prototype-types ../object-contract ../object-contract-flow
        (prefix-in ../declarative-metadata metadata.))

;; Ordinary prototype parameters remain Type descriptors. Computed inherited
;; methods bind to the specialized receiver, with no new metaclass or registry.
(def Service (.o self: receiver .parameters: '(Self Super)
  (operation (lambda (value) (validate (.get receiver Self) (abs (validate (.get receiver Super) value)))))))
;; Appendix Self <: Super bounds specialize to the existing Function constructor.
;; Inputs may be broader than the return type (e.g. Integer input, UInt output).
(def ServiceType
  (prototype-type Service '(Self Super) '(Function (Self) (Super)) '((Self Super))))

;; The appendix Proto A B has signature A <- A B with A <: B. Here A/B
;; themselves are Function descriptors; existing wrappers check both nested calls.
(def FunctionPrototype (.o .parameters: '(Self Super)
  (combine (lambda (_self super) (lambda (value) (abs (super (abs value))))))))
;; Universals are explicit outer prototype parameters; there is no impredicative
;; runtime inference and the prototype does not force a recursive self eagerly.
(def FunctionPrototypeType
  (prototype-type FunctionPrototype '(Self Super)
    '(Function (Self) (Self Super)) '((Self Super))))

;; Admit the inferred Function, recursively wrap it as a field, then add a whole
;; service obligation. The Reader/FUN consumer receives only the normalized value.
(def (service-action instance maximum consume)
  (let* ((signature (.get instance descriptor))
         (shape (.cc ObjectContract. responsibilities: (.o operation: signature limit: signature)))
         (contract (refine shape
           (lambda (value path)
             (if (<= ((.get value operation) -3) maximum) []
               (list (.o bind-these: #f kind: 'service-limit path: path)))))))
    (checked-action contract consume)))

;; Bind exact subject/signature/revision references before the existing publisher.
;; A stale identity fails logic and preserves old state; this function performs no
;; caching and creates no new approval authority.
(def (publish-service instance subject context evidence old-state)
  (let* ((invocation (metadata.contract
                      (metadata.predicate "subject" object?)
                      (metadata.predicate "evidence" object?)
                      (lambda (_atom _input _output) #t) metadata.truth))
         (bound (metadata.bind-evidence invocation subject (.get instance descriptor) context identity)))
    (metadata.publish bound old-state (lambda (_) (values evidence subject)) subject)))
