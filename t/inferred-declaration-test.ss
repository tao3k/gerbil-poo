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
;; Build the full named interface for admission controls. Optional certificate
;; overrides exercise provenance failures without executing either method body.
(def (shared-forms instance (report #f) (recover #f))
  ;; Catalog paths are explicit fields in the existing Object Type expression.
  (def (signature path)
    (instance-signature instance (lambda (_) [['Service]]) []
      standard-combination combination.standard-contribution? #f 8192 1 path))
  (def path [(dispatch.prototype 'Service)])
  [(typed-method-fragment '.report (or report (signature '(.report)))
     [(metadata.replace "report" path (combination.primary (lambda _ (values 1 abs))))])
   (typed-method-fragment '.recover (or recover (signature '(.recover)))
     [(metadata.replace "recover" path (combination.primary (lambda (_next . args) (apply values args))))])])
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
    (test-case "rich Function variance covers supplied call languages and ordered cases"
      (check (subtype-expression?
        '(Function (UInt) (Integer) optional: (Integer) keywords: ((scale: . Integer)) rest: Integer)
        '(Function (Integer) (UInt) optional: (UInt) keywords: ((scale: . UInt)) rest: UInt)) => #t)
      (check (subtype-expression?
        '(CaseFunction (Function (UInt) (Integer)) (Function () ()))
        '(CaseFunction (Function (Integer) (UInt)) (Function () ()))) => #t)
      (check (subtype-expression? '(Function (UInt) (Integer) optional: () rest: #f)
        '(Function (Integer) (UInt))) => #t)
      (check (subtype-expression? '(Function (UInt) (Integer) rest: Integer)
        '(Function (Integer) (UInt))) => #t)
      (check (subtype-expression?
        '(CaseFunction (Function (UInt) (UInt)) (Function (Integer) (Integer Integer)))
        '(CaseFunction (Function (Integer) (Integer Integer)) (Function (UInt) (UInt)))) => #t)
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
    (test-case "joint named call inference installs one shared fully checked receiver"
      (def events [])
      (def builds 0)
      ;; Report preserves rich argument binding and returns a recursively checked callback.
      (def (report value (extra 0) scale: (scale 1) . rest)
        (values (* scale (abs (+ value extra (apply + rest)))) abs))
      ;; The host case-lambda implements the same source-ordered shapes as the catalog.
      (def recover (case-lambda ((value) (+ 100 value)) ((a b) (values (+ 100 a) (+ 100 b)))))
      ;; No method is called while the complete named receiver is being installed.
      (def (build instance)
        (set! builds (+ builds 1))
        (service.shared-service-declarations instance report recover
          (lambda (event) (set! events (cons event events)))))
      (def observations
        '(((.report) (Integer Integer scale: UInt Integer) (UInt (Function (UInt) (Integer))))
          ((.recover) (UInt UInt) (Integer Integer))))
      (def inferred (infer-declared-calls service.SharedServiceType '(UInt Integer) observations build))
      (check-equal? (.get inferred status) 'unique)
      (check-equal? (.get inferred solutions) '((UInt Integer)))
      (check-equal? (.get inferred calls) observations)
      (check (and (member '(Self UInt) (.get inferred queries)) #t) => #t)
      (check (and (member '(Integer Super) (.get inferred queries)) #t) => #t)
      (check-equal? builds 1)
      (check-equal? events [])
      (def instance (.get inferred instance))
      (check-equal? (bound-parameters instance) '(Self Super))
      (check-equal? (.get instance prototype service-name) 'shared)
      (def consumed [])
      (def action (service.shared-service-action instance -4
        (lambda (answer recovered callback) (set! consumed (list answer recovered (callback -7))))))
      (check-exception (action (.o approved: #f)) Error?)
      (check-equal? events [])
      (defvalues (answer recovered report-owner recovery-owner) (action (.o approved: #t)))
      (check-equal? consumed '(6 106 7))
      (check-equal? (reverse events) '(report recover))
      (check-equal? (list answer recovered) '(6 106))
      (defvalues (a b warm) (invoke-declared recovery-owner [2 3]))
      (check-equal? (list a b) '(102 103))
      (check (eq? warm recovery-owner) => #t)
      (defvalues (a2 callback warm2) (invoke-declared report-owner [-5]))
      (check-equal? a2 5)
      (check-equal? (callback -6) 6)
      (check (eq? warm2 report-owner) => #t))
    (test-case "result-directed constraints bind variables on the subtype source side"
      (def schema (prototype-type (.o .parameters: '(Result)) '(Result) '(Function (Result) ()) []))
      (def plain (infer-prototype schema '(UInt Integer) '((Result UInt))))
      (check-equal? (.get plain solutions) '((UInt)))
      (def inferred (infer-declared-calls schema '(UInt Integer) '((() () (UInt)))
        (cut service.signature-service-declarations <> (lambda () 3) void)))
      (check-equal? (.get inferred solutions) '((UInt)))
      (defvalues (answer _) (service.invoke-signature-service (.get inferred instance prototype)))
      (check-equal? answer 3))
    (test-case "partial specialization and joint call inference retain original bounds"
      (def partial (specialize-prototype-type service.SharedServiceType '(UInt)))
      (def result (infer-prototype-calls partial '(UInt Integer)
        '(((.report) (Integer) (UInt (Function (UInt) (Integer)))))))
      (check-equal? (.get result solutions) '((Integer)))
      (check-equal? (bound-parameters (.get result instance)) '(Self Super))
      (check (eq? (.get result instance prototype Self) UInt) => #t)
      (check (eq? (.get result instance prototype Super) Integer) => #t))
    (test-case "optional keyword and rest inputs all constrain the same finite assignment"
      (def schema (prototype-type (.o .parameters: '(Input Result)) '(Input Result)
        '(Function (Result) (Input) optional: (Input)
          keywords: ((gate: . Result)) required-keywords: (gate:) rest: Input) []))
      (def good (infer-prototype-calls schema '(UInt Integer)
        '((() (Integer Integer gate: UInt Integer) (UInt)))))
      (check-equal? (.get good solutions) '((Integer UInt)))
      (for-each (lambda (arguments)
        (check-equal? (.get (infer-prototype-calls schema '(UInt Integer)
          (list (list [] arguments '(UInt)))) status) 'no-solution))
        '((Integer Bool gate: UInt) (Integer gate: Bool) (Integer Integer gate: UInt Bool)))
      (check-exception (infer-prototype-calls schema '(UInt Integer) '((() (Integer) (UInt)))) (refusal 'bounds))
      (check-exception (infer-prototype-calls schema '(UInt Integer)
        '((() (Integer gate: UInt gate: UInt) (UInt)))) (refusal 'malformed))
      (check-exception (infer-prototype-calls schema '(UInt Integer)
        '((() (Integer other: UInt) (UInt)))) (refusal 'bounds)))
    (test-case "ordered call inference never falls through after first-shape type failure"
      (def schema (prototype-type (.o .parameters: '(Result)) '(Result)
        '(CaseFunction (Function (Result) (UInt)) (Function (Result) (Integer))
                       (Function (Result) (Integer Integer))) []))
      (def refused (infer-declared-calls schema '(UInt Integer) '((() (Integer) (UInt))) forbidden-builder))
      (check-equal? (.get refused status) 'no-solution)
      (check-equal? (.get refused instance) #f)
      (def selected (infer-prototype-calls schema '(UInt Integer) '((() (Integer Integer) (UInt)))))
      (check-equal? (.get selected solutions) '((UInt))))
    (test-case "individually admissible named calls may have no joint solution"
      (def first '((.report) (Integer) (UInt (Function (UInt) (Integer)))))
      (def second '((.recover) (UInt) (UInt)))
      (check-equal? (.get (infer-prototype-calls service.SharedServiceType '(UInt Integer) [first]) solutions)
        '((UInt Integer)))
      (check-equal? (.get (infer-prototype-calls service.SharedServiceType '(UInt Integer) [second]) solutions)
        '((UInt UInt)))
      (def joint (infer-declared-calls service.SharedServiceType '(UInt Integer) [first second] forbidden-builder))
      (check-equal? (.get joint status) 'no-solution)
      (check-equal? (.get joint instance) #f))
    (test-case "absent return obligations differ from explicit zero outputs"
      (def schema (prototype-type (.o .parameters: '(Result)) '(Result) '(Function (Result) ()) []))
      (def ambiguous (infer-declared-calls schema '(UInt Integer) '((() () #f)) forbidden-builder))
      (check-equal? (.get ambiguous status) 'ambiguous)
      (check-equal? (.get ambiguous instance) #f)
      (check-exception (infer-prototype-calls schema '(UInt Integer) '((() () ()))) (refusal 'bounds))
      (def zero (prototype-type (.o .parameters: []) [] '(Function () ()) []))
      (def unique (infer-declared-calls zero [] '((() () ()))
        (cut service.signature-service-declarations <> (lambda () (values)) void)))
      (check-equal? (.get unique solutions) '(()))
      (def owner (service.invoke-signature-service (.get unique instance prototype)))
      (check-equal? (dispatch.cache-size (extension.snapshot (declared-snapshot owner))) 1))
    (test-case "nested explicit signature paths reuse Object fields rather than a new catalog grammar"
      (def schema (prototype-type (.o .parameters: '(Result)) '(Result)
        '(Object ((api (Object ((run (Function (Result) (Integer)))) closed))) closed) []))
      ;; The builder installs the nested Object carrier at the exact catalog path;
      ;; full publication checks its group as well as top-level typed fields.
      (def (build instance)
        (def certified (instance-signature instance (lambda (_) [['Value]]) []
          standard-combination combination.standard-contribution? #f 8192 1 '(api run)))
        (def api (object<-declaration-forms MethodDeclaration. instance
          [(typed-method-fragment 'run certified
            [(metadata.replace "run" [(dispatch.prototype 'Value)] (combination.primary (lambda (_ x) (abs x))))])]))
        [(declaration-form 'public 'api (.o (constant api)))])
      (def result (infer-declared-calls schema '(UInt Integer) '(((api run) (Integer) (UInt))) build))
      (defvalues (answer _) (invoke-declared (.get result instance prototype api run) [-9]))
      (check-equal? answer 9)
      (check-exception (infer-prototype-calls schema '(UInt Integer) '(((api missing) (Integer) (UInt)))) (refusal 'unsupported)))
    (test-case "invalid observations refuse before building; concrete candidate signatures resolve"
      (check-exception (infer-declared-calls service.SharedServiceType '(UInt Integer)
        '(((.report) (Integer))) forbidden-builder) (refusal 'malformed))
      (check-exception (infer-declared-calls service.SharedServiceType '(UInt Integer)
        '((.report (Integer) #f)) forbidden-builder) (refusal 'malformed))
      (check-exception (infer-declared-calls service.SharedServiceType '(UInt Integer)
        '(((.report) (Unknown) #f)) forbidden-builder) (refusal 'unsupported))
      (check-exception (infer-declared-calls service.SharedServiceType '(UInt Integer)
        '(((.report) (Integer) (UInt))) forbidden-builder) (refusal 'bounds))
      (def schema (prototype-type (.o .parameters: '(Signature)) '(Signature) 'Signature []))
      (check-equal? (.get (infer-prototype-calls schema '((Function (UInt) (UInt)))
        '((() (UInt) (UInt)))) status) 'unique))
    (test-case "unique joint inference refuses a forbidden sibling without exposing an instance"
      (def bodies 0)
      ;; First group is valid; the second fails completed negative admission.
      ;; Arbitrary builder effects are not rolled back, but no receiver is returned.
      (def (build instance)
        (def report-signature (instance-signature instance (lambda (_) [['Service]]) []
          standard-combination combination.standard-contribution? #f 8192 1 '(.report)))
        (def recovery-signature (instance-signature instance (lambda (_) [['Service]]) [(extension.shape [['Blocked]])]
          standard-combination combination.standard-contribution? #f 8192 1 '(.recover)))
        [(typed-method-fragment '.report report-signature
          [(metadata.replace "valid" [(dispatch.prototype 'Service)] (combination.primary (lambda _ (set! bodies (+ bodies 1)) (values 1 abs))))])
         (typed-method-fragment '.recover recovery-signature
          [(metadata.replace "forbidden" [(dispatch.prototype 'Blocked)] (combination.primary (lambda _ (set! bodies (+ bodies 1)) 1)))])])
      (def issue (caught (cut infer-declared-calls service.SharedServiceType '(UInt Integer)
        '(((.report) (Integer) (UInt (Function (UInt) (Integer))))) build)))
      (check (extension.failure? issue) => #t)
      (check-equal? (extension.failure-stage issue) 'negative)
      (check-equal? bodies 0)
      (def retry (service.infer-shared-service '(UInt) '(UInt Integer)
        '(((.report) (Integer) (UInt (Function (UInt) (Integer)))))
        (lambda (n (extra 0) scale: (scale 1) . rest) (values (abs n) abs)) (lambda (n) n)))
      (check-equal? (.get retry status) 'unique))
    (test-case "call inference retains builder causes and bounded exhaustive refusal"
      (def cause (list 'builder-refused))
      ;; A complete unique search reaches one ordinary builder; its cause survives.
      (def (build _) (raise cause))
      (def observations '(((.report) (Integer) (UInt (Function (UInt) (Integer))))))
      (check (eq? (caught (cut infer-declared-calls service.SharedServiceType '(UInt Integer) observations build)) cause) => #t)
      (check-exception (infer-declared-calls service.SharedServiceType '(UInt Integer) observations forbidden-builder 1)
        (refusal 'exhausted))
      (def partial (specialize-prototype-type service.SharedServiceType '(UInt)))
      (.setslot! (.get partial prototype) Self ($constant-slot-spec Bool))
      (check-exception (infer-declared-calls partial '(Integer) observations forbidden-builder) (refusal 'bounds)))
    (test-case "call diagnostics retain the captured request after builder-side list changes"
      (def schema (prototype-type (.o .parameters: '(Result)) '(Result) '(Function (Result) (Integer)) []))
      (def observations (list (list [] (list 'Integer) (list 'UInt))))
      ;; Request capture precedes the builder. Mutating the caller-owned input
      ;; afterwards cannot change the chosen assignment or its diagnostic query.
      (def (build instance)
        (set-car! (cadr (car observations)) 'Bool)
        (service.signature-service-declarations instance abs void))
      (def report (infer-declared-calls schema '(UInt Integer) observations build))
      (check-equal? (.get report calls) '((() (Integer) (UInt))))
      (check-equal? (.get report queries) '((Integer Integer) (Result UInt)))
      (check-equal? (.get report solutions) '((UInt)))
      (defvalues (answer _) (service.invoke-signature-service (.get report instance prototype) -4))
      (check-equal? answer 4))
    (test-case "catalog completeness includes unobserved required siblings"
      ;; A unique call solution is not sufficient when the builder omits recover.
      (def (build instance) (list (car (shared-forms instance))))
      (check-exception (infer-declared-calls service.SharedServiceType '(UInt Integer)
        '(((.report) (Integer) (UInt (Function (UInt) (Integer))))) build) (refusal 'bounds)))
    (test-case "catalog methods cannot be replaced by unchecked procedures or wrong paths"
      ;; A plain callable is not the completed typed group promised by the catalog.
      (def (plain instance)
        (list (declaration-form 'public '.report (.o (constant (lambda _ (values 1 abs)))))
              (cadr (shared-forms instance))))
      (check-exception (instantiate-declared service.SharedServiceType '(UInt Integer) plain) (refusal 'bounds))
      ;; Even an otherwise valid typed certificate names a different field/case set.
      (def (wrong instance)
        (def signature (instance-signature instance (lambda (_) [['Service]]) []
          standard-combination combination.standard-contribution? #f 8192 1 '(.recover)))
        (shared-forms instance signature signature))
      (check-exception (instantiate-declared service.SharedServiceType '(UInt Integer) wrong) (refusal 'bounds)))
    (test-case "catalog admission rejects descriptor revision and copied source stamps"
      ;; Direct supported metadata changes cannot reuse a factory's earlier stamp.
      (def (revised instance)
        (def signature (instance-signature instance (lambda (_) [['Service]]) []
          standard-combination combination.standard-contribution? #f 8192 1 '(.report)))
        (def descriptor (dispatch.function-signature (extension.snapshot signature)))
        (.setslot! descriptor outputs ($constant-slot-spec [Any]))
        (shared-forms instance signature))
      (check-exception (instantiate-declared service.SharedServiceType '(UInt Integer) revised) (refusal 'bounds))
      ;; Extensible public Type metadata can be copied, but its private origin still
      ;; names the original exact descriptor. No global weak registry is necessary.
      (def (copied instance)
        (def signature (instance-signature instance (lambda (_) [['Service]]) []
          standard-combination combination.standard-contribution? #f 8192 1 '(.report)))
        (def descriptor (dispatch.function-signature (extension.snapshot signature)))
        (def forged (.cc descriptor outputs: [Any]))
        (def replacement (extension.check
          (dispatch.make-function forged (lambda (_) [['Service]]) standard-combination 1 combination.standard-contribution?) []))
        (shared-forms instance replacement))
      (check-exception (instantiate-declared service.SharedServiceType '(UInt Integer) copied) (refusal 'bounds)))
    (test-case "a signature from another ground assignment cannot close the new catalog"
      (def old (instantiate-prototype service.SharedServiceType '(UInt Integer)))
      (def previous (instance-signature old (lambda (_) [['Service]]) []
        standard-combination combination.standard-contribution? #f 8192 1 '(.report)))
      ;; Matching field names do not justify borrowing a different substituted Type.
      (def (build instance) (shared-forms instance previous))
      (check-exception (instantiate-declared service.SharedServiceType '(UInt UInt) build) (refusal 'bounds)))
    (test-case "inherited complete catalog groups retain their exact admitted source"
      (def original (instantiate-declared service.SharedServiceType '(UInt Integer) shared-forms))
      (def source (.cc (.get original prototype) .parameters: []))
      (def schema (prototype-type source [] (.get original expression) []))
      (def inherited (instantiate-declared schema [] (lambda (_) [])))
      (defvalues (one two _) (service.recover-service (.get inherited prototype) 2 3))
      (check-equal? (list one two) '(2 3))
      (check-equal? (.get inherited prototype service-name) 'shared))
    (test-case "catalog admission does not force unrelated declared data fields"
      (def demanded 0)
      (def schema (prototype-type (.o .parameters: []) []
        '(Object ((.run (Function (UInt) (Integer))) (unused Integer)) closed) []))
      ;; The callable catalog and ordinary data contracts retain separate demand;
      ;; unused is not certified as Integer merely by publishing this method group.
      (def (build instance)
        (def signature (instance-signature instance (lambda (_) [['Value]]) []
          standard-combination combination.standard-contribution? #f 8192 1 '(.run)))
        [(typed-method-fragment '.run signature
           [(metadata.replace "run" [(dispatch.prototype 'Value)] (combination.primary (lambda (_ n) (abs n))))])
         (declaration-form 'public 'unused (.o
           (compute (lambda (_self _super) (set! demanded (+ demanded 1)) (error "not demanded")))))])
      (def result (instantiate-declared schema [] build))
      (check-equal? demanded 0)
      (defvalues (answer _) (invoke-declared (.get result prototype .run) [-3]))
      (check-equal? answer 3)
      (check-equal? demanded 0))
    (test-case "cyclic observation data refuses under the existing depth budget"
      (def cycle (list [] [] #f))
      (set-cdr! cycle cycle)
      (check-exception (infer-declared-calls service.SharedServiceType '(UInt Integer) [cycle] forbidden-builder)
        (refusal 'exhausted)))
    (test-case "builder mutation of inferred syntax or bound snapshots refuses publication"
      (def schema (prototype-type (.o .parameters: '(Result)) '(Result) '(Function (Result) (Integer)) []))
      ;; Source getters are extensible, but changing the returned mutable AST
      ;; cannot silently turn the already inferred contract into a different one.
      (def (changed-expression instance)
        (set-car! (cadr (.get instance expression)) 'Integer)
        (service.signature-service-declarations instance abs void))
      (check-exception (infer-declared-calls schema '(UInt Integer) '((() (Integer) (UInt))) changed-expression)
        (refusal 'bounds))
      ;; The pre-builder frame includes every bound name; removing a snapshot
      ;; cannot authorize overriding an already specialized parameter field.
      (def (dropped-bindings instance)
        (set-cdr! (.get instance bound-parameters) [])
        [(declaration-form 'public 'Super (.o (constant Bool)))])
      (check-exception (instantiate-declared service.SharedServiceType '(UInt Integer) dropped-bindings)
        (refusal 'bounds)))
    (test-case "published factory groups reject directly revised descriptors before invocation"
      (def descriptor #f)
      (def bodies 0)
      (def schema (prototype-type (.o .parameters: []) [] '(Function (UInt) (UInt)) []))
      ;; The published group retains its own immutable factory source stamp.
      (def (build instance)
        (def signature (instance-signature instance (lambda (_) [['Value]]) []))
        (set! descriptor (dispatch.function-signature (extension.snapshot signature)))
        [(typed-method-fragment '.invoke signature
          [(metadata.replace "run" [(dispatch.prototype 'Value)]
            (combination.primary (lambda (_ n) (set! bodies (+ bodies 1)) n)))])])
      (def instance (instantiate-declared schema [] build))
      (def group (.get instance prototype .invoke))
      (.setslot! descriptor audit ($constant-slot-spec 'changed))
      (check-exception (invoke-declared group [1]) (refusal 'bounds))
      (check-exception (declared-snapshot group) (refusal 'bounds))
      (check-equal? bodies 0))
    (test-case "descriptor changes during a successful body discard its values and owner"
      (def descriptor #f)
      (def changed? #f)
      (def bodies 0)
      (def schema (prototype-type (.o .parameters: []) [] '(Function (UInt) (UInt)) []))
      ;; The first body deliberately changes its signature metadata. Effects stay,
      ;; but no user result/cache successor may escape; retry rebuilds a fresh source.
      (def (build instance)
        (def signature (instance-signature instance (lambda (_) [['Value]]) []))
        (set! descriptor (dispatch.function-signature (extension.snapshot signature)))
        [(typed-method-fragment '.invoke signature
          [(metadata.replace "run" [(dispatch.prototype 'Value)]
            (combination.primary (lambda (_ n)
              (set! bodies (+ bodies 1))
              (unless changed? (set! changed? #t) (.setslot! descriptor audit ($constant-slot-spec 'changed)))
              n)))])])
      (def instance (instantiate-declared schema [] build))
      (def old (.get instance prototype .invoke))
      (check-exception (invoke-declared old [1]) (refusal 'bounds))
      (check-equal? bodies 1)
      (check-exception (invoke-declared old [1]) (refusal 'bounds))
      (def fresh (instantiate-declared schema [] build))
      (defvalues (answer _) (service.invoke-signature-service (.get fresh prototype) 2))
      (check-equal? answer 2)
      (check-equal? bodies 2))
    (test-case "anonymous Function declarations require their captured factory signature"
      (def schema (prototype-type (.o .parameters: '(Result)) '(Result) '(Function (Result) (Integer)) []))
      (check-exception (instantiate-declared schema '(UInt) (lambda (_) [])) (refusal 'bounds))
      ;; Changing a public AST only while compiling, then restoring it, still leaves
      ;; a mismatched private signature and cannot evade the root admission check.
      (def (build instance)
        (def outputs (cadr (.get instance expression)))
        (set-car! outputs 'Integer)
        (def forms (service.signature-service-declarations instance abs void))
        (set-car! outputs 'UInt)
        forms)
      (check-exception (instantiate-declared schema '(UInt) build) (refusal 'bounds)))
    (test-case "deferred edit compilation cannot revise a signature during cold snapshot admission"
      (def calls 0)
      (def schema (prototype-type (.o .parameters: []) [] '(Function (UInt) (UInt)) []))
      ;; Unlike an eager .cc argument, this .compile slot really executes only
      ;; when the completed certificate promise compiles its metadata edits.
      (def (build instance)
        (def signature (instance-signature instance (lambda (_) [['Value]]) []))
        (def descriptor (dispatch.function-signature (extension.snapshot signature)))
        (def declaration (.o inherit: [metadata.Declaration.] bind-these: #f name: "deferred-revision"
          (.compile (begin
            (set! calls (+ calls 1))
            (.setslot! descriptor audit ($constant-slot-spec 'revised-during-compilation))
            (extension.register [(dispatch.prototype 'Value)] (combination.primary (lambda (_ n) n)))))))
        [(typed-method-fragment '.invoke signature [declaration])])
      (check-exception (instantiate-declared schema [] build) (refusal 'bounds))
      (check-equal? calls 1))
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
    (test-case "guarded catalog retains hidden rich methods without demanding ordinary data"
      (def demanded 0)
      (def events [])
      ;; Hidden method metadata still participates in complete typed admission.
      (def (build instance)
        (cons (declaration-form 'public 'unused (.o
          (compute (lambda (_self _inherited) (set! demanded (+ demanded 1)) (error "unused")))))
          (map (lambda (form) (.cc form descriptor: (.cc (.get form descriptor) hidden: #t)))
            (service.signature-service-declarations instance
              (lambda (value (extra 0) scale: (scale 1) . rest)
                (values (abs (* scale (+ value extra (apply + rest)))) abs))
              (lambda (event) (set! events (cons event events)))))))
      (def instance (instantiate-declared service.SignatureServiceType '(UInt Integer) build))
      (check-equal? demanded 0)
      (defvalues (answer callback owner) (service.invoke-signature-service (.get instance prototype) -3 1 scale: 2 1))
      (check-equal? answer 2)
      (check-equal? (callback -4) 4)
      (check-exception (callback "bad") TypeError?)
      (check-equal? (reverse events) '(around before after))
      (check-equal? demanded 0))
    (test-case "deferred metadata edits refuse before guarded catalog invalidation and retry"
      (def schema (prototype-type (.o .parameters: []) [] '(Function (UInt) (UInt)) []))
      (def metadata #f)
      (def fail? #t)
      (def compiled 0)
      ;; The supported edit reaches the registered Slot and active receiver.
      (def edit (.o inherit: [metadata.Declaration.] bind-these: #f name: "catalog-edit"
        (.compile (begin (set! compiled (+ compiled 1))
          (when fail? (.setslot! metadata hidden ($constant-slot-spec #t)))
          (extension.register [(dispatch.prototype 'Value)]
            (combination.primary (lambda (_ n) n)))))))
      ;; A fresh construction retries the same failed declaration, not its approval.
      (def (build instance)
        (def signature (instance-signature instance (lambda (_) [['Value]]) []))
        (def form (typed-method-fragment '.invoke signature [edit]))
        (set! metadata (.get form descriptor))
        [form])
      (check-exception (instantiate-declared schema [] build)
        (lambda (cause) (and (Error? cause)
          (equal? (error-message cause) "object mutation during computation"))))
      (check-equal? compiled 1)
      (check-equal? (.get metadata hidden) #f)
      (check-equal? (object-revision metadata) 0)
      (set! fail? #f)
      (def instance (instantiate-declared schema [] build))
      (defvalues (answer owner) (service.invoke-signature-service (.get instance prototype) 7))
      (check-equal? answer 7)
      (check-equal? compiled 2))
    (test-case "private normalized literals cannot alias a builder's replaced AST subtree"
      (def schema (prototype-type (.o .parameters: []) [] '(Function ((UIntN 8)) ((UIntN 8))) []))
      (def detached #f)
      ;; Restoring equal public syntax must not leave a private normalized leaf
      ;; pointing at the detached, revised literal from before the replacement.
      (def (build instance)
        (def inputs (caddr (.get instance expression)))
        (set! detached (car inputs))
        (set-car! (cdr detached) 9)
        (set-car! inputs (list 'UIntN 8))
        (service.signature-service-declarations instance identity void))
      (def instance (instantiate-declared schema [] build))
      (check-equal? detached '(UIntN 9))
      (check-equal? (.get instance expression) '(Function ((UIntN 8)) ((UIntN 8))))
      (defvalues (answer owner) (service.invoke-signature-service (.get instance prototype) 255))
      (check-equal? answer 255)
      (check-exception (service.invoke-signature-service (.get instance prototype) 256) TypeError?))
    (test-case "construction guard rejects supported edits to the specialized source"
      ;; Guard the same receiver whose checked Type fields inform the declaration.
      (def (build instance)
        (.setslot! (.get instance prototype) Self ($constant-slot-spec Bool))
        [])
      (check-exception (instantiate-declared service.ServiceType '(UInt Integer) build) Error?)
      (check-equal? (parameters service.Service) '(Self Super)))))
