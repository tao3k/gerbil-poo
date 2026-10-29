;;; Receiver-bound inherited computation through checked factories and FUN.
(export Transform BaseRecord ServiceRecord InitializedRecord EnvelopeContract service-action)
(import (only-in :std/list/list foldl)
        ../object
        ../mop
        ../number
        ../object-contract
        (only-in ../type Record List)
        (runtime: :clan/poo/fun)
        (prefix-in ./object-contracts config.)
        (prefix-in ./contract-publication publication.)
        (prefix-in (only-in :clan/poo/fun Observation.) fun.))

;; Defaults, computed delegates and nested result Functions share one interface.
(def Transform (Fun Integer <- Integer))

;; Each computed field reads the final receiver, including a Function dependency
;; captured when the field is first forced, rather than only when called later.
(define-type BaseRecord
  (Record backend: [Transform default: (lambda (n) (+ n 1))]
          bias: [Integer default: 1]
          captured: [Any compute: (lambda (self _next) (.get self backend))]
          run: [Transform compute: (lambda (self _next)
                    (def backend-value (.get self backend))
                    (lambda (n) (+ (.get self bias) (backend-value n))))]
          callbacks: [(List Transform) compute: (lambda (self _next)
                        (list (.get self backend) (.get self run)))]
          maker: [(Fun Transform <- Integer) compute: (lambda (self _next)
                    (def backend-value (.get self backend))
                    (lambda (offset)
                      (lambda (n) (+ offset (.get self bias) (backend-value n)))))]))

;; The derived slot computation retains its inherited computation and final self.
;; Both metadata selection and super-thunk composition remain ordinary POO.
(define-type ServiceRecord
  (.cc (Record [BaseRecord] bias: [Integer default: 2])
    proto: (.o (:: self (.get BaseRecord proto))
             bias: 2
             run: => (lambda (inherited-value)
                       (lambda (n) (+ (.get self bias) (inherited-value n)))))))

;; Replace a dependency and a scalar in the hook. Captured delegates, nested
;; Functions and inherited super computations must all rebind to this replacement.
(define-type InitializedRecord
  (.cc ServiceRecord .instantiate:
    (lambda (checked)
      (.cc checked backend: (lambda (n) (* n 2)) bias: 3))))

;; Refinement observes the exact normalized dependency shared by two fields.
;; Freezing the earlier captured Function would violate this relation.
(def EnvelopeContract
  (refine (.cc ObjectContract. responsibilities:
            (.o config: publication.CapacityContract processor: InitializedRecord))
    (lambda (candidate path)
      (def processor-value (.get candidate processor))
      (if (and (eq? (.get processor-value backend) (.get processor-value captured))
               (<= (.get processor-value bias) (.get candidate config capacity))) '()
        [(.o kind: 'computed-dependency path: (append path '(processor)))]))))

;; Execute only after full recursive validation/refinement, then associate the
;; actual root with the existing publication context. No external effects roll back.
(def (produce context-value checked-value)
  (def processor-value (.get checked-value processor))
  (def first ((.get processor-value run) (.get checked-value config used)))
  (def total-value (foldl (lambda (callback value) (callback value)) first
                         (.get processor-value callbacks)))
  (def nested-value (((.get processor-value maker) 1) 2))
  (values (.o subject: checked-value descriptor: EnvelopeContract context: context-value
              total: total-value nested: nested-value)
          (.cc context-value commits: (+ 1 (.get context-value commits)))))

;; Compose JSON decoding, checked inheritance/hook initialization and normalized
;; evidence publication through the existing Observation Reader/FUN abstraction.
(def (service-action invocation context-value)
  (def publish (publication.publication-action EnvelopeContract invocation context-value
                 (cut produce context-value <>)))
  (.call fun.Observation. .bind
    (lambda (text)
      (def config-value (config.decode-service text))
      (.o config: config-value processor: (make-instance InitializedRecord)))
    (lambda (candidate) (lambda (_text) (publish candidate)))))
