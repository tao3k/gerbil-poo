;;; Explicit bounded Self/Super polymorphism through existing FUN and contracts.
(export invoke-signature-service invoke-report-service SignatureServiceType
        signature-service-declarations instantiate-signature-service infer-signature-service signature-service-action convert conversion-declarations instantiate-conversion infer-conversion conversion-action FunctionPrototypeType Service ServiceType service-action publish-service)
(import ../object ../mop ../prototype-types ../object-contract ../object-contract-flow
        (prefix-in ../declarative-metadata metadata.) ../method-declaration
        (prefix-in ../generalized-prototype observation.)
        (prefix-in ../multimethod dispatch.) (prefix-in ../dispatch-extension extension.)
        (prefix-in ../method-combination combination.))

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

;; One statically bound generic keeps Gerbil formal binding and both result/cache
;; values; its method slot was installed only after complete type specialization.
(.defgeneric (convert service value) slot: .convert combination: invoke-declared)
;; Turn the checked instance's ground Function into the existing typed dispatcher.
;; Multiple fragments share one signature; inherited operations still read the
;; specialized Self/Super fields. The preparer is the established standard policy.
(def (conversion-declarations record instance)
  (def certified (instance-signature instance (lambda (_) [['Number]])
    [(extension.shape [['Blocked]])] standard-combination combination.standard-contribution?
    (lambda (methods) (combination.prepare-standard methods (lambda (_) (error "missing conversion"))))))
  (def path [(dispatch.prototype 'Number)])
  (def operation (.get instance prototype operation))
  [(typed-method-fragment '.convert certified
     [(metadata.replace "convert" path (combination.primary (lambda (_ value) (record 'primary) (operation value))))])
   (typed-method-fragment '.convert certified
     [(metadata.contribute "audit" path (combination.before (lambda (_) (record 'before))))
      (metadata.contribute "observe" path (combination.after (lambda (_) (record 'after))))])])
;; Explicit ground substitution and declaration installation use the same entry.
;; The builder is a normal higher-order callback, not a second declaration DSL.
(def (instantiate-conversion schema arguments record)
  (instantiate-declared schema arguments (cut conversion-declarations record <>)))
;; A ground prefix leaves a checked residual schema; exhaustive inference of the
;; remaining parameters must be uniquely complete before any builder is invoked.
(def (infer-conversion schema prefix candidates queries record (budget 8192))
  (infer-declared (specialize-prototype-type schema prefix budget) candidates queries
    (cut conversion-declarations record <>) budget))
;; FUN sequences current approval, the installed generic and the IO consumer.
;; A rejected context or bad argument has no method/consumer effects; successful
;; invocation retains the complete cache successor as the second returned value.
(def (conversion-action instance value consume)
  (.call observation.Observation. .bind
    (lambda (context)
      (unless (eq? (.get context approved) #t) (error "conversion approval refused"))
      (.get instance prototype))
    (lambda (receiver) (lambda (_context)
      (defvalues (answer next) (convert receiver value))
      (consume answer)
      (values answer next)))))

;; The same rank-one schema now has optional/rest/keyword input positions and two
;; outputs, one itself a checked callback. Literal keyword names are not variables.
(def SignatureServiceType
  (prototype-type (.o .parameters: '(Self Super)) '(Self Super)
    '(Function (Self (Function (Self) (Super))) (Super)
       optional: (Super) keywords: ((scale: . UInt)) required-keywords: () rest: Super)
    '((Self Super))))
;; Rest-only generic forwarding leaves optional defaults in the target procedure.
;; Returned user values precede the complete immutable declaration/cache successor.
(.defgeneric (invoke-signature-service service . arguments) slot: .invoke combination: invoke-declared)
;; Core optional/keyword binding resolves these defaults before constructing the
;; declared argument row; the method then receives each supplied value once.
(.defgeneric (invoke-report-service service value (bonus 0) scale: (scale 1) . rest)
  slot: .invoke combination: invoke-declared)
;; A whole qualified declaration group shares one inferred signature and existing
;; standard preparer. No method executes until a shape/type-checked call succeeds.
(def (signature-service-declarations instance procedure record)
  (def certified (instance-signature instance (lambda (_) [['Service]]) []
    standard-combination combination.standard-contribution?
    (lambda (methods) (combination.prepare-standard methods (lambda (_) (error "missing service"))))
    8192 1))
  (def path [(dispatch.prototype 'Service)])
  [(typed-method-fragment '.invoke certified
    [(metadata.replace "service" path
       (combination.primary (lambda (_next . arguments) (apply procedure arguments))))
     (metadata.contribute "audit-before" path (combination.before (lambda _ (record 'before))))
     (metadata.contribute "audit-after" path (combination.after (lambda _ (record 'after))))
     (metadata.contribute "audit-around" path
       (combination.around (lambda (next . _arguments) (record 'around) (next))))])])
;; Explicit complete binding uses the same declaration stream as residual inference.
(def (instantiate-signature-service schema arguments procedure (record void))
  (instantiate-declared schema arguments (cut signature-service-declarations <> procedure record)))
;; Specialize an ordered prefix, then exhaust the finite residual candidate set;
;; ambiguous/failed inference cannot call the builder or install a partial generic.
(def (infer-signature-service schema prefix candidates queries procedure (record void))
  (infer-declared (specialize-prototype-type schema prefix) candidates queries
    (cut signature-service-declarations <> procedure record)))
;; FUN supplies current approval; IO consumes both checked user outputs once. A
;; rejected call transfers neither partial outputs nor a cache successor to IO.
(def (signature-service-action instance arguments consume)
  (.call observation.Observation. .bind
    (lambda (context)
      (unless (eq? (.get context approved) #t) (error "signature service approval refused"))
      (.get instance prototype))
    (lambda (receiver) (lambda (_context)
      (defvalues (answer callback next) (apply invoke-signature-service receiver arguments))
      (consume answer callback)
      (values answer callback next)))))
