;;-*- Gerbil -*-
;; Prototype Object Orientation Functionally, in Gerbil Scheme.
;;
;; Next version of poo, with multiple inheritance and a budding meta-object protocol.
;; See doc/poo.md for documentation
;; TODO: see Future Features and the Internals TODO sections in document above.

;; Reexport renamed version of core things we shadow
(export #t @object? @make-object
        (for-syntax %make-object-slot-self-parameter
                    %make-object-slot-identifier-expander))

(import
  (prefix-in (only-in Runtime object? make-object) @) ;; Rename them before we shadow them
  (for-syntax :std/iter
              (only-in :std/list/list push!)
              (only-in :std/list/list-builder with-list-builder))
  (only-in :std/error deferror-class Exception)
  (only-in :std/hash/misc hash->list/sort hash-ref/default hash-ensure-modify!)
  :std/iter
  ./object-state
  (only-in :std/list/list-builder with-list-builder)
  (only-in :std/list/list flatten)
  (only-in :std/string/symbol symbol<?)
  :std/stxparam
  (only-in :std/values first-value)
  (only-in :gerbil/runtime/c3 c4-linearize)
  (only-in ./support/base λ let-id-rule defonce awhen))

;; A slot list is still exposed as an immutable-in-practice snapshot.  Writes
;; accumulate behind that view and are materialized only when a reader asks for
;; the list, so repeated .putslot! calls do not repeatedly copy its prefix.
(defstruct $slot-store (snapshot pending values dirty?))

(def (make-slot-store snapshot)
  (make-$slot-store snapshot '() #f #f))

(def ($slot-store-put! store name value)
  (unless ($slot-store-values store)
    (let (values (make-hash-table-symbolic))
      (for (([key . old-value] ($slot-store-snapshot store)))
        (unless (hash-key? values key)
          (hash-put! values key old-value)))
      (set! ($slot-store-values store) values)))
  (unless (hash-key? ($slot-store-values store) name)
    (set! ($slot-store-pending store)
          (cons name ($slot-store-pending store))))
  (hash-put! ($slot-store-values store) name value)
  (set! ($slot-store-dirty? store) #t))

(def ($slot-store-list store)
  (if (not ($slot-store-dirty? store))
    ($slot-store-snapshot store)
    (let ((seen (make-hash-table-symbolic))
          (values ($slot-store-values store)))
      (def result
        (with-list-builder (add)
          (for (([name . old-value] ($slot-store-snapshot store)))
            (if (hash-key? seen name)
              (add (cons name old-value))
              (begin
                (hash-put! seen name #t)
                (add (cons name (hash-ref values name))))))
          (for (name (reverse ($slot-store-pending store)))
            (add (cons name (hash-ref values name))))))
      (set! ($slot-store-snapshot store) result)
      (set! ($slot-store-pending store) '())
      (set! ($slot-store-values store) #f)
      (set! ($slot-store-dirty? store) #f)
      result)))

;; TODO: formalize (Object A S D) and the type conditions under which an object is instantiatable?
(defstruct object ;; = (Object A)
  (supers ;; : (Listof (Object ?))
   %slots ;; : direct slot method list, or $slot-store after mutation
   %defaults ;; : direct slot default list, or $slot-store after mutation
   %instance ;; : (Table (A_ k) <- k:Sym) ; hash table from slot keys to slot values
   %precedence-list ;; : (Listof (Object ?)) ; linearization of the supers DAG
   %slot-funs ;; : (Table (Fun (A_ k)) <- k:Symbol) ; functions to compute slots
   %all-slots
   %state ;; mutation revision, sealed flag and weak dependency edges
   %protocol ;; optional ordinary POO object supplying inheritance hooks
   %overrides ;; explicit INSTANCE assignments, never inherited specifications
   %declarations) ;; : (Listof Symbol) ; definition order for all slot keys
  constructor: :init!)
(defmethod {:init! object}
  (lambda (self ;; : (Object A)
      supers: (supers '()) ;; : (Listof Objects) ;; Actually, can be a pair-tree of Object's and nulls.
      slots: (slots '()) ;; : (Listof (Pair Symbol (SlotSpec ? ?)))
      defaults: (defaults '())
      protocol: (protocol #f) declarations: (declarations '())) ;; : (Listof (Pair Symbol ?))
    (set! (object-supers self) (flatten supers))
    (set! (object-%slots self) slots)
    (set! (object-%defaults self) defaults)
    (set! (object-%instance self) #f)
    (set! (object-%precedence-list self) #f)
    (set! (object-%slot-funs self) #f)
    (set! (object-%all-slots self) #f)
    (set! (object-%state self) (make-object-state))
    (set! (object-%protocol self) protocol)
    (set! (object-%overrides self) #f)
    (set! (object-%declarations self) declarations)
    (for-each (cut depend-on-object! self <>) (object-supers self))
    (when protocol (depend-on-object! self protocol))))

(def (object-slots self)
  (let (storage (object-%slots self))
    (if ($slot-store? storage) ($slot-store-list storage) storage)))

(def (object-defaults self)
  (let (storage (object-%defaults self))
    (if ($slot-store? storage) ($slot-store-list storage) storage)))

;; Track dependencies on prototypes, protocol objects and declaration descriptors.
(def (depend-on-object! self source)
  (unless (object? source) (error "object dependency required"))
  (depend-on-state! (object-%state source) self (object-%state self)))
;; Read-only revision identity for source-bound external caches.
(def (object-revision self) (object-state-revision (object-%state self)))
;; Active construction is separate from slot computation: no partial method table
;; or instance is published when an inherited hook tries to read its own receiver.
(def active-object-constructions (make-parameter []))
;; Clear all derived state together. Explicit instance assignments remain separate.
(def (clear-object-cache! self)
  (set! (object-%instance self) #f)
  (set! (object-%precedence-list self) #f)
  (set! (object-%slot-funs self) #f)
  (set! (object-%all-slots self) #f))
;; Refuse mutation during evaluation anywhere in the affected dependency closure.
(def (check-object-edit self state)
  (when (or (memq self (active-object-constructions))
            (any (lambda (entry) (eq? self (car entry))) (active-slot-computations)))
    (error "object mutation during computation")))
;; Explicit invalidation preserves specifications and reaches shared descendants once.
(def (uninstantiate-object! self)
  (invalidate-state! self (object-%state self) check-object-edit clear-object-cache!))
;; Sealed sources reject all supported writes; invalidation alone remains allowed.
(def (before-object-edit! self)
  (when (object-state-sealed? (object-%state self)) (error "sealed prototype"))
  (uninstantiate-object! self))
;; Seal the current receiver's specifications and explicit instance assignments.
;; Ancestors can still change through the invalidation protocol unless sealed too.
(def (seal-object! self)
  (check-object-edit self (object-%state self))
  (set! (object-state-sealed? (object-%state self)) #t) self)
;; Replace direct specifications, invalidating every retained dependent cache.
(def (object-slots-set! self slots)
  (before-object-edit! self)
  (set! (object-%slots self) slots))
;; Replace direct defaults through the same invalidation discipline.
(def (object-defaults-set! self defaults)
  (before-object-edit! self)
  (set! (object-%defaults self) defaults))
;; Install a new protocol; old dependency edges conservatively remain valid.
(def (object-protocol-set! self protocol)
  (unless (or (not protocol) (object? protocol)) (error "protocol object required"))
  (before-object-edit! self)
  (when protocol (depend-on-object! self protocol))
  (set! (object-%protocol self) protocol))
;; Replace parent topology only after C3 admission and cycle checks. Low-level
;; generated struct setters are internal escape hatches, not this public protocol.
(def (replace-object-supers! self supers)
  (def parents (flatten supers))
  (for-each (lambda (parent)
    (unless (object? parent) (error "prototype parent required"))
    (when (memq self (compute-precedence-list! parent)) (error "cyclic prototype revision"))) parents)
  (compute-precedence-list! (make-object supers: parents))
  (before-object-edit! self)
  (for-each (cut depend-on-object! self <>) parents)
  (set! (object-supers self) parents))
;; Resolve the most-specific explicit protocol after checked C3 linearization.
;; Protocol descriptors themselves inherit with the ordinary object mechanism.
(def (object-protocol self)
  (let find ((order (object-%precedence-list self)))
    (and (pair? order) (or (object-%protocol (car order)) (find (cdr order))))))
;; Invoke one optional inherited hook. The continuation is the existing engine,
;; not a second evaluator; hook errors propagate and never install partial caches.
(def (invoke-object-hook self name next . args)
  (def protocol (object-protocol self))
  (if (and protocol (.slot? protocol name))
    (apply (.ref protocol name) self next args) (next)))
;; Instantiate atomically with respect to native exceptions. Mutating callbacks and
;; concurrent reads/writes are outside the sequential protocol, and are rejected
;; for actively evaluated receivers rather than returning a partially built value.
(def (instantiate-object! self)
  (unless (object? self) (error "Not an object"))
  (unless (object-%instance self)
    (when (memq self (active-object-constructions)) (error "recursive object construction"))
    (parameterize ((active-object-constructions (cons self (active-object-constructions))))
      (try
        (compute-precedence-list! self)
        (compute-slot-funs! self)
        (def instance (make-hash-table-symbolic))
        (when (object-%overrides self)
          (for (([key . value] (object-%overrides self))) (hash-put! instance key value)))
        (set! (object-%instance self) instance)
        (catch (cause) (clear-object-cache! self) (raise cause))))))

(defclass (InvalidObject Exception) (slots) transparent: #t)
(def (invalid-object-summary self)
  (InvalidObject slots: (map car (append (object-slots self) (object-defaults self) (object-%declarations self)))))

(def (compute-precedence-list! self (heads '()))
  ;; Preserve the ordered heads for diagnostics while keeping the cycle guard
  ;; as private implementation state at this abstraction boundary.
  (def active (make-hash-table-eq))
  (for-each (lambda (head) (hash-put! active head #t)) heads)
  (let compute ((object self) (heads heads))
    (cond
     ((object-%precedence-list object))
     ((hash-key? active object)
      (error "Circular precedence graph" (member object heads)))
     (else
      (hash-put! active object #t)
      (parameterize ((active-object-constructions (cons object (active-object-constructions))))
        (let (precedence-list
            (first-value
             (c4-linearize
              [object] (object-supers object)
              get-precedence-list:
              (lambda (super) (compute super [object . heads]))
              eq: eq?
              get-name: invalid-object-summary)))
        (hash-remove! active object)
        (set! (object-%precedence-list object) precedence-list)
        (try
          (let (chosen (invoke-object-hook object 'compute-precedence-list (lambda () precedence-list)))
            (unless (and (list? chosen) (= (length chosen) (length precedence-list))
                         (andmap eq? chosen precedence-list))
              (error "inheritance hook must preserve checked C3 order"))
            chosen)
          (catch (cause) (clear-object-cache! object) (raise cause)))))))))

;; Compile declaration metadata through the existing Slot protocol on a fresh
;; private receiver. Repeating this after descriptor edits cannot retain stale
;; constant/default/compute specifications from the previous metadata revision.
(def (declaration-specifications self)
  (if (null? (object-%declarations self)) (cons [] [])
    (let (scratch (make-object))
      (for (([name . descriptor] (object-%declarations self)))
        (def type (.@ descriptor .type))
        (depend-on-object! self type)
        (.call type .slot.define descriptor name scratch))
      (cons (object-slots scratch) (object-defaults scratch)))))
;; Assemble the ordinary inheritance chain, then let inherited hooks transform
;; each effective thunk. Direct specification writes override their declaration.
(def (compute-slot-funs! self)
  (def h (make-hash-table-symbolic))
  (def sources (map (lambda (super) (cons super (declaration-specifications super)))
                   (reverse (object-%precedence-list self))))
  (for (([super . declarations] sources))
    (for (([slot . value] (append (cdr declarations) (object-defaults super))))
      (hash-put! h slot (lambda _ value))))
  (for (([super . declarations] sources))
    (for (([slot . spec] (append (car declarations) (object-slots super))))
      (hash-ensure-modify! h slot
        (lambda () (cut no-applicable-method self slot))
        (cut apply-slot-spec self spec <>))))
  (for (([slot . standard] (hash->list h)))
    (def compiled (invoke-object-hook self 'compute-slot (lambda () standard) slot))
    (unless (procedure? compiled) (error "compute-slot must return a thunk" slot))
    (hash-put! h slot compiled))
  (set! (object-%slot-funs self) h))

;; Given a list of list of keys, in precedence order,
;; return a list of keys from containing from left to right
;; all the keys from tail to head of the precedence list, skipping repetitions.
(def (merge-super-slots super-slots)
  (def h (make-hash-table-symbolic))
  (with-list-builder (c)
    (for-each (lambda (l)
    (for-each (lambda (k)
      (unless (hash-key? h k)
        (hash-put! h k #t) (c k)))
    l)) (reverse super-slots))))

(defstruct $slot-spec () transparent: #t) ;; = (SlotSpec A k)
(defstruct ($constant-slot-spec $slot-spec) (value) transparent: #t) ;; constant value
(defstruct ($thunk-slot-spec $slot-spec) (thunk) transparent: #t) ;; thunk
(defstruct ($self-slot-spec $slot-spec) (fun) transparent: #t) ;; fun to be passed self as argument, not super
(defstruct ($computed-slot-spec $slot-spec) (fun) transparent: #t) ;; fun to be passed self and superfun as arguments

(def (apply-slot-spec self spec superfun)
  (match spec
    (($constant-slot-spec val) (lambda _ val))
    (($thunk-slot-spec fun) fun)
    (($self-slot-spec fun) (cut fun self))
    (($computed-slot-spec fun) (cut fun self superfun))))

(def (object-instance self)
  (instantiate-object! self)
  (object-%instance self))

;; Active computations are dynamically scoped per thread and unwind on failure.
;; Only cache misses enter this path; successful #f and other values stay cached.
(def active-slot-computations (make-parameter []))
;; Report receiver/slot paths without forcing any value while formatting the error.
(defclass (CyclicSlot Exception) (path) transparent: #t)
;; Evaluate one uncached slot with finite cycle detection, including lazy delegates.
;; Failures publish no value and parameterize restores the caller's active path.
(def (compute-slot-value self slot thunk)
  (def active (active-slot-computations))
  (def key (cons self slot))
  (when (any (lambda (entry) (and (eq? (car entry) self) (eq? (cdr entry) slot))) active)
    (raise (CyclicSlot path: (reverse (cons key active)))))
  (parameterize ((active-slot-computations (cons key active))) (thunk)))
;; Read a cached slot or compute it through the cycle-aware missing-method protocol.
(def (.ref self slot)
  (def instance (object-instance self))
  ;; Keep the cached path to one V19 runtime hash lookup without allocating
  ;; the cache-miss thunk required by hash-ensure-ref.
  (def value (hash-ref instance slot absent-value))
  (if (eq? value absent-value)
    (let (value (compute-slot-value self slot
                  (hash-ref/default (object-%slot-funs self) slot
                    (cut cut no-applicable-method self slot))))
      (hash-put! instance slot value)
      value)
    value))

;; Get an existing cached slot value from an object
(def (.ref/cached self slot (default false))
  (hash-ref/default (object-instance self) slot default))

(defclass (NoApplicableMethod Exception) (self slot) transparent: #t)

;; Prototype to put at the end of the list, to handle
;; undefined-prototype-behavior a bit better.
;; Should it send a special message in that case?
(def (no-applicable-method self slot)
  (def nam (and (not (eq? slot 'no-applicable-method))
    (try (.@ self no-applicable-method)
      (catch (NoApplicableMethod? cause)
        ;; Only genuine absence of THIS hook means no handler. A broken hook,
        ;; cyclic definition or delegate's own missing slot remains a source error.
        (if (and (eq? (NoApplicableMethod-self cause) self)
                 (eq? (NoApplicableMethod-slot cause) 'no-applicable-method))
          #f (raise cause))))))
  (if nam (nam self slot) (raise (NoApplicableMethod self: self slot: slot))))

;; Lazy delegation is ordinary prototype behavior, using the existing missing
;; method hook. Each receiver computes/caches its own fallback only on first miss;
;; direct slots never force it. Delegate failures and cycles propagate unchanged.
(def (fallback-to thunk)
  (unless (procedure? thunk) (error "fallback must be a thunk"))
  (.o (.fallback-handler (thunk))
    (no-applicable-method (lambda (self slot) (.ref (.@ self .fallback-handler) slot)))))

;; : (Object A) <- (IndexedList ? ((Pair s (A s)) <- s:Symbol)) \
;;     supers: ? (ConsTreeOf (Object ?)) defaults: ? (Table ? Symbol)
(def (object<-alist a supers: (supers '()) defaults: (defaults '()))
  (make-object slots: (for/collect (([k . v] a)) (cons k ($constant-slot-spec v)))
               supers: supers defaults: defaults))

(def (object<-hash h supers: (supers '()) defaults: (defaults '()))
  (object<-alist (hash->list/sort h symbol<?) supers: supers defaults: defaults))

(def (object<-fun f keys: (keys '()) supers: (supers '()) defaults: (defaults '()))
  (make-object slots: (map (lambda (k) (cons k ($thunk-slot-spec (cut f k)))) keys)
               supers: supers defaults: defaults))

(def (.mix slots: (slots '()) defaults: (defaults '()) . supers)
  (make-object supers: supers slots: slots defaults: defaults))
(def (.extend self defaults: (defaults '()) . slots)
  (make-object slots: slots supers: [self] defaults: defaults))
(def (.+ base override)
  (make-object slots: (object-slots override)
               supers: [(object-supers override)... base] defaults: (object-defaults override)))

;; : Bool <- (Object _) Symbol
(def (.slot? self slot)
  (instantiate-object! self)
  (hash-key? (object-%slot-funs self) slot))

(defrules .has? ()
  ((_ x) #t)
  ((_ x slot) (.slot? x 'slot))
  ((_ x slot1 slot2 slot3 ...) (and (.has? x slot1) (.has? x slot2 slot3 ...))))

;; : (Listof Symbol) <- (Object _)
(def (.all-slots self)
  (instantiate-object! self)
  (or (object-%all-slots self)
      (let (esl (merge-super-slots
                 (map (lambda (super) (map car (append (object-slots super) (object-defaults super) (object-%declarations super))))
                      (object-%precedence-list self))))
        (def defined (filter (lambda (slot) (hash-key? (object-%slot-funs self) slot)) esl))
        (set! (object-%all-slots self) defined)
        defined)))

;; : Unit <- (Object A) (Fun _ <- s:Symbol (A s))
(def (.for-each! self fun)
  (for-each (lambda (slot) (fun slot (.ref self slot))) (.all-slots self)))

;; : (Listof Symbol) <- (Object _)
(def (.all-slots/sort object) (list-sort symbol<? (.all-slots object)))

;; : (Listof (Pair s:Symbol (A s))) <- (Object A)
(def (.alist self)
  (map (λ (slot) (cons slot (.ref self slot))) (.all-slots self)))

;; : (Listof (Pair s:Symbol (A s))) <- (Object A)
(def (.alist/sort self)
  (map (λ (slot) (cons slot (.ref self slot))) (.all-slots/sort self)))

;; Force the lazy computation of all slots in an object
;; : (Object A) <- (Object A)
(def (force-object self) (for-each (cut .ref self <>) (.all-slots self)) self)

;; : (Table (A s) <- s:Symbol) <- (Object A)
(def (hash<-object self)
  (object-%instance (force-object self)))

;; For (? test :: proc => pattern),
;;   test = (o?/slots ks)
;;   proc = (.refs/slots ks)
;; : Bool <- (Object _) <- (Listof Symbol)
(def ((o?/slots slots) o) (and (object? o) (andmap (cut .slot? o <>) slots)))
;; : (IndexedList ss A) <- (Object A) <- ss:(Listof Symbol)
(def ((.refs/slots slots) o) (map (cut .ref o <>) slots))

;; the ctx argument exists for macro-scope purposes
;; TODO: use a syntax-parameter for self instead of the ctx argument?
(defrules .o/ctx ()
  ((_ ctx (:: self) slot-spec ...)
   (object/slots ctx self [] () slot-spec ...))
  ((_ ctx (:: self super slots ...) slot-spec ...)
   (object/slots ctx self super (slots ...) slot-spec ...))
  ((_ ctx () slot-spec ...)
   (object/slots ctx self [] () slot-spec ...))
  ((_ ctx slot-spec ...)
   (object/slots ctx self [] () slot-spec ...)))

(begin-syntax
  ;; TODO: is there a better option than (stx-car stx) to introduce correct identifier scope?
  ;; the stx argument is the original syntax #'(.o args ...) or #'(@method args ...)
  (def (unkeywordify-syntax ctx k)
    (datum->syntax (stx-car ctx)
                   (string->symbol (keyword->string (syntax->datum k)))))

  ;; A NormalizedSlotSpec is one of:
  ;;  - (slot-name value-expr)                           ; ignore parent, override
  ;;  - (slot-name => function-expr extra-arg-expr ...)  ; invoke parent, pass into function
  ;;  - (slot-name (inherited-computation) value-expr)   ; lazy reference to parent
  ;;  - (slot-name)                                      ; same-named var from surrounding scope
  ;;  - (slot-name =>.+ object-expr)                     ; override parent with a mixin
  ;;  - (slot-name ?: default-expr)                      ; default for the slot
  ;; Interpretation according to `doc/poo.md` section `POO Definition Syntax`

  (def (normalize-slot-specs ctx specs)
    (def methods (make-hash-table-symbolic))
    (def defaults (make-hash-table-symbolic))
    (def defaults-list '())
    (def (d x) (push! x defaults-list))
    (def slot-methods
      (with-list-builder (c) (%normalize-slot-specs ctx specs methods defaults c d)))
    [slot-methods (reverse defaults-list)])

  (def (%normalize-slot-specs ctx specs methods defaults c d)
    (def (loop more) (%normalize-slot-specs ctx more methods defaults c d))
    (syntax-case specs ()
      (() (void))
      ((arg . more)
       (let ((e (syntax-e #'arg)))
         (cond
          ((pair? e) (%normalize-slot-spec ctx #'arg methods defaults c d) (loop #'more))
          ((symbol? e) (%normalize-slot-spec ctx #'(arg) methods defaults c d) (loop #'more))
          ((keyword? e) (%normalize-named-slot-specs
                         ctx (unkeywordify-syntax ctx #'arg) #'more methods defaults c d))
          (else (raise-syntax-error #f "bad slot spec" #'arg ctx)))))))

  (def (%normalize-slot-spec ctx spec methods defaults c d)
    (def (do-method name more)
      (def sym (syntax-e name))
      (unless (symbol? sym) (raise-syntax-error #f "Slot name not a symbol" ctx name))
      (if (hash-key? methods sym)
        (raise-syntax-error #f "Multiple slot methods specified" name ctx)
        (hash-put! methods sym #t))
      (c [name . more]))
    (def (do-defaults name value)
      (def sym (syntax-e name))
      (unless (symbol? sym) (raise-syntax-error #f "Slot name not a symbol" ctx name))
      (if (hash-key? defaults sym)
        (raise-syntax-error #f "Multiple slot defaults specified" name ctx)
        (hash-put! defaults sym #f))
      (d [name value]))
    (syntax-case spec (?)
      ((name value) (do-method #'name #'(value)))
      ((name ? value) (do-defaults #'name #'value))
      ((name ? . more) (raise-syntax-error #f "Invalid slot default specified" ctx #'name))
      ((name . more) (do-method #'name #'more))))

  (def (%normalize-named-slot-specs ctx name specs methods defaults c d)
    (def (loop spec more)
      (%normalize-slot-spec ctx spec methods defaults c d)
      (%normalize-slot-specs ctx more methods defaults c d))
    (with-syntax ((name name))
      (syntax-case specs (=> =>.+ ?)
        ((=> value-spec . more) (loop #'(name => value-spec) #'more))
        ((=>.+ value-spec . more) (loop #'(name =>.+ value-spec) #'more))
        ((? value-spec . more) (loop #'(name ? value-spec) #'more))
        ((value-spec . more) (loop #'(name value-spec) #'more))
        (() (raise-syntax-error #f "missing value after slot name" #'name (syntax->datum #'name) ctx (syntax->datum ctx))))))

  (def (normalize-slot-specs-for-match ctx specs)
    (with ([slot-methods defaults] (normalize-slot-specs ctx specs))
      (unless (null? defaults) (raise-syntax-error #f "? not allowed in patterns" ctx))
      (for/collect ((s slot-methods))
        (syntax-case s (=> =>.+ ?)
          ((slot form) #'(slot form))
          ((slot) #'(slot slot))
          ((slot ? . _) (raise-syntax-error #f "? not allowed in patterns" ctx))
          ((slot => . _) (raise-syntax-error #f "=> not allowed in patterns" ctx))
          ((slot =>.+ . _) (raise-syntax-error #f "=>.+ not allowed in patterns" ctx))
          ((slot (next-method) form) (raise-syntax-error #f "(inherited-computation) not allowed in patterns" ctx)))))))

;; A prototype may name the same slot in its inherited, default, and direct
;; declarations.  Syntax bindings only need one entry for identifiers that
;; denote the same lexical slot.
(begin-syntax
  (def (%make-object-slot-self-parameter)
    (make-syntax-parameter key: (gensym 'slot-self) default: #f))

  (def (%make-object-slot-identifier-expander self-parameter slot ref)
    (lambda (stx)
      (let (self (syntax-parameter-value self-parameter))
        (unless self
          (raise-syntax-error #f "slot reference outside object method scope" stx))
        (with-syntax ((self self) (slot slot) (ref ref))
          (if (identifier? stx)
            #'(ref self 'slot)
            (syntax-case stx ()
              ((_ . args) #'((ref self 'slot) . args))))))))

  (def (deduplicate-slot-identifiers slots)
    (let loop ((rest (syntax->list slots)) (seen []) (result []))
      (match rest
        ([] (reverse result))
        ([slot . tail]
         (if (find (cut bound-identifier=? slot <>) seen)
           (loop tail seen result)
           (loop tail [slot . seen] [slot . result]))))))

  (def (prepare-shared-slot-specs specs)
    (let loop ((rest specs) (bindings []) (result []))
      (match rest
        ([] [(reverse bindings) (reverse result)])
        ([spec . tail]
         (syntax-case spec ()
           ((slot)
            (with-syntax ((value (genident 'slot-value)))
              (loop tail
                    [#'(value slot) . bindings]
                    [#'(slot lexical-slot-value value) . result])))
           (_ (loop tail bindings [spec . result]))))))))

;; the ctx argument exists for macro-scope purposes
(defsyntax (object/slots stx)
  (syntax-case stx ()
    ((_ ctx self super (slots ...) . slot-specs)
     (let* ((normalized (normalize-slot-specs #'ctx #'slot-specs))
            (slot-methods (car normalized))
            (defaults (cadr normalized))
            (prepared (prepare-shared-slot-specs slot-methods)))
       (with-syntax ((((slot spec ...) ...) slot-methods)
                     (((default-slot . default-value) ...) defaults)
                     (((constant-id constant-value) ...) (car prepared))
                     (((prepared-slot prepared-spec ...) ...) (cadr prepared)))
         #'(let ((constant-id constant-value) ...)
             (object/init self super (slots ... default-slot ... slot ...)
                          ((default-slot . default-value) ...)
                          (prepared-slot prepared-spec ...) ...)))))))

(defrule (object/defaults (default-slot default-value) ...)
  (list (cons 'default-slot default-value) ...))

(defrule (object/init self super slots ((default-slot default-value) ...) (slot slotspec ...) ...)
  (make-object
   supers: super
   slots: (%with-shared-slot-bindings slots (slot-self)
           (list (cons 'slot (object/slot-spec %with-shared-slots slot-self self slots slot slotspec ...)) ...))
   defaults: (object/defaults (default-slot default-value) ...)))

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

(defsyntax (%with-shared-slot-bindings stx)
  (syntax-case stx ()
    ((_ (slots ...) (slot-self) body ...)
     (let* ((slot-self-id (genident 'slot-self))
            (body (stx-substitute [[#'slot-self . slot-self-id]]
                                  #'(begin body ...))))
       (with-syntax (((slot ...) (deduplicate-slot-identifiers #'(slots ...)))
                     (slot-self slot-self-id)
                     (body body))
         #'(let-syntax ((slot-self (%make-object-slot-self-parameter)))
             (let-syntax ((slot
                           (%make-object-slot-identifier-expander
                            (quote-syntax slot-self)
                            (quote-syntax slot)
                            (quote-syntax .ref))) ...)
               body)))))))

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

;; TODO: have it called with-slots in both cases, but autodetect
;; that the first argument is a keyword or string?
(defsyntax (with-prefixed-slots input)
  (let (stx (syntax-local-introduce input))
    (syntax-local-introduce
     (syntax-case stx ()
       ((_ (prefix slot ...) self body ...)
        #'(with-prefixed-slots prefix (prefix slot ...) self body ...))
       ((_ ctx (prefix) self body ...) #'(begin body ...))
       ((_ ctx (prefix slot slots ...) self body ...)
        (with-syntax ((var (stx-identifier #'ctx #'prefix #'slot)))
          #'(let-id-rule (var (.@ self slot))
              (with-prefixed-slots ctx (prefix slots ...) self body ...))))))))

(defsyntax (def-prefixed-slots input)
  (let (stx (syntax-local-introduce input))
    (syntax-local-introduce
     (syntax-case stx ()
       ((_ (prefix slot ...) self)
        #'(def-prefixed-slots prefix (prefix slot ...) self))
       ((_ ctx (prefix) self) #'(void))
       ((_ ctx (prefix slot slots ...) self)
        (with-syntax ((var (stx-identifier #'ctx #'prefix #'slot)))
          #'(begin
              (def var (.@ self slot))
              (def-prefixed-slots ctx (prefix slots ...) self))))))))

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

;; Install a direct specification; all retained descendants lose derived caches.
;; : Unit <- (Object A) s:Symbol (SlotSpec A s)
(def (.putslot! self slot slot-spec)
  (before-object-edit! self)
  (let (storage (object-%slots self))
    (unless ($slot-store? storage)
      (set! storage (make-slot-store storage))
      (set! (object-%slots self) storage))
    ($slot-store-put! storage slot slot-spec)))

;; Change a direct default and invalidate all derived inherited state.
(def (.putdefault! self slot default)
  (before-object-edit! self)
  (let (storage (object-%defaults self))
    (unless ($slot-store? storage)
      (set! storage (make-slot-store storage))
      (set! (object-%defaults self) storage))
    ($slot-store-put! storage slot default)))

(defrules .setslot! () ((_ object. slot slot-spec) (.putslot! object. 'slot slot-spec)))

(defrules .def! ()
  ((_ object slot (:: self _ slots ...) slotspec ...)
   (.putslot! object 'slot
              (object/slot-spec %with-direct-slots #f self
                                (slot slots ...) slot slotspec ...)))
  ((_ object slot (:: self) slotspec ...)
   (.def! object slot (:: self []) slotspec ...))
  ((_ object slot (slots ...) slotspec ...)
   (.def! object slot (:: self [] slots ...) slotspec ...)))

;; Side-effect the value of a field into an object.
;; Assumes the top-object-proto was used.
;; : Unit <- (Object A) s:Symbol (A s)
(def (.put! self slot value)
  (before-object-edit! self)
  (unless (object-%overrides self)
    (set! (object-%overrides self) (make-hash-table-symbolic)))
  (hash-put! (object-%overrides self) slot value)
  (hash-put! (object-instance self) slot value))

(defrules .set! () ((_ object. slot value) (.put! object. 'slot value)))

;; carbon copy / clone c...
;; : (Object A') <- (Object A) <<TODO: type for overrides from A to A' ...>>
(def (.cc self . overrides)
  (def added-hash (make-hash-table-symbolic))
  (def added
    (with-list-builder (c)
      (def (add-slot! slot value)
        (when (hash-key? added-hash slot) (error "Cannot override slot twice" self slot))
        (hash-put! added-hash slot ($constant-slot-spec value))
        (c slot))
      (let loop ((l overrides))
        (match l
          ([] (void))
          ([(? symbol? s) v . r] (add-slot! s v) (loop r))
          ([(? keyword? k) v . r] (add-slot! (make-symbol k) v) (loop r))
          (else (error "invalid object overrides" overrides))))))
  (def slots
    (with-list-builder (c)
      (for ((ss (object-slots self)))
        (def slot (car ss))
        (cond
         ((hash-get added-hash slot) => (lambda (spec) (hash-remove! added-hash slot) (c [slot . spec])))
         (else (c ss))))
      (for (slot added)
        (awhen (spec (hash-get added-hash slot))
          (hash-remove! added-hash slot) (c [slot . spec])))))
  (make-object slots: slots supers: (object-supers self) defaults: (object-defaults self)))

;; TODO: find an efficient way to repeatedly override one field in a pure way without leaking memory,
;; in O(log n) rather than O(n)?
;; TODO: maybe have explicitly distinct variants of stateful vs pure object?
;; Could one convert from the other, with some freezing and thawing or copying operations?
;; When overriding a field, should we invalidate all the cached values for all fields?
;; Should we keep an indefinitely growing list of the super formulas?
;; Should we maintain flags as to which formulas do or don't use the super and/or self references,
;; so we know what to invalidate or not?

;; TODO: For type validation,
;; 1. cache which types an instance was tested to be part of,
;; which allows for fast checking of types for recursive data structures,
;; maybe even with cycles.
;; 2. have a mechanism to extend the above to non-instances.
