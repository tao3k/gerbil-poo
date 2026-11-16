;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Reusable name checks, list traversal and indexing for CLOS.

(import (only-in :std/list/plist plist?)
        (only-in :gerbil/runtime/hash list->hash-table-eq))

(export clos-qualifier? clos-normalize-qualifier clos-short-qualifier
        clos-setf-name? clos-function-name? clos-function-name-list?
        clos-copy-function-name clos-copy-function-names
        clos-initarg-name? clos-initarg-name-list? clos-default-initargs?
        clos-initarg-list? clos-initarg-names
        clos-initarg-ref clos-initarg-index
        clos-initarg-index-first-of clos-identity-index
        clos-leftmost-index-by clos-first-invalid-initarg
        clos-allow-other-keys-name? clos-allow-other-keys?
        clos-position-lookup
        clos-natural-permutation?)

;; Qualifier lists must be finite before traversing their elements.
(def (clos-qualifier? value)
  (or (symbol? value) (and (list? value) (andmap symbol? value))))

;; Preserve the actual Slot value; normalize only the comparison key.
;; (primary) is an explicit long-form qualifier, distinct from no qualifier.
(def (clos-normalize-qualifier value)
  (cond
   ((symbol? value) value)
   ((null? value) 'primary)
   ((and (pair? value) (null? (cdr value))
         (symbol? (car value)) (not (eq? (car value) 'primary))) (car value))
   (else value)))

;; A short-combination name denotes one qualifier, even when named primary.
(def (clos-short-qualifier name)
  (if (eq? name 'primary) '(primary) name))

(def (clos-setf-name? name)
  (and (pair? name) (eq? (car name) 'setf)
       (pair? (cdr name)) (symbol? (cadr name)) (null? (cddr name))))

(def (clos-function-name? name)
  (or (symbol? name) (clos-setf-name? name)))

;; Names contain only symbols and, for setf, one finite two-cell list.
(def (clos-copy-function-name name)
  (if (clos-setf-name? name) (list-copy name) name))

(def (clos-copy-function-names names)
  (map clos-copy-function-name names))

(def (clos-function-name-list? names)
  (and (list? names) (andmap clos-function-name? names)))

(def (clos-initarg-name? name)
  (or (symbol? name) (keyword? name)))

(def (clos-initarg-name-list? names)
  (and (list? names) (andmap clos-initarg-name? names)))

(def (clos-default-initargs? entries)
  (and (list? entries)
       (andmap (lambda (entry)
                 (and (pair? entry) (clos-initarg-name? (car entry))
                      (procedure? (cdr entry))))
               entries)))

(def (clos-initarg-list? values)
  (and (plist? values)
       (let loop ((rest values))
         (or (null? rest)
             (and (clos-initarg-name? (car rest))
                  (loop (cddr rest)))))))

(def (clos-initarg-names values)
  (let loop ((rest values) (result-rev '()))
    (if (null? rest)
      (reverse result-rev)
      (loop (cddr rest) (cons (car rest) result-rev)))))

;; A presence flag keeps an explicit #f value distinct from absence.
(def (clos-initarg-ref arguments name)
  (let loop ((rest arguments))
    (cond ((null? rest) (values #f #f))
          ((eq? (car rest) name) (values #t (cadr rest)))
          (else (loop (cddr rest))))))

;; Retain each key's leftmost position and value, matching CLOS semantics.
(def (clos-initarg-index arguments)
  ;; The runtime constructor writes duplicate keys from left to right.  Build
  ;; entries in reverse call order so the original leftmost occurrence wins.
  (let loop ((rest arguments) (position 0) (entries '()))
    (if (null? rest)
      (list->hash-table-eq entries)
      (loop (cddr rest) (+ position 1)
            (cons (cons (car rest) (cons position (cadr rest))) entries)))))

;; A slot can name several initargs; call order decides which value wins.
(def (clos-initarg-index-first-of index names)
  (let (selected #f)
    (for-each
     (lambda (name)
       (let (entry (hash-get index name))
         (when (and entry
                    (or (not selected) (< (car entry) (car selected))))
           (set! selected entry))))
     names)
    (if selected (values #t (cdr selected)) (values #f #f))))

(def (clos-identity-index values)
  (list->hash-table-eq
   (map (lambda (value) (cons value #t)) values)))

;; Index domain objects once while preserving the first declaration selected
;; by the former linear `find` traversal.
(def (clos-leftmost-index-by key-of values)
  ;; Reversing makes the runtime constructor's final write for a duplicate key
  ;; the declaration that appeared first in the source list.
  (list->hash-table-eq
   (reverse (map (lambda (value) (cons (key-of value) value)) values))))

;; Admitted class and method orders have distinct identities.
(def (clos-position-lookup values)
  (def positions (make-table test: eq?))
  (let loop ((remaining values) (position 0))
    (unless (null? remaining)
      (table-set! positions (car remaining) position)
      (loop (cdr remaining) (1+ position))))
  (lambda (value) (table-ref positions value #f)))

;; One bounded vector pass proves that values are exactly 0..size-1.
(def (clos-natural-permutation? values size)
  (and (= (length values) size)
       (let (seen (make-vector size #f))
         (let loop ((rest values))
           (cond
            ((null? rest) #t)
            ((or (not (exact-integer? (car rest)))
                 (< (car rest) 0) (>= (car rest) size)
                 (vector-ref seen (car rest))) #f)
            (else
             (vector-set! seen (car rest) #t)
             (loop (cdr rest))))))))

;; Preserve the first invalid supplied key for stable diagnostics.
(def (clos-first-invalid-initarg arguments valid-index exempt?)
  (let loop ((rest arguments))
    (cond ((null? rest) #f)
          ((or (exempt? (car rest)) (hash-key? valid-index (car rest)))
           (loop (cddr rest)))
          (else (car rest)))))

(def (clos-allow-other-keys-name? name)
  (or (eq? name 'allow-other-keys)
      (and (keyword? name)
           (string=? (keyword->string name) "allow-other-keys"))))

;; Callers have already checked the plist. Both spellings name the same
;; control, so an explicit #f at the first occurrence ends the search.
(def (clos-allow-other-keys? arguments)
  (let loop ((rest arguments))
    (cond ((null? rest) #f)
          ((clos-allow-other-keys-name? (car rest)) (cadr rest))
          (else (loop (cddr rest))))))
