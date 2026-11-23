;; the ctx argument exists for macro-scope purposes
;; TODO: use a syntax-parameter for self instead of the ctx argument?
;; Parse the lexical option prefix or legacy :: form before shared slot lowering.
(defsyntax (.o/ctx stx)
  (syntax-case stx ()
    ((_ ctx (:: self) specs ...) #'(object/slots ctx self [] () specs ...))
    ((_ ctx (:: self parents slots ...) specs ...)
     #'(object/slots ctx self parents (slots ...) specs ...))
    ((_ ctx () specs ...) #'(object/slots ctx self [] () specs ...))
    ((_ ctx specs ...)
     (let-values (((self super parents bindings include? rest)
                   (parse-object-options #'ctx #'(specs ...))))
       (with-syntax ((self self) (super super) (parents parents)
                     (bindings bindings) (include? include?) (rest rest))
         #'(object/configured ctx self parents bindings include? super . rest))))))

;; the ctx argument exists for macro-scope purposes
(defrule (object/slots ctx self parents bindings specs ...)
  (object/configured ctx self parents bindings #t #f specs ...))

;; Lower all construction syntax to the same slot/default/inheritance engine.
;; The optional super name denotes the current slot's inherited computation,
;; matching $slot-gen, and never reifies another slot's super-instance.
(defsyntax (object/configured stx)
  (syntax-case stx ()
    ((_ ctx self parents (bindings ...) include? super . slot-specs)
     (let* ((normalized (normalize-slot-specs #'ctx #'slot-specs))
            (methods (car normalized)) (defaults (cadr normalized))
            (names (append (map stx-car defaults) (map stx-car methods)))
            (selected (append (syntax->list #'(bindings ...))
                              (if (syntax-e #'include?) names []))))
       (when (and (identifier? #'super) (bound-identifier=? #'self #'super))
         (raise-syntax-error #f "self and super must be distinct" stx))
       (for-each (lambda (name)
         (when (or (bound-identifier=? name #'self)
                   (and (identifier? #'super) (bound-identifier=? name #'super)))
           (raise-syntax-error #f "slot binding conflicts with self or super" stx name))) selected)
       ;; Preserve lexical slot capture; only actual computed formulas need
       ;; the inherited computation alias. Explicit per-slot names keep working.
       (def transformed (if (eq? (syntax-e #'super) #f) methods
         (map (lambda (spec)
           (with-syntax ((super #'super))
             (syntax-case spec (:= => =>.+)
               ((name) spec)
               ((name := form) spec)
               ((name => form args ...) #'(name (super) (form (super) args ...)))
               ((name =>.+ args ...) #'(name (super) (.+ (super) args ...)))
               ((name (next) form) #'(name (next) (let ((super next)) form)))
               ((name form) #'(name (super) form))))) methods)))
       (def prepared (prepare-shared-slot-specs transformed))
       (with-syntax (((selected ...) selected)
                     (((default-slot . default-value) ...) defaults)
                     (((constant-id constant-value) ...) (car prepared))
                     (((prepared-slot prepared-spec ...) ...) (cadr prepared)))
         #'(let ((constant-id constant-value) ...)
             (object/init self parents (selected ...)
                          ((default-slot . default-value) ...)
                          (prepared-slot prepared-spec ...) ...)))))))

(defrule (object/defaults (default-slot default-value) ...)
  (list (cons 'default-slot default-value) ...))

(defrule (object/init self super slots ((default-slot default-value) ...) (slot slotspec ...) ...)
  (make-object
   supers: super
   slots: (prototype-map
            (%with-shared-slot-bindings slots (slot-self)
              (list (cons 'slot (object/slot-spec %with-shared-slots slot-self self slots slot slotspec ...)) ...))
            policy: 'compact)
   defaults: (prototype-map (object/defaults (default-slot default-value) ...) policy: 'compact)))

(defrules object/slot-spec (=> =>.+ lexical-slot-value)
  ((_ scope slot-self self slots slot lexical-slot-value value)
   ($constant-slot-spec value))
  ((_ scope slot-self self slots slot form)
   ($self-slot-spec (lambda (self)
    (scope slot-self slots self form))))
  ((_ scope slot-self self slots slot => form args ...)
   ($computed-slot-spec (lambda (self superfun)
    (scope slot-self slots self (form (superfun) args ...)))))
  ((_ scope slot-self self slots slot =>.+ args ...)
   (object/slot-spec scope slot-self self slots slot => .+ args ...))
  ((_ scope slot-self self slots slot (next-method) form)
   ($computed-slot-spec (lambda (self superfun)
     (defonce (next-method) (superfun))
     (scope slot-self slots self form))))
  ((_ scope slot-self self slots slot)
   ($constant-slot-spec slot)))

(defsyntax (%with-slots stx)
  (syntax-case stx ()
    ((_ (slots ...) self body ...)
     (with-syntax (((slot ...) (deduplicate-slot-identifiers #'(slots ...))))
       #'(let-id-rule ((slot (.@ self slot)) ...) body ...)))))

;; Core syntax parameters own receiver scope and its unbound-scope error. Core
;; identifier-rules owns field identifier/application expansion and lexical binding.
;; The shared parameter is rebound only while expanding a particular method body;
;; no custom transformer factory or syntax-tree substitution remains in this path.
(defsyntax (%with-shared-slot-bindings stx)
  (syntax-case stx ()
    ((_ (slots ...) (slot-self) body ...)
     (with-syntax (((slot ...) (deduplicate-slot-identifiers #'(slots ...))))
       #'(let ()
           (defsyntax-parameter* receiver slot-self "slot reference outside object method scope")
           (let-syntax ((slot (identifier-rules (set!)
                               ((set! _ value) (syntax-error "slot binding is read-only"))
                               ((_ . args) ((.ref receiver 'slot) . args))
                               (_ (.ref receiver 'slot)))) ...)
             body ...))))))

(defrule (%with-shared-slots slot-self _ self body ...)
  (syntax-parameterize ((slot-self (quote-syntax self))) body ...))

(defrule (%with-direct-slots _ slots self body ...)
  (%with-slots slots self body ...))

(defrules with-slots ()
  ((_ () self body ...) (begin body ...))
  ((_ (slots ...) self body ...) (let (object self) (%with-slots (slots ...) object body ...))))

(defrule (def-slots (slot ...) self)
  (begin
    (def object self)
    (defvalues (slot ...) (values (.@ object slot) ...))))

;; Lower the whole prefixed lexical binding group at once. Gerbil owns syntax
;; traversal and foldr retains nested identifier scopes, including repeated
;; names. Only the explicit context determines generated identifiers. The receiver
;; expression remains lazy and is reevaluated at each use, as before.
(defsyntax (with-prefixed-slots input)
  (syntax-case input ()
    ((_ (prefix slot ...) self body ...)
     #'(with-prefixed-slots prefix (prefix slot ...) self body ...))
    ((_ ctx (prefix slot ...) self body ...)
     (foldr (lambda (slot tail)
       (with-syntax ((var (stx-identifier #'ctx #'prefix slot))
                     (slot slot) (tail tail))
         #'(let-syntax ((var (identifier-rules ()
                              ((_ . args) ((.@ self slot) . args))
                              (_ (.@ self slot))))) tail)))
       #'(begin body ...) (syntax->list #'(slot ...))))))

;; Snapshot prefixed fields with one core definition sequence. Template ellipsis
;; replaces recursive macro invocations; definitions still read in source order,
;; reevaluate the receiver per field and stop at the first failure. These bindings
;; retain their captured values after the receiver's source or metadata changes.
(defsyntax (def-prefixed-slots input)
  (syntax-case input ()
    ((_ (prefix slot ...) self)
     #'(def-prefixed-slots prefix (prefix slot ...) self))
    ((_ ctx (prefix slot ...) self)
     (with-syntax (((var ...) (stx-map (lambda (slot)
                      (stx-identifier #'ctx #'prefix slot)) #'(slot ...))))
       #'(begin (def var (.@ self slot)) ...)))))

;; TODO: use defsyntax-for-match, and in the pattern use (? test :: proc => pattern) to do the job
(defsyntax-for-match .o
  (lambda (stx)
    (syntax-case stx ()
      ((_ args ...)
       (with-syntax ((((k v) ...) (normalize-slot-specs-for-match stx #'(args ...))))
        #'(? (o?/slots '(k ...)) :: (.refs/slots '(k ...)) => [v ...])))))
  (lambda (stx)
    (syntax-case stx ()
      ((_ args ...)
       (with-syntax ((ctx stx)) #'(.o/ctx ctx args ...))))))

(defsyntax (.def stx)
  (syntax-case stx ()
    ((_ args ...)
     (with-syntax ((ctx stx)) #'(.def/ctx ctx args ...)))))

;; the ctx argument exists for macro-scope purposes
(defrules .def/ctx ()
  ((_ ctx (name options ...) slot-defs ...)
   (def name (.o/ctx ctx (:: options ...) slot-defs ...)))
  ((_ ctx name slot-defs ...)
   (def name (.o/ctx ctx () slot-defs ...))))

(defrules .get ()
  ((_ object) object)
  ((_ object slot slots ...) (.get (.ref object 'slot) slots ...)))

(defalias .@ .get)

(defrules .get-set! ()
  ((_ object slot v) (.put! object 'slot v))
  ((_ object slot0 slot1 slots ... v) (.get-set! (.@ object slot0) slot1 slots ... v)))

(defalias .@-set! .get-set!)

(defrules .call ()
  ((_ object slot args ...) ((.get object slot) args ...)))
