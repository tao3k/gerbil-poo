;;; Paired private discovery kernels over the SAME captured Graph rows.
;;; Ordinary consumers keep partition; this white-box fixture adds no export.
(extern namespace: clan/poo/strong-components discover discover-wide normalize partition-captured)
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
  (let (compact (capture-compact keys reads (.@ work edge-visits)))
    (check-discovery (compact-discovery-result compact) keys
      (scc.partition-groups part) (.@ work discoveries) (.@ work groups) (.@ work edge-visits))
    (for (root keys)
      (unless (and (equal? (compact-row compact root) (hash-ref reads root))
                   (equal? (compact-reachable compact root) (list-reachable-order reads root))
                   (equal? (reachable reads root) (list-reachable-order reads root)))
        (error "ordered indexed reachability oracle" root))))
  #t)

(def (discovery-study part keys family size)
  ;; Borrow immutable rows from the already certified public partition. Charge
  ;; projection into a hash explicitly; do not time author getters twice.
  (defvalues (reads projection)
    (measure (cut captured-rows part keys) 1))
  (def expected (scc.partition-groups part))
  (def work (scc.partition-work part))
  (def edges (.@ work edge-visits))
  (def groups-count (.@ work groups))
  (for ((regime '(natural collected))
        (order '((dense packed packed dense) (packed dense dense packed))))
    (let (observations [])
      (for (side order)
        (let-values (((result costs) (measure (cut discovery-result
                      (if (eq? side 'dense) discover-wide discover) keys reads)
                      1 (eq? regime 'collected))))
          ;; Normalization and the complete canonical group oracle are untimed.
          ;; Only costs escape this iteration; candidate owner maps are retired.
          (check-discovery result keys expected size groups-count edges)
          (set! observations (cons (list side costs) observations))))
      (display "GRAPH-DISCOVERY-PAIR ")
      (write (list family size regime order (cons 'captured-index-projection projection)
                   (reverse observations)))
      (newline) (force-output)))
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
