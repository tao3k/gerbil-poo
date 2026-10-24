;;; Finite recursive Type graphs; scalar samplers are supplied by the caller.
(export compile-graph graph-nodes graph-sources graph-costs graph-stamps node-descriptor node-kind node-children node-sampler
        generation-refusal? generation-refusal-kind refuse-generation)
(import (only-in ./support/base require-value) :std/iter :std/error ./object
        (only-in ./mop Type validate)
        (only-in ./type List. Tuple. Pair. Union. Or. Maybe. OrFalse.))

;; Controlled resource refusal is distinct from a property exception or false result.
(deferror-class GenerationRefusal () generation-refusal?)
;; Inspect the precise exhausted resource without parsing an error message.
(def (generation-refusal-kind cause) (car (Error-irritants cause)))
;; All controlled limits carry the original operation/resource tag.
(def (refuse-generation kind) (raise (GenerationRefusal "generation limit" irritants: [kind])))
;; Graph nodes contain stable integer edges; no recursive value is used as a hash key.
(defstruct node (descriptor kind children sampler) final: #t)
;; Graph discovery captures every descriptor and explicit sampler dependency.
(defstruct graph (nodes sources costs stamps) final: #t)

;; Validate bounded configuration before allocating a graph or dynamic-program table.
;; These caps bound protocol bookkeeping, not arbitrary callback execution or bytes.
(def (check-limits depth nodes descriptors search)
  (let (refuse (lambda () (error "invalid recursive generation limits" depth nodes descriptors search)))
    (require-value depth (in-range-inclusive? 0 64) refuse)
    (require-value nodes (in-range-inclusive? 0 65536) refuse)
    (require-value descriptors (in-range-inclusive? 1 1024) refuse)
    (require-value search (in-range-inclusive? 1 1048576) refuse)))
;; Classify standard carrier constructors; explicit .generator overrides remain
;; opaque leaves with declared callback dependencies. Container semantics are reused.
(def (describe descriptor scalar)
  (validate Type descriptor)
  (def ancestors (compute-precedence-list! descriptor))
  ;; Explicit finite-empty samplers must not poison an otherwise viable Union.
  (def (as-leaf)
    (def sampler (scalar descriptor))
    (values (if (and (.has? sampler .inhabited?) (not (.get sampler .inhabited?))) 'empty 'leaf) [] sampler))
  (cond
    ((.has? descriptor .generator) (as-leaf))
    ((memq List. ancestors) (values 'list (list (.get descriptor type)) #f))
    ((memq Tuple. ancestors) (values 'tuple (.get descriptor type-list) #f))
    ((memq Pair. ancestors) (values 'pair (list (.get descriptor left) (.get descriptor right)) #f))
    ;; Both protocols share a finite alternative membership grammar. Runtime
    ;; selection/normalization still belongs to the original descriptor.
    ((or (memq Union. ancestors) (memq Or. ancestors))
     (values 'union (.get descriptor types) #f))
    ((memq Maybe. ancestors) (values 'maybe (list (.get descriptor type)) #f))
    ((memq OrFalse. ancestors) (values 'or-false (list (.get descriptor type)) #f))
    (else (as-leaf))))

;; Refuse cycles containing only transparent alternatives. A supported recursive
;; cycle must cross a concrete List/Tuple/Pair carrier, so finite values make
;; structural progress. This is guarded finite-data generation, not arbitrary knots.
(def (check-guarded nodes)
  (def colors (make-vector (vector-length nodes) 'white))
  ;; Standard finite graph DFS visits each transparent edge once; graph admission
  ;; already bounds both vertices and edges before this local traversal starts.
  (def (visit index)
    (case (vector-ref colors index)
      ((gray) (refuse-generation 'unguarded))
      ((white)
       (vector-set! colors index 'gray)
       (let (node (vector-ref nodes index))
         (when (memq (node-kind node) '(union maybe or-false))
           (for-each visit (node-children node))))
       (vector-set! colors index 'black))))
  (for-each visit (iota (vector-length nodes))))

;; Saturated minimum node costs at each unfolding depth. Every edge reads the
;; preceding row, so SCCs need no unsafe host fixed point. #f means no finite
;; inhabitant at this depth; nodes+1 means inhabited but over the configured quota.
(def (cost-table nodes depth budget)
  (def table (make-vector (+ depth 1)))
  (def cap (+ budget 1))
  (vector-set! table 0 (make-vector (vector-length nodes) #f))
  (for (level (in-range 1 (+ depth 1)))
    (def previous (vector-ref table (- level 1)))
    (def row (make-vector (vector-length nodes) #f))
    (for (index (in-range (vector-length nodes)))
      (def node (vector-ref nodes index))
      (def costs (map (cut vector-ref previous <>) (node-children node)))
      (vector-set! row index
        (case (node-kind node)
          ((leaf list maybe or-false) 1)
          ((tuple pair) (and (every identity costs) (min cap (+ 1 (apply + costs)))))
          ((union) (let (known (filter identity costs)) (and (pair? known) (min cap (+ 1 (apply min known))))))
          (else #f))))
    (vector-set! table level row))
  table)

;; Discover shared/cyclic descriptors by object identity, charging one unit per
;; visited edge occurrence plus the root. Callbacks and descriptor slots must stay
;; stable during compilation; the resulting sampler checks these captured stamps.
(def (compile-graph root depth budget descriptor-budget search scalar)
  (check-limits depth budget descriptor-budget search)
  (let ()
  (def indices (make-hash-table-eq))
  (def rows (make-vector descriptor-budget #f))
  (def types (make-vector descriptor-budget #f))
  (def count 0)
  (def remaining descriptor-budget)
  (def sources [])
  (def stamps [])
  ;; Reserve an identity before reading children, closing shared edges without
  ;; unfolding their Types recursively or invoking recursive .element? methods.
  (def (intern descriptor)
    (when (zero? remaining) (refuse-generation 'descriptors))
    (set! remaining (- remaining 1))
    (if (hash-key? indices descriptor) (hash-ref indices descriptor)
      (let (index count)
        (set! count (+ count 1))
        (vector-set! types index descriptor)
        (hash-put! indices descriptor index)
        index)))
  (intern root)
  (let loop ((index 0))
    (when (< index count)
      (let* ((type (vector-ref types index)) (stamp (cons type (object-revision type))))
        (set! stamps (cons stamp stamps))
        (let-values (((kind children sampler) (describe type scalar)))
          (unless (list? children) (error "proper descriptor child list required"))
          (let (edges (map intern children))
            (vector-set! rows index (make-node type kind edges sampler)))
          (set! sources (cons type (append (if sampler (cons sampler (.get sampler sources)) []) sources)))))
      (loop (+ index 1))))
  (let (nodes (subvector rows 0 count))
    (check-guarded nodes)
    (make-graph nodes sources (cost-table nodes depth budget) stamps))))
