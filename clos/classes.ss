;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; POO CLOS classes and direct/effective slot projection.

(import :clan/poo/object
        (only-in :clan/poo/mop/prototype element?)
        (only-in :std/hash/misc hash-ref/default hash-remove!)
        (only-in :std/list/list delete-duplicates/hash)
        (only-in :std/list/list find filter filter-map flatten1)
        "types.ss" "objects.ss" "funcs.ss")

(extern namespace: clan/poo/object %ref-owned-list %publish-slot-edits! %owned-list-slot-spec)
(extern namespace: clan/poo/slot-observation %make-owned-list)

(export ClosDirectSlotDefinition ClosEffectiveSlotDefinition ClosClass
        clos-standard-object-class clos-direct-slot-definition
        clos-class
        clos-find-class clos-set-find-class! clos-resolve-class
        clos-class-effective-slots clos-find-effective-slot
        clos-class-subclass? clos-class-specializer
        clos-class-slot-cell
        make-slot-cell
        %clos-make-class-generation %clos-class-redefinition-edits
        %clos-project-class-redefinition
        initialize-direct-class-slots!
        %clos-set-class-name!)

;; : POOObject
(def ClosDirectSlotDefinition. (.ref ClosDirectSlotDefinition 'proto))
;; : POOObject
(def ClosEffectiveSlotDefinition. (.ref ClosEffectiveSlotDefinition 'proto))
;; : POOObject
(def ClosClass. (.ref ClosClass 'proto))
;; : POOObject
(def ClosSlotCell. (.ref ClosSlotCell 'proto))

(def +clos-no-initform+ (cons 'clos 'no-initform))

;;; The ANSI class-name namespace is process-local and identity keyed.  Lexical
;;; `.defclass` bindings remain ordinary POO values, while symbolic class
;;; designators resolve through this single registry.
(def clos-class-registry (make-hash-table-eq))

;; : (-> Symbol Boolean (Maybe ClosClass))
(def (clos-find-class name error?: (error-value #t)
                          environment: (_environment-value #f))
  (unless (symbol? name) (clos-fail 'invalid-class-name class: name))
  (let (class-value
        (hash-ref/default clos-class-registry name (lambda () #f)))
    (when (and (not class-value) error-value)
      (clos-fail 'class-not-found class: name operation: 'find-class))
    class-value))

;;; FIND-CLASS owns the symbol-to-class association independently from the
;;; class object's name.  A false new value removes only that association.
;; : (-> (Maybe ClosClass) Symbol error?: Boolean environment: Any
;;        (Maybe ClosClass))
(def (clos-set-find-class! new-class name error?: (_error-value #t)
                               environment: (_environment-value #f))
  (unless (symbol? name) (clos-fail 'invalid-class-name class: name))
  (unless (or (not new-class) (element? ClosClass new-class))
    (clos-fail 'invalid-class class: new-class operation: 'setf-find-class))
  (if new-class
    (hash-put! clos-class-registry name new-class)
    (hash-remove! clos-class-registry name))
  new-class)

;; : (-> Symbol ClosClass Symbol)
(def (%clos-set-class-name! new-name class-value)
  (unless (symbol? new-name)
    (clos-fail 'invalid-class-name operation: 'setf-class-name))
  (unless (element? ClosClass class-value) (clos-fail 'invalid-class))
  (.put! class-value 'identity new-name)
  new-name)

;; : (-> (U Symbol ClosClass) ClosClass)
(def (clos-resolve-class value)
  (cond
   ((element? ClosClass value) value)
   ((symbol? value) (clos-find-class value))
   (else (clos-fail 'invalid-class class: value))))

;; : (-> [SchemeValue] [SchemeValue])
(def (unique/identity values)
  (delete-duplicates/hash
   values
   table: (make-hash-table-eq)
   from-end?: #t))

;; : (-> [SchemeValue] Boolean)
(def (unique-identities? values)
  (= (length values) (length (unique/identity values))))

;; | ClosDirectSlotDefinition = POOObject
;; clos-direct-slot-definition
;;   : (-> Symbol allocation: SlotAllocation initargs: [InitargName]
;;         initform: (Maybe Thunk) readers: [Symbol] writers: [Symbol]
;;         type-predicate: (Maybe Procedure) documentation: (Maybe String)
;;         ClosDirectSlotDefinition)
;;   | contract: captures one direct slot declaration without evaluating its
;;     optional initform thunk.
;;   | doc m%
;;   | result: an immutable POO direct-slot metaobject.
(def (clos-direct-slot-definition
      identity-value allocation: (allocation-value 'instance)
      initargs: (initarg-values '())
      initform: (initform-value +clos-no-initform+)
      readers: (reader-values '()) writers: (writer-values '())
      type-predicate: (type-predicate-value #f)
      documentation: (documentation-value #f))
  (unless (symbol? identity-value)
    (clos-fail 'invalid-slot-name slot: identity-value))
  (unless (memq allocation-value '(instance class))
    (clos-fail 'invalid-slot-allocation slot: identity-value))
  (unless (clos-initarg-name-list? initarg-values)
    (clos-fail 'invalid-slot-initargs slot: identity-value))
  (unless (and (clos-function-name-list? reader-values)
               (clos-function-name-list? writer-values))
    (clos-fail 'invalid-slot-accessors slot: identity-value))
  (unless (or (eq? initform-value +clos-no-initform+)
              (procedure? initform-value))
    (clos-fail 'invalid-slot-initform slot: identity-value))
  (unless (or (not type-predicate-value) (procedure? type-predicate-value))
    (clos-fail 'invalid-slot-type-predicate slot: identity-value))
  (unless (or (not documentation-value) (string? documentation-value))
    (clos-fail 'invalid-slot-documentation slot: identity-value))
  (checked
   ClosDirectSlotDefinition
   (let (slot (.o (:: @ ClosDirectSlotDefinition.)
                 identity: identity-value allocation: allocation-value
                 initargs: (unique/identity initarg-values)
                 initfunction: (if (eq? initform-value +clos-no-initform+)
                                 #f initform-value)
                 type-predicate: type-predicate-value
                 documentation: documentation-value))
     (.putslot! slot 'readers
       (%owned-list-slot-spec (unique/identity reader-values) clos-copy-function-names))
     (.putslot! slot 'writers
       (%owned-list-slot-spec (unique/identity writer-values) clos-copy-function-names))
     slot)
   'invalid-direct-slot-definition))

;; : (-> [SchemeValue] [Pair])
(def (require-default-initargs values)
  (unless (clos-default-initargs? values)
    (clos-fail 'invalid-default-initargs))
  (unless (unique-identities? (map car values))
    (clos-fail 'duplicate-default-initarg))
  values)

;; Default thunks are opaque values; copy their association cells, never
;; their environments and never by evaluating them.
(def (copy-default-initargs entries)
  (map (lambda (entry) (cons (car entry) (cdr entry))) entries))

;; : (-> [ClosDirectSlotDefinition] [ClosDirectSlotDefinition])
(def (require-direct-slots values)
  (unless (and (list? values)
               (andmap (lambda (value)
                         (element? ClosDirectSlotDefinition value))
                       values))
    (clos-fail 'invalid-direct-slots))
  (unless (unique-identities? (map (lambda (slot) (.ref slot 'identity)) values))
    (clos-fail 'duplicate-direct-slot))
  values)

;; : (-> [ClosClass] [ClosClass])
(def (require-direct-superclasses values)
  (unless (and (list? values)
               (andmap (lambda (value) (element? ClosClass value)) values))
    (clos-fail 'invalid-direct-superclasses))
  (unless (unique-identities? values)
    (clos-fail 'duplicate-direct-superclass))
  values)

;; : (-> ClosClass [POOObject] POOObject)
(def (instance-prototype-value class-value superclass-prototypes)
  (.o (:: @ superclass-prototypes) %clos-class: class-value))

;; : (-> ClosClass POOObject)
(def (class-instance-prototype class-value)
  (.ref class-value 'instance-prototype))

;; : (-> ClosClass [ClosClass])
(def (class-direct-superclasses class-value)
  (.ref class-value 'direct-superclasses))

;; : (-> ClosClass POOObject)
(def (make-instance-prototype class-value)
  (let (superclass-prototypes
        (map class-instance-prototype
             (class-direct-superclasses class-value)))
    (instance-prototype-value class-value superclass-prototypes)))

;;; POO is the sole precedence owner. Every class generation owns one
;;; instance prototype, and each prototype points back to that exact class
;;; metaobject. Projecting prototype C4 preserves identity without a second
;;; class graph or linearization algorithm.
;; : (-> POOObject Symbol [ClosClass])
(def (compute-class-precedence-list prototype identity-value)
  (with-catch
   (lambda (failure)
     (if (clos-failure? failure)
       (raise failure)
       (clos-fail 'inconsistent-class-precedence
                  class: identity-value
                  operation: 'compute-class-precedence-list)))
   (lambda ()
     (filter-map
      (lambda (prototype)
        (and (.slot? prototype '%clos-class)
             (.ref prototype '%clos-class)))
      (compute-precedence-list! prototype)))))

;; Each owner index retains its first direct declaration for a slot name.  The
;; outer list stays in runtime C4 order, so option inheritance follows POO.
;; : (-> [ClosClass] Procedure [Pair])
(def (class-direct-slot-indexes precedence direct-slots-for)
  (map
   (lambda (owner-class)
     (cons owner-class
           (clos-leftmost-index-by
            (lambda (slot) (.ref slot 'identity))
            (direct-slots-for owner-class))))
   precedence))

;; : (-> [Pair] Symbol [Pair])
(def (slot-descriptions owner-indexes slot-name)
  (filter-map
   (lambda (owner+index)
     (let (direct-slot (hash-get (cdr owner+index) slot-name))
       (and direct-slot (cons (car owner+index) direct-slot))))
   owner-indexes))

;; : (-> [Pair] Symbol (Maybe SchemeValue))
(def (first-slot-option descriptions option)
  (let (description
        (find (lambda (entry) (.ref (cdr entry) option)) descriptions))
    (and description (.ref (cdr description) option))))

;; : (-> [Pair] Symbol [SchemeValue])
(def (merged-slot-list descriptions option)
  (unique/identity
   (flatten1
    (map (lambda (entry) (.ref (cdr entry) option))
         descriptions))))

;; : (-> [Pair] Symbol ClosEffectiveSlotDefinition)
(def (compute-effective-slot owner-indexes slot-name)
  (let* ((descriptions (slot-descriptions owner-indexes slot-name))
         (most-specific (car descriptions))
         (most-specific-slot (cdr most-specific))
         (allocation-value (.ref most-specific-slot 'allocation))
         (initfunction-value
          (first-slot-option descriptions 'initfunction))
         (documentation-value
          (first-slot-option descriptions 'documentation))
         (type-predicate-values
          (filter-map (lambda (entry) (.ref (cdr entry) 'type-predicate))
                      descriptions)))
    (seal-object!
     (checked
      ClosEffectiveSlotDefinition
      (.o (:: @ ClosEffectiveSlotDefinition.)
          identity: slot-name allocation: allocation-value
          initargs: (%make-owned-list (merged-slot-list descriptions 'initargs))
          initfunction: initfunction-value
          readers: (%make-owned-list (merged-slot-list descriptions 'readers) clos-copy-function-names)
          writers: (%make-owned-list (merged-slot-list descriptions 'writers) clos-copy-function-names)
          type-predicates: (%make-owned-list type-predicate-values)
          documentation: documentation-value
          defining-classes: (%make-owned-list (map car descriptions))
          storage-class: (car most-specific))
      'invalid-effective-slot-definition))))

;; : (-> [ClosClass] Procedure
;;        [ClosEffectiveSlotDefinition])
(def (compute-effective-slots precedence direct-slots-for)
  (let* ((owner-indexes
          (class-direct-slot-indexes precedence direct-slots-for))
         (slot-names
          (unique/identity
           (flatten1
            (map (lambda (owner-class)
                   (map (lambda (slot) (.ref slot 'identity))
                        (direct-slots-for owner-class)))
                 precedence)))))
    (map (lambda (slot-name)
           (compute-effective-slot owner-indexes slot-name))
         slot-names)))

(def (effective-slot-lookup slots)
  (let (index (clos-leftmost-index-by (lambda (slot) (.ref slot 'identity)) slots))
    (lambda (name) (hash-get index name))))

;;; Initial construction and redefinition derive lookup from the same sequence.
;; : (-> ClosClass ClosClass)
(def (refresh-effective-slots! class-value)
  (let (slots (compute-effective-slots
              (.ref class-value 'class-precedence-list)
              (lambda (owner) (.ref owner 'direct-slots))))
    (%publish-slot-edits!
     (list (list class-value
                 (cons 'effective-slots (%make-owned-list slots))
                 (cons 'effective-slot-index (effective-slot-lookup slots)))))
    class-value))

;; : (-> ClosSlotCell)
(def (make-slot-cell)
  (checked ClosSlotCell
           (.o (:: @ ClosSlotCell.) bound?: #f value: #f)
           'invalid-slot-cell))

;; : (-> ClosClass Symbol ClosSlotCell)
(def (clos-class-slot-cell class-value slot-name)
  (let* ((storage (.ref class-value 'class-storage))
         (existing (hash-ref/default storage slot-name (lambda () #f))))
    (or existing
        (let (cell (make-slot-cell))
          (hash-put! storage slot-name cell)
          cell))))

;; : (-> ClosClass ClosClass)
(def (initialize-direct-class-slots! class-value)
  (for-each
   (lambda (slot)
     (when (and (eq? (.ref slot 'allocation) 'class)
                (eq? (.ref slot 'storage-class) class-value))
       (let ((cell (clos-class-slot-cell
                    class-value (.ref slot 'identity)))
             (initfunction (.ref slot 'initfunction)))
         (when (and initfunction (not (.ref cell 'bound?)))
           (.put! cell 'value (initfunction))
           (.put! cell 'bound? #t)))))
   (.ref class-value 'effective-slots))
  class-value)

;; | ClosClass = POOObject
;; %clos-make-class-generation
;;   : (-> Symbol [ClosClass] [ClosDirectSlotDefinition] [Pair] Natural
;;        (Maybe Procedure) (Maybe Procedure)
;;        (Maybe Procedure) (Maybe Procedure) ClosClass)
;;   | contract: validates and finalizes one runtime-POO class generation before
;;     registering its direct dependency edges.
;;   | doc m%
;;       `%clos-make-class-generation` is the checked internal constructor.
;;
;;       # Examples
;;       ```scheme
;;       (%clos-make-class-generation 'root '() '() '() 0
;;                                        #f #f #f #f)
;;       ;; => class-generation
;;       ```
;;
;;       result: a complete class generation whose class and slot precedence
;;       are projected from its POO prototype C4.
;;     %
(def (%clos-make-class-generation
      identity-value superclass-values direct-slot-values
      default-initarg-values generation-value
      slot-missing-handler-value slot-unbound-handler-value
      redefinition-handler-value different-handler-value)
  (unless (symbol? identity-value)
    (clos-fail 'invalid-class-name class: identity-value))
  (let ((superclass-values (require-direct-superclasses superclass-values))
        (direct-slot-values (require-direct-slots direct-slot-values))
        (default-initarg-values
         (require-default-initargs default-initarg-values)))
  (unless (and (exact-integer? generation-value) (>= generation-value 0))
    (clos-fail 'invalid-class-generation class: identity-value))
  (unless (or (not slot-missing-handler-value)
              (procedure? slot-missing-handler-value))
    (clos-fail 'invalid-slot-missing-handler class: identity-value))
  (unless (or (not slot-unbound-handler-value)
              (procedure? slot-unbound-handler-value))
    (clos-fail 'invalid-slot-unbound-handler class: identity-value))
  (unless (or (not redefinition-handler-value)
              (procedure? redefinition-handler-value))
    (clos-fail 'invalid-redefinition-update-handler class: identity-value))
  (unless (or (not different-handler-value)
              (procedure? different-handler-value))
    (clos-fail 'invalid-different-class-update-handler class: identity-value))
  ;; Mutable storage belongs to this class identity. Allocating it inside a
  ;; computed slot recreates it when unrelated class metadata invalidates the
  ;; receiver cache (for example when registering a direct subclass).
  (let* ((class-storage-value (make-hash-table-eq))
         (candidate
        (.o (:: self ClosClass.)
            identity: identity-value
            direct-superclasses: (%make-owned-list superclass-values)
            generation: generation-value
            slot-missing-handler: slot-missing-handler-value
            slot-unbound-handler: slot-unbound-handler-value
            direct-subclasses: (%make-owned-list '())
            layout-history: (lambda (_) #f)
            redefinition-update-handler: redefinition-handler-value
            different-class-update-handler: different-handler-value
            documentation: #f metaclass: 'standard-class
            class-storage: class-storage-value
            instance-prototype: (make-instance-prototype self)
            class-precedence-list:
            (%make-owned-list
             (compute-class-precedence-list
              (.ref self 'instance-prototype) identity-value))
            class-precedence-index:
            (clos-position-lookup
             (%ref-owned-list self 'class-precedence-list))
            effective-slots: '()
            effective-slot-index: (lambda (_) #f))))
    (.putslot! candidate 'direct-slots (%owned-list-slot-spec direct-slot-values))
    (.putslot! candidate 'default-initargs
      (%owned-list-slot-spec default-initarg-values copy-default-initargs))
    (let (class-value
          (initialize-direct-class-slots!
           (refresh-effective-slots!
            (checked ClosClass candidate 'invalid-class))))
      (for-each
       (lambda (superclass)
         (.put! superclass 'direct-subclasses
                (%make-owned-list
                 (cons class-value (.ref superclass 'direct-subclasses)))))
       superclass-values)
      class-value))))

;;; Redefinition preserves the class metaobject identity required by ANSI
;;; Common Lisp 4.3.6.  Historical effective-slot projections remain inert
;;; layout evidence for lazy instance migration; they are not class objects and
;;; cannot participate in dispatch or inheritance.
;; : (-> ClosClass [ClosClass] Procedure Procedure POOObject)
(def (%clos-project-class-redefinition
      class-value superclasses prototype-for direct-slots-for)
  ;; Project against a fresh POO prototype before touching the live
  ;; class or either parent's dependency edge.
  (let* ((prototype-value
          (instance-prototype-value
           class-value (map prototype-for superclasses)))
         (precedence-value
          (compute-class-precedence-list
           prototype-value (.ref class-value 'identity)))
         (effective-slots-value
          (compute-effective-slots precedence-value direct-slots-for)))
    (.o prototype: prototype-value
        precedence: precedence-value
        precedence-index: (clos-position-lookup precedence-value)
        effective-slots: effective-slots-value
        effective-slot-index: (effective-slot-lookup effective-slots-value))))

;; Retain the old immutable spine privately. A new history entry shares its
;; predecessors, and a query copies only the selected generation's list.
(def (%clos-class-redefinition-edits
      class-value superclass-values direct-slot-values default-initarg-values
      slot-missing-handler-value slot-unbound-handler-value
      redefinition-handler-value different-handler-value projection)
  (unless (element? ClosClass class-value) (clos-fail 'invalid-class))
  (def parents (require-direct-superclasses superclass-values))
  (def slots (require-direct-slots direct-slot-values))
  (def defaults (require-default-initargs default-initarg-values))
  (def generation (.ref class-value 'generation))
  (def previous-slots (%ref-owned-list class-value 'effective-slots))
  (def history (.ref class-value 'layout-history))
  (list class-value
        (cons 'layout-history
              (lambda (requested)
                (if (= requested generation) (list-copy previous-slots)
                    (history requested))))
        (cons 'direct-superclasses (%make-owned-list parents))
        (cons 'direct-slots (%make-owned-list slots))
        (cons 'default-initargs (%make-owned-list defaults copy-default-initargs))
        (cons 'slot-missing-handler slot-missing-handler-value)
        (cons 'slot-unbound-handler slot-unbound-handler-value)
        (cons 'redefinition-update-handler redefinition-handler-value)
        (cons 'different-class-update-handler different-handler-value)
        (cons 'generation (+ 1 generation))
        (cons 'instance-prototype (.ref projection 'prototype))
        (cons 'class-precedence-list (%make-owned-list (.ref projection 'precedence)))
        (cons 'class-precedence-index (.ref projection 'precedence-index))
        (cons 'effective-slots (%make-owned-list (.ref projection 'effective-slots)))
        (cons 'effective-slot-index (.ref projection 'effective-slot-index))))

;;; The root class contributes no slots; all ordinary classes with an omitted
;;; superclass list inherit from this exact class and POO prototype.
(def clos-standard-object-class
  (%clos-make-class-generation
   'standard-object '() '() '() 0 #f #f #f #f))

(hash-put! clos-class-registry 'standard-object
           clos-standard-object-class)

;; | ClosClass = POOObject
;; clos-class
;;   : (-> Symbol direct-superclasses: [ClosClass]
;;         direct-slots: [ClosDirectSlotDefinition]
;;         default-initargs: [Pair] slot-missing-handler: (Maybe Procedure)
;;         slot-unbound-handler: (Maybe Procedure) ClosClass)
;;   | contract: creates one finalized class generation whose instance
;;     prototype is the single POO inheritance and precedence owner.
;;   | doc m%
;;   | result: a POO class metaobject with lazy effective slots.
(def (clos-class
      identity-value direct-superclasses: (superclass-values #f)
      direct-slots: (direct-slot-values '())
      default-initargs: (default-initarg-values '())
      slot-missing-handler: (slot-missing-handler-value #f)
      slot-unbound-handler: (slot-unbound-handler-value #f)
      redefinition-update-handler: (redefinition-handler-value #f)
      different-class-update-handler: (different-handler-value #f)
      documentation: (documentation-value #f)
      metaclass: (metaclass-value 'standard-class))
  (unless (or (not documentation-value) (string? documentation-value))
    (clos-fail 'invalid-class-documentation class: identity-value))
  (let (class-value
        (%clos-make-class-generation
         identity-value
         (map clos-resolve-class
              (or superclass-values (list clos-standard-object-class)))
         direct-slot-values default-initarg-values 0
         slot-missing-handler-value slot-unbound-handler-value
         redefinition-handler-value different-handler-value))
    (.put! class-value 'documentation documentation-value)
    (.put! class-value 'metaclass metaclass-value)
    (hash-put! clos-class-registry identity-value class-value)
    class-value))

;; : (-> ClosClass [ClosEffectiveSlotDefinition])
(def (clos-class-effective-slots class-value)
  (unless (element? ClosClass class-value) (clos-fail 'invalid-class))
  (.ref class-value 'effective-slots))

;; : (-> ClosClass Symbol (Maybe ClosEffectiveSlotDefinition))
(def (clos-find-effective-slot class-value slot-name)
  (unless (element? ClosClass class-value) (clos-fail 'invalid-class))
  ((.ref class-value 'effective-slot-index) slot-name))

;; : (-> ClosClass ClosClass Boolean)
(def (clos-class-subclass? class-value superclass-value)
  (and (element? ClosClass class-value)
       (element? ClosClass superclass-value)
       (if ((.ref class-value 'class-precedence-index) superclass-value)
         #t
         #f)))
