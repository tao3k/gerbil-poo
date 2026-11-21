;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/test
        (only-in :clan/poo/clos/funcs
                 clos-function-name? clos-initarg-name?
                 clos-initarg-list? clos-initarg-ref
                 clos-initarg-index clos-initarg-index-first-of
                 clos-identity-index clos-leftmost-index-by
                 clos-first-invalid-initarg
                 clos-position-lookup
                 clos-natural-permutation?))

(export clos-funcs-test)

(def clos-funcs-test
  (test-suite "POO CLOS linear algorithm functions"
    (test-case "plist traversal preserves presence and leftmost values"
      (check (clos-initarg-list? '(alpha 1 beta #f alpha 2)) => #t)
      (check (clos-initarg-list? '(alpha 1 beta)) => #f)
      (check (clos-initarg-list? (list alpha: 1 'beta #f)) => #t)
      (check (clos-initarg-list? '((setf alpha) 1)) => #f)
      (check (call-with-values
              (lambda () (clos-initarg-ref '(alpha #f alpha 2) 'alpha))
              cons)
             => '(#t . #f)))
    (test-case "function names and initarg names have separate grammars"
      (check (clos-function-name? 'name) => #t)
      (check (clos-function-name? (list 'setf 'name)) => #t)
      (for-each (lambda (name) (check (clos-function-name? name) => #f))
        (list name: '(setf) '(setf name extra) '(setf . name) (list 'setf name:)))
      (check (clos-initarg-name? 'name) => #t)
      (check (clos-initarg-name? name:) => #t)
      (check (clos-initarg-name? '(setf name)) => #f))
    (test-case "ordered indexes select call order across aliases"
      (let (index (clos-initarg-index '(second 2 first 1 second 9)))
        (check (call-with-values
                (lambda ()
                  (clos-initarg-index-first-of index '(first second)))
                cons)
               => '(#t . 2))))
    (test-case "identity indexes support one-pass invalid-key admission"
      (let (valid (clos-identity-index '(alpha beta)))
        (check (clos-first-invalid-initarg
                '(alpha 1 allow-other-keys #t gamma 3)
                valid (lambda (name) (eq? name 'allow-other-keys)))
               => 'gamma)))
    (test-case "object indexes retain the first declaration"
      (let* ((first '(payload first))
             (second '(payload second))
             (index
              (clos-leftmost-index-by car (list first second))))
        (check (hash-get index 'payload) => first)))
    (test-case "positions and natural permutations use bounded runtime indexes"
      (let* ((a (cons 'a '())) (b (cons 'b '()))
             (positions (clos-position-lookup (list a b))))
        (check (positions a) => 0)
        (check (positions b) => 1)
        (check (positions (cons 'a '())) => #f)
        (check (clos-natural-permutation? 'invalid 3) => #f)
        (check (clos-natural-permutation? '(0 . 1) 2) => #f)
        (check (clos-natural-permutation? '(2 0 1) 3) => #t)
        (check (clos-natural-permutation? '(2 0 2) 3) => #f)
        (check (clos-natural-permutation? '(3 0 1) 3) => #f)))))
