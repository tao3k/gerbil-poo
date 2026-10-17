;;; Guarded finite data generation through the existing recursive Interaction.
(export recursive-generator)
(import :std/iter :std/error (only-in :std/list/list map-in-order)
        ./object (only-in ./mop Any element?) ./generation-graph
        (prefix-in ./recursive recursive.))
;; Standard host PRNG state is invocation-local; no mutable source escapes a node.
(extern namespace: #f make-random-source random-source-pseudo-randomize! random-source-make-integers)
;; Immutable finite derivations retain the selected Union branch and normalized
;; scalar weight. They are private evidence, not user-injected source receipts.
(defstruct derivation (node value children weight count) final: #t)
;; Remaining visit quota flows through every sibling and failed alternative.
(defstruct answer (value remaining) final: #t)

;; Capture source revisions at compilation, not only at the start of testing.
(def (capture sources) (map (lambda (source) (cons source (object-revision source))) sources))
;; Opaque custom samplers retain their own compiled-source admission hooks.
(def (fresh? stamps nodes)
  (and (every (lambda (entry) (= (cdr entry) (object-revision (car entry)))) stamps)
    (every (lambda (node)
      (let (sampler (node-sampler node))
        (or (not sampler) (not (.has? sampler .current?)) (.call sampler .current?)))) (vector->list nodes))))
;; A local deterministic source makes each request replayable from its explicit
;; seed. Choices/seeds are fully consumed before a continuation is returned.
(def (random-at seed)
  (def source (make-random-source))
  (random-source-pseudo-randomize! source 0 seed)
  (random-source-make-integers source))
;; Reuse existing carrier representations; transparent descriptors retain values.
(def (pack node children)
  (case (node-kind node)
    ((list) children) ((tuple) (list->vector children))
    ((pair) (cons (car children) (cadr children)))
    ((union) (car children))
    ((maybe) (if (null? children) (void) (car children)))
    ((or-false) (and (pair? children) (car children)))))
;; Combine one concrete constructor with already finite child derivations.
(def (constructed index node children)
  (make-derivation index (pack node (map derivation-value children)) children
    (+ 1 (apply + (map derivation-weight children)))
    (+ 1 (apply + (map derivation-count children)))))
;; Proper-list admission is bounded and detects cycles by pair identity before
;; invoking any recursive Type predicate or computing length on an unknown tail.
(def (list-carrier value budget)
  (def seen (make-hash-table-eq))
  (let loop ((tail value) (left budget) (out []))
    (cond ((null? tail) (reverse out))
          ((not (pair? tail)) #f)
          ((hash-key? seen tail) #f)
          ((zero? left) (refuse-generation 'search))
          (else (hash-put! seen tail #t) (loop (cdr tail) (- left 1) (cons (car tail) out))))))

;; Compile only a finite descriptor graph. Bounds apply to grammar visits and
;; emitted grammar nodes; primitive callbacks retain their own cost obligations.
(def (recursive-generator descriptor depth budget descriptor-budget search make-generator scalar)
  (def graph (compile-graph descriptor depth budget descriptor-budget search scalar))
  (def nodes (graph-nodes graph))
  (def stamps (append (graph-stamps graph) (capture (graph-sources graph))))
  ;; Read a saturated minimum; zero depth never has an inhabitant.
  (def (cost index level) (vector-ref (vector-ref (graph-costs graph) level) index))
  ;; Scalar callbacks must supply natural weights; their failures are never false
  ;; property results or reasons to choose a different Union alternative.
  (def (leaf index node value)
    (def sampler (node-sampler node))
    (def weight (.call sampler measure value))
    (unless (and (exact-integer? weight) (>= weight 0)) (error "invalid shrink measure" weight))
    (make-derivation index value [] (+ weight 1) 1))
  ;; Fold independent child requests with explicit residual quota, using the same
  ;; Interaction bind that source-language recursive programs already use.
  (def (children-action mode ids level remaining values seeds reserve?)
    (def minimum (if reserve? (apply + (map (cut cost <> level) ids)) 0))
    (let loop ((ids ids) (values values) (seeds seeds) (remaining remaining) (minimum minimum) (out []))
      (if (null? ids) (recursive.value (make-answer (reverse out) remaining))
        (let* ((reserve (if reserve? (- minimum (cost (car ids) level)) 0))
               (request (list mode (car ids) level (- remaining reserve) (car seeds) (car values))))
          (recursive.bind (recursive.request request)
            (lambda (head)
              (if (and (eq? mode 'inspect) (not (answer-value head)))
                (recursive.value (make-answer #f (+ reserve (answer-remaining head))))
                (loop (cdr ids) (cdr values) (cdr seeds) (+ reserve (answer-remaining head))
                  reserve (cons (answer-value head) out)))))))))
  ;; Choose only alternatives with a finite witness within this call's allowance.
  ;; No rejection sampling or retry-on-exception is hidden in the draw operation.
  (def (draw index node level remaining seed size)
    (def random (random-at seed))
    (def available (- remaining 1))
    (def lower (- level 1))
    (def ids (node-children node))
    (unless (cost index level) (refuse-generation 'depth))
    (when (> (cost index level) remaining) (refuse-generation 'nodes))
    (if (eq? (node-kind node) 'leaf)
      (let (value (.call (node-sampler node) draw random size))
        (unless (element? (node-descriptor node) value) (error "scalar generator left its descriptor"))
        (recursive.value (make-answer (leaf index node value) available)))
      (let* ((chosen
          (case (node-kind node)
            ((list)
             (let* ((minimum (cost (car ids) lower))
                    (width (if minimum (min size (quotient available minimum)) 0)))
               (make-list (random (+ width 1)) (car ids))))
            ((union)
             (let (choices (filter (lambda (id) (let (n (cost id lower)) (and n (<= n available)))) ids))
               (list (list-ref choices (random (length choices))))))
            ((maybe or-false)
             (if (and (cost (car ids) lower) (<= (cost (car ids) lower) available) (= (random 2) 1)) ids []))
            (else ids)))
             (seeds (map (lambda (_) (random 268435456)) chosen)))
        (recursive.map-interaction
          (lambda (children) (make-answer (constructed index node (answer-value children)) (answer-remaining children)))
          (children-action 'draw chosen lower available (make-list (length chosen) size) seeds #t)))))
  ;; Ordered bounded membership never invokes a container's recursively defined
  ;; .element?. Failed alternatives spend quota; malformed/cyclic carriers refuse.
  (def (inspect index node level remaining value)
    (def available (- remaining 1))
    (def lower (- level 1))
    (def ids (node-children node))
    (cond
      ((eq? (node-kind node) 'empty) (recursive.value (make-answer #f available)))
      ((eq? (node-kind node) 'leaf)
       (recursive.value (make-answer (and (element? (node-descriptor node) value) (leaf index node value)) available)))
      ((eq? (node-kind node) 'union)
       (let loop ((choices ids) (left available))
         (if (null? choices) (recursive.value (make-answer #f left))
           (recursive.bind (recursive.request (list 'inspect (car choices) lower left 0 value))
             (lambda (child)
               (if (answer-value child)
                 (recursive.value (make-answer (constructed index node (list (answer-value child))) (answer-remaining child)))
                 (loop (cdr choices) (answer-remaining child))))))))
      (else
        (def values
          (case (node-kind node)
            ((list) (list-carrier value available))
            ((tuple) (and (vector? value) (= (vector-length value) (length ids)) (vector->list value)))
            ((pair) (and (pair? value) (list (car value) (cdr value))))
            ((maybe) (if (void? value) [] (list value)))
            ((or-false) (if value (list value) []))))
        (if (not values) (recursive.value (make-answer #f available))
          (let ()
            (when (eq? (node-kind node) 'list) (set! ids (make-list (length values) (car ids))))
            (when (null? values) (set! ids []))
            (recursive.map-interaction
              (lambda (children) (make-answer (and (answer-value children)
                (constructed index node (answer-value children))) (answer-remaining children)))
              (children-action 'inspect ids lower available values (make-list (length ids) 0) #f)))))))
  ;; Value candidates preserve the selected Union branch. Lists may drop their
  ;; contents; nullable constructors may become absent. Domain checks/strict measure
  ;; descent and property failures are rechecked by the existing test runner.
  (def (shrink witness remaining)
    (def index (derivation-node witness))
    (def node (vector-ref nodes index))
    (def children (derivation-children witness))
    (def value (derivation-value witness))
    (if (eq? (node-kind node) 'leaf)
      (recursive.value (make-answer (.call (node-sampler node) shrink value) (- remaining 1)))
      (let loop ((rest children) (before []) (left (- remaining 1)) (out []))
        (if (null? rest)
          (recursive.value (make-answer
            (append (case (node-kind node)
                      ((list) (if (null? value) [] (list [] (cdr value))))
                      ((maybe) (if (void? value) [] (list (void))))
                      ((or-false) (if value [#f] [])) (else [])) out) left))
          (recursive.bind (recursive.request (list 'shrink 0 0 left 0 (car rest)))
            (lambda (candidates)
              (unless (list? (answer-value candidates)) (error "shrinker must return a finite proper list"))
              (loop (cdr rest) (cons (derivation-value (car rest)) before) (answer-remaining candidates)
                (append out (map (lambda (smaller)
                  (pack node (append (reverse before) (cons smaller (map derivation-value (cdr rest))))))
                  (answer-value candidates))))))))))
  ;; The program's requests carry all quotas and seeds. No cross-run memo is reused
  ;; for random/stateful callbacks; source observation depth remains independent.
  (def (generate request)
    (match request
      ([mode index level remaining seed value]
       (when (<= remaining 0) (refuse-generation (if (eq? mode 'draw) 'nodes 'search)))
       (cond ((eq? mode 'shrink) (shrink value remaining))
             ((= level 0) (if (eq? mode 'draw) (refuse-generation 'depth)
                              (recursive.value (make-answer #f (- remaining 1)))))
             (else (let (node (vector-ref nodes index))
               (if (eq? mode 'draw) (draw index node level remaining seed value)
                 (inspect index node level remaining value))))))))
  (def program (.cc recursive.Generator. input: Any output: Any generate: generate))
  ;; One observation is fresh and source-bound. A pending observation is a limit,
  ;; never a source error or proof of divergence. Host exceptions propagate intact.
  (def (run mode value allowance seed)
    (unless (fresh? stamps nodes) (refuse-generation 'stale))
    (let (result (recursive.solve program (+ (* 2 depth) 4) (list mode 0 depth allowance seed value)))
    (when (recursive.pending? result) (refuse-generation 'observation))
    (when (recursive.source-error? result) (error "unexpected recursive generation source error"))
    (unless (fresh? stamps nodes) (refuse-generation 'stale))
    (answer-value (recursive.value-result result))))
  ;; Decode with a finite grammar derivation; a value outside the depth-bounded
  ;; domain is a refusal, not an assertion that its unbounded Type is empty.
  (def (parse value)
    (def witness (run 'inspect value search 0))
    (and witness (<= (derivation-count witness) budget) witness))
  (def sampler (make-generator descriptor
    (lambda (random size)
      (derivation-value (run 'draw size budget (random 268435456))))
    (lambda (value)
      (def witness (parse value))
      (unless witness (error "value outside bounded recursive grammar"))
      (def candidates (run 'shrink witness search 0))
      (when (> (length candidates) search) (refuse-generation 'candidates))
      candidates)
    (lambda (value)
      (def witness (parse value))
      (unless witness (error "value outside bounded recursive grammar"))
      (derivation-weight witness))
    dependencies: (graph-sources graph)))
  (.cc sampler .accept?: (lambda (value) (and (parse value) #t))
      .current?: (lambda () (fresh? stamps nodes))
      limits: (.o bind-these: #f depth: depth nodes: budget descriptors: descriptor-budget search: search)))
