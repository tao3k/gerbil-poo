;;; Several entry points share one graph and keep their own effect contexts.
(export entry-action)
(import ../object
        (prefix-in ../recursive-validation graph.)
        (prefix-in ./recursive-topology service.))

;; Bind a per-entry context and invocation to existing whole-value refinement and
;; exact evidence. FUN Readers still receive the actual checked current root.
(def (entry-action expected targets providers chosen invocation context)
  (lambda (current)
    ((service.publish-action current expected targets providers chosen invocation context)
      (.o report: (graph.closed-ref current 'report)))))

