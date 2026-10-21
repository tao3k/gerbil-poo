;;; Candidate-dependent catalogs reuse the existing call and declaration protocol.
(export candidate-inference-test)
(import :std/test :std/error ../object ../mop ../prototype-types ../type-relation
        (only-in ../type-syntax map-type-children)
        ../declaration
        (only-in ../slot-observation call-with-slot-read-observer slot-read-key)
        (prefix-in ../multimethod dispatch.) (prefix-in ../declarative-metadata metadata.)
        (prefix-in ../dispatch-extension extension.)
        (prefix-in ../method-combination combination.)
        ../method-declaration (prefix-in ../examples/polymorphic-services service.)
        (prefix-in ../examples/signature-service selected.))
;; Preserve typed failures while keeping ordinary builder errors observable.
(def (refusal kind) (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) kind))))
;; A whole candidate may determine the signature kind and every named field.
(def schema (prototype-type (.o .parameters: '(Catalog)) '(Catalog) 'Catalog []))
;; No builder is permitted for incomplete, ambiguous or inconsistent inference.
(def (forbidden _) (error "builder ran before unique complete inference"))
;; Shared observations constrain the same candidate layout, never separate solves.
(def calls '(((api run) (Integer) (UInt)) ((api audit) (UInt) (Bool))))
;; Exact field catalogs contain two required signatures and one non-method field.
(def good '(Object ((api (Object ((run (Function (UInt) (Integer)))
                                 (audit (Function (Bool) (UInt)))) closed))
                    (limit UInt)) closed))
;; Missing sibling support is a negative candidate, not a synthesized method.
(def missing '(Object ((api (Object ((run (Function (UInt) (Integer)))) closed))) closed))
;; One finite directory covers every current descriptor constructor and both Map
;; spellings. Row occurs only in its admitted tail position; literal names that
;; look like parameters must survive every phase without becoming Type children.
(def metadata-templates
  '(T U Tail Never Bool Integer UInt String Symbol Keyword Null Unit Bytes
    UInt256 JsInt Bytes32 Bytes64 (UIntN 8) (IntN 8) (BytesN 4)
    (IntegerRange max: 9 min: 0) (Exactly T) (Enum T U #f #!rest)
    (List T) (Maybe T) (OrFalse T) (Tuple T U) (Pair T (List U))
    (Map T <- U) (Map T -> U) (Sum T: T U: (List U))
    (Union T U T) (Or T U T) (TypeValuePair UInt Bool)
    (Record ((T T required) (U U optional)) closed)
    (Object ((T T) (U U)) (Row Tail))
    (Mu Node 2 (Pair T (List Node)))
    (Function (T U) (T) rest: U required-keywords: (T:)
      keywords: ((T: . U)) optional: ((List T)))
    (CaseFunction (Function (T) ()) (Function (U T) (T U) rest: T))))
;; Observe exact protocol work without substituting a new production counter.
;; The checked workers accept this caller-owned observer; public APIs still
;; validate numeric quotas through the existing type-work constructor.
(def (observed-work operation)
  (let (count 0)
    (operation (lambda () (set! count (1+ count))))
    count))
;; Find the exact successful public quota with logarithmically many fresh calls.
;; Only exhaustion moves the lower bound: malformed metadata, ownership and user
;; failures remain observable. The unchanged default quota must already succeed.
(def (required-budget operation)
  (operation 8192)
  (let search ((low 1) (high 8192))
    (if (= low high) low
      (let* ((middle (quotient (+ low high) 2))
             (accepted? (try (operation middle) #t
               (catch (cause)
                 (if ((refusal 'exhausted) cause) #f (raise cause))))))
        (if accepted? (search low middle) (search (1+ middle) high))))))
;; Every public entry point uses the same whole declaration builder. Keeping the
;; pure and published operations beside each other makes phase-reset regressions
;; independent of a fixed count or a particular metadata representation.
(def (declaration-drivers)
  (def signature '(Function (UInt) (Integer)))
  (def candidates (list signature))
  (def queries `((Catalog ,signature)))
  (def observations '((() (Integer) (UInt))))
  (list
    (cons (lambda (work) (instantiate/checked schema candidates work))
      (lambda (builder budget) (instantiate-declared schema candidates builder budget)))
    (cons (lambda (work) (infer-prototype/checked schema candidates queries work))
      (lambda (builder budget) (.get (infer-declared schema candidates queries builder budget) instance)))
    (cons (lambda (work) (infer-prototype-calls/checked schema candidates observations work))
      (lambda (builder budget) (.get (infer-declared-calls schema candidates observations builder budget) instance)))))
;; Complete end-to-end coverage includes kind, shape, rows, quotas and provenance.
(def candidate-inference-test
  (test-suite "Candidate-dependent signatures and field layouts"
    (test-case "signature requests retain their field selection across source getters"
      (def catalog '(Object ((api (Object
        ((run (Function (UInt (Function (Integer) (Integer))) (Integer)))
         (audit (Function (Bool) (Bool)))) closed))) closed))
      (def schema (prototype-type (.o .parameters: '(T)) '(T) catalog []))
      (def instance (instantiate-prototype schema '(UInt)))
      (def path (list 'api 'run))
      (def reads 0)
      (.setslot! (.get instance prototype) .parameters
        ($computed-slot-spec (lambda (_self _inherited)
          (set! reads (1+ reads)) (set-car! (cdr path) 'audit) [])))
      (def checked (instance-signature instance (lambda (_) [['Service]]) []
        standard-combination combination.standard-contribution? #f 8192 1 path))
      (def descriptor (dispatch.function-signature (extension.snapshot checked)))
      (check-equal? path '(api audit))
      (check-equal? (length (.get descriptor outputs)) 2)
      (check (> reads 0) => #t)
      ;; A subsequent request observes the edited path, never a cached old choice.
      (def retry (instance-signature instance (lambda (_) [['Service]]) []
        standard-combination combination.standard-contribution? #f 8192 1 path))
      (check-equal? (length (.get (dispatch.function-signature (extension.snapshot retry)) outputs)) 1)
      ;; Whole path admission precedes every source getter, including cycles and
      ;; exhaustion. No cap is widened; an independent request can still retry.
      (set! reads 0)
      (for-each (lambda (bad)
        (check-exception (instance-signature instance void [] standard-combination
          combination.standard-contribution? #f 8192 1 bad) (refusal 'malformed)))
        (list '(api . run) '(api 3)))
      (def cycle (list 'api)) (set-cdr! cycle cycle)
      (check-exception (instance-signature instance void [] standard-combination
        combination.standard-contribution? #f 8192 1 cycle) (refusal 'exhausted))
      (check-exception (instance-signature instance void [] standard-combination
        combination.standard-contribution? #f 1 1 '(api run)) (refusal 'exhausted))
      (check-equal? reads 0)
      (def cause (list 'source-failed))
      (.setslot! (.get instance prototype) .parameters
        ($computed-slot-spec (lambda (_self _inherited) (raise cause))))
      (check (try (instance-signature instance void [] standard-combination
        combination.standard-contribution? #f 8192 1 '(api run)) #f
        (catch (actual) (eq? cause actual))) => #t))
    (test-case "captured nested selection closes inference declarations refine and evidence"
      (def schema (prototype-type (.o .parameters: '(Result)) '(Result)
        '(Object ((api (Object
          ((run (Function (Result (Function (Integer) (Integer))) (Integer)))
           (audit (Function (Bool) (Bool)))) closed))) closed) []))
      (def path (list 'api 'run)) (def bodies 0) (def consumed 0)
      ;; Return a callback so the publication contract must retain wrapping.
      (def (operation value) (set! bodies (1+ bodies)) (values (abs value) abs))
      ;; Refresh only a caller request buffer; the declared source stays unchanged.
      (def (observe read)
        (when (eq? (slot-read-key read) '.parameters) (set-car! (cdr path) 'audit)))
      ;; Arm the observer inside the builder so schema preparation cannot pre-edit
      ;; the request before its signature entry. Reuse the existing slot observer.
      (def (build instance)
        (call-with-slot-read-observer observe
          (cut selected.selected-declarations instance path operation)))
      (def report (infer-declared-calls schema '(UInt Bool)
        '(((api run) (Integer) (UInt (Function (Integer) (Integer))))
          ((api audit) (Bool) (Bool))) build))
      (check-equal? (.get report solutions) '((UInt)))
      (check-equal? bodies 0)
      (def context (.o approved: #t))
      (def seen #f)
      ;; Approval refusal executes neither generic nor IO; policy refusal executes
      ;; the body but publishes nothing. A fresh action succeeds with exact evidence.
      (check-exception ((selected.selected-action (.get report instance) -7 (.o approved: #f) void) #f) Error?)
      (check-equal? bodies 0)
      (check-exception ((selected.selected-action (.get report instance) -7 context void 0) context) TypeError?)
      (check-equal? bodies 1)
      (def action (selected.selected-action (.get report instance) -7 context
        (lambda (subject) (set! consumed (1+ consumed)) (set! seen subject))))
      (defvalues (evidence next failure) (action context))
      (check-equal? failure #f) (check-equal? consumed 1) (check-equal? bodies 2)
      (check-equal? (.get seen answer) 7) (check-equal? (.get seen audit) #t)
      (check-equal? ((.get seen callback) -9) 9)
      (check-exception ((.get seen callback) #f) TypeError?)
      (check (eq? (.get evidence subject) seen) => #t)
      (check (eq? (.get evidence context) context) => #t)
      (check (eq? next context) => #t))
    (test-case "final parameter getters cannot change already admitted source metadata"
      (for-each (lambda (revise)
        (def instance (instantiate-prototype service.DescriptorServiceType '(Integer UInt)))
        (def effects 0)
        (check-exception (service.finalizing-service-declarations
          (lambda (instance owner) (set! effects (1+ effects)) (revise instance owner))
          instance (lambda (value) (values (abs value) abs)) void) (refusal 'bounds))
        (check-equal? effects 1))
        (list
          (lambda (instance _) (.setslot! instance expression
            ($constant-slot-spec '(Function (Bool) (Integer)))))
          (lambda (instance _) (set-car! (cadr (.get instance expression)) 'Bool))
          (lambda (instance _) (set-car! (car (.get instance bound-parameters)) 'Other))))
      (def cause (list 'finalizer-failed))
      (def instance (instantiate-prototype service.DescriptorServiceType '(Integer UInt)))
      (check (try (service.finalizing-service-declarations
        (lambda (_instance _owner) (raise cause)) instance (lambda (value) (values (abs value) abs)) void)
        #f (catch (actual) (eq? actual cause))) => #t)
      (def healthy (instantiate-prototype service.DescriptorServiceType '(Integer UInt)))
      (def completions 0)
      (check (pair? (service.finalizing-service-declarations
        (lambda (_instance _owner) (set! completions (1+ completions)))
        healthy (lambda (value) (values (abs value) abs)) void)) => #t)
      (check-equal? completions 1))
    (test-case "later binding getters cannot invalidate earlier direct descriptor checks"
      (def schema (prototype-type (.o .parameters: '(A B)) '(A B) '(Function (A) (B)) []))
      (def instance (instantiate-prototype schema '((List UInt) (List Integer))))
      (def owner (.get instance prototype))
      (def first (.get owner A)) (def second (.get owner B))
      (.setslot! owner B ($computed-slot-spec (lambda (_self _inherited)
        (.setslot! first audit ($constant-slot-spec 'changed)) second)))
      (check-exception (bound-parameters instance) (refusal 'bounds))
      (def fresh (instantiate-prototype schema '((List UInt) (List Integer))))
      (check-equal? (bound-parameters fresh) '(A B))
      (def cause (list 'binding-getter-failed))
      (def failed-owner (.get fresh prototype))
      (.setslot! failed-owner B ($computed-slot-spec (lambda (_self _inherited)
        (.setslot! (.get failed-owner A) audit ($constant-slot-spec 'changed)) (raise cause))))
      (check (try (bound-parameters fresh) #f (catch (actual) (eq? actual cause))) => #t))
    (test-case "nested catalog getters cannot revise syntax after initial declaration admission"
      (def schema (prototype-type (.o .parameters: '(Result)) '(Result)
        '(Object ((api (Object ((run (Function (Result) (Integer)))) closed))) closed) []))
      (def armed? #f) (def edits 0) (def expression #f)
      ;; Reuse the existing nested typed declaration and finite path protocol.
      (def (build instance)
        (def certified (instance-signature instance (lambda (_) [['Value]]) []
          standard-combination combination.standard-contribution? #f 8192 1 '(api run)))
        (def api (object<-declaration-forms MethodDeclaration. instance
          [(typed-method-fragment 'run certified
            [(metadata.replace "run" [(dispatch.prototype 'Value)]
              (combination.primary (lambda (_ value) (abs value))))])]))
        (set! expression (.get instance expression))
        (set! armed? #t)
        [(declaration-form 'public 'api (.o (constant api)))])
      ;; The first real api value read happens during final catalog walking,
      ;; after source admission. Reuse its existing finite signature projection.
      (def (observe read)
        (when (and armed? (eq? (slot-read-key read) 'api))
          (set! armed? #f) (set! edits (1+ edits))
          (set-car! (cadr (function-expression expression '(api run) (type-work 8192))) 'Bool)))
      (check-exception (call-with-slot-read-observer observe
        (lambda () (infer-declared-calls schema '(UInt)
          '(((api run) (Integer) (UInt))) build))) (refusal 'bounds))
      (check-equal? edits 1))
    (test-case "failed finalization retries through inferred declarations wrapping and evidence"
      (def partial (specialize-prototype-type service.DescriptorServiceType '(Integer)))
      (def observations '((() (Integer) (UInt (Function (UInt) (Integer))))))
      (def staged (infer-prototype-calls partial '(UInt Bool) observations))
      (def effects 0) (def bodies 0) (def consumed 0) (def callback #f)
      ;; Finalization effects remain observable even when no declaration escapes.
      (def (finalize instance _owner)
        (set! effects (1+ effects)) (set-car! (cadr (.get instance expression)) 'Bool))
      ;; The returned function is recursively wrapped by the existing signature.
      (def (operation value) (set! bodies (1+ bodies)) (values (abs value) abs))
      (check-exception (service.finalizing-service-declarations finalize
        (.get staged instance) operation void) (refusal 'bounds))
      (check-equal? effects 1) (check-equal? bodies 0)
      (def report (infer-declared-calls partial '(UInt Bool) observations
        (cut service.signature-service-declarations <> operation void)))
      (check-equal? (.get report solutions) '((UInt)))
      (def context (.o approved: #t))
      (check-exception ((service.descriptor-service-action (.get report instance) -7 context void #f) context) TypeError?)
      (def action (service.descriptor-service-action (.get report instance) -7 context
        (lambda (subject) (set! consumed (1+ consumed)) (set! callback (.get subject callback)))))
      (defvalues (evidence next issue) (action context))
      (check-equal? issue #f) (check-equal? consumed 1)
      (check (eq? (.get evidence context) context) => #t) (check (eq? next context) => #t)
      (check-equal? (callback -9) 9) (check-exception (callback #f) TypeError?))
    (test-case "publication jointly rechecks compiled origins after final source getters"
      (for-each (lambda (stage)
        (def schema (prototype-type (.o .parameters: '(T)) '(T) '(Function (T) (Integer)) []))
        (def descriptor #f) (def armed? #f) (def source-seen? #f) (def edits 0)
        ;; Retain the real factory-owned signature, then use the same qualified
        ;; stream. No method body may execute during whole declaration admission.
        (def (build instance)
          (def signature (instance-signature instance (lambda (_) [['Service]]) []))
          (set! descriptor (dispatch.function-signature (extension.snapshot signature)))
          (def forms (service.signature-service-declarations instance abs void signature))
          (set! armed? #t) forms)
        ;; Revise at the real source getter or the later root catalog read.
        ;; The earlier forcing read cannot trigger the catalog-stage control.
        (def (observe read)
          (when armed?
            (when (eq? (slot-read-key read) '.parameters) (set! source-seen? #t))
            (when (and source-seen?
                    (eq? (slot-read-key read) (if (eq? stage 'source) '.parameters '.invoke)))
              (set! edits (1+ edits)) (set! armed? #f)
              (.setslot! descriptor audit ($constant-slot-spec 'changed)))))
        (check-exception (call-with-slot-read-observer observe
          (lambda () (infer-declared schema '(UInt) [] build))) (refusal 'bounds))
        (check-equal? edits 1)) '(source catalog)))
    (test-case "explicit and prefix requests own nested arguments before source refresh"
      (for-each (lambda (request)
        (def source (.o .parameters: '(T)))
        (def schema (prototype-type source '(T) 'T []))
        (def arguments (list (list 'List 'UInt)))
        (.setslot! source .parameters ($computed-slot-spec (lambda (_self _inherited)
          (set-car! (cdar arguments) 'Bool) '(T))))
        (check-equal? (.get (request schema arguments) expression) '(List UInt))
        (check-equal? arguments '((List Bool))))
        (list instantiate-prototype
          (lambda (schema arguments) (instantiate-prototype (specialize-prototype-type schema arguments) [])))))
    (test-case "raw and call inference own the whole candidate and constraint batch"
      (for-each (lambda (calls?)
        (def source (.o .parameters: '(T)))
        (def schema (prototype-type source '(T) '(Function ((List T)) (Integer)) []))
        (def candidates (list 'UInt 'Bool))
        (def queries (list (list 'T 'UInt)))
        (def calls (list (list [] '(Integer) (list (list 'List 'UInt)))))
        (.setslot! source .parameters ($computed-slot-spec (lambda (_self _inherited)
          (set-car! candidates 'Bool)
          (set-car! (cdar queries) 'Bool)
          (set-car! (cdr (car (caddar calls))) 'Bool) '(T))))
        (def report (if calls? (infer-prototype-calls schema candidates calls)
                     (infer-prototype schema candidates queries)))
        (check-equal? (.get report solutions) '((UInt)))
        (check-equal? (.get report instance expression) '(Function ((List UInt)) (Integer)))
        (if calls? (check-equal? (.get report calls) '((() (Integer) ((List UInt)))))
          (check-equal? (.get report queries) '((T UInt))))
        (check-equal? candidates '(Bool Bool))
        (check-equal? queries '((T Bool)))) '(#f #t)))
    (test-case "cyclic request inputs refuse before any schema getter or declaration builder"
      (for-each (lambda (request)
        (def source (.o .parameters: '(T)))
        (def schema (prototype-type source '(T) '(Function (T) (Integer)) []))
        (def reads 0)
        (.setslot! source .parameters ($computed-slot-spec
          (lambda (_self _inherited) (set! reads (1+ reads)) '(T))))
        (def cycle (list 'UInt)) (set-cdr! cycle cycle)
        (check-exception (request schema cycle) (refusal 'exhausted))
        (check-equal? reads 0))
        (list instantiate-prototype specialize-prototype-type
          (lambda (schema data) (infer-prototype schema data []))
          (lambda (schema data) (infer-prototype schema '(UInt) data))
          (lambda (schema data) (infer-prototype-calls schema data []))
          (lambda (schema data) (infer-prototype-calls schema '(UInt) data))
          (lambda (schema data) (instantiate-declared schema data forbidden))
          (lambda (schema data) (infer-declared schema data [] forbidden))
          (lambda (schema data) (infer-declared-calls schema '(UInt) data forbidden)))))
    (test-case "request capture retains original getter exceptions and refusal categories"
      (def source (.o .parameters: '(T)))
      (def schema (prototype-type source '(T) '(Function (T) (Integer)) []))
      (def cause (Error "request source getter failed"))
      (.setslot! source .parameters ($computed-slot-spec (lambda (_self _inherited) (raise cause))))
      (check (try (infer-prototype schema '(UInt) []) #f (catch (actual) (eq? actual cause))) => #t)
      (check-exception (infer-prototype schema '(UInt) [] 1) (refusal 'exhausted)))
    (test-case "source refresh cannot rewrite complete inference or evidence publication"
      (def candidates (list 'UInt))
      (def calls (list (list [] '(Integer)
        (list 'UInt (list 'Function (list 'UInt) (list 'Integer))))))
      (def observations 0) (def bodies 0) (def consumed 0) (def callback #f)
      ;; Simulate configuration buffer reuse while the source metadata is read.
      (def (observe)
        (set! observations (1+ observations))
        (set-car! candidates 'Bool)
        (set-car! (caddar calls) 'Bool)
        (set-car! (cadr (cadr (caddar calls))) 'Bool))
      ;; Return both the scalar and a recursively checked callback, exactly once.
      (def (operation value)
        (set! bodies (1+ bodies)) (values (abs value) abs))
      (def report (service.infer-observed-descriptor-calls observe '(Integer) candidates calls operation))
      (check-equal? observations 1) (check-equal? bodies 0)
      (check-equal? (.get report solutions) '((UInt)))
      (check-equal? (.get report calls) '((() (Integer) (UInt (Function (UInt) (Integer))))))
      (def context (.o approved: #t))
      (def denied (service.descriptor-service-action (.get report instance) -7 context void #f))
      (check-exception (denied context) TypeError?)
      (check-equal? consumed 0)
      (def action (service.descriptor-service-action (.get report instance) -7 context
        (lambda (subject) (set! consumed (1+ consumed)) (set! callback (.get subject callback)))))
      (defvalues (evidence next issue) (action context))
      (check-equal? issue #f) (check-equal? consumed 1)
      (check (eq? (.get evidence context) context) => #t) (check (eq? next context) => #t)
      (check-equal? (callback -9) 9) (check-exception (callback #f) TypeError?)
      ;; A later request sees the reused Bool buffers and refuses; restoring
      ;; them admits a fresh request, without rewriting the first receipt.
      (def none (service.infer-observed-descriptor-calls void '(Integer) candidates calls operation))
      (check-equal? (.get none status) 'no-solution) (check-equal? (.get none instance) #f)
      (set-car! candidates 'UInt)
      (set-car! (caddar calls) 'UInt)
      (set-car! (cadr (cadr (caddar calls))) 'UInt)
      (def retry (service.infer-observed-descriptor-calls void '(Integer) candidates calls operation))
      (check-equal? (.get retry solutions) '((UInt)))
      (check-equal? (.get report calls) (.get retry calls)))
    (test-case "every complete classification retains deep raw query snapshots"
      (def scheme (prototype-type (.o .parameters: '(T)) '(T) '(List T) []))
      (for-each (lambda (candidates status)
        (def queries (list (list (list 'List 'UInt) (list 'List 'T))))
        (def report (infer-prototype scheme candidates queries))
        (check-equal? (.get report status) status)
        ;; Change a nested source leaf before first reading lazy report fields.
        (set-car! (cdr (car (car queries))) 'Bool)
        (check-equal? (.get report queries) '(((List UInt) (List T))))
        (for-each (lambda (alternative)
          (check-equal? (.get alternative queries) '(((List UInt) (List T)))))
          (.get report alternatives)))
        '((UInt) (UInt Integer) (Bool)) '(unique ambiguous no-solution)))
    (test-case "query capture refuses cyclic or malformed batches before copying or classifying"
      (def scheme (prototype-type (.o .parameters: '(T)) '(T) 'T []))
      (def cycle (list (list 'UInt 'T)))
      (set-cdr! cycle cycle)
      (check-exception (infer-prototype scheme '(UInt) cycle) (refusal 'exhausted))
      (check-exception (infer-prototype scheme [] '((UInt T) (Bool))) (refusal 'malformed))
      (check-exception (infer-prototype scheme [] '((UInt T) (Unknown T))) (refusal 'unsupported)))
    (test-case "declaration callbacks may reuse input buffers without rewriting solve evidence"
      (def queries (list (list 'Integer 'Super)))
      (def partial (specialize-prototype-type service.SignatureServiceType '(UInt)))
      (def builds 0)
      (def build (lambda (instance)
        (set! builds (1+ builds))
        (set-car! (car queries) 'Bool)
        (service.signature-service-declarations instance
          (lambda (value (extra 0) scale: (scale 1) . rest) (values (abs value) abs)) void)))
      (def solved (infer-declared partial '(UInt Integer) queries build))
      (check-equal? builds 1)
      (check-equal? (.get solved status) 'unique)
      (check-equal? (.get solved queries) '((Integer Super)))
      (check-equal? (.get (car (.get solved alternatives)) queries) '((Integer Super)))
      (check-equal? queries '((Bool Super)))
      (def refused (infer-declared partial '(UInt Integer) queries forbidden))
      (check-equal? (.get refused status) 'no-solution)
      (check-equal? (.get refused queries) '((Bool Super)))
      (set-car! (car queries) 'Unknown)
      (check-exception (infer-declared partial '(UInt Integer) queries forbidden) (refusal 'unsupported))
      (check-equal? (.get solved queries) '((Integer Super)))
      (check-equal? (.get refused queries) '((Bool Super))))
    (test-case "request FUN reuses caller buffers through refinement evidence refusal and retry"
      (def queries (list (list 'Integer 'Super)))
      (def requests 0) (def consumed 0) (def observed #f)
      (def context (.o bind-these: #f approved: #t queries: queries))
      (def request (service.signature-request-action service.SignatureServiceType '(UInt)
        '(UInt Integer)
        (lambda (ctx) (set! requests (1+ requests)) (.get ctx queries))
        (lambda (value (extra 0) scale: (scale 1) . rest) (values (abs value) abs))
        ;; Method effects reuse the source buffer AFTER a successful search.
        (lambda (_) (set-car! (car queries) 'Bool))))
      (check-equal? requests 0)
      (def solved (request context))
      (check-equal? requests 1)
      (def action (service.catalog-service-action (.get solved instance) -7 context
        (lambda (subject) (set! consumed (1+ consumed)) (set! observed (.get subject callback)))))
      (defvalues (evidence next issue) (action context))
      (check-equal? issue #f) (check-equal? consumed 1)
      (check (eq? (.get evidence context) context) => #t)
      (check (eq? next context) => #t)
      (check-equal? (observed -9) 9)
      (check-exception (observed #f) TypeError?)
      (check-equal? (.get solved queries) '((Integer Super)))
      (def denied (request context))
      (check-equal? (.get denied status) 'no-solution)
      (check-equal? (.get denied queries) '((Bool Super)))
      (set-car! (car queries) 'Integer)
      (def retry (request context))
      (check-equal? (.get retry status) 'unique)
      (def limited (service.catalog-service-action (.get retry instance) -7 context
        (lambda (_) (set! consumed (1+ consumed))) 2))
      (check-exception (limited context) TypeError?)
      (check-equal? consumed 1)
      (check-equal? (.get retry queries) '((Integer Super)))
      (check-equal? (.get denied queries) '((Bool Super))))
    (test-case "all declaration entry points retain inference quota before the builder"
      (for-each (lambda (driver)
        (def count (observed-work (car driver)))
        ;; Pure binding/search has enough work, but source admission must not
        ;; reset that consumed quota or execute any declaration callback.
        (check-exception ((cdr driver) forbidden count) (refusal 'exhausted)))
        (declaration-drivers)))
    (test-case "late admission exhaustion publishes nothing and fresh exact-budget retries succeed"
      (for-each (lambda (driver)
        (def builds 0) (def bodies 0) (def returned #f)
        (def builder (lambda (instance)
          (set! builds (1+ builds))
          (service.signature-service-declarations instance
            (lambda (value) (set! bodies (1+ bodies)) (abs value)) void)))
        (def request (lambda (budget) ((cdr driver) builder budget)))
        (def count (required-budget request))
        (check (> count (observed-work (car driver))) => #t)
        (set! builds 0)
        (check-exception (set! returned (request (1- count))) (refusal 'exhausted))
        (check-equal? returned #f) (check-equal? builds 1) (check-equal? bodies 0)
        ;; Construction guards unwind after late failure. Reuse exactly the same
        ;; schema/builder, then invoke the accepted typed group and its successor.
        (def instance (request count))
        (check-equal? (bound-parameters instance) '(Catalog))
        (check-equal? builds 2) (check-equal? bodies 0)
        (defvalues (answer next) (service.invoke-signature-service (.get instance prototype) -7))
        (check-equal? answer 7) (check-equal? bodies 1)
        (defvalues (again _) (invoke-declared next [-8]))
        (check-equal? again 8) (check-equal? bodies 2)) (declaration-drivers)))
(test-case "declaration reports complete admission before any later instance observation"
  (for-each (lambda (request)
    (def builds 0)
    (def builder (lambda (instance)
      (set! builds (1+ builds))
      (service.signature-service-declarations instance abs void)))
    (let (report (request builder 8192))
      (check-equal? builds 1)
      (check-equal? (.get report status) 'unique)
      (check-equal? (bound-parameters (.get report instance)) '(Catalog))
      (check-equal? builds 1)))
    (list
      (lambda (build budget)
        (infer-declared schema '((Function (UInt) (Integer))) [] build budget))
      (lambda (build budget)
        (infer-declared-calls schema '((Function (UInt) (Integer)))
          '((() (Integer) (UInt))) build budget)))))
    (test-case "nested independent requests cannot replenish or consume the outer admission quota"
      (def driver (caddr (declaration-drivers)))
      (def nested? #f) (def nested-count 0)
      (def builder (lambda (instance)
        (when nested?
          ((cdr driver) (lambda (inner)
            (set! nested-count (1+ nested-count))
            (service.signature-service-declarations inner abs void)) 8192))
        (service.signature-service-declarations instance abs void)))
      (def count (required-budget (cut (cdr driver) builder <>)))
      (set! nested? #t)
      (check-exception ((cdr driver) builder (1- count)) (refusal 'exhausted))
      (check-equal? nested-count 1)
      (def instance ((cdr driver) builder count))
      (check-equal? nested-count 2)
      (defvalues (answer _) (service.invoke-signature-service (.get instance prototype) -5))
      (check-equal? answer 5))
    (test-case "builder causes precede late exhaustion and incomplete classifications never declare"
      (def driver (caddr (declaration-drivers)))
      (def builder (lambda (instance) (service.signature-service-declarations instance abs void)))
      (def count (required-budget (cut (cdr driver) builder <>)))
      (def cause (try (error "builder refused") (catch (cause) cause)))
      (def found (try ((cdr driver) (lambda (_) (raise cause)) (1- count)) #f
        (catch (failed) failed)))
      (check (eq? found cause) => #t)
;; Changed grammar retains its original refusal before source comparison.
(for-each (lambda (entry)
  (def source (prototype-type (.o .parameters: '(Item)) '(Item) '(List Item) []))
  (check-exception
    (instantiate-declared source '(UInt)
      (lambda (instance) (set-car! (.get instance expression) (car entry)) []) 8192)
    (refusal (cdr entry)))) '((Unknown . unsupported) (Function . malformed)))

      (for-each (lambda (candidates)
        (def observations '((() (UInt) (Integer))))
        (def work (observed-work (cut infer-prototype-calls/checked schema candidates observations <>)))
        (def pure (infer-prototype-calls schema candidates observations work))
        (def declared (infer-declared-calls schema candidates observations forbidden work))
        (check-equal? (.get declared status) (.get pure status))
        (check-equal? (.get declared solutions) (.get pure solutions)))
        '((Bool) ((Function (UInt) (Integer)) (Function (Integer) (Integer))))))
    (test-case "compiled Map and Record children never retain a completed request counter"
      (def packet '(Map (Record ((callbacks (List (Function (UInt) (Integer))) required)
                                 (backup (Maybe (Function (UInt) (Integer))) optional)) closed) <- UInt))
      (def syntax `(Function (,packet) (UInt)))
      (type-expression syntax [] (type-work 8192))
      (def closed? #f) (def ticks 0) (def bodies 0)
      (def descriptor (compile-expression syntax (lambda ()
        (when closed? (error "compiler work escaped into descriptor observation"))
        (set! ticks (1+ ticks)))))
      ;; A successful compiler request is over. Every later validation, clone,
      ;; callback and diagnostic must work without another compiler tick.
      (set! closed? #t)
      (let (compiled ticks)
        (for-each (lambda (current)
          (def checked (validate current (lambda (key)
            (set! bodies (1+ bodies))
            (let (table (make-hash-table-eq))
              (hash-put! table key (.o callbacks: (list abs))) table))))
          (def result (checked 3))
          (def callback (car (.get (hash-ref result 3) callbacks)))
          (check-equal? (callback -4) 4)
          (check-exception (callback #f) TypeError?)
          (let (before bodies)
            (check-exception (checked #f) TypeError?)
            (check-equal? bodies before))
          (check-equal? ticks compiled)) (list descriptor (.cc descriptor)))
        (def table (.get descriptor outputs))
        (def record (.get (car table) Value))
        (check (eq? (.get (.cc (car table)) Value) record) => #t)
        (check (eq? (.get (.cc record) slots) (.get record slots)) => #t)
        (check-equal? (.get (car table) Key sexp) 'UInt)
        (check-equal? ticks compiled)))
    (test-case "complete metadata directory shares transformation and canonicalization"
      (def substitution '((T . UInt) (U . Bool) (Tail . (Object ((extra UInt)) closed))))
      (for-each (lambda (term)
        (type-expression term '(T U Tail) (type-work 8192))
        (check-equal? (if (pair? term) (map-type-children term identity) term) term)
        (check-equal? (substitute-type term [] (type-work 8192)) term)
        (def staged (foldl (lambda (binding expression)
          (substitute-type expression (list binding) (type-work 8192))) term substitution))
        (def whole (substitute-type term substitution (type-work 8192)))
        (check-equal? staged whole)
        (check-equal? (canonical-type (canonical-type whole (type-work 8192)) (type-work 8192))
          (canonical-type whole (type-work 8192)))) metadata-templates)
      (check-equal? (substitute-type '(Mu Node 2 (Pair T (List Node)))
        '((Node . Bool) (T . UInt)) (type-work 8192)) '(Mu Node 2 (Pair UInt (List Node))))
      (check-equal? (canonical-type '(Map UInt -> (List Bool)) (type-work 8192))
        (canonical-type '(Map (List Bool) <- UInt) (type-work 8192))))
    (test-case "the complete directory agrees across staged binding inference and assembly"
      (def extension '(Object ((extra UInt)) closed))
      (for-each (lambda (term)
        (def original (prototype-type (.o .parameters: '(T U Tail)) '(T U Tail) term []))
        (def fixed (specialize-prototype-type original '(UInt Bool)))
        (def direct (instantiate-prototype original (list 'UInt 'Bool extension)))
        (def staged (instantiate-prototype fixed (list extension)))
        (def report (infer-prototype fixed (list 'Bool extension)
          `((Tail ,extension) (,extension Tail))))
        (check-equal? (.get report status) 'unique)
        (check-equal? (.get report solutions) (list (list extension)))
        (check-equal? (.get staged expression) (.get direct expression))
        (check-equal? (.get report instance expression) (.get direct expression))
        (check-equal? (.get (car (.get report alternatives)) expression)
          (normalize-type (.get direct expression) (type-work 8192)))
        (check-equal? (bound-parameters (.get report instance)) '(T U Tail))) metadata-templates))
    (test-case "whole signature kinds are selected after candidate substitution"
      (def report (infer-prototype-calls schema '(Integer (Function (UInt) (Integer)))
        '((() (Integer) (UInt)))))
      (check-equal? (.get report status) 'unique)
      (check-equal? (.get report solutions) '(((Function (UInt) (Integer)))))
      (check-equal? (.get report queries) '((Integer Integer) (UInt UInt))))
    (test-case "one composite publication keeps row metadata wrappers evidence and retry"
      (def extension '(Object ((audit (Function (Bool) (UInt)))) closed))
      (def packet '(Object
        ((Value (Pair (List UInt) (Map UInt -> (Function (UInt) (Integer)))))
         (state (OrFalse (Maybe (Sum ready: (Tuple (Function (UInt) (Integer)))
                                    idle: (List (Function (UInt) (Integer)))))))
         (audit (Function (Bool) (UInt)))) closed))
      (def signature `(Function (,packet) (Integer)))
      (def target `(Function (,packet) (UInt)))
      (def calls 0) (def consumed 0) (def observed #f) (def broken? #f)
      ;; Actual host tables and ordinary POO values supply independent carriers.
      ;; Functions are deliberately returned raw so recursive wrapping is tested.
      (def callback (lambda (value)
        (set! calls (1+ calls))
        (let (table (make-hash-table-eq))
          (hash-put! table 0 abs)
          (.o Value: (cons (list (if broken? #f (abs value))) table)
              state: (.o tag: 'ready value: (vector abs))
              audit: (lambda (number) (>= number 0))))))
      (def request (service.metadata-service-request (list 'UInt extension) (list 'Bool signature)
        `((() (UInt) (UInt ,target))) (lambda (value) (values value callback))))
      (def budget (required-budget request))
      (check-exception (request (1- budget)) (refusal 'exhausted))
      (check-equal? calls 0) (check-equal? consumed 0)
      (def report (request budget))
      (check-equal? (.get report status) 'unique)
      (check-equal? calls 0)
      (check-equal? (bound-parameters (.get report instance)) '(Value Tail Callback))
      (def context (.o approved: #t))
      (def action (service.catalog-service-action (.get report instance) 7 context
        (lambda (subject) (set! consumed (1+ consumed)) (set! observed (.get subject callback)))))
      (defvalues (evidence next failure) (action context))
      (check-equal? failure #f) (check-equal? consumed 1) (check-equal? calls 0)
      (check (eq? next context) => #t)
      (check (eq? (.get evidence context) context) => #t)
      (def wrapped (validate (expression-type target) observed))
      (let (result (wrapped 3))
        (check-equal? (car (.get result Value)) '(3))
        (check (eq? (.has? result UInt) #f) => #t)
        (check-equal? ((hash-ref (cdr (.get result Value)) 0) -8) 8)
        (check-equal? ((vector-ref (.get result state value) 0) -9) 9)
        (check ((.get result audit) 7) => #t)
        (check-exception ((hash-ref (cdr (.get result Value)) 0) #f) TypeError?)
        (check-exception ((vector-ref (.get result state value) 0) #f) TypeError?)
        (check-exception ((.get result audit) #f) TypeError?))
      (let (before calls)
        (check-exception (wrapped -1) TypeError?)
        (check-equal? calls before))
      (set! broken? #t)
      (check-exception (wrapped 3) TypeError?)
      (set! broken? #f)
      (check-equal? (car (.get (wrapped 4) Value)) '(4))
      (def rejected (service.catalog-service-action (.get report instance) 7 context
        (lambda (_) (error "refused consumer ran")) 0))
      (check-exception (rejected context) TypeError?)
      (defvalues (_retry-evidence _retry-context retried) (action context))
      (check-equal? retried #f) (check-equal? consumed 2))
    (test-case "every sibling uses one candidate layout"
      (def report (infer-prototype-calls schema (list missing good) calls))
      (check-equal? (.get report solutions) (list (list good)))
      (check-equal? (.get (car (.get report alternatives)) expression) good)
      (check-equal? (.get report queries) '((Integer Integer) (UInt UInt) (UInt UInt) (Bool Bool))))
    (test-case "alternative diagnostics retain their own inequalities"
      (def report (infer-declared-calls schema
        '((Function (UInt) (Integer)) (Function (Integer) (Any)))
        '((() (UInt) (Integer))) forbidden))
      (check-equal? (.get report status) 'ambiguous)
      (check-equal? (map (lambda (entry) (.get entry queries)) (.get report alternatives))
        '(((UInt Integer) (UInt Integer)) ((UInt Any) (Integer Integer)))))
    (test-case "cross-candidate sibling matches cannot manufacture a solution"
      (def wrong '(Object ((api (Object ((run (Function (Bool) (Integer)))
                                        (audit (Function (Bool) (UInt)))) closed))) closed))
      (check-equal? (.get (infer-declared-calls schema (list missing wrong) calls forbidden) status) 'no-solution))
    (test-case "row substitutions decide paths and reject non-object or overlapping rows"
      (def row-schema (prototype-type (.o .parameters: '(Tail)) '(Tail)
        '(Object ((version UInt)) (Row Tail)) []))
      (def row '(Object ((run (Function (UInt) (Integer)))) closed))
      (def overlap '(Object ((version UInt) (run (Function (UInt) (Integer)))) closed))
      (def report (infer-prototype-calls row-schema (list 'UInt overlap row) '(((run) (Integer) (UInt)))))
      (check-equal? (.get report solutions) (list (list row)))
      (check-equal? (.get (car (.get report alternatives)) expression)
        '(Object ((version UInt) (run (Function (UInt) (Integer)))) closed)))
    (test-case "prefix specialization preserves literal names and deferred field types"
      (def partial (specialize-prototype-type
        (prototype-type (.o .parameters: '(Value Signature)) '(Value Signature)
          '(Object ((Value Value) (run Signature)) closed) []) '(UInt)))
      (check-equal? (.get (infer-prototype-calls partial '((Function (UInt) (Integer)) Bool)
        '(((run) (Integer) (UInt)))) solutions) '(((Function (UInt) (Integer))))))
    (test-case "rich keyword rest and multiple values use the existing selector"
      (def signature '(Function (UInt Bool) (Integer) optional: (Bool)
        keywords: ((mode: . UInt)) required-keywords: (mode:) rest: Integer))
      (check-equal? (.get (infer-prototype-calls schema (list '(Function (UInt) (Integer)) signature)
        '((() (Integer Bool Integer mode: UInt) (UInt Bool)))) status) 'unique)
      (check-equal? (.get (infer-prototype-calls schema (list signature)
        '((() (Integer Bool mode: UInt) ()))) status) 'no-solution))
    (test-case "ordered case selection never retries a later type-compatible case"
      (def shadowed '(CaseFunction (Function (Bool) (Integer)) (Function (UInt) (Integer))))
      (check-equal? (.get (infer-prototype-calls schema (list shadowed) '((() (Integer) (UInt)))) status) 'no-solution))
    (test-case "empty candidates still validate malformed observations"
      (check-exception (infer-declared-calls schema [] '((() (mode:) #f)) forbidden) (refusal 'malformed))
      (check-exception (infer-declared-calls schema [] '((() (Unknown) #f)) forbidden) (refusal 'unsupported))
      (check-exception (infer-declared-calls schema [] '((() () (Unknown))) forbidden) (refusal 'unsupported)))
    (test-case "whole observation admission precedes fixed or dependent shape refusal"
      (def fixed (prototype-type (.o .parameters: '(T)) '(T)
        '(Object ((run (Function (UInt) (Integer)))) closed) []))
      (def observed 0)
      ;; The first known shape cannot consume the request before a later sibling
      ;; receives grammar/Type admission, even when no candidate will be searched.
      (for-each (lambda (bad kind)
        (def observations (list '((run) () (UInt)) bad))
        (for-each (lambda (candidates)
          (check-exception (infer-prototype-calls fixed candidates observations) (refusal kind))
          (check-exception (infer-declared-calls fixed candidates observations
            (lambda (_) (set! observed (1+ observed)) [])) (refusal kind)))
          '(() (UInt))))
        '(((run) (Unknown) (UInt)) ((run) (Integer) (Unknown))
          ((run) (mode:) #f) ((run) () #t))
        '(unsupported unsupported malformed malformed))
      (check-equal? observed 0)
      ;; Standard left-to-right admission retains the first metadata refusal.
      (check-exception (infer-declared-calls fixed '(UInt)
        '(((run) (Unknown) (UInt)) ((run) (mode:) #f)) forbidden) (refusal 'unsupported))
      ;; Valid metadata keeps the old distinction: a fixed impossible shape is
      ;; bounds refusal; a candidate-dependent incompatible layout is no-solution.
      (check-exception (infer-prototype-calls fixed '(UInt) '(((run) () (UInt)))) (refusal 'bounds))
      (check-equal? (.get (infer-prototype-calls schema '((Function (UInt) (Integer)))
        '((() () (UInt)))) status) 'no-solution))
    (test-case "failed whole-batch admission retries through specialized shared publication"
      (def invoked 0) (def events []) (def consumed 0)
      ;; Body effects begin only after complete inference and approved invocation.
      (def (report value (extra 0) scale: (scale 1) . rest)
        ;; Real Gerbil optional/keyword/rest formals own argument interpretation.
        (set! invoked (1+ invoked))
        (values (* scale (+ (abs value) extra (apply + rest))) abs))
      ;; Recovery shares the same inferred Type assignment and checked receiver.
      (def (recover value) (+ value 1))
      ;; Record method order independently from the consumer's IO count.
      (def (record event) (set! events (cons event events)))
      (check-exception (service.infer-shared-service '(UInt) '(UInt Integer Bool)
        (append (list '((.report) () #f)) '(((.recover) (Unknown) (Integer))))
        report recover record) (refusal 'unsupported))
      (check-equal? invoked 0) (check-equal? events [])
      (def inferred (service.infer-shared-service '(UInt) '(UInt Integer Bool)
        service.shared-service-calls report recover record))
      (check-equal? (.get inferred status) 'unique)
      (check-equal? (.get inferred solutions) '((Integer)))
      (def action (service.shared-service-action (.get inferred instance) -4
        (lambda (answer recovered callback)
          (set! consumed (1+ consumed))
          (check-equal? answer 10) (check-equal? recovered 11)
          (check-equal? (callback -9) 9)
          (check-exception (callback #f) TypeError?))))
      (check-exception (action (.o approved: #f)) Error?)
      (check-equal? invoked 0)
      (action (.o approved: #t))
      (check-equal? invoked 1) (check-equal? consumed 1)
      (check-equal? (reverse events) '(report recover)))
    (test-case "a matched prefix cannot bypass exhaustion or recursive admission"
      (check-exception (infer-declared-calls schema (list good missing) calls forbidden 30) (refusal 'exhausted))
      (def nested (prototype-type (.o .parameters: '(T)) '(T) '(Mu X 1 (List T)) []))
      (check-exception (infer-prototype-calls nested '((Mu Y 1 (List Y))) []) (refusal 'unsupported)))
    (test-case "known literal missing paths keep their unsupported boundary"
      (def fixed (prototype-type (.o .parameters: '(T)) '(T) '(Object ((data T)) closed) []))
      (check-exception (infer-prototype-calls fixed '(UInt) '(((missing) () #f))) (refusal 'unsupported)))
    (test-case "whole candidate declaration invokes wrapped callbacks through FUN and evidence"
      (def report (service.infer-catalog-service
        '((Function (Bool) (Integer)) (Function (UInt (Function (UInt) (Integer))) (Integer)))
        '((() (Integer) (UInt (Function (UInt) (Integer)))))
        (lambda (value) (values (abs value) abs))))
      (def seen #f)
      (def action (service.catalog-service-action (.get report instance) -7 (.o approved: #t)
        (lambda (subject) (set! seen (.get subject callback)))))
      (defvalues (_ _context failure) (action #f))
      (check-equal? failure #f)
      (check-equal? (seen -9) 9)
      (check-exception (seen #f) TypeError?))
    (test-case "candidate field layout installs and invokes both qualified generics"
      (def catalog '(Object
        ((.report (Function (UInt (Function (UInt) (Integer))) (Integer)
          optional: (Integer) keywords: ((scale: . UInt)) rest: Integer))
         (.recover (Function (Integer) (UInt)))) closed))
      (def calls '(((.report) (Integer Integer scale: UInt) (UInt (Function (UInt) (Integer))))
                    ((.recover) (UInt) (Integer))))
      (def events [])
      (def report (service.infer-shared-catalog-service (list missing catalog) calls
        (lambda (_value _extra scale: (_scale 1) . _rest) (values 7 abs))
        (lambda (value) (+ value 1)) (lambda (event) (set! events (cons event events)))))
      (check-equal? events [])
      (def action (service.shared-service-action (.get report instance) -4
        (lambda (answer recovered callback)
          (check-equal? answer 7) (check-equal? recovered 8)
          (check-equal? (callback -9) 9)
          (check-exception (callback #f) TypeError?))))
      (defvalues (_answer _recovered _report-owner _recover-owner) (action (.o approved: #t)))
      (check-equal? (reverse events) '(report recover))
      ;; An otherwise unique layout cannot hide a required unobserved method.
      (def extended (list 'Object (append (cadr catalog) '((backup (Function (UInt) (UInt))))) 'closed))
      (check-exception (service.infer-shared-catalog-service (list extended) calls
        (lambda _ (values 7 abs)) values) (refusal 'bounds)))
    (test-case "unique builder failure stays an error and a fresh request may retry"
      (def failed 0)
      (check-exception (infer-declared-calls schema '((Function (UInt) (Integer)))
        '((() (Integer) (UInt))) (lambda (_) (set! failed (1+ failed)) (error "approval failed"))) Error?)
      (check-equal? failed 1)
      (check-equal? (.get (service.infer-catalog-service '((Function (UInt) (Integer)))
        '((() (Integer) (UInt))) abs) status) 'unique))))
