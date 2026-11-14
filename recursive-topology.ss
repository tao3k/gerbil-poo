;;; On-demand SCC receipts over the actual declared recursive validation catalog.
(export partition changed-members)
(import (only-in :std/list/list filter append-map delete-duplicates/hash)
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
  (def changed (make-hash-table-eq))
  ;; Lean ComponentWitness.indexed_group_check_exact: unique member sets agree
  ;; iff cardinalities agree and every old member resolves to that same new group.
  ;; One verdict per old group; do not scan a fresh giant group per singleton.
  (for-each (lambda (members)
    (let* ((root (car members)) (fresh (scc.partition-group-of after root))
           (same (and fresh (= (length members) (scc.partition-group-size after root))
             (andmap (lambda (node) (eq? fresh (scc.partition-group-of after node))) members))))
      (unless same
        (for-each (lambda (node) (hash-put! changed node #t)) members)))) old-groups)
  (for-each (lambda (members)
    (for-each (lambda (node)
      (unless (scc.partition-group-of before node) (hash-put! changed node #t))) members))
    new-groups)
  ;; Preserve the existing old/new union and Gerbil duplicate-removal order,
  ;; without applying append to an unbounded number of components. Gerbil
  ;; append-map reverses each mapped row; reverse restores the original members.
  (filter (cut hash-key? changed <>)
    (delete-duplicates/hash (append-map reverse (append old-groups new-groups)))))
