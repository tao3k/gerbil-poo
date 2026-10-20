;;; Candidate-dependent catalogs reuse the existing call and declaration protocol.
(export candidate-inference-test)
(import :std/test :std/error ../object ../mop ../prototype-types ../type-relation
        (only-in ../type-syntax map-type-children)
        ../method-declaration (prefix-in ../examples/polymorphic-services service.))
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
;; Complete end-to-end coverage includes kind, shape, rows, quotas and provenance.
(def candidate-inference-test
  (test-suite "Candidate-dependent signatures and field layouts"
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
      (def report (service.infer-metadata-service (list 'UInt extension) (list 'Bool signature)
        `((() (UInt) (UInt ,target))) (lambda (value) (values value callback))))
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
