;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; POO ensure/reinitialize generic-function conformance.

(import (only-in :std/test
                 test-suite test-case check-equal? check-exception check)
        (only-in :std/error Error? Error-message)
        (only-in :clan/poo/object .o .ref depend-on-object! object-revision
                 object-read-current? seal-object!)
        (only-in :clan/poo/mop call-with-slot-read-observer slot-read-key slot-read-receiver)
        :clan/poo/clos)

(export poo-clos-generic-evolution-test)

(def (failure-code? code)
  (lambda (error)
    (and (poo-clos-failure? error)
         (eq? (.ref error 'code) code))))

(def (mutation-refused? cause)
  (and (Error? cause)
       (equal? (Error-message cause) "object mutation during read replay")))

;; Wait until validation has read the last template field. The next rest?
;; read belongs to preparation of the replacement slots.
(def (observe-replacement generic observe action)
  (def template #f)
  (call-with-slot-read-observer
    (lambda (read)
      (def receiver (slot-read-receiver read))
      (case (slot-read-key read)
        ((declarations)
         (unless (eq? receiver generic) (set! template receiver)))
        ((rest?)
         (when (eq? receiver template)
           (set! template #f)
           (observe receiver)))))
    action))

(def poo-clos-generic-evolution-test
  (test-suite "POO CLOS generic evolution"
    (test-case "ensure creates an explicit dispatchable binding"
      (let (binding
            (poo-clos-ensure-generic-function
             'ensured required: 1 rest?: #t))
        (check-equal? (poo-clos-generic-name binding) 'ensured)
        (check-equal? (poo-clos-generic-generation binding) 0)
        (check-exception (poo-clos-call binding)
                         (failure-code? 'argument-count-mismatch))))

    (test-case "reinitialization preserves admitted methods atomically"
      (let* ((binding
              (poo-clos-ensure-generic-function 'configured required: 1))
             (method
              (poo-clos-method
               'configured/any (list (poo-clos-any-specializer))
               (lambda (_frame value) value))))
        (poo-clos-generic-binding-add-method! binding method)
        (let ((before (poo-clos-generic-binding-current binding))
              (next
               (poo-clos-reinitialize-generic-function!
                binding rest?: #t)))
          (check-equal? (poo-clos-call binding 'ok) 'ok)
          (check-equal? (poo-clos-generic-generation next) 2)
          (check-equal? (poo-clos-generic-methods next) (list method))
          (check (eq? before next) => #t)
          (check-exception
           (poo-clos-reinitialize-generic-function!
            binding required: 2 argument-precedence-order: '(0 1))
           (failure-code? 'method-required-argument-mismatch))
          (check (eq? (poo-clos-generic-binding-current binding) next) => #t))))

    (test-case "an observer exception leaves the complete generic generation intact"
      (def generic (poo-clos-generic-function 'observed-abort 1))
      (def binding (poo-clos-generic-binding 'observed-abort generic))
      (def generic-revision (object-revision generic))
      (def binding-revision (object-revision binding))
      (def stopped (list 'observer-stopped))
      (check-exception
       (observe-replacement generic (lambda (_template) (raise stopped))
         (lambda ()
           (poo-clos-reinitialize-generic-function! binding required: 2 rest?: #t
             argument-precedence-order: '(0 1))))
       (lambda (cause) (eq? cause stopped)))
      (check-equal? (.ref generic 'required) 1)
      (check-equal? (.ref generic 'rest?) #f)
      (check-equal? (.ref (.ref generic 'lambda-list) 'required) 1)
      (check-equal? (.ref generic 'generation) 0)
      (check-equal? (object-revision generic) generic-revision)
      (check-equal? (object-revision binding) binding-revision))

    (test-case "reentrant generic and binding edits are refused during preparation"
      (def generic (poo-clos-generic-function 'observed-reentry 1))
      (def binding (poo-clos-generic-binding 'observed-reentry generic))
      (def alias (poo-clos-generic-binding 'observed-reentry generic))
      (def observed? #f)
      (def result
        (observe-replacement generic
          (lambda (template)
            (set! observed? #t)
            (check-exception
             (poo-clos-reinitialize-generic-function! binding optional: 1)
             mutation-refused?)
            (check-exception
             (poo-clos-reinitialize-generic-function! alias optional: 1)
             mutation-refused?)
            (check-exception
             (poo-clos-reinitialize-generic-function!
              (poo-clos-generic-binding 'observed-reentry template) optional: 1)
             mutation-refused?)
            (check-equal? (.ref generic 'generation) 0))
          (lambda () (poo-clos-reinitialize-generic-function! binding rest?: #t))))
      (check-equal? observed? #t)
      (check (eq? result generic) => #t)
      (check-equal? (.ref generic 'generation) 1)
      (check-equal? (.ref generic 'rest?) #t)
      (check-equal? (.ref (.ref generic 'lambda-list) 'optional) 0))

    (test-case "batch invalidates the binding and its dependents once"
      (def generic (poo-clos-generic-function 'binding-invalidation 2))
      (def binding (poo-clos-generic-binding 'binding-invalidation generic))
      (def order (list 1 0))
      (def demands 0)
      (def dependent (.o current: (begin (set! demands (1+ demands)) (.ref binding 'current))))
      (depend-on-object! dependent binding)
      (check (eq? (.ref dependent 'current) generic) => #t)
      (def binding-read #f)
      (call-with-slot-read-observer
        (lambda (read)
          (when (and (eq? (slot-read-receiver read) binding)
                     (eq? (slot-read-key read) 'current))
            (set! binding-read read)))
        (lambda () (.ref binding 'current)))
      (check-equal? (object-read-current? binding-read) #t)
      (def owners (list generic binding dependent))
      (def revisions (map object-revision owners))
      (poo-clos-reinitialize-generic-function! binding rest?: #t
        argument-precedence-order: order)
      (check-equal? (map object-revision owners) (map 1+ revisions))
      (check-equal? (object-read-current? binding-read) #f)
      (check (eq? (.ref dependent 'current) generic) => #t)
      (check-equal? demands 2)
      (check-equal? (.ref generic 'generation) 1)
      (set-car! order 0)
      (def returned-order (poo-clos-generic-argument-precedence-order binding))
      (check-equal? returned-order '(1 0))
      (set-car! returned-order 0)
      (check-equal? (poo-clos-generic-argument-precedence-order binding) '(1 0))
      (seal-object! binding)
      (set! revisions (map object-revision owners))
      (check-exception
       (poo-clos-reinitialize-generic-function! binding rest?: #f)
       (lambda (cause) (and (Error? cause) (equal? (Error-message cause) "sealed prototype"))))
      (check-equal? (map object-revision owners) revisions)
      (check-equal? (.ref generic 'generation) 1)
      (check-equal? (.ref generic 'rest?) #t))

    (test-case "ensure reuses bindings and checks their identity"
      (let (binding
            (poo-clos-ensure-generic-function 'same required: 0))
        (check (eq? (poo-clos-ensure-generic-function
                     'same existing: binding optional: 1)
                    binding)
               => #t)
        (check-equal? (poo-clos-generic-generation binding) 1)
        (check-exception
         (poo-clos-ensure-generic-function 'other existing: binding)
         (failure-code? 'generic-binding-identity-mismatch))
        (check-exception
         (poo-clos-ensure-generic-function '(setf same extra) existing: binding required: -1)
         (failure-code? 'invalid-generic-name))
        (check-exception
         (poo-clos-find-generic-function '(setf . same) error?: #f)
         (failure-code? 'invalid-generic-function-name))
        (check-exception
         (poo-clos-generic-function '(setf same extra) -1)
         (failure-code? 'invalid-required-argument-count))
        (check-exception
         (poo-clos-generic-function '(setf same extra) 1)
         (failure-code? 'invalid-generic-function))
        (check-exception
         (poo-clos-method '(setf same extra) '() (lambda (_frame) #f))
         (failure-code? 'invalid-method))))))
