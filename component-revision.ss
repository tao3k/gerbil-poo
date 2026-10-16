;;; Joint component membership edits before SCC discovery and whole publication.
(export Fragment. fragment reconfigure)
(import (only-in :std/list/list delete-duplicates/hash filter) ./object ./mop
        (prefix-in ./generalized-graph graph.))
;; Service contributions use ordinary POO descriptors; code/base remain separate
;; namespaces, and cross-fragment references are checked only on the final graph.
(define-type (Fragment. @ [] added removed codes bases))
;; Describe one immutable contribution. Membership lists declare actual additions
;; and removals, not an alternate support view or an implicit replacement policy.
(def (fragment added removed codes (bases []))
  (.cc Fragment. added: added removed: removed codes: codes bases: bases))
;; Join all services before construction: reject duplicate or stale membership
;; edits, forbid remove/re-add ambiguity, and delegate provider conflict checks to
;; graph.reconfigure. Unedited survivors keep identity; additions have no latent
;; providers. The ordered union determines the final deterministic SCC key order.
;; Descriptors/lists and callbacks obey the existing immutable-source discipline.
(def (reconfigure spec fragments)
  ;; Flatten each provider namespace in deterministic contribution order.
  (def (collect field) (apply append (map (lambda (part) (.ref part field)) fragments)))
  (def added (collect 'added))
  (def removed (collect 'removed))
  ;; Membership validation applies across all services, not just each descriptor.
  (def (distinct-symbols? names)
    (and (list? names) (andmap symbol? names)
      (= (length names) (length (delete-duplicates/hash names)))))
  (unless (and (distinct-symbols? added) (distinct-symbols? removed)
               (andmap (lambda (key) (not (memq key (.@ spec keys)))) added)
               (andmap (lambda (key) (memq key (.@ spec keys))) removed))
    (error "conflicting or stale component membership contributions"))
  (graph.reconfigure spec
    (append (filter (lambda (key) (not (memq key removed))) (.@ spec keys)) added)
    (collect 'codes) (collect 'bases)))
