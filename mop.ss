;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public POO metaobject protocol.

(import (except-in "mop/prototype.ss" .defclass .defgeneric)
        (rename-in (only-in "mop/prototype.ss" .defclass .defgeneric)
                   (.defclass .defprototype-class)
                   (.defgeneric .defreceiver-generic))
        "clos/types.ss" "clos/objects.ss" "clos/generic-evolution.ss" "clos/classes.ss"
        "clos/model.ss"
        "clos/evolution.ss" "clos/lifecycle.ss" "clos/reflection.ss" "clos/dispatch.ss"
        "clos/load-form.ss" "clos/mop.ss"
        (except-in "clos/syntax.ss" .defclass .defgeneric)
        (rename-in (only-in "clos/syntax.ss" .defclass .defgeneric)
                   (.defclass .defclos-class)
                   (.defgeneric .defclos-generic)))

(export (except-out (import: "mop/prototype.ss")
                    .defclass .defgeneric .defprototype-class .defreceiver-generic
                    Any Bool Object MonomorphicObject. MonomorphicObject ObjectObject
                    Function. Function CaseFunction Fun
                    Type Type. define-type element? validate TypeError TypeError? raise-type-error)
        ClosSpecializer ClosLambdaList ClosMethod ClosMethodBundle ClosMethodGroup
        ClosMethodCombination
        ClosGenericProtocol ClosGenericFunction ClosGenericBinding ClosEffectiveMethod
        ClosInvocationFrame ClosFailure ClosUnboundSlotFailure
        ClosDirectSlotDefinition
        ClosEffectiveSlotDefinition ClosClass ClosInstanceState ClosSlotCell
        ClosMopProfile
        clos-any-specializer clos-class-specializer
        clos-prototype-specializer
        clos-eql-specializer clos-method clos-generic-function
        clos-add-method clos-remove-method clos-failure?
        clos-unbound-slot? clos-unbound-slot-instance
        clos-lambda-list clos-lambda-lists-congruent?
        clos-standard-method-combination
        clos-built-in-method-combination
        clos-short-method-combination
        clos-method-group
        clos-long-method-combination
        clos-configure-method-combination
        clos-resolve-method-combination
        clos-method-combination-admits-qualifier?
        clos-generic-protocol clos-default-generic-protocol
        clos-method-bundle clos-compose-method-bundle
        clos-compose-method-bundles
        clos-generic-binding clos-generic-binding-current
        clos-generic-binding-add-method!
        clos-register-generic-function! clos-find-generic-function
        clos-ensure-generic-function
        clos-reinitialize-generic-function!
        clos-compute-applicable-methods clos-call
        clos-compute-effective-method
        clos-call-carrier-policy-guard
        clos-no-applicable-method clos-no-next-method
        clos-no-applicable-method-generic
        clos-no-next-method-generic
        clos-effective-method-group clos-call-method
        clos-make-method
        clos-call-next-method clos-next-method?
        clos-funcall clos-setf
        clos-make-load-form clos-make-load-form-generic
        clos-make-load-form-saving-slots
        clos-standard-object-class clos-direct-slot-definition
        clos-class clos-class-precedence-list
        clos-find-class clos-set-find-class! clos-resolve-class
        clos-class-effective-slots clos-find-effective-slot
        clos-model-prototype clos-model-validation-failure
        clos-model? clos-check-model
        clos-class-subclass?
        clos-redefine-class clos-make-instances-obsolete
        clos-instance? clos-class-of
        clos-allocate-instance clos-make-instance
        clos-initialize-instance clos-shared-initialize
        clos-reinitialize-instance clos-slot-value
        clos-set-slot-value! clos-slot-bound? clos-slot-exists?
        clos-slot-missing clos-slot-unbound
        clos-slot-missing-generic clos-slot-unbound-generic
        clos-slot-makunbound! clos-slot-reader-method
        clos-slot-writer-method clos-change-class
        clos-update-instance-for-redefined-class
        clos-update-instance-for-different-class
        clos-allocate-instance-generic clos-make-instance-generic
        clos-initialize-instance-generic
        clos-shared-initialize-generic
        clos-reinitialize-instance-generic clos-change-class-generic
        clos-update-instance-for-redefined-class-generic
        clos-update-instance-for-different-class-generic
        clos-class-name clos-set-class-name!
        clos-class-name-generic clos-set-class-name-generic
        clos-class-generation
        clos-class-direct-superclasses clos-class-direct-subclasses
        clos-class-direct-slots clos-class-default-initargs
        clos-class-documentation clos-class-metaclass
        clos-instance-slot-names
        clos-slot-name clos-slot-allocation clos-slot-initargs
        clos-slot-readers clos-slot-writers
        clos-slot-defining-classes clos-slot-storage-class
        clos-specializer-kind clos-specializer-object
        clos-method-name clos-method-qualifiers
        clos-method-specializers clos-method-lambda-list
        clos-method-generic-function clos-find-method
        clos-function-keywords
        clos-generic-name clos-generic-methods
        clos-generic-lambda-list clos-generic-argument-precedence-order
        clos-generic-method-combination clos-generic-generation
        clos-generic-documentation
        clos-generic-function-class clos-generic-method-class
        clos-mop-extended-profile clos-mop-profile-admits?
        .defclass .defgeneric .defmethod .defmethod-bundle .generic-object
        .with-slots .with-accessors
        .define-method-combination)

;; CLOS declares a name, a list of superclasses, and a separate list of slots.
;; Prototype declarations put superclass options in the class head.
(defsyntax (.defclass stx)
  (syntax-case stx ()
    ((_ name (super ...) (slot ...) option ...)
     (and (identifier? #'name) (andmap identifier? (syntax->list #'(super ...))))
     #'(.defclos-class name (super ...) (slot ...) option ...))
    ((_ head slots option ...)
     #'(.defprototype-class head slots option ...))))

;; Receiver declarations have an inline receiver signature. Multi-method
;; declarations give a function name (including setf names) and a lambda list.
(defsyntax (.defgeneric stx)
  (syntax-case stx ()
    ((_ (writer name) (parameter ...) option ...)
     (eq? (syntax-e #'writer) 'setf)
     #'(.defclos-generic (writer name) (parameter ...) option ...))
    ((_ (name receiver . formals) option ...)
     #'(.defreceiver-generic (name receiver . formals) option ...))
    ((_ name lambda-list option ...)
     #'(.defclos-generic name lambda-list option ...))))
