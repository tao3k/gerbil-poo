;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; POO CLOS descriptor family.
;;;
;;; This factor owns values and validation only.  Dispatch and mutation policy
;;; remain in their dedicated factors.

(import :clan/poo/object
        :clan/poo/read-projection
        (only-in :clan/poo/class-validation required-slots? with-present-slot)
        (only-in :clan/poo/mop/prototype prototype-instance?)
        (only-in :clan/poo/mop/prototype define-type Type. Class. Slot Bool Type element? raise-type-error)
        (only-in "funcs.ss"
                 clos-function-name? clos-function-name-list? clos-qualifier?
                 clos-initarg-name-list? clos-default-initargs?))

(export ClosSpecializer ClosLambdaList ClosMethod ClosMethodBundle
        ClosMethodGroup ClosMethodCombination
        ClosGenericProtocol ClosGenericFunction ClosGenericBinding ClosEffectiveMethod
        ClosInvocationFrame ClosFailure ClosUnboundSlotFailure
        ClosDirectSlotDefinition
        ClosEffectiveSlotDefinition ClosClass ClosInstanceState ClosSlotCell
        ClosMopProfile clos-carrier-policy-guard)

(def ClosType. Type.)

(extern namespace: clan/poo/object %ref-owned-list %registered-field-reader
  %prepared-vector-slots-ref object-read-value %register-slot-dependencies!
  object-construction-current?)
(import (only-in :clan/poo/slot-observation %slot-read-active?
          slot-read-observers-compatible? %call-with-recorded-slot-reads
          slot-read-key slot-read-receiver))
(extern namespace: clan/poo/slot-observation %borrow-owned-list)
(extern namespace: clan/poo/read-projection %owned-closed-registration?)

(def (%closed-registered-field-reader candidate)
  (and (%owned-closed-registration?) (%registered-field-reader candidate)))

;; Closed groups contain only stock predicates over already registered reads.
;; A probe miss resumes the original sequence with its ordinary effect boundary.
(defrules check-closed-slots (owned-list)
  ((_ read ordinary) #t)
  ((_ read ordinary (name predicate owned-list) remaining ...)
   (let (value (read 'name))
     (if (eq? value absent-value) (ordinary)
       (and (predicate (%borrow-owned-list value))
            (check-closed-slots read ordinary remaining ...)))))
  ((_ read ordinary (name predicate) remaining ...)
   (let (value (read 'name))
     (if (eq? value absent-value) (ordinary)
       (and (predicate value) (check-closed-slots read ordinary remaining ...))))))

(defrules ordinary-closed-slot (owned-list)
  ((_ receiver (name predicate owned-list))
   (required-slots? receiver (name predicate read: %ref-owned-list)))
  ((_ receiver (name predicate))
   (required-slots? receiver (name predicate))))

(defrule (closed-required-slots? candidate field ...)
  (let* ((receiver candidate) (read (%closed-registered-field-reader receiver)))
    (def (ordinary) (and (ordinary-closed-slot receiver field) ... #t))
    (if read (check-closed-slots read ordinary field ...) (ordinary))))

(def (clos-prototype type-value kind-value)
  (.o .type: type-value kind: kind-value schema: 'v1))

(def (natural? value)
  (and (exact-integer? value) (>= value 0)))

(def (symbol-or-false? value)
  (or (not value) (symbol? value)))

(def (any-value? _value) #t)

(def (procedure-or-false? value)
  (or (not value) (procedure? value)))

(def (string-or-false? value)
  (or (not value) (string? value)))

(def (symbol-list? value)
  (and (list? value) (andmap symbol? value)))

(def (specializer-kind? value)
  (if (memq value '(any class prototype eql)) #t #f))

(def (method-combination? value)
  (and (object? value)
       (prototype-instance? (.ref ClosMethodCombination 'proto) value)))

(def (generic-protocol? value)
  (and (object? value)
       (prototype-instance? (.ref ClosGenericProtocol 'proto) value)))

(def (specializers? value)
  (and (list? value)
       (andmap (cut element? ClosSpecializer <>) value)))

(def (clos-lambda-list-element? candidate)
  (and (prototype-instance? (.ref ClosLambdaList 'proto) candidate)
       (closed-required-slots? candidate
         (required natural?)
         (optional natural?)
         (rest? boolean?)
         (key? boolean?)
         (keys clos-initarg-name-list? owned-list)
         (allow-other-keys? boolean?))))

;;; Lambda-list descriptors retain only the congruence and call-admission
;;; shape; lexical parameter bindings remain in hygienic method expansions.
(define-type (ClosLambdaList @ ClosType.)
  proto: (clos-prototype ClosLambdaList 'clos/lambda-list)
  .element?: clos-lambda-list-element?)

(def (lambda-list-or-false? value)
  (or (not value) (element? ClosLambdaList value)))

(def (methods? value)
  (and (list? value)
       (andmap (cut element? ClosMethod <>) value)))

(def (argument-precedence-order? value)
  (and (list? value) (andmap natural? value)))

(def (clos-specializer-element? candidate)
  (def (target-valid? kind target)
    (case kind
      ((any) (not (target)))
      ((class) (element? ClosClass (target)))
      ((prototype) (object? (target)))
      ((eql) #t)
      (else #f)))
  (def (ordinary)
    (and (required-slots? candidate (kind specializer-kind?) (target any-value?))
         (target-valid? (.ref candidate 'kind) (lambda () (.ref candidate 'target)))))
  (and (prototype-instance? (.ref ClosSpecializer 'proto) candidate)
       (let (read (%closed-registered-field-reader candidate))
         (if read
           (let (kind (read 'kind))
             (cond
              ((eq? kind absent-value) (ordinary))
              ((not (specializer-kind? kind)) #f)
              (else
               (let (target (read 'target))
                 (if (eq? target absent-value) (ordinary)
                   (target-valid? kind (lambda () target)))))))
           (ordinary)))))

;;; Boundary: a specializer records only matching identity; it never owns or
;;; mutates a class, prototype, or argument value.
(define-type (ClosSpecializer @ ClosType.)
  proto: (clos-prototype ClosSpecializer 'clos/specializer)
  .element?: clos-specializer-element?)

(def (clos-method-element? candidate)
  (and (prototype-instance? (.ref ClosMethod 'proto) candidate)
       (required-slots? candidate
         (identity clos-function-name?)
         (specializers specializers? read: %ref-owned-list))
       (closed-required-slots? candidate
         (qualifier clos-qualifier? owned-list) (body procedure?))
       (required-slots? candidate (lambda-list lambda-list-or-false?))
       (closed-required-slots? candidate
         (generic-function any-value?) (synthetic-effective-method? boolean?))))

;;; Invariant: a method is executable only through a generic-owned applicable
;;; effective method; its body is not a standalone public procedure contract.
(define-type (ClosMethod @ ClosType.)
  proto: (clos-prototype ClosMethod 'clos/method)
  .element?: clos-method-element?)

(def (combination-kind? value)
  (if (memq value '(standard short long)) #t #f))

(def (combination-order? value)
  (if (memq value '(most-specific-first most-specific-last)) #t #f))

(def (operator-or-false? value)
  (or (not value) (symbol? value) (procedure? value)))

(def (method-group-matcher? value)
  (or (eq? value '*) (list? value) (pair? value) (procedure? value)))

(def (method-group-matchers? value)
  (and (list? value) (pair? value) (andmap method-group-matcher? value)))

(def (clos-method-group-element? candidate)
  (and (prototype-instance? (.ref ClosMethodGroup 'proto) candidate)
       (required-slots? candidate
         (identity symbol?)
         (matchers method-group-matchers?)
         (order combination-order?)
         (required? boolean?)
         (description string-or-false?))))

;;; A long-form method group owns qualifier selection, order, requirement, and
;;; reflection text without owning executable method bodies.
(define-type (ClosMethodGroup @ ClosType.)
  proto: (clos-prototype ClosMethodGroup 'clos/method-group)
  .element?: clos-method-group-element?)

(def (method-groups? value)
  (and (list? value) (andmap (cut element? ClosMethodGroup <>) value)))

(def (clos-method-combination-element? candidate)
  (and (prototype-instance? (.ref ClosMethodCombination 'proto) candidate)
       (required-slots? candidate
         (identity symbol?)
         (kind combination-kind?)
         (operator operator-or-false?)
         (order combination-order?)
         (identity-with-one-argument? boolean?)
         (groups method-groups?)
         (effective-builder procedure-or-false?)
         (configurer procedure-or-false?)
         (configuration list?)
         (documentation string-or-false?)
         (.admits-qualifier? procedure?))))

;;; A method-combination descriptor is inert POO policy data.  Dispatch owns
;;; invocation, and a long-form builder can only return a checked effective method.
(define-type (ClosMethodCombination @ ClosType.)
  proto: (clos-prototype ClosMethodCombination 'clos/method-combination)
  .element?: clos-method-combination-element?)

(def (clos-generic-protocol-element? candidate)
  (and (prototype-instance? (.ref ClosGenericProtocol 'proto) candidate)
       (required-slots? candidate
         (identity symbol?)
         (no-applicable-method procedure-or-false?)
         (no-next-method procedure-or-false?)
         (compute-applicable-methods procedure-or-false?)
         (compute-effective-method procedure-or-false?))))

;;; Generic protocol hooks are collected behind one named POO object so raw
;;; procedures never become an unowned parallel public dispatch surface.
(define-type (ClosGenericProtocol @ ClosType.)
  proto: (clos-prototype ClosGenericProtocol 'clos/generic-protocol)
  .element?: clos-generic-protocol-element?)

(def (clos-method-bundle-element? candidate)
  (and (prototype-instance? (.ref ClosMethodBundle 'proto) candidate)
       (required-slots? candidate
         (identity symbol?)
         (protocol generic-protocol?)
         (methods methods?)
         (documentation string-or-false?))))

;;; A bundle is the checked composition unit between one generic protocol and
;;; a method family.  It owns no registry and performs no dispatch itself.
(define-type (ClosMethodBundle @ ClosType.)
  proto: (clos-prototype ClosMethodBundle 'clos/method-bundle)
  .element?: clos-method-bundle-element?)

(def (clos-generic-function-element? candidate)
  (and (prototype-instance? (.ref ClosGenericFunction 'proto) candidate)
       (closed-required-slots? candidate
         (identity clos-function-name? owned-list) (required natural?) (rest? boolean?)
         (argument-precedence-order argument-precedence-order? owned-list))
       (required-slots? candidate
         (method-combination method-combination?)
         (methods methods? read: %ref-owned-list)
         (generation natural?)
         (lambda-list (cut element? ClosLambdaList <>))
         (protocol generic-protocol?))
       (closed-required-slots? candidate
         (documentation string-or-false?)
         (generic-function-class any-value?)
         (method-class any-value?)
         (declarations list? owned-list))))

;;; Boundary: a generic value is the stable ANSI generic-function identity;
;;; method-set generation is a mutation counter, not a replacement object.
(define-type (ClosGenericFunction @ ClosType.)
  proto: (clos-prototype ClosGenericFunction 'clos/generic-function)
  .element?: clos-generic-function-element?)

(def (clos-generic-binding-element? candidate)
  (and (prototype-instance? (.ref ClosGenericBinding 'proto) candidate)
       (required-slots? candidate
         (identity clos-function-name?)
         (current (cut element? ClosGenericFunction <>)))))

;;; A binding is the explicit effect owner for top-level defmethod evolution;
;;; each current value remains an immutable generic generation.
(define-type (ClosGenericBinding @ ClosType.)
  proto: (clos-prototype ClosGenericBinding 'clos/generic-binding)
  .element?: clos-generic-binding-element?)

(def (clos-effective-method-element? candidate)
  (and (prototype-instance? (.ref ClosEffectiveMethod 'proto) candidate)
       (required-slots? candidate
         (generic (cut element? ClosGenericFunction <>))
         (arguments list?)
         (around methods?)
         (before methods?)
         (primary methods?)
         (after methods?)
         (groups list?)
         (executor procedure-or-false?))))

;;; Invariant: effective methods retain qualifier-separated methods from exactly
;;; one generic generation and one argument set.
(define-type (ClosEffectiveMethod @ ClosType.)
  proto: effective-method-prototype
  .element?: clos-effective-method-element?)

(def effective-method-prototype
  (clos-prototype ClosEffectiveMethod 'clos/effective-method))

(def (next-method? value)
  (or (not value) (procedure? value)))

(def (clos-invocation-frame-element? candidate)
  (and (prototype-instance? (.ref ClosInvocationFrame 'proto) candidate)
       (required-slots? candidate
         (effective-method (cut element? ClosEffectiveMethod <>))
         (arguments list?)
         (next next-method?)
         (qualifier clos-qualifier?)
         (method (cut element? ClosMethod <>)))))

;;; Boundary: the lexical frame owns next-method continuation access; it is not
;;; a serializable or cross-runtime capability.
(define-type (ClosInvocationFrame @ ClosType.)
  proto: invocation-frame-prototype
  .element?: clos-invocation-frame-element?)

;; Replacing a Type validator revises its policy. The carrier's prototype
;; identity still belongs to the same type and must survive recomputation.
(def invocation-frame-prototype
  (clos-prototype ClosInvocationFrame 'clos/invocation-frame))

;; This certificate belongs to the private declarations above, not to whatever
;; public policy a caller installs later. A replaced/edited policy remains
;; usable through ordinary CLOS, but is not silently certified as our code.
(def carrier-declaration-owners
  (list ClosEffectiveMethod ClosInvocationFrame
        (.ref ClosEffectiveMethod 'proto) (.ref ClosInvocationFrame 'proto)))
(def carrier-declaration-revisions (map object-revision carrier-declaration-owners))

(def (%carrier-declarations-current?)
  (andmap (lambda (owner revision) (= (object-revision owner) revision))
    carrier-declaration-owners carrier-declaration-revisions))

;; Reuse only these exact procedures, never an override with the same Type.
(def (%stock-call-validator? type procedure (class? #f))
  (cond
   ((eq? type ClosGenericFunction) (eq? procedure clos-generic-function-element?))
   ((eq? type ClosMethod) (eq? procedure clos-method-element?))
   ((eq? type ClosSpecializer) (eq? procedure clos-specializer-element?))
   ((eq? type ClosLambdaList) (eq? procedure clos-lambda-list-element?))
   ((and class? (eq? type ClosClass)) (eq? procedure clos-class-element?))
   (else #f)))

;; Certify only our two original, hook-free carrier predicates/prototypes for
;; ONE dynamic operation. Revisions reject mutate-and-restore callbacks too.
;; This does not certify contributor methods or arbitrary Type predicates.
(def (clos-carrier-policy-guard effective-proto frame-proto)
  (def owners (list ClosEffectiveMethod ClosInvocationFrame effective-proto frame-proto))
  (def revisions (map object-revision owners))
  (def closed?
    (and (andmap eq? owners carrier-declaration-owners)
         (equal? revisions carrier-declaration-revisions)
         (eq? (.ref ClosEffectiveMethod '.element?) clos-effective-method-element?)
         (eq? (.ref ClosInvocationFrame '.element?) clos-invocation-frame-element?)
         (eq? (.ref ClosEffectiveMethod 'proto) effective-proto)
         (eq? (.ref ClosInvocationFrame 'proto) frame-proto)
         (andmap (lambda (owner)
                   (compute-precedence-list! owner)
                   (not (object-protocol owner))) owners)))
  (lambda ()
    ;; Runtime names queries retain these exact owner revisions in an enclosing
    ;; read frame, without forcing policy fields or minting application records.
    (for-each .all-slots owners)
    (and closed? (equal? revisions (map object-revision owners)))))

(def (allocation? value)
  (if (memq value '(instance class)) #t #f))

(def (clos-direct-slot-definition-element? candidate)
  (and (prototype-instance? (.ref ClosDirectSlotDefinition 'proto) candidate)
       (element? Slot candidate)
       (required-slots? candidate
         (identity symbol?)
         (allocation allocation?)
         (initargs clos-initarg-name-list?)
         (initfunction procedure-or-false?)
         (readers clos-function-name-list?)
         (writers clos-function-name-list?)
         (documentation string-or-false?))))

;;; A direct slot is an inert declaration value.  Captured initforms are
;;; represented as thunks so their lexical environment remains Scheme-owned.
(define-type (ClosDirectSlotDefinition @ Slot)
  proto: (.mix (clos-prototype ClosDirectSlotDefinition
                              'clos/direct-slot-definition)
               (.ref Slot 'proto))
  .element?: clos-direct-slot-definition-element?)

(def (class-reference? value)
  (and (object? value)
       (prototype-instance? (.ref ClosClass 'proto) value)))

(def (class-references? value)
  (and (list? value) (andmap class-reference? value)))

(def (clos-effective-slot-definition-element? candidate)
  (and (prototype-instance? (.ref ClosEffectiveSlotDefinition 'proto) candidate)
       (element? Slot candidate)
       (required-slots? candidate
         (identity symbol?)
         (allocation allocation?)
         (initargs clos-initarg-name-list?)
         (initfunction procedure-or-false?)
         (readers clos-function-name-list?)
         (writers clos-function-name-list?)
         (documentation string-or-false?)
         (defining-classes class-references?)
         (storage-class class-reference?))))

;;; Effective slots are immutable projections over the POO class CPL.
(define-type (ClosEffectiveSlotDefinition @ Slot)
  proto: (.mix (clos-prototype ClosEffectiveSlotDefinition
                              'clos/effective-slot-definition)
               (.ref Slot 'proto))
  .element?: clos-effective-slot-definition-element?)

(def (direct-slot-definitions? value)
  (and (list? value)
       (andmap (cut element? ClosDirectSlotDefinition <>) value)))

;; Only the successful stock direct-slot subcheck moves to publication.
;; The proof owner holds no lookup table; the existing weak POO source
;; edges advance its revision when the validation support changes.
(defstruct direct-slot-proof (class generation slots owner) final: #t)

(def stock-slot-policies
  (and (andmap (lambda (type) (zero? (object-revision type)))
               (list ClosDirectSlotDefinition Slot Bool Type))
       (list (list ClosDirectSlotDefinition '.element? clos-direct-slot-definition-element?)
             (list Slot '.element? (.ref Slot '.element?))
             (list Slot '.slot.check (.ref Slot '.slot.check))
             (list Bool '.element? (.ref Bool '.element?))
             (list Type '.element? (.ref Type '.element?)))))

(def (%quiet-direct-slot-check?)
  (and (not (%slot-read-active?)) (slot-read-observers-compatible? '())))

(extern namespace: clan/poo/clos/classes %class-publication-direct-proof)

(def (%capture-direct-slot-proof slots action)
  (if (and (pair? slots) stock-slot-policies (%quiet-direct-slot-check?)
           (object-construction-current?)
           (andmap (lambda (policy) (zero? (object-revision (car policy))))
                   stock-slot-policies)
           (list? slots)
           (andmap (lambda (slot)
                     (and (object-precedence-ready? slot) (not (object-protocol slot))))
                   slots))
    (let-values (((valid roots) (%call-with-recorded-slot-reads action unique-roots?: #t)))
      (values valid
        (and valid
             (with-catch (lambda (_) #f)
               (lambda ()
                 (and (andmap stock-direct-slot-read? roots)
                      (let (owner (make-object))
                        (%register-slot-dependencies! owner roots)
                        owner)))))))
    (values (action) #f)))

(def (stock-direct-slot-read? read)
  (def key (slot-read-key read))
  (def receiver (slot-read-receiver read))
  (def value (object-read-value read))
  (and (not (object-protocol receiver))
       (cond ((memq key '(.element? .slot.check))
              (ormap (lambda (policy)
                       (and (eq? receiver (car policy))
                            (eq? key (cadr policy))
                            (eq? value (caddr policy))))
                     stock-slot-policies))
             ((pair? key)
              (not (eq? (car key) 'bootstrap)))
             ;; List-shaped field data must have an owned spine.
             (else (not (pair? value))))))

(def (published-direct-slots? class-value)
  (and (%quiet-direct-slot-check?)
       (let (revision (object-revision class-value))
         (defvalues (publication slots generation)
           (%prepared-vector-slots-ref class-value '%effective-slot-initargs 'direct-slots 'generation))
         (def proof (%class-publication-direct-proof publication))
         (and (direct-slot-proof? proof)
              (eq? class-value (direct-slot-proof-class proof))
              (eq? (direct-slot-proof-slots proof) slots)
              (eqv? (direct-slot-proof-generation proof) generation)
              (zero? (object-revision (direct-slot-proof-owner proof)))
              (= revision (object-revision class-value))))))

(def (clos-direct-slots-element? candidate)
  (if (%quiet-direct-slot-check?)
    ;; Class owns this list spine. Test emptiness before asking for evidence;
    ;; the inherited standard Class is checked for every Class specializer.
    (with-present-slot (slots candidate 'direct-slots read: %ref-owned-list)
      (or (null? slots)
          (and (pair? slots) (published-direct-slots? candidate))
          (direct-slot-definitions? slots))
      #f)
    (required-slots? candidate (direct-slots direct-slot-definitions?))))

(def (clos-class-element? candidate)
  (and (prototype-instance? (.ref ClosClass 'proto) candidate)
       (required-slots? candidate
         (identity symbol?)
         (direct-superclasses class-references?))
       (clos-direct-slots-element? candidate)
       (required-slots? candidate
         (default-initargs clos-default-initargs?)
         (generation natural?)
         (slot-missing-handler procedure-or-false?)
         (slot-unbound-handler procedure-or-false?)
         (direct-subclasses class-references?)
         (redefinition-update-handler procedure-or-false?)
         (different-class-update-handler procedure-or-false?)
         (documentation string-or-false?)
         (metaclass any-value?))))

;;; Class metaobjects own lazy runtime prototypes and class-allocated storage;
;;; they do not replace gerbil-poo's inheritance or C4 implementation.
(define-type (ClosClass @ ClosType.)
  slot-descriptor-class: ClosEffectiveSlotDefinition
  proto:
  (.o (:: self [Class. (clos-prototype ClosClass 'clos/class)])
      slots: (seal-object!
              (object<-alist
               (map (lambda (slot) (cons (.ref slot 'identity) slot))
                    (.ref self 'effective-slot-definitions))))
      (effective-slots (inherited)
        (let (slots (inherited))
          (.for-each! slots (lambda (_name slot) (seal-object! slot)))
          (seal-object! slots)))
      proto: (.ref self 'instance-prototype)
      (.validate (inherited)
        (lambda (candidate)
          (if (and (object? candidate) (.slot? candidate '%clos-state))
            ;; Canonical cells were normalized on write. Rechecking a mutable
            ;; instance must not wrap FUN fields again or create a second store.
            (with-slot-dependencies candidate
              (lambda ()
                (unless (.call self .element? candidate)
                  (raise-type-error self candidate))
                candidate))
            ((inherited) candidate))))
      (.element? (inherited)
        (lambda (candidate)
          (and (object? candidate)
               (if (.slot? candidate '%clos-state)
                 (let (state (.ref candidate '%clos-state))
                   (and (element? ClosInstanceState state)
                        (let (current-class (.ref state 'class))
                          (and (= (.ref state 'generation) (.ref current-class 'generation))
                               (memq self (.ref current-class 'class-precedence-list))))))
                 (prototype-instance? (.ref self 'instance-prototype) candidate))
               ((inherited) candidate)))))
  .element?: clos-class-element?)

(def (clos-instance-state-element? candidate)
  (and (prototype-instance? (.ref ClosInstanceState 'proto) candidate)
       (required-slots? candidate
         (class class-reference?)
         (generation natural?)
         (storage hash-table?))))

;;; An instance state is the explicit identity-preserving mutation boundary.
(define-type (ClosInstanceState @ ClosType.)
  proto: (clos-prototype ClosInstanceState 'clos/instance-state)
  .element?: clos-instance-state-element?)

(def (clos-slot-cell-element? candidate)
  (and (prototype-instance? (.ref ClosSlotCell 'proto) candidate)
       (required-slots? candidate (bound? boolean?) (value any-value?))))

;;; Slot cells distinguish an unbound slot from a slot whose value is =#f=.
(define-type (ClosSlotCell @ ClosType.)
  proto: (clos-prototype ClosSlotCell 'clos/slot-cell)
  .element?: clos-slot-cell-element?)

(def (clos-mop-profile-element? candidate)
  (and (prototype-instance? (.ref ClosMopProfile 'proto) candidate)
       (required-slots? candidate
         (identity symbol?)
         (version symbol?)
         (status symbol?)
         (operations symbol-list?)
         (dependency-readers symbol-list?)
         (customization-protocols symbol-list?)
         (sealed? boolean?)
         (documentation string-or-false?))))

;;; A MOP profile is a sealed capability inventory.  It exposes no mutable
;;; registry and therefore cannot add a second metaobject dispatch hierarchy.
(define-type (ClosMopProfile @ ClosType.)
  proto: (clos-prototype ClosMopProfile 'clos/mop-profile)
  .element?: clos-mop-profile-element?)

(def (clos-failure-element? candidate)
  (and (prototype-instance? (.ref ClosFailure 'proto) candidate)
       (required-slots? candidate
         (code symbol?)
         (generic any-value?)
         (qualifier any-value?)
         (method any-value?)
         (class symbol-or-false?)
         (slot symbol-or-false?)
         (operation symbol-or-false?))))

;;; Boundary: failures preserve symbolic dispatch context and never retain raw
;;; argument payloads.
(define-type (ClosFailure @ ClosType.)
  proto: (clos-prototype ClosFailure 'clos/failure)
  .element?: clos-failure-element?)

;;; The inherited failure prototype is stable for the lifetime of this module.
;;; Hoist it once so subtype construction does not repeat reflective lookup.
(def ClosFailure. (.ref ClosFailure 'proto))

(def (clos-unbound-slot-failure-element? candidate)
  (and (element? ClosFailure candidate)
       (prototype-instance? (.ref ClosUnboundSlotFailure 'proto) candidate)
       (required-slots? candidate (instance any-value?))))

;;; UNBOUND-SLOT refines the common failure carrier with the exact instance;
;;; the inherited `slot` field is its cell-error name adaptation.
(define-type (ClosUnboundSlotFailure @ ClosFailure)
  proto: (.o (:: @ ClosFailure.)
             .type: ClosUnboundSlotFailure
             kind: 'clos/unbound-slot schema: 'v1)
  .element?: clos-unbound-slot-failure-element?)
