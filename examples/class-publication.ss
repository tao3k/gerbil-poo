;;; Inherited Record defaults/computed methods, checked initialization and FUN.
(export Transform BaseRecord LimitsRecord ServiceRecord InitializedRecord EnvelopeContract service-action)
(import (only-in :std/list/list foldl)
        ../object ../mop ../number ../object-contract
        (only-in ../type Record String Maybe List)
        (prefix-in ../generalized-prototype observation.)
        (prefix-in ./object-contracts service.)
        (prefix-in ./contract-publication publication.))

;; One existing callable interface is reused by defaults, overrides and containers.
(def Transform (Fun Integer <- Integer))

;; Record metadata owns inherited defaults and optional absent slots. Its existing
;; Class prototype creates the values; checked initialization recursively wraps them.
(define-type BaseRecord
  (Record tenant: [String default: "api"]
          run: [Transform default: (lambda (n) (+ n 1))]
          extras: [(Maybe (List Transform)) default: (void)]
          optional-run: [Transform optional: #t]))

;; Computed methods use unchanged scalar instance state. Constant scalar policy
;; remains exact; normalization does not weaken constant equality.
(define-type LimitsRecord
  (Record limit: [Integer default: 10]
          enabled: [Bool constant: #t]
          audit: [(Fun Bool <- Integer)
                  compute: (lambda (self _next) (lambda (n) (<= n (.get self limit))))]))

;; Multiple inheritance reuses current C3 slot metadata and ordinary Class defaults.
(define-type ServiceRecord
  (.cc (Record [BaseRecord LimitsRecord] bias: [Integer default: 2]) sealed: #t))

;; The hook receives a checked run method, then returns an override that must be
;; checked again. It neither publishes state nor caches an admitted instance.
(define-type InitializedRecord
  (.cc ServiceRecord .instantiate:
    (lambda (checked)
      (.cc checked run: (lambda (n) (+ (.get checked bias) ((.get checked run) n)))))))

;; Outer refinement checks the final record alongside its parsed configuration.
;; Class validation does not re-run initialization hooks during ordinary admission.
(def EnvelopeContract
  (refine (.cc ObjectContract. responsibilities:
            (.o config: publication.CapacityContract processor: InitializedRecord))
    (lambda (candidate location)
      (if (and (equal? (.get candidate config host) (.get candidate processor tenant))
               (<= (.get candidate processor bias) (.get candidate processor limit))) '()
        [(.o kind: 'service-relation path: (append location '(processor)))]))))

;; Consume normalized inherited/computed Function fields, then return exact root
;; evidence. All callback errors retain the ordinary publication failure boundary.
(def (produce context-value checked-value)
  (def processor-value (.get checked-value processor))
  (def first ((.get processor-value run) (.get checked-value config used)))
  (def extras-value (.get processor-value extras))
  (def total-value (if (void? extras-value) first
                    (foldl (lambda (transform value) (transform value)) first extras-value)))
  (def approved-value ((.get processor-value audit) total-value))
  (values (.o subject: checked-value descriptor: EnvelopeContract context: context-value
              total: total-value approved: approved-value)
          (.cc context-value commits: (+ 1 (.get context-value commits)))))

;; JSON → Class factory/hooks → outer checked FUN → exact bound publication.
;; Hooks run at construction, not each time a field or result is observed.
(def (service-action invocation context-value extras-value)
  (def publish (publication.publication-action EnvelopeContract invocation context-value
                 (cut produce context-value <>)))
  (.call observation.Observation. .bind
    (lambda (text)
      (def config-value (service.decode-service text))
      (def processor-value (make-instance InitializedRecord
        tenant: (.get config-value host) limit: (.get config-value capacity) extras: extras-value))
      (.o config: config-value processor: processor-value))
    (lambda (candidate) (lambda (_text) (publish candidate)))))
