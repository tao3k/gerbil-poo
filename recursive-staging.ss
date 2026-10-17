;;; Deferred recursive catalog edits over the existing sequential closure engine.
(export stage-reconfiguration)
(import (prefix-in ./recursive-validation validation.))

;; A staged request is an ordinary FUN Reader action. Copy edit list spines so
;; callers cannot replace contributions after staging. Recipe bodies/metadata are
;; immutable by protocol. No speculative graph, builder or approval runs here.
;; Stale attempts refuse before construction; failed closure leaves the previous
;; graph valid. Re-stage against the actual current graph after a competing commit
;; or watched-input change. This is not a concurrent compare-and-swap operation.
(def (stage-reconfiguration previous added removed replacements (limit 256))
  (unless (and (list? added) (list? removed) (list? replacements))
    (error "recursive edit lists required"))
  (def additions (append added []))
  (def removals (append removed []))
  (def updates (append replacements []))
  (def checkpoint (validation.validation-checkpoint previous (append additions updates)))
  (def action (validation.reconfiguration-action additions removals updates limit))
  (lambda (current)
    (checkpoint current)
    (action current)))
