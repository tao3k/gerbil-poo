;;; Optional typed plugin pipeline through existing JSON, FUN and publication.
(export Transform PipelineSchema pipeline-action)
(import (only-in :std/list/list foldl)
        ../object
        ../mop
        ../number
        ../object-contract
        (only-in ../type Maybe OrFalse TypeValuePair Tuple List String)
        (runtime: :clan/poo/generalized-prototype)
        (prefix-in (only-in ../generalized-prototype Observation.) observation.)
        (prefix-in ./object-contracts service.)
        (prefix-in ./contract-publication publication.))

;; Application-approved callable interface; TypeValuePair remains an open Type
;; carrier, while this particular consumer explicitly owns its accepted interface.
(def Transform (Fun Integer <- Integer))

;; Void means no plugin list; #f and void separately mean absent outer/inner
;; fallback. Refinement observes wrapped typed payloads and the actual final root.
(def PipelineSchema
  (refine (.cc ObjectContract. responsibilities:
            (.o config: publication.CapacityContract
                plugins: (Maybe (List (Tuple String TypeValuePair)))
                fallback: (OrFalse (Maybe Transform))))
    (lambda (candidate location)
      (def plugins-value (.get candidate plugins))
      (if (or (void? plugins-value)
              (andmap (lambda (row)
                        (and (equal? (vector-ref row 0) (.get candidate config host))
                             (eq? (car (vector-ref row 1)) Transform))) plugins-value)) '()
        [(.o kind: 'plugin-interface path: (append location '(plugins)))]))))

;; A checked typed value exposes its normalized callback. Sentinels never invoke
;; an optional callback; ordered transforms and fallback use the same Integer API.
(def (produce context-value checked-value)
  (def plugins-value (.get checked-value plugins))
  (def fallback-value (.get checked-value fallback))
  (def used (.get checked-value config used))
  (def transformed
    (if (void? plugins-value) used
      (foldl (lambda (row value) ((cdr (vector-ref row 1)) value)) used plugins-value)))
  (def total-value
    (if (or (not fallback-value) (void? fallback-value)) transformed (fallback-value transformed)))
  (values (.o subject: checked-value descriptor: PipelineSchema context: context-value total: total-value)
          (.cc context-value commits: (+ 1 (.get context-value commits)))))

;; Parse data-only JSON, admit/normalize executable fields, then bind publication
;; to this exact checked object and immutable context. No accepted-value cache.
(def (pipeline-action invocation context-value plugins-value fallback-value)
  (def publish (publication.publication-action PipelineSchema invocation context-value
                 (cut produce context-value <>)))
  (.call observation.Observation. .bind
    (lambda (text) (.o config: (service.decode-service text) plugins: plugins-value fallback: fallback-value))
    (lambda (candidate) (lambda (_text) (publish candidate)))))
