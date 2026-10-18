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
      (check-exception (instance-signature (.cc forged expression: '(CaseFunction))
        (lambda (_) [['Number]]) []) (refusal 'malformed))
      (check-exception (instance-signature forged (lambda (_) [['Number]]) []
        standard-combination combination.standard-contribution? #f 1) (refusal 'exhausted))
      (def certified (instance-signature forged (lambda (_) [['Number]]) []))
      (def installed (extension.snapshot (declared-snapshot
        (.get (object<-declaration-forms MethodDeclaration. (.o)
          [(typed-method-fragment '.test certified [(metadata.replace "bad" [(dispatch.prototype 'Number)]
            (combination.primary (lambda (_ __) -1)))])]) .test))))
      (check-exception (dispatch.call installed 1) TypeError?))
    (test-case "rich Function variance retains exact structural call language"
      (check (subtype-expression?
        '(Function (UInt) (Integer) optional: (Integer) keywords: ((scale: . Integer)) rest: Integer)
        '(Function (Integer) (UInt) optional: (UInt) keywords: ((scale: . UInt)) rest: UInt)) => #t)
      (check (subtype-expression?
        '(CaseFunction (Function (UInt) (Integer)) (Function () ()))
        '(CaseFunction (Function (Integer) (UInt)) (Function () ()))) => #t)
      (check (subtype-expression? '(Function (UInt) (Integer) optional: () rest: #f)
        '(Function (Integer) (UInt))) => #t)
      (check (subtype-expression? '(Function (UInt) (Integer) rest: Integer)
        '(Function (Integer) (UInt))) => #f)
      (check (subtype-expression?
        '(CaseFunction (Function (UInt) (UInt)) (Function (Integer) (Integer Integer)))
        '(CaseFunction (Function (Integer) (Integer Integer)) (Function (UInt) (UInt)))) => #f)
      (check-exception (expression-type '(Function () () optional: () optional: (UInt))) (refusal 'malformed))
      (check-exception (expression-type '(Function () () keywords: ((x: . UInt)) required-keywords: (y:))) (refusal 'malformed))
      (check-exception (expression-type '(CaseFunction (CaseFunction (Function () ())))) (refusal 'malformed))
      (check-exception (expression-type '(Function () () effect: IO)) (refusal 'malformed)))
    (test-case "specialization traverses optional keyword rest and ordered case Types"
      (def schema (prototype-type (.o .parameters: '(Self Super)) '(Self Super)
        '(CaseFunction
           (Function (Self (Function (Self) (Super))) (Super)
             optional: (Super) keywords: ((Self: . Self)) required-keywords: (Self:) rest: Super)
           (Function () ())) '((Self Super))))
      (def partial (specialize-prototype-type schema '(UInt)))
      (def instance (instantiate-prototype partial '(Integer)))
      (check-equal? (.get instance expression)
        '(CaseFunction
           (Function (UInt (Function (UInt) (Integer))) (Integer)
             optional: (Integer) keywords: ((Self: . UInt)) required-keywords: (Self:) rest: Integer)
           (Function () ())))
      (check-exception (instantiate-prototype partial '(Bool)) (refusal 'bounds)))
    (test-case "inferred rich declaration reaches generic qualifiers nested outputs and IO"
      (def events [])
      (def consumed [])
      ;; The host owns optional defaults; the finite type schema does not execute it.
      (def (report value (bonus 0) scale: (scale 1) . rest)
        (values (* scale (abs (+ value bonus (apply + rest)))) abs))
      (def result (service.infer-signature-service service.SignatureServiceType '(UInt)
        '(UInt Integer) '((Integer Super)) report (lambda (event) (set! events (cons event events)))))
      (check-equal? (.get result status) 'unique)
      (check-equal? events [])
      (def instance (.get result instance))
      (def action (service.signature-service-action instance [-4 1 scale: 2 -3]
        (lambda (answer callback) (set! consumed (list answer (callback -9))))))
      (check-exception (action (.o approved: #f)) Error?)
      (check-equal? events [])
      (defvalues (answer callback next) (action (.o approved: #t)))
      (check-equal? answer 12)
      (check-equal? consumed '(12 9))
      (check-equal? (reverse events) '(around before after))
      (check-equal? (callback -8) 8)
      (check-exception (callback #f) TypeError?)
      (check-equal? (dispatch.effective-cache-size (extension.snapshot (declared-snapshot next))) 1)
      (defvalues (again _callback owner) (invoke-declared next [-5]))
      (check-equal? again 5)
      (check (eq? next owner) => #t)
      (check-exception (invoke-declared owner [-2 scale: #f]) TypeError?))
    (test-case "omitted defaults execute only in their host binding site"
      (def defaults 0)
      ;; This callback counts target default evaluation separately from dispatch.
      (def (report value (bonus (begin (set! defaults (+ defaults 1)) 3)) scale: (scale 1) . rest)
        (values (abs (* scale (+ value bonus (apply + rest)))) abs))
      (def instance (service.instantiate-signature-service service.SignatureServiceType '(UInt Integer) report))
      (def receiver (.get instance prototype))
      (check-equal? defaults 0)
      (defvalues (direct _callback _) (service.invoke-signature-service receiver -7))
      (check-equal? direct 4)
      (check-equal? defaults 1)
      (defvalues (bound _callback2 _owner) (service.invoke-report-service receiver -7))
      (check-equal? bound 7)
      (check-equal? defaults 1)
      (check-exception (service.invoke-signature-service receiver -7 #f) TypeError?)
      (check-equal? defaults 1))
    (test-case "one effective cache serves distinct case arities and result counts"
      (def schema (prototype-type (.o .parameters: []) []
        '(CaseFunction (Function (UInt UInt) (UInt)) (Function (Integer) (Integer Integer))) []))
      (def instance (service.instantiate-signature-service schema []
        (case-lambda ((value) (values value (+ value 1))) ((a b) (+ a b)))))
      (def group (.get instance prototype .invoke))
      (defvalues (one two next) (invoke-declared group [4]))
      (check-equal? (list one two) '(4 5))
      (defvalues (sum owner) (invoke-declared next [-2 8]))
      (check-equal? sum 6)
      (check (eq? next owner) => #t)
      (check-exception (invoke-declared owner [-1]) TypeError?)
      (check-exception (invoke-declared owner [1 2 3]) TypeError?))
    (test-case "first shape type or result refusal never falls through"
      (def bodies 0)
      (def schema (prototype-type (.o .parameters: []) []
        '(CaseFunction (Function (UInt) (UInt)) (Function (Integer) (Integer))) []))
      ;; A selected bad result is a failure after one body, not a second overload.
      (def (body value) (set! bodies (+ bodies 1)) (- value))
      (def instance (service.instantiate-signature-service schema [] body))
      (def group (.get instance prototype .invoke))
      (check-exception (invoke-declared group [-1]) TypeError?)
      (check-equal? bodies 0)
      (check-exception (invoke-declared group [1]) TypeError?)
      (check-equal? bodies 1)
      (check-equal? (dispatch.cache-size (extension.snapshot (declared-snapshot group))) 0))
    (test-case "zero outputs retain only owner and wrong counts refuse before IO"
      (def calls 0)
      (def schema (prototype-type (.o .parameters: []) [] '(Function () () rest: Integer) []))
      ;; Side effects are not rolled back; zero user values is distinct from false.
      (def (zero . arguments) (set! calls (+ calls 1))
        (if (null? arguments) (values) #f))
      (def instance (service.instantiate-signature-service schema [] zero))
      (def group (.get instance prototype .invoke))
      (def owner (invoke-declared group []))
      (check (eq? owner (invoke-declared owner [])) => #t)
      (check-exception (invoke-declared owner [1]) TypeError?)
      (check-equal? calls 3))
    (test-case "required unknown duplicate and escaped keyword rows preserve failure phases"
      (def calls 0)
      (def schema (prototype-type (.o .parameters: []) []
        '(Function (Any) (Any) keywords: ((scale: . UInt)) required-keywords: (scale:)) []))
      ;; Core keyword dispatch sees the escaped positional keyword as data.
      (def (body value scale: scale) (set! calls (+ calls 1)) value)
      (def instance (service.instantiate-signature-service schema [] body))
      (def receiver (.get instance prototype))
      (check-exception (service.invoke-signature-service receiver 1) TypeError?)
      (check-exception (service.invoke-signature-service receiver 1 scale: 2 scale: 3) TypeError?)
      (check-exception (service.invoke-signature-service receiver 1 other: 3) TypeError?)
      (check-exception (service.invoke-signature-service receiver 1 scale:) TypeError?)
      (check-equal? calls 0)
      (defvalues (value _) (service.invoke-signature-service receiver scale: 2 #!rest payload:))
      (check-equal? value payload:)
      (check-equal? calls 1))
    (test-case "rich calls keep exact target errors and retry the unchanged owner"
      (def cause (list 'target-error))
      (def failing? #t)
      ;; Raised source identity propagates without classification or cache success.
      (def (body value (extra 0))
        (if failing? (raise cause) (values value extra)))
      (def schema (prototype-type (.o .parameters: []) [] '(Function (UInt UInt) (UInt) optional: (UInt)) []))
      (def instance (service.instantiate-signature-service schema [] body))
      (def group (.get instance prototype .invoke))
      (check (eq? (caught (cut invoke-declared group [1])) cause) => #t)
      (check-equal? (dispatch.cache-size (extension.snapshot (declared-snapshot group))) 0)
      (set! failing? #f)
      (defvalues (a b _) (invoke-declared group [2]))
      (check-equal? (list a b) '(2 0)))
    (test-case "single-output declarations check exact count with the same Type refusal"
      (def schema (prototype-type (.o .parameters: []) [] '(Function (UInt) (UInt)) []))
      (def instance (service.instantiate-signature-service schema [] (lambda (value) (values value value))))
      (check-exception (service.invoke-signature-service (.get instance prototype) 1) TypeError?))
    (test-case "rich negative call watches reject publication before any body"
      (def bodies 0)
      (def schema (prototype-type (.o .parameters: []) []
        '(Function (UInt UInt) (UInt) keywords: ((scale: . UInt))) []))
      (def instance (instantiate-prototype schema []))
      (def seed (instance-signature instance (lambda (_) [['Service]]) [(extension.call 1 scale: 2)]))
      (defvalues (unchanged failure) (extension.publish seed
        [(extension.register [(dispatch.prototype 'Service)]
          (combination.primary (lambda (_ . args) (set! bodies (+ bodies 1)) (values 1 2))))]))
      (check (eq? unchanged seed) => #t)
      (check-equal? (extension.failure-stage failure) 'negative)
      (check-equal? bodies 0))
    (test-case "prepared and uncached complete combinations preserve all user values"
      (def descriptor (expression-type '(Function (UInt UInt) (UInt) optional: (UInt))))
      (def effects [])
      ;; The same callback is used by both qualified implementations; the oracle
      ;; reselects and prepares rather than reusing the effective cache under test.
      (def primary (combination.primary (lambda (_ x (y 0)) (values x y))))
      (def before (combination.before (lambda _ (set! effects (cons 'before effects)))))
      (def after (combination.after (lambda _ (set! effects (cons 'after effects)))))
      (def seed (dispatch.make-function descriptor (lambda (_) [['Service]])
        standard-combination 1 combination.standard-contribution?))
      (def path [(dispatch.prototype 'Service)])
      (def edited (dispatch.contribute (dispatch.contribute (dispatch.register seed path primary) path before) path after))
      (def prepared (dispatch.prepared edited
        (lambda (methods) (combination.prepare-standard methods (lambda (_) (error "missing"))))))
      (defvalues (plain _) (dispatch.call edited 3 4))
      (defvalues (compiled owner) (dispatch.call prepared 3 4))
      (check-equal? plain '(3 4))
      (check-equal? compiled plain)
      (check-equal? (dispatch.reference-call owner 3 4) plain)
      (check-equal? (reverse effects) '(before after before after before after))
      ;; Explicit-context preparation must pack values as well, keeping the bound
      ;; context separate from both the user row and the invocation cache owner.
      (def contextual (dispatch.prepared-context edited
        (lambda (_methods) (lambda (context args) (values (+ context (car args)) 0))) UInt 7))
      (defvalues (bound next) (dispatch.call contextual 2))
      (check-equal? bound '(9 0))
      (check-equal? (dispatch.reference-call next 2) bound))
    (test-case "forwarding and inner continuation chains preserve multiple values"
      (def parts [(combination.forward-primary (lambda (_next _dispatch payload) (values payload (+ payload 1))))
                  (combination.forward-after (lambda _ (void)))])
      (check-equal? (call/values (lambda ()
        (combination.forward-effective parts [1 4] (lambda (_) (error "missing")) identity)) list) '(4 5))
      (def compiled (combination.prepare-forwarding parts (lambda (_) (error "missing")) identity))
      (check-equal? (call/values (cut compiled [1 4]) list) '(4 5))
      (check-equal? (call/values (lambda ()
        (combination.inner-chain [(lambda (inner . _) (inner))] []
          (lambda (_) (values #f 7)))) list) '(#f 7)))
    (test-case "specialized higher-order optional keyword and rest inputs keep wrappers"
      (def schema (prototype-type (.o .parameters: '(Callback)) '(Callback)
        '(Function (Callback) (Callback) optional: (Callback)
          keywords: ((fallback: . Callback)) rest: Callback) []))
      (def calls 0)
      ;; Methods receive normalized callback arguments, never their unchecked
      ;; sources. Rest callback failure occurs inside the body and stops outputs.
      (def (body callback (other callback) fallback: (fallback other) . rest)
        (set! calls (+ calls 1))
        (for-each (lambda (f) (f -3)) rest)
        fallback)
      (def instance (service.instantiate-signature-service schema '((Function (UInt) (Integer))) body))
      (def receiver (.get instance prototype))
      (defvalues (callback owner) (service.invoke-signature-service receiver abs abs fallback: abs abs))
      (check-equal? (callback -5) 5)
      (check-exception (callback #f) TypeError?)
      (check-exception (invoke-declared owner [#f]) TypeError?)
      (check-equal? calls 1)
      (check-exception (invoke-declared owner [abs abs (lambda (_) #f)]) TypeError?)
      (check-equal? calls 2))
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
