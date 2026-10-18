(export inferred-declaration-test)
(import :std/test :std/error ../object ../mop ../number ../parameters ../prototype-types ../type-relation
        ../declaration ../method-declaration
        (prefix-in ../examples/polymorphic-services service.)
        (prefix-in ../multimethod dispatch.) (prefix-in ../dispatch-extension extension.)
        (prefix-in ../declarative-metadata metadata.) (prefix-in ../method-combination combination.))
;; Match typed refusal categories independently of prose or unrelated exceptions.
(def (refusal kind) (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) kind))))
;; Capture exact exception identity so source callback errors cannot masquerade as
;; no-solution, ambiguous inference or declaration registration failure.
(def (caught thunk) (try (thunk) #f (catch (cause) cause)))
;; Public inference/declaration entries must reject before executing this builder.
(def (forbidden-builder _) (error "builder must not run"))
;; Exercise the complete installed row instead of bypassing .defgeneric forwarding.
(def (invoke instance value)
  (service.convert (.get instance prototype) value))
;; These controls cover staging and failures as well as ordinary successful calls.
(def inferred-declaration-test
  (test-suite "inference positional specialization and one declaration protocol"
    (test-case "ground prefix produces a residual schema without forcing operations"
      (def calls 0)
      (def source (.o .parameters: '(Self Super)
        (operation (begin (set! calls (+ calls 1)) identity))))
      (def schema (prototype-type source '(Self Super) '(Function (Self) (Super)) '((Self Super))))
      (def partial (specialize-prototype-type schema '(UInt)))
      (check-equal? (.get partial variables) '(Super))
      (check-equal? (.get partial expression) '(Function (UInt) (Super)))
      (check-equal? (.get partial bounds) '((UInt Super)))
      (check (eq? (.get partial prototype Self) UInt) => #t)
      (check-equal? (parameters (.get partial prototype)) '(Super))
      (check-equal? (parameters source) '(Self Super))
      (check-equal? calls 0)
      (check (eq? (.get (specialize-prototype-type schema []) prototype) source) => #t))
    (test-case "prefix plus remaining binding agrees with direct complete instantiation"
      (def partial (specialize-prototype-type service.ServiceType '(UInt)))
      (def staged (instantiate-declared partial '(Integer) (cut service.conversion-declarations void <>)))
      (def direct (service.instantiate-conversion service.ServiceType '(UInt Integer) void))
      (check-equal? (.get staged expression) (.get direct expression))
      (check-equal? (parameters (.get staged prototype)) [])
      (defvalues (a _) (invoke staged -8))
      (defvalues (b __) (invoke direct -8))
      (check-equal? a 8)
      (check-equal? b 8)
      (check (eq? (.get staged prototype Self) UInt) => #t)
      (check (eq? (.get staged prototype Super) Integer) => #t))
    (test-case "complete type prefix leaves one empty assignment for inference"
      (def complete (specialize-prototype-type service.ServiceType '(UInt Integer)))
      (check-equal? (.get complete variables) [])
      (def report (infer-declared complete [] [] (cut service.conversion-declarations void <>)))
      (check-equal? (.get report status) 'unique)
      (check-equal? (.get report solutions) '(()))
      (defvalues (value _) (invoke (.get report instance) -5))
      (check-equal? value 5))
    (test-case "partial substitution preserves literal Object field labels"
      (def source (.o .parameters: '(Self Super)))
      (def schema (prototype-type source '(Self Super)
        '(Function ((Object ((Self Super)) closed)) (Self)) []))
      (def partial (specialize-prototype-type schema '(UInt)))
      (check-equal? (.get partial expression) '(Function ((Object ((Self Super)) closed)) (UInt)))
      (def instance (instantiate-prototype partial '(Bool)))
      (check-equal? (.get instance expression) '(Function ((Object ((Self Bool)) closed)) (UInt))))
    (test-case "higher-order inferred rows preserve recursive Function wrapping"
      ;; Function outputs are Types too: outer dispatch must preserve the nested
      ;; input/result wrappers, with exactly one ordinary Result/cache pair.
      (def (build instance)
        (def certified (instance-signature instance (lambda (_) [['Value] ['Value]]) []))
        [(typed-method-fragment '.higher certified
          [(metadata.replace "return-first" [(dispatch.prototype 'Value) (dispatch.prototype 'Value)]
            (combination.primary (lambda (_ first _second) first)))])])
      (def instance (instantiate-declared service.FunctionPrototypeType
        '((Function (UInt) (Integer)) (Function (Integer) (UInt))) build))
      (def group (.get instance prototype .higher))
      (defvalues (callback next) (invoke-declared group [abs identity]))
      (check-equal? (callback -6) 6)
      (check-exception (callback #f) TypeError?)
      (check-exception (invoke-declared next [#f identity]) TypeError?))
    (test-case "residual constraints remain obligations until complete specialization"
      (def partial (specialize-prototype-type service.ServiceType '(Integer)))
      (check-exception (instantiate-declared partial '(UInt) forbidden-builder) (refusal 'bounds))
      (check-exception (specialize-prototype-type service.ServiceType '(Integer UInt)) (refusal 'bounds))
      (check-exception (specialize-prototype-type service.ServiceType '(UInt Integer Bool)) (refusal 'malformed))
      (check-exception (specialize-prototype-type service.ServiceType '(Unknown)) (refusal 'unsupported))
      (check-exception (specialize-prototype-type service.ServiceType '(UInt) 1) (refusal 'exhausted)))
    (test-case "nonunique or incomplete inference never invokes declaration builders"
      (def builds 0)
      ;; Any unexpected builder call changes a separate receipt before failing.
      (def (build _) (set! builds (+ builds 1)) (error "unexpected build"))
      (def ambiguous (infer-declared service.ServiceType '(UInt Integer) [] build))
      (def none (infer-declared service.ServiceType '(UInt Integer) '((Bool Self)) build))
      (check-equal? (.get ambiguous status) 'ambiguous)
      (check-equal? (.get ambiguous instance) #f)
      (check-equal? (.get none status) 'no-solution)
      (check-equal? (.get none instance) #f)
      (check-exception (infer-declared service.ServiceType '(UInt Integer) [] build 1) (refusal 'exhausted))
      (check-exception (infer-declared service.ServiceType '(Unknown) [] build) (refusal 'unsupported))
      (check-equal? builds 0))
    (test-case "unique exhaustive inference installs once without calling methods"
      (def builds 0)
      (def events [])
      (def partial (specialize-prototype-type service.ServiceType '(UInt)))
      ;; The same ordinary builder supplies all fragments for the completed instance.
      (def (build instance)
        (set! builds (+ builds 1))
        (service.conversion-declarations (lambda (event) (set! events (cons event events))) instance))
      (def report (infer-declared partial '(UInt Integer Integer) '((Integer Super)) build))
      (check-equal? (.get report status) 'unique)
      (check-equal? (.get report solutions) '((Integer)))
      (check-equal? builds 1)
      (check-equal? events [])
      (defvalues (answer next) (invoke (.get report instance) -4))
      (check-equal? answer 4)
      (check-equal? (reverse events) '(before primary after))
      (check-equal? (dispatch.effective-cache-size (extension.snapshot (declared-snapshot next))) 1)
      (check-exception (invoke (.get report instance) #f) TypeError?)
      (check-equal? (length events) 3))
    (test-case "FUN current approval and IO preserve normalization and cache ownership"
      (def events [])
      (def consumed [])
      (def report (service.infer-conversion service.ServiceType '(UInt) '(UInt Integer) '((Integer Super))
        (lambda (event) (set! events (cons event events)))))
      (def action (service.conversion-action (.get report instance) -9
        (lambda (value) (set! consumed (cons value consumed)))))
      (check-exception (action (.o approved: #f)) Error?)
      (check-exception (action (.o approved: 'truthy)) Error?)
      (check-equal? events [])
      (check-equal? consumed [])
      (defvalues (answer next) (action (.o approved: #t)))
      (check-equal? answer 9)
      (check-equal? consumed '(9))
      (defvalues (again _) (invoke-declared next [-11]))
      (check-equal? again 11))
    (test-case "unique inference rejects a completed forbidden declaration before publishing"
      (def bodies 0)
      (def partial (specialize-prototype-type service.ServiceType '(UInt)))
      ;; A builder may construct a candidate, but cannot publish a forbidden method.
      (def (build instance)
        (def certified (instance-signature instance (lambda (_) [['Number]]) [(extension.shape [['Blocked]])]))
        [(typed-method-fragment '.convert certified
          [(metadata.replace "forbidden" [(dispatch.prototype 'Blocked)]
            (combination.primary (lambda (_ n) (set! bodies (+ bodies 1)) n)))])])
      (def issue (caught (cut infer-declared partial '(Integer) [] build)))
      (check (extension.failure? issue) => #t)
      (check-equal? (extension.failure-stage issue) 'negative)
      (check-equal? bodies 0)
      (def retry (infer-declared partial '(Integer) [] (cut service.conversion-declarations void <>)))
      (defvalues (answer _) (invoke (.get retry instance) -7))
      (check-equal? answer 7))
    (test-case "callback identity and malformed declarations refuse without partial reports"
      (def cause (list 'source-refused))
      ;; Source errors are neither classification results nor wrapped type errors.
      (def (build _) (raise cause))
      (check (eq? (caught (cut instantiate-declared service.ServiceType '(UInt Integer) build)) cause) => #t)
      (check-exception (instantiate-declared service.ServiceType '(UInt Integer) (lambda (_) #f)) Error?)
      (check-exception (instantiate-declared service.ServiceType '(UInt Integer) #f) true))
    (test-case "signature bridge recompiles ground syntax and refuses unsupported rows"
      (def instance (instantiate-prototype service.ServiceType '(UInt Integer)))
      ;; A forged permissive descriptor does not replace the actual checked syntax.
      (def forged (.cc instance descriptor: Any))
      (check-exception (instance-signature (.cc forged expression: 'Integer) (lambda (_) []) []) (refusal 'unsupported))
      (check-exception (instance-signature (.cc forged expression: '(Function (UInt Integer) (Integer)))
        (lambda (_) [['Number]]) []) (refusal 'unsupported))
      (check-exception (instance-signature forged (lambda (_) [['Number]]) []
        standard-combination combination.standard-contribution? #f 1) (refusal 'exhausted))
      (def certified (instance-signature forged (lambda (_) [['Number]]) []))
      (def installed (extension.snapshot (declared-snapshot
        (.get (object<-declaration-forms MethodDeclaration. (.o)
          [(typed-method-fragment '.test certified [(metadata.replace "bad" [(dispatch.prototype 'Number)]
            (combination.primary (lambda (_ __) -1)))])]) .test))))
      (check-exception (dispatch.call installed 1) TypeError?))
    (test-case "revised bound prefixes refuse before inference and can be restored"
      (def partial (specialize-prototype-type service.ServiceType '(UInt)))
      (def source (.get partial prototype))
      (.setslot! source Self ($constant-slot-spec Bool))
      (check-exception (infer-declared partial '(Integer) [] forbidden-builder) (refusal 'bounds))
      (.setslot! source Self ($constant-slot-spec UInt))
      (def retry (infer-declared partial '(Integer) [] (cut service.conversion-declarations void <>)))
      (defvalues (answer _) (invoke (.get retry instance) -3))
      (check-equal? answer 3))
    (test-case "same-identity Type descriptor revisions invalidate bound prefixes"
      (def partial (specialize-prototype-type service.ServiceType '((List UInt))))
      (def descriptor (.get partial prototype Self))
      (.setslot! descriptor audit-tag ($constant-slot-spec 'changed))
      (check-exception (infer-declared partial '(Any) [] forbidden-builder) (refusal 'bounds)))
    (test-case "installation cannot publish a descriptor revised by compile callbacks"
      ;; The final check catches changes after the pre-elaboration binding check.
      ;; This callback changes metadata only; no method body is invoked.
      (def (build instance)
        (def descriptor (.get instance prototype Self))
        (def certified (instance-signature instance (lambda (_) [['Value]]) []))
        (def declaration (.cc metadata.Declaration. name: "revise" .compile:
          (begin (.setslot! descriptor audit-tag ($constant-slot-spec 'changed))
            (extension.register [(dispatch.prototype 'Value)] (combination.primary (lambda (_ __) []))))))
        [(typed-method-fragment '.convert certified [declaration])])
      (check-exception (instantiate-declared service.ServiceType '((List UInt) Any) build) (refusal 'bounds)))
    (test-case "finalized declarations cannot overwrite already bound parameters"
      ;; Check finalized nonlocal entry names, not the pre-expansion form spelling.
      (def (replace-self _) [(declaration-form 'public 'Self (.o (constant Bool)))])
      (def (replace-arity _) [(declaration-form 'public '.parameters (.o (constant '(again))))])
      (check-exception (instantiate-declared service.ServiceType '(UInt Integer) replace-self) (refusal 'bounds))
      (check-exception (instantiate-declared service.ServiceType '(UInt Integer) replace-arity) (refusal 'bounds)))
    (test-case "typed installation leaves unrelated computed fields lazy"
      (def demanded 0)
      ;; Ordinary computed fields participate in the same declaration stream but
      ;; are not requested while forcing all typed groups before publication.
      (def (build instance)
        (cons (declaration-form 'public 'unused (.o
          (compute (lambda (_self _inherited) (set! demanded (+ demanded 1)) (error "unused")))))
          (service.conversion-declarations void instance)))
      (def instance (instantiate-declared service.ServiceType '(UInt Integer) build))
      (check-equal? demanded 0)
      (defvalues (answer _) (invoke instance -2))
      (check-equal? answer 2)
      (check-equal? demanded 0))
    (test-case "construction guard rejects supported edits to the specialized source"
      ;; Guard the same receiver whose checked Type fields inform the declaration.
      (def (build instance)
        (.setslot! (.get instance prototype) Self ($constant-slot-spec Bool))
        [])
      (check-exception (instantiate-declared service.ServiceType '(UInt Integer) build) Error?)
      (check-equal? (parameters service.Service) '(Self Super)))))
