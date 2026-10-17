;;; Multi-round support edits, computed footprint migration and safe retry.
(export recursive-migration-test)
(import :std/test ../object ../mop ../number
        (only-in ../type Record)
        (prefix-in ../recursive-validation graph.)
        (prefix-in ../examples/recursive-migration service.)
        (prefix-in ../declarative-metadata metadata.)
        (prefix-in ../examples/contract-publication publication.))

;; Inspect the exact lifecycle refusal rather than catching any unrelated error.
(def (phase? kind)
  (lambda (cause) (and (graph.validation-failure? cause)
                      (eq? kind (graph.validation-failure-kind cause)))))

;; Existing publication policy composes with root refinement and bound evidence.
(def Call (metadata.contract (metadata.predicate "object" object?)
  (metadata.predicate "evidence" object?) (lambda (_ _request _result) #t) metadata.truth))

;; Assert effects only after complete final graph admission, across changing support.
(def recursive-migration-test
  (test-suite "recursive catalog migration"
    (test-case "six rounds migrate sharing reindex names refuse ABA and retry"
      (def a (service.provider 'a 3))
      (def first (graph.revise-validation #f
        [a (service.peer 'left 'right 'a 2) (service.peer 'right 'left 'a 3)
           (service.summary 'left) service.report service.idle]))
      (def old-a (graph.closed-ref first 'a)) (def old-a-type (graph.closed-type first 'a))
      (def idle (graph.closed-ref first 'idle)) (def idle-type (graph.closed-type first 'idle))
      (check-equal? (.get (graph.closed-ref first 'report) total) 19)
      ;; Add a provider and change both shared links plus the computed reader.
      (def second ((graph.reconfiguration-action [ (service.provider 'b 8) ] []
        [(service.peer 'left 'right 'b 2) (service.peer 'right 'left 'b 3) (service.summary 'right)]) first))
      (check-equal? (graph.closed-evaluated second) '(left right summary report b))
      (check (eq? old-a (graph.closed-ref second 'a)) => #t)
      (check-equal? (.get (graph.closed-ref second 'report) total) 35)
      (def b (graph.closed-ref second 'b))
      (def old-summary (graph.closed-ref second 'summary))
      (def old-summary-type (graph.closed-type second 'summary))
      ;; Remove the now unread provider, add a downstream observer, retain all readers.
      (def report (graph.closed-ref second 'report))
      (def third (graph.reconfigure-validation second [service.meter] '(a) []))
      (check-equal? (graph.closed-evaluated third) '(meter))
      (check (eq? report (graph.closed-ref third 'report)) => #t)
      (check (eq? b (graph.closed-ref third 'b)) => #t)
      (check-exception (validate old-a-type old-a) (phase? 'stale))
      ;; Re-submit the EXACT original recipe after a gap. Numeric equality and the
      ;; old key/recipe do not restore the retired receiver or its capability.
      (def fourth (graph.reconfigure-validation third [a] '(b)
        [(service.peer 'left 'right 'a 2) (service.peer 'right 'left 'a 3) (service.summary 'left)]))
      (check-equal? (.get (graph.closed-ref fourth 'report) total) 19)
      (check-equal? (.get (graph.closed-ref fourth 'meter) total) 19)
      (check (eq? old-a (graph.closed-ref fourth 'a)) => #f)
      (check-exception (validate old-a-type (graph.closed-ref fourth 'a)) (phase? 'stale))
      (check-exception (validate (graph.closed-type fourth 'a) old-a) (phase? 'reference))
      (check-exception (validate old-summary-type old-summary) (phase? 'stale))
      (def current-a (graph.closed-ref fourth 'a))
      (def current-report (graph.closed-ref fourth 'report))
      (def current-type (graph.closed-type fourth 'report))
      ;; A late whole-node refusal cannot retire the current graph or references.
      (check-exception (graph.reconfigure-validation fourth [] []
        [(service.peer 'left 'right 'a 9) (service.summary 'right #f)]) (phase? 'admission))
      (check (eq? current-report (graph.closed-ref fourth 'report)) => #t)
      (check (eq? current-report (validate current-type current-report)) => #t)
      (def fifth (graph.reconfigure-validation fourth [] []
        [(service.peer 'left 'right 'a 9) (service.summary 'right)]))
      (check-equal? (graph.closed-evaluated fifth) '(left right summary report meter))
      (check (eq? current-a (graph.closed-ref fifth 'a)) => #t)
      (check-equal? (.get (graph.closed-ref fifth 'report) total) 27)
      (check-exception (validate current-type current-report) (phase? 'stale))
      ;; Changing only the computed reader must skip the peer SCC and provider.
      (def left (graph.closed-ref fifth 'left)) (def left-type (graph.closed-type fifth 'left))
      (def right (graph.closed-ref fifth 'right))
      (def sixth (graph.reconfigure-validation fifth [] [] [(service.summary 'left)]))
      (check-equal? (graph.closed-evaluated sixth) '(summary report meter))
      (check (eq? left (graph.closed-ref sixth 'left)) => #t)
      (check (eq? right (graph.closed-ref sixth 'right)) => #t)
      (check (eq? left (validate left-type left)) => #t)
      (check (eq? idle (validate idle-type idle)) => #t)
      (check (eq? idle (graph.closed-ref sixth 'idle)) => #t)
      (check-equal? (.get (graph.closed-ref sixth 'meter) total) 33)
      (check-exception ((.get left handler) #f) TypeError?)
      (def context-value (.o commits: 7))
      (def candidate (.o report: (graph.closed-ref sixth 'report)))
      (defvalues (result state failure) ((service.publish-action sixth 33 'left Call context-value) candidate))
      (check-equal? failure #f) (check-equal? (.get result total) 33)
      (check-equal? (.get state commits) 8)
      (def descriptor-value (service.envelope sixth 33 'left))
      (def stale-context (.o commits: 6))
      (def stale-action (publication.publication-action descriptor-value Call context-value
        (lambda (subject) (values (.o subject: subject descriptor: descriptor-value context: stale-context)
                                  (.o commits: 8)))))
      (defvalues (_ old-state refusal) (stale-action candidate))
      (check (eq? old-state context-value) => #t)
      (check-equal? (metadata.failure-phase refusal) 'logic))
    (test-case "equal computed outputs still replace changed reader references"
      (def first (graph.revise-validation #f
        [(service.provider 'a 3) (service.peer 'left 'right 'a 2)
         (service.peer 'right 'left 'a 2) (service.summary 'left) service.report service.idle]))
      (def left (graph.closed-ref first 'left)) (def right (graph.closed-ref first 'right))
      (def old-summary (graph.closed-ref first 'summary))
      (def old-type (graph.closed-type first 'summary))
      (def second (graph.reconfigure-validation first [] [] [(service.summary 'right)]))
      (check-equal? (graph.closed-evaluated second) '(summary report))
      (check-equal? (.get (graph.closed-ref second 'report) total) 18)
      (check-equal? (.get old-summary total) 6)
      (check-equal? (.get (graph.closed-ref second 'summary) total) 6)
      (check (eq? left (graph.closed-ref second 'left)) => #t)
      (check (eq? right (graph.closed-ref second 'right)) => #t)
      (check-exception (validate old-type old-summary) (phase? 'stale))
      (def checked (validate (service.envelope second 18 'right)
        (.o report: (graph.closed-ref second 'report))))
      (check (eq? (.get checked report summary reader) right) => #t))
    (test-case "conflicting membership and duplicate edits refuse before builders"
      (def calls 0)
      ;; Count actual builders; declaring an edit has no construction effects.
      (def (recipe name) (graph.validation-node name [] [] (lambda (_reference _source)
        (set! calls (+ calls 1)) (list (Record value: [Integer]) (.o value: 1)))))
      (def initial (recipe 'root)) (def next (recipe 'other))
      (def graph (graph.revise-validation #f [initial]))
      (check-exception (graph.reconfigure-validation graph [next next] [] []) (phase? 'edit))
      (check-exception (graph.reconfigure-validation graph [initial] '(root) []) (phase? 'edit))
      (check-exception (graph.reconfigure-validation graph [] '(root) [initial]) (phase? 'edit))
      (check-exception (graph.reconfigure-validation graph [] [] [next]) (phase? 'edit))
      (check-exception (graph.reconfigure-validation graph [] '(absent) []) (phase? 'edit))
      (check-exception (graph.reconfigure-validation graph [] [] [initial initial]) (phase? 'edit))
      (check-equal? calls 1))
    (test-case "dangling migration empty support and node limit retain prior graph"
      (def graph (graph.revise-validation #f [(service.provider 'a 3)
        (service.peer 'left 'right 'a 2) (service.peer 'right 'left 'a 3)]))
      (def root (graph.closed-ref graph 'left))
      (check-exception (graph.reconfigure-validation graph [] '(a) []) (phase? 'missing-reference))
      (check-exception (graph.reconfigure-validation graph [] '(a left right) []) (phase? 'catalog))
      (check-exception (graph.reconfigure-validation graph [service.idle] [] [] 3) (phase? 'catalog))
      (check (eq? root (graph.closed-ref graph 'left)) => #t))
    (test-case "retired catalog refuses its batch before any new construction"
      (def calls 0)
      (def initial (graph.revise-validation #f [service.idle]))
      (graph.reconfigure-validation initial [] [] [])
      (def addition (graph.validation-node 'extra [] [] (lambda (_reference _source)
        (set! calls (+ calls 1)) (list (Record) (.o)))))
      (check-exception (graph.reconfigure-validation initial [addition] [] []) (phase? 'stale))
      (check-equal? calls 0))))
