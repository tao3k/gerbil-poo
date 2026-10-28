;;; Independent generators and lazy shrinking provenance; no POO dependencies.
(export make-generator make-tree-generator make-sample generator? integer-shrinks
        generator-unit generator-map generator-bind generator-sequence bind-generators
        generator-choice generator-frequency generator-sized generator-resize generator-scale
        generator-delay generator-filter generator-no-shrink generator-with-shrink
        generate generator-current? sample? sample-value sample-children sample-current sample-sources
        rejected? proposal-current proposal-sources generation-exhausted? stale-generation?
        boolean-result live? random-at)
(import :std/error :std/iter (only-in :std/list/list delete-duplicates/hash))
(extern namespace: #f make-random-source random-source-pseudo-randomize! random-source-make-integers)
;; Producers and nodes retain flat source leaves, never recursively composed guards.
(defstruct generation (run sources) final: #t)
;; Nodes have immutable-by-protocol value/child/source ownership within one run.
(defstruct sample-node (value children sources) final: #t)
;; A pruned child is still charged, but never reaches a value callback.
(defstruct rejected (sources) final: #t)
;; Resource exhaustion and source invalidation cannot impersonate false properties.
(defstruct generation-exhausted () final: #t)
;; Stale source refusal is classified before domain-specific exception mapping.
(defstruct stale () final: #t)
;; Public recognition preserves ordinary Gerbil record identity.
(def generator? generation?)
;; Public recognition does not expose node mutators.
(def sample? sample-node?)
;; Values and factories retain their existing public accessors.
(def sample-value sample-node-value)
;; Child factories are invoked only by positive-budget consumers.
(def sample-children sample-node-children)
;; Only the precise source refusal is classified as stale generation.
(def stale-generation? stale?)
;; Immutable defaults contribute no source leaves and allocate no per-node guard.
(def (immutable-current) #t)
;; Explicit callbacks are leaves. Hash deduplication uses callback identity;
;; separately captured revision epochs remain separate callbacks and are retained.
(def (merge-sources . groups)
  (def sources (apply append groups))
  (cond ((null? sources) [])
        ((null? (cdr sources)) (list (car sources)))
        (else (delete-duplicates/hash sources table: (make-hash-table-eq)))))
;; Normalize and validate the observer boundary once, not at every sample read.
(def (observer-sources current sources)
  (unless (and (procedure? current) (list? sources) (every procedure? sources))
    (error "source observers must be procedures"))
  (merge-sources (if (eq? current immutable-current) [] (list current)) sources))
;; Predicate results are strict Boolean judgments, never truthy authorization.
(def (boolean-result value message)
  (unless (boolean? value) (error message value)) value)
;; User source observers remain explicit pure callbacks.
(def (live? current) (boolean-result (current) "source observer must return a boolean"))
;; A stale producer cannot invoke its next selector or construct a replacement.
(def (require-sources! sources)
  (unless (every live? sources) (raise (make-stale))))
;; Public source lists are copies, so a downstream consumer cannot edit node ownership.
(def (sample-sources tree) (map identity (sample-node-sources tree)))
;; Each node exposes an ordinary callback for consumers outside the core algebra.
(def (sample-current tree) (lambda () (every live? (sample-node-sources tree))))
;; Both ordinary and pruned proposals retain every observed source leaf.
(def (proposal-sources proposal)
  (cond ((sample? proposal) (sample-sources proposal))
        ((rejected? proposal) (map identity (rejected-sources proposal)))
        (else (error "shrinker must produce sample proposals"))))
;; External observation uses the same leaves without a parallel callback registry.
(def (proposal-current proposal) (lambda () (every live? (proposal-sources proposal))))
;; Advanced tree construction accepts explicit leaves, retaining one callback boundary.
(def (make-sample value children (current immutable-current) sources: (sources []))
  (unless (procedure? children) (error "sample child factory required"))
  (make-sample-node value children (observer-sources current sources)))
;; Draw from a fresh invocation-owned PRNG rather than global random state.
(def (random-at seed)
  (def source (make-random-source))
  (random-source-pseudo-randomize! source 0 seed)
  (random-source-make-integers source))
;; Split once per parent/child pair; dependent regeneration reuses the child seed.
(def (split-seed random) (random 4294967087))
;; Root admission merges producer and node sources without nesting callback guards.
(def (generate generator random size)
  (unless (generator? generator) (error "generator required"))
  (unless (and (exact-integer? size) (>= size 0)) (error "natural generator size required" size))
  (require-sources! (generation-sources generator))
  (def tree ((generation-run generator) random size))
  (unless (sample? tree) (error "generator must produce a sample"))
  (make-sample-node (sample-value tree) (sample-children tree)
    (merge-sources (generation-sources generator) (sample-node-sources tree))))
;; Signed shrinking is a general value algorithm independent of POO Types.
(def (integer-shrinks value)
  (if (zero? value) []
    (delete-duplicates/hash (list 0 (quotient value 2) (- value (if (> value 0) 1 -1))))))
;; Lift value callbacks once; do not force child factories while constructing roots.
(def (make-generator (draw : :procedure) (shrink : :procedure)
                    current?: (current immutable-current) sources: (sources []))
  (def observed (observer-sources current sources))
  (def (tree value)
    (make-sample-node value
      (lambda () (in-coroutine (lambda (yield)
        (require-sources! observed)
        (for (child (shrink value)) (yield (tree child)))))) observed))
  (make-generation (lambda (random size) (tree (draw random size))) observed))
;; An advanced producer returns a validated sample tree using the same protocol.
(def (make-tree-generator (draw : :procedure) current?: (current immutable-current) sources: (sources []))
  (make-generation draw (observer-sources current sources)))
;; Constants consume no randomness and have no shrink children.
(def (generator-unit value)
  (make-generator (lambda (_random _size) value) (lambda (_) [])))
;; Node mapping retains preimages and flat ownership; rejected proposals skip mapping.
(def (map-sample tree transform sources)
  (def observed (merge-sources sources (proposal-sources tree)))
  (require-sources! observed)
  (if (rejected? tree) (make-rejected observed)
    (make-sample-node (transform (sample-value tree))
      (lambda () (in-coroutine (lambda (yield)
        (require-sources! observed)
        (for (child ((sample-children tree))) (yield (map-sample child transform sources)))))) observed)))
;; Mapping is separate from the domain specification and its decreasing measure.
(def (generator-map generator (transform : :procedure) current?: (current immutable-current))
  (def sources (merge-sources (observer-sources current []) (generation-sources generator)))
  (make-generation (lambda (random size) (map-sample (generate generator random size) transform sources)) sources))
;; Parent shrinks regenerate the dependent child using its captured seed. A rejected
;; parent never invokes selection; source leaves are unioned rather than rewrapped.
(def (bind-sample parent select seed size sources)
  (def observed (merge-sources sources (proposal-sources parent)))
  (require-sources! observed)
  (if (rejected? parent) (make-rejected observed)
    (let (child (generate (select (sample-value parent)) (random-at seed) size))
      (make-sample-node (sample-value child)
        (lambda () (in-coroutine (lambda (yield)
          (require-sources! observed)
          (for (smaller ((sample-children parent))) (yield (bind-sample smaller select seed size sources)))
          (for (smaller ((sample-children child))) (yield (map-sample smaller identity observed))))))
        (merge-sources observed (sample-node-sources child))))))
;; Bind owns no output-value cache or second PRNG owner.
(def (generator-bind generator (select : :procedure) current?: (current immutable-current))
  (def sources (merge-sources (observer-sources current []) (generation-sources generator)))
  (make-generation (lambda (random size)
    (def parent-seed (split-seed random)) (def child-seed (split-seed random))
    (bind-sample (generate generator (random-at parent-seed) size) select child-seed size sources)) sources))
;; Products lower through bind/map rather than another generation/shrink traversal.
(def (generator-sequence generators)
  (foldr (lambda (generator tail)
    (generator-bind generator (lambda (head)
      (generator-map tail (lambda (rest) (cons head rest)))))) (generator-unit []) generators))
;; Producer freshness is one flat leaf walk.
(def (generator-current? generator) (every live? (generation-sources generator)))
;; Dependent syntax is only the existing bind/unit algebra, evaluated once.
(defrules bind-generators ()
  ((_ () body ...) (generator-unit (let () body ...)))
  ((_ ((name expression) rest ...) body ...)
   (generator-bind expression (lambda (name) (bind-generators (rest ...) body ...)))))
;; Dynamic branches contribute their own producer/node leaves when generated.
(def (selected-sample selected random size sources)
  (unless (generator? selected) (error "selector must return a generator"))
  (map-sample (generate selected random size) identity sources))
;; Validate and copy the finite weight table once. Zero weights are never selected.
(def (generator-frequency choices)
  (unless (and (pair? choices) (list? choices)
    (every (lambda (entry) (and (pair? entry) (exact-integer? (car entry))
      (>= (car entry) 0) (generator? (cdr entry)))) choices)
    (> (apply + (map car choices)) 0)) (error "invalid generator weights"))
  (set! choices (map (lambda (entry) (cons (car entry) (cdr entry))) choices))
  (def total (apply + (map car choices)))
  (make-generation (lambda (random size)
    (let select ((entries choices) (offset (random total)))
      (if (< offset (caar entries)) (selected-sample (cdar entries) random size [])
        (select (cdr entries) (- offset (caar entries)))))) []))
;; Uniform choice reuses the weighted selector and its empty-table refusal.
(def (generator-choice . generators)
  (generator-frequency (map (lambda (generator) (cons 1 generator)) generators)))
;; Size selection retains the selected branch's sample provenance.
(def (generator-sized (select : :procedure) current?: (current immutable-current))
  (def sources (observer-sources current []))
  (make-generation (lambda (random size)
    (require-sources! sources) (selected-sample (select size) random size sources)) sources))
;; Size overrides are explicit natural values, not descriptor-budget overrides.
(def (generator-resize generator size)
  (unless (and (generator? generator) (exact-integer? size) (>= size 0)) (error "invalid generator size" size))
  (make-generation (lambda (random _) (generate generator random size)) (generation-sources generator)))
;; Scaling is sized/resize composition, preserving their shared boundary.
(def (generator-scale generator (scale : :procedure) current?: (current immutable-current))
  (generator-sized (lambda (size) (generator-resize generator (scale size))) current?: current))
;; Delay quota is invocation-local and shared by nested delayed constructors.
(def current-delay-budget (make-parameter #f))
;; Each force spends a token before invoking its constructor; callback termination
;; itself remains subject to the unchanged process guard, not a universal theorem.
(def (generator-delay (construct : :procedure) depth: (depth 32) current?: (current immutable-current))
  (unless (and (exact-integer? depth) (>= depth 0)) (error "invalid generator delay depth"))
  (def sources (observer-sources current []))
  (make-generation (lambda (random size)
    (require-sources! sources)
    (def fuel (min depth (or (current-delay-budget) depth)))
    (when (zero? fuel) (raise (make-generation-exhausted)))
    (parameterize ((current-delay-budget (1- fuel))) (selected-sample (construct) random size sources))) sources))
;; Prune rejected branches, yielding a charged tombstone rather than searching
;; descendants invisibly. Predicates never receive already rejected proposals.
(def (filter-sample tree predicate sources)
  (def observed (merge-sources sources (proposal-sources tree)))
  (require-sources! observed)
  (if (rejected? tree) (make-rejected observed)
    (let (accepted? (boolean-result (predicate (sample-value tree)) "filter must return a boolean"))
      (require-sources! observed)
      (if accepted?
        (make-sample-node (sample-value tree)
          (lambda () (in-coroutine (lambda (yield)
            (for (child ((sample-children tree))) (yield (filter-sample child predicate observed)))))) observed)
        (make-rejected observed)))))
;; Even rejected draws retain their leaves in the accepted root. Their independent
;; finite retry quota does not consume or evade the shrink consumer's attempt quota.
(def (generator-filter generator (predicate : :procedure) attempts: (attempts 100)
                          current?: (current immutable-current))
  (unless (and (generator? generator) (exact-integer? attempts) (>= attempts 0)) (error "invalid generator filter budget"))
  (def sources (merge-sources (observer-sources current []) (generation-sources generator)))
  (make-generation (lambda (random size)
    (let search ((fuel attempts) (observed sources))
      (require-sources! observed)
      (when (zero? fuel) (raise (make-generation-exhausted)))
      (def tree (generate generator random size))
      (def visited (merge-sources observed (sample-node-sources tree)))
      (def result (filter-sample tree predicate visited))
      (if (sample? result) result (search (1- fuel) visited)))) sources))
;; Replace only the shrink policy, retaining all drawn branch leaves without
;; forcing old/new child factories during preparation or zero-fuel checking.
(def (generator-with-shrink generator (shrink : :procedure) current?: (current immutable-current))
  (def sources (merge-sources (observer-sources current []) (generation-sources generator)))
  (make-generation (lambda (random size)
    (def tree (generate generator random size))
    (generate (make-generator (lambda (_random _size) (sample-value tree)) shrink
      sources: (merge-sources sources (sample-node-sources tree))) random size)) sources))
;; Disabling shrinking is the empty policy, using the same source-owned protocol.
(def (generator-no-shrink generator) (generator-with-shrink generator (lambda (_) [])))
