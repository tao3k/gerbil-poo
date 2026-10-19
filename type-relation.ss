;;; Finite structural Type expressions; no nominal-inheritance implication.
(export capture-type-catalog function-covers? function-signatures type-refusal? type-refusal-kind refuse-type bounded-type-data type-work scalar-recognizer type-constructor? type-expression substitute-type subtype-expression? subtype/checked? expression-type compile-expression normalize-type function-options function-expression function-template copy-type canonical-type)
(import (only-in :std/hash/misc hash-ensure-ref)
        (only-in :std/list/list append-map map-in-order) (prefix-in ./function-signature signature.) ./type-syntax ./recursive-types ./object
        (only-in ./mop Any Bool Function CaseFunction Type. Object Class.)
        (only-in ./object-contract ObjectContract.)
        (only-in ./optional-validation type-value-catalog capture-type-values
                 catalog-type? catalog-current! catalog-descriptor catalog-contract)
        (only-in ./number Integer UInt IntegerRange UIntN IntN UInt256 JsInt)
        (only-in ./type TypeValuePair first-index-hash<-vector List Tuple Maybe OrFalse Pair Map Sum Union RecordSlot String Symbol Keyword Null Unit Bytes BytesN Bytes32 Bytes64 Exactly Enum.))

;; Bottom has no inhabitants. Crossing a finite recursive approximation boundary
;; is ordinary type refusal, not work exhaustion or evidence of global emptiness.
(def Never (.cc Type. sexp: 'Never .element?: (lambda (_) #f)))

;; Snapshot explicitly named computed Class/Schema Types through ordinary POO
;; getters. Tokens remain local to this capture; no global registry is installed.
(def (capture-type-catalog provider names (budget 8192) sources: (sources []))
  (capture-type-values provider names sources (type-work budget) refuse-type))

;; Expand only explicit guarded Mu and splice explicit Object row substitutions.
;; Disjointness/kind failures invalidate an assignment; exhaustion always escapes.
(def (normalize-type term work)
  (work)
  (cond ((not (pair? term)) term)
        ((eq? (car term) 'Mu) (normalize-type (unfold-type term work) work))
        ((eq? (car term) 'Object)
         (let* ((fields (map (lambda (field) (list (car field) (normalize-type (cadr field) work))) (cadr term)))
                (tail (caddr term)))
           (if (memq tail '(open closed)) (list 'Object fields tail)
             (let (row (normalize-type (cadr tail) work))
               (unless (and (pair? row) (eq? (car row) 'Object))
                 (refuse-type 'bounds "Row substitution requires an Object Type"))
               (when (ormap (lambda (field) (assq (car field) fields)) (cadr row))
                 (refuse-type 'bounds "Row substitution overlaps explicit fields"))
               (list 'Object (append fields (cadr row)) (caddr row))))))
        (else (map-type-children term (cut normalize-type <> work) #t))))

;; Select a declared Function through explicit Object fields. An unresolved row
;; tail or Type variable cannot invent a named signature before substitution.
;; Callers validate syntax with their own variable set before this shared walk.
(def (function-expression expression path work (missing 'unsupported))
  (bounded-type-data path work)
  (unless (and (list? path) (andmap symbol? path))
    (refuse-type 'malformed "Signature path must contain field names" path))
  (let walk ((term expression) (path path))
    (work)
    (def current (if (and (pair? term) (eq? (car term) 'Mu)) (normalize-type term work) term))
    (if (null? path)
      (begin
        (unless (and (pair? current) (memq (car current) '(Function CaseFunction)))
          (refuse-type missing "Signature path does not name a concrete Function" path))
        current)
      (let (field (and (pair? current) (eq? (car current) 'Object) (assq (car path) (cadr current))))
        (unless field (refuse-type missing "Signature path needs explicit Object fields" path))
        (walk (cadr field) (cdr path))))))

;; Return a known signature template, or #f when substitution can decide the
;; path's kind/layout. Literal names are not variables: capture-free substitution
;; detects only actual Type positions. Fixed absent paths still refuse up front.
;; Candidate projection later uses function-expression with bounds refusal.
(def (function-template expression path variables work)
  (bounded-type-data path work)
  (unless (and (list? path) (andmap symbol? path))
    (refuse-type 'malformed "Signature path must contain field names" path))
  ;; A private false marker detects free Type parameters without unfolding Mu.
  (def (dependent? term)
    (not (equal? term (substitute-type term (map (lambda (name) (cons name #f)) variables) work))))
  (let walk ((term expression) (remaining path))
    (work)
    (cond
      ((memq term variables) #f)
      ((and (pair? term) (eq? (car term) 'Mu))
       (if (dependent? term) #f (walk (normalize-type term work) remaining)))
      ((null? remaining) (function-expression term [] work))
      ((and (pair? term) (eq? (car term) 'Object))
       (let (field (assq (car remaining) (cadr term)))
         (cond (field (walk (cadr field) (cdr remaining)))
               ((pair? (caddr term))
                (if (dependent? (cadr (caddr term))) #f
                  (walk (normalize-type term work) remaining)))
               (else (refuse-type 'unsupported "Signature path needs a declared field" remaining)))))
      (else (refuse-type 'unsupported "Signature path needs Object fields" remaining)))))

;; Decide derivability in the closed algebra: UInt <: Integer <: Any; Bool <: Any;
;; covariant List/Tuple observations; covered Function inputs contravariant,
;; outputs covariant, with exact multiple-value counts. False means no rule here,
;; not a counterexample to arbitrary predicate inclusion or mutable-slot writes.
(def (subtype-expression? source target (budget 8192))
  (subtype/checked? source target (type-work budget)))

;; Recursive comparisons share their caller's quota, including inference search.
;; This is exported only through the main judgment above; no active-pair success
;; shortcut admits recursive types, CaseFunction shadowing or opaque predicates.
(def (subtype/checked? source target work)
  ;; Substitution can introduce new Mu nesting: recheck the complete ground terms.
  (type-expression source [] work) (type-expression target [] work)
  (compare-types (normalize-type source work) (normalize-type target work) work))

;; Numeric families reuse literal bounds, independent of mutable Type methods.
;; A false result means nonnumeric; a pair of false bounds means all integers.
(def (numeric-bounds term)
  (case term ((Integer) (cons #f #f)) ((UInt) (cons 0 #f))
    (else (let (term (or (descriptor-alias term) term)) (and (pair? term)
      (case (car term) ((IntegerRange) (range-bounds term))
        ((UIntN IntN) (fixed-integer-bounds term)) (else #f)))))))
;; Empty ranges are numeric bottom, not work failure or a universal fallback.
(def (empty-range? bounds)
  (and (car bounds) (cdr bounds) (> (car bounds) (cdr bounds))))
;; Symbolic inclusion compares at most two exact endpoints, never enumerating
;; inhabitants. Nonnumeric families are deliberately outside this rule.
(def (numeric-subtype? source target)
  (def left (numeric-bounds source)) (def right (numeric-bounds target))
  (and left right
    (or (empty-range? left)
      (and (or (not (car right)) (and (car left) (<= (car right) (car left))))
           (or (not (cdr right)) (and (cdr left) (<= (cdr left) (cdr right))))))))
;; A finite literal target covers a range only when every integer is present.
;; Reject unbounded/oversized intervals before reusing Enum's first-index table;
;; duplicate and noninteger literals cannot fill holes. Charge preparation and
;; every visited integer to the existing shared quota, never to endpoint size.
(def (range-literals-subtype? source values work)
  (def bounds (numeric-bounds source))
  (and bounds
    (or (empty-range? bounds)
      (and (car bounds) (cdr bounds)
        (<= (1+ (- (cdr bounds) (car bounds))) (length values))
        (begin
          (for-each (lambda (_) (work)) values)
          (let (index (first-index-hash<-vector (list->vector values)))
            (let loop ((value (car bounds)))
              (work)
              (or (> value (cdr bounds))
                  (and (hash-key? index value) (loop (1+ value)))))))))))
;; Intrinsic flat validators preserve values. Source admission stays separate
;; from token transport; public Union-to-Union descriptor identity is invariant.
(def (flat-type? term)
  (if (pair? term)
    (case (car term) ((Exactly Enum IntegerRange UIntN IntN BytesN) #t) ((Union) (andmap flat-type? (cdr term))) (else #f))
    (and (scalar-recognizer term) #t)))
;; Numeric families share their symbolic interval view; Bool has exactly two
;; intrinsic values. String/Symbol/Keyword require a same-family flat branch;
;; finite literals cannot cover their infinite domains. Other finite literal
;; sources still require keyword stability.
;; No descriptor kind is collapsed.
;; Keyword/escape transport, ordered Union identity and wrapper admission retain
;; their existing judgments; coverage does not execute user recognizers.
(def (flat-union-source? source work)
  (or (and (memq source '(Bool String Symbol Keyword Null Unit Bytes Bytes32 Bytes64)) #t) (and (numeric-bounds source) #t)
      (and (pair? source) (eq? (car source) 'BytesN))
      (and (pair? source) (memq (car source) '(Exactly Enum))
           (keyword-stable-type? source work))))
;; Project numeric coverage without altering the ordered descriptor tree.
;; Preserve unbounded endpoints; literal integers become singleton pieces.
;; Other admitted flat scalars contain no integers. No user recognizer executes.
(def (union-range-pieces term work)
  (work)
  (cond ((numeric-bounds term) => (lambda (bounds)
          (list bounds)))
        ((pair? term)
         (case (car term)
           ((Union) (append-map (cut union-range-pieces <> work) (cdr term)))
           ((Exactly Enum) (append-map (lambda (value) (work)
             (if (exact-integer? value) (list (cons value value)) [])) (cdr term)))
           (else [])))
        (else [])))
;; Subtract one closed integer interval, retaining at most two ordered residuals.
;; False lower/upper endpoints mean negative/positive infinity. Only finite
;; endpoints are shifted; empty/disjoint covers change nothing.
(def (subtract-range source covered)
  (def lower (car source)) (def upper (cdr source))
  (def left (car covered)) (def right (cdr covered))
  (if (or (empty-range? covered) (and upper left (< upper left))
          (and right lower (< right lower))) (list source)
    (append (if (and left (or (not lower) (< lower left)))
              (list (cons lower (1- left))) [])
            (if (and right (or (not upper) (< right upper)))
              (list (cons (1+ right) upper)) []))))
;; Accumulate uncovered pieces using Gerbil's ordered fold/append-map protocol.
;; Work depends on descriptor pieces, never the number of integers in a range.
;; Preparation and every residual visit share the original quota; exhaustion
;; escapes as a refusal and cannot be mistaken for a gap or complete coverage.
(def (range-union-subtype? source branches work)
  (def bounds (numeric-bounds source))
  (and bounds
    (or (empty-range? bounds)
      (null? (foldl (lambda (covered remaining)
        (append-map (lambda (piece) (work) (subtract-range piece covered)) remaining))
        (list bounds)
        (append-map (cut union-range-pieces <> work) branches))))))
;; Decide singleton inclusion without executing a user predicate or constructor.
(def (literal-in-type? value term work)
  (work)
  (cond ((scalar-recognizer term) => (lambda (recognize) (recognize value)))
        (else (and (pair? term)
          (case (car term)
            ((IntegerRange UIntN IntN)
             (let (bounds (numeric-bounds term))
               (and (exact-integer? value) (or (not (car bounds)) (<= (car bounds) value))
                    (or (not (cdr bounds)) (<= value (cdr bounds))))))
            ((Exactly) (equal? value (cadr term)))
            ((Enum) (and (member value (cdr term)) #t))
            ((Union) (ormap (cut literal-in-type? value <> work) (cdr term)))
            (else #f))))))
;; Bytes validation is identity-preserving; mutable contents never enter literal
;; metadata or a value cache. Only the carrier and immutable vector length matter.
(def (byte-type? term)
  (or (and (memq term '(Bytes Bytes32 Bytes64)) #t)
      (and (pair? term) (eq? (car term) 'BytesN))))
;; Finite fixed-length branches cover a fixed source only at that same length.
;; An unbounded Bytes source requires a whole Bytes branch; no finite length list
;; can cover every vector. Ordered target traversal remains the shared flat rule.
(def (byte-subtype? source target work)
  (def left (or (descriptor-alias source) source))
  (def right (or (descriptor-alias target) target))
  (cond ((eq? right 'Bytes) #t)
        ((and (pair? right) (eq? (car right) 'BytesN))
         (and (pair? left) (= (cadr left) (cadr right))))
        ((and (pair? target) (eq? (car target) 'Union))
         (ormap (cut flat-subtype? source <> work) (cdr target)))
        (else #f)))
;; Inclusion distributes only over the proven identity-preserving flat fragment.
;; An explicit Any source still cannot replace a narrower field or signature.
(def (flat-subtype? source target work)
  (work)
  (cond ((equal? source target) #t)
        ((or (eq? source 'Never) (eq? target 'Any)) #t)
        ;; The private finite view reuses literal membership without rewriting
        ;; the public Bool descriptor or interpreting false as missing data.
        ((eq? source 'Null) (literal-in-type? [] target work))
        ((eq? source 'Unit) (literal-in-type? (void) target work))
        ((byte-type? source) (byte-subtype? source target work))
        ((eq? source 'Bool) (flat-subtype? '(Enum #f #t) target work))
        ((and (pair? source) (eq? (car source) 'Union))
         (andmap (cut flat-subtype? <> target work) (cdr source)))
        ((and (pair? source) (memq (car source) '(Exactly Enum)))
         (andmap (cut literal-in-type? <> target work) (cdr source)))
        ((and (pair? target) (memq (car target) '(Exactly Enum)))
         (range-literals-subtype? source (cdr target) work))
        ((and (pair? target) (eq? (car target) 'Union))
         (or (ormap (cut flat-subtype? source <> work) (cdr target))
             (range-union-subtype? source (cdr target) work)))
        (else (numeric-subtype? source target))))

;; Object fields are required; Record fields carry explicit presence metadata.
;; Syntax admission already rejects duplicate names and unknown presence markers.
(def (field-required? field)
  (or (null? (cddr field)) (eq? (caddr field) 'required)))

;; Decide only witnessed emptiness of admitted, normalized finite data Types.
;; Products need one impossible mandatory child; alternatives need every child
;; impossible. Empty List/Map, void/false sentinels, optional fields and procedures
;; remain inhabited or unknown. No mutable descriptor/user predicate is invoked.
;; Shared work is charged even for a negative result; Mu means only its explicit
;; finite approximant, never a claim about an unrestricted recursive fixed point.
(def (empty-type? term work)
  (work)
  (cond ((eq? term 'Never) #t)
        ((not (pair? term)) #f)
        (else
          (case (car term)
            ((Enum) (null? (cdr term)))
            ((IntegerRange) (empty-range? (range-bounds term)))
            ((Tuple Pair) (ormap (cut empty-type? <> work) (cdr term)))
            ((Union) (andmap (cut empty-type? <> work) (cdr term)))
            ((Sum) (let loop ((entries (cdr term)))
                     (or (null? entries)
                         (and (empty-type? (cadr entries) work) (loop (cddr entries))))))
            ((Object Record) (ormap (lambda (field)
                              (work)
                              (and (field-required? field) (empty-type? (cadr field) work)))
                              (cadr term)))
            (else #f)))))

;; Descriptor identity is independent of inhabitants: direct Sum/Union sources
;; retain their tag/branch protocol. Other failed comparisons may use a witnessed
;; empty source without rewriting its descriptor kind, fields or callback Types.
(def (empty-replacement? source target work)
  (and (not (and (pair? source) (memq (car source) '(Union Sum))))
       (or (not (and (pair? target) (eq? (car target) 'Union))) (flat-type? target))
       (empty-type? source work)))

;; Standard symbol-keyed tables index admitted immutable field declarations.
;; Charge the shared quota before inserting each name; never evaluate a Slot.
(def (field-index fields work)
  (list->hash-table-eq (map-in-order (lambda (field)
    (work) (cons (car field) field)) fields)))

;; One observational protocol for Object rows and required/optional Record slots.
;; Closed targets require a closed source with no extra declared key. Missing
;; optional targets are safe only for closed sources: an open source could hide
;; that name with an incompatible value. Supplied fields retain readable variance;
;; this rule grants neither mutable writes nor arbitrary callback implication.
(def (row-related? source target relate work)
  (def left (field-index (cadr source) work))
  (def right (field-index (cadr target) work))
  (def closed? (eq? (caddr source) 'closed))
  (and (or (eq? (caddr target) 'open)
           (and closed? (andmap (lambda (field) (work) (hash-key? right (car field))) (cadr source))))
    (andmap (lambda (expected)
      (work)
      (cond ((hash-get left (car expected)) =>
             (lambda (actual)
               (and (or (not (field-required? expected)) (field-required? actual))
                    (relate (cadr actual) (cadr expected)))))
            (else (and closed? (not (field-required? expected)))))) (cadr target))))

;; Compare normalized finite terms; every required target field must be present.
;; Open source rows leave undeclared fields unconstrained; closed targets exclude extras.
(def (compare-types source target work)
  (work)
  (or (cond
   ((equal? source target) #t)
   ((or (eq? target 'Any) (eq? source 'Never)) #t)
   ;; Null and the empty Tuple share their sole list value, not descriptor keys.
   ((or (and (eq? source 'Null) (equal? target '(Tuple)))
        (and (equal? source '(Tuple)) (eq? target 'Null))) #t)
   ;; Optional sentinel inclusion never changes Function wrapping or calls.
   ((and (memq source '(Null Unit)) (pair? target) (memq (car target) '(Maybe OrFalse)))
    (or (and (eq? source 'Unit) (eq? (car target) 'Maybe))
        (compare-types source (cadr target) work)))
   ((and (flat-type? source) (flat-type? target)
         (not (and (pair? source) (eq? (car source) 'Union)))
         (or (not (and (pair? target) (eq? (car target) 'Union)))
             (flat-union-source? source work)))
    (flat-subtype? source target work))
   ((and (pair? source) (pair? target)
         (memq (car source) '(Function CaseFunction)) (memq (car target) '(Function CaseFunction)))
    (function-replaces? source target work))
   ((and (pair? source) (pair? target) (eq? (car source) (car target)))
    (case (car source)
      ((List Maybe OrFalse Tuple Pair)
       (and (= (length source) (length target))
            (andmap (lambda (s t) (compare-types s t work)) (cdr source) (cdr target))))
      ;; Keys are invariant after finite normalization: changing their validator
      ;; could change identity/equality or create a collision. Values are readable.
      ((Map) (and (equal? (cadddr source) (cadddr target))
                  (compare-types (cadr source) (cadr target) work)))
      ;; Catalog membership is descriptor identity, not payload covariance:
      ;; UInt's Type object never becomes Integer's Type object. Source order
      ;; remains metadata, even when set inclusion permits readable replacement.
      ((TypeValuePair)
       (andmap (lambda (name) (work) (and (memq name (cdr target)) #t)) (cdr source)))
      ;; Equal tag skeletons retain wire order and selected payload identity.
      ((Sum)
       (let loop ((left (cdr source)) (right (cdr target)))
         (work)
         (cond ((null? left) (null? right))
               ((null? right) #f)
               (else (and (eq? (car left) (car right))
                          (compare-types (cadr left) (cadr right) work)
                          (loop (cddr left) (cddr right)))))))
      ;; Union equality was handled above. No widening, sorting, deduplication or
      ;; branchwise covariance may change committed first-match normalization.
      ((Union) #f)
      ;; Class/Slot and ObjectContract keep their distinct runtime validators;
      ;; their finite field-coverage judgment uses the same named-row protocol.
      ((Record Object) (row-related? source target (cut compare-types <> <> work) work))
      (else #f)))
   (else #f))
    (empty-replacement? source target work)))

;; Project raw Type positions to the EXISTING shape selector/argument normalizer.
;; These temporary objects are shape views, not new Types or dispatch certificates.
(def (signature-view term)
  (call-with-function-types term
    (lambda (outputs inputs optional keywords required rest)
      (.o bind-these: #f outputs: outputs inputs: inputs optional: optional
        keywords: keywords required-keywords: required rest: rest))))

;; Shared structural views feed inference and coverage through the same existing
;; Function selector/normalizer. They do not construct Types or certificates.
(def (function-signatures term)
  (map-in-order signature-view (if (eq? (car term) 'Function) (list term) (cdr term))))

;; Recognized ground Types exclude outer keyword/escape tokens without calling
;; user recognizers. Containers keep their outer carrier even when their payload
;; is Any; Maybe/OrFalse and Union can expose payloads, so inspect those alternatives.
;; Mu has already undergone the existing finite normalization/admission guard.
(def (keyword-stable-type? term work)
  (work)
  (cond ((catalog-type? term) #f)
        ((scalar-recognizer term) =>
         (lambda (recognize)
           (not (or (recognize mode:) (recognize #!key) (recognize #!rest)))))
        (else (case (car term)
          ((IntegerRange UIntN IntN BytesN) #t)
          ((Exactly Enum) (andmap (lambda (value) (not (or (keyword? value) (eq? value #!key) (eq? value #!rest)))) (cdr term)))
          ((Maybe OrFalse) (keyword-stable-type? (cadr term) work))
          ((Union) (andmap (cut keyword-stable-type? <> work) (cdr term)))
          ((List Tuple Pair TypeValuePair Map Sum Record Object Function CaseFunction) #t)
          (else #f)))))

;; Only the raw transport judgment uses extensional flat-origin inclusion:
;; identity validators cannot alter earlier branch wrapping or normalization.
;; Literal token origins keep their public guard. Scalar family coverage is
;; value inclusion, not permission to erase wire origins or change Union order.
(def (raw-origin-subtype? source target work)
  (if (and (flat-type? source) (flat-type? target))
    (flat-subtype? source target work) (compare-types source target work)))

;; Restrict ordinary (unescaped) data to values the keyword decoder can read as
;; data. Exactly/Enum/Keyword are decided extensionally; no user recognizer runs.
;; Flat Union alternatives are identity validators, so removing token-only arms
;; preserves their ordinary values. Opaque/wrapper-bearing carriers stay bounded
;; overapproximations. Explicit Any remains explicit; no complement is invented.
(def (ordinary-origin type work)
  (work)
  (case type
    ((Keyword) 'Never)
    (else (if (not (pair? type)) type
      (case (car type)
        ((Exactly Enum)
         (let (values (filter (lambda (value)
                        (not (or (keyword? value) (eq? value #!key) (eq? value #!rest)))) (cdr type)))
           (if (null? values) 'Never (cons (car type) values))))
        ((Union)
         (if (not (flat-type? type)) type
           (let (types (filter (lambda (child) (not (eq? child 'Never)))
                        (map (cut ordinary-origin <> work) (cdr type))))
             (cond ((null? types) 'Never) ((null? (cdr types)) (car types))
                   (else (cons 'Union types))))))
        ((Maybe OrFalse) (list (car type) (ordinary-origin (cadr type) work)))
        (else type))))))

;; Only decidably empty finite scalar alternatives are removed. Unknown host
;; carriers remain potentially inhabited; an unsupported proof cannot erase them.
(def (empty-origin? type)
  (or (eq? type 'Never)
      (and (pair? type)
        (case (car type) ((Enum) (null? (cdr type)))
          ((IntegerRange) (empty-range? (range-bounds type)))
          ((Union) (andmap empty-origin? (cdr type))) (else #f)))))

;; Private graph edges retain ordered origin Types, including exact marker Types.
;; States are standard equal?-hashed lists (position, keys, raw offset, rest mode).
(defstruct raw-edge (next origins) final: #t)

;; Explore a finite directed graph with the arrow/target protocol used by
;; std/struct/dag. Unlike walk-dag, this worklist admits cycles: an explored node
;; records outgoing arrows, never a successful subtype result. Each pop consumes
;; the caller's quota; the whole request-local graph is discarded on exhaustion.
(def (raw-reachable starts arrows target work)
  (def visited (make-hash-table))
  (let visit ((pending starts))
    (unless (null? pending)
      (work)
      (let (node (car pending))
        (if (hash-key? visited node) (visit (cdr pending))
          (let (outgoing (arrows node))
            (hash-put! visited node outgoing)
            (visit (foldr (lambda (arrow tail) (cons (target arrow) tail))
                     (cdr pending) outgoing)))))))
  visited)

;; Construct the decoder/arity product, its reverse arrows and legal endings.
;; Exact and saturated counters share this grammar; no subtype is admitted here.
(def (raw-graph expected row raw-count limits work)
  (def positions (list->vector (car row)))
  (def position-count (vector-length positions))
  (def bounded-positions? (<= position-count (cdr limits)))
  (def bounded-raw? (<= raw-count (car limits)))
  (def initial (list 0 (cdr row) 0 #f))
  (def predecessors (make-hash-table))
  (def ordinary (make-hash-table))
  (def endings [])
  ;; At the saturated decoded position, only the target's declared rest repeats.
  (def (position-type index)
    (if (< index position-count) (vector-ref positions index) (.get expected rest)))
  ;; Cache only completed ordinary restrictions, including an explicit Never.
  (def (ordinary-type type)
    (hash-ensure-ref ordinary type (cut ordinary-origin type work)))
  ;; Necessary exact-region bounds prune unreachable suffix sizes early. Rest
  ;; mode has no further keyword interpretation, hence exactly one token/value.
  (def (feasible? position keys offset rest?)
    (work)
    (and (or (not bounded-raw?) (<= offset raw-count))
      (or (not bounded-positions?)
        (let ((remaining (- position-count position)) (raw-left (- raw-count offset)))
          (and (>= remaining 0)
            (if bounded-raw?
              (if rest? (= raw-left remaining)
                (and (<= (+ remaining (* 2 (length keys))) raw-left)
                     (<= raw-left (+ (* 2 remaining) (* 2 (length keys)) 1))))
              (>= (+ offset (if rest? remaining
                           (+ (* 2 remaining) (* 2 (length keys)) 1))) raw-count)))))))
  ;; Emit the exact one/two-token prefix and its counter successor, or no edge.
  (def (edge position keys offset rest? origins)
    (def next-offset (+ offset (length origins)))
    (and (feasible? position keys next-offset rest?)
      (make-raw-edge
        (list position keys (if bounded-raw? next-offset (min raw-count next-offset)) rest?) origins)))
  ;; Enumerate decoder alternatives using the existing supplied key/Type pairs.
  ;; Literal token payloads may occur after key/rest escape but never ordinary.
  (def (successors state)
    (match state
      ([position keys offset rest?]
       (def type (and (or (< position position-count) (not bounded-positions?)) (position-type position)))
       (def next-position (min position-count (1+ position)))
       (def data? (and type (not (empty-origin? type))))
       (filter identity
         (if rest?
           (if data? (list (edge next-position keys offset #t (list type))) [])
           (append
             (if data?
               (let (plain (ordinary-type type))
                 (list (and (not (empty-origin? plain)) (edge next-position keys offset #f (list plain)))
                       (edge next-position keys offset #f (list '(Exactly #!key) type)))) [])
             (map (lambda (entry)
               (and (not (empty-origin? (cdr entry)))
                 (edge position (remq entry keys) offset #f (list (list 'Exactly (car entry)) (cdr entry))))) keys)
             (if (null? keys) (list (edge position [] offset #t '((Exactly #!rest)))) [])))))))
  ;; Register reverse arrows while exploring; the same traversal later closes
  ;; predecessors. The official hash-update! retains all shared predecessors.
  (def (arrows state)
    (match state
      ([position keys offset _rest?]
       (when (and (= position position-count) (null? keys) (= offset raw-count))
         (set! endings (cons state endings)))))
    (def outgoing (successors state))
    (for-each (lambda (out)
      (hash-update! predecessors (raw-edge-next out) (cut cons state <>) [])) outgoing)
    outgoing)
  (values (raw-reachable (list initial) arrows raw-edge-next work) predecessors endings initial))

;; Independently check endings, predecessor closure and ordered per-slot evidence.
;; Even an empty initial language must carry a complete closure certificate;
;; merely encountering an explored cycle can never approve a call region.
(def (raw-certificate? edges live endings initial actual at? work)
  (and (andmap (cut hash-key? live <>) endings)
    (or (not (hash-key? live initial)) actual)
    (hash-fold (lambda (state outgoing accepted?)
      (work)
      (and accepted?
        (match state
          ([_position _keys offset _rest?]
           (andmap (lambda (out)
             (or (not (hash-key? live (raw-edge-next out)))
               (and (hash-key? live state) actual
                 (let slots ((origins (raw-edge-origins out)) (index offset))
                   (or (null? origins)
                     (and (at? index (car origins)) (slots (cdr origins) (1+ index)))))))) outgoing))))) #t edges)
    (if (hash-key? live initial) #t 'empty)))

;; Normalize through the existing signature protocol, construct the product,
;; close predecessors, then check slot evidence. Cache only completed comparisons
;; with std/hash/misc: cached #f stays #f and exceptions never install an answer.
(def (raw-inputs-related? actual expected arguments raw-arguments limits work)
  (def row (signature.decode-arguments
    (signature.normalize-arguments expected arguments #t (lambda (formal _) formal)) #t))
  (defvalues (edges predecessors endings initial)
    (raw-graph expected row (length raw-arguments) limits work))
  (def live (raw-reachable endings (cut hash-ref predecessors <> []) identity work))
  (def admitted (make-hash-table))
  (def source-fixed (and actual (list->vector (append (.get actual inputs) (.get actual optional)))))
  (def source-rest (and actual (.get actual rest)))
  ;; Each edge origin uses its own raw offset, including the saturated rest slot.
  ;; Public Union bounds remain invariant; only identity origins use flat inclusion.
  (def (at? index origin)
    (work)
    (def formal (if (< index (vector-length source-fixed)) (vector-ref source-fixed index) source-rest))
    (and formal (hash-ensure-ref admitted (cons origin formal)
                  (cut raw-origin-subtype? origin formal work))))
  (raw-certificate? edges live endings initial actual at? work))

;; Keyword sources still require stable supplied target carriers. Plain sources
;; use value-sensitive raw origin checks, preserving the exact selected clause.
(def (function-wire-related? actual expected arguments source-mode? target-mode? raw-arguments limits work)
  (work)
  (if source-mode?
    (let (stable #t)
      (signature.normalize-arguments expected arguments target-mode?
        (lambda (formal _placeholder)
          (unless (keyword-stable-type? formal work) (set! stable #f))
          formal))
      stable)
    (raw-inputs-related? actual expected arguments raw-arguments limits work)))

;; Decide shape-language inclusion in the bounded finite algebra. This checks
;; all allowed supplied rows, not Type inclusion or arbitrary host procedure arity.
;; Unsupported/malformed syntax and quota exhaustion retain their typed errors.
(def (function-covers? source target (budget 8192))
  (def work (type-work budget))
  (type-expression source [] work) (type-expression target [] work)
  (def left (normalize-type source work)) (def right (normalize-type target work))
  (unless (and (pair? left) (pair? right)
               (memq (car left) '(Function CaseFunction)) (memq (car right) '(Function CaseFunction)))
    (refuse-type 'bounds "Call coverage requires Function signatures"))
  (signature.covers-signatures? (function-signatures left) (function-signatures right) work
    (lambda _ #t)
    (lambda (actual expected arguments source-mode? target-mode? raw-arguments limits)
      ;; Direct rows ask shape coverage only, as in the same-mode judgment.
      ;; Replacement separately checks every direct value's contravariance.
      (or (and (not source-mode?) target-mode? actual (<= (length raw-arguments) (car limits))
               (let (row (signature.decode-arguments arguments #t))
                 (and (null? (cdr row)) (= (length (car row)) (length raw-arguments)))))
          (function-wire-related? actual expected arguments source-mode? target-mode? raw-arguments limits work)))))

;; First-match selection determines BOTH sides of every row. Required/optional/
;; rest and provided keyword inputs are contravariant; exact-count outputs are
;; covariant. Shadowed later cases cannot repair an earlier incompatible clause.
(def (function-replaces? source target work)
  (signature.covers-signatures? (function-signatures source) (function-signatures target) work
    (lambda (actual expected arguments source-mode? target-mode? _raw-arguments limits)
      (work)
      (and (= (length (.get actual outputs)) (length (.get expected outputs)))
           (andmap (lambda (s t) (compare-types s t work)) (.get actual outputs) (.get expected outputs))
        ;; The raw origin checker already establishes all cross-mode inputs.
        ;; Same-mode calls reuse ordinary supplied-input variance below.
        (or (and (not source-mode?) target-mode?)
          (let* ((accepted #t)
                 (normalized (signature.normalize-arguments expected arguments target-mode?
                   (lambda (formal _placeholder) formal)))
                 (supplied normalized))
            (signature.normalize-arguments actual supplied source-mode?
              (lambda (formal value)
                (work)
                (unless (compare-types value formal work) (set! accepted #f))
                value))
            accepted))))
    (cut function-wire-related? <> <> <> <> <> <> <> work)))

;; Compile a checked ground expression through existing recursive container and
;; Function validators. Wrapping remains at validate/contract boundaries, so this
;; never proves a host procedure's arity, totality or its result without a call.
(def (expression-type expression (budget 8192))
  (let (work (type-work budget))
    (type-expression expression [] work)
    (compile-expression expression work)))

;; Internal checked compiler shares its caller's work counter. Only finite terms
;; already admitted by type-expression may enter this lower-level operation.
(def (compile-expression expression work)
  (let build ((term (normalize-type expression work)))
    (work)
    (if (catalog-type? term) (catalog-contract term work) (case term
      ((Null) Null) ((Unit) Unit) ((Bytes) Bytes) ((Bytes32) Bytes32) ((Bytes64) Bytes64) ((UInt256) UInt256) ((JsInt) JsInt) ((Any) Any) ((Never) Never) ((Bool) Bool) ((Integer) Integer) ((UInt) UInt) ((Keyword) Keyword) ((String) String) ((Symbol) Symbol)
      (else
       (case (car term)
         ;; Reuse Class and its effective Slot protocol, including recursive
         ;; validation and checked initialization. Defaults/hooks are host policy,
         ;; supplied by deriving this descriptor, never executable inference data.
         ((Record)
          (.cc Class. sexp: (copy-type term) sealed: (eq? (caddr term) 'closed)
            slots: (object<-alist (map (lambda (field)
              (cons (car field) (RecordSlot (build (cadr field)) optional: (eq? (caddr field) 'optional))))
              (cadr term)))))
         ((Object)
          (let (fields (object<-alist (map (lambda (field) (cons (car field) (build (cadr field)))) (cadr term))))
            (if (eq? (caddr term) 'closed)
              (.cc ObjectContract. responsibilities: fields)
              (.cc ObjectContract. responsibilities: fields extra-fields: 'delegate constraints: (list Object)))))
         ((UIntN) (UIntN (cadr term)))
         ((IntN) (IntN (cadr term)))
         ((BytesN) (BytesN (cadr term)))
         ((IntegerRange)
          (let (bounds (range-bounds term)) (IntegerRange min: (car bounds) max: (cdr bounds))))
         ((Exactly) (Exactly (cadr term)))
         ((Enum)
          ;; Snapshot before entering lazy slots: later caller syntax mutation
          ;; cannot change the first observation's literal set or display syntax.
          (let ((values (copy-type (cdr term))) (syntax (copy-type term)))
            (.cc Enum. vals: values sexp: syntax)))
         ((Pair) (Pair (build (cadr term)) (build (caddr term))))
         ((TypeValuePair)
          (let (tokens (filter catalog-type? (cdr term)))
            (type-value-catalog TypeValuePair
              (map (lambda (child) (if (catalog-type? child) (catalog-descriptor child work) (build child))) (cdr term))
              (copy-type term) (lambda () (for-each catalog-current! tokens)))))
         ((Map) (Map (build (cadr term)) <- (build (cadddr term))))
         ((Sum) (apply Sum (cdr (map-sum-types term build))))
         ((Union) (apply Union (map build (cdr term))))
         ((Maybe) (Maybe (build (cadr term))))
         ((OrFalse) (OrFalse (build (cadr term))))
         ((List) (List (build (cadr term))))
         ((Tuple) (apply Tuple (map build (cdr term))))
         ((CaseFunction) (apply CaseFunction (map build (cdr term))))
         ((Function)
          (call-with-function-types term
            (lambda (outputs inputs optional keywords required rest)
              (Function (map build outputs) (map build inputs)
                optional: (map build optional)
                keywords: (map (lambda (entry) (cons (car entry) (build (cdr entry)))) keywords)
                required-keywords: required rest: (and rest (build rest))))))))))))
