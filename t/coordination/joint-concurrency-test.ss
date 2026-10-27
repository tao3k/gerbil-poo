(export joint-concurrency-test)
(import :std/test (only-in :std/list/list foldl filter) :clan/poo/object :clan/poo/mop :clan/poo/brace :clan/poo/feedback-graph
        (prefix-in :clan/poo/joint-publication joint.) (prefix-in :clan/poo/construction-cache cache.)
        (prefix-in :clan/poo/examples/joint-topology service.) (prefix-in :clan/poo/examples/joint-receipts receipts.)
        (prefix-in :clan/poo/examples/joint-concurrency concurrent.))
;; Independent feedback cannot rebuild during any concurrent lifecycle round.
(def builder (.cc cache.Builder. allow: (lambda (key) (not (eq? key 'stable)))))
;; Existing phase descriptors carry both services' declared support/source edits.
(def (changes phase) (map (lambda (key) (cons key (.cc service.Change. phase: phase))) '(a b)))
;; Construct a distinct proposed shared policy; installed metadata is immutable.
(def (policy owner ceiling budget) (.cc (joint.approval (joint.current owner) 'shared) limit: ceiling budget: budget))
;; Keep actual successful install outcomes, independently of completion order.
(def (successes outcomes) (filter (lambda (entry) (not (cdr entry))) outcomes))
;; Bounded native worker threads race only AFTER all receipt approvals returned.
(def joint-concurrency-test
  (test-suite "real concurrent approved receipt installation and SCC revisions"
    (test-case "five ready workers race after shared revision drift through six lifecycle rounds"
      (def owner (service.start)) (def original (joint.current owner))
      (def rows '((merge 24 48 24) (replace 16 32 16) (restore 12 24 12)
                  (merge 24 48 24) (replace 16 32 16) (restore 12 24 12)))
      (def history (foldl (lambda (row previous)
        (def before (joint.current owner)) (def edits (changes (car row)))
        (def ceiling (cadr row)) (def budget (caddr row))
        (def shared (policy owner ceiling budget))
        (def pending (receipts.approve-revisions owner [edits edits] shared builder))
        (def pa (policy owner ceiling budget)) (def pb (policy owner ceiling (+ budget 2)))
        (def a (car (receipts.approve-revisions owner [edits] pa builder)))
        (def b (car (receipts.approve-revisions owner [edits] pb builder)))
        (def outcomes (concurrent.install-concurrently owner [(car pending) a (cadr pending) b a]
          before-release: (lambda ()
            (check (eq? before (joint.current owner)) => #t)
            ;; Both writes occur while ALL workers await release, and both
            ;; budgets still approve. Equal values cannot revive shared revisions.
            (.putslot! shared 'budget ($constant-slot-spec (+ budget 1)))
            (.putslot! shared 'budget ($constant-slot-spec budget)))))
        (check-equal? (length outcomes) 5)
        (def accepted (successes outcomes)) (check-equal? (length accepted) 1)
        (def winner (joint.current owner))
        (check (eq? (caar accepted) winner) => #t)
        (check (or (eq? (joint.approval winner 'shared) pa) (eq? (joint.approval winner 'shared) pb)) => #t)
        (for-each (lambda (entry)
          (check (or (eq? (car entry) before) (eq? (car entry) winner)) => #t)) outcomes)
        ;; Earlier-round receipts race again against the current topology.
        (def replay (concurrent.install-concurrently owner previous))
        (check-equal? (successes replay) [])
        (for-each (lambda (entry) (check (eq? (car entry) winner) => #t)) replay)
        (for-each (lambda (key)
          (check-equal? (service.value winner key) (list-ref row 3))
          (check (eq? (graph-cache-ref (joint.head original key) 'stable)
                      (graph-cache-ref (joint.head winner key) 'stable)) => #t)
          (case (car row)
            ((replace) (check-exception (graph-cache-ref (joint.head winner key) 'b) true))
            ((restore) (for-each (lambda (removed)
              (check-exception (graph-cache-ref (joint.head winner key) removed) true)
              (check-equal? (.call (graph-cache-source (joint.head winner key)) .code removed) #f)
              (check-equal? (.call (graph-cache-source (joint.head winner key)) .base removed) #f)) '(e f))))) '(a b))
        (append previous pending [a b])) [] rows))
      ;; Fresh policy-only publication restores exact initial values with a new
      ;; snapshot. No obsolete receipt may resurrect its topology or policy.
      (def canonical (car (receipts.approve-revisions owner [[]] (policy owner 12 24)
        (.cc cache.Builder. allow: (lambda (_) #f)))))
      (defvalues (final ok) (joint.install! owner canonical)) (check-equal? ok #f)
      (def replay (concurrent.install-concurrently owner history))
      (check-equal? (successes replay) [])
      (for-each (lambda (entry) (check (eq? (car entry) final) => #t)) replay)
      (check-equal? (.@ (joint.approval final 'shared) budget) 24))
    (test-case "three workers racing the same receipt install it exactly once"
      (def owner (service.start))
      (def receipt (car (receipts.approve-revisions owner [(changes 'merge)] (policy owner 24 48) builder)))
      (def outcomes (concurrent.install-concurrently owner [receipt receipt receipt]))
      (check-equal? (length (successes outcomes)) 1)
      (for-each (lambda (entry) (check (eq? (car entry) (joint.current owner)) => #t)) outcomes))
    (test-case "failed coordination releases no installations and propagates the original failure"
      (def owner (service.start)) (def before (joint.current owner))
      (def receipt (car (receipts.approve-revisions owner [(changes 'merge)] (policy owner 24 48) builder)))
      (def failure (list 'coordination-refused))
      (check-exception (concurrent.install-concurrently owner [receipt receipt]
        before-release: (lambda () (raise failure))) (lambda (caught) (eq? caught failure)))
      (check (eq? before (joint.current owner)) => #t)
      (def outcomes (concurrent.install-concurrently owner [receipt receipt]))
      (check-equal? (length (successes outcomes)) 1))))
