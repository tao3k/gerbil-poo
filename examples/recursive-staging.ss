;;; Interleaved staged SCC edits composed with refinement and bound publication.
(export stage-transition publication-action)
(import ../object (prefix-in ../recursive-staging staging.)
        (prefix-in ../recursive-validation graph.)
        (prefix-in ../generalized-prototype observation.)
        (prefix-in ./recursive-topology service.)
        (prefix-in ./recursive-migration migration.))

;; Reuse the existing checked peer/summary recipes for independently staged edits.
;; Select only changed peer recipes; declared dependencies perform the reclosure.
(def (stage-transition current targets providers chosen added removed
                       (selected service.names) (accept? #t) (weight 2))
  (staging.stage-reconfiguration current added removed
    (append (service.peer-recipes targets providers weight selected)
      [(migration.summary chosen accept?)])))

;; FUN binds the guarded revision to whole-value refinement and exact evidence.
;; Four results expose the installed graph separately from the effect result:
;; later policy refusal does not roll back an already successful graph revision.
(def (publication-action request expected targets providers chosen invocation context-value)
  (.call observation.Observation. .bind request
    (lambda (next)
      (lambda (_previous)
        (defvalues (result state refusal)
          ((service.publish-action next expected targets providers chosen invocation context-value)
            (.o report: (graph.closed-ref next 'report))))
        (values next result state refusal)))))
