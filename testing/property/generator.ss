;;; Independent generators and lazy shrinking provenance; no POO dependencies.
(export make-generator make-tree-generator make-sample generator? integer-shrinks
        generator-unit generator-map generator-bind generator-sequence bind-generators
        generator-choice generator-frequency generator-sized generator-resize generator-scale
        generator-delay generator-filter generator-no-shrink generator-with-shrink
        generate generator-current? sample? sample-value sample-children sample-current sample-sources with-generation-check with-sources
        rejected? proposal-current proposal-sources generation-exhausted? stale-generation?
        boolean-result live? random-at
        generator-function function-value? function-domain function-apply function-procedure
        function-table function-from-table
        generator-integer generator-integer-range integer-range-anchor integer-range-shrinks generator-rational rational-weight rational-shrinks generator-character generator-byte generator-list
        generator-string generator-symbol generator-keyword generator-bytes generator-elements generator-hash data-list-shrinks character-shrinks list-deletions list-deletion-count sample-sequence)
(import :std/error :std/iter (only-in :std/list/list append-map delete-duplicates/hash take drop))
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
        ;; Gerbil retains last occurrences. Normalize the right side first with
        ;; one shared table, then omit those leaves from the left before joining.
        ;; This avoids copying the entire left spine before duplicate removal.
        (else
         (let* ((seen (make-hash-table-eq))
                (right (delete-duplicates/hash right table: seen)))
           (append (delete-duplicates/hash left table: seen) right)))))
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
;; Run-local checks use standard dynamic scope. They are never copied into
;; sample ownership: a checker may read the runner's mutable observer ledger.
(def current-generation-checks (make-parameter []))
;; Install an interrupting check for nested generator/iterator boundaries. The
;; caller owns admission and refusal control; normal return and exceptions unwind
;; this parameter without retaining the checker on a generated tree.
(defrule (with-generation-check checker body ...)
  (let (check checker)
    (unless (procedure? check) (error "generation check must be a procedure"))
    (parameterize ((current-generation-checks (append (current-generation-checks) (list check))))
      body ...)))
;; Transient checks precede retained leaves, preserving the outer runner's
;; existing stale refusal and exact callback exceptions at every boundary.
(def (require-sources! sources)
  (for-each (lambda (check) (check)) (current-generation-checks))
  (unless (every live? sources) (raise (make-stale))))
;; Standard dynamic scope carries inherited leaves through selected child
;; graphs. It is restored on every exit and never owns a registry or PRNG.
(def current-generation-sources (make-parameter []))
;; One hygienic callback boundary checks the merged leaves. Dynamic binding is
;; skipped for an already shared context identity, avoiding an extra frame.
;; Exceptions bypass post-return checks unchanged, and the callback runs once.
(def (call-with-sources sources action)
  (let* ((inherited (current-generation-sources)) (owned (merge-sources inherited sources)))
    (require-sources! owned)
    (begin0
      (if (eq? inherited owned) (action)
        (parameterize ((current-generation-sources owned)) (action)))
      (require-sources! owned))))
;; Keep lexical bodies and nonlocal exits hygienic, while compiling the checked
;; dynamic-scope implementation once rather than expanding it into every caller.
(defrule (with-sources sources body ...)
  (call-with-sources sources (lambda () body ...)))
;; One private iteration form uses the standard Iterator protocol. Factory
;; evaluation and every next! (including EOF) share the inherited source boundary;
;; a paused traversal therefore refuses before resuming stale producer effects.
(defrule (for-sources (value sequence sources) body ...)
  (let (owned (merge-sources (current-generation-sources) sources))
    ;; With neither retained leaves nor a run check there is nothing to recheck.
    ;; Keep the standard loop for that scope-free immutable-data path.
    (if (and (null? owned) (null? (current-generation-checks))) (for (value sequence) body ...)
      (using (children (iter (with-sources owned sequence)) :- Iterator)
        (let next ()
          (let (value (with-sources owned (children.next!)))
            (unless (eq? value #!eof)
              (let () body ...) (next))))))))
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
  (def observed (merge-sources (current-generation-sources) (generation-sources generator)))
  (def tree (with-sources observed ((generation-run generator) random size)))
  (unless (sample? tree) (error "generator must produce a sample"))
  (make-sample-node (sample-value tree) (sample-children tree)
    (merge-sources observed (sample-node-sources tree))))
;; Signed shrinking is a general value algorithm independent of POO Types.
(def (integer-shrinks value)
  (if (zero? value) []
    (delete-duplicates/hash (list 0 (quotient value 2) (- value (if (> value 0) 1 -1))))))
;; Lift value callbacks once; do not force child factories while constructing roots.
(def (make-generator (draw : :procedure) (shrink : :procedure)
                    current?: (current immutable-current) sources: (sources []))
  (def observed (observer-sources current sources))
  ;; Capture invocation ownership in the recursive tree, so later independently
  ;; retained children keep inherited leaves after dynamic scope has unwound.
  (def (tree value owned)
    (make-sample-node value
      (lambda () (in-coroutine (lambda (yield)
        (for-sources (child (shrink value) owned) (yield (tree child owned)))))) owned))
  (make-generation (lambda (random size)
    (tree (draw random size) (merge-sources (current-generation-sources) observed))) observed))
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
  (with-sources observed
    (cond ((rejected? tree) (make-rejected observed))
      ;; Identity can share an internal node only when it adds no source ownership.
      ((and (eq? transform identity) (eq? observed (sample-node-sources tree))) tree)
      (else (make-sample-node (transform (sample-value tree))
        (lambda () (in-coroutine (lambda (yield)
          (for-sources (child ((sample-children tree)) observed)
            (yield (map-sample child transform observed)))))) observed)))))
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
    (let* ((selected (with-sources observed (select (sample-value parent))))
           (child (with-sources observed
             (parameterize ((current-random-states states))
               (generate selected (random-at seed) size))))
           ;; The returned node and its rebuilds own all already observed leaves,
           ;; including the child selected for the original parent value.
           (owned (merge-sources observed (sample-node-sources child))))
      (require-sources! owned)
      (make-sample-node (sample-value child)
        (lambda () (in-coroutine (lambda (yield)
          (for-sources (smaller ((sample-children parent)) owned)
            (yield (bind-sample smaller select seed size owned states)))
          (for-sources (smaller ((sample-children child)) owned)
            (yield (map-sample smaller identity owned)))))) owned))))
;; Bind owns no output-value cache or second PRNG owner.
(def (generator-bind generator (select : :procedure) current?: (current immutable-current))
  (def sources (merge-sources (observer-sources current []) (generation-sources generator)))
  (make-generation (lambda (random size)
    (def states (or (current-random-states) (make-hash-table-eqv)))
    (parameterize ((current-random-states states))
      (def parent-seed (split-seed random)) (def child-seed (split-seed random))
      (bind-sample (generate generator (random-at parent-seed) size) select child-seed size sources states))) sources))
;; Admit finite topology before mapping or source discovery, then own its spine.
;; Retain the established bind/map checkpoint owner and split schedule: a direct
;; iterative draw candidate did not pass the full-workflow GC cost acceptance.
(def (sampled-sequence (generators :~ list?))
  (unless (every generator? generators) (error "product generators required"))
  (def fields (list-copy generators))
  (def roots
    (foldr (lambda (generator tail)
      (generator-bind generator (lambda (head)
        (generator-map tail (lambda (rest) (cons head rest))))))
      (generator-unit []) (map sampled-generator fields)))
  ;; All fixed participants are declared before drawing; no per-field extra
  ;; validation layer or alternative runtime strategy is retained.
  (make-generation (generation-run roots)
    (observer-sources immutable-current (append-map generation-sources fields))))
;; Fixed products share sample-sequence's coordinate policy. Changing one field
;; retains every other field's original node, sources and hidden preimage; it
;; never redraws a suffix. Only explicit generator-bind rebuilds dependencies.
(def (generator-sequence generators)
  (def roots (sampled-sequence generators))
  (def width (length generators))
  (make-tree-generator (lambda (random size)
    (let (tree (generate roots random size))
      (sample-sequence (sample-value tree) min-length: width sources: (sample-sources tree))))
    sources: (generation-sources roots)))
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
;; Size selection retains explicit common leaves before selection, while dynamic
;; branches add only the leaves of the producer actually chosen.
(def (generator-sized (select : :procedure) current?: (current immutable-current) sources: (sources []))
  (def observed (observer-sources current sources))
  (make-generation (lambda (random size)
    (selected-sample (with-sources observed (select size)) random size observed)) observed))
;; Size overrides are explicit natural values, not descriptor-budget overrides.
(def (generator-resize generator size)
  (unless (and (generator? generator) (exact-integer? size) (>= size 0)) (error "invalid generator size" size))
  (make-generation (lambda (random _) (generate generator random size)) (generation-sources generator)))
;; Scale always uses its known input. Sized owns its leaves directly, avoiding
;; a replacement descriptor or another callback wrapper around the same run.
(def (generator-scale generator (scale : :procedure) current?: (current immutable-current))
  (generator-sized (lambda (size) (generator-resize generator (scale size)))
    current?: current sources: (generation-sources generator)))
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
    (parameterize ((current-delay-budget (1- fuel))) (selected-sample (with-sources sources (construct)) random size sources))) sources))
;; Prune rejected branches, yielding a charged tombstone rather than searching
;; descendants invisibly. Predicates never receive already rejected proposals.
(def (filter-sample tree predicate sources)
  (def observed (merge-sources sources (proposal-owned-sources tree)))
  (with-sources observed
    (if (rejected? tree) (make-rejected observed)
      (let (accepted? (boolean-result (predicate (sample-value tree)) "filter must return a boolean"))
        (if accepted?
          (make-sample-node (sample-value tree)
            (lambda () (in-coroutine (lambda (yield)
              (for-sources (child ((sample-children tree)) observed)
                (yield (filter-sample child predicate observed)))))) observed)
          (make-rejected observed))))))
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
      ;; Earlier rejected branches remain owners of every later draw/selector,
      ;; not just its final predicate. The shared scope unwinds on every exit.
      (def tree (with-sources observed (generate generator random size)))
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
;; Prepare the nearest-to-zero inhabitant once. False denotes an omitted bound,
;; never a numeric fallback; reversed finite endpoints are configuration errors.
(def (integer-range-anchor lower upper)
  (unless (and (or (not lower) (exact-integer? lower))
               (or (not upper) (exact-integer? upper))
               (or (not lower) (not upper) (<= lower upper)))
    (error "ordered optional exact integer bounds required" lower upper))
  (cond ((and lower (> lower 0)) lower) ((and upper (< upper 0)) upper) (else 0)))
;; Shrink distance on the same side of the captured anchor. Every proposal stays
;; on that closed segment, without filtering, wrapping arithmetic or resampling.
(def (integer-range-shrinks (anchor :~ exact-integer?) (value :~ exact-integer?))
  (map (if (< value anchor) (lambda (distance) (- anchor distance))
                              (lambda (distance) (+ anchor distance)))
    (integer-shrinks (abs (- value anchor)))))
;; Size bounds distance from the anchor, including one-sided/unbounded ranges.
;; Each primitive draw therefore spans at most 2*size+1 values, not the entire
;; bignum representation. The original with-shrink owner retains tree provenance.
(def (generator-integer-range lower upper)
  (def anchor (integer-range-anchor lower upper))
  (generator-with-shrink
    (generator-sized (lambda (size)
      (generator-integer (if lower (max lower (- anchor size)) (- anchor size))
                         (if upper (min upper (+ anchor size)) (+ anchor size)))))
    (cut integer-range-shrinks anchor <>)))
;; Scheme's finite inexact rationals also have an exact numeric value. This
;; canonical rank is natural, symmetric in sign, and independent of input spelling.
;; It does not measure floating-point representation, rounding error or byte cost.
(def (rational-weight (value :~ rational?))
  (def exact (inexact->exact value))
  (+ (abs (numerator exact)) (denominator exact) -1))
;; Shrink canonical numerator and positive denominator independently, normalize
;; with standard division, then retain only strict canonical-rank reductions.
;; The same value policy serves typed callbacks and the generic lazy tree.
(def (rational-shrinks (value :~ rational?))
  (def exact (inexact->exact value))
  (def n (numerator exact)) (def d (denominator exact))
  (def weight (rational-weight exact))
  (filter (lambda (candidate) (< (rational-weight candidate) weight))
    (delete-duplicates/hash
      (append (map (lambda (smaller) (/ smaller d)) (integer-shrinks n))
        (map (lambda (smaller) (/ n (1+ smaller))) (integer-shrinks (1- d)))))))
;; Generate exact ratios through the existing product/size algebra. Size bounds
;; numerator magnitude and denominator growth; the explicit positive cap remains
;; in force under resize. Zero size is exactly zero, and no denominator can be zero.
(def (generator-rational max-denominator: (limit 128))
  (unless (and (exact-integer? limit) (> limit 0)) (error "positive rational denominator limit required"))
  ;; Immutable sign metadata is shared; invocation-owned randomness is not cached.
  (def sign (generator-elements '(-1 1)))
  (generator-with-shrink
    (generator-sized (lambda (size)
      (generator-map (generator-sequence
        (list (generator-integer 0 size) sign
          (generator-integer 1 (min limit (1+ size)))))
        (lambda (parts) (/ (* (car parts) (cadr parts)) (caddr parts))))))
    rational-shrinks))
;; A declared finite order supplies simplification ranks. Capture its spine once;
;; map retains index preimages, including distinct positions with equal payloads.
;; No equality search, random redraw or application-specific value ordering is added.
(def (generator-elements choices current?: (current immutable-current))
  (unless (and (list? choices) (pair? choices)) (error "nonempty finite choices required"))
  (def domain (list->vector choices))
  (generator-map
    (make-generator (lambda (random _size) (random (vector-length domain)))
      integer-shrinks current?: current)
    (cut vector-ref domain <>)))
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
;; The private deletion policy traverses an already owned finite spine. Sharing
;; this algorithm lets both public policies copy once before any callback runs.
;; Retained payloads keep their identities and declared source obligations.
(def (sequence-deletions owned minimum)
  (def size (length owned))
  (list-deletion-count size minimum)
  (in-coroutine (lambda (yield)
    (let sizes ((width (- size minimum)))
      (unless (zero? width)
        (for (start (in-range 0 (1+ (- size width)) width))
          (yield (append (take owned start) (drop owned (+ start width)))))
        (sizes (quotient width 2)))))))
;; Snapshot the caller-owned spine before exposing the lazy iterator. Minimum
;; constrains length rather than privileging any particular retained prefix.
(def (list-deletions values minimum)
  (using (values :~ list?) (sequence-deletions (list-copy values) minimum)))
;; The whole finite policy owns ONE input spine before any parameter callback.
;; Both structural and coordinate phases read that snapshot, even if a callback
;; edits the caller's list. Parameter lists still require whole-spine admission;
;; no partial batch escapes on refusal, and arbitrary payloads are not copied.
(def (data-list-shrinks values (shrink : :procedure) minimum)
  (using (values :~ list?)
    (def owned (list-copy values))
    (def structural (for/collect (candidate (sequence-deletions owned minimum)) candidate))
    (append structural
      (let coordinates ((tail owned) (before []))
        (if (null? tail) []
          (using (children (with-sources [] (shrink (car tail))) :~ list?)
            (append (map (lambda (value) (append (reverse before) (cons value (cdr tail)))) children)
              (coordinates (cdr tail) (cons (car tail) before)))))))))
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
      (make-sample-node (with-sources observed (pack (map sample-value trees)))
        (lambda () (in-coroutine (lambda (yield)
          (require-sources! observed)
          (for (smaller (list-deletions trees minimum)) (yield (sequence smaller observed)))
          (let coordinates ((tail trees) (before []))
            (unless (null? tail)
              (for-sources (child ((sample-children (car tail))) observed)
                (yield (sequence (append (reverse before) (cons child (cdr tail))) observed)))
              (coordinates (cdr tail) (cons (car tail) before))))))) observed)))
  (sequence (list-copy samples) inherited))
;; Capture each root as a value without forcing its descendants. Wrapping does
;; not split or consume randomness, so the existing sequence draw schedule survives.
(def (sampled-generator generator)
  (make-generation (lambda (random size)
    (let (tree (generate generator random size))
      (make-sample-node tree (lambda () []) (sample-node-sources tree)))) (generation-sources generator)))
;; Length is chosen once. Structural shrinking deletes retained trees rather
;; than regenerating payloads under a shorter length's dependent seed. Positive
;; minimum makes the element a mandatory participant before any length draw.
(def (generator-list element min-length: (minimum 0) max-length: (maximum 128))
  (unless (and (generator? element) (exact-integer? minimum) (exact-integer? maximum)
               (<= 0 minimum maximum)) (error "invalid sequence generator bounds"))
  (generator-sized (lambda (size)
    (generator-bind (generator-no-shrink (generator-integer minimum (+ minimum (min size (- maximum minimum)))))
      (lambda (count)
        (def row (sampled-sequence (make-list count element)))
        (make-tree-generator (lambda (random size)
          (let (tree (generate row random size))
            (sample-sequence (sample-value tree) min-length: minimum sources: (sample-sources tree))))))))
    sources: (if (positive? minimum) (generation-sources element) [])))
;; Finite key domains use the same equality as Gerbil's ordinary HashTable.
;; Validate uniqueness once; fixed-key structural/value shrinking cannot collide.
(def (generator-hash keys value-generator domain-limit: (limit 256) current?: (current immutable-current))
  (unless (and (list? keys) (generator? value-generator) (exact-integer? limit) (>= limit 0)
    (<= (length keys) limit)) (error "invalid finite hash domain"))
  (def domain (list-copy keys))
  (def seen (make-hash-table seed: 0))
  (for (key domain)
    (when (hash-key? seen key) (error "duplicate finite hash key" key))
    (hash-put! seen key #t))
  (make-generation (lambda (random size)
    ;; Consider every key, then cap selected rows by size. No value is drawn for
    ;; absent keys; size zero neither samples keys nor invokes value producers.
    (def selected (if (zero? size) []
      (let (active (filter (lambda (_) (zero? (random 2))) domain))
        (take active (min size (length active))))))
    (def row (sampled-sequence (map (lambda (key)
      (generator-map value-generator (lambda (value) (cons key value)))) selected)))
    (let (tree (generate row random size))
      (sample-sequence (sample-value tree) (lambda (entries) (list->hash-table entries seed: 0)) sources: (sample-sources tree))))
    (observer-sources current [])))
;; Standard Scheme carriers are mapped once; shrinking keeps the hidden list tree.
(def (generator-string (character (generator-character)) min-length: (minimum 0) max-length: (maximum 128))
  (generator-map (generator-list character min-length: minimum max-length: maximum) list->string))
;; Symbols are interned spellings, including empty and reader-sensitive spellings.
;; No gensyms, identifier grammar or module-name interpretation is inferred.
(def (generator-symbol (character (generator-character)) min-length: (minimum 0) max-length: (maximum 128))
  (generator-map (generator-string character min-length: minimum max-length: maximum) string->symbol))
;; Keywords reuse exactly the same spelling tree as strings and symbols. The
;; standard intern operation gives data, not an instruction to parse a call row.
(def (generator-keyword (character (generator-character)) min-length: (minimum 0) max-length: (maximum 128))
  (generator-map (generator-string character min-length: minimum max-length: maximum) string->keyword))
;; Mutable byte vectors are freshly packed at each mapped node, never encoded as text.
(def (generator-bytes min-length: (minimum 0) max-length: (maximum 128))
  (generator-map (generator-list (generator-byte) min-length: minimum max-length: maximum) list->u8vector))

;; Finite functions store raw argument rows and result tuples, not opaque closures.
(defstruct function-value (entries current) final: #t)
;; All finite observations share the existing transient/retained source boundary.
;; The form adds no stored wrapper or guard chain to the function's table.
(defrule (with-function value body ...)
  (with-sources (list (function-value-current value)) body ...))
;; Domain inspection returns fresh spines only under current call-site and table
;; authority; callers still own the declared dependencies of mutable payloads.
(def (function-domain value)
  (with-function value
    (map (lambda (entry) (map identity (car entry))) (function-value-entries value))))
;; Unknown rows are refused explicitly; repeated equal rows select the same tuple.
(def (function-apply value arguments)
  (with-function value
    (def entry (assoc arguments (function-value-entries value)))
    (unless entry (error "arguments outside finite function domain" arguments))
    (map identity (cdr entry))))
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
          (for-sources (child ((sample-children tree)) (sample-node-sources tree))
            (yield (function-tree child rows current))))))
        (sample-node-sources tree)))))
;; The finite row boundary is shared by generators and portable table restoration.
(def (function-rows rows limit)
  (unless (and (list? rows) (every list? rows) (exact-integer? limit) (>= limit 0)
    (<= (length rows) limit) (= (length rows) (length (delete-duplicates/hash rows))))
    (error "invalid finite function domain" rows))
  (map (cut map identity <>) rows))
;; Export fresh row/result spines; payload ownership remains the declared source law.
(def (function-table value)
  (with-function value
    (map (lambda (entry) (cons (map identity (car entry)) (map identity (cdr entry))))
      (function-value-entries value))))
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
    (function-tree (generate tuples random size) domain current)) current?: current
    sources: (generation-sources tuples)))
