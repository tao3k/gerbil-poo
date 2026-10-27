(export service-revisions-test)
(import :std/test :clan/poo/object :clan/poo/mop :clan/poo/brace :clan/poo/support/option :clan/poo/feedback-graph :clan/poo/feedback-cache :clan/poo/lens-laws
        (prefix-in :clan/poo/generalized-graph graph.) (prefix-in :clan/poo/strong-components scc.)
        (prefix-in :clan/poo/dependency-analysis code.) (prefix-in :clan/poo/construction-cache cache.)
        (prefix-in :clan/poo/generalized-prototype gp.) (prefix-in :clan/poo/examples/service-revisions service.))
;; Work accounting comes from the actual existing group materializer.
(def (evaluated current) (cache.cache-evaluated (graph-cache-values current)))
;; Independent sources/groups must not invoke their builders during topology edits.
(def topology-builder (.cc cache.Builder. allow: (lambda (key) (not (memq key '(quota spare stable))))))
;; The current partition itself is observable for exact regrouping assertions.
(def (groups current) (scc.partition-groups (graph-cache-partition current)))
;; Controls exercise real whole-equation closure and joint approval, not only graph metadata.
(def service-revisions-test
  (test-suite "simultaneous SCC revision and shared dependency migration"
    (test-case "several old groups split and merge in one publication; unchanged monitor invalidates"
      (def policy (.o (allowed #t) (limit 30)))
      (defvalues (old failure) (service.publish #f (service.source 3 4) policy (.cc cache.Builder.)))
      (check-equal? failure #f)
      (check-equal? (groups old) '((quota) (spare) (shared a b) (c d) (e) (f) (monitor) (settlement) (stable)))
      (def next ((service.revision-action #t [] policy topology-builder) old))
      (check-equal? (groups next) '((quota) (spare) (shared c d) (a) (b) (e f) (monitor) (settlement) (stable)))
      (check-equal? (service.report next) '(3 4 4 4 4 4 4 4 4 4 24 2))
      (check-equal? (evaluated next) '(shared a b e monitor settlement))
      (check (eq? (.call (cache.cache-source (graph-cache-values old)) .code 'monitor)
                  (.call (cache.cache-source (graph-cache-values next)) .code 'monitor)) => #t)
      (check (eq? (graph-cache-ref old 'monitor) (graph-cache-ref next 'monitor)) => #f)
      (check (eq? (graph-cache-ref next 'shared) (graph-cache-ref next 'd)) => #t)
      (check (eq? (graph-cache-ref next 'e) (graph-cache-ref next 'f)) => #t)
      (for-each (lambda (key) (check (eq? (graph-cache-ref old key) (graph-cache-ref next key)) => #t))
        '(quota spare stable))
      (def back ((service.revision-action #f [] policy topology-builder) next))
      (check-equal? (groups back) (groups old))
      (check-equal? (service.report back) (service.report old))
      (check-equal? (evaluated back) '(shared c e f monitor settlement))
      (check (eq? (graph-cache-ref back 'stable) (graph-cache-ref old 'stable)) => #t))
    (test-case "migration detaches obsolete quota and keeps new quota invalidation"
      (def policy (.o (allowed #t) (limit 30)))
      (defvalues (old _) (service.publish #f (service.source 3 4) policy (.cc cache.Builder.)))
      (def migrated ((service.revision-action #t [] policy topology-builder) old))
      (defvalues (detached ok) (publish-feedback-graph-revision migrated
        (lambda (source) (graph.revise source [] [(cons 'quota (some (code.make-success 9)))]))
        service.build-group (service.admit policy)
        builder: (.cc cache.Builder. allow: (lambda (key) (eq? key 'quota)))))
      (check-equal? ok #f) (check-equal? (evaluated detached) '(quota))
      (for-each (lambda (key) (check (eq? (graph-cache-ref migrated key) (graph-cache-ref detached key)) => #t))
        '(shared a b c d e f monitor settlement stable))
      (defvalues (updated fine) (publish-feedback-graph-revision detached
        (lambda (source) (graph.revise source [] [(cons 'spare (some (code.make-success 5)))]))
        service.build-group (service.admit policy)
        builder: (.cc cache.Builder. allow: (lambda (key) (not (memq key '(quota stable)))))))
      (check-equal? fine #f) (check-equal? (evaluated updated) '(spare shared a b e monitor settlement))
      (check-equal? (service.report updated) '(9 5 5 5 5 5 5 5 5 5 30 2)))
    (test-case "an intermediate service edit refuses while the complete joint batch succeeds"
      (def policy (.o (allowed #t) (limit 30)))
      (defvalues (old _) (service.publish #f (service.source 3 4) policy (.cc cache.Builder.)))
      (def final (service.revise (graph-cache-source old) #t))
      (defvalues (held denied) (publish-feedback-graph-revision old
        (lambda (source) (graph.revise source [(cons 'shared (.call final .code 'shared))]))
        service.build-group (service.admit policy)))
      (check (eq? held old) => #t) (check (not (not denied)) => #t)
      (def next ((service.revision-action #t [] policy topology-builder) old))
      (check-equal? (service.report next) '(3 4 4 4 4 4 4 4 4 4 24 2)))
    (test-case "equal-valued migration still rebuilds all changed groups and downstream services"
      (def policy (.o (allowed #t) (limit 18)))
      (defvalues (old _) (service.publish #f (service.source 3 3) policy (.cc cache.Builder.)))
      (def next ((service.revision-action #t [] policy topology-builder) old))
      (check-equal? (service.report next) (service.report old))
      (check-equal? (evaluated next) '(shared a b e monitor settlement))
      (check (eq? (graph-cache-ref old 'shared) (graph-cache-ref next 'shared)) => #f)
      (check (eq? (graph-cache-ref old 'monitor) (graph-cache-ref next 'monitor)) => #f))
    (test-case "topology and quota change are approved once on the final candidate; refusal retains old"
      (def policy (.o (allowed #t) (limit 18)))
      (defvalues (old _) (service.publish #f (service.source 3 4) policy (.cc cache.Builder.)))
      (def inputs [(cons 'spare (some (code.make-success 5)))])
      (def prepare (lambda (source) (service.revise source #t inputs)))
      (def seen [])
      (defvalues (held refused) (publish-feedback-graph-revision old prepare service.build-group
        (lambda (prior candidate)
          (check (eq? prior old) => #t) (set! seen (cons (service.report candidate) seen))
          ((service.admit policy) prior candidate))))
      (check (eq? held old) => #t) (check (not (not refused)) => #t)
      (check-equal? seen '((3 5 5 5 5 5 5 5 5 5 30 2)))
      (.putslot! policy 'limit ($constant-slot-spec 30))
      (def next ((service.revision-action #t inputs policy
        (.cc cache.Builder. allow: (lambda (key) (not (memq key '(quota stable)))))) old))
      (check-equal? (evaluated next) '(spare shared a b e monitor settlement))
      (check-equal? (service.report old) '(3 4 3 3 3 3 3 3 3 3 18 2))
      (def back ((service.revision-action #f [(cons 'quota (some (code.make-success 2)))] policy
        (.cc cache.Builder. allow: (lambda (key) (not (memq key '(spare stable)))))) next))
      (check-equal? (service.report back) '(2 5 2 2 2 2 2 2 2 2 12 2)))
    (test-case "duplicate and unsupported batch writes fail before any builder or approval"
      (def policy (.o (allowed #t) (limit 30)))
      (defvalues (old _) (service.publish #f (service.source 3 4) policy (.cc cache.Builder.)))
      (def reached? #f)
      (def changes [(cons 'shared (code.pure 3)) (cons 'shared (code.pure 4))])
      (defvalues (held duplicate) (publish-feedback-graph-revision old
        (lambda (source) (graph.revise source changes)) service.build-group
        (lambda (_ __) (set! reached? #t) #t) builder: (.cc cache.Builder. allow: (lambda (_) (set! reached? #t) #f))))
      (check (eq? held old) => #t) (check (not (not duplicate)) => #t) (check-equal? reached? #f)
      (check-exception (graph.revise (graph-cache-source old) [] [(cons 'spare #f) (cons 'spare #f)]) true)
      (check-exception (graph.revise (graph-cache-source old) [(cons 'unknown (code.pure 0))]) true)
      (check-exception (graph.revise (graph-cache-source old) [] [(cons 'quota 'invalid)]) true))
    (test-case "failure after partial group work is never a speculative reuse base"
      (def policy (.o (allowed #t) (limit 30)))
      (defvalues (old _) (service.publish #f (service.source 3 4) policy (.cc cache.Builder.)))
      (def reached? #f)
      (defvalues (held failure) (publish-feedback-graph-revision old
        (lambda (source) (service.revise source #t)) service.build-group
        (lambda (_ __) (set! reached? #t) #t)
        builder: (.cc cache.Builder. allow: (lambda (key) (not (eq? key 'e))))))
      (check (eq? held old) => #t) (check (not (not failure)) => #t) (check-equal? reached? #f)
      (def next ((service.revision-action #t [] policy topology-builder) old))
      (check-equal? (evaluated next) '(shared a b e monitor settlement)))
    (test-case "revision guards cover preparation and FUN bind suppresses the suffix"
      (def policy (.o (allowed #t) (limit 30)))
      (defvalues (old _) (service.publish #f (service.source 3 4) policy (.cc cache.Builder.)))
      (def reached? #f)
      (def action (.call gp.Observation. .map (lambda (_) (set! reached? #t))
        (feedback-graph-revision-action (lambda (source) (error "preparation refused"))
          service.build-group (service.admit policy))))
      (check-exception (action old) true) (check-equal? reached? #f)
      (defvalues (held guarded) (publish-feedback-graph-revision old
        (lambda (source) (.putslot! policy 'allowed ($constant-slot-spec #f)) source)
        service.build-group (service.admit policy)
        guards: [(lens-check (.lens) [policy] sources: [policy])]))
      (check (eq? held old) => #t) (check (not (not guarded)) => #t)
      (check-equal? (.@ policy allowed) #t))))
