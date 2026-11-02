;; Count actual group constructors, including unchanged downstream readers.
(def (evaluated current) (cache.cache-evaluated (graph-cache-values current)))
;; Query the admitted partition rather than predicting owners from old group keys.
(def (groups current) (scc.partition-groups (graph-cache-partition current)))
;; Replacement of two service SCCs must skip both inputs and independent feedback.
(def topology-builder (.cc cache.Builder. allow: (lambda (key) (not (memq key '(quota spare stable))))))
;; Each case exercises complete publication, not just descriptor merging.
(def component-migration-test
  (test-suite "joint component replacement and shared dependency migration"
    (test-case "separate service contributions replace two SCCs in one final source"
      (def policy (.o (allowed #t) (limit 20)))
      (defvalues (old failure) (initial.publish #f (component-migration.service.source 3 4) policy (.cc cache.Builder.)))
      (check-equal? failure #f)
      (def next ((component-migration.service.revision-action policy topology-builder) old))
      (check-equal? (.@ (graph-cache-source next) keys) '(quota spare shared a c monitor settlement stable e f))
      (check-equal? (groups next) '((quota) (spare) (shared a e) (c f) (monitor) (settlement) (stable)))
      (check-equal? (evaluated next) '(shared c monitor settlement))
      (check-equal? (component-migration.service.report next) '(3 4 4 4 4 4 16 2 4 4))
      (for-each (lambda (key)
        (check-exception (graph-cache-ref next key) true)
        (check-equal? (.call (graph-cache-source next) .code key) #f)
        (check-equal? (.call (graph-cache-source next) .base key) #f)) '(b d))
      (for-each (lambda (key) (check (eq? (graph-cache-ref old key) (graph-cache-ref next key)) => #t))
        '(quota spare stable))
      (check (eq? (graph-cache-ref old 'monitor) (graph-cache-ref next 'monitor)) => #f)
      (check-equal? (initial.report old) '(3 4 3 3 3 3 3 3 12 2)))
    (test-case "membership topology and two service inputs reach one exact approval candidate"
      (def policy (.o (allowed #t) (limit 20)))
      (defvalues (old _) (initial.publish #f (component-migration.service.source 3 4) policy (.cc cache.Builder.)))
      (def parts (append component-migration.service.contributions
        [(revision.fragment [] [] [] [(cons 'quota (some (code.make-success 9)))])
         (revision.fragment [] [] [] [(cons 'spare (some (code.make-success 5)))])]))
      (def seen [])
      (defvalues (next ok) (publish-feedback-graph-revision old
        (lambda (spec) (revision.reconfigure spec parts)) component-migration.service.build-group
        (lambda (prior candidate) (set! seen (cons candidate seen)) ((component-migration.service.admit policy) prior candidate))
        builder: (.cc cache.Builder. allow: (lambda (key) (not (eq? key 'stable))))))
      (check-equal? ok #f) (check-equal? (length seen) 1) (check (eq? (car seen) next) => #t)
      (check-equal? (component-migration.service.report next) '(9 5 5 5 5 5 20 2 5 5))
      (check-equal? (evaluated next) '(quota spare shared c monitor settlement))
      (check (eq? (graph-cache-ref old 'stable) (graph-cache-ref next 'stable)) => #t))
    (test-case "partial cross-service references refuse before construction and approval"
      (def policy (.o (allowed #t) (limit 20)))
      (defvalues (old _) (initial.publish #f (component-migration.service.source 3 4) policy (.cc cache.Builder.)))
      (def reached? #f)
      (defvalues (held failure) (publish-feedback-graph-revision old
        (lambda (spec) (revision.reconfigure spec [(car component-migration.service.contributions)])) component-migration.service.build-group
        (lambda (_ __) (set! reached? #t) #t)
        builder: (.cc cache.Builder. allow: (lambda (_) (set! reached? #t) #f))))
      (check (eq? held old) => #t) (check (not (not failure)) => #t) (check-equal? reached? #f))
    (test-case "conflicts across contributions reject without silent last-writer selection"
      (def policy (.o (allowed #t) (limit 20)))
      (defvalues (old _) (initial.publish #f (component-migration.service.source 3 4) policy (.cc cache.Builder.)))
      (def part (revision.fragment '(e) [] [(cons 'e (code.pure 4))]))
      (def base-part (revision.fragment [] [] [] [(cons 'spare (some (code.make-success 4)))]))
      (def code-part (revision.fragment [] [] [(cons 'a (code.pure 4))]))
      (def remove-part (revision.fragment [] '(b) []))
      (for-each (lambda (parts)
        (def reached? #f)
        (defvalues (held failure) (publish-feedback-graph-revision old
          (lambda (spec) (revision.reconfigure spec parts)) component-migration.service.build-group
          (lambda (_ __) (set! reached? #t) #t)
          builder: (.cc cache.Builder. allow: (lambda (_) (set! reached? #t) #f))))
        (check (eq? held old) => #t) (check (not (not failure)) => #t) (check-equal? reached? #f))
        [[part part] [base-part base-part] [code-part code-part] [remove-part remove-part]
         [(revision.fragment '(a) [] [])] [(revision.fragment [] '(e) [])]
         [(revision.fragment '(b) '(b) [])]
         [remove-part (revision.fragment [] [] [(cons 'b (code.pure 4))])]]))
    (test-case "shared migration detaches old quota and propagates new quota across both SCCs"
      (def policy (.o (allowed #t) (limit 20)))
      (defvalues (old _) (initial.publish #f (component-migration.service.source 3 4) policy (.cc cache.Builder.)))
      (def migrated ((component-migration.service.revision-action policy topology-builder) old))
      (defvalues (detached ok) (publish-feedback-graph-revision migrated
        (lambda (spec) (revision.reconfigure spec
          [(revision.fragment [] [] [] [(cons 'quota (some (code.make-success 9)))])]))
        component-migration.service.build-group (component-migration.service.admit policy) builder: (.cc cache.Builder. allow: (lambda (key) (eq? key 'quota)))))
      (check-equal? ok #f) (check-equal? (evaluated detached) '(quota))
      (for-each (lambda (key) (check (eq? (graph-cache-ref migrated key) (graph-cache-ref detached key)) => #t))
        '(shared a c e f monitor settlement stable))
      (defvalues (updated good) (publish-feedback-graph-revision detached
        (lambda (spec) (revision.reconfigure spec
          [(revision.fragment [] [] [] [(cons 'spare (some (code.make-success 5)))])]))
        component-migration.service.build-group (component-migration.service.admit policy)
        builder: (.cc cache.Builder. allow: (lambda (key) (not (memq key '(quota stable)))))))
      (check-equal? good #f) (check-equal? (evaluated updated) '(spare shared c monitor settlement))
      (check-equal? (component-migration.service.report updated) '(9 5 5 5 5 5 20 2 5 5)))
    (test-case "joint policy denial retains the exact old snapshot and retry reconstructs replacements"
      (def policy (.o (allowed #t) (limit 12)))
      (defvalues (old _) (initial.publish #f (component-migration.service.source 3 4) policy (.cc cache.Builder.)))
      (def seen [])
      (defvalues (held refused) (publish-feedback-graph-revision old component-migration.service.reconfigure component-migration.service.build-group
        (lambda (prior candidate)
          (check (eq? prior old) => #t) (set! seen (cons (component-migration.service.report candidate) seen))
          ((component-migration.service.admit policy) prior candidate))))
      (check (eq? held old) => #t) (check (not (not refused)) => #t)
      (check-equal? seen '((3 4 4 4 4 4 16 2 4 4)))
      (.putslot! policy 'limit ($constant-slot-spec 20))
      (def next ((component-migration.service.revision-action policy topology-builder) old))
      (check-equal? (evaluated next) '(shared c monitor settlement))
      (check-exception ((component-migration.service.revision-action policy topology-builder) next) true))
    (test-case "no-op contributions still obtain current approval without rebuilding clean groups"
      (def policy (.o (allowed #t) (limit 20)))
      (defvalues (old _) (initial.publish #f (component-migration.service.source 3 4) policy (.cc cache.Builder.)))
      (def next ((component-migration.service.revision-action policy topology-builder) old))
      (def seen #f)
      (defvalues (same ok) (publish-feedback-graph-revision next
        (lambda (spec) (revision.reconfigure spec [])) component-migration.service.build-group
        (lambda (prior candidate) (set! seen candidate) ((component-migration.service.admit policy) prior candidate))
        builder: (.cc cache.Builder. allow: (lambda (_) #f))))
      (check-equal? ok #f) (check (eq? seen same) => #t) (check-equal? (evaluated same) [])
      (.putslot! policy 'allowed ($constant-slot-spec #f))
      (defvalues (held refused) (publish-feedback-graph-revision same
        (lambda (spec) (revision.reconfigure spec [])) component-migration.service.build-group (component-migration.service.admit policy)
        builder: (.cc cache.Builder. allow: (lambda (_) #f))))
      (check (eq? held same) => #t) (check (not (not refused)) => #t))
    (test-case "joint membership without a replacement provider cannot reuse latent definitions"
      (def policy (.o (allowed #t) (limit 20)))
      (defvalues (old _) (initial.publish #f (component-migration.service.source 3 4) policy (.cc cache.Builder.)))
      (def reached? #f)
      (def parts (map (lambda (part)
        (if (memq 'f (.@ part added)) (.cc part codes: [(cons 'c (code.need 'f identity))]) part))
        component-migration.service.contributions))
      (defvalues (held refused) (publish-feedback-graph-revision old
        (lambda (spec) (revision.reconfigure spec parts)) component-migration.service.build-group
        (lambda (_ __) (set! reached? #t) #t)))
      (check (eq? held old) => #t) (check (not (not refused)) => #t) (check-equal? reached? #f))))

;; Return the original suites from this lexical scope.
(values component-migration-test)
