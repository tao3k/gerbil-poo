;; Per-node work permissions allow source changes but forbid rebuilding independent feedback.
(def builder (.cc cache.Builder. allow: (lambda (key) (not (eq? key 'stable)))))
;; Describe phase/input contributions with the existing POO abstraction.
(def (change phase (inputs [])) (.cc joint-topology.service.Change. phase: phase inputs: inputs))
;; Actual current SCC membership remains observable independently of values.
(def (groups snapshot endpoint) (scc.partition-groups (graph-cache-partition (joint.head snapshot endpoint))))
;; Controls use full closure and actual immutable bundle pointers, not only arithmetic.
(def joint-topology-test
  (test-suite "asymmetric atomic component membership topology and shared approval"
    (test-case "one endpoint adds bridges while the untouched endpoint only reapproves"
      (def owner (joint-topology.service.start)) (def original (joint.current owner))
      (def changes [(cons 'a (change 'merge [(cons 'spare (some (code.make-success 2)))]))])
      (defvalues (next ok) (joint.submit! owner (joint-topology.service.stage-current owner changes 12 24 builder)))
      (check-equal? ok #f)
      (check-equal? (joint-topology.service.value next 'a) 12) (check-equal? (joint-topology.service.value next 'b) 12)
      (check-equal? (length (car (cddr (groups next 'a)))) 7)
      (check-exception (graph-cache-ref (joint.head next 'b) 'e) true)
      (for-each (lambda (key)
        (check (eq? (graph-cache-ref (joint.head original 'b) key)
                    (graph-cache-ref (joint.head next 'b) key)) => #t)) '(quota spare shared c monitor settlement stable)))
    (test-case "seven atomic rounds interleave insert delete split merge and shared input migration"
      (def owner (joint-topology.service.start)) (def original (joint.current owner))
      (def old-request (joint-topology.service.stage-current owner [(cons 'a (change 'merge)) (cons 'b (change 'merge))] 24 48 builder))
      (def rounds (list
        (list [(cons 'a (change 'merge [(cons 'spare (some (code.make-success 2)))]))] 12 24 12 12)
        (list [(cons 'a (change 'replace)) (cons 'b (change 'merge))] 24 32 8 24)
        (list [(cons 'a (change 'restore)) (cons 'b (change 'replace))] 16 28 12 16)
        (list [(cons 'a (change 'merge [(cons 'spare (some (code.make-success 5)))]))
               (cons 'b (change 'restore [(cons 'quota (some (code.make-success 2)))]))] 30 38 30 8)
        (list [(cons 'a (change 'replace)) (cons 'b (change 'merge))] 24 44 20 24)
        (list [(cons 'a (change 'restore)) (cons 'b (change 'replace))] 16 28 12 16)
        (list [(cons 'b (change 'restore [(cons 'quota (some (code.make-success 3)))]))] 12 24 12 12)))
      (def final (foldl (lambda (entry previous)
        (def changes (car entry)) (def ceiling (cadr entry)) (def budget (caddr entry))
        (def sibling (joint-topology.service.stage-current owner changes ceiling budget builder))
        (defvalues (next ok) (joint.submit! owner (joint-topology.service.stage-current owner changes ceiling budget builder)))
        (check-equal? ok #f)
        (check-equal? (joint-topology.service.value next 'a) (list-ref entry 3))
        (check-equal? (joint-topology.service.value next 'b) (list-ref entry 4))
        (check-equal? (.@ (joint.approval next 'shared) budget) budget)
        (for-each (lambda (endpoint)
          (check (eq? (graph-cache-ref (joint.head original endpoint) 'stable)
                      (graph-cache-ref (joint.head next endpoint) 'stable)) => #t)) '(a b))
        (defvalues (held stale) (joint.submit! owner sibling))
        (check (eq? held next) => #t) (check (not (not stale)) => #t)
        next) original rounds))
      (for-each (lambda (endpoint)
        (for-each (lambda (key)
          (check-exception (graph-cache-ref (joint.head final endpoint) key) true)
          (check-equal? (.call (graph-cache-source (joint.head final endpoint)) .code key) #f)
          (check-equal? (.call (graph-cache-source (joint.head final endpoint)) .base key) #f)) '(e f))) '(a b))
      (defvalues (held stale) (joint.submit! owner old-request))
      (check (eq? held final) => #t) (check (not (not stale)) => #t))
    (test-case "final shared budget refuses both topologies then fresh preparation succeeds"
      (def owner (joint-topology.service.start)) (def old (joint.current owner))
      (def changes [(cons 'a (change 'merge))])
      (def denied (joint-topology.service.stage-current owner changes 24 35 builder))
      (defvalues (held failure) (joint.submit! owner denied))
      (check (eq? held old) => #t) (check (not (not failure)) => #t)
      (check-equal? (.@ (joint.approval held 'shared) limit) 12)
      (check-exception (graph-cache-ref (joint.head held 'a) 'e) true)
      (defvalues (next ok) (joint.submit! owner (joint-topology.service.stage-current owner changes 24 36 builder)))
      (check-equal? ok #f) (check-equal? (joint-topology.service.value next 'a) 24) (check-equal? (joint-topology.service.value next 'b) 12))
    (test-case "restoration and split fail their shared budget without changing any installed field"
      (def owner (joint-topology.service.start))
      (defvalues (merged ok) (joint.submit! owner (joint-topology.service.stage-current owner
        [(cons 'a (change 'merge)) (cons 'b (change 'merge))] 24 48 builder)))
      (check-equal? ok #f)
      (def bad (joint.stage owner [] [(cons 'a [])] builder: builder))
      (defvalues (same good) (joint.submit! owner bad))
      (check-equal? good #f)
      (check (eq? (joint.approval same 'shared) (joint.approval merged 'shared)) => #t)
      (defvalues (prepared prepare-ok) (joint.submit! owner (joint-topology.service.stage-current owner
        [(cons 'a (change 'replace))] 24 40 builder)))
      (check-equal? prepare-ok #f)
      (def request (joint-topology.service.stage-current owner [(cons 'a (change 'restore)) (cons 'b (change 'replace))] 16 27 builder))
      (defvalues (held refused) (joint.submit! owner request))
      (check (eq? held prepared) => #t) (check (not (not refused)) => #t)
      (defvalues (next fine) (joint.submit! owner (joint-topology.service.stage-current owner
        [(cons 'a (change 'restore)) (cons 'b (change 'replace))] 16 28 builder)))
      (check-equal? fine #f) (check-equal? (joint-topology.service.value next 'a) 12) (check-equal? (joint-topology.service.value next 'b) 16))))

;; Return the original suites from this lexical scope.
(values joint-topology-test)
