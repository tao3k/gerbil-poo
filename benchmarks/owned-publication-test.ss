;;; Optional complete publication benchmark through the public Graph API.
(export owned-publication-test)
(import :std/test :std/iter
        (only-in :clan/poo/mop/prototype .lens)
        (only-in :clan/poo/graph/feedback/builder component-group-builder)
        (only-in :clan/poo/generalized-closure closed-raw)
        (only-in :clan/poo/graph/feedback/cache group-closed)
        (only-in :clan/poo/graph/feedback publish-owned-feedback-graph graph-cache-ref graph-cache-partition)
        (prefix-in :clan/poo/graph/schedule graph.)
        (prefix-in :clan/poo/graph/scc scc.)
        (prefix-in :clan/poo/dependency-analysis code.)
        (only-in :clan/poo/benchmarks/closure-measure measure qualified-metrics))

;; Source declaration and result checks are outside the publication window.
(def owned-publication-test
  (test-suite "complete cold publication of 10000 components"
    (test-case "stock publication with one dependency and isolated programs"
      (def count 10000)
      (def names (for/collect (i (in-range count))
        (string->symbol (string-append "publication-owner-" (number->string i)))))
      (def provider (car names))
      (def reader (cadr names))
      (def constant (code.pure 0))
      (def source (graph.declaration names
        (map (lambda (key)
          (cons key (if (eq? key reader) (code.need provider identity) constant))) names)))
      (def build (component-group-builder names (lambda (_) (.lens)) 0 0 8))
      (def approvals 0)
      (def (accept _ __) (set! approvals (1+ approvals)) #t)
      (defvalues (head stats)
        (measure (lambda ()
          (defvalues (head failure) (publish-owned-feedback-graph source build accept))
          (when failure (raise failure))
          head) 1))
      (displayln (list 'OWNED-PUBLICATION (qualified-metrics stats)))
      (force-output)
      (check-equal? approvals 1)
      (check-equal? (closed-raw (group-closed (graph-cache-ref head reader))) 0)
      (def partition (graph-cache-partition head))
      (check-equal? (scc.partition-groups partition) (map list names))
      (def reads (scc.partition-reads partition))
      (check (andmap (lambda (key) (equal? (reads key)
        (if (eq? key reader) (list provider) []))) names) => #t))))
