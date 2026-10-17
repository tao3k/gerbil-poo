;;; On-demand SCC receipts over the actual declared recursive validation catalog.
(export partition changed-members)
(import (only-in :std/list/list find filter delete-duplicates/hash)
        ./object (prefix-in ./recursive-validation validation.)
        (prefix-in ./strong-components scc.) (prefix-in ./generalized-graph graph.)
        (prefix-in ./dependency-analysis computation.))

;; Reuse the existing checked SCC algorithm without invoking node builders,
;; validators, getters or the dummy computation evaluator. Ordinary revision does
;; not pay this analysis cost. Historical partition receipts are immutable data;
;; obtaining a new receipt requires a current graph before AND after analysis.
(def (partition current)
  (def names (append (validation.closed-names current) []))
  (def source (graph.declaration names
    (map (lambda (name) (cons name (.cc computation.Computation.
      reads: (validation.closed-reads current name)
      .evaluate: (lambda (_) (error "topology metadata is not a computation"))))) names)))
  (def result (scc.partition source))
  (validation.closed-reads current (car names))
  result)

;; Compare membership sets, including additions/removals, rather than source row
;; order or representative labels. These observations never authorize cache reuse;
;; the existing recipe/stamp/dependency closure remains the admission authority.
(def (changed-members before after)
  (unless (and (scc.partition? before) (scc.partition? after)) (error "checked SCC partitions required"))
  (def old-groups (scc.partition-groups before))
  (def new-groups (scc.partition-groups after))
  ;; A missing key differs from every real singleton component.
  (def (group groups name) (find (lambda (members) (memq name members)) groups))
  ;; The SCC module guarantees distinct keys within each admitted partition.
  (def (same? left right)
    (and left right (= (length left) (length right)) (andmap (cut memq <> right) left)))
  (filter (lambda (name) (not (same? (group old-groups name) (group new-groups name))))
    (delete-duplicates/hash (apply append (append old-groups new-groups)))))
