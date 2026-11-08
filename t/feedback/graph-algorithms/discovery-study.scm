;;; Paired private discovery kernels over the SAME captured Graph rows.
;;; Ordinary consumers keep partition; this white-box fixture adds no export.
(extern namespace: clan/poo/strong-components discover discover-wide normalize partition-captured capture-graph)
(extern namespace: clan/poo/recursive-validation reachable)

(def (discovery-result kernel keys reads)
  (let-values (((owners nodes groups edges finished popped) (kernel keys reads)))
    (vector owners nodes groups edges finished popped)))

(def (captured-rows part keys)
  (let ((table (make-hash-table-eq)) (read-row (scc.partition-reads part)))
    (for (key keys) (hash-put! table key (read-row key))) table))

(def (check-discovery result keys expected-groups nodes groups-count expected-edges)
  (let-values (((groups _members _ranks) (normalize keys (vector-ref result 0))))
    (unless (and (equal? groups expected-groups)
                 (= (vector-ref result 1) nodes)
                 (= (vector-ref result 2) groups-count)
                 (= (vector-ref result 3) expected-edges)
                 (= (vector-ref result 4) nodes)
                 (= (vector-ref result 5) nodes))
      (error "captured discovery groups/work oracle"))))

;; Reuse the existing bounded exhaustive/property inputs; no new case matrix.
(def (discovery-controls part keys)
  (def reads (captured-rows part keys))
  (def work (scc.partition-work part))
  (for (kernel (list discover-wide))
    (check-discovery (discovery-result kernel keys reads) keys
      (scc.partition-groups part) (.@ work discoveries) (.@ work groups) (.@ work edge-visits)))
  (let-values (((captured index declared edges) (capture-graph keys (cut hash-ref reads <>))))
    (unless (and (= declared (.@ work edge-visits)) (= edges declared)
                 (andmap (lambda (key) (equal? (hash-ref captured key) (hash-ref reads key))) keys))
      (error "fused capture rows/work oracle"))
    (check-discovery (compact-discovery-result index) keys
      (scc.partition-groups part) (.@ work discoveries) (.@ work groups) (.@ work edge-visits)))
  (let (compact (capture-compact keys reads (.@ work edge-visits)))
    (check-discovery (compact-discovery-result compact) keys
      (scc.partition-groups part) (.@ work discoveries) (.@ work groups) (.@ work edge-visits))
    (for (root keys)
      (unless (and (equal? (compact-row compact root) (hash-ref reads root))
                   (equal? (compact-reachable compact root) (list-reachable-order reads root))
                   (equal? (reachable reads root) (list-reachable-order reads root)))
        (error "ordered indexed reachability oracle" root))))
  #t)

;; Frozen pre-fusion support/row capture, same pure historical row provider.
;; No author factory or business evaluator is substituted into a kernel window.
(def (wide-capture-graph keys read-owner)
  (def supported (make-hash-table-eq)) (def rows (make-hash-table-eq))
  (def declared 0) (def edges 0)
  (for (key keys) (hash-put! supported key #t))
  (for (key keys)
    (let (row (read-owner key))
      (unless (and (list? row) (andmap (cut hash-key? supported <>) row))
        (error "unsupported component read" key row))
      (let (unique (delete-duplicates/hash row))
        (hash-put! rows key unique) (set! edges (+ edges (length unique))))
      (set! declared (+ declared (length row)))))
  (values rows #f declared edges))

(def (capture-and-discover side keys read-owner)
  (let-values (((rows index _declared edges)
                ((if (eq? side 'wide) wide-capture-graph capture-graph) keys read-owner)))
    (if index (compact-discovery-result index) (discovery-result discover-wide keys rows))))

(def (discovery-study read-owner keys family size expected edges preparation)
  ;; One frozen pure row provider is the input to BOTH cold pipelines. Row
  ;; generation is charged inside every window. No stored E-sized input is
  ;; artificially retained while testing the streaming Declaration interface.
  ;; Stored-row encoding/query and public certification have their own windows.
  (def groups-count (length expected))
  (for ((regime '(natural collected))
        (order '((wide fused fused wide) (fused wide wide fused))))
    (let (observations [])
      (for (side order)
        (display "GRAPH-DISCOVERY-BEGIN ") (write (list family size regime side))
        (newline) (force-output)
        (let-values (((result costs) (measure (cut capture-and-discover side keys read-owner) 1 (eq? regime 'collected))))
          ;; Normalization and the complete canonical group oracle are untimed.
          ;; Only costs escape this iteration; candidate owner maps are retired.
          (check-discovery result keys expected size groups-count edges)
          (set! observations (cons (list side costs) observations))))
      (display "GRAPH-DISCOVERY-PAIR ")
      (write (list family size regime order (cons 'input-preparation preparation)
                   '(input-kind . generated-rows)
                   '(window . row-generation-admission-index-discovery-symbolic-output)
                   (reverse observations)))
      (newline) (force-output)))
  (void))

(def (reachability-study reads keys family size edges)
  ;; Time only the indexed native walk at capacity. The old list rule is already
  ;; checked on every bounded exhaustive/property graph, including output order.
  (let* ((backwards (reverse keys)) (band? (eq? family 'band))
         (root (car (if band? backwards keys))) (expected-order (if band? keys backwards)))
    (let-values (((visited costs) (measure (cut hash-reachable reads root) 1)))
      (unless (equal? visited expected-order) (error "capacity reachability order" family size))
      (display "GRAPH-REACHABILITY-SCALE ")
      (write (list family size 'full (cons 'reached-owners size) (cons 'captured-edges edges) costs))
      (newline) (force-output)))
  (when (eq? family 'band)
    (let-values (((visited costs) (measure (cut hash-reachable reads (car keys)) 1)))
      (unless (equal? visited (list (car keys))) (error "sparse reachability support" size))
      (display "GRAPH-REACHABILITY-SCALE ")
      (write (list family size 'sparse '(reached-owners . 1) '(captured-edges . 0) costs))
      (newline) (force-output))))

;; Bound small-graph setup separately before choosing a promotion policy. Every
;; row is a batch on one frozen input; normalization/capture are not in the timer.
(def (small-reachability-study)
  (def repetitions 1000)
  (for* ((size '(1 4 8 16 32 64)) (family '(chain ring)))
    (def keys (names size))
    (def rows (make-hash-table-eq))
    (for (i (in-range size))
      (hash-put! rows (vector-ref keys i) (family-reads family keys size i)))
    (def root (vector-ref keys 0))
    (def expected (reverse (vector->list keys)))
    (for ((regime '(natural collected))
          (order '((list indexed indexed list) (indexed list list indexed))))
      (let (observations [])
        (for (side order)
          (let-values (((visited costs) (measure
                        (cut (if (eq? side 'list) list-reachable-order hash-reachable) rows root)
                        repetitions (eq? regime 'collected))))
            (unless (equal? visited expected) (error "small reachability order" size side))
            (set! observations (cons (list side costs) observations))))
        (display "GRAPH-REACHABILITY-PAIR ")
        (write (list family size regime order (cons 'repetitions repetitions) (reverse observations)))
        (newline) (force-output))))
  (displayln "GRAPH-SMALL-REACHABILITY-OK observations=96 repetitions=1000"))
