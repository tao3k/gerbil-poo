;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/type define-type Type.) (only-in :clan/poo/object .o .ref)
        :clan/poo/mop
        (only-in :clan/poo/number Integer)
        :std/test :std/error)
(export clos-model-test)

(def Base
  (clos-class 'model-test/base
    direct-slots: (list (clos-direct-slot-definition
                         'value type: Integer))))
(define-type (PositiveValue @ Type.)
  .element?: (lambda (v) (and (number? v) (> v 0))))
(def Positive
  (clos-class 'model-test/positive direct-superclasses: (list Base)
    direct-slots: (list (clos-direct-slot-definition
                         'value
                         type: PositiveValue))))
(def good (.o (:: @ (clos-model-prototype Positive)) value: 2))
(def Shared
  (clos-class 'model-test/shared
    direct-slots: (list (clos-direct-slot-definition
                         'value allocation: 'class))))

(def clos-model-test
  (test-suite "CLOS-governed pure model values"
    (test-case "inherited effective slot predicates apply"
      (check-equal? (clos-model? Positive good) #t)
      (check-equal? (clos-model? Base good) #t)
      (check-equal? (clos-model? Positive (.o (:: @ good) value: -1)) #f)
      (check-equal? (clos-model? Positive (.o (:: @ good) value: 1.5)) #f))
    (test-case "copied class markers cannot impersonate ancestry"
      (check-equal?
       (clos-model-validation-failure
        Positive (.o (:: @ good) value: 'bad))
       '(slot-type-failed value bad))
      (check-equal?
       (clos-model-validation-failure
        Positive (.o (:: @ (clos-model-prototype Positive))))
       '(missing-slot value))
      (check-equal?
       (clos-model? Positive (.o value: 2 %clos-class: Positive)) #f)
      (check-equal?
       (clos-model?
        Positive (.o (:: @ (clos-model-prototype Positive)))) #f)
      (check-equal? (clos-model? Positive #f) #f)
      (check-exception
       (clos-check-model Positive (.o (:: @ good) value: 'bad))
       Error?))
    (test-case "checking preserves the input value"
      (check-eq? (clos-check-model Positive good) good)
      (check-equal? (.ref good 'value) 2))
    (test-case "class storage is not a pure model slot"
      (check-equal?
       (clos-model? Shared
                        (.o (:: @ (clos-model-prototype Shared)) value: 2))
       #f))))
