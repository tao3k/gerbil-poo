;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Transaction-shaped class generation and dependent-class evolution.

(import :clan/poo/object
        (only-in :clan/poo/mop/prototype element?)
        (only-in :std/list/list filter-map)
        "types.ss" "objects.ss" "classes.ss")

(export clos-redefine-class clos-make-instances-obsolete)

(extern namespace: clan/poo/object %with-slot-edit-protection %publish-slot-edits!)
(extern namespace: clan/poo/slot-observation %make-owned-list)

(def +clos-unspecified+ (cons 'clos 'unspecified))

;; : (-> ClosClass [ClosClass])
(def (live-direct-subclasses class-value)
  (.ref class-value 'direct-subclasses))

;; : (-> ClosClass [ClosClass])
(def (dependent-closure root)
  ;; Class identity is the graph key. The index makes diamond admission O(1)
  ;; while the returned list remains the stable, functional traversal value.
  (let (visited (make-hash-table-eq))
    (letrec ((visit
              (lambda (class-value result-rev)
                (if (hash-key? visited class-value)
                  result-rev
                  (begin
                    (hash-put! visited class-value #t)
                    (foldl visit
                           (cons class-value result-rev)
                           (live-direct-subclasses class-value)))))))
      (reverse (visit root '())))))

;; : (-> ClosClass Natural)
(def (class-depth class-value)
  (length (clos-class-precedence-list class-value)))

;; : (-> [ClosClass] [ClosClass])
(def (sort-by-depth classes)
  (map cdr
       (list-sort
        (lambda (left right) (< (car left) (car right)))
        (map (lambda (class-value)
               (cons (class-depth class-value) class-value))
             classes))))

;; : (forall (a) (-> Boolean a a a))
(def (redefinition-option root? supplied fallback)
  (if (and root? (not (eq? supplied +clos-unspecified+)))
    supplied fallback))

;; Stage descendants against the new prototypes in superclass order.
(def (prepare-class-edits classes root parents slots defaults
                         slot-missing slot-unbound redefinition-handler different-handler)
  (let ((prototypes (make-hash-table-eq))
        (direct-slots (make-hash-table-eq)))
    (map
     (lambda (current)
       (def root? (eq? current root))
       (def supers (if root? parents (.ref current 'direct-superclasses)))
       (def selected-slots (redefinition-option root? slots (.ref current 'direct-slots)))
       (hash-put! direct-slots current selected-slots)
       (def projection
         (%clos-project-class-redefinition
          current supers
          (lambda (owner)
            (or (hash-get prototypes owner) (.ref owner 'instance-prototype)))
          (lambda (owner)
            (or (hash-get direct-slots owner) (.ref owner 'direct-slots)))))
       (hash-put! prototypes current (.ref projection 'prototype))
       (%clos-class-redefinition-edits
        current supers selected-slots
        (redefinition-option root? defaults (.ref current 'default-initargs))
        (redefinition-option root? slot-missing (.ref current 'slot-missing-handler))
        (redefinition-option root? slot-unbound (.ref current 'slot-unbound-handler))
        (redefinition-option root? redefinition-handler (.ref current 'redefinition-update-handler))
        (redefinition-option root? different-handler (.ref current 'different-class-update-handler))
        projection))
     classes)))

(def (subclass-link-edits child previous parents)
  (append
   (filter-map
    (lambda (owner)
      (and (not (memq owner parents))
           (list owner
                 (cons 'direct-subclasses
                       (%make-owned-list
                        (filter (lambda (class) (not (eq? class child)))
                                (live-direct-subclasses owner)))))))
    previous)
   (filter-map
    (lambda (owner)
      (and (not (memq owner previous))
           (list owner
                 (cons 'direct-subclasses
                       (%make-owned-list (cons child (live-direct-subclasses owner)))))))
    parents)))

;; | ClosClass = POOObject
;; clos-redefine-class
;;   : (-> ClosClass direct-superclasses: [ClosClass]
;;        direct-slots: [ClosDirectSlotDefinition] default-initargs: [Pair]
;;        slot-missing-handler: (Maybe Procedure)
;;        slot-unbound-handler: (Maybe Procedure)
;;        redefinition-update-handler: (Maybe Procedure)
;;        different-class-update-handler: (Maybe Procedure) ClosClass)
;;   | contract: mutates the existing class metaobject in place, preserving the
;;     ANSI class identity while recomputing each dependent class projection.
;;   | doc m%
;;       `clos-redefine-class` preserves old slot layouts as inert evidence.
;;
;;       # Examples
;;       ```scheme
;;       (clos-redefine-class class-value direct-slots: revised-slots)
;;       ;; => revised-class-generation
;;       ```
;;
;;       result: the same class metaobject with an incremented layout generation.
;;     %
(def (clos-redefine-class
      class-value
      direct-superclasses: (supers +clos-unspecified+)
      direct-slots: (slots +clos-unspecified+)
      default-initargs: (defaults +clos-unspecified+)
      slot-missing-handler: (slot-missing +clos-unspecified+)
      slot-unbound-handler: (slot-unbound +clos-unspecified+)
      redefinition-update-handler: (redefinition-handler
                                    +clos-unspecified+)
      different-class-update-handler: (different-handler
                                       +clos-unspecified+))
  (unless (element? ClosClass class-value) (clos-fail 'invalid-class))
  (def classes (sort-by-depth (dependent-closure class-value)))
  (def previous (.ref class-value 'direct-superclasses))
  (def parents (map clos-resolve-class (redefinition-option #t supers previous)))
  (when (ormap (lambda (parent) (memq parent classes)) parents)
    (clos-fail 'inconsistent-class-precedence
               class: (.ref class-value 'identity)
               operation: 'compute-class-precedence-list))
  (def edits
    (%with-slot-edit-protection (append classes previous parents)
      (lambda ()
        (append (prepare-class-edits classes class-value parents slots defaults
                                    slot-missing slot-unbound redefinition-handler different-handler)
                (subclass-link-edits class-value previous parents)))))
  (%publish-slot-edits! edits)
  ;; Initializers may run user code. All class layouts are visible by then.
  (for-each initialize-direct-class-slots! classes)
  class-value)

;; : (-> ClosClass ClosClass)
(def (clos-make-instances-obsolete class-value)
  (clos-redefine-class class-value))
