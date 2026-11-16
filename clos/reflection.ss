;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Read-only class and instance reflection over POO metaobjects.

(import :clan/poo/object
        (only-in :clan/poo/mop/prototype element?)
        (only-in :std/list/list find)
        "types.ss" "objects.ss" "classes.ss" "lifecycle.ss" "dispatch.ss")

(export clos-class-name clos-set-class-name!
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
        clos-generic-function-class clos-generic-method-class)

;; : (-> SchemeValue ClosClass)
(def (require-class value)
  (checked ClosClass value 'invalid-class))

;; : ClosGenericFunction
(def clos-class-name-generic
  (clos-add-method
   (clos-generic-function 'class-name 1)
   (clos-method
    'class-name/default (list (clos-any-specializer))
    (lambda (_frame class-value)
      (.ref (require-class class-value) 'identity))
    lambda-list: (clos-lambda-list 1 0 #f #f '() #f))))

;; : ClosGenericFunction
(def clos-set-class-name-generic
  (clos-add-method
   (clos-generic-function '(setf class-name) 2)
   (clos-method
    'set-class-name/default
    (list (clos-any-specializer) (clos-any-specializer))
    (lambda (_frame new-name class-value)
      (%clos-set-class-name! new-name class-value))
    lambda-list: (clos-lambda-list 2 0 #f #f '() #f))))

;; : (-> ClosClass Symbol)
(def (clos-class-name class-value)
  (clos-call clos-class-name-generic class-value))

;; : (-> Symbol ClosClass Symbol)
(def (clos-set-class-name! new-name class-value)
  (clos-call clos-set-class-name-generic new-name class-value))

;; : (-> ClosClass Natural)
(def (clos-class-generation class-value)
  (.ref (require-class class-value) 'generation))

;; : (-> ClosClass [ClosClass])
(def (clos-class-direct-superclasses class-value)
  (list-copy (.ref (require-class class-value) 'direct-superclasses)))

;; : (-> ClosClass [ClosClass])
(def (clos-class-direct-subclasses class-value)
  (list-copy (.ref (require-class class-value) 'direct-subclasses)))

;; : (-> ClosClass [ClosDirectSlotDefinition])
(def (clos-class-direct-slots class-value)
  (.ref (require-class class-value) 'direct-slots))

;; : (-> ClosClass [Pair])
(def (clos-class-default-initargs class-value)
  (.ref (require-class class-value) 'default-initargs))

(def (clos-class-documentation class-value)
  (.ref (require-class class-value) 'documentation))

(def (clos-class-metaclass class-value)
  (.ref (require-class class-value) 'metaclass))

;; : (-> ClosInstance [Symbol])
(def (clos-instance-slot-names instance-value)
  (map (lambda (slot) (.ref slot 'identity))
       (clos-class-effective-slots
       (clos-class-of instance-value))))

;; : (-> ClosEffectiveSlotDefinition Symbol)
(def (clos-slot-name slot-value)
  (.ref (checked ClosEffectiveSlotDefinition slot-value
                 'invalid-effective-slot-definition)
        'identity))

;; : (-> ClosEffectiveSlotDefinition SlotAllocation)
(def (clos-slot-allocation slot-value)
  (.ref (checked ClosEffectiveSlotDefinition slot-value
                 'invalid-effective-slot-definition)
        'allocation))

;; : (-> ClosEffectiveSlotDefinition [InitargName])
(def (clos-slot-initargs slot-value)
  (list-copy
   (.ref (checked ClosEffectiveSlotDefinition slot-value
                  'invalid-effective-slot-definition)
         'initargs)))

;; : (-> ClosEffectiveSlotDefinition [Symbol])
(def (clos-slot-readers slot-value)
  (list-copy
   (.ref (checked ClosEffectiveSlotDefinition slot-value
                  'invalid-effective-slot-definition)
         'readers)))

;; : (-> ClosEffectiveSlotDefinition [Symbol])
(def (clos-slot-writers slot-value)
  (list-copy
   (.ref (checked ClosEffectiveSlotDefinition slot-value
                  'invalid-effective-slot-definition)
         'writers)))

;; : (-> ClosEffectiveSlotDefinition [ClosClass])
(def (clos-slot-defining-classes slot-value)
  (list-copy
   (.ref (checked ClosEffectiveSlotDefinition slot-value
                  'invalid-effective-slot-definition)
         'defining-classes)))

;; : (-> ClosEffectiveSlotDefinition ClosClass)
(def (clos-slot-storage-class slot-value)
  (.ref (checked ClosEffectiveSlotDefinition slot-value
                 'invalid-effective-slot-definition)
        'storage-class))

;; : (-> ClosSpecializer Symbol)
(def (clos-specializer-kind specializer-value)
  (.ref (checked ClosSpecializer specializer-value
                 'invalid-specializer)
        'kind))

;; : (-> ClosSpecializer SchemeValue)
(def (clos-specializer-object specializer-value)
  (.ref (checked ClosSpecializer specializer-value
                 'invalid-specializer)
        'target))

;; : (-> ClosMethod Symbol)
(def (clos-method-name method-value)
  (.ref (checked ClosMethod method-value 'invalid-method) 'identity))

;; : (-> ClosMethod [MethodQualifier])
(def (clos-method-qualifiers method-value)
  (list-copy (method-qualifier-list
              (.ref (checked ClosMethod method-value 'invalid-method) 'qualifier))))

;; : (-> ClosMethod [ClosSpecializer])
(def (clos-method-specializers method-value)
  (list-copy
   (.ref (checked ClosMethod method-value 'invalid-method)
         'specializers)))

;; : (-> ClosMethod (Maybe ClosLambdaList))
(def (clos-method-lambda-list method-value)
  (.ref (checked ClosMethod method-value 'invalid-method)
        'lambda-list))

;; : (-> ClosMethod (Maybe ClosGenericFunction))
(def (clos-method-generic-function method-value)
  (.ref (checked ClosMethod method-value 'invalid-method)
        'generic-function))

;; : (-> ClosMethod (values [InitargName] Boolean))
(def (clos-function-keywords method-value)
  (let (lambda-list-value
        (clos-method-lambda-list method-value))
    (if lambda-list-value
      (values (list-copy (.ref lambda-list-value 'keys))
              (.ref lambda-list-value 'allow-other-keys?))
      (values '() #f))))

;; : (-> GenericSource List [ClosSpecializer] Boolean (Maybe ClosMethod))
(def (clos-find-method generic-source qualifiers specializers
                           error?: (error-value #t))
  (def generic (require-clos-generic generic-source))
  (unless (and (list? qualifiers) (andmap symbol? qualifiers))
    (clos-fail 'invalid-method-qualifier generic: (.ref generic 'identity)
               qualifier: qualifiers))
  (unless (and (list? specializers) (= (length specializers) (.ref generic 'required)))
    (clos-fail 'method-required-argument-mismatch generic: (.ref generic 'identity)))
  (unless (andmap (cut element? ClosSpecializer <>) specializers)
    (clos-fail 'invalid-specializer generic: (.ref generic 'identity)))
  (def method
    (find (lambda (candidate)
            (and (equal? (method-qualifier-list (.ref candidate 'qualifier)) qualifiers)
                 (same-specializers? (.ref candidate 'specializers) specializers)))
          (.ref generic 'methods)))
  (when (and (not method) error-value)
    (clos-fail 'method-not-found generic: (.ref generic 'identity) qualifier: qualifiers))
  method)

;; : (-> GenericSource Symbol)
(def (clos-generic-name generic-source)
  (.ref (require-clos-generic generic-source) 'identity))

;; : (-> GenericSource [ClosMethod])
(def (clos-generic-methods generic-source)
  (list-copy (.ref (require-clos-generic generic-source) 'methods)))

;; : (-> GenericSource ClosLambdaList)
(def (clos-generic-lambda-list generic-source)
  (.ref (require-clos-generic generic-source) 'lambda-list))

;; : (-> GenericSource [Natural])
(def (clos-generic-argument-precedence-order generic-source)
  (list-copy
   (.ref (require-clos-generic generic-source) 'argument-precedence-order)))

;; : (-> GenericSource ClosMethodCombination)
(def (clos-generic-method-combination generic-source)
  (.ref (require-clos-generic generic-source) 'method-combination))

;; : (-> GenericSource Natural)
(def (clos-generic-generation generic-source)
  (.ref (require-clos-generic generic-source) 'generation))

(def (clos-generic-documentation generic-source)
  (.ref (require-clos-generic generic-source) 'documentation))

(def (clos-generic-function-class generic-source)
  (.ref (require-clos-generic generic-source) 'generic-function-class))

(def (clos-generic-method-class generic-source)
  (.ref (require-clos-generic generic-source) 'method-class))
