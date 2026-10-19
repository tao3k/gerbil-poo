;;; Finite structural Type expressions; no nominal-inheritance implication.
(export function-covers? function-signatures type-refusal? type-refusal-kind refuse-type bounded-type-data type-work scalar-recognizer type-constructor? type-expression substitute-type subtype-expression? subtype/checked? expression-type compile-expression normalize-type function-options function-expression function-template copy-type canonical-type)
(import (only-in :std/hash/misc hash-ensure-ref)
        (only-in :std/list/list map-in-order) (prefix-in ./function-signature signature.) ./type-syntax ./recursive-types ./object
        (only-in ./mop Any Bool Function CaseFunction Type. Object Class.)
        (only-in ./object-contract ObjectContract.)
        (only-in ./number Integer UInt)
        (only-in ./type List Tuple Maybe OrFalse Pair Map Sum Union RecordSlot String Symbol Keyword Exactly Enum.))

;; Bottom has no inhabitants. Crossing a finite recursive approximation boundary
;; is ordinary type refusal, not work exhaustion or evidence of global emptiness.
(def Never (.cc Type. sexp: 'Never .element?: (lambda (_) #f)))

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

;; Flat Types validate without replacing values. Raw-origin admission alone
;; may compare their alternatives; the public Union relation stays invariant.
(def (flat-type? term)
  (if (pair? term)
    (case (car term) ((Exactly Enum) #t) ((Union) (andmap flat-type? (cdr term))) (else #f))
    (and (scalar-recognizer term) #t)))
;; Decide singleton inclusion without executing a user predicate or constructor.
(def (literal-in-type? value term work)
  (work)
  (cond ((scalar-recognizer term) => (lambda (recognize) (recognize value)))
        (else (and (pair? term)
          (case (car term)
            ((Exactly) (equal? value (cadr term)))
            ((Enum) (and (member value (cdr term)) #t))
            ((Union) (ormap (cut literal-in-type? value <> work) (cdr term)))
            (else #f))))))
;; Inclusion distributes only over the proven identity-preserving flat fragment.
;; An explicit Any source still cannot replace a narrower field or signature.
(def (flat-subtype? source target work)
  (work)
  (cond ((equal? source target) #t)
        ((or (eq? source 'Never) (eq? target 'Any)) #t)
        ((and (pair? source) (eq? (car source) 'Union))
         (andmap (cut flat-subtype? <> target work) (cdr source)))
        ((and (pair? source) (memq (car source) '(Exactly Enum)))
         (andmap (cut literal-in-type? <> target work) (cdr source)))
        ((and (pair? target) (eq? (car target) 'Union))
         (ormap (cut flat-subtype? source <> work) (cdr target)))
        (else (and (eq? source 'UInt) (eq? target 'Integer)))))

;; Object fields are required; Record fields carry explicit presence metadata.
;; Syntax admission already rejects duplicate names and unknown presence markers.
(def (field-required? field)
  (or (null? (cddr field)) (eq? (caddr field) 'required)))

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
  (cond
   ((equal? source target) #t)
   ((or (eq? target 'Any) (eq? source 'Never)) #t)
   ((and (flat-type? source) (flat-type? target)
         (not (and (pair? source) (eq? (car source) 'Union)))
         (not (and (pair? target) (eq? (car target) 'Union))))
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
   (else #f)))

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
  (cond ((scalar-recognizer term) =>
         (lambda (recognize)
           (not (or (recognize mode:) (recognize #!key) (recognize #!rest)))))
        (else (case (car term)
          ((Exactly Enum) (andmap (lambda (value) (not (or (keyword? value) (eq? value #!key) (eq? value #!rest)))) (cdr term)))
          ((Maybe OrFalse) (keyword-stable-type? (cadr term) work))
          ((Union) (andmap (cut keyword-stable-type? <> work) (cdr term)))
          ((List Tuple Pair Map Sum Record Object Function CaseFunction) #t)
          (else #f)))))

;; Only the raw transport judgment uses extensional flat-origin inclusion:
;; identity validators cannot alter earlier branch wrapping or normalization.
;; Public Union bounds and general subtype inference retain exact ordered syntax.
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
    (case term
      ((Any) Any) ((Never) Never) ((Bool) Bool) ((Integer) Integer) ((UInt) UInt) ((Keyword) Keyword) ((String) String) ((Symbol) Symbol)
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
         ((Exactly) (Exactly (cadr term)))
         ((Enum)
          ;; Snapshot before entering lazy slots: later caller syntax mutation
          ;; cannot change the first observation's literal set or display syntax.
          (let ((values (copy-type (cdr term))) (syntax (copy-type term)))
            (.cc Enum. vals: values sexp: syntax)))
         ((Pair) (Pair (build (cadr term)) (build (caddr term))))
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
                required-keywords: required rest: (and rest (build rest)))))))))))
