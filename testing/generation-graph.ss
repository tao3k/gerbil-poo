;;; Finite recursive Type graphs; scalar samplers are supplied by the caller.
(export generator-sources compile-graph graph-nodes graph-sources graph-costs graph-stamps graph-sources-current? node-descriptor node-kind node-children node-sampler node-branches
        generation-refusal? generation-refusal-kind refuse-generation)
(import (only-in ../support/base require-value) :std/iter :std/error ../object
        (only-in :clan/poo/testing/property/generator with-sources with-generation-check boolean-result)
        (only-in ../mop Type validate)
        (only-in :std/list/list map-in-order delete-duplicates/hash)
        (only-in ../type List. Tuple. Pair. Union. Or. Maybe. OrFalse. Sum.))

;; Controlled resource refusal is distinct from a property exception or false result.
(deferror-class GenerationRefusal () generation-refusal?)
;; Inspect the precise exhausted resource without parsing an error message.
(def (generation-refusal-kind cause) (car (Error-irritants cause)))
;; All controlled limits carry the original operation/resource tag.
(def (refuse-generation kind) (raise (GenerationRefusal "generation limit" irritants: [kind])))
;; Graph nodes contain stable integer edges; no recursive value is used as a hash key.
(defstruct node (descriptor kind children sampler branches) final: #t)
;; Graph discovery captures every descriptor and explicit sampler dependency.
(defstruct graph (nodes sources costs stamps) final: #t)

;; Discovery and evaluation share the same epoch and opaque-sampler admission.
;; Callers prepare the sampler spine once; checking never rebuilds a node list.
;; Every present hook uses the core Boolean contract before the next participant.
(def (graph-sources-current? stamps samplers)
  (and (every (lambda (entry) (= (cdr entry) (object-revision (car entry)))) stamps)
    (every (lambda (sampler)
      (or (not (.has? sampler .current?))
        (boolean-result (.call sampler .current?) "source observer must return a boolean"))) samplers)))

;; One preparation boundary owns the constructor's declaration binding. Retarget
;; through a fresh constructor, never by inheriting a different Type's parser/tree.
;; Mandatory identities cannot be removed by replacing application dependencies.
(def (generator-sources sampler (retain! void) (expected #f))
  (retain! sampler)
  (def descriptor (with-sources [] (.get sampler descriptor)))
  (retain! descriptor)
  (when (and expected (not (eq? descriptor expected))) (error "sampler descriptor mismatch"))
  (def bound (with-sources [] (.get sampler bound-descriptor)))
  (retain! bound)
  (unless (eq? descriptor bound)
    (error "sampler descriptor binding changed; construct a new sampler"))
  (def dependencies (with-sources [] (.get sampler sources)))
  (unless (list? dependencies) (error "finite sampler sources required"))
  (def captured (list-copy dependencies))
  (for-each retain! captured)
  (cons sampler (cons descriptor captured)))
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
(def (describe descriptor scalar capture! discover)
  (validate Type descriptor)
  (def ancestors (compute-precedence-list! descriptor))
  ;; Explicit finite-empty samplers must not poison an otherwise viable Union.
  (def (as-leaf)
    (def sampler (scalar descriptor))
    ;; Admit the returned sampler through the SAME constructor/source boundary
    ;; as bridges and products, before optional metadata or later factories.
    (generator-sources sampler capture! descriptor)
    (values (if (and (.has? sampler .inhabited?) (not (.get sampler .inhabited?))) 'empty 'leaf) [] sampler #f))
  ;; One edge-discovery action owns quota, source admission and first observation.
  ;; Metadata callbacks cannot run ahead of the captured earlier child epochs.
  (def (carrier kind children)
    (unless (list? children) (error "proper descriptor child list required"))
    (values kind (map-in-order (lambda (child) (discover (lambda () child))) children) #f #f))
  ;; Fixed named edges use the same quota/observation action as Sum branches.
  ;; Capture each returned Type before another computed field can revise it.
  (def (fields kind names)
    (values kind (map-in-order (lambda (name)
      (discover (lambda () (.ref descriptor name)))) names) #f #f))
  (cond
    ((.has? descriptor .generator) (as-leaf))
    ((memq List. ancestors) (fields 'list '(type)))
    ((memq Tuple. ancestors) (carrier 'tuple (.get descriptor type-list)))
    ((memq Pair. ancestors) (fields 'pair '(left right)))
    ((memq Sum. ancestors)
     ;; Own the effective directory epoch before reading any tag or payload Type.
     ;; Duplicate child Types remain distinct branches; their labels are not IDs.
     (def directory (with-sources [] (.get descriptor variants)))
     (unless (object? directory) (error "Sum variant directory required"))
     (capture! directory)
     (def names (with-sources [] (.get descriptor variant-names)))
     (unless (and (list? names) (every symbol? names)
       (= (length names) (length (delete-duplicates/hash names table: (make-hash-table-eq)))))
       (error "distinct finite Sum tags required"))
     (def owned (list-copy names))
     (values 'sum (map-in-order (lambda (tag) (discover (lambda () (.ref directory tag)))) owned) #f owned))
    ;; Both protocols share a finite alternative membership grammar. Runtime
    ;; selection/normalization still belongs to the original descriptor.
    ((or (memq Union. ancestors) (memq Or. ancestors))
     (carrier 'union (.get descriptor types)))
    ((memq Maybe. ancestors) (fields 'maybe '(type)))
    ((memq OrFalse. ancestors) (fields 'or-false '(type)))
    (else (as-leaf))))

;; Refuse cycles containing only transparent alternatives. A supported recursive
;; cycle must cross a concrete List/Tuple/Pair or tagged Sum carrier, so finite values make
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
          ((union sum) (let (known (filter identity costs)) (and (pair? known) (min cap (+ 1 (apply min known))))))
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
  (def samplers [])
  (def observed (make-hash-table-eq))
  ;; One ledger captures each discovered identity once. A later edge or factory
  ;; cannot refresh an epoch already owned by this preparation.
  (def (capture! source)
    (unless (hash-key? observed source)
      (hash-put! observed source #t)
      (set! sources (cons source sources))
      (set! stamps (cons (cons source (object-revision source)) stamps))))
  ;; Reuse the same immutable stamps at runtime. The temporary checker protects
  ;; nested checked work inside a factory, but is never retained on the graph.
  (def (check!)
    (unless (graph-sources-current? stamps samplers)
      (refuse-generation 'stale)))
  ;; Reserve an identity before reading children, closing shared edges without
  ;; unfolding their Types recursively or invoking recursive .element? methods.
  (def (intern descriptor)
    (when (zero? remaining) (refuse-generation 'descriptors))
    (set! remaining (- remaining 1))
    (if (hash-key? indices descriptor) (hash-ref indices descriptor)
      (let (index count)
        (capture! descriptor)
        (set! count (+ count 1))
        (vector-set! types index descriptor)
        (hash-put! indices descriptor index)
        index)))
  ;; Reserve edge fuel before reading metadata, then capture its Type before
  ;; another edge callback. Intern still charges repeated/shared occurrences.
  (def (discover read)
    (when (zero? remaining) (refuse-generation 'descriptors))
    (intern (with-sources [] (read))))
  (intern root)
  (with-generation-check check!
  (let loop ((index 0))
    (when (< index count)
      (let (type (vector-ref types index))
        (let-values (((kind children sampler tags) (with-sources [] (describe type scalar capture! discover))))
          (vector-set! rows index (make-node type kind children sampler
            (if (memq kind '(union sum)) (map cons (or tags (make-list (length children) #f)) children) [])))
          (when sampler (set! samplers (cons sampler samplers)))
          (check!)))
      (loop (+ index 1))))
  (let (nodes (subvector rows 0 count))
    (check-guarded nodes)
    (make-graph nodes sources (cost-table nodes depth budget) stamps)))))
