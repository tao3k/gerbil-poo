;;; Automatic recursive generation, bounded membership, shrinking and replay.
(export recursive-generation-test)
(import (only-in :std/list/list take drop) (prefix-in :clan/poo/testing/property/generator core.) :std/test :std/error :std/iter :clan/poo/object :clan/poo/mop :clan/poo/type :clan/poo/number
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
    (test-case "typed recursive Lists share complete structural deletion and value callbacks"
      (def descriptor (List UInt))
      (def sampler (generator descriptor))
      (def candidates (.call sampler shrink '(11 99 22)))
      (check (and (member '(11 22) candidates) #t) => #t)
      (check (and (member '(11 99) candidates) #t) => #t)
      (def generation (generator-core sampler))
      (def root (let find ((seed 0))
        (when (= seed 100) (error "fixture needs a nontrivial typed list"))
        (def tree (core.generate generation (core.random-at seed) 5))
        (if (>= (length (core.sample-value tree)) 3) tree (find (1+ seed)))))
      (def original (core.sample-value root))
      (def expected (append (take original 1) (drop original 2)))
      ;; Stop at the retained witness without draining the lazy Iterator.
      (def found (let/cc return
        (for (child ((core.sample-children root)))
          (when (and (core.sample? child) (equal? (core.sample-value child) expected))
            (return #t)))
        #f))
      (check-eq? found #t)
      (def callbacks 0)
      (define-type GuardedLeaf (.cc Type. .element?: exact-integer?
        .generator: (lambda () (make-generator GuardedLeaf (lambda (_random _) 1)
          (lambda (_) (set! callbacks (1+ callbacks)) []) abs))))
      (def limited (generator (List GuardedLeaf) search-budget: 6))
      (check-exception (.call limited shrink '(1 2 3 4)) (limited? 'search))
      (check-equal? callbacks 0))
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
    (test-case "work and candidate exhaustion retain the original false witnesses"
      ;; Keep the six-element workload: root + nine structural reservations + six
      ;; child walks exceed 15. Four elements fit that work but yield >15
      ;; candidates. Both phases retain exact refusal kinds, inputs and replay.
      (for (fixture (list (cons '(8 8 8 8 8 8) 'search)
                         (cons '(8 8 8 8) 'candidates)))
        (let* ((descriptor (List Integer))
               (base (generator descriptor 2 node-budget: 20 search-budget: 15))
               (sampler (.cc base draw: (lambda (_random _size) (car fixture))))
               (report (check-property descriptor false sampler: sampler))
               (again (replay-property report)))
          (check-equal? (.get report status) 'exhausted)
          (check-equal? (reason report) (cdr fixture))
          (check-equal? (.get report original) (car fixture))
          (check (.get report minimal?) => #f)
          (check-equal? (.get report limits search) 15)
          (check-equal? (reason again) (cdr fixture)))))
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
    (test-case "recursive scalar admission refuses before measure or a shared sibling"
      (for (action '(admit measure shrink))
        (def owner (.o epoch: 0)) (def armed #f) (def admissions 0) (def measures 0)
        (define-type Leaf (.cc Type. .element?: (lambda (value)
          (when armed (set! admissions (1+ admissions))
            (.putslot! owner 'epoch ($constant-slot-spec (1+ (.get owner epoch)))))
          (exact-integer? value))
          .generator: (lambda () (make-generator Leaf (lambda (_random _size) 1) (lambda (_) [])
            (lambda (_) (set! measures (1+ measures)) 1) dependencies: (list owner)))))
        (def sampler (generator (Tuple Leaf Leaf)))
        (set! armed #t)
        (check-exception (case action
          ((admit) (.call sampler .accept? #(1 1)))
          ((measure) (.call sampler measure #(1 1)))
          ((shrink) (.call sampler shrink #(1 1)))) (limited? 'stale))
        (check-equal? (list admissions measures) '(1 0))))
    (test-case "recursive scalar measure and shrink preserve causes and stop later work"
      (for (mode '(revise error shrink-error))
        (def owner (.o epoch: 0)) (def armed #f) (def measures 0) (def shrinks 0)
        (def cause (cons 'scalar mode))
        (define-type Leaf (.cc Type. .element?: exact-integer?
          .generator: (lambda () (make-generator Leaf (lambda (_random _size) 1)
            (lambda (_) (set! shrinks (1+ shrinks))
              (when armed (.putslot! owner 'epoch ($constant-slot-spec (1+ (.get owner epoch)))) (raise cause)) [])
            (lambda (_) (set! measures (1+ measures))
              (when (and armed (not (eq? mode 'shrink-error)))
                (.putslot! owner 'epoch ($constant-slot-spec (1+ (.get owner epoch))))
                (when (eq? mode 'error) (raise cause))) 1) dependencies: (list owner)))))
        (def sampler (generator (Tuple Leaf Leaf)))
        (set! armed #t)
        (def result (with-catch identity (lambda ()
          (if (eq? mode 'shrink-error) (.call sampler shrink #(1 1)) (.call sampler measure #(1 1))))))
        (if (eq? mode 'revise) (check ((limited? 'stale) result) => #t) (check-eq? result cause))
        (check-equal? measures (if (eq? mode 'shrink-error) 2 1))
        (check-equal? shrinks (if (eq? mode 'shrink-error) 1 0))))
    (test-case "recursive bridge preparation refuses before binding the next scalar"
      (def owner (.o epoch: 0)) (def bindings 0)
      ;; Distinct scalar Types share one owner; each custom bridge is built once.
      (def (sampler type)
        (.cc (make-generator type (lambda (_random _size) 1) (lambda (_) []) abs dependencies: (list owner))
          generation: (lambda (_self)
            (set! bindings (1+ bindings))
            (.putslot! owner 'epoch ($constant-slot-spec (1+ (.get owner epoch))))
            (core.generator-unit 1))))
      (define-type Left (.cc Type. .element?: exact-integer? .generator: (lambda () (sampler Left))))
      (define-type Right (.cc Type. .element?: exact-integer? .generator: (lambda () (sampler Right))))
      (check-exception (generator (Tuple Left Right)) (limited? 'stale))
      (check-equal? bindings 1))
    (test-case "shared Record leaves stop recursive work and fresh FUN actions shrink and replay"
      (for (target '(admit weight))
        (def owner (.o epoch: 0)) (def armed #t) (def calls [])
        ;; Test metadata stays independent of the private descriptor graph.
        (def (trigger phase)
          (set! calls (append calls (list phase)))
          (when (and armed (eq? phase target))
            (.putslot! owner 'epoch ($constant-slot-spec (1+ (.get owner epoch))))))
        (def configuration (make-instance PropertyConfiguration seed: 31 cases: 1 size: 3 shrink-budget: 30
          depth: 8 node-budget: 128 search-budget: 20000))
        (def old (trees.source-tree-tests owner trigger identity))
        (let (report (old configuration))
          (check-eq? (.get report status) 'stale)
          (check-eq? (last calls) target)
          (check-equal? (length (filter (cut eq? <> target) calls)) 1)
          (check-equal? (filter (cut eq? <> 'property) calls) [])
          (check-exception (replay-property report) Error?))
        (set! armed #f) (set! calls [])
        (let (report ((trees.source-tree-tests owner trigger identity) configuration))
          (check-eq? (.get report status) 'failed)
          (check-eq? (.get (replay-property report) status) 'failed)
          (check (replay-counterexample report) => #f)
          (check-exception ((.@ (car (vector-ref (.get report counterexample) 1)) handler) 'invalid) TypeError?)
          (check (and (memq 'property calls) #t) => #t))))
    (test-case "repeated draws use their explicit seed, with no cross-run memo reuse"
      (let* ((first (check-property trees.Tree false seed: 99 cases: 1 size: 5 shrink-budget: 0))
             (_other (check-property trees.Message true seed: 101 cases: 50 size: 5))
             (next (replay-property first)))
        (check-equal? (.get first original) (.get next original))
        (check-equal? (.get first counterexample) (.get next counterexample))))))
