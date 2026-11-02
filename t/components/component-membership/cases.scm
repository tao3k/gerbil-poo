;; Actual materializer work distinguishes reconstruction from merely equal values.
(def (evaluated current) (cache.cache-evaluated (graph-cache-values current)))
;; Insertion/deletion must skip the unchanged inputs and independent feedback group.
(def membership-builder (.cc cache.Builder. allow: (lambda (key) (not (memq key '(quota spare stable))))))
;; Assertions observe current support only, never retained old raw field positions.
(def (groups current) (scc.partition-groups (graph-cache-partition current)))
;; Complete scenarios cover SCC growth/shrink, provider erasure and current admission.
(def component-membership-test
  (test-suite "component insertion deletion and joint SCC publication"
    (test-case "adding two bridges merges old SCCs and invalidates unchanged shared readers"
      (def policy (.o (allowed #t) (limit 30)))
      (defvalues (old failure) (component-membership.service.publish #f (component-membership.service.source 3 4) policy (.cc cache.Builder.)))
      (check-equal? failure #f)
      (check-equal? (groups old) '((quota) (spare) (shared a b) (c d) (monitor) (settlement) (stable)))
      (def next ((component-membership.service.revision-action #t [] policy membership-builder) old))
      (check-equal? (groups next) '((quota) (spare) (shared a b c d e f) (monitor) (settlement) (stable)))
      (check-equal? (evaluated next) '(shared monitor settlement))
      (check-equal? (component-membership.service.report next) '(3 4 4 4 4 4 4 4 4 4 24 2))
      (check (eq? (graph-cache-ref old 'monitor) (graph-cache-ref next 'monitor)) => #f)
      (for-each (lambda (key) (check (eq? (graph-cache-ref old key) (graph-cache-ref next key)) => #t))
        '(quota spare stable))
      (check (eq? (graph-cache-ref next 'shared) (graph-cache-ref next 'f)) => #t)
      (check-exception (graph-cache-ref old 'e) true))
    (test-case "deleting both bridges and rewiring splits the SCC, removing every old provider"
      (def policy (.o (allowed #t) (limit 30)))
      (defvalues (old _) (component-membership.service.publish #f (component-membership.service.source 3 4) policy (.cc cache.Builder.)))
      (def expanded ((component-membership.service.revision-action #t [] policy membership-builder) old))
      (def back ((component-membership.service.revision-action #f [] policy membership-builder) expanded))
      (check-equal? (groups back) (groups old)) (check-equal? (component-membership.service.report back) (component-membership.service.report old))
      (check-equal? (evaluated back) '(shared c monitor settlement))
      (for-each (lambda (key)
        (check-exception (graph-cache-ref back key) true)
        (check-equal? (.call (graph-cache-source back) .code key) #f)
        (check-equal? (.call (graph-cache-source back) .base key) #f)) '(e f))
      (check (eq? (graph-cache-ref old 'stable) (graph-cache-ref back 'stable)) => #t)
      (def revised ((component-membership.service.revision-action #f [(cons 'quota (some (code.make-success 2)))] policy
        (.cc cache.Builder. allow: (lambda (key) (not (memq key '(spare stable)))))) back))
      (check-equal? (component-membership.service.report revised) '(2 4 2 2 2 2 2 2 8 2)))
    (test-case "dangling reads after deletion refuse before builders and current approval"
      (def policy (.o (allowed #t) (limit 30)))
      (defvalues (initial _) (component-membership.service.publish #f (component-membership.service.source 3 4) policy (.cc cache.Builder.)))
      (def old ((component-membership.service.revision-action #t [] policy membership-builder) initial))
      (def reached? #f)
      (defvalues (held failure) (publish-feedback-graph-revision old
        (lambda (spec) (graph.reconfigure spec '(quota spare shared a b c d e monitor settlement stable) []))
        component-membership.service.build-group (lambda (_ __) (set! reached? #t) #t)
        builder: (.cc cache.Builder. allow: (lambda (_) (set! reached? #t) #f))))
      (check (eq? held old) => #t) (check (not (not failure)) => #t) (check-equal? reached? #f))
    (test-case "re-adding deleted names cannot resurrect their previous code or base"
      (def policy (.o (allowed #t) (limit 30)))
      (defvalues (initial _) (component-membership.service.publish #f (component-membership.service.source 3 4) policy (.cc cache.Builder.)))
      (def expanded ((component-membership.service.revision-action #t [] policy membership-builder) initial))
      (def old ((component-membership.service.revision-action #f [] policy membership-builder) expanded))
      (def fresh (graph.reconfigure (graph-cache-source old) component-membership.service.keys []))
      (check-equal? (.call fresh .code 'e) #f) (check-equal? (.call fresh .base 'e) #f)
      (def reached? #f)
      (defvalues (held missing) (publish-feedback-graph old fresh component-membership.service.build-group
        (lambda (_ __) (set! reached? #t) #t)))
      (check (eq? held old) => #t) (check (not (not missing)) => #t) (check-equal? reached? #f)
      (def next ((component-membership.service.revision-action #t [] policy membership-builder) old))
      (check-equal? (component-membership.service.report next) (component-membership.service.report expanded))
      (check (eq? (graph-cache-ref next 'shared) (graph-cache-ref expanded 'shared)) => #f)
      (def latent (graph.declaration '(quota) [(cons 'spare (code.pure 99))]
        [(cons 'quota (some (code.make-success 3))) (cons 'spare (some (code.make-success 88)))]))
      (def cleared (graph.reconfigure latent '(quota spare) []))
      (check-equal? (.call cleared .code 'spare) #f) (check-equal? (.call cleared .base 'spare) #f))
    (test-case "joint refusal never promotes inserted components and retry rebuilds from old"
      (def policy (.o (allowed #t) (limit 12)))
      (defvalues (old _) (component-membership.service.publish #f (component-membership.service.source 3 4) policy (.cc cache.Builder.)))
      (def seen [])
      (defvalues (held denied) (publish-feedback-graph-revision old
        (lambda (spec) (component-membership.service.reconfigure spec #t [(cons 'spare (some (code.make-success 5)))])) component-membership.service.build-group
        (lambda (prior candidate) (set! seen (cons (component-membership.service.report candidate) seen)) ((component-membership.service.admit policy) prior candidate))))
      (check (eq? held old) => #t) (check (not (not denied)) => #t)
      (check-equal? seen '((3 5 5 5 5 5 5 5 5 5 30 2)))
      (check-exception (graph-cache-ref held 'e) true)
      (.putslot! policy 'limit ($constant-slot-spec 30))
      (def next ((component-membership.service.revision-action #t [(cons 'spare (some (code.make-success 5)))] policy
        (.cc cache.Builder. allow: (lambda (key) (not (memq key '(quota stable)))))) old))
      (check-equal? (evaluated next) '(spare shared monitor settlement)))
    (test-case "deleting an SCC representative reconstructs its surviving member under a new key"
      (def code-a (code.need 'b (lambda (value) (min 3 (+ 1 value)))))
      (def source (graph.declaration '(a b stable) [(cons 'a code-a) (cons 'b (code.need 'a identity))
        (cons 'stable (code.pure 2))]))
      (defvalues (old failure) (publish-feedback-graph #f source component-membership.service.build-group (lambda (_ __) #t)))
      (check-equal? failure #f)
      (defvalues (next ok) (publish-feedback-graph-revision old
        (lambda (spec) (graph.reconfigure spec '(b stable) [(cons 'b (code.pure 7))])) component-membership.service.build-group
        (lambda (_ candidate) (= (component-membership.service.value candidate 'b) 7))
        builder: (.cc cache.Builder. allow: (lambda (key) (eq? key 'b)))))
      (check-equal? ok #f) (check-equal? (groups next) '((b) (stable)))
      (check-equal? (evaluated next) '(b)) (check-exception (graph-cache-ref next 'a) true)
      (check (eq? (graph-cache-ref old 'stable) (graph-cache-ref next 'stable)) => #t))
    (test-case "a fresh isolated input constructs once while all surviving groups are skipped"
      (def source (graph.declaration '(quota stable) [(cons 'stable (code.pure 2))]
        [(cons 'quota (some (code.make-success 3)))]))
      (defvalues (old _) (publish-feedback-graph #f source component-membership.service.build-group (lambda (_ __) #t)))
      (defvalues (next ok) (publish-feedback-graph-revision old
        (lambda (spec) (graph.reconfigure spec '(quota spare stable) [] [(cons 'spare (some (code.make-success 4)))]))
        component-membership.service.build-group (lambda (_ candidate) (= (component-membership.service.value candidate 'spare) 4))
        builder: (.cc cache.Builder. allow: (lambda (key) (eq? key 'spare)))))
      (check-equal? ok #f) (check-equal? (evaluated next) '(spare))
      (check (eq? (graph-cache-ref old 'quota) (graph-cache-ref next 'quota)) => #t))
    (test-case "invalid final support and edits outside it fail at preparation"
      (def source (component-membership.service.source 3 4))
      (check-exception (graph.reconfigure source '(quota quota) []) true)
      (check-exception (graph.reconfigure source component-membership.service.compact-keys [(cons 'e (code.pure 3))]) true)
      (check-exception (graph.reconfigure source component-membership.service.compact-keys [] [(cons 'f #f)]) true)
      (check-exception (graph.reconfigure source component-membership.service.keys [(cons 'e #f) (cons 'e (code.pure 3))]) true))
    (test-case "partial deployment and current policy-only revocation both refuse"
      (def policy (.o (allowed #t) (limit 30)))
      (defvalues (old _) (component-membership.service.publish #f (component-membership.service.source 3 4) policy (.cc cache.Builder.)))
      (defvalues (held partial) (publish-feedback-graph-revision old
        (lambda (spec) (graph.reconfigure spec (append component-membership.service.compact-keys '(e)) [(cons 'e (code.pure 3))]))
        component-membership.service.build-group (component-membership.service.admit policy)))
      (check (eq? held old) => #t) (check (not (not partial)) => #t)
      (.putslot! policy 'allowed ($constant-slot-spec #f))
      (defvalues (same denied) (component-membership.service.publish old (graph-cache-source old) policy (.cc cache.Builder. allow: (lambda (_) #f))))
      (check (eq? same old) => #t) (check (not (not denied)) => #t))))

;; Return the original suites from this lexical scope.
(values component-membership-test)
