;;; Finite cyclic objects, positive computed facts and memoized bounded requests.
(export Handler program registry build close-service envelope service-action)
(import ../object
        ../mop
        ../number
        ../object-contract
        (only-in ../type Record String)
        (runtime: :clan/poo/recursive)
        (prefix-in (only-in ../recursive Generator. Interaction. request source-error
                   value) recursive.)
        (runtime: :clan/poo/recursive-handling)
        (prefix-in (only-in ../recursive-handling Signature. call-slot result-failure
                   result-next result-reused result-value) handling.)
        (runtime: :clan/poo/recursive-validation)
        (prefix-in (only-in ../recursive-validation closed-ref closed-type
                   validation-action) validation.)
        (runtime: :clan/poo/closure)
        (prefix-in (only-in ../closure closure-ref compile-closure either fact literal
                   solve-closure) closure.)
        (runtime: :clan/poo/generalized-prototype)
        (prefix-in (only-in ../generalized-prototype Observation.) observation.)
        (prefix-in ./object-contracts config.)
        (prefix-in ./contract-publication publication.))

;; Functions receive explicit recursive session state; no mutable memo is hidden
;; in a supposedly pure getter or shared between unrelated program owners.
(def Handler (Fun Any <- Any Integer))

;; Object backedges do not justify arbitrary recursion: calls use the existing
;; explicit Interaction machine, with a decreasing request and bounded execution.
(def program
  (.cc recursive.Generator. input: Any output: Integer
    generate: (lambda (input)
      (def node (car input)) (def count (cdr input))
      (cond ((not (memq node '(left right))) (recursive.source-error "unknown node"))
            ((not (and (exact-integer? count) (>= count 0))) (recursive.source-error "invalid count"))
            ((= count 0) (recursive.value 0))
            (else (.call recursive.Interaction. .map
                    (lambda (total) (+ (if (eq? node 'left) 2 3) total))
                    (recursive.request (cons (if (eq? node 'left) 'right 'left) (- count 1)))))))))

;; Current input/output admission runs on memo hits too, using existing signatures.
(def registry
  (.o left: (.cc handling.Signature. name: 'left input: (IntegerRange min: 0 max: 32) output: Integer)
      right: (.cc handling.Signature. name: 'right input: (IntegerRange min: 0 max: 32) output: Integer)))

;; A real positive computed cycle uses the existing least-closure solver, rather
;; than an arbitrary successful warm seed: left = true OR right; right = left.
(def (active-facts)
  (closure.solve-closure (closure.compile-closure
    (vector (closure.either (closure.literal #t) (closure.fact 1)) (closure.fact 0)))))

;; Build raw cyclic sources with explicit Reference Types. Every target is later
;; independently normalized/admitted. Computed handlers are productive because
;; their peer calls are delayed; eager recursive getters still refuse CyclicSlot.
(def (build reference _config)
  (def facts (active-facts))
  ;; Reuse one descriptor factory; peer-handler retains the actual checked peer
  ;; Function by identity, and its guard remains the peer Handler's own wrapper.
  (def (node-type target index)
    (Record name: [Any] peer: [(reference target)]
      active: [Bool compute: (lambda (_self _next) (closure.closure-ref facts index))]
      handler: [Handler compute: (lambda (self _next)
        (lambda (session count)
          (unless (.get self active) (error "inactive service"))
          (handling.call-slot session registry (.get self name) count 256)))]
      peer-handler: [Any compute: (lambda (self _next) (.get self peer handler))]))
  (def left-type (node-type 'right 0))
  (def right-type (node-type 'left 1))
  (def left-source (.o (:: self (.get left-type proto)) name: 'left peer: right-source))
  (def right-source (.o (:: self (.get right-type proto)) name: 'right peer: left-source))
  (list (list 'left left-type left-source) (list 'right right-type right-source)))

;; Use the existing Reader/FUN-compatible validation action, with a finite catalog.
(def close-service (validation.validation-action build 8))

;; Root refinement sees canonical backedges and checked computed peer captures.
;; A Reference Type rechecks graph admission without allocating a different root.
(def (envelope graph)
  (refine (.cc ObjectContract. responsibilities:
            (.o config: publication.CapacityContract processor: (validation.closed-type graph 'left)))
    (lambda (candidate location)
      (def root (.get candidate processor))
      (if (and (eq? root (.get root peer peer))
               (eq? (.get root peer-handler) (.get root peer handler))
               (.get root active) (.get root peer active)) '()
        [(.o kind: 'recursive-service path: (append location '(processor)))]))))

;; Execute two calls sharing the right/3 request and return only a successful
;; next session. Existing publication controls the returned ledger and evidence.
(def (produce descriptor-value context-value checked)
  (def first ((.get checked processor handler) (.get context-value session) 4))
  (when (handling.result-failure first) (raise (handling.result-failure first)))
  (def second ((.get checked processor peer-handler) (handling.result-next first) 3))
  (when (handling.result-failure second) (raise (handling.result-failure second)))
  (def total-value (+ (handling.result-value first) (handling.result-value second)))
  (values (.o subject: checked descriptor: descriptor-value context: context-value total: total-value
              reused: (handling.result-reused second))
          (.cc context-value session: (handling.result-next second)
               commits: (+ 1 (.get context-value commits)))))

;; Decode → close all graph nodes → root refine → exact bound FUN publication.
(def (service-action invocation context-value)
  (.call observation.Observation. .bind
    (lambda (text)
      (def config-value (config.decode-service text))
      (def graph (close-service config-value))
      (vector (envelope graph) (.o config: config-value processor: (validation.closed-ref graph 'left))))
    (lambda (packet)
      (lambda (_text)
        (def descriptor (vector-ref packet 0))
        ((publication.publication-action descriptor invocation context-value
           (cut produce descriptor context-value <>)) (vector-ref packet 1))))))
