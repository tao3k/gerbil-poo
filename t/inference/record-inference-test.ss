;;; Finite Record inference reuses Class/Slot and checked inheritance construction.
(export record-inference-test)
(import :std/test :std/error :clan/poo/object :clan/poo/mop :clan/poo/number :clan/poo/types/relation :clan/poo/prototype-types
        :clan/poo/method-declaration (only-in :clan/poo/type Record)
        (prefix-in :clan/poo/examples/polymorphic-services service.))
;; Compare failure categories without turning callback failures into no-solution.
(def (refusal kind) (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) kind))))
;; A return obligation fixes callback input and output along with the original bound.
(def expected '(Record ((run (Function (UInt) (Integer)) required)
                       (limit UInt required) (bias UInt required)
                       (extra (Function (UInt) (Integer)) optional)) open))
;; Observation extraction is unchanged: a scalar argument and a structured output.
(def observations (list (list [] '(Integer) (list expected))))
;; Exercise complete protocols as well as conservative rejected replacements.
(def record-inference-test
  (test-suite "Record Type inference and Class construction"
    (test-case "presence variance and sealed policy are explicit"
      (check (subtype-expression? '(Record ((n UInt required)) closed)
                                  '(Record ((n Integer optional)) open)) => #t)
      (check (subtype-expression? '(Record ((n UInt optional)) closed)
                                  '(Record ((n Integer required)) open)) => #f)
      (check (subtype-expression? '(Record ((n UInt required)) open)
                                  '(Record ((n UInt required)) closed)) => #f)
      (check (subtype-expression? '(Record ((n UInt required)) closed)
                                  '(Record ((other UInt required)) closed)) => #f)
      (check (subtype-expression? '(Record ((n UInt required)) closed)
                                  '(Record () open)) => #t))
    (test-case "named row coverage preserves closure and optional absence"
      (check (subtype-expression? '(Record ((n UInt required) (flag Bool optional)) closed)
        '(Record ((flag Bool optional) (n Integer required)) closed)) => #t)
      (check (subtype-expression? '(Record ((n UInt required)) closed)
        '(Record ((missing Bool optional) (n Integer required)) closed)) => #t)
      ;; An open source may contain an undeclared incompatible missing field.
      (check (subtype-expression? '(Record ((n UInt required)) open)
        '(Record ((missing Bool optional) (n Integer required)) open)) => #f)
      (check (subtype-expression? '(Record ((n UInt required) (extra Bool optional)) closed)
        '(Record ((n Integer required)) closed)) => #f)
      (check (subtype-expression? '(Record ((n UInt optional)) closed)
        '(Record ((n Integer required)) open)) => #f)
      (check (subtype-expression? '(Record ((n Bool optional)) closed)
        '(Record ((n Integer optional)) open)) => #f)
      ;; The same named protocol continues to require every Object target field.
      (check (subtype-expression? '(Object ((n UInt) (flag Bool)) closed)
        '(Object ((flag Bool) (n Integer)) open)) => #t)
      (check (subtype-expression? '(Object ((n UInt)) closed)
        '(Object ((missing Bool)) open)) => #f))
    (test-case "record read view crosses inference declarations inherited Class and evidence"
      (def events [])
      (def report (service.infer-record-view-service (lambda (event) (set! events (cons event events)))))
      (check-equal? (.get report status) 'unique)
      (check-equal? (.get report solutions) '((Integer)))
      (check-equal? events [])
      (def view (expression-type service.RecordServiceView))
      (def context (.o approved: #t)) (def consumed 0)
      (def action (service.record-service-action (.get report instance) -1 context
        (lambda (record)
          (def observed (validate view record))
          (check-equal? ((.get observed run) -3) 5)
          (check-exception ((.get observed run) #f) TypeError?)
          (check-equal? (.get observed bias) 2)
          (set! consumed (1+ consumed)))))
      (defvalues (evidence next failure) (action context))
      (check-equal? failure #f) (check (eq? next context) => #t)
      (check-equal? consumed 1) (check (eq? (.get evidence context) context) => #t)
      (check (and (member 'hook events) #t) => #t)
      (check-exception ((service.record-service-action (.get report instance) -1 context
        (lambda (_) (set! consumed 99)) 0) context) TypeError?)
      (check-equal? consumed 1))
    (test-case "row replacement composes contravariant calls and invariant Map keys"
      (def wide '(Record ((n Integer required)) open))
      (def narrow '(Record ((flag Bool required) (n UInt required)) closed))
      (def source `(Function (UInt) (,wide)))
      (def target `(Function (Integer) (,narrow)))
      (check (subtype-expression? source target) => #t)
      (check (subtype-expression? `(Map ,narrow <- Keyword) `(Map ,wide <- Keyword)) => #t)
      (check (subtype-expression? `(Map UInt <- ,narrow) `(Map Integer <- ,wide)) => #f)
      (def called (validate (expression-type target)
        (validate (expression-type source) (lambda (record) (abs (.get record n))))))
      (check-equal? (called (.o n: 7 flag: #t)) 7)
      (check-exception (called (.o n: -1 flag: #t)) TypeError?)
      ;; This accepted open source supplies an undeclared value rejected by the
      ;; proposed optional target; therefore absent declaration is not absence.
      (def raw (.o n: 7 missing: #t))
      (validate (expression-type '(Record ((n UInt required)) open)) raw)
      (check-exception (validate (expression-type
        '(Record ((n Integer required) (missing UInt optional)) open)) raw) TypeError?))
    (test-case "finite independent Class oracle checks optional absent and extra observations"
      (def layouts '((Record () closed) (Record () open)
        (Record ((n UInt required)) closed) (Record ((n UInt required)) open)
        (Record ((n Integer optional)) closed) (Record ((n Integer optional)) open)
        (Record ((flag Bool optional) (n Integer required)) closed)
        (Record ((flag Bool optional) (n Integer required)) open)
        (Record ((n UInt required) (flag Bool required)) closed)))
      (def descriptors (map expression-type layouts))
      ;; Four choices per name: absent, nonnegative, negative, Boolean. These
      ;; observations are constructed independently of row-related? and its index.
      (def rows (apply append (map (lambda (n)
        (map (lambda (flag) (object<-alist (append n flag)))
          '(() ((flag . 0)) ((flag . -1)) ((flag . #t)))))
        '(() ((n . 0)) ((n . -1)) ((n . #t))))))
      (for-each (lambda (source left)
        (for-each (lambda (target right)
          (when (subtype-expression? source target)
            (for-each (lambda (raw)
              (def admitted (try (cons #t (validate left raw))
                (catch (cause) (if (TypeError? cause) #f (raise cause)))))
              (when admitted
                (check (element? right (cdr admitted)) => #t)
                (validate right (cdr admitted)))) rows))) layouts descriptors)) layouts descriptors))
    (test-case "failed shared row inference never builds and a fresh request can retry"
      (def partial (specialize-prototype-type service.RecordServiceType '(UInt)))
      (def calls (list (list [] '(Integer) (list service.RecordServiceView))))
      ;; A failed or exhausted search must not execute declaration construction.
      (def (forbidden _) (error "row inference must skip declaration builder"))
      (def none (infer-declared-calls partial '(UInt) calls forbidden))
      (check-equal? (.get none status) 'no-solution)
      (check-equal? (.get none instance) #f)
      (check-exception (infer-declared-calls partial '(UInt Integer) calls forbidden 100)
        (refusal 'exhausted))
      (check-equal? (.get (service.infer-record-view-service) status) 'unique))
    (test-case "kind arity labels and presence markers refuse malformed metadata"
      (for-each (lambda (term) (check-exception (expression-type term) (refusal 'malformed)))
        '((Record) (Record ((n UInt)) open) (Record ((n UInt mutable)) open)
          (Record ((n UInt required) (n Bool optional)) closed)
          (Record ((n UInt required)) (Row UInt))))
      (check-exception (prototype-type (.o .parameters: '(Record)) '(Record) 'Record [])
        (refusal 'malformed)))
    (test-case "Record compilation uses the existing effective Slot protocol"
      (def descriptor (expression-type '(Record ((run (Function (UInt) (Integer)) required)
                                                (extra Bool optional)) closed)))
      (check-equal? (.get descriptor effective-slots extra optional) #t)
      (def raw (.o run: abs)) (def checked (validate descriptor raw))
      (check (eq? (.get raw run) abs) => #t)
      (check-equal? ((.get checked run) -3) 3)
      (check-exception ((.get checked run) #f) TypeError?)
      (check-exception (validate descriptor (.o run: abs unknown: 1)) TypeError?)
      (check-exception (validate descriptor (.o extra: #t)) TypeError?))
    (test-case "literal field labels and presence survive prefix and Mu substitution"
      (def schema (prototype-type (.o .parameters: '(Self Super)) '(Self Super)
        '(Record ((Self Super required) (Super Self optional)) closed) []))
      (def partial (specialize-prototype-type schema '(UInt)))
      (check-equal? (.get partial expression) '(Record ((Self Super required) (Super UInt optional)) closed))
      (check-equal? (.get (instantiate-prototype partial '(Integer)) expression)
                    '(Record ((Self Integer required) (Super UInt optional)) closed))
      (def tree (expression-type '(Mu X 1 (Record ((children (List X) required)) closed))))
      (check (element? tree (.o children: [])) => #t)
      (check-exception (validate tree (.o children: (list (.o children: [])))) TypeError?))
    (test-case "inference closes required callback and optional sibling types together"
      (def audit [])
      (def report (service.infer-record-service '(UInt) '(UInt Integer) observations
        (lambda (event) (set! audit (cons event audit)))))
      (check-equal? (.get report status) 'unique)
      (check-equal? (.get report solutions) '((Integer)))
      (check-equal? audit [])
      (defvalues (record owner) (service.record-service (.get report instance prototype) -2))
      (check-equal? ((.get record run) -3) 5)
      (check-exception ((.get record run) #f) TypeError?)
      (check-equal? (.get record limit) 10)
      (check-equal? (.get record bias) 2)
      (check (.slot? record 'extra) => #f)
      (check (and (member 'hook audit) #t) => #t)
      (check (begin (declared-snapshot owner) #t) => #t))
    (test-case "FUN refinement binds actual Class results before IO and refuses before consumption"
      (def report (service.infer-record-service '(UInt) '(UInt Integer) observations))
      (def instance (.get report instance)) (def context (.o approved: #t)) (def consumed 0)
      (def action (service.record-service-action instance -1 context
        (lambda (record)
          (set! consumed (+ consumed 1))
          (check-exception ((.get record run) #f) TypeError?))))
      (defvalues (evidence next failure) (action context))
      (check-equal? failure #f)
      (check-equal? consumed 1)
      (check (eq? (.get evidence context) context) => #t)
      (check (eq? next context) => #t)
      (check-exception ((service.record-service-action instance -1 context
                         (lambda (_) (set! consumed 99)) 0) context) TypeError?)
      (check-equal? consumed 1))
    (test-case "hook result is checked again and a fresh request can retry"
      (def descriptor (expression-type '(Record ((run (Function (UInt) (Integer)) required)) closed)))
      (def calls 0)
      (def bad (.cc descriptor .instantiate: (lambda (_) (set! calls (+ calls 1)) (.o run: #f))))
      (check-exception (make-instance bad run: abs) TypeError?)
      (check-equal? calls 1)
      (def good (make-instance descriptor run: abs))
      (check-equal? ((.get good run) -4) 4))
    (test-case "closed snapshot prevents inherited extra slots from escaping"
      (def descriptor (expression-type '(Record ((n UInt required)) closed)))
      (def actual (Record n: [UInt default: 1] extra: [UInt default: 2]))
      (check-exception (validate descriptor (make-instance actual)) TypeError?))
    (test-case "optional callbacks are checked when present without invented defaults"
      (def descriptor (expression-type '(Record ((run (Function (UInt) (UInt)) optional)) closed)))
      (check (element? descriptor (make-instance descriptor)) => #t)
      (check-exception ((.get (make-instance descriptor run: values) run) -1) TypeError?)
      (check-exception (make-instance descriptor run: #f) TypeError?))
    (test-case "conflicting record obligations and exhausted search never construct a Class"
      (def built 0)
      ;; One incomplete or inconsistent request cannot execute a staged builder.
      (def (builder _) (set! built (+ built 1)) [])
      (def schema (specialize-prototype-type service.RecordServiceType '(UInt)))
      (def contradictory (list (list [] '(Bool) (list expected))))
      (check-equal? (.get (infer-declared-calls schema '(UInt Integer) contradictory builder) status) 'no-solution)
      (check-equal? built 0)
      (check-exception (infer-declared-calls schema '(UInt Integer) observations builder 16) (refusal 'exhausted))
      (check-equal? built 0)
      (check-equal? (.get (service.infer-record-service '(UInt) '(UInt Integer) observations) status) 'unique))
    (test-case "unsupported method catalogs cannot silently skip Record signatures"
      ;; Record expressions describe DATA callbacks. Typed groups use an explicit
      ;; Object catalog: treating optional Class fields as required generics would
      ;; change both absence and initialization semantics.
      (check-exception (instantiate-declared
        (prototype-type (.o .parameters: '(Self)) '(Self)
          '(Record ((run (Function (Self) (Self)) required)) closed) []) '(UInt)
        (lambda (_) (error "builder demanded"))) (refusal 'unsupported))
      (check-exception (infer-declared-calls
        (prototype-type (.o .parameters: '(Self)) '(Self)
          '(Record ((run (Function (Self) (Self)) required)) closed) [])
        '(UInt) '(((run) (UInt) (UInt))) (lambda (_) (error "builder demanded")))
        (refusal 'unsupported)))))
