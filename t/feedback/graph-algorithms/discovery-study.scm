;;; Paired private discovery kernels over the SAME captured Graph rows.
;;; Ordinary consumers keep partition; this white-box fixture adds no export.
(extern namespace: clan/poo/strong-components discover discover-wide normalize partition-captured capture-graph)

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
(def (discovery-controls part keys original-rows)
  (def reads (captured-rows part keys))
  (def work (scc.partition-work part))
  (for (kernel (list discover-wide))
    (check-discovery (discovery-result kernel keys reads) keys
      (scc.partition-groups part) (.@ work discoveries) (.@ work groups) (.@ work edge-visits)))
  (def declared-source (make-hash-table-eq))
  (for ((key keys) (row (in-vector original-rows))) (hash-put! declared-source key row))
  (let-values (((captured index declared edges) (capture-graph keys (cut hash-ref declared-source <>))))
    (unless (and (= declared (.@ work validation-edges)) (= edges (.@ work edge-visits))
                 (andmap (lambda (key) (and (equal? (hash-ref captured key) (hash-ref reads key))
                   (equal? (compact-row index key) (hash-ref reads key)))) keys))
      (error "fused capture rows/work oracle"))
    (check-discovery (compact-discovery-result index) keys
      (scc.partition-groups part) (.@ work discoveries) (.@ work groups) (.@ work edge-visits)))
  (let (compact (capture-compact keys reads (.@ work edge-visits)))
    (check-discovery (compact-discovery-result compact) keys
      (scc.partition-groups part) (.@ work discoveries) (.@ work groups) (.@ work edge-visits))
    (for (root keys)
      (unless (and (equal? (compact-row compact root) (hash-ref reads root))
                   (equal? (compact-reachable compact root) (list-reachable-order reads root)))
        (error "ordered indexed reachability oracle" root))))
  #t)

;; Frozen epoch/list capture at e94cfc2, for matched allocation measurements.
(def (prior-capture-graph keys read-owner)
  (def count (length keys))
  (def positions (make-hash-table-symbolic size: count))
  (def raw (interface-instance-object positions))
  (unless (symbol-hash-table? raw) (error "captured owner index representation"))
  (let assign ((rest keys) (at 0))
    (unless (null? rest)
      (unless (symbol? (car rest)) (error "symbolic captured owner required" (car rest)))
      (symbolic-table-set! raw (car rest) at)
      (assign (cdr rest) (1+ at))))
  (unless (= count (hash-length positions)) (error "distinct captured owners required"))
  (def word-support? (and (fixnum? (* 2 count)) (<= (* 2 count) 4294967295)))
  (def packed? word-support?)
  ;; Per-invocation duplicate membership, allocated only for a multi-key row.
  ;; It never stores source/currentness approvals. owner+1 is fresh for this row.
  (def row-marks #f)
  (def offsets (and packed? (make-u32vector (1+ count) 0)))
  (def reads (make-hash-table-eq size: count))
  (def declared 0) (def edges 0)
  ;; Private, bounded construction chunks, not a retained graph/value cache.
  ;; A small graph pays only its support-sized chunk; an empty graph pays none.
  (def capacity (max 1 (min count 65536)))
  (def chunks []) (def chunk #f) (def used 0)
  (def (append-target id)
    (when packed?
      ;; Outside the word domain retain the original wide algorithm, rather
      ;; than imposing a new public graph-size refusal.
      (if (or (not (fixnum? (1+ edges))) (>= edges 4294967295))
        (begin (set! packed? #f) (set! offsets #f)
               (set! chunks []) (set! chunk #f))
        (begin
          (when (= used capacity)
            (set! chunks (cons chunk chunks)) (set! chunk #f) (set! used 0))
          (unless chunk (set! chunk (make-u32vector capacity 0)))
          (u32vector-set! chunk used id) (set! used (fx+ used 1))))))
  (for ((key keys) (owner (in-range count)))
    (when packed? (u32vector-set! offsets owner edges))
    (def deps (read-owner key))
    (unless (and (list? deps) (andmap symbol? deps))
      (error "unsupported component read" key deps))
    (if (and word-support? (pair? deps) (pair? (cdr deps)))
      (begin
        (unless row-marks (set! row-marks (make-u32vector count 0)))
        (let ((token (fx+ owner 1)))
          ;; Same reverse scan as the standard normalizer. The owner index
          ;; proves support and supplies the mark-cell address in one lookup.
          ;; Both outputs prepend together, preserving identity and row order.
          (let-values (((ids unique)
                        (let scan ((pending (reverse deps)) (ids []) (unique []))
                          (if (null? pending) (values ids unique)
                            (let* ((dep (car pending)) (id (symbolic-table-ref raw dep #f)))
                              (unless id (error "unsupported component read" key deps))
                              (if (fx= (u32vector-ref row-marks id) token)
                                (scan (cdr pending) ids unique)
                                (begin
                                  (u32vector-set! row-marks id token)
                                  (scan (cdr pending) (cons id ids) (cons dep unique)))))))))
            (for (id ids) (append-target id) (set! edges (1+ edges)))
            (hash-put! reads key unique))))
      ;; Preserve the inexpensive empty/singleton path and the original wide
      ;; domain. Copy singleton spines before the next independent callback.
      (let (unique (cond ((null? deps) []) ((null? (cdr deps)) (list (car deps)))
                        (else (delete-duplicates/hash deps))))
        (for (dep unique)
          (let (id (symbolic-table-ref raw dep #f))
            (unless id (error "unsupported component read" key deps))
            (append-target id))
          (set! edges (1+ edges)))
        (hash-put! reads key unique)))
    (set! declared (+ declared (length deps))))
  (def index
    (and packed?
      (begin
        (u32vector-set! offsets count edges)
        (let* ((tail (if chunk
                       (if (= used capacity) chunk (u32vector-copy chunk 0 used))
                       (make-u32vector 0)))
               (targets (if (null? chunks) tail
                          (u32vector-concatenate (reverse (cons tail chunks))))))
          (unless (= (u32vector-length targets) edges) (error "captured edge count changed"))
          (make-compact-graph (list->vector keys) positions offsets targets)))))
  (values reads index declared edges))


(def (capture-and-discover side keys read-owner)
  (let-values (((rows index _declared edges)
                ((if (eq? side 'prior) prior-capture-graph capture-graph) keys read-owner)))
    (if index (compact-discovery-result index) (discovery-result discover-wide keys rows))))

(def (discovery-study read-owner keys family size expected edges preparation)
  ;; One frozen pure row provider is the input to BOTH cold pipelines. Row
  ;; generation is charged inside every window. No stored E-sized input is
  ;; artificially retained while testing the streaming Declaration interface.
  ;; Stored-row encoding/query and public certification have their own windows.
  (def groups-count (length expected))
  (for ((regime '(natural collected))
        (order '((prior buffered buffered prior) (buffered prior prior buffered))))
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
    (defvalues (index preparation)
      (measure (cut capture-compact (vector->list keys) rows
        (if (eq? family 'chain) (1- size) size)) 1))
    (def root (vector-ref keys 0))
    (def expected (reverse (vector->list keys)))
    (for ((regime '(natural collected))
          (order '((list indexed indexed list) (indexed list list indexed))))
      (let (observations [])
        (for (side order)
          (let-values (((visited costs) (measure
                        (lambda () (if (eq? side 'list) (list-reachable-order rows root) (compact-reachable index root)))
                        repetitions (eq? regime 'collected))))
            (unless (equal? visited expected) (error "small reachability order" size side))
            (set! observations (cons (list side costs) observations))))
        (display "GRAPH-REACHABILITY-PAIR ")
        (write (list family size regime order (cons 'repetitions repetitions) (cons 'index-preparation preparation) (reverse observations)))
        (newline) (force-output))))
  (displayln "GRAPH-SMALL-REACHABILITY-OK observations=96 repetitions=1000"))
