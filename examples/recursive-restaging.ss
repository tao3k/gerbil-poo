;;; Explicit current-catalog preparation while requests from older rounds wait.
(export transition-action)
(import (only-in :std/list/list filter) ../object
        (prefix-in ../recursive-validation graph.)
        (prefix-in ../recursive-staging staging.)
        (prefix-in ./recursive-topology service.)
        (prefix-in ./recursive-migration migration.))

;; Adapt the same immutable service recipes to the catalog observed on EACH
;; preparation, including reintroduction of a formerly removed provider. The
;; returned FUN Reader prepares a request, not a graph; later publication still
;; checks that exact snapshot. No closure, refinement or approval is cached here.
(def (transition-action targets providers chosen (accept? #t) (weight 2))
  (staging.restaging-action
    (lambda (current)
      (def present (graph.closed-names current))
      (def wanted (vector->list providers))
      (def recipes [service.primary service.secondary])
      (def keys '(primary secondary))
      (values
        (map cdr (filter (lambda (entry)
          (and (memq (car entry) wanted) (not (memq (car entry) present))))
          (map cons keys recipes)))
        (filter (lambda (key) (and (memq key present) (not (memq key wanted)))) keys)
        (append (service.peer-recipes targets providers weight)
          [(migration.summary chosen accept?)])))))
