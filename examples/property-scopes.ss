;;; Run-local admission through retained generator algebra and seeded replay.
(export declaration-test-cases! copy-test-cases! function-test-cases! assertion-test-cases! scope-test-cases! nested-scope-test-cases! classification-test-cases! codec-scope-test-cases!)
(import :std/test :std/error :std/iter
        (prefix-in (only-in :std/test/base TestConfig TestCase TestResultError
          test-case! test-result-error? current-test-config current-test-exit) test.) (only-in :std/list/list delete-duplicates/hash)
        (prefix-in :clan/poo/testing/property/test assertion.)
        (prefix-in :clan/poo/testing/property/generator generator.)
        (prefix-in :clan/poo/testing/property property.)
        (prefix-in :clan/poo/testing/property/replay replay.))

;; Copy admission covers constructor identities, encoded envelopes and imported
;; data through the same public codec boundary; no private copier is exported.
(def (copy-test-cases!)
  ;; Resource refusal has one established diagnostic across every data carrier.
  (def (budget? cause)
    (and (Error? cause) (equal? (Error-message cause) "replay data budget exceeded")))
  (test-case "portable vector width is admitted before contents and uses remaining fuel"
    (def wide (make-vector 64 #f))
    (vector-set! wide 0 values)
    (check-exception (replay.make-codec wide values values nodes: 8) budget?)
    ;; The first child spends four nodes; only one remains for the next child.
    ;; Its width two is impossible despite fitting the original node allowance.
    (check-exception (replay.make-codec (vector #(a b c) (vector values #f))
      values values nodes: 7) budget?))
  (test-case "portable exact width and depth boundaries preserve empty vectors"
    (check (and (replay.make-codec #(a b) values values nodes: 3 depth: 1) #t) => #t)
    (check-exception (replay.make-codec #(a b) values values nodes: 2 depth: 1) budget?)
    (check (and (replay.make-codec #(#()) values values nodes: 2 depth: 1) #t) => #t)
    (check-exception (replay.make-codec #(#(a)) values values nodes: 3 depth: 1) budget?)
    (def cycle (make-vector 1))
    (vector-set! cycle 0 cycle)
    (check-exception (replay.make-codec cycle values values nodes: 16 depth: 4) budget?))
  (test-case "portable feasible vectors retain forward first-error order"
    (def first (lambda () 'first)) (def last (lambda () 'last))
    (def cause (with-catch values (lambda ()
      (replay.make-codec (vector first last) values values nodes: 8))))
    (check-equal? (Error-message cause) "nonportable replay datum")
    (check-eq? (car (Error-irritants cause)) first))
  (test-case "portable envelope budget is shared and successful copies detach mutable data"
    (def identity (vector 'bounded 1)) (def value (vector 'a 'b)) (def decoded #f)
    (def domain (property.make-specification vector? (lambda (_) 0)))
    (def report (property.check-property (generator.generator-unit value) (lambda (_) #f)
      domain cases: 1 shrink-budget: 0))
    ;; Envelope costs one root, two tags, a three-node identity and a three-node
    ;; payload: nine nodes in total. Per-child counters must not reset that sum.
    (def output (open-output-string))
    (check-exception (replay.write-counterexample report
      (replay.make-codec identity values values nodes: 8 depth: 2) output) budget?)
    (check-equal? (get-output-string output) "")
    (def codec (replay.make-codec identity values
      (lambda (datum) (set! decoded datum) datum) nodes: 9 depth: 2))
    (vector-set! identity 0 'changed)
    (replay.write-counterexample report codec output)
    (vector-set! value 0 'changed)
    (check (replay.read-counterexample codec (open-input-string (get-output-string output))
      domain (lambda (_) #f)) => #f)
    (check-equal? decoded #(a b))
    (check (eq? decoded value) => #f)
    ;; Compact strings/bytes spend payload units from that same node allowance.
    (def mixed (vector "ab" (list->u8vector '(1 2)) #f))
    (def mixed-report (property.check-property (generator.generator-unit mixed) (lambda (_) #f)
      domain cases: 1 shrink-budget: 0))
    (def mixed-output (open-output-string))
    (check-exception (replay.write-counterexample mixed-report
      (replay.make-codec 'mixed values values nodes: 11) mixed-output) budget?)
    (def mixed-codec (replay.make-codec 'mixed values values nodes: 12))
    (replay.write-counterexample mixed-report mixed-codec mixed-output)
    (check (replay.read-counterexample mixed-codec (open-input-string (get-output-string mixed-output))
      domain (lambda (datum) (string-set! (vector-ref datum 0) 0 #\z)
        (u8vector-set! (vector-ref datum 1) 0 9) #f)) => #f)
    (check-equal? (vector-ref mixed 0) "ab")
    (check-equal? (u8vector-ref (vector-ref mixed 1) 0) 1))
  (test-case "portable over-budget import skips decoding and retries without widening limits"
    (def decoded 0) (def properties 0)
    (def codec (replay.make-codec 'bounded values
      (lambda (datum) (set! decoded (1+ decoded)) datum) nodes: 16))
    (def domain (property.make-specification vector? (lambda (_) 0)))
    (def oversized (open-output-string))
    (write (vector 'property-counterexample 1 'bounded (make-vector 64 #f)) oversized)
    (check-exception (replay.read-counterexample codec (open-input-string (get-output-string oversized))
      domain (lambda (_) (set! properties (1+ properties)) #f)) budget?)
    (check-equal? (list decoded properties) '(0 0))
    (def output (open-output-string))
    (def report (property.check-property (generator.generator-unit #(#f)) (lambda (_) #f)
      domain cases: 1 shrink-budget: 0))
    (replay.write-counterexample report codec output)
    (check (replay.read-counterexample codec (open-input-string (get-output-string output))
      domain (lambda (_) (set! properties (1+ properties)) #f)) => #f)
    (check-equal? (list decoded properties) '(1 1))))

;; Exercise each public observation under the same transient and retained owners.
;; A procedure delegates invocation to function-apply; no second dispatcher exists.
(def (function-test-cases!)
  (def observations
    (list generator.function-domain generator.function-table
      (cut generator.function-apply <> '(request))
      (lambda (value) ((generator.function-procedure value) 'request))))
  (test-case "finite observations inherit retired run checks before local observers"
    (for (observe observations)
      (def active? #t) (def calls 0) (def cause (Error "retired function caller"))
      (def value (generator.function-from-table '(((request) 7))
        current?: (lambda () (set! calls (1+ calls)) #t)))
      (check-exception
        (generator.with-generation-check (lambda () (unless active? (raise cause)))
          (set! active? #f) (observe value))
        (lambda (found) (eq? found cause)))
      (check-equal? calls 0)))
  (test-case "finite observations inherit retained leaves and refuse stale own tables"
    (for (observe observations)
      (def active? #t) (def calls 0)
      (def value (generator.function-from-table '(((request) 7))
        current?: (lambda () (set! calls (1+ calls)) #t)))
      (check-exception
        (generator.with-sources (list (lambda () active?))
          (set! active? #f) (observe value)) generator.stale-generation?)
      (check-equal? calls 0)
      (check-exception (observe (generator.function-from-table '(((request) 7))
        current?: (lambda () #f))) generator.stale-generation?)))
  (test-case "finite observation errors retain observer identity and strict booleans"
    (for (observe observations)
      (def cause (Error "function observer"))
      (check-exception (observe (generator.function-from-table '(((request) 7))
        current?: (lambda () (raise cause)))) (lambda (found) (eq? found cause)))
      (check-exception (observe (generator.function-from-table '(((request) 7))
        current?: (lambda () 'truthy))) Error?)))
  (test-case "finite calls preserve raw keyword rows multiple values and detached spines"
    (def entries '(((request) 7 8) ((request scale: 2) 9 10)))
    (def value (generator.function-from-table entries))
    (check-equal? (call-with-values (cut (generator.function-procedure value) 'request scale: 2) list) '(9 10))
    (check-exception ((generator.function-procedure value) 'request scale: 3) Error?)
    (def domain (generator.function-domain value))
    (set-car! (car domain) 'changed)
    (def table (generator.function-table value))
    (set-car! (cdar table) 99)
    (check-equal? (generator.function-domain value) '((request) (request scale: 2)))
    (check-equal? (generator.function-table value) entries)
    (check-equal? (generator.function-apply value '(request)) '(7 8)))
  (test-case "finite call scopes unwind without retaining a caller or its failure"
    (def active? #t)
    (def value (generator.function-from-table '(((request) 7))))
    (generator.with-sources (list (lambda () active?))
      (check-equal? (generator.function-apply value '(request)) '(7)))
    (set! active? #f)
    (check-equal? (generator.function-apply value '(request)) '(7))
    (check-exception
      (generator.with-generation-check (lambda () (error "caller refused"))
        (generator.function-table value)) Error?)
    (check-equal? (generator.function-table value) '(((request) 7))))
  (test-case "finite calls interrupt retired properties and codec encoders before continuation"
    (def active? #t) (def after 0)
    (def value (generator.function-from-table '(((request) 7))))
    (def domain (property.make-specification generator.function-value? (lambda (_) 0)
      current?: (lambda () active?)))
    (def report (property.check-property (generator.generator-unit value)
      (lambda (function) (set! active? #f) (generator.function-apply function '(request))
        (set! after (1+ after)) #f) domain cases: 1 shrink-budget: 0))
    (check-eq? (property.report-status report) 'stale)
    (check-equal? after 0)
    (set! active? #t)
    (def failed (property.check-property (generator.generator-unit value) (lambda (_) #f)
      domain cases: 1 shrink-budget: 0))
    (def codec (replay.make-codec '(finite-call 1)
      (lambda (function) (set! active? #f) (generator.function-table function)
        (set! after (1+ after)) []) generator.function-from-table current?: (lambda () active?)))
    (def output (open-output-string))
    (check-exception (replay.write-counterexample failed codec output) Error?)
    (check-equal? after 0)
    (check-equal? (get-output-string output) "")))

;; Each root advances an application epoch. Ownership can belong to the root
;; or to a subsequently observed child; neither path invents a report owner.
(def (epoch-generator advance capture transform child-source?: (child-source? #f))
  (generator.generator-map (generator.make-tree-generator (lambda (_random _size)
    (advance)
    (if child-source?
      (generator.make-sample 9 (lambda ()
        (list (generator.make-sample 0 (lambda () []) (capture)))))
      (generator.make-sample 9 (lambda () []) (capture))))) transform))

;; Ordinary case registration keeps the same standard suite and runner.
(def (scope-test-cases!)
  (test-case "source union retains last-observer order and unwinds original errors"
    (def visits [])
    ;; Distinct observers expose ordering without changing their Boolean judgment.
    (def observers (map (lambda (tag)
      (cons tag (lambda () (set! visits (cons tag visits)) #t))) '(a b c)))
    (for* ((left '((a b) (b a) (a b c))) (right '((a) (b a) (b c b) ())))
      (def observed #f)
      (generator.with-sources (map (lambda (tag) (cdr (assq tag observers))) left)
        (set! visits [])
        (generator.with-sources (map (lambda (tag) (cdr (assq tag observers))) right)
          (set! observed (reverse visits))))
      (check-equal? observed (delete-duplicates/hash (append left right))))
    (def live #t) (def cause (cons 'original 'scope-error))
    (check-eq? (with-catch identity (lambda ()
      (generator.with-sources (list (lambda () live)) (raise cause)))) cause)
    (set! live #f)
    (check-equal? (generator.sample-value (generator.generate
      (generator.generator-unit 7) (generator.random-at 1) 0)) 7))
  (test-case "earlier trials and inspection roots guard nested later construction"
    (for (kind '(pass discard inspect))
      (def epoch 0) (def mapped 0) (def properties 0)
      (def generation (epoch-generator (lambda () (set! epoch (1+ epoch)))
        (lambda () (let (stamp epoch) (lambda () (= stamp epoch))))
        (lambda (value) (set! mapped (1+ mapped)) value)))
      (def domain (property.make-specification exact-integer? abs))
      (if (eq? kind 'inspect)
        (let (result (property.inspect-generator generation domain count: 2))
          (check-eq? (property.inspection-status result) 'stale)
          (check-equal? (length (property.inspection-events result)) 1)
          (check-equal? (property.inspection-draws result) 2)
          (check-eq? (property.inspection-cause result) #f))
        (let (report (property.check-property generation
            (lambda (_) (set! properties (1+ properties)) #t) domain cases: 2
            policy: (property.make-policy precondition: (lambda (_) (not (eq? kind 'discard))) discard-budget: 1)))
          (check-eq? (property.report-status report) 'stale)
          (check-eq? (property.report-cause report) #f)
          (check-equal? (property.report-attempts report) 0)
          (check-equal? properties (if (eq? kind 'pass) 1 0))))
      (check-equal? mapped 1)))
  (test-case "replay refuses a retired shrink owner before a new root mapper"
    (def epoch 0) (def mapped 0)
    (def generation (epoch-generator (lambda () (set! epoch (1+ epoch)))
      (lambda () (let (stamp epoch) (lambda () (= stamp epoch))))
      (lambda (value) (set! mapped (1+ mapped)) value) child-source?: #t))
    (def report (property.check-property generation (lambda (value) (< value 1))
      (property.make-specification exact-integer? abs) cases: 1 shrink-budget: 4))
    (check-equal? (list (property.report-status report) (property.report-counterexample report)
      (property.report-attempts report) mapped) '(failed 9 1 2))
    (def replay (property.replay-property report))
    (check-equal? (list (property.report-status replay) (property.report-attempts replay)
      (property.report-counterexample replay) (property.report-cause replay) mapped) '(stale 0 #f #f 2))
    (check-exception (property.replay-property report) Error?)
    (check-equal? (generator.sample-value
      (generator.generate (generator.generator-unit 42) (generator.random-at 3) 5)) 42))
  (test-case "transient checks compose unwind and stay out of retained tree ownership"
    (def outer #t) (def inner #t) (def mapped 0)
    (def cause (Error "outer generation check")) (def inner-cause (Error "inner generation check"))
    (check-eq? (with-catch identity (lambda ()
      (generator.with-generation-check (lambda () (unless outer (raise cause)))
        (generator.with-generation-check (lambda () (unless inner (raise inner-cause)))
          (generator.generate (generator.generator-map
            (generator.make-generator (lambda (_random _size) (set! outer #f) (set! inner #f) 9) generator.integer-shrinks)
            (lambda (value) (set! mapped (1+ mapped)) value)) (generator.random-at 2) 5))))) cause)
    (check-equal? mapped 0)
    (check-equal? (generator.sample-value
      (generator.generate (generator.generator-unit 3) (generator.random-at 2) 5)) 3)
    (def entered 0)
    (check-exception (generator.with-generation-check #f (set! entered 1)) Error?)
    (check-equal? entered 0)
    (def active #t) (def checks 0)
    (def root (generator.with-generation-check
      (lambda () (set! checks (1+ checks)) (unless active (raise cause)))
      (generator.generate (generator.make-generator (lambda (_random _size) 9) (lambda (_) '(0)))
        (generator.random-at 2) 5)))
    (check-equal? (generator.sample-sources root) [])
    ;; This is a phase snapshot, not another internal definition: capture after
    ;; root construction before testing that later child demand adds no checks.
    (let (completed-checks checks)
      (set! active #f)
      (check-equal? (for/collect (child ((generator.sample-children root))) (generator.sample-value child)) '(0))
      (check-equal? checks completed-checks))
    (def effects 0)
    (def paused (generator.generate (generator.make-generator (lambda (_random _size) 9)
      (lambda (_) (in-coroutine (lambda (yield) (yield 0) (set! effects (1+ effects)) (yield 1)))))
      (generator.random-at 2) 5))
    (set! active #t)
    (check-eq? (with-catch identity (lambda ()
      (generator.with-generation-check (lambda () (unless active (raise cause)))
        (using (cursor (iter ((generator.sample-children paused))) :- Iterator)
          ;; A resumable coroutine captures its caller's dynamic context. Pull
          ;; outside the assertion so later refusal keeps this scope's handler.
          (let (first (cursor.next!))
            (check-equal? (generator.sample-value first) 0)
            (set! active #f)
            (cursor.next!)))))) cause)
    (check-equal? effects 0))
  (test-case "repeated replay keeps a stable observer cost without retaining prior run checkers"
    (def checks 0)
    (def generation (generator.make-generator (lambda (_random _size) 3) generator.integer-shrinks
      current?: (lambda () (set! checks (1+ checks)) #t)))
    (def report (property.check-property generation (lambda (value) (< value 1))
      (property.make-specification exact-integer? abs) cases: 1 shrink-budget: 8))
    (def costs [])
    (for (_ (in-range 12))
      (set! checks 0)
      (set! report (property.replay-property report))
      (set! costs (cons checks costs))
      (check-eq? (property.report-status report) 'failed)
      (check-equal? (property.report-counterexample report) 1))
    (check (> (car costs) 0) => #t)
    (check (every (lambda (cost) (= cost (car costs))) costs) => #t)))

;; Ordinary producer ownership supplies an ancestor without a second runner.
(def (under-owner action current)
  (with-catch identity (lambda ()
    (generator.generate (generator.make-generator (lambda (_random _size) (action))
      (lambda (_) []) current?: current) (generator.random-at 11) 0))))

;; Nested admission uses the same standard suite and public module protocol.
(def (nested-scope-test-cases!)
  (test-case "nested product weights inherit producer sources before the next field"
    (def live #t) (def first 0) (def later 0)
    (def domain (property.make-product-specification
      (list (property.make-specification exact-integer? (lambda (_)
              (set! first (1+ first)) (set! live #f) 1))
            (property.make-specification exact-integer? (lambda (_) (set! later (1+ later)) 1)))))
    (check (generator.stale-generation? (under-owner
      (lambda () (property.specification-weight domain '(1 2))) (lambda () live))) => #t)
    (check-equal? (list first later) '(1 0)))
  (test-case "terminal child reports cannot escape an obsolete ancestor or recurse in their own guard"
    (for (kind '(check inspect))
      (def parent-live #t) (def child-live #t) (def after 0) (def closed 0)
      (def parent (property.make-specification exact-integer? abs current?: (lambda () parent-live)))
      (def child (property.make-specification exact-integer? abs current?: (lambda () child-live)))
      ;; Both scopes become obsolete. The child's local stop must unwind before
      ;; ancestor admission, so no checker can invoke itself through that stop.
      (def (invalidate _)
        (set! parent-live #f) (set! child-live #f) #t)
      (def report (property.check-property (generator.generator-unit 1) (lambda (_)
        (try
          (case kind
            ((check) (property.check-property (generator.generator-unit 1) invalidate child cases: 1))
            ((inspect) (property.inspect-generator (generator.generator-unit 1) child count: 1
              labels: (lambda (value) (invalidate value) []))))
          (set! after (1+ after)) #t
          (finally (set! closed (1+ closed))))) parent cases: 1))
      (check-eq? (property.report-status report) 'stale)
      (check-equal? (list after closed) '(0 1))))
  (test-case "portable stages inherit ancestors before encoding writing or property admission"
    (for (stage '(reconfirm encode decode))
      (def live #t) (def armed #f) (def encodes 0) (def admissions 0) (def properties 0)
      (def domain (property.make-specification (lambda (value)
        (set! admissions (1+ admissions)) (exact-integer? value)) abs))
      ;; The witness remains valid in its own domain; only the enclosing run ends.
      (def (predicate _)
        (set! properties (1+ properties))
        (when (and armed (eq? stage 'reconfirm)) (set! live #f)) #f)
      (def report (property.check-property (generator.generator-unit 1) predicate domain cases: 1 shrink-budget: 0))
      (def codec (replay.make-codec 'scope
        (lambda (value) (set! encodes (1+ encodes))
          (when (eq? stage 'encode) (set! live #f)) value)
        (lambda (value) (set! live #f) value)))
      (def output (open-output-string))
      (set! admissions 0) (set! properties 0) (set! armed #t)
      (def result (under-owner (lambda ()
        (if (eq? stage 'decode)
          (replay.read-counterexample codec
            (open-input-string "#(property-counterexample 1 scope 1)") domain predicate)
          (replay.write-counterexample report codec output))) (lambda () live)))
      (check (generator.stale-generation? result) => #t)
      (check-equal? (get-output-string output) "")
      (check-equal? encodes (if (eq? stage 'encode) 1 0))
      (when (eq? stage 'decode) (check-equal? (list admissions properties) '(0 0)))))
  (test-case "nested codec callback exceptions retain identity even after ancestor revision"
    (def live #t) (def cause (cons 'codec 'cause))
    (def report (property.check-property (generator.generator-unit 1) (lambda (_) #f)
      (property.make-specification exact-integer? abs) cases: 1 shrink-budget: 0))
    (def codec (replay.make-codec 'cause (lambda (_)
      (set! live #f) (raise cause)) identity))
    (def output (open-output-string))
    (check-eq? (under-owner (lambda () (replay.write-counterexample report codec output)) (lambda () live)) cause)
    (check-equal? (get-output-string output) ""))
  (test-case "fresh nested reports preserve outcomes without retaining ancestor guards"
    (def visits 0)
    (def domain (property.make-specification exact-integer? abs))
    ;; Finite nesting checks normal child report publication as well as unwinding.
    (def (nested depth)
      (property.check-property (generator.generator-unit 1) (lambda (_)
        (set! visits (1+ visits))
        (or (zero? depth) (eq? (property.report-status (nested (1- depth))) 'passed))) domain cases: 1))
    (check-eq? (property.report-status (nested 8)) 'passed)
    (check-equal? visits 9)
    (check-equal? (property.specification-weight (property.make-product-specification []) []) 0)
    (check-eq? (property.report-status (nested 0)) 'passed)
    (check-equal? visits 10)))


;; Classification shares the execution/inspection source boundary. The original
;; callback cause and confirmed progress belong to the report, not its classifier.
(def (classification-test-cases!)
  (test-case "execution and inspection classify under their own current sources"
    (def live #t) (def calls 0) (def properties 0) (def cause (cons 'draw 'original))
    (def domain (property.make-specification exact-integer? abs current?: (lambda () live)))
    (def generation (generator.make-generator (lambda (_random _size) (raise cause)) (lambda (_) [])))
    ;; Ending this owner's authority cannot publish the normal classification.
    (def (classify _) (set! calls (1+ calls)) (set! live #f) 'unsupported)
    (def report (property.check-property generation (lambda (_) (set! properties (1+ properties)) #t)
      domain cases: 1 classify-error: classify))
    (check-eq? (property.report-status report) 'stale)
    (check-eq? (property.report-cause report) cause)
    (check-equal? (list calls properties (property.report-attempts report) (property.report-steps report)) '(1 0 0 0))
    (check-exception (property.replay-counterexample report) Error?)
    (set! live #t)
    (def inspection (property.inspect-generator generation domain count: 1 classify-error: classify))
    (check-eq? (property.inspection-status inspection) 'stale)
    (check-eq? (property.inspection-cause inspection) cause)
    (check-equal? (list calls (property.inspection-draws inspection) (property.inspection-attempts inspection)) '(2 1 0)))
  (test-case "classification suppresses obsolete nested generation and unwinds its scope"
    (def live #t) (def mapped 0) (def cause (cons 'failed 'root))
    (def generation (generator.make-generator (lambda (_random _size) (raise cause)) (lambda (_) [])))
    (def domain (property.make-specification exact-integer? abs current?: (lambda () live)))
    ;; The shared checker must interrupt before the mapper, not after classification.
    (def (classify _)
      (set! live #f)
      (generator.generate (generator.generator-map (generator.generator-unit 1)
        (lambda (value) (set! mapped (1+ mapped)) value)) (generator.random-at 3) 0)
      'unsupported)
    (def report (property.check-property generation (lambda (_) #t) domain cases: 1 classify-error: classify))
    (check-eq? (property.report-status report) 'stale)
    (check-eq? (property.report-cause report) cause)
    (check-equal? mapped 0)
    (check-eq? (property.report-status (property.check-property (generator.generator-unit 1)
      (lambda (_) #t) (property.make-specification exact-integer? abs) cases: 1)) 'passed))
  (test-case "secondary classifier and observer errors keep the original failure"
    (for (stage '(classifier observer))
      (def broken #f) (def calls 0) (def cause (cons stage 'original)) (def secondary (cons stage 'secondary))
      ;; A failing observer is an error, never a fabricated stale judgment.
      (def (current) (if broken (raise secondary) #t))
      (def generation (generator.make-generator (lambda (_random _size)
        (when (eq? stage 'observer) (set! broken #t)) (raise cause)) (lambda (_) [])))
      (def report (property.check-property generation (lambda (_) #t)
        (property.make-specification exact-integer? abs current?: current) cases: 1
        classify-error: (lambda (_) (set! calls (1+ calls)) (raise secondary))))
      (check-eq? (property.report-status report) 'error)
      (check-eq? (property.report-cause report) cause)
      (check-equal? calls (if (eq? stage 'classifier) 1 0))))
  (test-case "stale and bounded exhaustion retain precedence without calling a classifier"
    (def calls 0)
    ;; Built-in bounded outcomes bypass caller-specific error interpretation.
    (def (classify _) (set! calls (1+ calls)) 'unsupported)
    (for (kind '(stale exhausted))
      (let* ((generation (if (eq? kind 'stale)
               (generator.make-generator (lambda (_random _size) 1) (lambda (_) []) current?: (lambda () #f))
               (generator.generator-delay (lambda () (generator.generator-unit 1)) depth: 0)))
             (report (property.check-property generation (lambda (_) #t)
               (property.make-specification exact-integer? abs) cases: 1 classify-error: classify)))
        (check-eq? (property.report-status report) kind)))
    (check-equal? calls 0))
  (test-case "classification refusal retains confirmed shrinking progress and exact cause"
    (def live #t) (def cause (cons 'property 'failure))
    (def generation (generator.make-generator (lambda (_random _size) 4)
      (lambda (value) (if (> value 2) (list (1- value)) []))))
    (def report (property.check-property generation (lambda (value) (if (= value 2) (raise cause) #f))
      (property.make-specification exact-integer? abs current?: (lambda () live)) cases: 1 shrink-budget: 10
      classify-error: (lambda (_) (set! live #f) 'unsupported)))
    (check-eq? (property.report-status report) 'stale)
    (check-eq? (property.report-cause report) cause)
    (check-equal? (list (property.report-original report) (property.report-counterexample report)
      (property.report-attempts report) (property.report-steps report) (property.report-minimal? report)) '(4 3 2 1 #f))
    (check-exception (property.replay-counterexample report) Error?))
  (test-case "fresh classifications replay without becoming passing or false evidence"
    (for (status '(error exhausted unsupported))
      (def cause (cons status 'original)) (def calls 0)
      (def generation (generator.make-generator (lambda (_random _size) (raise cause)) (lambda (_) [])))
      ;; Classification is run once per execution, including an explicit seed replay.
      (def (classify _) (set! calls (1+ calls)) status)
      (def report (property.check-property generation (lambda (_) #t)
        (property.make-specification exact-integer? abs) cases: 1 classify-error: classify))
      (def replayed (property.replay-property report))
      (check-eq? (property.report-status report) status)
      (check-eq? (property.report-status replayed) status)
      (check-eq? (property.report-cause replayed) cause)
      (check (property.report-current? report) => #t)
      (check-equal? calls 2)
      (check-exception (property.replay-counterexample report) Error?))))


;; Portable handoff scopes use standard checked actions inside application codecs.
;; No raw callback interruption or rollback of already consumed bytes is assumed.
(def (codec-scope-test-cases!)
  (test-case "codec and application revisions suppress nested encode and decode effects"
    (for (stage '(encode decode))
      (for (owner '(codec context))
        (def codec-live #t) (def context-live #t) (def mapped 0) (def properties 0)
        (def domain (property.make-specification exact-integer? abs current?: (lambda () context-live)))
        ;; A valid root witness is independent of codec authority until handoff.
        (def (predicate _) (set! properties (1+ properties)) #f)
        (def report (property.check-property (generator.generator-unit 2) predicate domain cases: 1 shrink-budget: 0))
        ;; Retire one local owner before starting a nested checked action.
        (def (transform value)
          (if (eq? owner 'codec) (set! codec-live #f) (set! context-live #f))
          (generator.generate (generator.generator-map (generator.generator-unit value)
            (lambda (value) (set! mapped (1+ mapped)) value)) (generator.random-at 1) 0)
          value)
        (def codec (replay.make-codec 'scope (if (eq? stage 'encode) transform identity)
          (if (eq? stage 'decode) transform identity) current?: (lambda () codec-live)))
        (def output (open-output-string))
        (set! properties 0)
        (check-exception (if (eq? stage 'encode) (replay.write-counterexample report codec output)
          (replay.read-counterexample codec (open-input-string "#(property-counterexample 1 scope 2)") domain predicate))
          (lambda (cause) (and (Error? cause) (equal? (Error-message cause)
            (if (eq? owner 'codec) "stale replay codec" "stale replay context")))))
        (check-equal? (list mapped properties (get-output-string output))
          (list 0 (if (eq? stage 'encode) 1 0) "")))))
  (test-case "witness reconfirmation inherits codec authority before nested work"
    (def live #t) (def armed #f) (def mapped 0) (def encodes 0)
    ;; Initial falsification is pure; export reconfirmation changes codec authority.
    (def (predicate value)
      (when armed
        (set! live #f)
        (generator.generate (generator.generator-map (generator.generator-unit value)
          (lambda (value) (set! mapped (1+ mapped)) value)) (generator.random-at 1) 0)) #f)
    (def report (property.check-property (generator.generator-unit 2) predicate
      (property.make-specification exact-integer? abs) cases: 1 shrink-budget: 0))
    (def codec (replay.make-codec 'scope (lambda (value) (set! encodes (1+ encodes)) value) identity current?: (lambda () live)))
    (def output (open-output-string))
    (set! armed #t)
    (check-exception (replay.write-counterexample report codec output) Error?)
    (check-equal? (list mapped encodes (get-output-string output)) '(0 0 "")))
  (test-case "nested portable scopes retain outer refusal priority and unwind cleanup"
    (def outer-live #t) (def inner-live #t) (def mapped 0) (def closed 0)
    (def domain (property.make-specification exact-integer? abs current?: (lambda () outer-live)))
    (def report (property.check-property (generator.generator-unit 2) (lambda (_) #f) domain cases: 1 shrink-budget: 0))
    (def inner (replay.make-codec 'scope identity (lambda (value)
      (set! outer-live #f) (set! inner-live #f)
      (try
        (generator.generate (generator.generator-map (generator.generator-unit value)
          (lambda (value) (set! mapped (1+ mapped)) value)) (generator.random-at 1) 0)
        value (finally (set! closed (1+ closed))))) current?: (lambda () inner-live)))
    (def outer (replay.make-codec 'scope (lambda (value)
      (try (replay.read-counterexample inner (open-input-string "#(property-counterexample 1 scope 2)")
          (property.make-specification exact-integer? abs) (lambda (_) #f))
        value (finally (set! closed (1+ closed))))) identity))
    (def output (open-output-string))
    (check-exception (replay.write-counterexample report outer output)
      (lambda (cause) (and (Error? cause) (equal? (Error-message cause) "stale replay context"))))
    (check-equal? (list mapped closed (get-output-string output)) '(0 2 "")))
  (test-case "codec exceptions retain exact identity after retiring both local sources"
    (for (stage '(encode decode))
      (def codec-live #t) (def context-live #t) (def cause (cons stage 'original))
      (def domain (property.make-specification exact-integer? abs current?: (lambda () context-live)))
      (def report (property.check-property (generator.generator-unit 2) (lambda (_) #f) domain cases: 1 shrink-budget: 0))
      ;; Throws skip trailing checks; a new observer error cannot replace this cause.
      (def (fault _) (set! codec-live #f) (set! context-live #f) (raise cause))
      (def codec (replay.make-codec 'scope (if (eq? stage 'encode) fault identity)
        (if (eq? stage 'decode) fault identity) current?: (lambda () codec-live)))
      (check-eq? (with-catch identity (lambda ()
        (if (eq? stage 'encode) (replay.write-counterexample report codec (open-output-string))
          (replay.read-counterexample codec (open-input-string "#(property-counterexample 1 scope 2)") domain (lambda (_) #f))))) cause)))
  (test-case "completed handoff does not retain its checker on child trees or reports"
    (def live #t) (def retained #f) (def child-report #f)
    (def domain (property.make-specification exact-integer? abs))
    (def report (property.check-property (generator.generator-unit 2) (lambda (_) #f) domain cases: 1 shrink-budget: 0))
    (def codec (replay.make-codec 'scope (lambda (value)
      (set! retained (generator.generate (generator.make-generator (lambda (_random _size) value)
        (lambda (value) (if (> value 0) [0] []))) (generator.random-at 1) 0))
      (set! child-report (property.check-property (generator.generator-unit value) (lambda (_) #t) domain cases: 1))
      value) identity current?: (lambda () live)))
    (def output (open-output-string))
    (replay.write-counterexample report codec output)
    (set! live #f)
    (check ((generator.sample-current retained)) => #t)
    (check-equal? (for/collect (child ((generator.sample-children retained))) (generator.sample-value child)) [0])
    (check (property.report-current? child-report) => #t)
    (check-eq? (property.report-status (property.replay-property child-report)) 'passed))
  (test-case "failed codec epochs need explicit preparation before successful handoff retry"
    (def epoch 0) (def encodes 0)
    ;; Each complete preparation captures an immutable epoch, not a freshening guard.
    (def (prepare revise?)
      (def stamp epoch)
      (def domain (property.make-specification exact-integer? abs current?: (lambda () (= stamp epoch))))
      (def report (property.check-property (generator.generator-unit 2) (lambda (_) #f) domain cases: 1 shrink-budget: 0))
      (def codec (replay.make-codec 'scope (lambda (value)
        (set! encodes (1+ encodes))
        (when revise? (set! epoch (1+ epoch)))
        (generator.generate (generator.generator-unit value) (generator.random-at 1) 0)
        value) identity current?: (lambda () (= stamp epoch))))
      (values report codec domain))
    (defvalues (old old-codec _old-domain) (prepare #t))
    (def output (open-output-string))
    (check-exception (replay.write-counterexample old old-codec output) Error?)
    (check-equal? (get-output-string output) "")
    (defvalues (fresh codec domain) (prepare #f))
    (replay.write-counterexample fresh codec output)
    (check (replay.read-counterexample codec (open-input-string (get-output-string output)) domain (lambda (_) #f)) => #f)
    (check-exception (replay.write-counterexample old old-codec (open-output-string)) Error?)
    (check-equal? encodes 2)))


;; Standard assertion admission uses actual reports; diagnostic callbacks supply
;; display fields only. The surrounding TestSuite owns all positive controls.
(def (assertion-test-cases!)
  (test-case "formatter fields cannot promote a failed report or replace false cause"
    (def calls 0) (def formats 0)
    (def report (property.check-property (generator.generator-unit 1)
      (lambda (_) (set! calls (1+ calls)) #f) (property.make-specification exact-integer? abs)
      cases: 1 shrink-budget: 0))
    (def failure (with-catch values (lambda () (assertion.require-passed report
      diagnostics: (lambda (_) (set! formats (1+ formats))
        '((status . passed) (cause . invented) (status . passed) (detail . rendered)))))))
    (check-equal? (Error-message failure) "property check did not pass")
    (def fields (Error-irritants failure))
    (check-eq? (cdr (assq 'status fields)) 'failed)
    (check-eq? (cdr (assq 'cause fields)) #f)
    (check-equal? (length (filter (lambda (field) (eq? (car field) 'status)) fields)) 1)
    (check-equal? (list calls formats) '(1 1)))
  (test-case "passed report authority interrupts obsolete nested rendering work"
    (def live #t) (def formats 0) (def mapped 0)
    (def report (property.check-property (generator.make-generator (lambda (_r _s) 1) (lambda (_) [])
      current?: (lambda () live)) positive? (property.make-specification exact-integer? abs) cases: 1))
    (def failure (with-catch values (lambda () (assertion.require-passed report
      diagnostics: (lambda (_)
        (set! formats (1+ formats)) (set! live #f)
        (generator.generate (generator.generator-map (generator.generator-unit 1)
          (lambda (value) (set! mapped (1+ mapped)) value)) (generator.random-at 0) 0)
        '((status . passed)))))))
    (check-eq? (cdr (assq 'status (Error-irritants failure))) 'stale)
    (check-equal? (list formats mapped) '(1 0))
    (check-equal? (generator.sample-value (generator.generate (generator.generator-unit 7) (generator.random-at 0) 0)) 7))
  (test-case "already stale passed reports suppress the formatter before any effect"
    (def live #t) (def formats 0)
    (def report (property.check-property (generator.make-generator (lambda (_r _s) 1) (lambda (_) [])
      current?: (lambda () live)) positive? (property.make-specification exact-integer? abs) cases: 1))
    (set! live #f)
    (def failure (with-catch values (lambda () (assertion.require-passed report
      diagnostics: (lambda (_) (set! formats (1+ formats)) '((status . passed)))))))
    (check-eq? (cdr (assq 'status (Error-irritants failure))) 'stale)
    (check-equal? formats 0))
  (test-case "original report failures outrank rendering faults"
    (def original (cons 'property 'fault)) (def secondary (cons 'render 'fault))
    (def report (property.check-property (generator.generator-unit 1) (lambda (_) (raise original))
      (property.make-specification exact-integer? abs) cases: 1))
    (def failure (with-catch values (lambda ()
      (assertion.require-passed report diagnostics: (lambda (_) (raise secondary))))))
    (def fields (Error-irritants failure))
    (check-eq? (cdr (assq 'status fields)) 'error)
    (check-eq? (cdr (assq 'cause fields)) original)
    (check-eq? (cdr (assq 'diagnostic-cause fields)) secondary))
  (test-case "passing formatter and observer exceptions stay exact and malformed data cannot pass"
    (def report (property.check-property (generator.generator-unit 1) positive?
      (property.make-specification exact-integer? abs) cases: 1))
    (def cause (cons 'render 'fault))
    (check-eq? (with-catch values (lambda ()
      (assertion.require-passed report diagnostics: (lambda (_) (raise cause))))) cause)
    (check-exception (assertion.require-passed report diagnostics: (lambda (_) '(malformed))) Error?)
    (def armed #f)
    (def observed (property.check-property (generator.make-generator (lambda (_r _s) 1) (lambda (_) [])
      current?: (lambda () (if armed (raise cause) #t))) positive?
      (property.make-specification exact-integer? abs) cases: 1))
    (set! armed #t)
    (check-eq? (with-catch values (lambda () (assertion.require-passed observed))) cause))
  (test-case "diagnostics cannot downgrade a valid report or manufacture missing execution"
    (def formats 0)
    (def report (property.check-property (generator.generator-unit 1) positive?
      (property.make-specification exact-integer? abs) cases: 1))
    (check (void? (assertion.require-passed report diagnostics: (lambda (_)
      (set! formats (1+ formats)) '((status . failed) (cause . invented))))) => #t)
    (check-equal? formats 1)
    (def absent (with-catch values (lambda () (assertion.require-passed #f
      diagnostics: (lambda (_) '((status . passed)))))))
    (check-eq? (cdr (assq 'status (Error-irritants absent))) 'error)))

;; Gerbil assertions exit with a TestResult, not an ordinary raised exception.
;; A standard owned TestCase keeps expected refusal separate from outer results;
;; callers must inspect that result and its original cause, never discard it.
(def (assertion-result thunk)
  (let/cc done
    (parameterize ((test.current-test-config (test.TestConfig verbosity: 0 capture-output?: #t))
                   (test.current-test-exit done))
      (test.test-case! (test.TestCase "expected declaration refusal" thunk)))))

;; Named property declarations share ordered domain admission and one existing
;; generator-construction scope. Ordinary caller argument evaluation is separate.
(def (declaration-test-cases!)
  (test-case "declarations admit proper builders and live domains before later effects"
    (let ((calls 0) (later 0))
      (def stale (property.make-specification integer? abs current?: (lambda () #f)))
      (check-exception (property.call-with-specifications
        (list (lambda () (set! calls (1+ calls)) stale)
              (lambda () (set! later (1+ later)) stale))
        (lambda (_) (set! later (1+ later)))) Error?)
      (check-equal? (list calls later) '(1 0))
      (check-exception (property.call-with-specifications
        (list (lambda () (set! calls (1+ calls)) stale) #f) void) Error?)
      (check-equal? calls 1)
      (check-exception (property.call-with-specifications
        (list (lambda () #f) (lambda () (set! later 1) stale)) void) Error?)
      (check-equal? later 0)))
  (test-case "later specifications cannot retire earlier domains and run nested producers"
    (for (probe? '(#f #t))
      (let ((alive #t) (calls 0) (produced 0))
        (def first (property.make-specification integer? abs current?: (lambda () alive)))
        (check-exception (property.call-with-specifications
          (list (lambda () first) (lambda ()
            (set! alive #f)
            (when probe? (generator.generate
              (generator.generator-map (generator.generator-unit 1)
                (lambda (value) (set! produced (1+ produced)) value)) (generator.random-at 0) 0))
            (property.make-specification integer? abs))
            (lambda () (set! calls 1) first))
          (lambda (_) (set! calls 1))) Error?)
        (check-equal? (list produced calls) '(0 0)))))
  (test-case "generator construction refuses retired declarations before nested pulls"
    (for (probe? '(#f #t))
      (let ((alive #t) (produced 0))
        (def domain (property.make-specification integer? abs current?: (lambda () alive)))
        (check-exception (property.call-with-specifications (list (lambda () domain))
          (lambda (_)
            (set! alive #f)
            (when probe? (generator.generate
              (generator.generator-map (generator.generator-unit 1)
                (lambda (value) (set! produced (1+ produced)) value)) (generator.random-at 0) 0))
            (generator.generator-unit 1))) Error?)
        (check-equal? produced 0))))
  (test-case "declaration and construction causes remain exact after retirement"
    (for* ((stage '(specification generator)) (cause (list #f (cons 'construction 'cause))))
      (let ((alive #t) (later 0))
        (def domain (property.make-specification integer? abs current?: (lambda () alive)))
        (def failure (with-catch values (lambda ()
          (property.call-with-specifications
            (list (lambda () domain) (lambda ()
              (when (eq? stage 'specification) (set! alive #f) (raise cause)) domain))
            (lambda (_) (set! alive #f) (raise cause)))
          (set! later 1))))
        (check-eq? failure cause)
        (check-equal? later 0)
        (check-equal? (generator.sample-value (generator.generate
          (generator.generator-unit 42) (generator.random-at 0) 0)) 42))))
  (test-case "domains and multiple construction values retain order identity and one evaluation"
    (let ((events []) (first (property.make-specification integer? abs))
          (second (property.make-specification boolean? (lambda (_) 0))))
      (let-values (((present domains)
                    (property.call-with-specifications
                      (list (lambda () (set! events (cons 'first events)) first)
                            (lambda () (set! events (cons 'second events)) second))
                      (lambda (domains) (set! events (cons 'build events)) (values #f domains)))))
        (check present => #f)
        (check-eq? (car domains) first)
        (check-eq? (cadr domains) second)
        (check-equal? (reverse events) '(first second build)))))
  (test-case "constructor spines are owned before any declaration callback"
    (let* ((domain (property.make-specification integer? abs)) (later 0)
           (builders (list (lambda () domain) (lambda () (set! later (1+ later)) domain))))
      (set-car! builders (lambda ()
        (set-car! (cdr builders) (lambda () (error "replacement must not run"))) domain))
      (check-equal? (property.call-with-specifications builders length) 2)
      (check-equal? later 1)))
  (test-case "single named declarations stop obsolete construction then shrink and replay fresh runs"
    (let ((epoch 0) (retire? #t) (produced 0))
      ;; The fixed specification captures each invocation's actual epoch.
      (property.define-property (named value)
        (begin
          (when retire? (set! epoch (1+ epoch)))
          (generator.generate (generator.generator-map (generator.generator-unit 1)
            (lambda (value) (set! produced (1+ produced)) value)) (generator.random-at 0) 0)
          (generator.make-generator (lambda (_r _s) 3) generator.integer-shrinks))
        (let (captured epoch)
          (property.make-specification exact-integer? abs current?: (lambda () (= epoch captured))))
        (< value 0))
      (check-exception (named cases: 1) Error?)
      (check-equal? produced 0)
      (set! retire? #f)
      (let (report (named seed: 17 cases: 1 shrink-budget: 20))
        (check-eq? (property.report-status report) 'failed)
        (check-eq? (property.report-name report) 'named)
        (check-equal? (property.report-counterexample report) 0)
        (check (property.replay-counterexample report) => #f)
        (check-equal? (property.report-counterexample (property.replay-property report)) 0)
        (let ((codec (replay.make-codec '(named 1) values values)) (output (open-output-string)))
          (replay.write-counterexample report codec output)
          (check (replay.read-counterexample codec (open-input-string (get-output-string output))
            (property.report-specification report) (property.report-property report)) => #f))
        (set! epoch (1+ epoch))
        (check-exception (property.replay-property report) Error?))
      (check-eq? (property.report-status (named cases: 1)) 'failed)))
  (test-case "multiargument declarations prepare once and retain ordinary dependent generation"
    (let ((epoch 0) (retire? #t) (specifications 0) (factories 0) (dependent 0) (produced 0) (trials 0))
      ;; Domain factories run during declaration, not once for every trial.
      (def (domain)
        (set! specifications (1+ specifications))
        (let (captured epoch)
          (property.make-specification exact-integer? abs current?: (lambda () (= epoch captured)))))
      ;; The assertion macro keeps Gerbil's standard location/error machinery.
      (assertion.define-property balanced
        ((left (begin
                 (set! factories (1+ factories))
                 (when retire? (set! epoch (1+ epoch)))
                 (generator.generate (generator.generator-map (generator.generator-unit 1)
                   (lambda (value) (set! produced (1+ produced)) value)) (generator.random-at 0) 0)
                 (generator.generator-integer 0 3)) (domain))
         (right (begin (set! dependent (1+ dependent)) (generator.generator-unit (- left))) (domain)))
        (set! trials (1+ trials)) (= (+ left right) 0))
      (let (result (assertion-result (lambda () (balanced cases: 3))))
        (check (test.test-result-error? result) => #t)
        (using (refusal result :- test.TestResultError)
          (check-equal? (Error-message refusal.exn) "stale property preparation")))
      (check-equal? (list specifications factories dependent produced trials) '(2 1 0 0 0))
      (set! retire? #f)
      (balanced cases: 3)
      (check-equal? (list specifications factories dependent produced trials) '(4 2 3 1 3))))
  (test-case "a later named domain refuses before any generator construction"
    (let ((alive #t) (factories 0))
      (def first (property.make-specification integer? abs current?: (lambda () alive)))
      ;; The second declaration cannot refresh first's existing observer.
      (assertion.define-property named
        ((left (begin (set! factories 1) (generator.generator-unit 1)) first)
         (right (generator.generator-unit left)
           (begin (set! alive #f) (property.make-specification integer? abs))))
        (= left right))
      (let (result (assertion-result (lambda () (named cases: 1))))
        (check (test.test-result-error? result) => #t)
        (using (refusal result :- test.TestResultError)
          (check-equal? (Error-message refusal.exn) "stale property preparation")))
      (check-equal? factories 0)))
  (test-case "zero argument declarations and preparation scope release use standard execution"
    (let ((alive #t) (constructed 0))
      (def domain (property.make-specification integer? abs current?: (lambda () alive)))
      (def generation (property.call-with-specifications (list (lambda () domain))
        (lambda (_) (set! constructed (1+ constructed)) (generator.generator-unit 7))))
      (set! alive #f)
      (check-equal? (generator.sample-value (generator.generate generation (generator.random-at 0) 0)) 7)
      (check-equal? constructed 1)
      ;; Empty product declarations still enter the ordinary runner and assertion.
      (assertion.define-property empty () #t)
      (empty cases: 2))))
