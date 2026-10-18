;;-*- Gerbil -*-
;;; Classes on top of POO
;; Slogan: A Type meta-object as a prototype is a class descriptor,
;; as an instance is a type descriptor.

(export #t (import: ./slot-observation))

(import
  ./slot-observation
  ./value-diagnostics
  ./function-signature
  ./class-validation
  (only-in :std/error deferror-class defraise/context)
  (only-in :std/list/list-builder with-list-builder)
  (only-in :std/list/list pop! append-map foldr delete-duplicates/hash)
  (only-in :std/list/walist walist)
  (for-syntax (only-in :std/list/plist plist?)
              (only-in :std/list/alist plist->alist))
  (only-in :std/values list->values)
  (only-in :std/func compose)
  (only-in ./support/base λ nest invalid)
  (only-in ./support/io u8vector<-<-marshal <-u8vector<-unmarshal
           marshal<-u8vector<- unmarshal<-<-u8vector
           marshal-sized16-u8vector unmarshal-sized16-u8vector)
  (only-in ./support/json string<-json json<-string)
  (only-in ./support/syntax call<-formals)
  (only-in ./support/repr repr pr)
  (only-in ./object object object? .def/ctx .cc .mix .ref .@ .get .has? .call
           .all-slots with-slots .slot? .putslot! .putdefault! .for-each!
           NoApplicableMethod? NoApplicableMethod-self NoApplicableMethod-slot
           .alist object<-alist
           $constant-slot-spec $computed-slot-spec)
  (prefix-in (only-in :gerbil/core @method) @)
  (only-in ./brace @method))

;; * Options
;; default: default value when no method is defined, also bottom value for fixed-point
;; from: one of the symbols instance (default), or type. Specifies who provides methods
;;   for the generic function: the instance directly, or its .type field, respectively.
;; slot: slot-name can specify an alternate slot-name, which helps avoid with-slot shadowing
;;   when calling the gf from a method definition.
;; combination: optional (fragments arguments -> result) interpreter for the raw
;; slot's inherited fragment list. Metadata assembly remains in ordinary .ref.
;; TODO: make this information somehow available at compile-time when possible,
;;   to enable inlining and partial evaluation.
(defsyntax (.defgeneric stx) ;; define a generic function that invokes the prototype's slot
  ;; Admit syntax shape with standard plist operations, then apply POO policy.
  (def (parse-options options)
    (def slot-name #f)
    (def compute-default #f)
    (def from #f)
    (def combination #f)
    ;; Gerbil owns alternating-list structure. POO only interprets option names,
    ;; duplicate/alias policy and syntax bindings; no value expression executes.
    (unless (plist? options)
      (error "invalid options" options (syntax->datum options)))
    (for-each (lambda (entry)
      (match entry
        ([kw . val]
         (match (syntax-e kw)
           (slot:
            (when slot-name (error "slot-name set twice" stx))
            (set! slot-name val))
           (combination:
            (when combination (error "combination set twice" stx))
            (set! combination val))
           (from:
            (when from (error "from set twice" stx))
            (case (syntax-e val)
              ((type) (set! from 'type))
              ((instance) (set! from 'instance))
              (else (error "invalid option" stx val))))
           (compute-default:
            (when compute-default (error "default set twice" stx))
            (set! compute-default val))
           (default:
            (when compute-default (error "default set twice" stx))
            (set! compute-default (with-syntax ((expr val)) #'(lambda (_1 _2) expr))))
           (x (error "invalid option" x stx)))))) (plist->alist options))
    (values slot-name compute-default (or from 'instance) combination))
  (syntax-case stx ()
    ((.defgeneric (gf self . formals) options ...)
     (begin
       (define-values (slot-name compute-default from combination) (parse-options (syntax->list #'(options ...))))
       (with-syntax* ((slot-name (or slot-name (make-symbol "." (syntax->datum #'gf))))
                      (methods (case from
                                 ((instance) #'self)
                                 ((type) #'(.get self .type))
                                 (else (error "invalid from" (syntax->datum stx)))))
                      (method (if compute-default
                                (with-syntax ((compute-default compute-default))
                                  #'(try (.ref methods 'slot-name)
                                         (catch (NoApplicableMethod? cause)
                                           (if (and (eq? (NoApplicableMethod-self cause) methods)
                                                    (eq? (NoApplicableMethod-slot cause) 'slot-name))
                                             (compute-default self 'slot-name) (raise cause)))))
                                #'(.ref methods 'slot-name)))
                      (invoker (if combination
                                 (with-syntax ((combine combination)) #'(combine-method combine method))
                                 #'method))
                      ((selfvar ...) (case from ((type) #'(self)) ((instance) #'())))
                      (body (if (and (stx-null? #'formals) (eq? from 'instance) (not combination))
                              #'method
                              (call<-formals #'(invoker selfvar ...) #'formals))))
           #'(def (gf self . formals) body))))))

;; Adapt raw inherited fragments to the generic's normal argument forwarding.
;; The combiner owns qualifier admission; body failures are not missing-slot defaults.
;; Nothing memoizes a result or an approval, and from:type still forwards self once.
(def (combine-method combine fragments)
  (unless (procedure? combine) (error "generic combination must be a procedure"))
  (lambda arguments (combine fragments arguments)))

;;(def (and-combination new-value old-value) (and (new-value dont-call-next-method) (old-value)))

(defrule (.call.method object slot args ...) ((.get object .type slot) object args ...))

(.defgeneric (element? type x)
   ;;default: false
   ;;combination: and-combination
   slot: .element?)

;;; SEXP from values

;; gf to extract a source sexp from a value of given type
(.defgeneric (sexp<- type x) slot: .sexp<-)

(def (:sexp x)
  (if (object? x)
    (cond
     ((.has? x .type .sexp<-) (.call (.@ x .type) .sexp<- x))
     ((.has? x sexp) (.@ x sexp))
     (else x))
    (if (or (number? x) (boolean? x) (string? x) (char? x)
            (void? x) (keyword? x) (eof-object? x))
      x
      `',x)))

;; gf to extract a value of given type from some json
(.defgeneric (<-json type j) slot: .<-json)
;; gf to extract some json from a value of given type
(.defgeneric (json<- type x) slot: .json<-)

;; For now, types are just runtime descriptors...
(defsyntax (define-type stx)
  (syntax-case stx ()
    ((_ name desc) (identifier? #'name)
     #'(def name (.cc desc sexp: 'name)))
    ((_ (name opts ...) spec ...) (identifier? #'name)
     (with-syntax ((ctx stx))
       #'(.def/ctx ctx (name opts ...) sexp: 'name spec ...)))))

(define-type (Type. @ [])
  .type: Type
  ;; NB: either `validate` or `element?` can be primary, with the other method deduced from it.
  ;; But if you fail to override either, it's bottomless mutual recursion calling them.
  .element?: ;; : GeneralizedBool <- Any ;; is this an element of this type? -- #f or maybe useful data
  (lambda (x) (try (.validate x) #t (catch (_) #f)))
  .validate: ;; : @ <- Any ?(List Any) ;; identity for an @, throws a type-error if input isn't a @
  (lambda (x) (if (.element? x) x (raise-type-error (TV Type @) x))))

(def (display-object l (port (current-output-port)))
  (let d ((space? #f))
    (unless (null? l)
      (let (x (pop! l))
        (when (and space? (not (string? x))) (display " " port))
        (cond
         ((string? x)
          (display x port) (d #f))
         ((or (symbol? x) (keyword? x))
          (display x port) (d #t))
         ((element? Type x)
          (write (sexp<- x (pop! l)) port) (d #t))
         (else (pr x port) (d #t)))))))

(def (display-object-ln . l)
  (def port (current-output-port))
  (display-object l port)
  (newline port)
  (force-output port))

(deferror-class TypeError ())
(defraise/context (raise-type-error where irritants ...)
  (TypeError "type error" irritants: [irritants ...]))

;; Optional positional/keyword defaults and rest forwarding use support/syntax;
;; defaults resolve at the generic boundary before any method/combiner invocation.
;; TODO: use macro that leaves source info by default, returns a function when passed as argument.
(def (validate type x) (.call type .validate x))

;; Any accepts any Scheme object, but only does best effort at printing, invalid reading
(define-type (Any @ [Type.])
  .element?: true
  .sexp<-: (lambda (x) (if (or (pair? x) (null? x) (symbol? x)) (list 'quote x) x))
  .string<-: repr .<-string: invalid
  .bytes<-: (compose string->bytes .string<-)
  .<-bytes: (compose .<-string bytes->string)
  .json<-: .string<- .<-json: .<-string
  .marshal: (lambda (x port) (marshal-sized16-u8vector (.bytes<- x) port))
  .unmarshal: (lambda (port) (.<-bytes (unmarshal-sized16-u8vector port)))
  .=?: equal?)

(define-type (Object @ Type.)
  .element?: object? .sexp<-: identity) ;; TODO: improve on that

(define-type (Bool @ Type.)
  .length-in-bytes: 1
  .element?: boolean?
  .sexp<-: identity
  .json<-: identity
  .<-json: (cut validate @ <>)
  .bytes<-: (lambda (x) (if x #u8(1) #u8(0)))
  .<-bytes: (λ (b) (< 0 (u8vector-ref b 0)))
  .marshal: (marshal<-u8vector<- .bytes<-)
  .unmarshal: (unmarshal<-<-u8vector .<-bytes .length-in-bytes))

(def (object-values x) (map (cut .ref x <>) (.all-slots x)))
(def (monomorphic-object? type x)
  (and (object? x) (every (cut element? type <>) (object-values x))))

(define-type (MonomorphicObject. @ Type. type) ;; all the values are of given type
  .element?: (cut monomorphic-object? type <>)
  .sexp<-: (lambda (x) `(.o ,@(append-map (match <> ([s . v] [(make-keyword s) (sexp<- type v)])) (.alist x))))
  .json<-: (lambda (x) (list->hash-table (map (match <> ([s . v] (cons s (json<- type v)))) (.alist x))))
  .<-json: (lambda (j) (object<-alist (map (match <> ([s . v] (cons (make-symbol s) (<-json type v)))) (hash->list j)))))

(def (MonomorphicObject type) {(:: @ MonomorphicObject.) type
                               sexp: `(MonomorphicObject ,(.@ type sexp))})
(def ObjectObject (MonomorphicObject Object))
(def (map-object-values f object)
  (object<-alist (map (lambda (slot) (cons slot (f (.ref object slot)))) (.all-slots object))))

;; Function descriptors preserve supplied optional/keyword/rest values; the host
;; target still owns its defaults and actual arity. Recognition remains procedure?.
;; TODO: Deduplicate wrappers across contracts/continuations without changing tail calls.
;; TODO: Incremental amortized O(1) recursive-data validation needs its own cache laws.
(define-type (Function. @ Type. outputs inputs)
  optional: [] keywords: [] required-keywords: [] rest: #f
  signatures: (list @)
  .element?: procedure?
  .validate: (lambda (f) (wrap-function @ f signatures validate (lambda (type value) (raise-type-error type value))))
  arity: (length inputs))

;; Check every declaration before installing a wrapper; duplicate or missing keyword
;; declarations are malformed descriptors, not target procedure failures.
(def (Function outputs inputs optional: (optional []) keywords: (keywords [])
               required-keywords: (required-keywords []) rest: (rest #f))
  (for-each (lambda (row)
    (unless (list? row) (error "Function types must form a proper list"))
    (for-each (cut validate Type <>) row)) (list outputs inputs optional))
  (unless (and (list? keywords) (every (lambda (entry) (and (pair? entry) (keyword? (car entry)))) keywords)
               (list? required-keywords) (every keyword? required-keywords))
    (error "invalid Function keyword declaration"))
  (def names (map car keywords))
  (unless (and (= (length names) (length (delete-duplicates/hash names)))
               (= (length required-keywords) (length (delete-duplicates/hash required-keywords)))
               (every (cut memq <> names) required-keywords))
    (error "duplicate or undeclared Function keyword"))
  (for-each (lambda (entry) (validate Type (cdr entry))) keywords)
  (when rest (validate Type rest))
  {(:: @ Function.) (outputs) (inputs) (optional) (keywords) (required-keywords) (rest)
   sexp: `(Function (@list ,@(map (cut .@ <> sexp) outputs))
                    (@list ,@(map (cut .@ <> sexp) inputs))
                    ,@(if (and (null? optional) (null? keywords) (not rest)) []
                      `(optional: (@list ,@(map (cut .@ <> sexp) optional))
                        keywords: (@list ,@(map (lambda (entry)
                          `(cons ,(car entry) ,(.@ (cdr entry) sexp))) keywords))
                        required-keywords: (quote ,required-keywords)
                        rest: ,(and rest (.@ rest sexp)))))})

;; Ordered signature alternatives share the normal Function Type and recursive
;; wrapping path. Structural first-match selection never probes a function body.
(def (CaseFunction . cases)
  (unless (and (pair? cases) (every (lambda (case)
      (and (object? case) (element? Type case) (.has? case signatures)
           (let (signatures (.get case signatures))
             (and (= (length signatures) 1) (eq? (car signatures) case))))) cases))
    (error "CaseFunction requires nonempty single-signature Functions"))
  (.cc Function. outputs: [] inputs: [] signatures: cases
       arity: (apply min (map (lambda (case) (.get case arity)) cases))
       sexp: `(CaseFunction ,@(map (cut .@ <> sexp) cases))))

;; The expander complains "Syntax Error: Ambiguous pattern".
;; TODO: Use syntax-case, detect when there are opposite arrows, curry when there are multiple ones?
;; With no arrow, it's a thunk (no inputs) with the given outputs.
(begin-syntax
  ;; V19 removed SRFI-1's list-index. Keep the O(n) helper private to this
  ;; transformer; split-at is provided by the Gerbil runtime.
  (def (syntax-list-index pred xs)
    (let loop ((xs xs) (index 0))
      (cond ((null? xs) #f)
            ((pred (car xs)) index)
            (else (loop (cdr xs) (1+ index)))))))

(defsyntax (Fun stx)
  (syntax-case stx ()
    ((_ . io)
     (let (iol (syntax->list #'io))
       (cond
        ((syntax-list-index (lambda (x) (eq? (stx-e x) '<-)) iol)
         => (lambda (k)
              (defvalues (outputs inputs) (split-at iol k))
              (let loop ((o outputs) (i (cdr inputs)))
                (cond
                 ((syntax-list-index (lambda (x) (eq? (stx-e x) '<-)) i)
                  => (lambda (k)
                       (defvalues (inputs moreinputs) (split-at i k))
                       (loop [[#'Function [#'@list . o] [#'@list . inputs]]] (cdr moreinputs))))
                 (else [#'Function [#'@list . o] [#'@list . i]])))))
        ((syntax-list-index (lambda (x) (eq? (stx-e x) '->)) iol)
         => (lambda (k)
              (defvalues (inputs ios) (split-at iol k))
              (let loop ((i inputs) (iol (cdr ios)))
                (cond
                 ((syntax-list-index (lambda (x) (eq? (stx-e x) '->)) i)
                  => (lambda (k)
                       (defvalues (inputs moreios) (split-at i k))
                       [#'Function [#'@list (loop inputs (cdr moreios))] [#'@list . i]]))
                 (else [#'Function [#'@list . iol] [#'@list . i]])))))
        (else
         [#'Function [#'@list . iol] []]))))))

(.defgeneric (slot-checker slot-descriptor slot-name x) slot: .slot.check from: type)
(.defgeneric (slot-definer slot-descriptor slot-name x) slot: .slot.define from: type)

(define-type (Class. class Type. slots sexp sealed) ;; this is the class descriptor for class descriptor objects.
  .type: Class
  effective-slots:
   (let (slot-base (.@ .type slot-descriptor-class proto))
     (map-object-values (cut .mix <> slot-base) slots))
  .element?:
   (λ (x)
     (and (object? x)
          (every (λ (slot-name)
                   (def slot (.ref effective-slots slot-name))
                   (slot-checker slot slot-name x))
                 (.all-slots effective-slots))
          (or (not sealed) ;; sealed means only defined slots can be present.
              (every (cut .slot? effective-slots <>) (.all-slots x)))))
  ;; Finite graph closure uses the same selected field normalizers without
  ;; invoking initialization hooks or forcing a partly allocated peer receiver.
  .validation-fields: (lambda (value) (class-validation-fields class value))
  ;; Class validation wraps effective typed fields before final membership.
  .validate: (lambda (value) (validate-class class value
                        (lambda (descriptor candidate details)
                          (raise-type-error descriptor candidate details))))
  .diagnose-shape: (lambda (value location (check-field diagnose-structure))
                     (class-shape class value location check-field))
  .diagnose: (lambda (value location) (class-diagnostics class value location))
  slots: ? {}
  sealed: ? #f
  ;;slots: {.type: {type: Type default: class hidden: #t}} ;; should it be optional?
  proto:
   (let (p {})
     (for-each (λ (slot-name)
                 (def slot (.ref effective-slots slot-name))
                 (slot-definer slot slot-name p))
               (.all-slots effective-slots))
     p)
  .sexp<-: (lambda (v) `(instance ,sexp
                     ,@(with-list-builder (c)
                         (def (add s v) (c (make-keyword s)) (c v))
                         (.for-each! effective-slots
                                     (lambda (name slot) (.call.method slot .slot.sexp<- name v add))))))
  .string<-: (compose string<-json .json<-)
  .<-string: (compose .<-json json<-string)
  .json<-: (lambda (v) (walist
                   (with-list-builder (c)
                     (def (add s v) (c (cons (symbol->string s) v)))
                     (.for-each! effective-slots
                                 (lambda (name slot) (.call.method slot .slot.json<- name v add))))))
  .<-json: (lambda (j)
             (object<-alist supers: proto
              (with-list-builder (c)
                (def add (compose c cons))
                (.for-each! effective-slots
                            (lambda (name slot) (.call.method slot .slot.<-json name j add))))))
  .marshal: (lambda (v port)
              (.for-each! effective-slots
                          (lambda (name slot) (.call.method slot .slot.marshal name v port))))
  .unmarshal: (lambda (port)
                (object<-alist supers: proto
                 (with-list-builder (c)
                   (def add (compose c cons))
                   (.for-each! effective-slots
                               (lambda (name slot) (.call.method slot .slot.unmarshal name port add))))))
  .bytes<-: (u8vector<-<-marshal .marshal)
  .<-bytes: (<-u8vector<-unmarshal .unmarshal)
  .tuple-list<-: (lambda (x) (map (lambda (s) (.ref x s)) (.all-slots effective-slots)))
  .<-tuple-list: (lambda (x) (object<-alist (map (lambda (s v) (cons s v)) (.all-slots effective-slots) x)))
  .tuple<-: (compose list->vector .tuple-list<-)
  .<-tuple: (compose .<-tuple-list vector->list))

(define-type (Slot @ Class.)
  slots:
   {type: {type: Type optional: #t}
    constant: {type: Any optional: #t}
    compute: {type: (Fun Any <- Object (Fun Any <-)) optional: #t} ;; a function that takes self and superfun, suitable to be passed to $computed-slot-spec
    default: {type: Any optional: #t}
    optional: {type: Bool default: #f}
    hidden: {type: Bool default: #f}}
  proto: {.type: @ optional: #f hidden: #f}
  .effectively-optional?: (lambda (x) (or (.@ x optional?) (.has? x default)))
  .slot.check:
    (λ (@@ slot-name x)
      (with-slots (type constant optional) @@
        (if (.slot? x slot-name)
          (let ((value (.ref x slot-name)))
            (and
              (or (not (.has? @@ type)) (element? type value))
              (or (not (.has? @@ constant)) (equal? constant value))))
          (and (.has? @@ optional) optional))))
  ;; Shape and validation are separate overridable Slot methods. Class checks
  ;; final .slot.check after every changed field has been persistently installed.
  .slot.shape: (lambda (@@ name candidate location check-field)
                 (class-slot-shape @@ name candidate location check-field))
  .slot.validate: (lambda (@@ name original receiver)
                    (class-slot-validate @@ name original receiver))
  .slot.define:
    (λ (@@ slot-name x)
       (with-slots (type constant compute default) @@
         (cond
          ((.has? @@ constant) (.putslot! x slot-name ($constant-slot-spec constant)))
          ((.has? @@ compute) (.putslot! x slot-name ($computed-slot-spec compute)))
          ((.has? @@ default) (.putdefault! x slot-name default))
          ((and (.has? @@ type) (.has? type proto))
           (.putslot! x slot-name ($constant-slot-spec (.@ type proto)))))))
    ;;TODO: (put-assertion! x (λ (self) (assert! (slot-checker slot-name self))))
  .slot.marshal:
    (λ (@@ slot-name x port)
      (with-slots (type constant optional default) @@
        (unless (.has? @@ constant)
          (let (default? (.has? @@ default))
            (cond
             ((or optional default?)
              (if (or (not (.slot? x slot-name))
                      (and default? (equal? (.ref x slot-name) default)))
                (write-u8 0 port)
                (begin
                  (write-u8 1 port)
                  (.call type .marshal (.ref x slot-name) port))))
             ((.slot? x slot-name)
              (.call type .marshal (.ref x slot-name) port))
             (else (error "Can't marshal missing slot" slot-name x)))))))
  .slot.unmarshal:
    (λ (@@ slot-name port add)
       (with-slots (type constant optional default) @@
         (unless (.has? @@ constant)
           (let (default? (.has? @@ default))
             (cond
              ((or optional default?)
               (match (read-u8 port)
                 (0 (when default? (add slot-name default)))
                 (1 (add slot-name (.call type .unmarshal port)))))
              (else (add slot-name (.call type .unmarshal port))))))))
  .slot.sexp<-:
    (λ (@@ slot-name x c)
      (with-slots (type constant optional default) @@
        (unless (.has? @@ constant)
          (let (default? (.has? @@ default))
            (cond
             ((or optional default?)
              (when (and (.slot? x slot-name)
                         (not (and default? (equal? (.ref x slot-name) default))))
                (c slot-name (.call type .sexp<- (.ref x slot-name)))))
             ((.slot? x slot-name)
              (c slot-name (.call type .sexp<- (.ref x slot-name))))
             (else (error "Can't convert missing slot to sexp" slot-name x)))))))
  .slot.json<-:
    (λ (@@ slot-name x c)
      (with-slots (type constant optional default) @@
        (unless (.has? @@ constant)
          (let (default? (.has? @@ default))
            (cond
             ((or optional default?)
              (when (and (.slot? x slot-name)
                         (not (and default? (equal? (.ref x slot-name) default))))
                (c slot-name (.call type .json<- (.ref x slot-name)))))
             ((.slot? x slot-name)
              (c slot-name (.call type .json<- (.ref x slot-name))))
             (else (error "Can't convert missing slot to json" slot-name x)))))))
  .slot.<-json:
    (λ (@@ slot-name j c)
       (with-slots (type constant optional default) @@
         (unless (.has? @@ constant)
           (let (key (symbol->string slot-name))
             (cond
              ((hash-key? j key) (c slot-name (.call type .<-json (hash-ref j key))))
              ((.has? @@ default) (c slot-name default))
              (optional (void))
              (else (error "Missing slot in json" slot-name j))))))))
(def Slot. (.@ Slot proto))

;; Functional get/set lenses compose through arbitrary nested immutable storage.
;; .lens / slots-lens below reuse this same protocol for static/dynamic paths.
(define-type (Lens @ Class.) ;; Lens 's 'a
  slots: =>.+ { ;; or should we have just a ((f a) <- (f : Functor) ((f b) <- b) a) ?
    .get: { } ;; 's -> 'a
    .set: { }} ;; 'a -> 's -> 's
  .get: (lambda (l s) (.call l .get s))
  .set: (lambda (l a s) (.call l .set a s))
  .modify: (lambda (l f s)
             (.call l .set (f (.call l .get s)) s)) ;; over in haskell
  ;; Same order as in Haskell, opposite to OCaml. (compose x y) will access x then y
  ;; (Lens 'a 'c)  <- (Lens 'a 'b) (Lens 'b 'c)
  .compose: (lambda (l1 l2) {.get: (lambda (s) (.call l2 .get (.call l1 .get s)))
                        .set: (lambda (a s) (.modify l1 (cut .call l2 .set a <>) s))}))

(define-type (Type @ Class.)
  slots: {sexp: {type: Any}
          .element?: {type: (Fun Bool <- Any)}}
  .element?: (λ (x) (and (object? x) (.has? x sexp) (.has? x .element?)))
  ;; Type bootstrap validation recognizes descriptor structure and retains its
  ;; identity; it must not recursively wrap the descriptor's own .element? method.
  .validate: (lambda (value) (if (.element? value) value (raise-type-error @ value)))
  .sexp<-: (lambda (x) (.@ x sexp)) ;; : SEXP <- @
  proto: Type.)

(define-type (Class @ Type)
   slot-descriptor-class: Slot ;; MOP magic!
   slots: =>.+
    {slots: {type: ObjectObject} ;; would be (MonomorphicObject Slot) if we didn't automatically append Slot
     sealed: {type: Bool default: #f}}
   proto: Class.)

(def (instance class . plist) (apply .cc (.@ class proto) plist))

;; Existing .new syntax constructs lazily. Use make-instance / .new/checked for
;; explicit class validation and construction-time hooks, before publication.
(defrules .new ()
  ((_ (class self slots ...) slot-defs ...)
   {(:: self (.@ class proto) slots ...) slot-defs ...})
  ((_ (class) slot-defs ...)
   {(:: self (.@ class proto)) slot-defs ...})
  ((_ class slot-defs ...)
   {(:: self (.@ class proto)) slot-defs ...}))

;; Instantiate through the CURRENT class validation and optional .instantiate
;; hook. Invalid input never reaches the hook; its returned replacement is checked
;; again. Exceptions propagate; external callback effects are not rolled back.
(def (instantiate class value)
  (def checked (validate class value))
  (if (.has? class .instantiate)
    (validate class (.call class .instantiate checked)) checked))
;; Checked runtime constructor; instance and .new retain explicit lazy construction.
(def (make-instance class . plist)
  (instantiate class (apply instance class plist)))
;; Checked syntax reuses ALL existing object-binding syntax, evaluating class once.
;; Class constraints and the hook complete before the new value reaches its caller.
(defsyntax (.new/checked stx)
  (syntax-case stx ()
    ((_ (class self slots ...) slot-defs ...) (identifier? #'self)
     #'(let (descriptor class)
         (instantiate descriptor (.new (descriptor self slots ...) slot-defs ...))))
    ((_ (class) slot-defs ...) (identifier? #'class)
     #'(.new/checked class slot-defs ...))
    ((_ class slot-defs ...)
     #'(let (descriptor class) (instantiate descriptor (.new descriptor slot-defs ...))))))

(defrules .defclass ()
  ((_ (class class-options ...) (slotdefs ...) options ...)
   (define-type (class class-options ...) (slots =>.+ {slotdefs ...}) options ...))
  ((_ class (slotdefs ...) options ...)
   (.defclass (class) (slotdefs ...) options ...)))

;; Build the existing Lens protocol from pure callbacks, matching MonoLens.ofGetSet.
;; Get/set laws remain caller premises; functions do not prove those laws by shape.
(def (lens-of-get-set getter setter)
  (unless (and (procedure? getter) (procedure? setter)) (error "lens callbacks required"))
  (instance Lens .get: getter .set: setter))

;; Focus one native POO slot with persistent updates; the original object is retained.
(def (slot-lens slot-name)
  {(:: @ (instance Lens))
   .get: (lambda (s) (.ref s slot-name))
   .set: (lambda (x s) (.cc s slot-name x))})

;; Compose a validated dynamic slot path through the standard Lens protocol.
;; Empty path is identity. Laws require suitable immutable storage, just as for
;; slot-lens; arbitrary dependent/refining slots do not acquire laws by syntax.
(def (slots-lens slots)
  (unless (and (list? slots) (andmap symbol? slots)) (error "symbol slot path required"))
  (foldr (lambda (slot rest) (.call Lens .compose (slot-lens slot) rest))
    (lens-of-get-set identity (lambda (value _) value)) slots))
;; Static slot path syntax expands only to the existing dynamic constructor.
(defrule (.lens slot ...) (slots-lens '(slot ...)))

;; Explicit .parameters metadata and persistent prefix binding are implemented in
;; parameters.ss; validation/effect execution remains a separate checked consumer.
