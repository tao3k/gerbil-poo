(defstruct $Trie () transparent: #t)
(defstruct (Empty $Trie) () transparent: #t final: #t)
(defstruct (Leaf $Trie) (value) transparent: #t final: #t)
(defstruct (Branch $Trie) (height left right) transparent: #t final: #t) ;; height of the top bit, not integer-length
(defstruct (Skip $Trie) (height bits-height bits child) transparent: #t final: #t) ;; bits-height is similarly top bit of bits, the number of valid bits in bits is (1+ bits-height)

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
(defstruct (BranchStep $Step) (branch) transparent: #t final: #t)
(defstruct (SkipStep $Step) (bits-height) transparent: #t final: #t)

;; The height in a Costep (context for applying a step) is the height of the current trie so far,
;; *before* next step is taken. It is -1 if a leaf, the length of the key *minus one* for another node,
;; thus 0 for a branch whose bit of decision is 1, h for a branch whose bit of decision is 1<<h.
;; Note that steps may be applied to an empty trie, whose height is undefined outside of such a context,
;; and that the height of a Costep may itself be #f (or -inf.0, or whatever it is for .empty),
;; when the Costep is itself the result of trying to find a path from the empty trie.
;; The key in a Costep is the bits *above* the height, to be multiplied by 2**(height+1),
;; to get the actual key of the start of the current trie,
;; i.e. prepend those Costep bits as high bits to the bits provided by the subtrie-in-focus as low bits.
(defstruct $Costep (height key) transparent: #t final: #t) ; height: (Or Height '(-1 #f)) key: Key
(defstruct $Unstep (left right skip) transparent: #t final: #t) ;; left: (Fun trunk <- Key Height trunk branch) right: (Fun trunk <- Key Height branch trunk) skip: (Fun trunk <- Key Height Height Key trunk) ;; the first argument, key, only contains the high bits and must be shifted by 1+ the second argument Height, to get the full key for the first element of the trie node resulting from unstepping. ;; trunk is conceptually branch plus optional path-dependent information
(defstruct $Path (costep steps) transparent: #t final: #t) ; costep: Costep steps: (List (Step t))
(def ($Path-key path)
  (using (costep ($Path-costep path) :- $Costep)
    costep.key)) ;; key used in a path
