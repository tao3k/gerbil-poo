;;; Persistent rational-key dictionary backed by Gerbil V19's red-black tree.

(export rationaldict? empty-rationaldict rationaldict-empty?
        rationaldict-ref rationaldict-put rationaldict-remove
        rationaldict-has-key? rationaldict-keys rationaldict-values
        list->rationaldict rationaldict->list rationaldict-fold rationaldict-foldr rationaldict=?
        rationaldict-min-key rationaldict-max-key rationaldict-iter)

(import :std/iter :std/struct/rbtree)

(defstruct rationaldict (tree) transparent: #t)
(def empty-rationaldict (rationaldict (RBTree -)))
(def absent (gensym 'absent))

(def (rationaldict-empty? dict) (rbtree-empty? (rationaldict-tree dict)))
(def (rationaldict-ref dict key
                       (default (cut error "rationaldict-ref: missing key" dict key)))
  (def value (rbtree-ref (rationaldict-tree dict) key absent))
  (if (eq? value absent) (default) value))
(def (rationaldict-put dict key value)
  (rationaldict (rbtree-put (rationaldict-tree dict) key value)))
(def (rationaldict-remove dict key)
  (rationaldict (rbtree-remove (rationaldict-tree dict) key)))
(def (rationaldict-has-key? dict key)
  (not (eq? absent (rbtree-ref (rationaldict-tree dict) key absent))))
(def (rationaldict-keys dict)
  (for/collect ((key (in-rbtree-keys (rationaldict-tree dict)))) key))
(def (rationaldict-values dict)
  (for/collect ((value (in-rbtree-values (rationaldict-tree dict)))) value))
(def (list->rationaldict entries)
  ;; V19 owns the transient construction path; only the completed tree escapes.
  (rationaldict (list->rbtree - entries)))
(def (rationaldict->list dict) (rbtree->list (rationaldict-tree dict)))
(def (rationaldict-iter dict (from #f))
  (def entries (iter (rationaldict-tree dict)))
  (if from
    (in-coroutine
     (lambda (yield)
       (for (entry entries)
         (when (>= (car entry) from) (yield entry)))))
    entries))
(def (rationaldict-fold proc seed dict)
  (rbtree-fold proc seed (rationaldict-tree dict)))
(def (rationaldict-foldr proc seed dict)
  (rbtree-foldr proc seed (rationaldict-tree dict)))
(def (rationaldict=? left right (value=? equal?))
  (using ((left-entries (iter (rationaldict-tree left)) :- Iterator)
          (right-entries (iter (rationaldict-tree right)) :- Iterator))
    (let compare-next ()
      (def left-entry (left-entries.next!))
      (def right-entry (right-entries.next!))
      (cond
       ((eq? left-entry #!eof) (eq? right-entry #!eof))
       ((eq? right-entry #!eof) #f)
       ((and (= (car left-entry) (car right-entry))
             (value=? (cdr left-entry) (cdr right-entry)))
        (compare-next))
       (else #f)))))
(def (rationaldict-min-key dict (default #f))
  (let/cc return
    (rbtree-for-each (lambda (key _value) (return key)) (rationaldict-tree dict))
    default))
(def (rationaldict-max-key dict (default #f))
  (let/cc return
    (rbtree-for-eachr (lambda (key _value) (return key)) (rationaldict-tree dict))
    default))
