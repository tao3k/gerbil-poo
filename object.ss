;;-*- Gerbil -*-
;; Prototype Object Orientation Functionally, in Gerbil Scheme.
;;
;; Next version of poo, with multiple inheritance and a budding meta-object protocol.
;; See doc/poo.md for documentation

;; Reexport renamed version of core things we shadow
(export (except-out #t object-record-read object-read-query object-read-bootstrap
                    %call-with-fresh-slot-read-group %admitted-vector-read-fields!
                    object-deliver-value require-object-read-route! object-issued-read-current?
                    call-with-issued-reads %call-with-current-slot-reads %replay-fresh-slot-reads! replay-read-list!
                    active-read-replays issue-object-read %issue-read object-slot-names object-slot-present?
                    object-read-key object-read-dependencies object-read-value
                    require-current-read-sweep! %projection-read-visit-index %pure-read-sweep? %read-index-size-effect-free?
                    record-key-field record-dependencies-field record-value-field
                    slot-spec-discards-super? compile-slot-specs prepare-declaration-specifications compute-object-precedence!
                    %prepared-vector-slot-ref %prepared-vector-slots-ref %registered-field-reader
                    %bind-current-slot-reads %prepared-slot-present?
                    %register-slot-dependencies!
                    %with-slot-edit-protection %publish-slot-edits!
                    %put-assigned-slot! %depend-on-object-except-slot!
                    %owned-list-slot-spec %ref-owned-list define-slot-ref
                    instance-storage-info instance-native-table
                    %live-object-instance %live-object-layout
                    instantiate-for-demand! compile-slot-funs-for-demand!
                    current-constant-method? instantiate-with-preparation!
                    prepare-slot-values publish-preparation! compile-slot-funs-with!) @object? @make-object)

(import
  (prefix-in (only-in Runtime object? make-object) @) ;; Rename them before we shadow them
  (only-in ./support/object-syntax parse-object-options
           deduplicate-slot-identifiers prepare-shared-slot-specs
           normalize-slot-specs normalize-slot-specs-for-match)
  (for-syntax :std/iter
              (only-in :std/list/list push! delete-duplicates/hash)
              (only-in :std/list/list-builder with-list-builder))
  (only-in :std/error deferror-class Exception)
  (only-in :std/hash/misc hash->list/sort hash-ref/default hash-ensure-modify!)
  :std/iter
  ./slot-observation
  (prefix-in (only-in :gerbil/runtime/mop object-class find-method) read-runtime.)
  (only-in ./read-route standard-symbol-table-writes?
           %issued-read? %read-issuance)
  ./object-state
  ./prototype-map
  ./slot-layout
  (only-in :std/list/list-builder with-list-builder)
  (only-in :std/list/list flatten delete-duplicates/hash map-in-order)
  (only-in :std/string/symbol symbol<?)
  :std/stxparam
  (only-in :std/values first-value)
  (only-in :gerbil/runtime/c3 c4-linearize*)
  (only-in :gerbil/runtime/table symbolic-hash raw-table-ref symbolic-table-ref)
  (only-in :gerbil/runtime/interface interface-instance? interface-instance-object)
  (only-in :gerbil/runtime/table raw-table? raw-table-for-each &raw-table-count &raw-table-table)
  (only-in ./support/base λ let-id-rule defonce awhen %graph-table-seed))

(include "object/representation.scm")
(include "object/construction.scm")

(include "object/slot-values.scm")
;; Receiver-bound observations share this module's object/Slot authority.
(include "object/observation.ss")

(include "object/slot-access.scm")

(include "object/operations.scm")

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

;; Install a direct specification; all retained descendants lose derived caches.
;; : Unit <- (Object A) s:Symbol (SlotSpec A s)
(def (.putslot! self slot slot-spec)
  (def next (prototype-map-put (object-%slots self) slot slot-spec))
  (before-object-edit! self)
  (set! (object-%slots self) next))
;; Change a default persistently through the same descendant invalidation protocol.
(def (.putdefault! self slot default)
  (def next (prototype-map-put (object-%defaults self) slot default))
  (before-object-edit! self)
  (set! (object-%defaults self) next))
;; Remove every direct method contribution; inherited methods/defaults can reappear.
(def (.removeslot! self slot)
  (def next (prototype-map-remove (object-%slots self) slot))
  (before-object-edit! self)
  (set! (object-%slots self) next))
;; Remove a direct fallback without removing inherited or explicit instance values.
(def (.removedefault! self slot)
  (def next (prototype-map-remove (object-%defaults self) slot))
  (before-object-edit! self)
  (set! (object-%defaults self) next))

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

;; Admit the symbolic key before invalidation, then install an explicit value.
;; Bad keys retain all source/cache generations; argument evaluation is not undone.
;; Assumes the top-object-proto was used.
;; : Unit <- (Object A) s:Symbol (A s)
(defrule (put-object-slot! self slot value edited-slot)
  (using (slot :~ symbol?)
    (set! value (own-assigned-slot-value self slot value))
    (before-object-edit! self edited-slot)
    (unless (object-%overrides self)
      (set! (object-%overrides self) (make-hash-table test: eq? hash: symbolic-hash seed: (%graph-table-seed))))
    (hash-put! (object-%overrides self) slot value)
    (hash-put! (%live-object-instance self) slot value)))

(def (.put! self slot value) (put-object-slot! self slot value #f))
(def (%put-assigned-slot! self slot value) (put-object-slot! self slot value slot))

;; Protect the selected receivers while checking an edit that may run hooks.
(def (%with-slot-edit-protection owners action)
  (def protected (make-hash-table-eq))
  (for-each (lambda (owner) (hash-put! protected owner #t)) owners)
  (parameterize ((active-read-replays (cons protected (active-read-replays))))
    (action)))

;; Each row is (receiver . ((slot . value) ...)), with distinct receivers.
;; Prepare replacement overrides and check the entire invalidation closure
;; before advancing any revision. Reconstruct value stores on demand.
(def (%publish-slot-edits! edits (scope-direct-assignments? #f))
  (def replacements
    (%with-slot-edit-protection (map car edits)
      (lambda ()
        (map-in-order
          (lambda (edit)
            (def owner (car edit))
            (def old (object-%overrides owner))
            (def overrides (if old (hash-copy old) (make-hash-table-symbolic)))
            (for-each (lambda (entry) (hash-put! overrides (car entry) (cdr entry)))
                      (cdr edit))
            (cons owner overrides))
          edits))))
  (def roots
    (map (lambda (edit)
           (def owner (car edit))
           (def state (object-%state owner))
           (when (object-state-sealed? state) (error "sealed prototype"))
           (cons owner state))
         replacements))
  (def edited-slot
    (and scope-direct-assignments?
         (let (single-slots (make-hash-table-eq))
           (for-each
             (lambda (edit)
               (when (and (pair? (cdr edit)) (null? (cddr edit)))
                 (hash-put! single-slots (car edit) (caadr edit))))
             edits)
           (lambda (owner) (hash-get single-slots owner)))))
  (def invalidate!
    (prepare-invalidation roots check-object-edit clear-object-cache! edited-slot))
  (invalidate!)
  (for-each (lambda (entry) (set! (object-%overrides (car entry)) (cdr entry)))
            replacements))

(defrules .set! () ((_ object. slot value) (.put! object. 'slot value)))

;; carbon copy / clone c...
;; : (Object A') <- (Object A) <<TODO: type for overrides from A to A' ...>>
(def (.cc self . overrides)
  (def added-hash (make-hash-table test: eq? hash: symbolic-hash seed: (%graph-table-seed)))
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
  ;; Persistent path copies preserve direct contribution order and share all
  ;; unaffected tree branches. No evaluated receiver or cache is inherited.
  (def slots (foldl (lambda (slot source)
    (prototype-map-put source slot (hash-ref added-hash slot))) (object-%slots self) added))
  ;; Clone direct metadata with direct formulas; .cc does not inherit SELF.
  (make-object slots: slots supers: (object-%supers self) defaults: (object-%defaults self)
               protocol: (object-%protocol self) declarations: (object-%declarations self)))

;; Persistent direct overrides now copy balanced-tree paths; allocation and end-to-end
;; workflow performance still require measurement before selecting a faster policy.
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
