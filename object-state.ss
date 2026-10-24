;;; Mutation ownership and transitive invalidation, independent of slot evaluation.
(export make-object-state object-state-revision object-state-sealed?
        object-state-sealed?-set! depend-on-state! invalidate-state!)
(import :std/iter (only-in :gerbil/runtime/hash HashTable))
;; Weak child keys prevent a retained prototype from keeping abandoned instances alive.
(defstruct object-state (revision sealed? dependents) constructor: :init!)
;; Allocate dependency storage lazily; leaf objects need no weak table.
(defmethod {:init! object-state}
  (lambda (self)
    (set! (object-state-revision self) 0)
    (set! (object-state-sealed? self) #f)
    (set! (object-state-dependents self) #f)))
;; Register an immediate source edge; values contain state, never the weak key itself.
(def (depend-on-state! parent child child-state)
  (unless (object-state-dependents parent)
    (set! (object-state-dependents parent) (HashTable (make-table test: eq? weak-keys: #t))))
  (hash-put! (object-state-dependents parent) child child-state))
;; Check the ENTIRE affected closure before clearing anything. Diamonds visit once;
;; source edits clear all cached values, method closures, order and reflection views.
;; The caller serializes mutation/evaluation; this is not a concurrent transaction.
(def (invalidate-state! root state check clear)
  (def seen (make-hash-table-eq))
  (def affected [])
  (let visit ((owner root) (state state))
    (unless (hash-key? seen owner)
      (hash-put! seen owner #t)
      (check owner state)
      (set! affected (cons (cons owner state) affected))
      (when (object-state-dependents state)
        (for (([child . child-state] (object-state-dependents state)))
          (visit child child-state)))))
  (for-each (lambda (entry)
    (set! (object-state-revision (cdr entry)) (+ 1 (object-state-revision (cdr entry))))
    (clear (car entry))) affected))
