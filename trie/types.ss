(define-type (TrieSet. @ Set<-Table.)
  ;; Match RationalSet's binding: one element descriptor owns the backing key
  ;; contract. The UInt default breaks the inherited Elt/Table.Key alias cycle.
  Elt: UInt
  Table: {(:: @T Trie.) Key: Elt Value: Unit}
  .subset?: ;; is a a subset of b
  (lambda (a b)
    ;; Keep the existing shared-subtree shortcut inside complete set admission.
    (with-set-tables @ a b (lambda ()
    (let/cc return
      (when (eq? a b) (return #t))
      (.call Table .recurse/trie-pair
             0 a b
             recurse: (lambda (r k a b) (or (eq? a b) (r k a b)))
             empty: true
             leaf: true
             branch: true
             skip: true
             onlya: (lambda (_1 _2) (return #f))
             onlyb: true))))))

(def (SimpleTrie Key Value)
  {(:: @ [Trie. IdWrap]) (Key) (Value)
   sexp: `(SimpleTrie ,(.@ Key sexp) ,(.@ Value sexp))})

;; Specialize the same UInt-compatible element/key contract throughout the Set
;; family; the backing declaration and standard style factories retain identity.
(def (SimpleTrieSet Elt)
  {(:: @ [TrieSet.]) (Elt)
   sexp: `(SimpleTrieSet ,(.@ Elt sexp))
   Value: Unit})

(def UIntTrieSet
  {(:: @ [TrieSet.])
   Elt: UInt
   sexp: `(SimpleTrieSet ,(.@ UInt sexp))
   Value: Unit
   .foldl:
   (lambda (f seed input)
     (fold-set/shared-backing @ f seed input
       (lambda ()
         (and (eq? @ UIntTrieSet)
              (slot-read-observers-compatible? [])
              (andmap (lambda (source) (zero? (object-revision source)))
                      (list @ (.@ @ Table) Type Type. UInt Unit Identity))))))})

;; This captures protocol identities, never admitted tree identities. Each call
;; checks the live shape again. Active read capture and observer scopes keep
;; the original method observations and callbacks.
(set! stock-uint-trie-shape?
  (let* ((table (.ref UIntTrieSet 'Table))
         (height (.ref table 'Height))
         (wrapper (.ref table 'Wrapper))
         (sources (apply append
                    (map compute-precedence-list!
                         (list UIntTrieSet table height wrapper Type Type.))))
         (revisions (map object-revision sources)))
    (lambda (descriptor tree)
      (and (eq? descriptor table)
           (not (%slot-read-active?))
           (%object-revisions-current? sources revisions)
           (uint-trie-shape-height tree)))))
