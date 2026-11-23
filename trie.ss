;;; Pure Big Endian Patricia Trees (Tries), mapping natural integers to values.
;;; See article "Fast Mergable Integer Maps" by Chris Okasaki & Andrew Gill, 1998
;;; http://www.eecs.usma.edu/webs/people/okasaki/ml98maps.ps

(export (except-out #t uint-trie-shape-height stock-uint-trie-shape?))

(import
  (only-in ./slot-observation slot-read-observers-compatible? %slot-read-active?)
  :std/format :std/iter :std/number/misc :std/values
  ./support/base ./support/option
  ./object ./mop/prototype ./brace ./number ./type ./fun ./io ./table)

#;(defrule (aver cond msg expr ...)
  (unless cond
    (DBG msg expr ...)
    (with-catch/cont
     (lambda (_ k)
       (eprintf "In thread ~a:\n" (thread-name (current-thread)))
       (display-continuation-backtrace k (current-error-port) #t #t 20 20))
     (cut error "foo"))
    (##repl-debug)))

(defstruct $Trie () transparent: #t)
(defstruct (Empty $Trie) () transparent: #t)
(defstruct (Leaf $Trie) (value) transparent: #t)
(defstruct (Branch $Trie) (height left right) transparent: #t) ;; height of the top bit, not integer-length
(defstruct (Skip $Trie) (height bits-height bits child) transparent: #t) ;; bits-height is similarly top bit of bits, the number of valid bits in bits is (1+ bits-height)

;; Return each validated subtree height to its parent. The canonical UInt
;; carrier needs one visit per node and no repeated method lookup. Failures
;; return to the public validator for the original typed cause and ordering.
(def (uint-trie-shape-height tree)
  (match tree
    ((Empty) 'empty)
    ((Leaf _) -1)
    ((Branch height left right)
     (and (exact-integer? height) (<= 0 height)
          (let (left-height (uint-trie-shape-height left))
            (and (exact-integer? left-height) (= left-height (- height 1))
                 (let (right-height (uint-trie-shape-height right))
                   (and (exact-integer? right-height)
                        (= right-height (- height 1)) height))))))
    ((Skip height bits-height bits child)
     (and (exact-integer? height) (exact-integer? bits-height)
          (<= 0 bits-height height) (exact-integer? bits) (<= 0 bits)
          (<= (integer-length bits) (+ bits-height 1))
          (let (child-height (uint-trie-shape-height child))
            (and (exact-integer? child-height)
                 (= child-height (- height bits-height 1)) height))))
    (_ #f)))

;; Initialization uses the ordinary protocol until the canonical receiver and
;; its method families have been constructed.
(def stock-uint-trie-shape? (lambda (_descriptor _tree) #f))

(defstruct $Step () transparent: #t)
(defstruct (BranchStep $Step) (branch) transparent: #t)
(defstruct (SkipStep $Step) (bits-height) transparent: #t)

;; The height in a Costep (context for applying a step) is the height of the current trie so far,
;; *before* next step is taken. It is -1 if a leaf, the length of the key *minus one* for another node,
;; thus 0 for a branch whose bit of decision is 1, h for a branch whose bit of decision is 1<<h.
;; Note that steps may be applied to an empty trie, whose height is undefined outside of such a context,
;; and that the height of a Costep may itself be #f (or -inf.0, or whatever it is for .empty),
;; when the Costep is itself the result of trying to find a path from the empty trie.
;; The key in a Costep is the bits *above* the height, to be multiplied by 2**(height+1),
;; to get the actual key of the start of the current trie,
;; i.e. prepend those Costep bits as high bits to the bits provided by the subtrie-in-focus as low bits.
(defstruct $Costep (height key) transparent: #t) ; height: (Or Height '(-1 #f)) key: Key
(defstruct $Unstep (left right skip) transparent: #t) ;; left: (Fun trunk <- Key Height trunk branch) right: (Fun trunk <- Key Height branch trunk) skip: (Fun trunk <- Key Height Height Key trunk) ;; the first argument, key, only contains the high bits and must be shifted by 1+ the second argument Height, to get the full key for the first element of the trie node resulting from unstepping. ;; trunk is conceptually branch plus optional path-dependent information
(defstruct $Path (costep steps) transparent: #t) ; costep: Costep steps: (List (Step t))
(def ($Path-key path) ($Costep-key ($Path-costep path))) ;; key used in a path

(include "trie/changes.ss")

(include "trie/protocol.ss")

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
