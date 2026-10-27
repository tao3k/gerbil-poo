;;; Automatic recursive generation, bounded membership, shrinking and replay.
(export recursive-generation-test)
(import :std/test :std/error :clan/poo/object :clan/poo/mop :clan/poo/type :clan/poo/number
        :clan/poo/testing/generation-graph :clan/poo/testing/type
        (prefix-in :clan/poo/examples/recursive-trees trees.))

;; Match only a controlled refusal and its precise resource tag.
(def (limited? kind)
  (lambda (cause) (and (generation-refusal? cause) (eq? (generation-refusal-kind cause) kind))))
;; Inspect recorded resource refusals rather than accepting unrelated errors.
(def (reason report)
  (and (generation-refusal? (.get report cause)) (generation-refusal-kind (.get report cause))))
;; Every case checks a complete protocol outcome; no trial count is reduced to
;; make a recursive descriptor pass, and no inconclusive result is a success.
(def recursive-generation-test
  (test-suite "automatic guarded recursive generators"
    (test-case "Or reuses bounded alternative generation shrinking and replay"
      (def descriptor (Or (List UInt) (Tuple Bool)))
      (def passed (check-property descriptor (cut element? descriptor <>)
        seed: 39 cases: 20 size: 5 depth: 6 node-budget: 32))
      (check-equal? (.get passed status) 'passed)
      (check-equal? (.get passed trial) 20)
      (def failed (check-property descriptor (lambda (_) #f)
        seed: 39 cases: 20 size: 5 depth: 6 node-budget: 32 shrink-budget: 30))
      (check-equal? (.get failed status) 'failed)
      (check-equal? (.get (replay-property failed) status) 'failed))
    (test-case "mutual recursion and shared children derive without custom callbacks"
      (let (report (check-property trees.Message (cut element? trees.Message <>) seed: 37
                      cases: 150 size: 5 depth: 10 node-budget: 100 search-budget: 20000))
        (check-equal? (.get report status) 'passed)
        (check-equal? (.get report trial) 150)
        (check-equal? (.get report limits depth) 10)))
    (test-case "FUN workflow shrinks a recursive false witness and replays it"
      (let* ((consumed 0)
             (action (trees.tree-tests (lambda (report) (set! consumed (+ consumed 1)) report)))
             (report (action (.o seed: 42 cases: 100 size: 12 shrink-budget: 300
                                depth: 10 node-budget: 100 search-budget: 20000)))
             (replayed (replay-property report)))
        (check-equal? (.get report status) 'failed)
        (check-equal? (abs (trees.tree-total (.get report counterexample) 64)) 4)
        (check-equal? (.get replayed original) (.get report original))
        (check-equal? (.get replayed counterexample) (.get report counterexample))
        (check-equal? (.get replayed attempts) (.get report attempts))
        (check-equal? (.get report node-budget) 100)
        (check-equal? consumed 1)))
    (test-case "zero depth and node exhaustion never call the property"
      (let* ((calls 0) (property (lambda (_) (set! calls (+ calls 1)) #t))
             (depth (check-property trees.Tree property depth: 0 node-budget: 10))
             (nodes (check-property trees.Tree property depth: 10 node-budget: 0)))
        (check-equal? (.get depth status) 'exhausted)
        (check-equal? (reason depth) 'depth)
        (check-equal? (.get nodes status) 'exhausted)
        (check-equal? (reason nodes) 'nodes)
        (check-equal? calls 0)
        (check-equal? (.get (replay-property depth) status) 'exhausted)))
    (test-case "nonproductive carrier cycles exhaust depth, not divergence"
      (let* ((loop (.o self: self inherit: [Pair.] left: Integer right: self sexp: 'Loop))
             (report (check-property loop true depth: 12 node-budget: 100)))
        (check-equal? (.get report status) 'exhausted)
        (check-equal? (reason report) 'depth)))
    (test-case "transparent alias cycles are refused before recursive Type recognition"
      (let* ((loop (.o self: self inherit: [Union.] (types (list self Bool)) sexp: 'Alias))
             (report (check-property loop true)))
        (check-equal? (.get report status) 'unsupported)
        (check-equal? (reason report) 'unguarded)
        (check-equal? (.get report trial) 0)
        (check (.get report replayable?) => #f)
        (check-exception (replay-property report) Error?)))
    (test-case "shared-edge discovery and membership have independent work quotas"
      (let* ((descriptor (Tuple Integer Integer Integer))
             (compiled (check-property descriptor true descriptor-budget: 2))
             (parsed (check-property trees.Tree true search-budget: 1 depth: 8)))
        (check-equal? (reason compiled) 'descriptors)
        (check-equal? (reason parsed) 'search)
        (check-equal? (.get compiled status) 'exhausted)
        (check-equal? (.get parsed status) 'exhausted)))
    (test-case "minimum-cost selection reserves nodes for every mandatory sibling"
      (let* ((descriptor (Tuple (List trees.Tree) trees.Tree (Maybe trees.Tree)))
             (report (check-property descriptor (cut element? descriptor <>) seed: 88
                      cases: 200 depth: 8 node-budget: 5 size: 1000)))
        (check-equal? (.get report status) 'passed)))
    (test-case "empty finite alternatives are excluded without rejection sampling"
      (let* ((descriptor (Union (Enum) Integer))
             (report (check-property descriptor exact-integer? seed: 3 cases: 100)))
        (check-equal? (.get report status) 'passed))
      (check-equal? (.get (check-property (Enum) true) status) 'exhausted))
    (test-case "compiled samplers refuse descriptor changes before testing or replay"
      (let* ((descriptor (.o inherit: [List.] type: Integer sexp: 'Numbers))
             (sampler (generator descriptor 6)))
        (.putslot! descriptor 'type ($constant-slot-spec Bool))
        (let (report (check-property descriptor true sampler: sampler))
          (check-equal? (.get report status) 'stale)
          (check-equal? (.get report trial) 0)
          (check-exception (replay-property report) Error?))))
    (test-case "recursive carrier cycles are bounded refusals without native recursion"
      (let* ((descriptor (.o self: self inherit: [Union.]
                           (types (list Integer (Pair Integer self))) sexp: 'Chain))
             (sampler (generator descriptor 8)) (value (cons 1 #f)))
        (set-cdr! value value)
        (check (.call sampler .accept? value) => #f))
      (let* ((sampler (generator (List Integer) 8)) (value (list 1)))
        (set-cdr! value value)
        (check (.call sampler .accept? value) => #f)))
    (test-case "custom leaf exceptions retain identity and do not switch alternatives"
      (let* ((cause (Error "leaf"))
             (descriptor (.o self: self inherit: [Type.] .element?: exact-integer?
                           .generator: (lambda () (make-generator self
                             (lambda (_random _size) (raise cause)) (lambda (_) []) abs))))
             (report (check-property (Tuple descriptor) true)))
        (check-equal? (.get report status) 'error)
        (check (eq? (.get report cause) cause) => #t)))
    (test-case "bounded membership refuses larger witnesses without declaring the Type empty"
      (let (sampler (generator trees.Tree 8 node-budget: 2))
        (check (.call sampler .accept? 3) => #t)
        (check (element? trees.Tree '(1 2)) => #t)
        (check (.call sampler .accept? '(1 2)) => #f)))
    (test-case "shrink construction exhaustion retains the original false witness"
      (let* ((descriptor (List Integer))
             (base (generator descriptor 2 node-budget: 20 search-budget: 15))
             (sampler (.cc base draw: (lambda (_random _size) '(8 8 8 8 8 8))))
             (report (check-property descriptor false sampler: sampler))
             (again (replay-property report)))
        (check-equal? (.get report status) 'exhausted)
        (check-equal? (reason report) 'candidates)
        (check-equal? (.get report original) '(8 8 8 8 8 8))
        (check (.get report minimal?) => #f)
        (check-equal? (.get report limits search) 15)
        (check-equal? (reason again) 'candidates)))
    (test-case "compilation-time descriptor mutation cannot capture fresh authority"
      (let* ((root #f) (calls 0)
             (child (.o self: self inherit: [Type.] .element?: exact-integer?
               .generator: (lambda ()
                 (.putslot! root 'type ($constant-slot-spec Bool))
                 (make-generator self (lambda (_random _size) 1) (lambda (_) []) abs)))))
        (set! root (List child))
        (let (report (check-property root (lambda (_) (set! calls (+ calls 1)) #t)))
          (check-equal? (.get report status) 'stale)
          (check-equal? calls 0)
          (check-exception (replay-property report) Error?))))
    (test-case "repeated draws use their explicit seed, with no cross-run memo reuse"
      (let* ((first (check-property trees.Tree false seed: 99 cases: 1 size: 5 shrink-budget: 0))
             (_other (check-property trees.Message true seed: 101 cases: 50 size: 5))
             (next (replay-property first)))
        (check-equal? (.get first original) (.get next original))
        (check-equal? (.get first counterexample) (.get next counterexample))))))
