;;; Mutation ownership and transitive invalidation, independent of slot evaluation.
(export make-object-state object-state-revision object-state-sealed?
        object-state-sealed?-set! depend-on-state! invalidate-state!
        prepare-invalidation)
(import (only-in :gerbil/runtime/hash HashTable))
;; Weak child keys prevent a retained prototype from keeping abandoned instances alive.
(defstruct object-state (revision sealed? dependents) constructor: :init!)
;; Allocate dependency storage lazily; leaf objects need no weak table.
(defmethod {:init! object-state}
  (lambda (self)
    (set! (object-state-revision self) 0)
    (set! (object-state-sealed? self) #f)
    (set! (object-state-dependents self) #f)))
;; A filtered edge ignores only one direct assignment. Its payload never
;; holds the weak key. A second registration can widen the edge.
(defstruct slot-excluded-edge (state slot) final: #t)

(def (depend-on-state! parent child child-state (excluded-slot #f))
  (unless (object-state-dependents parent)
    (set! (object-state-dependents parent) (HashTable (make-table test: eq? weak-keys: #t))))
  (let* ((index (object-state-dependents parent))
         (prior (and excluded-slot (hash-get index child))))
    (hash-put! index child
      (if (and excluded-slot
               (or (not prior)
                   (and (slot-excluded-edge? prior)
                        (eq? excluded-slot (slot-excluded-edge-slot prior)))))
        (make-slot-excluded-edge child-state excluded-slot)
        child-state))))

;; A scoped visit is also an affected owner, but has not opened its whole row.
(defstruct scoped-visit (state slot) final: #t)

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
(def (invalidate-state! root state check clear (edited-slot #f))
  (check root state)
  (if (not (object-state-dependents state)) (clear-state! root state clear)
    ((prepare-invalidation (list (cons root state))
       (lambda (owner child-state) (unless (eq? owner root) (check owner child-state)))
       clear (and edited-slot (lambda (_) edited-slot))))))

;; Validate the current affected closure before advancing any revisions.
;; Only the first step of an explicitly scoped direct edit filters edges.
(def (prepare-invalidation roots check clear (root-slot #f))
  (let ((seen (make-hash-table-eq)) (affected '()))
    (def (admitted-state edge edited-slot)
      (if (slot-excluded-edge? edge)
        (and (not (eq? edited-slot (slot-excluded-edge-slot edge)))
             (slot-excluded-edge-state edge))
        edge))
    (def (walk state edited-slot)
      (let (index (object-state-dependents state))
        (when index
          ;; Weak tables already expose key and edge to the visitor.
          (hash-for-each
            (lambda (child edge)
              (let (child-state (admitted-state edge edited-slot))
                (when child-state (visit child child-state #f))))
            index))))
    (def (visit owner state edited-slot)
      (let (prior (hash-get seen owner))
        (cond
         ((not prior)
          (hash-put! seen owner (if edited-slot (make-scoped-visit state edited-slot) state))
          (check owner state)
          (set! affected (cons (cons owner state) affected))
          (walk state edited-slot))
         ((and (not edited-slot) (scoped-visit? prior))
          ;; Another root or a return edge reaches this owner without a
          ;; scope. Expand the whole row, but advance the owner only once.
          (unless (eq? state (scoped-visit-state prior))
            (error "dependency graph changed during invalidation"))
          (hash-put! seen owner state)
          (walk state #f)))))
    (for-each (lambda (root)
                (visit (car root) (cdr root) (and root-slot (root-slot (car root)))))
              roots)
    ;; Late preflight registration may open a previously unvisited edge.
    ;; Every admitted edge must have reached its child without a scope.
    (def checked-slot #f)
    (def (check-edge! child edge)
      (let (child-state (admitted-state edge checked-slot))
        (when (and child-state (not (eq? (hash-get seen child) child-state)))
          (error "dependency graph changed during invalidation"))))
    (for-each (lambda (entry)
                (let ((index (object-state-dependents (cdr entry)))
                      (visited (hash-get seen (car entry))))
                  (when index
                    (set! checked-slot (and (scoped-visit? visited) (scoped-visit-slot visited)))
                    (hash-for-each check-edge! index))))
              affected)
    (lambda ()
      (for-each (lambda (entry) (clear-state! (car entry) (cdr entry) clear)) affected))))
