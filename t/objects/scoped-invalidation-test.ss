;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/test :clan/poo/object-state)
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
      (check-equal? (map revision (list parent observer plan)) '(3 3 2)))))
