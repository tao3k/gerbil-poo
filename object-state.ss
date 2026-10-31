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
;; One admitted owner advances once before its existing cache-clear callback.
;; Clear failures keep their original effects; this is not effect rollback.
(def (clear-state! owner state clear)
  (set! (object-state-revision state) (+ 1 (object-state-revision state)))
  (clear owner)
  (void))
;; Root preflight precedes strategy selection: it may register a dependency.
;; A still-pristine leaf needs no traversal table or pending-owner spine. Any
;; retained weak table, including an empty one, keeps the complete graph path.
;; Graph checks finish before the first clear; diamonds still commit once each.
(def (invalidate-state! root state check clear)
  (check root state)
  (if (not (object-state-dependents state)) (clear-state! root state clear)
    (let ((seen (make-hash-table-eq)) (affected (list (cons root state))))
      (hash-put! seen root #t)
      ;; Root is already checked and marked. Follow the CURRENT dependencies,
      ;; preserving descendant-first commit order and the original false errors.
      (def (visit owner state)
        (unless (hash-key? seen owner)
          (hash-put! seen owner #t)
          (check owner state)
          (set! affected (cons (cons owner state) affected))
          (when (object-state-dependents state)
            (for (([child . child-state] (object-state-dependents state)))
              (visit child child-state)))))
      (for (([child . child-state] (object-state-dependents state)))
        (visit child child-state))
      (for-each (lambda (entry) (clear-state! (car entry) (cdr entry) clear)) affected))))
