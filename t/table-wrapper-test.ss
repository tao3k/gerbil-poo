;;; Whole table algorithms are derived from explicit representation symmetries.
(export table-wrapper-test box-table)
(import :std/test :std/iter :std/error
        (only-in ../slot-observation %call-with-recorded-slot-reads call-with-slot-read-observer
                 slot-read-receiver slot-read-key)
        ../object ../mop ../number ../type ../table ../rationaldict ../support/option
        (only-in ../fun Wrapper. IdWrap)
        (only-in ../trie SimpleTrie Trie. Branch Leaf)
        (prefix-in ../examples/service-collection service.))

;; Official host records supply a raw carrier with no table operations of its own.
(defstruct boxed-table (raw) transparent: #t final: #t)

;; Derive only the table protocol; raw target recognition does not pretend to
;; establish child membership or any inverse law automatically.
(def (box-table source (ap make-boxed-table) (unap boxed-table-raw))
  (def target (.cc Type. Key: (.@ source Key) Value: (.@ source Value) .element?: boxed-table?))
  (def carrier (.cc Wrapper. Domain: source Codomain: target .ap: ap .unap: unap))
  (def keys (.cc Wrapper. Domain: (.@ source Key) Codomain: (.@ source Key) .ap: - .unap: -))
  (def payloads (.cc Wrapper. Domain: (.@ source Value) Codomain: (.@ source Value) .ap: identity .unap: identity))
  (values (table-wrapper source carrier keys payloads) carrier keys))

;; Distinguish expected metadata refusal from unrelated backend errors.
(def (message? text)
  (lambda (cause) (and (Error? cause) (equal? (Error-message cause) text))))

;; Complete derived protocols share existing normalization, revisions, folds and FUN.
(def table-wrapper-test
  (test-suite "isomorphism-derived table algorithms"
    (test-case "a target without table methods derives lookup updates folds and optional lenses"
      (defvalues (table _carrier _keys) (box-table (RationalDict Integer)))
      (def base (.call table .<-list '((-1 . 10) (-2 . 20) (-9 . 90))))
      (check-equal? (.call table .ref base -2) 20)
      (check (.call table .empty? (.@ table .empty)) => #t)
      (check (.call table .empty? (.call table .remove (.call table .acons -1 10 (.@ table .empty)) -1)) => #t)
      (check-equal? (.call table .ref base -7 (lambda () 'absent)) 'absent)
      ;; The source traversal is inherited: negated keys appear in descending order.
      (check-equal? (.call table .list<- base) '((-1 . 10) (-2 . 20) (-9 . 90)))
      (check-equal? (.call table .foldl (lambda (_ v acc) (+ acc v)) 0 base) 120)
      (check-equal? (.call table .foldl (lambda (k _ acc) (cons k acc)) [] base) '(-9 -2 -1))
      (check-equal? (.call table .min-binding base) '(-1 . 10))
      (check-equal? (.call table .max-binding base) '(-9 . 90))
      (check-equal? (.call table .list<- (.call table .<-bytes (.call table .bytes<- base))) (.call table .list<- base))
      (def mapped (.call table .map/wrap
        (lambda (raw) (.call (.@ table T) .acons 3 30 raw)) base))
      (check-equal? (.call table .ref mapped -3) 30)
      (check-equal? (.call table .bind/wrap base (lambda (raw) (.call (.@ table T) .ref raw 1))) 10)
      (def focus (.call table .lens/opt -2))
      (def next (.call focus .set (some 21) base))
      (check-equal? (.call table .ref next -2) 21)
      (check-equal? (.call table .ref base -2) 20)
      (check (.call table .key? (.call table .remove next -2) -2) => #f)
      (check (element? table next) => #t)
      (check-exception (.call table .ref 'foreign -1) TypeError?))
    (test-case "ordered deltas and fold FUN consume a derived carrier with shared Functions"
      (def table (service.make-mirrored-ledger))
      (def raw (lambda (_) "bad result"))
      (def initial (validate table (.call table .<-list (list (cons -1 (cons 10 raw))))))
      (def f (cdr (.call table .ref initial -1)))
      (def base (.call table .acons -9 (cons 90 f) initial))
      (check (eq? (cdr (.call table .ref base -9)) f) => #t)
      (def middle (.call table .acons -1 (cons 20 f) base))
      (def final (.call table .acons -1 (cons 30 f) (.call table .remove middle -9)))
      (def batch (.call table .compose-deltas
        (list (.call table .diff base middle) (.call table .diff middle final))))
      (def folding (table-fold table Integer (lambda (_ v) (car v))))
      (def state (.call folding .ap base))
      (def consumed 0)
      (def action (service.fold-ledger-action folding state
        (lambda (v) (set! consumed (+ consumed 1)) v)))
      (def next (action batch))
      (check-equal? (.call folding .get next) 30)
      (check-equal? consumed 1)
      (check (eq? (cdr (.call table .ref (.call folding .unap next) -1)) f) => #t)
      (check-exception (f 2) TypeError?)
      (check-equal? (.call folding .get (.call folding .apply-delta next (invert-table-delta batch))) 100)
      (def stale (.call table .diff base (.call table .acons -1 (cons 40 f) base)))
      (check-exception (.call folding .apply-delta next stale) table-conflict?)
      (check-equal? consumed 1)
      (def retry (.call table .diff (.call folding .unap next) (.call table .acons -1 (cons 40 f) final)))
      (check-equal? (.call folding .get (.call folding .apply-delta next retry)) 40))
    (test-case "data and ordered delta isomorphisms reuse the generated backend"
      (def source (RationalDict Integer))
      (defvalues (target _carrier keys) (box-table source))
      (def payloads (.cc Wrapper. Domain: Integer Codomain: Integer .ap: identity .unap: identity))
      (def mapping (table-isomorphism source target keys payloads))
      (def base (.call source .<-list '((1 . 10) (2 . 20))))
      (def middle (.call source .acons 1 20 base))
      (def final (.call source .acons 1 30 middle))
      (def delta (.call source .compose-deltas
        (list (.call source .diff base middle) (.call source .diff middle final))))
      (def staged (.call (.@ mapping Delta) .ap (cons base delta)))
      (def next (.call target .apply-delta (car staged) (cdr staged)))
      (check-equal? (.call target .ref next -1) 30)
      (check-equal? (.call source .list<- (.call mapping .unap next)) (.call source .list<- final))
      (check-equal? (.call target .list<- (.call target .apply-delta next (invert-table-delta (cdr staged))))
                    (.call target .list<- (car staged))))
    (test-case "derived FUN publication preserves callbacks refusal and explicit retry"
      (def table (service.make-mirrored-ledger))
      (def initial (validate table (.call table .<-list
        (list (cons -1 (cons 10 (lambda (x) (+ x 1))))
              (cons -9 (cons 90 (lambda (x) (+ x 2))))))))
      (def callback (cdr (.call table .ref initial -1)))
      (def calls 0) (def consumed 0)
      ;; A malformed replacement refuses before the consumer, without poisoning
      ;; the checked conversions or revalidating the admitted Function payload.
      (check-exception (service.revise-ledger-point table initial -1
        (lambda (_) (set! calls (+ calls 1)) (some (cons "bad" callback)))
        (lambda (_) (set! consumed (+ consumed 1)))) TypeError?)
      (check-equal? consumed 0)
      (def next (service.revise-ledger-point table initial -1
        (lambda (_) (set! calls (+ calls 1)) (some (cons 20 callback)))
        (lambda (state) (set! consumed (+ consumed 1)) state)))
      (check-equal? calls 2)
      (check-equal? consumed 1)
      (check (eq? (cdr (.call table .ref next -1)) callback) => #t)
      (check-equal? (callback 7) 8)
      (def request (.call table .diff initial next))
      (check-exception (service.revise-ledger-styles table next (list request)
        (lambda (_) (set! consumed (+ consumed 1)))) table-conflict?)
      (check-equal? consumed 1)
      (def restored (service.revise-ledger-styles table next (list (invert-table-delta request)) identity))
      (check-equal? (.call table .list<- restored) (.call table .list<- initial)))
    (test-case "carrier checks share only local pure conversions and keep both inverse tests"
      (def source (RationalDict Integer))
      (def wraps 0) (def unwraps 0)
      (defvalues (table _carrier _keys) (box-table source
        (lambda (tree) (set! wraps (+ wraps 1)) (make-boxed-table tree))
        (lambda (box) (set! unwraps (+ unwraps 1)) (boxed-table-raw box))))
      (def raw (.call source .acons 1 10 (.@ source .empty)))
      ;; Counters observe actual callbacks, outside any performance interval.
      (set! wraps 0) (set! unwraps 0)
      (def boxed (.call table .wrap raw))
      (check-equal? (list wraps unwraps) '(2 1))
      (set! wraps 0) (set! unwraps 0)
      (check (eq? (.call table .unwrap boxed) raw) => #t)
      (check-equal? (list wraps unwraps) '(1 2))
      (set! wraps 0) (set! unwraps 0)
      (check-exception (.call table .wrap 'foreign) TypeError?)
      (check-exception (.call table .unwrap 'foreign) TypeError?)
      (check-equal? (list wraps unwraps) '(0 0))
      ;; A changing converter violates the pure law: keep the encountered right
      ;; inverse check and reject it, rather than silently accepting its output.
      (def calls 0) (def broken? #f)
      (defvalues (unstable _carrier2 _keys2) (box-table source
        (lambda (tree)
          (set! calls (+ calls 1))
          (make-boxed-table (if (and broken? (even? calls)) (.@ source .empty) tree)))))
      (set! calls 0) (set! broken? #t)
      (def refused (try (.call unstable .wrap raw) #f (catch (e) e)))
      (check (table-isomorphism-failure? refused) => #t)
      (check-equal? (table-isomorphism-failure-kind refused) 'right-inverse)
      (check-equal? calls 2))
    (test-case "captured child Types reject replaced and revised metadata before conversion"
      (def payload (.cc Integer))
      (def source (RationalDict payload))
      (def conversions 0)
      (defvalues (table _carrier _keys) (box-table source
        (lambda (tree) (set! conversions (+ conversions 1)) (make-boxed-table tree))))
      (def base (.call table .acons -1 10 (.@ table .empty)))
      (def empty (.call table .diff base base))
      ;; Capture after all setup: Gerbil can lift internal definitions, so the
      ;; mutation, negative controls and fresh reconstruction use explicit lets.
      (let (before conversions)
        (.set! source Key (.cc (.@ source Key)))
        (check-exception (.call table .ref base -1) (message? "stale table wrapper"))
        (check-exception (.call table .apply-delta base empty) (message? "stale or incompatible table delta"))
        (check-equal? conversions before))
      (let-values (((fresh _carrier2 _keys2) (box-table source)))
        (check-equal? (.call fresh .ref base -1) 10)
        ;; Captured children stay protected as well as their source. A supported
        ;; write during traversal refuses; a later write invalidates this context.
        (let (revision (object-revision payload))
          (check-exception (.call fresh .foldl
            (lambda (_k _v _acc) (.set! payload sexp 'changed)) #f base)
            (message? "object mutation during computation"))
          (check-equal? (object-revision payload) revision))
        (.set! payload sexp 'changed-after-traversal)
        (check-exception (.call fresh .ref base -1) (message? "stale table wrapper")))
      (let-values (((rebound _carrier3 _keys3) (box-table source)))
        (check-equal? (.call rebound .ref base -1) 10)))
    (test-case "persistent shape outputs reuse admission through GC refusal retry and undo"
      ;; Fresh private backends compare the same typed operations with/without
      ;; the explicit law. Full inverse checks and admitted leaves stay active.
      (def (exercise preserves?)
        (def visits 0) (def refuse? #f) (def failure (list 'update-refused))
        (def raw (.cc (.mix Trie. IdWrap) Key: UInt Value: Integer
          .shape-preserving?: preserves?
          .unwrap: (lambda (tree) (set! visits (+ visits 1)) tree)))
        (def source (.cc raw .acons: (lambda (k v t)
          (when refuse? (raise failure)) (.call raw .acons k v t))))
        (def target (.cc Type. Key: Integer Value: Integer .element?: boxed-table?))
        (def carrier (.cc Wrapper. Domain: source Codomain: target
          .ap: make-boxed-table .unap: boxed-table-raw))
        (def keys (.cc Wrapper. Domain: UInt Codomain: Integer .ap: - .unap: -))
        (def payloads (.cc Wrapper. Domain: Integer Codomain: Integer .ap: identity .unap: identity))
        (def table (table-wrapper source carrier keys payloads))
        (def base (.call table .<-list (for/collect (n (in-range 64)) (cons (- n) n))))
        (set! visits 0)
        (let* ((next (.call table .acons -1 70 base))
               (delta (.call table .delta/opt -2 (lambda (_) (some 80)) next)))
          ;; Collect while roots remain live, then reject a backend failure without
          ;; granting its candidate root any admission. Retry and inverse still work.
          (##gc)
          (set! refuse? #t)
          (check-exception (.call table .apply-delta next delta) (cut eq? <> failure))
          (set! refuse? #f)
          (let (published (.call table .apply-delta next delta))
            (check-equal? (.call table .ref published -2) 80)
            (check-equal? (.call table .ref
              (.call table .apply-delta published (invert-table-delta delta)) -2) 2))
          ;; Observation must still demand the live validator for a new output.
          (let (denied (list 'validator-denied))
            (check-exception (call-with-slot-read-observer void
              (lambda () (.call table .acons -3 90 base))
              before: (lambda (receiver field)
                (when (and (eq? receiver source) (eq? field '.validate-shape)) (raise denied))))
              (cut eq? <> denied)))
          (check-exception (.call table .wrap (Branch 1 (Leaf 1) (Leaf 2))) TypeError?)
          (check-equal? (.call table .ref base -1) 1)
          visits))
      (let ((reference (exercise #f)) (reused (exercise #t)))
        (check (< reused reference) => #t)
        (displayln "TABLE-WRAPPER-SHAPE reference=" reference " reused=" reused)))
    (test-case "paired revision checks retain every origin and prepared receiver scope"
      ;; Each iteration owns its Types; no shared library Type is mutated.
      (for (index (in-range 6))
        (def source (.cc (RationalDict (.cc Integer)) Key: (.cc Integer)))
        (defvalues (table carrier keys) (box-table source))
        (def base (.call table .acons -1 10 (.@ table .empty)))
        (def empty (.call table .diff base base))
        (def origin (list-ref (list source (.@ source Key) (.@ source Value)
          carrier keys (.@ carrier Codomain)) index))
        (.set! origin revision-marker index)
        (check-exception (.call table .ref base -1) (message? "stale table wrapper"))
        (check-exception (.call table .apply-delta base empty)
          (message? "stale or incompatible table delta")))
      (let-values (((table _carrier _keys) (box-table (RationalDict Integer))))
        (let ((base (.call table .acons -1 10 (.@ table .empty)))
              (revision (object-revision table)))
          ;; The reused scope still protects the derived receiver through FUN and
          ;; traversal callbacks. Refusal cannot alter its revision or snapshot.
          (check-exception (.call table .bind/wrap base
            (lambda (_) (.set! table revision-marker 'bind)))
            (message? "object mutation during computation"))
          (check-exception (.call table .foldl
            (lambda (_k _v _acc) (.set! table revision-marker 'fold)) #f base)
            (message? "object mutation during computation"))
          (check-equal? (object-revision table) revision)
          (check-equal? (.call table .ref base -1) 10))))
    (test-case "observed contexts retain live getter refusal and stale read provenance"
      (def source (RationalDict Integer))
      (defvalues (table _carrier _keys) (box-table source))
      (def base (.call table .acons -1 10 (.@ table .empty)))
      (def denied (list 'source-key-denied))
      ;; An observed access still executes the source Key getter demand; its
      ;; original cause cannot be replaced by a captured child Type.
      (check (eq? (try
        (call-with-slot-read-observer void (cut .call table .ref base -1)
          before: (lambda (owner key)
            (when (and (eq? owner source) (eq? key 'Key)) (raise denied))))
        #f (catch (e) e)) denied) => #t)
      (let-values (((value roots) (%call-with-recorded-slot-reads (cut .call table .ref base -1))))
        (check-equal? value 10)
        (let (selected (filter (lambda (read)
          (and (eq? (slot-read-receiver read) source) (eq? (slot-read-key read) 'Key))) roots))
          (check (pair? selected) => #t)
          (.set! source Key (.cc (.@ source Key)))
          (check (object-read-current? (car selected)) => #f)))
      (check-exception (.call table .ref base -1) (message? "stale table wrapper")))
    (test-case "point operations reuse the backend without enumerating snapshots"
      (def original (RationalDict Integer))
      (def blocked (.cc original .foldl: (lambda _ (error "unexpected scan"))
                                .foldr: (lambda _ (error "unexpected scan"))))
      (defvalues (table _carrier _keys) (box-table blocked))
      (def base (.call table .acons -1 10 (.@ table .empty)))
      (check-equal? (.call table .ref base -1) 10)
      (check-equal? (.call table .ref (.call table .acons -2 20 base) -2) 20)
      (check (.call table .key? (.call table .remove base -1) -1) => #f))
    (test-case "captured converter revisions refuse old operations and allow fresh derivation"
      (def source (RationalDict Integer))
      (defvalues (table carrier keys) (box-table source))
      (def base (.call table .acons -1 10 (.@ table .empty)))
      (def delta (.call table .diff base (.call table .acons -1 20 base)))
      (.set! keys sexp 'revised)
      (check-exception (.call table .ref base -1) (message? "stale table wrapper"))
      (check-exception (.call table .apply-delta base delta) (message? "stale or incompatible table delta"))
      (defvalues (fresh _carrier _keys) (box-table source))
      (check-equal? (.call fresh .ref base -1) 10))
    (test-case "broken carrier inverses reject before publication and callback exceptions retain identity"
      (def source (RationalDict Integer))
      (defvalues (table _carrier _keys)
        (box-table source make-boxed-table (lambda (_) (.@ source .empty))))
      (check-exception (.call table .acons -1 10 (.@ table .empty)) table-isomorphism-failure?)
      (def failure (list 'backend-failure))
      (def broken (.cc source .acons: (lambda _ (raise failure))))
      (defvalues (bad _carrier2 _keys2) (box-table broken))
      (def cause (try (.call bad .acons -1 10 (.@ bad .empty)) #f (catch (e) e)))
      (check (eq? cause failure) => #t))
    (test-case "invalid child conversions and noninjective key maps refuse before backend writes"
      (def original (RationalDict Integer))
      (def writes 0)
      (def source (.cc original .acons: (lambda (k v raw)
        (set! writes (+ writes 1)) (.call original .acons k v raw))))
      (def raw-type (.cc Type. Key: (.@ source Key) Value: Integer .element?: boxed-table?))
      (def carrier (.cc Wrapper. Domain: source Codomain: raw-type
        .ap: make-boxed-table .unap: boxed-table-raw))
      (def bad-keys (.cc Wrapper. Domain: (.@ source Key) Codomain: (.@ source Key)
        .ap: abs .unap: identity))
      (def values-map (.cc Wrapper. Domain: Integer Codomain: Integer .ap: identity .unap: identity))
      (def bad-key-table (table-wrapper source carrier bad-keys values-map))
      (check-exception (.call bad-key-table .acons -1 10 (.@ bad-key-table .empty)) table-isomorphism-failure?)
      (check-equal? writes 0)
      (def keys (.cc Wrapper. Domain: (.@ source Key) Codomain: (.@ source Key) .ap: identity .unap: identity))
      (def bad-values (.cc Wrapper. Domain: Integer Codomain: Integer .ap: (lambda (_) "wrong") .unap: identity))
      (def bad-value-table (table-wrapper source carrier keys bad-values))
      (check-exception (.call bad-value-table .acons 1 10 (.@ bad-value-table .empty)) table-isomorphism-failure?)
      (def raw (.call original .acons 1 10 (.@ original .empty)))
      (check-exception (.call bad-value-table .ref (.call bad-value-table .wrap raw) 1) TypeError?)
      (check-equal? writes 0))
    (test-case "multi-stage derivations retain transitive origins in folds and empty deltas"
      (def source (RationalDict Integer))
      (defvalues (first _carrier keys) (box-table source))
      (defvalues (second _carrier2 _keys2) (box-table first))
      (def base (.call second .<-list '((1 . 10) (9 . 90))))
      (def empty (.call second .diff base base))
      (def folding (table-fold second Integer (lambda (_ value) value)))
      (def state (.call folding .ap base))
      (check-equal? (.call folding .get state) 100)
      (.set! keys sexp 'revised-inner-converter)
      (check-exception (.call folding .get state) (message? "stale table fold"))
      (check-exception (.call second .apply-delta base empty) (message? "stale or incompatible table delta"))
      (check-exception (.call second .ref base 1) (message? "stale table wrapper")))
    (test-case "Rational pair encoding composes unary byte and JSON decoders"
      (for (value (list 0 -1 1/3 -7/5 65537/3 (/ (+ (expt 2 100) 1) 3)
                              (/ (- (+ (expt 2 100) 1)) (+ (expt 2 80) 3))))
        (check-equal? (.call Rational .<-pair (.call Rational .pair<- value)) value)
        (check-equal? (.call Rational .<-bytes (.call Rational .bytes<- value)) value)
        (check-equal? (.call Rational .<-json (.call Rational .json<- value)) value)))
    (test-case "Pair JSON delegates nested and integer-string children before carrier reconstruction"
      (def descriptor (Pair (Pair Integer UInt) (List (Pair Integer UInt))))
      (def large (+ (expt 2 100) 1))
      (def value (cons (cons (- large) large) (list (cons large 3) (cons 7 large))))
      (def json (.call descriptor .json<- value))
      ;; Ensure this control actually crosses Integer's nonnumeric JSON boundary.
      (check (string? (car (car json))) => #t)
      (check-equal? (.call descriptor .<-json json) value)
      (def trace [])
      (def cause (list 'left-codec-failure))
      (def left (.cc Integer .<-json: (lambda (_)
        (set! trace (cons 'left trace)) (raise cause))))
      (def right (.cc Integer .<-json: (lambda (_)
        (set! trace (cons 'right trace)) 7)))
      (def observed (try (.call (Pair left right) .<-json '(1 2)) #f (catch (e) e)))
      (check (eq? observed cause) => #t)
      (check-equal? trace '(left)))
    (test-case "supported source or receiver mutation during traversal refuses and remains retryable"
      (def source (RationalDict Integer))
      (defvalues (table _carrier _keys) (box-table source))
      (def base (.call table .acons -1 10 (.@ table .empty)))
      (for (changed (list source table))
        (def before (object-revision changed))
        (check-exception (.call table .foldl (lambda (_k _v _acc) (.set! changed sexp 'mutation)) #f base)
          (message? "object mutation during computation"))
        (check-equal? (object-revision changed) before))
      (check-exception (.call table .map/wrap (lambda (raw) (.set! source sexp 'mutation) raw) base)
        (message? "object mutation during computation"))
      (check-equal? (.call table .ref base -1) 10))))
