;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/test :std/error :clan/poo/object-state)
(export scoped-invalidation-test)

(def scoped-invalidation-test
  (test-suite "Scoped edges in the POO reverse index"
    (test-case "only a direct assignment can omit a filtered edge"
      (def parent (make-object-state))
      (def plan (make-object-state))
      (def observer (make-object-state))
      (def upstream (make-object-state))
      (def (revision state) (object-state-revision state))
      (depend-on-state! parent 'plan plan 'roster)
      (depend-on-state! parent 'observer observer)
      (invalidate-state! 'parent parent void void 'roster)
      (check-equal? (map revision (list parent observer plan)) '(1 1 0))
      (depend-on-state! upstream 'parent parent)
      ((prepare-invalidation (list (cons 'parent parent) (cons 'upstream upstream))
         void void (lambda (owner) (and (eq? owner 'parent) 'roster))))
      (check-equal? (map revision (list parent observer plan)) '(2 2 1))
      (depend-on-state! parent 'plan plan)
      (depend-on-state! parent 'plan plan 'roster)
      (invalidate-state! 'parent parent void void 'roster)
      (check-equal? (map revision (list parent observer plan)) '(3 3 2)))
    (test-case "a cycle checks each owner once and clears the child first"
      (def root (make-object-state))
      (def child (make-object-state))
      (depend-on-state! root 'child child)
      (depend-on-state! child 'root root)
      (def events '())
      (def (record event owner) (set! events (cons (list event owner) events)))
      ((prepare-invalidation (list (cons 'root root))
         (lambda (owner _) (record 'check owner))
         (lambda (owner) (record 'clear owner))))
      (check-equal? (reverse events)
                    '((check root) (check child) (clear child) (clear root)))
      (check-equal? (map object-state-revision (list root child)) '(1 1)))
    (test-case "late registration on a finished row refuses before clearing"
      (def first (make-object-state))
      (def second (make-object-state))
      (def late (make-object-state))
      (def cleared '())
      (check-exception
        ((prepare-invalidation (list (cons 'first first) (cons 'second second))
           (lambda (owner _)
             (when (eq? owner 'second) (depend-on-state! first 'late late)))
           (lambda (owner) (set! cleared (cons owner cleared)))))
        (lambda (cause)
          (and (Error? cause)
               (equal? (Error-message cause) "dependency graph changed during invalidation"))))
      (check-equal? cleared '())
      (check-equal? (map object-state-revision (list first second late)) '(0 0 0)))))
