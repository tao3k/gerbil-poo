;;; Finite positive equations: private compiled descriptors and owned scratch.
(export literal fact both either compile-closure reconfigure-closure
        closure-plan? closure-result? solve-closure closure-ref closure->list
        closure-counts closure-plan-size closure-plan-edges closure-plan-nodes
        closure-index-shared? closure-policy balanced-closure-policy closure-plan-queue closure-plan-hybrid-ceiling closure-plan-selector-visits prepare-closure construct-closure)
(import :gerbil/runtime/gambit :std/iter)

;; Input constructors; compilation validates and copies every descriptor.
(def (literal value) (vector 0 value #f))
(def (fact index) (vector 1 index #f))
(def (both left right) (vector 2 left right))
(def (either left right) (vector 3 left right))
(defstruct closure-plan (code watches degrees edges nodes maximum hybrid-ceiling queue selector) final: #t)
(defstruct closure-result (bits counts) final: #t)
(defstruct queue-prices (copy suspend resume) final: #t)
(def (closure-policy copy suspend resume)
  (unless (and (fixnum? copy) (>= copy 0) (fixnum? suspend) (>= suspend 0)
               (fixnum? resume) (>= resume 0) (fixnum? (+ suspend resume)))
    (error "invalid queue primitive prices"))
  (make-queue-prices copy suspend resume))
(def balanced-closure-policy (closure-policy 1 4 4))
(def (closure-plan-selector-visits plan)
  (if (eq? (closure-plan-selector plan) 'prepared) (closure-plan-size plan) 0))
(def (closure-plan-size plan) (vector-length (closure-plan-code plan)))

;; Counters: pops/evaluations/nodes/writes/pushes/frame-allocations/frame-pops/
;; fact-reads/joins/literals/queue-pair-cells/copied-state-bytes/peak-frames.
(def (inc! counts index (amount 1))
  (vector-set! counts index (+ (vector-ref counts index) amount)))

;; Private typed state, following the compiler's context style. Walkers are
;; specialized at expansion time: index construction has no per-equation closure
;; and copy-only revisions perform no reverse-index writes.
(defstruct compilation (nodes local edges target watches degrees) final: #t)
(defrule (index-read! ctx source)
  (using (indexer ctx :- compilation)
    (set! indexer.edges (1+ indexer.edges))
    (vector-set! indexer.watches source (cons indexer.target (vector-ref indexer.watches source)))
    (vector-set! indexer.degrees source (1+ (vector-ref indexer.degrees source)))))
(defrule (ignore-read! ctx source) (void))
(defrule (define-copy-walker name visit)
  (def (name node size context (depth 4096))
    (when (= depth 0) (error "positive descriptor depth limit"))
    (using (ctx context :- compilation)
      (set! ctx.nodes (1+ ctx.nodes))
      (set! ctx.local (1+ ctx.local))
      (when (> ctx.nodes 1000000) (error "positive descriptor node limit"))
      (unless (and (vector? node) (= (vector-length node) 3))
        (error "invalid positive descriptor" node))
      (let ((tag (vector-ref node 0)) (left (vector-ref node 1)))
        (case tag
          ((0) (unless (boolean? left) (error "literal must be Boolean" left)) (literal left))
          ((1) (unless (and (exact-integer? left) (<= 0 left) (< left size))
                 (error "fact index outside declaration" left size))
               (visit ctx left) (fact left))
          ((2 3) (vector tag (name left size ctx (1- depth))
                             (name (vector-ref node 2) size ctx (1- depth))))
          (else (error "unknown positive descriptor" tag)))))))
(define-copy-walker copy-indexed index-read!)
(define-copy-walker copy-only ignore-read!)

(def (check-priced-range! size edges maximum)
  (unless (and (fixnum? (+ size edges))
               (fixnum? (* 16 (+ 1 size edges (* (+ size edges) maximum)))))
    (error "declaration exceeds fixnum-priced operation range")))

(def (compile-closure equations (mode 'auto))
  (unless (vector? equations) (error "equations must be a finite vector"))
  (unless (memq mode '(auto cold append chunked hybrid)) (error "compile mode" mode))
  (def size (vector-length equations))
  (def code (make-vector size))
  (using (ctx (make-compilation 0 0 0 0 (make-vector size '()) (make-vector size 0)) :- compilation)
    (def maximum
      (for/fold (maximum 0) (target (in-range size))
        (set! ctx.local 0)
        (set! ctx.target target)
        (vector-set! code target (copy-indexed (vector-ref equations target) size ctx))
        (max maximum ctx.local)))
    (check-priced-range! size ctx.edges maximum)
    (defvalues (ceiling queue) (queue-metadata mode ctx.degrees ctx.edges size))
    (make-closure-plan code ctx.watches ctx.degrees ctx.edges ctx.nodes maximum ceiling queue (if (eq? mode 'auto) 'prepared 'unprepared))))

(def (queue-metadata mode degrees edges size)
  (def append-bound (* 4 edges))
  (def chunk-bound (* 32 size))
  (def ceiling (if (eq? mode 'auto)
                 (for/fold (cost size) (degree (in-vector degrees)) (+ cost (* 4 (min 8 degree))))
                 (+ size (min append-bound chunk-bound))))
  (values ceiling
    (case mode
      ((auto) (cond ((and (<= append-bound chunk-bound) (<= append-bound ceiling)) 'append)
                    ((<= chunk-bound ceiling) 'chunked) (else 'hybrid)))
      ((cold) (if (<= append-bound chunk-bound) 'append 'chunked))
      (else mode))))

;; Delayed cache preparation shares private code/index vectors; no AST copying.
(def (prepare-closure plan)
  (if (eq? (closure-plan-selector plan) 'unprepared)
    (using (p plan :- closure-plan)
      (defvalues (ceiling queue) (queue-metadata 'auto p.degrees p.edges (vector-length p.code)))
      (make-closure-plan p.code p.watches p.degrees p.edges p.nodes p.maximum ceiling queue 'prepared))
    plan))

;; Allocation-free fast path for literal-only revisions. The fallback below
;; admits changed shapes with exactly equal ordered read occurrences.
(def (same-topology? old fresh)
  (and (= (vector-ref old 0) (vector-ref fresh 0))
       (case (vector-ref old 0)
         ((0) #t)
         ((1) (= (vector-ref old 1) (vector-ref fresh 1)))
         (else (and (same-topology? (vector-ref old 1) (vector-ref fresh 1))
                    (same-topology? (vector-ref old 2) (vector-ref fresh 2)))))))

;; Same ordered read occurrences are sufficient, even after reassociating joins
;; or replacing both with either. This matches IncrementalClosure.reconfigure.
(def (collect-reads node tail)
  (case (vector-ref node 0)
    ((0) tail)
    ((1) (cons (vector-ref node 1) tail))
    (else (collect-reads (vector-ref node 1) (collect-reads (vector-ref node 2) tail)))))
(def (same-dependencies? old fresh)
  (or (same-topology? old fresh) (equal? (collect-reads old []) (collect-reads fresh []))))
(def (closure-index-shared? first second)
  (and (eq? (closure-plan-watches first) (closure-plan-watches second))
       (eq? (closure-plan-degrees first) (closure-plan-degrees second))))

(def (reconfigure-closure prior equations)
  (def size (closure-plan-size prior))
  (unless (and (vector? equations) (= (vector-length equations) size))
    (error "reconfiguration changes fact range"))
  (def code (make-vector size))
  (def ctx (make-compilation 0 0 0 0 #f #f))
  (def maximum 0)
  (for (index (in-range size))
    (set! (compilation-local ctx) 0)
    (def fresh (copy-only (vector-ref equations index) size ctx))
    (unless (same-dependencies? (vector-ref (closure-plan-code prior) index) fresh)
      (error "reconfiguration changes read topology" index))
    (vector-set! code index fresh)
    (set! maximum (max maximum (compilation-local ctx))))
  (check-priced-range! size (closure-plan-edges prior) maximum)
  (make-closure-plan code (closure-plan-watches prior) (closure-plan-degrees prior)
                    (closure-plan-edges prior) (compilation-nodes ctx) maximum
                    (closure-plan-hybrid-ceiling prior) (closure-plan-queue prior)
                    (if (eq? (closure-plan-selector prior) 'unprepared) 'unprepared 'retained)))

;; Strict evaluation agrees with the Lean instrumented interpreter; Boolean
;; results are scalar and no result pair is allocated per visited AST node.
(def (evaluate node bits counts)
  (inc! counts 2)
  (case (vector-ref node 0)
    ((0) (inc! counts 9) (vector-ref node 1))
    ((1) (inc! counts 7) (= (u8vector-ref bits (vector-ref node 1)) 1))
    (else
      (inc! counts 8)
      (let* ((left (evaluate (vector-ref node 1) bits counts))
             (right (evaluate (vector-ref node 2) bits counts)))
        (if (= (vector-ref node 0) 2) (and left right) (or left right))))))

(defalias initial-queue iota)

;; Macro-expanded engines dispatch once per solve, outside the propagation loop.
(defrule (queue-append loop plan counts index tail pending fuel depth degree copy-price frame-price)
  (if (= degree 0) (loop tail pending (- fuel 1) depth)
    (let ((watchers (vector-ref (closure-plan-watches plan) index)))
      (inc! counts 10 degree)
      (loop (cond ((= degree 1) (cons (car watchers) tail))
                  ((= degree 2) (cons (car watchers) (cons (cadr watchers) tail)))
                  (else (append watchers tail)))
            pending (- fuel 1) depth))))
(defrule (queue-chunked loop plan counts index tail pending fuel depth degree copy-price frame-price)
  (begin
    (inc! counts 5) (inc! counts 10)
    (vector-set! counts 12 (max (vector-ref counts 12) (+ depth 1)))
    (loop (vector-ref (closure-plan-watches plan) index) (cons tail pending) (- fuel 1) (+ depth 1))))
(defrule (queue-hybrid loop plan counts index tail pending fuel depth degree copy-price frame-price)
  (let ((watchers (vector-ref (closure-plan-watches plan) index)))
    (cond
      ((= degree 0) (inc! counts 14) (loop tail pending (- fuel 1) depth))
      ((null? tail) (inc! counts 15) (loop watchers pending (- fuel 1) depth))
      ((<= (* degree copy-price) frame-price)
       (inc! counts 13 degree) (inc! counts 16) (inc! counts 10 degree)
       (loop (if (= degree 1) (cons (car watchers) tail) (append watchers tail)) pending (- fuel 1) depth))
      (else
       (inc! counts 5) (inc! counts 10)
       (vector-set! counts 12 (max (vector-ref counts 12) (+ depth 1)))
       (loop watchers (cons tail pending) (- fuel 1) (+ depth 1))))))

(defrule (define-queue-engine name enqueue)
  (def (name plan state-kind policy)
    (let* ((size (closure-plan-size plan)) (bits (make-u8vector size 0))
           (counts (make-vector 17 0)) (budget (+ size (closure-plan-edges plan)))
           (copy-price (queue-prices-copy policy))
           (frame-price (+ (queue-prices-suspend policy) (queue-prices-resume policy))))
      (inc! counts 10 size)
      (let loop ((current (initial-queue size)) (pending '()) (fuel budget) (depth 0))
        (cond
          ((null? current)
           (if (null? pending) (make-closure-result (u8vector-copy bits) counts)
             (begin (inc! counts 6) (loop (car pending) (cdr pending) fuel (- depth 1)))))
          ((= fuel 0) (error "certified work budget exhausted"))
          (else
            (let ((index (car current)) (tail (cdr current)))
              (inc! counts 0)
              (if (= (u8vector-ref bits index) 1) (loop tail pending (- fuel 1) depth)
                (begin
                  (inc! counts 1)
                  (if (evaluate (vector-ref (closure-plan-code plan) index) bits counts)
                    (begin
                      (when (eq? state-kind 'copied)
                        (set! bits (u8vector-copy bits)) (inc! counts 11 size))
                      (u8vector-set! bits index 1)
                      (let ((degree (vector-ref (closure-plan-degrees plan) index)))
                        (inc! counts 3) (inc! counts 4 degree)
                        (enqueue loop plan counts index tail pending fuel depth degree copy-price frame-price)))
                    (loop tail pending (- fuel 1) depth)))))))))))

(define-queue-engine solve-append queue-append)
(define-queue-engine solve-chunked queue-chunked)
(define-queue-engine solve-hybrid queue-hybrid)

(def (solve-closure plan (queue-kind 'auto) (state-kind 'owned) (policy balanced-closure-policy))
  (unless (memq state-kind '(owned copied)) (error "state kind" state-kind))
  ;; Compilation already admitted the reference price range. The common path
  ;; uses that immutable policy object and cached choice, with no degree scan.
  (if (and (eq? queue-kind 'auto) (eq? policy balanced-closure-policy))
    (if (eq? (closure-plan-queue plan) 'append)
      (solve-append plan state-kind policy)
      (if (eq? (closure-plan-queue plan) 'chunked) (solve-chunked plan state-kind policy)
        (solve-hybrid plan state-kind policy)))
    (begin
      (when (eq? queue-kind 'auto)
        (unless (and (queue-prices? policy) (= (queue-prices-copy policy) 1)
                     (= (queue-prices-suspend policy) 4) (= (queue-prices-resume policy) 4))
          (error "automatic selection requires the reference profile"))
        (set! queue-kind (closure-plan-queue plan)))
      (when (eq? queue-kind 'minimum-allocation)
        (set! queue-kind (if (<= (closure-plan-edges plan) (closure-plan-size plan)) 'append 'chunked)))
      (unless (and (queue-prices? policy)
                   (fixnum? (* (closure-plan-edges plan) (queue-prices-copy policy))))
        (error "queue prices exceed fixnum-priced range"))
      (case queue-kind
        ((append) (solve-append plan state-kind policy))
        ((chunked) (solve-chunked plan state-kind policy))
        ((hybrid) (solve-hybrid plan state-kind policy))
        (else (error "queue kind" queue-kind))))))
(def (construct-closure equations) (solve-closure (compile-closure equations 'cold)))

(def (closure-ref result index) (= (u8vector-ref (closure-result-bits result) index) 1))
(def (closure->list result)
  (let* ((bits (closure-result-bits result)) (size (u8vector-length bits)))
    (let loop ((index (- size 1)) (facts '()))
      (if (< index 0) facts (loop (- index 1) (cons (= (u8vector-ref bits index) 1) facts))))))
(def (closure-counts result) (vector-copy (closure-result-counts result)))
