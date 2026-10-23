;;; Change discovery reuses the Trie pair and prefix-aware single-tree recursors.

;; Emit exactly the generic table order: all old changes, then all new inserts.
;; Both input admissions remain owned by .diff. Identity pruning assumes persistent
;; nodes, and never stands in for child contract recognition or Function wrapping.
(def (trie-for-each-change source emit before after)
  ;; One-sided subtrees keep the pair recursor's absolute key prefix.
  (def (only old?)
    ;; Use the Trie recursor's declared prefix API, not a fourth argument to the
    ;; generic table fold, whose lawful overrides accept only three arguments.
    (def (visit prefix tree)
      (.call source .recurse/trie prefix tree recurse: visit
        branch: void skip: void empty: void
        leaf: (lambda (key row) (emit key (if old? (some row) #f) (if old? #f (some row))))))
    visit)
  ;; Two ordered passes avoid interleaving early insertions with later deletions.
  ;; The same existing recursor handles branch/skip alignment and height changes.
  (def (walk inserts?)
    (.call source .recurse/trie-pair 0 before after
      recurse: (lambda (recurse key left right)
        (unless (eq? left right) (recurse key left right)))
      empty: void branch: void skip: void
      leaf: (if inserts? void (lambda (key old next)
        (unless (equal? old next) (emit key (some old) (some next)))))
      onlya: (if inserts? void (only #t))
      onlyb: (if inserts? (only #f) void)))
  (unless (eq? before after) (walk #f) (walk #t)))
