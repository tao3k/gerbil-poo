;;; Independent generators and lazy shrinking provenance; no POO dependencies.
(export make-generator make-tree-generator make-sample generator? integer-shrinks
        generator-unit generator-map generator-bind generator-sequence bind-generators
        generator-choice generator-frequency generator-sized generator-resize generator-scale
        generator-delay generator-filter generator-no-shrink generator-with-shrink
        generate generator-current? sample? sample-value sample-children sample-current sample-sources
        rejected? proposal-current proposal-sources generation-exhausted? stale-generation?
        boolean-result live? random-at
        generator-function function-value? function-domain function-apply function-procedure
        function-table function-from-table
        generator-integer generator-character generator-byte generator-list
        generator-string generator-symbol generator-bytes data-list-shrinks character-shrinks list-deletions list-deletion-count sample-sequence)
(import :std/error :std/iter (only-in :std/list/list delete-duplicates/hash take drop))
(extern namespace: #f make-random-source random-source-pseudo-randomize! random-source-make-integers
        random-source-state-ref random-source-state-set!)
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
(def (merge-sources left right)
  (cond ((null? left) right)
        ((or (null? right) (eq? left right)) left)
        (else (delete-duplicates/hash (append left right) table: (make-hash-table-eq)))))
;; Normalize and validate the observer boundary once, not at every sample read.
(def (observer-sources current sources)
  (unless (and (procedure? current) (list? sources) (every procedure? sources))
    (error "source observers must be procedures"))
  (def owned (map identity sources))
  (merge-sources (if (eq? current immutable-current) [] (list current))
    (if (and (pair? owned) (pair? (cdr owned)))
      (delete-duplicates/hash owned table: (make-hash-table-eq)) owned)))
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
;; Internal immutable lists can be shared without crossing the public boundary.
(def (proposal-owned-sources proposal)
  (cond ((sample? proposal) (sample-node-sources proposal))
        ((rejected? proposal) (rejected-sources proposal))
        (else (error "shrinker must produce sample proposals"))))
;; Both ordinary and pruned proposals export detached observer lists.
(def (proposal-sources proposal) (map identity (proposal-owned-sources proposal)))
;; External observation uses the same leaves without a parallel callback registry.
(def (proposal-current proposal) (lambda () (every live? (proposal-owned-sources proposal))))
;; Advanced tree construction accepts explicit leaves, retaining one callback boundary.
(def (make-sample value children (current immutable-current) sources: (sources []))
  (unless (procedure? children) (error "sample child factory required"))
  (make-sample-node value children (observer-sources current sources)))
;; Bind owns an invocation-local checkpoint table, like the existing delay quota.
;; Only opaque initial states are shared; mutable PRNG instances are never cached.
(def current-random-states (make-parameter #f))
;; SRFI-27 owns seed expansion and its opaque checkpoint representation.
(def (expand-random-state seed)
  (def source (make-random-source))
  (random-source-pseudo-randomize! source 0 seed)
  (random-source-state-ref source))
;; Nested bind regeneration reuses preparation, not earlier generated values.
(def (random-state-at seed)
  (def states (current-random-states))
  (if states
    (if (hash-key? states seed) (hash-ref states seed)
      (let (state (expand-random-state seed)) (hash-put! states seed state) state))
    (expand-random-state seed)))
;; Each replay restores a NEW source; sibling draws cannot mutate the checkpoint.
(def (random-from-state state)
  (def source (make-random-source))
  (random-source-state-set! source state)
  (random-source-make-integers source))
;; Draw from a fresh invocation-owned PRNG rather than global random state.
(def (random-at seed) (random-from-state (random-state-at seed)))
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
  (def tree (make-sample-node value (lambda () []) []))
  (make-generation (lambda (_random _size) tree) []))
;; Node mapping retains preimages and flat ownership; rejected proposals skip mapping.
(def (map-sample tree transform sources)
  (def observed (merge-sources sources (proposal-owned-sources tree)))
  (require-sources! observed)
  (cond ((rejected? tree) (make-rejected observed))
    ;; Identity can share an internal node only when it adds no source ownership.
    ((and (eq? transform identity) (eq? observed (sample-node-sources tree))) tree)
    (else (make-sample-node (transform (sample-value tree))
      (lambda () (in-coroutine (lambda (yield)
        (require-sources! observed)
        (for (child ((sample-children tree))) (yield (map-sample child transform sources)))))) observed))))
;; Mapping is separate from the domain specification and its decreasing measure.
(def (generator-map generator (transform : :procedure) current?: (current immutable-current))
  (def sources (merge-sources (observer-sources current []) (generation-sources generator)))
  (make-generation (lambda (random size) (map-sample (generate generator random size) transform sources)) sources))
;; Parent shrinks regenerate the dependent child using its captured seed. A rejected
;; parent never invokes selection; source leaves are unioned rather than rewrapped.
(def (bind-sample parent select seed size sources states)
  (def observed (merge-sources sources (proposal-owned-sources parent)))
  (require-sources! observed)
  (if (rejected? parent) (make-rejected observed)
    (let (child (parameterize ((current-random-states states))
                 (generate (select (sample-value parent)) (random-at seed) size)))
      (make-sample-node (sample-value child)
        (lambda () (in-coroutine (lambda (yield)
          (require-sources! observed)
          (for (smaller ((sample-children parent))) (yield (bind-sample smaller select seed size sources states)))
          (for (smaller ((sample-children child))) (yield (map-sample smaller identity observed))))))
        (merge-sources observed (sample-node-sources child))))))
;; Bind owns no output-value cache or second PRNG owner.
(def (generator-bind generator (select : :procedure) current?: (current immutable-current))
  (def sources (merge-sources (observer-sources current []) (generation-sources generator)))
  (make-generation (lambda (random size)
    (def states (or (current-random-states) (make-hash-table-eqv)))
    (parameterize ((current-random-states states))
      (def parent-seed (split-seed random)) (def child-seed (split-seed random))
      (bind-sample (generate generator (random-at parent-seed) size) select child-seed size sources states))) sources))
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
  (def observed (merge-sources sources (proposal-owned-sources tree)))
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

;; Inclusive finite intervals shrink their offset toward the admitted lower bound.
(def (generator-integer lower upper)
  (unless (and (exact-integer? lower) (exact-integer? upper) (<= lower upper))
    (error "ordered exact integer bounds required" lower upper))
  (make-generator (lambda (random _) (+ lower (random (1+ (- upper lower)))))
    (lambda (value) (map (cut + lower <>) (integer-shrinks (- value lower))))))
;; Unicode scalar ranks omit surrogate code points by construction, without retries.
(def (character-rank char)
  (unless (char? char) (error "character required" char))
  (def code (char->integer char))
  (when (<= #xd800 code #xdfff) (error "surrogate character refused"))
  (if (> code #xdfff) (- code #x800) code))
;; Scalar rank decoding is monotone across the one excluded Unicode interval.
(def (rank-character rank) (integer->char (if (>= rank #xd800) (+ rank #x800) rank)))
;; Value-only Type callbacks and sample trees share the same scalar shrink policy.
(def (character-shrinks value (lower #\x00))
  (def start (character-rank lower))
  (def offset (- (character-rank value) start))
  (unless (>= offset 0) (error "character below shrink interval"))
  (map (lambda (smaller) (rank-character (+ start smaller))) (integer-shrinks offset)))
;; Explicit inclusive character intervals skip the surrogate gap as well.
(def (generator-character lower: (lower #\x00) upper: (upper #\x10ffff))
  (generator-map (generator-integer (character-rank lower) (character-rank upper)) rank-character))
;; Bytes are exact octets, independent of text encoding and locale.
(def (generator-byte) (generator-integer 0 255))
;; Aligned blocks halve down to individual positions. No value equality or
;; callback participates: equal values at different positions keep distinct origins.
(def (list-deletion-count size minimum)
  (unless (and (exact-integer? size) (exact-integer? minimum) (<= 0 minimum size))
    (error "invalid deletion bounds"))
  (let sizes ((width (- size minimum)) (count 0))
    (if (zero? width) count (sizes (quotient width 2) (+ count (quotient size width))))))
;; Produce structural subsequences lazily, keeping every retained element intact.
;; Minimum is a length constraint; it does not privilege any particular prefix.
(def (list-deletions values minimum)
  (def size (length values))
  (list-deletion-count size minimum)
  (in-coroutine (lambda (yield)
    (let sizes ((width (- size minimum)))
      (unless (zero? width)
        (for (start (in-range 0 (1+ (- size width)) width))
          (yield (append (take values start) (drop values (+ start width)))))
        (sizes (quotient width 2)))))))
;; Value-only callbacks share structural deletion with the lazy sample protocol.
(def (data-list-shrinks values shrink minimum)
  (append (for/collect (candidate (list-deletions values minimum)) candidate)
    (let coordinates ((tail values) (before []))
      (if (null? tail) []
        (append (map (lambda (value) (append (reverse before) (cons value (cdr tail)))) (shrink (car tail)))
          (coordinates (cdr tail) (cons (car tail) before)))))))
;; Compose retained element trees without drawing again. Every descendant keeps
;; all previously observed leaves, including sources of structurally removed nodes.
(def (sample-sequence samples (pack identity) min-length: (minimum 0)
                      current?: (current immutable-current) sources: (sources []))
  (unless (and (list? samples) (procedure? pack)) (error "sample sequence required"))
  (list-deletion-count (length samples) minimum)
  (def inherited (observer-sources current sources))
  ;; One tree policy serves raw Lists, mapped data and typed recursive carriers.
  (def (sequence trees inherited)
    (def observed (foldl (lambda (tree sources) (merge-sources sources (proposal-owned-sources tree))) inherited trees))
    (require-sources! observed)
    (if (not (every sample? trees)) (make-rejected observed)
      (make-sample-node (pack (map sample-value trees))
        (lambda () (in-coroutine (lambda (yield)
          (require-sources! observed)
          (for (smaller (list-deletions trees minimum)) (yield (sequence smaller observed)))
          (let coordinates ((tail trees) (before []))
            (unless (null? tail)
              (for (child ((sample-children (car tail))))
                (yield (sequence (append (reverse before) (cons child (cdr tail))) observed)))
              (coordinates (cdr tail) (cons (car tail) before))))))) observed)))
  (sequence samples inherited))
;; Capture each root as a value without forcing its descendants. Wrapping does
;; not split or consume randomness, so the existing sequence draw schedule survives.
(def (sampled-generator generator)
  (make-generation (lambda (random size)
    (let (tree (generate generator random size))
      (make-sample-node tree (lambda () []) (sample-node-sources tree)))) (generation-sources generator)))
;; Length is chosen once. Structural shrinking deletes retained trees rather
;; than regenerating payloads under a shorter length's dependent seed.
(def (generator-list element min-length: (minimum 0) max-length: (maximum 128))
  (unless (and (generator? element) (exact-integer? minimum) (exact-integer? maximum)
               (<= 0 minimum maximum)) (error "invalid sequence generator bounds"))
  (generator-sized (lambda (size)
    (generator-bind (generator-no-shrink (generator-integer minimum (+ minimum (min size (- maximum minimum)))))
      (lambda (count)
        (def row (generator-sequence (make-list count (sampled-generator element))))
        (make-tree-generator (lambda (random size)
          (let (tree (generate row random size))
            (sample-sequence (sample-value tree) min-length: minimum sources: (sample-sources tree))))))))))
;; Standard Scheme carriers are mapped once; shrinking keeps the hidden list tree.
(def (generator-string (character (generator-character)) min-length: (minimum 0) max-length: (maximum 128))
  (generator-map (generator-list character min-length: minimum max-length: maximum) list->string))
;; Symbols are interned spellings, including empty and reader-sensitive spellings.
;; No gensyms, identifier grammar or module-name interpretation is inferred.
(def (generator-symbol (character (generator-character)) min-length: (minimum 0) max-length: (maximum 128))
  (generator-map (generator-string character min-length: minimum max-length: maximum) string->symbol))
;; Mutable byte vectors are freshly packed at each mapped node, never encoded as text.
(def (generator-bytes min-length: (minimum 0) max-length: (maximum 128))
  (generator-map (generator-list (generator-byte) min-length: minimum max-length: maximum) list->u8vector))

;; Finite functions store raw argument rows and result tuples, not opaque closures.
(defstruct function-value (entries current) final: #t)
;; Domain inspection returns fresh spines; callers own mutable payload dependencies.
(def (function-domain value) (map (lambda (entry) (map identity (car entry))) (function-value-entries value)))
;; Unknown rows are refused explicitly; repeated equal rows select the same tuple.
(def (function-apply value arguments)
  (unless (live? (function-value-current value)) (raise (make-stale)))
  (def entry (assoc arguments (function-value-entries value)))
  (unless entry (error "arguments outside finite function domain" arguments))
  (def result (cdr entry))
  (unless (live? (function-value-current value)) (raise (make-stale)))
  (map identity result))
;; Gerbil owns keyword forwarding and multiple-value delivery; Function contracts
;; may wrap this ordinary rest procedure without changing its finite table.
(def (function-procedure value)
  (lambda arguments (apply values (function-apply value arguments))))
;; Lift the SAME result-product tree, retaining each node's own branch observers.
(def (function-tree tree rows current)
  (if (rejected? tree) tree
    (let (results (sample-value tree))
      (def guard (sample-current tree))
      (unless (and (list? results) (= (length rows) (length results)) (every list? results))
        (error "finite function results must be value tuples" results))
      (make-sample-node
        (make-function-value (map cons rows (map (cut map identity <>) results))
          (lambda () (and (live? current) (guard))))
        (lambda () (in-coroutine (lambda (yield)
          (for (child ((sample-children tree))) (yield (function-tree child rows current))))))
        (sample-node-sources tree)))))
;; The finite row boundary is shared by generators and portable table restoration.
(def (function-rows rows limit)
  (unless (and (list? rows) (every list? rows) (exact-integer? limit) (>= limit 0)
    (<= (length rows) limit) (= (length rows) (length (delete-duplicates/hash rows))))
    (error "invalid finite function domain" rows))
  (map (cut map identity <>) rows))
;; Export fresh row/result spines; payload ownership remains the declared source law.
(def (function-table value)
  (unless (live? (function-value-current value)) (raise (make-stale)))
  (map (lambda (entry) (cons (map identity (car entry)) (map identity (cdr entry))))
    (function-value-entries value)))
;; A decoder restores finite data directly without drawing or evaluating stored code.
(def (function-from-table entries domain-limit: (limit 256) current?: (current immutable-current))
  (unless (and (list? entries) (every pair? entries) (every (lambda (entry) (list? (cdr entry))) entries)
    (procedure? current)) (error "invalid finite function table" entries))
  (def rows (function-rows (map car entries) limit))
  (make-function-value (map cons rows (map (lambda (entry) (map identity (cdr entry))) entries)) current))
;; Explicit finite domains avoid universal function inference or a fallback value.
;; Generate one tuple per distinct raw row; product shrinking preserves the domain.
(def (generator-function rows result-generator domain-limit: (limit 256) current?: (current immutable-current))
  (unless (and (generator? result-generator) (procedure? current)) (error "invalid function result generator"))
  (def domain (function-rows rows limit))
  (def tuples (generator-sequence (map (lambda (_) result-generator) domain)))
  (make-tree-generator (lambda (random size)
    (function-tree (generate tuples random size) domain current)) current?: current))
