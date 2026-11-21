;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Generic-function creation and binding-owned configuration evolution.

(import :clan/poo/object
        (only-in :clan/poo/mop/prototype element?)
        (only-in :std/list/list map-in-order)
        (only-in "funcs.ss" clos-function-name?)
        "types.ss" "objects.ss")

(export clos-ensure-generic-function
        clos-reinitialize-generic-function!)

(extern namespace: clan/poo/object %with-slot-edit-protection %publish-slot-edits!)
(extern namespace: clan/poo/slot-observation %make-owned-list %borrow-owned-list)
(extern namespace: clan/poo/clos/objects %dispatch-generation-field)

(def +clos-unspecified-generic-option+
  (cons 'clos 'unspecified-generic-option))

;; : (forall (a) (-> a a a))
(def (option-or-current option current)
  (if (eq? option +clos-unspecified-generic-option+) current option))

;; : (-> ClosGenericFunction GenericFunctionOptions ClosGenericFunction)
(def (generic-configuration-template
      current-value required-value rest-value optional-value key-value key-values
      allow-other-keys-value precedence-value combination-value protocol-value)
  (let (lambda-list-value (.ref current-value 'lambda-list))
    (clos-generic-function
     (.ref current-value 'identity)
     (option-or-current required-value (.ref current-value 'required))
     rest?: (option-or-current rest-value (.ref current-value 'rest?))
     optional:
     (option-or-current optional-value (.ref lambda-list-value 'optional))
     key?: (option-or-current key-value (.ref lambda-list-value 'key?))
     keys: (option-or-current key-values (.ref lambda-list-value 'keys))
     allow-other-keys?:
     (option-or-current allow-other-keys-value
                        (.ref lambda-list-value 'allow-other-keys?))
     argument-precedence-order:
     (option-or-current precedence-value
                        (.ref current-value 'argument-precedence-order))
     method-combination:
     (option-or-current combination-value
                        (.ref current-value 'method-combination))
     protocol: (option-or-current protocol-value
                                  (.ref current-value 'protocol)))))

(def (prepare-generic-edits current-value template-value)
  (def methods (.ref current-value 'methods))
  (%with-slot-edit-protection methods
    (lambda ()
      (for-each (lambda (method-value)
                  ;; Admit a detached method while the original stays with its generic.
                  (clos-add-method
                   template-value
                   (clos-method
                    (.ref method-value 'identity)
                    (.ref method-value 'specializers)
                    (.ref method-value 'body)
                    qualifier: (.ref method-value 'qualifier)
                    lambda-list: (.ref method-value 'lambda-list))))
                methods)
      (%with-slot-edit-protection (list template-value)
        (lambda ()
          (def fields
            (map-in-order (lambda (field)
                            (def value (.ref template-value field))
                            (cons field (if (eq? field 'argument-precedence-order)
                                          (%make-owned-list value) value)))
              '(required rest? argument-precedence-order method-combination lambda-list protocol)))
          (cons* current-value
               (%dispatch-generation-field current-value methods
                 (%borrow-owned-list (cdr (assq 'argument-precedence-order fields))))
               (cons 'generation (1+ (.ref current-value 'generation))) fields))))))

;; clos-reinitialize-generic-function!
;;   : (-> ClosGenericBinding required: (Maybe Natural)
;;         rest?: (Maybe Boolean) optional: (Maybe Natural)
;;         key?: (Maybe Boolean) keys: (Maybe [InitargName])
;;         allow-other-keys?: (Maybe Boolean)
;;         argument-precedence-order: (Maybe [Natural])
;;         method-combination: (Maybe ClosMethodCombination)
;;         protocol: (Maybe ClosGenericProtocol) ClosGenericFunction)
;;   | contract: validates a complete configuration and every existing method
;;     before mutating the stable ANSI generic-function object.
;;   | doc m%
;;       `clos-reinitialize-generic-function!` attributes mutation to one
;;       explicit generic binding.
;;
;;       # Examples
;;       ```scheme
;;       (clos-reinitialize-generic-function! binding rest?: #t)
;;       ;; => successor-generic
;;       ```
;;
;;       result: the same generic-function identity at its next generation.
;;     %
(def (clos-reinitialize-generic-function!
      binding-value
      required: (required-value +clos-unspecified-generic-option+)
      rest?: (rest-value +clos-unspecified-generic-option+)
      optional: (optional-value +clos-unspecified-generic-option+)
      key?: (key-value +clos-unspecified-generic-option+)
      keys: (key-values +clos-unspecified-generic-option+)
      allow-other-keys?:
      (allow-other-keys-value +clos-unspecified-generic-option+)
      argument-precedence-order:
      (precedence-value +clos-unspecified-generic-option+)
      method-combination:
      (combination-value +clos-unspecified-generic-option+)
      protocol: (protocol-value +clos-unspecified-generic-option+))
  (defvalues (current-value edits)
    (%with-slot-edit-protection (list binding-value)
      (lambda ()
        (unless (element? ClosGenericBinding binding-value)
          (clos-fail 'invalid-generic-binding))
        (def current-value (clos-generic-binding-current binding-value))
        (values current-value
          (%with-slot-edit-protection (list current-value)
            (lambda ()
              (def template-value
                (generic-configuration-template
                 current-value required-value rest-value optional-value key-value
                 key-values allow-other-keys-value precedence-value combination-value
                 protocol-value))
              (list (prepare-generic-edits current-value template-value)
                    (list binding-value (cons 'current current-value)))))))))
  (%publish-slot-edits! edits)
  current-value)

;; : (-> Symbol GenericFunctionOptions ClosGenericFunction)
(def (initial-generic identity-value required-value rest-value optional-value
                      key-value key-values allow-other-keys-value
                      precedence-value combination-value protocol-value)
  (clos-generic-function
   identity-value
   (option-or-current required-value 0)
   rest?: (option-or-current rest-value #f)
   optional: (option-or-current optional-value 0)
   key?: (option-or-current key-value #f)
   keys: (option-or-current key-values '())
   allow-other-keys?: (option-or-current allow-other-keys-value #f)
   argument-precedence-order:
   (if (eq? precedence-value +clos-unspecified-generic-option+)
     #f precedence-value)
   method-combination: (option-or-current combination-value 'standard)
   protocol: (if (eq? protocol-value +clos-unspecified-generic-option+)
               #f protocol-value)))

;; clos-ensure-generic-function
;;   : (-> Symbol existing: (Maybe GenericSource)
;;         required: (Maybe Natural) GenericFunctionOptions ClosGenericBinding)
;;   | contract: creates a binding when absent or reconfigures an existing
;;     binding only through its checked immutable successor transition.
;;   | doc m%
;;       `clos-ensure-generic-function` is the explicit Scheme adaptation of
;;       ANSI `ensure-generic-function`; it returns the POO mutation owner.
;;
;;       # Examples
;;       ```scheme
;;       (clos-ensure-generic-function 'route required: 2)
;;       ;; => route-binding
;;       ```
;;
;;       result: a POO generic binding accepted by ordinary dispatch.
;;     %
(def (clos-ensure-generic-function
      identity-value
      existing: (existing-value #f)
      required: (required-value +clos-unspecified-generic-option+)
      rest?: (rest-value +clos-unspecified-generic-option+)
      optional: (optional-value +clos-unspecified-generic-option+)
      key?: (key-value +clos-unspecified-generic-option+)
      keys: (key-values +clos-unspecified-generic-option+)
      allow-other-keys?:
      (allow-other-keys-value +clos-unspecified-generic-option+)
      argument-precedence-order:
      (precedence-value +clos-unspecified-generic-option+)
      method-combination:
      (combination-value +clos-unspecified-generic-option+)
      protocol: (protocol-value +clos-unspecified-generic-option+))
  (unless (clos-function-name? identity-value)
    (clos-fail 'invalid-generic-name generic: identity-value))
  (if existing-value
    (let (binding-value
          (if (element? ClosGenericBinding existing-value)
            existing-value
            (clos-generic-binding identity-value existing-value)))
      (unless (equal? identity-value (.ref binding-value 'identity))
        (clos-fail 'generic-binding-identity-mismatch
                   generic: identity-value))
      (clos-reinitialize-generic-function!
       binding-value required: required-value rest?: rest-value
       optional: optional-value key?: key-value keys: key-values
       allow-other-keys?: allow-other-keys-value
       argument-precedence-order: precedence-value
       method-combination: combination-value protocol: protocol-value)
      binding-value)
    (clos-generic-binding
     identity-value
     (initial-generic
      identity-value required-value rest-value optional-value key-value
      key-values allow-other-keys-value precedence-value combination-value
      protocol-value))))
