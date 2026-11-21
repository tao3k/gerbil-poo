;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: validate ordinary POO values against CLOS class slot metadata.
;;; These are pure model values, not mutable CLOS lifecycle instances.
(import :clan/poo/object
        (only-in :clan/poo/mop/prototype prototype-instance?)
        (only-in :clan/poo/clos/classes clos-class-effective-slots))
(export clos-model-prototype clos-model-validation-failure
        clos-model? clos-check-model)

(def (clos-model-prototype class-value)
  (.ref class-value 'instance-prototype))

(def (clos-model-diagnostic-value value)
  (cond
   ((or (symbol? value) (keyword? value) (string? value)
        (number? value) (boolean? value) (char? value)) value)
   ((object? value) 'poo-object)
   ((pair? value) 'pair)
   ((vector? value) 'vector)
   ((procedure? value) 'procedure)
   (else 'opaque-value)))

;;; Return the first bounded diagnostic without forcing unrelated lazy slots.
(def (clos-model-validation-failure class-value candidate)
  (cond
   ((not (object? candidate)) '(candidate-not-poo-object))
   ((not (prototype-instance? (clos-model-prototype class-value) candidate))
    '(prototype-ancestry-mismatch))
   (else
    (let loop ((slots (clos-class-effective-slots class-value)))
      (if (null? slots)
        #f
        (let* ((slot (car slots))
               (name (.ref slot 'identity)))
          (cond
           ((not (eq? (.ref slot 'allocation) 'instance))
            (list 'non-instance-slot name))
           ((not (.slot? candidate name))
            (list 'missing-slot name))
           ((not (.call (.ref slot '.type) .slot.check slot name candidate))
            (list 'slot-type-failed name
                  (clos-model-diagnostic-value (.ref candidate name))))
           (else (loop (cdr slots))))))))))

(def (clos-model? class-value candidate)
  (not (clos-model-validation-failure class-value candidate)))

(def (clos-check-model class-value candidate)
  (let (failure (clos-model-validation-failure class-value candidate))
    (when failure
      (error "invalid POO model" (.ref class-value 'identity) failure))
    candidate))
