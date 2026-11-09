;;; Frozen production strategy from cd4de64, qualification only. Never installed
;;; as a graph implementation. It intentionally retains the old repeated scans.
(def (baseline-reachable reads root)
  (def seen (make-hash-table-eq))
  (let visit ((pending (list root)))
    (if (null? pending) seen
      (let ((key (car pending)) (rest (cdr pending)))
        (if (hash-key? seen key) (visit rest)
          (begin (hash-put! seen key #t) (visit (append (hash-ref reads key) rest))))))))
(def (baseline-partition spec)
  (def keys (.@ spec keys))
  (unless (and (list? keys) (andmap symbol? keys)
               (= (length keys) (length (delete-duplicates/hash keys))))
    (error "distinct finite component keys required"))
  (def reads (make-hash-table-eq))
  (def reverse-reads (make-hash-table-eq))
  (def owners (make-hash-table-eq))
  (for-each (lambda (key) (hash-put! reverse-reads key [])) keys)
  (for (key keys)
    (def code (.call spec .code key))
    (def deps (if code (.@ code reads) []))
    (unless (and (list? deps) (andmap (lambda (dep) (memq dep keys)) deps))
      (error "unsupported component read" key deps))
    (def unique (delete-duplicates/hash deps))
    (hash-put! reads key unique)
    (for-each (lambda (dep) (hash-update! reverse-reads dep (cut cons key <>))) unique))
  (def groups (foldl (lambda (key result)
    (if (hash-key? owners key) result
      (let (members
        (if (andmap (lambda (prior) (or (eq? prior key) (hash-key? owners prior)))
                    (hash-ref reverse-reads key))
          (list key)
          (let ((forward (baseline-reachable reads key))
                (backward (baseline-reachable reverse-reads key)))
            (filter (lambda (other)
              (and (hash-key? forward other) (hash-key? backward other))) keys))))
        (for-each (lambda (member) (hash-put! owners member key)) members)
        (cons members result)))) [] keys))
  (reverse groups))

;; Exact ordered list-membership walk frozen from recursive-validation 6394e95.
;; Bounded semantic oracle only; never time its quadratic capacity behavior.
(def (list-reachable-order dependencies root)
  (let loop ((todo (list root)) (seen []))
    (if (null? todo) seen
      (if (memq (car todo) seen) (loop (cdr todo) seen)
        (loop (append (hash-ref dependencies (car todo)) (cdr todo)) (cons (car todo) seen))))))

;; Rejected as an unconditional runtime default: small requests pay excessive
;; setup/allocation. Retained ONLY as the indexed capacity-study reference.
(def (hash-reachable dependencies root)
  ;; Invocation-local membership index; keep the original reverse-discovery list.
  ;; Lean OrderedReachability preserves every finite prefix and visit order.
  ;; Source/currentness and admission checks remain at their original callers.
  (def visited (make-hash-table-eq))
  (let loop ((todo (list root)) (seen []))
    (if (null? todo) seen
      (let (key (car todo))
        (if (hash-key? visited key) (loop (cdr todo) seen)
          (begin (hash-put! visited key #t)
            (loop (append (hash-ref dependencies key) (cdr todo)) (cons key seen))))))))

;; Frozen 4a644ca collector for same-toolchain admission comparison only.
(def (separate-admission-capture keys read-owner (symbolic-rows? #t) (edge-word-ceiling 4294967295))
  ;; The private reduced ceiling exercises exactly the native wide fallback in
  ;; bounded tests. Production always uses the full u32 range; it cannot expand.
  (unless (and (exact-integer? edge-word-ceiling) (<= 0 edge-word-ceiling 4294967295))
    (error "captured edge word ceiling" edge-word-ceiling))
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
  (def row-buffer #f) (def owner-names #f)
  (def offsets (and packed? (make-u32vector (1+ count) 0)))
  (def reads (and (or symbolic-rows? (not packed?)) (make-hash-table-eq size: count)))
  (def declared 0) (def edges 0)
  (def direction 3)
  ;; Private, bounded construction chunks, not a retained graph/value cache.
  ;; A small graph pays only its support-sized chunk; an empty graph pays none.
  (def capacity (max 1 (min count 65536)))
  (def chunks []) (def chunk #f) (def used 0)
  ;; A query consumes the packed product only. On a real word-domain fallback,
  ;; recover completed rows BEFORE dropping those chunks. The current row can
  ;; have a partial suffix there; offsets stop before it (restore_completed_prefix).
  (def (restore-symbolic-prefix! completed)
    (unless reads
      (set! reads (make-hash-table-eq size: count))
      (unless owner-names (set! owner-names (list->vector keys)))
      (let ((pending (reverse (if chunk (cons chunk chunks) chunks))) (cursor 0))
        (def (next-id)
          (when (fx= cursor capacity) (set! pending (cdr pending)) (set! cursor 0))
          (unless (pair? pending) (error "incomplete captured row prefix"))
          (let (id (u32vector-ref (car pending) cursor))
            (set! cursor (fx+ cursor 1)) id))
        (for (owner (in-range completed))
          (hash-put! reads (vector-ref owner-names owner)
            (for/collect (_at (in-range (u32vector-ref offsets owner)
                               (u32vector-ref offsets (fx+ owner 1))))
              (vector-ref owner-names (next-id))))))))
  (def (use-wide-rows! completed)
    (restore-symbolic-prefix! completed)
    (set! packed? #f) (set! offsets #f)
    (set! chunks []) (set! chunk #f))
  (def (append-target owner id)
    (when packed?
      ;; Outside the word domain retain the original wide algorithm, rather
      ;; than imposing a new public graph-size refusal.
      (if (or (not (fixnum? (1+ edges))) (>= edges edge-word-ceiling))
        (use-wide-rows! owner)
        (begin
          (when (= used capacity)
            (set! chunks (cons chunk chunks)) (set! chunk #f) (set! used 0))
          (unless chunk (set! chunk (make-u32vector capacity 0)))
          (u32vector-set! chunk used id) (set! used (fx+ used 1))))))
  ;; Copy retained row IDs in bounded standard-vector slices. No per-edge
  ;; closure call or counter update; each chunk preserves exact row order.
  (def (append-row-targets owner start end)
    (let (after (+ edges (- end start)))
      (when packed?
        (if (or (not (fixnum? after)) (> after edge-word-ceiling))
          (use-wide-rows! owner)
          (let copy ((at start))
            (when (fx< at end)
              (when (fx= used capacity)
                (set! chunks (cons chunk chunks)) (set! chunk #f) (set! used 0))
              (unless chunk (set! chunk (make-u32vector capacity 0)))
              (let* ((take (fxmin (fx- end at) (fx- capacity used))) (stop (fx+ at take)))
                (u32vector-copy! chunk used row-buffer at stop)
                (set! used (fx+ used take))
                (copy stop))))))
      (set! edges after)))
  (for ((key keys) (owner (in-range count)))
    (when packed? (u32vector-set! offsets owner edges))
    (def deps (read-owner key))
    (unless (and (list? deps) (andmap symbol? deps))
      (error "unsupported component read" key deps))
    (def row-length (length deps))
    (if (and word-support? (pair? deps) (pair? (cdr deps))
             (fixnum? row-length) (<= row-length 4294967295))
      (begin
        (unless row-marks (set! row-marks (make-u32vector count 0)))
        ;; Reuse one numeric row workspace across author callbacks. The unread
        ;; prefix and retained suffix are disjoint (row_buffer_store law).
        ;; Only public symbolic adjacency allocates an output list per edge.
        (unless owner-names (set! owner-names (list->vector keys)))
        (when (or (not row-buffer) (fx< (u32vector-length row-buffer) row-length))
          (set! row-buffer (make-u32vector
            (let (grown (if row-buffer (* 2 (u32vector-length row-buffer)) 0))
              (if (fixnum? grown) (max row-length grown) row-length)) 0)))
        (let fill ((pending deps) (at 0))
          (unless (null? pending)
            (let (id (symbolic-table-ref raw (car pending) #f))
              (unless id (error "unsupported component read" key deps))
              (cond ((fx< id owner) (set! direction (fxand direction 1)))
                    ((fx> id owner) (set! direction (fxand direction 2))))
              (u32vector-set! row-buffer at id))
            (fill (cdr pending) (fx+ at 1))))
        (let ((token (fx+ owner 1)))
          (let-values (((start unique)
                        (let scan ((read row-length) (write row-length) (unique (and reads [])))
                          (if (fx= read 0) (values write unique)
                            (let* ((next (fx- read 1)) (id (u32vector-ref row-buffer next)))
                              (if (fx= (u32vector-ref row-marks id) token)
                                (scan next write unique)
                                (let (destination (fx- write 1))
                                  (u32vector-set! row-marks id token)
                                  (u32vector-set! row-buffer destination id)
                                  (scan next destination (and reads (cons (vector-ref owner-names id) unique))))))))))
            (append-row-targets owner start row-length)
            (when reads
              (hash-put! reads key (or unique
                (for/collect (at (in-range start row-length))
                  (vector-ref owner-names (u32vector-ref row-buffer at)))))))))
      ;; Preserve the inexpensive empty/singleton path and the original wide
      ;; domain. Copy singleton spines before the next independent callback.
      (let (unique (cond ((null? deps) []) ((null? (cdr deps)) deps)
                        (else (delete-duplicates/hash deps))))
        (for (dep unique)
          (let (id (symbolic-table-ref raw dep #f))
            (unless id (error "unsupported component read" key deps))
            (cond ((fx< id owner) (set! direction (fxand direction 1)))
                  ((fx> id owner) (set! direction (fxand direction 2))))
            (append-target owner id))
          (set! edges (1+ edges)))
        (when reads
          ;; Copy the singleton before the next author, including when this row
          ;; caused fallback. Packed queries need no unconsumed symbolic copy.
          (hash-put! reads key (if (and (pair? unique) (null? (cdr unique)))
                                (list (car unique)) unique)))))
    (set! declared (+ declared row-length)))
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
          (make-compact-graph (or owner-names (list->vector keys)) positions offsets targets direction)))))
  (values reads index declared edges))
