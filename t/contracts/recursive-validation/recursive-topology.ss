;;; Interleaved simultaneous SCC merges/splits, shared migration and evidence.



;; Preserve exact phase controls instead of accepting unrelated callback failures.
(def (phase? expected)
  (lambda (cause) (and (graph.validation-failure? cause)
    (eq? expected (graph.validation-failure-kind cause)))))

;; Select actual multi-member service SCCs, leaving provider/report singletons visible
;; in the original receipt for dependency inspection and historical comparison.
(def (cycles partition)
  (filter (lambda (members) (> (length members) 1)) (scc.partition-groups partition)))

;; Existing application policy composes with exact bound-evidence publication.
(def Call (metadata.contract (metadata.predicate "object" object?)
  (metadata.predicate "evidence" object?) (lambda (_ _request _result) #t) metadata.truth))

;; Exercise actual canonical references and optional analysis across seven rounds.
(def recursive-topology-test
  (test-suite "recursive SCC topology revision"
    (test-case "two simultaneous merges splits and crossed merges with retry"
      (def initial (recursive-topology.service.initial)) (def first-partition (recursive-topology.topology.partition initial))
      (check-equal? (cycles first-partition) '((ingress auth) (billing ledger) (index cache) (notify delivery)))
      (def idle (graph.closed-ref initial 'idle)) (def idle-type (graph.closed-type initial 'idle))
      (def first-ingress (graph.closed-ref initial 'ingress))
      (def first-type (graph.closed-type initial 'ingress))
      (check-equal? (.get (graph.closed-ref initial 'report) total) 82)
      (def mixed '#(secondary secondary secondary secondary primary primary primary primary))
      (def all-secondary (make-vector 8 'secondary))
      ;; Only two recipes change in the second pair of SCCs; their other partners
      ;; must be invalidated automatically by new reachability.
      (def merged (graph.reconfigure-validation initial [recursive-topology.service.secondary] []
        (append (recursive-topology.service.peer-recipes recursive-topology.service.merged mixed 2 '(ingress auth billing ledger cache delivery))
          [(migration.summary 'notify)])))
      (def merged-partition (recursive-topology.topology.partition merged))
      (check-equal? (cycles merged-partition) '((ingress auth billing ledger) (index cache notify delivery)))
      (check-equal? (.get (graph.closed-ref merged 'report) total) 108)
      (check (and (memq 'secondary (recursive-topology.topology.changed-members first-partition merged-partition)) #t) => #t)
      (check (eq? (graph.closed-ref merged 'index) (graph.closed-ref merged 'notify)) => #f)
      (check-exception (validate first-type first-ingress) (phase? 'stale))
      (def secondary (graph.closed-ref merged 'secondary))
      ;; Split both quartets, move every shared dependency, remove unused provider.
      (def split (graph.reconfigure-validation merged [] '(primary)
        (append (recursive-topology.service.peer-recipes recursive-topology.service.split all-secondary) [(migration.summary 'auth)])))
      (def split-partition (recursive-topology.topology.partition split))
      (check-equal? (cycles split-partition) '((ingress billing) (auth ledger) (index notify) (cache delivery)))
      (check (eq? secondary (graph.closed-ref split 'secondary)) => #t)
      (check-equal? (.get (graph.closed-ref split 'report) total) 128)
      (check (and (memq 'primary (recursive-topology.topology.changed-members merged-partition split-partition)) #t) => #t)
      (check (andmap (cut memq <> (recursive-topology.topology.changed-members merged-partition split-partition)) recursive-topology.service.names) => #t)
      (def split-root (graph.closed-ref split 'report)) (def split-type (graph.closed-type split 'report))
      (def edits (recursive-topology.service.peer-recipes recursive-topology.service.crossed all-secondary 2 '(billing ledger notify delivery)))
      ;; Final refusal after all candidates are normalized must retain both old
      ;; groups and capabilities; the retry does not reuse speculative receivers.
      (check-exception (graph.reconfigure-validation split [] []
        (append edits [(migration.summary 'cache #f)])) (phase? 'admission))
      (check-equal? (cycles (recursive-topology.topology.partition split)) (cycles split-partition))
      (check (eq? split-root (validate split-type split-root)) => #t)
      (def crossed ((graph.reconfiguration-action [] [] (append edits [(migration.summary 'cache)])) split))
      (check-equal? (cycles (recursive-topology.topology.partition crossed)) '((ingress billing index notify) (auth ledger cache delivery)))
      (check-equal? (.get (graph.closed-ref crossed 'report) total) 132)
      (check-exception (validate split-type split-root) (phase? 'stale))
      ;; Return to the original partition with fresh references. Matching group
      ;; labels do not authorize revival of a capability from the first round.
      (def restored (graph.reconfigure-validation crossed [] []
        (append (recursive-topology.service.peer-recipes recursive-topology.service.original all-secondary) [(migration.summary 'ingress)])))
      (def restored-partition (recursive-topology.topology.partition restored))
      (check-equal? (cycles restored-partition) (cycles first-partition))
      (check-equal? (.get (graph.closed-ref restored 'report) total) 127)
      (check-exception (validate first-type (graph.closed-ref restored 'ingress)) (phase? 'stale))
      (def delivery (graph.closed-ref restored 'delivery))
      (def delivery-type (graph.closed-type restored 'delivery))
      (def computed (graph.reconfigure-validation restored [] [] [(migration.summary 'delivery)]))
      (check-equal? (graph.closed-evaluated computed) '(summary report meter))
      (check-equal? (recursive-topology.topology.changed-members restored-partition (recursive-topology.topology.partition computed)) [])
      (check-equal? (.get (graph.closed-ref computed 'report) total) 134)
      ;; Edit just one member of one SCC: retain all six services in other SCCs,
      ;; the computed reader and shared provider, while rebinding the partner.
      (def cache-node (graph.closed-ref computed 'cache))
      (def summary (graph.closed-ref computed 'summary))
      (def final (graph.reconfigure-validation computed [] []
        (recursive-topology.service.peer-recipes recursive-topology.service.original all-secondary 3 '(ingress))))
      (check-equal? (graph.closed-evaluated final) '(ingress auth report meter))
      (check (eq? cache-node (graph.closed-ref final 'cache)) => #t)
      (check (eq? summary (graph.closed-ref final 'summary)) => #t)
      (check (eq? delivery (validate delivery-type delivery)) => #t)
      (check (eq? idle (validate idle-type idle)) => #t)
      (check (eq? secondary (graph.closed-ref final 'secondary)) => #t)
      (check-equal? (.get (graph.closed-ref final 'meter) total) 135)
      (def context-value (.o commits: 6))
      (defvalues (result state refusal)
        ((recursive-topology.service.publish-action final 135 recursive-topology.service.original all-secondary 'delivery Call context-value)
          (.o report: (graph.closed-ref final 'report))))
      (check-equal? refusal #f) (check-equal? (.get result total) 135)
      (check-equal? (.get state commits) 7)
      (def descriptor-value (recursive-topology.service.envelope final 135 recursive-topology.service.original all-secondary 'delivery))
      (def stale-context (.o commits: 5))
      (def stale-action (recursive-topology.publication.publication-action descriptor-value Call context-value
        (lambda (checked) (values (.o subject: checked descriptor: descriptor-value context: stale-context)
                                  (.o commits: 7)))))
      (defvalues (_ old-context stale-failure) (stale-action (.o report: (graph.closed-ref final 'report))))
      (check (eq? old-context context-value) => #t)
      (check-equal? (metadata.failure-phase stale-failure) 'logic)
      (check-exception (recursive-topology.topology.partition initial) (phase? 'stale)))
    (test-case "reflection copies reads and does not replay any node computation"
      (def calls 0) (def normalized 0)
      (def counted (.cc Integer .validate: (lambda (value)
        (set! normalized (+ normalized 1)) value)))
      (def recipe (graph.validation-node 'root '(root) [] (lambda (reference source)
        (set! calls (+ calls 1))
        (list (Record peer: [(reference 'root)] value: [counted]) (.o value: 1 peer: (source 'root))))))
      (def closed (graph.revise-validation #f [recipe]))
      ;; This is an observation AFTER closure, not a parallel internal binding.
      (let ((before normalized))
        (def reflected (graph.closed-reads closed 'root))
        (set-car! reflected 'absent)
        (check-equal? (graph.closed-reads closed 'root) '(root))
        (check-equal? (cycles (recursive-topology.topology.partition closed)) [])
        (check-equal? calls 1)
        (check-equal? normalized before)
        (check (> before 0) => #t)))
    (test-case "ordinary closure cannot invent undeclared topology metadata"
      (def current (graph.close-validation (lambda (_reference)
        (list (list 'root (Record value: [Integer]) (.o value: 1))))))
      (check-exception (recursive-topology.topology.partition current) (phase? 'protocol)))
    (test-case "historical group comparison ignores source row representatives"
      (def a (graph.validation-node 'a '(b) [] (lambda (reference source)
        (list (Record peer: [(reference 'b)]) (.o peer: (source 'b))))))
      (def b (graph.validation-node 'b '(a) [] (lambda (reference source)
        (list (Record peer: [(reference 'a)]) (.o peer: (source 'a))))))
      (def first (graph.revise-validation #f [a b])) (def before (recursive-topology.topology.partition first))
      (def second (graph.revise-validation first [b a]))
      (check-equal? (recursive-topology.topology.changed-members before (recursive-topology.topology.partition second)) [])
      (check-equal? (graph.closed-evaluated second) []))))

;; Return the original suites from this lexical scope.
(values recursive-topology-test)
