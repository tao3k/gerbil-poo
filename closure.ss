;;; Finite positive equations: private compiled descriptors and owned scratch.
(export literal fact both either compile-closure reconfigure-closure
        closure-plan? closure-result? solve-closure closure-ref closure->list
        closure-counts closure-plan-size closure-plan-edges closure-plan-nodes
        closure-policy balanced-closure-policy closure-plan-queue closure-plan-hybrid-ceiling)
(import :gerbil/runtime/gambit)

;; Input constructors; compilation validates and copies every descriptor.
(def (literal value) (vector 0 value #f))
(def (fact index) (vector 1 index #f))
(def (both left right) (vector 2 left right))
(def (either left right) (vector 3 left right))
(defstruct closure-plan (code watches degrees edges nodes maximum hybrid-ceiling queue) final: #t)
(defstruct closure-result (bits counts) final: #t)
(defstruct queue-prices (copy suspend resume) final: #t)
(def (closure-policy copy suspend resume)
  (unless (and (fixnum? copy) (>= copy 0) (fixnum? suspend) (>= suspend 0)
               (fixnum? resume) (>= resume 0) (fixnum? (+ suspend resume)))
    (error "invalid queue primitive prices"))
  (make-queue-prices copy suspend resume))
(def balanced-closure-policy (closure-policy 1 4 4))
(def (closure-plan-size plan) (vector-length (closure-plan-code plan)))

;; Counters: pops/evaluations/nodes/writes/pushes/frame-allocations/frame-pops/
;; fact-reads/joins/literals/queue-pair-cells/copied-state-bytes/peak-frames.
(def (inc! counts index (amount 1))
  (vector-set! counts index (+ (vector-ref counts index) amount)))

(def (copy-expression node size on-read on-node (depth 4096))
  (when (= depth 0) (error "positive descriptor depth limit"))
  (unless (and (vector? node) (= (vector-length node) 3))
    (error "invalid positive descriptor" node))
  (on-node)
  (let ((tag (vector-ref node 0)) (left (vector-ref node 1)) (right (vector-ref node 2)))
    (case tag
      ((0) (unless (boolean? left) (error "literal must be Boolean" left)) (literal left))
      ((1) (unless (and (exact-integer? left) (<= 0 left) (< left size))
             (error "fact index outside declaration" left size))
           (on-read left) (fact left))
      ((2 3) (vector tag (copy-expression left size on-read on-node (- depth 1))
                         (copy-expression right size on-read on-node (- depth 1))))
      (else (error "unknown positive descriptor" tag)))))

(def (compile-closure equations)
  (unless (vector? equations) (error "equations must be a finite vector"))
  (let* ((size (vector-length equations)) (code (make-vector size))
         (watches (make-vector size '())) (degrees (make-vector size 0))
         (edges 0) (nodes 0) (maximum 0))
    (let loop ((target 0))
      (when (< target size)
        (let ((local 0))
          (vector-set! code target
            (copy-expression (vector-ref equations target) size
              (lambda (source)
                (set! edges (+ edges 1))
                (vector-set! watches source (cons target (vector-ref watches source)))
                (vector-set! degrees source (+ 1 (vector-ref degrees source))))
              (lambda () (set! local (+ local 1)) (set! nodes (+ nodes 1))
                (when (> nodes 1000000) (error "positive descriptor node limit")))))
          (set! maximum (max maximum local)))
        (loop (+ target 1))))
    ;; Generic arithmetic checks capacity before the fixnum-priced solve scope.
    (unless (and (fixnum? (+ size edges)) (fixnum? (* 16 (+ 1 size edges (* (+ size edges) maximum)))))
      (error "declaration exceeds fixnum-priced operation range"))
    (let ((ceiling (let sum ((index 0) (cost 0))
                     (if (= index size) cost
                       (sum (+ index 1) (+ cost 1 (* 4 (min 8 (vector-ref degrees index)))))))))
      (make-closure-plan code watches degrees edges nodes maximum ceiling
                         (if (<= (* 4 edges) ceiling) 'append 'hybrid)))))

;; A sufficient no-allocation topology check: same tags/read indices, arbitrary
;; literal changes. General dependency-equivalent reshaping needs fresh compile.
(def (same-topology? old fresh)
  (and (= (vector-ref old 0) (vector-ref fresh 0))
       (case (vector-ref old 0)
         ((0) #t)
         ((1) (= (vector-ref old 1) (vector-ref fresh 1)))
         (else (and (same-topology? (vector-ref old 1) (vector-ref fresh 1))
                    (same-topology? (vector-ref old 2) (vector-ref fresh 2)))))))

(def (reconfigure-closure prior equations)
  (let* ((size (closure-plan-size prior)) (code (make-vector size)) (nodes 0) (maximum 0))
    (unless (and (vector? equations) (= (vector-length equations) size))
      (error "reconfiguration changes fact range"))
    (let loop ((index 0))
      (when (< index size)
        (let* ((local 0)
               (fresh (copy-expression (vector-ref equations index) size void
                        (lambda () (set! local (+ local 1)) (set! nodes (+ nodes 1))
                (when (> nodes 1000000) (error "positive descriptor node limit"))))))
          (unless (same-topology? (vector-ref (closure-plan-code prior) index) fresh)
            (error "reconfiguration changes read topology" index))
          (vector-set! code index fresh)
          (set! maximum (max maximum local)))
        (loop (+ index 1))))
    (make-closure-plan code (closure-plan-watches prior) (closure-plan-degrees prior)
                       (closure-plan-edges prior) nodes maximum
                       (closure-plan-hybrid-ceiling prior) (closure-plan-queue prior))))

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

(def (initial-queue size)
  (let loop ((index (- size 1)) (queue '()))
    (if (< index 0) queue (loop (- index 1) (cons index queue)))))

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
      (solve-append plan state-kind policy) (solve-hybrid plan state-kind policy))
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
(def (closure-ref result index) (= (u8vector-ref (closure-result-bits result) index) 1))
(def (closure->list result)
  (let* ((bits (closure-result-bits result)) (size (u8vector-length bits)))
    (let loop ((index (- size 1)) (facts '()))
      (if (< index 0) facts (loop (- index 1) (cons (= (u8vector-ref bits index) 1) facts))))))
(def (closure-counts result) (vector-copy (closure-result-counts result)))
