;;; Paired private discovery kernels over the SAME captured Graph rows.
;;; Ordinary consumers keep partition; this white-box fixture adds no export.
(extern namespace: clan/poo/strong-components discover discover-wide normalize partition-captured capture-graph wide-reachable)
(extern namespace: clan/poo/recursive-validation affected-owners)

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
                 (or (and (= (vector-ref result 3) expected-edges)
                          (= (vector-ref result 4) nodes) (= (vector-ref result 5) nodes))
                     (and (= groups-count nodes) (= (vector-ref result 3) 0)
                          (= (vector-ref result 4) 0) (= (vector-ref result 5) 0))))
      (error "captured discovery groups/work oracle"))))

;; Reuse the existing bounded exhaustive/property inputs; no new case matrix.
(def (discovery-controls part keys original-rows)
  (def reads (captured-rows part keys))
  (def work (scc.partition-work part))
  (for (kernel (list discover-wide))
    (check-discovery (discovery-result kernel keys reads) keys
      (scc.partition-groups part) (length keys) (.@ work groups) (.@ work quotient-edges)))
  (def declared-source (make-hash-table-eq))
  (for ((key keys) (row (in-vector original-rows))) (hash-put! declared-source key row))
  (def expected-direction 3)
  (for ((key keys) (owner (in-range (length keys))))
    (for (dep (hash-ref reads key))
      (def id (let position ((rest keys) (at 0))
                (if (eq? (car rest) dep) at (position (cdr rest) (1+ at)))))
      (cond ((< id owner) (set! expected-direction (fxand expected-direction 1)))
            ((> id owner) (set! expected-direction (fxand expected-direction 2))))))
  (let-values (((captured index declared edges) (capture-graph keys (cut hash-ref declared-source <>))))
    (unless (and (= expected-direction (compact-graph-direction index))
                 (= declared (.@ work validation-edges)) (= edges (.@ work quotient-edges))
                 (andmap (lambda (key) (and (equal? (hash-ref captured key) (hash-ref reads key))
                   (equal? (compact-row index key) (hash-ref reads key)))) keys))
      (error "fused capture rows/work oracle"))
    (check-discovery (compact-discovery-result index) keys
      (scc.partition-groups part) (length keys) (.@ work groups) (.@ work quotient-edges)))
  ;; Same bounded inputs check query-only product erasure. No second author
  ;; pass belongs to a production capture; this is an independent differential.
  (defvalues (discarded projected projected-declared projected-edges)
    (capture-graph keys (cut hash-ref declared-source <>) #f))
  (unless (and (not discarded) projected
               (= projected-declared (.@ work validation-edges))
               (= projected-edges (.@ work quotient-edges)))
    (error "query projection retained symbolic rows or changed work"))
  (let (compact (capture-compact keys reads (.@ work quotient-edges)))
    (unless (= expected-direction (compact-graph-direction compact))
      (error "captured source rank flags disagree with independent row order"))
    (check-discovery (compact-discovery-result compact) keys
      (scc.partition-groups part) (length keys) (.@ work groups) (.@ work quotient-edges))
    ;; Force the general engine even when source ranks could bypass it. This
    ;; reuses every existing bounded case, including empty/self-only graphs.
    (let (general (compact-discover compact))
      (vector-set! general 0 (compact-component-owners compact general))
      (check-discovery general keys (scc.partition-groups part) (length keys)
        (.@ work groups) (.@ work quotient-edges)))
    (for (root keys)
      (unless (and (equal? (compact-row projected root) (hash-ref reads root))
                   (equal? (compact-reachable projected root) (list-reachable-order reads root))
                   (equal? (compact-row compact root) (hash-ref reads root))
                   (equal? (compact-reachable compact root) (list-reachable-order reads root)))
        (error "ordered indexed reachability oracle" root))))
  ;; Same bounded exhaustive/property graphs, two roots and duplicated hints.
  ;; The oracle uses the independent hash walk; only the production inverse
  ;; worklist receives the callback-free bucket/edge probe.
  (def inverse (make-hash-table-symbolic size: (length keys)))
  (for (key keys) (hash-put! inverse key []))
  (for (consumer keys)
    (for (provider (hash-ref reads consumer))
      (hash-put! inverse provider (cons consumer (hash-ref inverse provider)))))
  (def roots (if (null? keys) [] (if (null? (cdr keys)) keys (list (car keys) (cadr keys)))))
  (def expected (make-hash-table-eq))
  (for (root roots)
    (hash-for-each (lambda (key _) (hash-put! expected key #t)) (baseline-reachable inverse root)))
  (def inverse-work (vector 0 0))
  (def actual (affected-owners inverse (append roots roots) inverse-work))
  (unless (and (= (hash-length actual) (hash-length expected))
               (andmap (lambda (key) (eq? (hash-key? actual key) (hash-key? expected key))) keys)
               (= (vector-ref inverse-work 0) (hash-length expected))
               (= (vector-ref inverse-work 1) (foldl (lambda (key count)
                   (+ count (length (hash-ref inverse key)))) 0 (hash-keys expected))))
    (error "old inverse closure membership/inverse-work oracle"))
  #t)

;; Frozen six-vector production discovery at 3dfd464; reference only.
;; Numeric Tarjan over the exact CSR rows. This is the existing algorithm:
;; discovery order, lowlinks and pop order are unchanged. No hash per edge.
;; state 0 = fresh; 1..N = active discovery+1; N+1+component = retired.
(def (prior-compact-discover graph)
  (def offsets (compact-graph-offsets graph))
  (def targets (compact-graph-targets graph))
  (def count (vector-length (compact-graph-names graph)))
  (unless (and (fixnum? (* 2 count)) (<= (* 2 count) 4294967295))
    (error "compact SCC state word range" count))
  (def state (make-u32vector count 0)) (def low (make-u32vector count 0))
  (def members (make-u32vector count 0))
  (def saved-nodes (make-u32vector count 0))
  (def saved-cursors (make-u32vector count 0))
  (def saved-ends (make-u32vector count 0))
  (def next 0) (def component 0) (def member-top 0)
  (def examined 0) (def finished 0) (def popped 0)
  (def (enter node)
    (set! next (fx+ next 1))
    (u32vector-set! state node next) (u32vector-set! low node next)
    (u32vector-set! members member-top node)
    (set! member-top (fx+ member-top 1)))
  (for (root (in-range count))
    (when (fx= (u32vector-ref state root) 0)
      (enter root)
      (let walk ((node root) (top 0) (cursor (u32vector-ref offsets root))
                 (end (u32vector-ref offsets (fx+ root 1))))
        (if (fx< cursor end)
          (let* ((dep (u32vector-ref targets cursor)) (next-cursor (fx+ cursor 1))
                 (dep-state (u32vector-ref state dep)))
            (set! examined (fx+ examined 1))
            (cond
              ((fx= dep-state 0)
               (u32vector-set! saved-nodes top node)
               (u32vector-set! saved-cursors top next-cursor)
               (u32vector-set! saved-ends top end)
               (enter dep)
               (walk dep (fx+ top 1) (u32vector-ref offsets dep)
                     (u32vector-ref offsets (fx+ dep 1))))
              ((fx<= dep-state count)
               (let (prior (u32vector-ref low node))
                 (when (fx< dep-state prior) (u32vector-set! low node dep-state)))
               (walk node top next-cursor end))
              (else (walk node top next-cursor end))))
          (let (node-low (u32vector-ref low node))
            (set! finished (fx+ finished 1))
            (when (fx= node-low (u32vector-ref state node))
              (let pop ()
                (set! member-top (fx- member-top 1))
                (let (member (u32vector-ref members member-top))
                  (u32vector-set! state member (fx+ (fx+ count 1) component))
                  (set! popped (fx+ popped 1))
                  (unless (fx= member node) (pop))))
              (set! component (fx+ component 1)))
            (unless (fx= top 0)
              (let* ((parent-top (fx- top 1)) (parent (u32vector-ref saved-nodes parent-top))
                     (parent-low (u32vector-ref low parent)))
                (when (fx< node-low parent-low) (u32vector-set! low parent node-low))
                (walk parent parent-top (u32vector-ref saved-cursors parent-top)
                      (u32vector-ref saved-ends parent-top)))))))))
  (unless (fx= member-top 0) (error "compact SCC live members after discovery" member-top))
  (vector state next component examined finished popped))

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
          (make-compact-graph (list->vector keys) positions offsets targets 0)))))
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
