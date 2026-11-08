;;; Strongly connected components (SCC): maximal mutually reachable node groups.
;;; Iterative Tarjan partitions captured finite POO computation footprints.
;;; Explicit feedback construction and recursive topology consume these groups;
;;; this does not load namespaces or make ordinary cyclic slot access valid.
(export partition partition? partition-groups partition-owner partition-reads
        partition-members partition-group-of partition-group-size partition-work capture-reachability)
(import :std/iter
        (only-in :gerbil/runtime/interface interface-instance-object)
        (only-in :gerbil/runtime/hash symbol-hash-table?)
        (only-in :gerbil/runtime/table symbolic-table-ref symbolic-table-set!) (only-in :std/list/list delete-duplicates/hash foldl)
        ./object)
;; Public groups/representatives retain source order, independently of DFS order.
(defstruct %partition (groups owner reads members work owners) final: #t)
(def partition? %partition?)
(def partition-groups %partition-groups)
(def partition-owner %partition-owner)
(def partition-reads %partition-reads)
(def partition-work %partition-work)
;; The existing representative index stores (cardinality . members). The owner
;; index is the same table already captured by partition-owner, not a second cache.
(def (partition-members part representative)
  (let (entry (hash-get (%partition-members part) representative)) (and entry (cdr entry))))
(def (group-entry part node)
  (let (representative (hash-get (%partition-owners part) node))
    (and representative (hash-ref (%partition-members part) representative))))
(def (partition-group-of part node)
  (let (entry (group-entry part node)) (and entry (cdr entry))))
(def (partition-group-size part node)
  (let (entry (group-entry part node)) (and entry (car entry))))
(def (work-receipt owner-count input-edges discoveries-count edges-count finish-count
                   pop-count normalized-count group-count span-buckets span-edges quotient-count
                   singleton-count reverse-count)
  (.o validation-owners: owner-count validation-edges: input-edges
      discoveries: discoveries-count edge-visits: edges-count finishes: finish-count
      member-pops: pop-count normalization-owners: normalized-count groups: group-count
      certificate-buckets: span-buckets certificate-edges: span-edges
      quotient-edges: quotient-count certificate-singletons: singleton-count
      reverse-edges: reverse-count))

;; DFS state is private to this call and dies before normalization/certification.
;; Reuse the existing owner index; lowlinks/active flags are contiguous cells.
;; A frame is #(owner discovery-slot remaining-edges). Only its tail changes;
;; the SCC stack observes the unchanged owner/slot (DiscoveryFrame law).
(def (discover-wide keys reads)
  (def indices (make-hash-table-eq))
  (def low (make-vector (length keys) 0))
  (def active (make-vector (length keys) #f))
  (def owners (make-hash-table-eq))
  (def stack []) (def next 0) (def component 0)
  (def examined 0) (def finished 0) (def popped 0)
  (def (enter key)
    (def slot next)
    (def frame (vector key slot (hash-ref reads key)))
    (hash-put! indices key slot)
    (vector-set! low slot slot)
    (vector-set! active slot #t)
    (set! next (1+ next))
    (set! stack (cons frame stack))
    frame)
  (for (root keys)
    (unless (hash-key? indices root)
      (let walk ((frames (list (enter root))))
        (unless (null? frames)
          (let* ((frame (car frames)) (key (vector-ref frame 0))
                 (slot (vector-ref frame 1)) (pending (vector-ref frame 2))
                 (parents (cdr frames)))
            (if (pair? pending)
              (let* ((dep (car pending)) (dep-slot (hash-get indices dep)))
                (vector-set! frame 2 (cdr pending))
                (set! examined (1+ examined))
                ;; Scheme zero is truthy: discovery slot zero is present.
                (cond
                  ((not dep-slot) (walk (cons (enter dep) frames)))
                  ((vector-ref active dep-slot)
                   (vector-set! low slot (min (vector-ref low slot) dep-slot))
                   (walk frames))
                  (else (walk frames))))
              (begin
                (set! finished (1+ finished))
                (when (= (vector-ref low slot) slot)
                  (let pop ()
                    (let* ((member (car stack)) (name (vector-ref member 0)))
                      (set! stack (cdr stack))
                      (vector-set! active (vector-ref member 1) #f)
                      (hash-put! owners name component)
                      (set! popped (1+ popped))
                      (unless (eq? name key) (pop))))
                  (set! component (1+ component)))
                (when (pair? parents)
                  (let (parent-slot (vector-ref (car parents) 1))
                    (vector-set! low parent-slot
                      (min (vector-ref low parent-slot) (vector-ref low slot)))))
                (walk parents))))))))
  (values owners next component examined finished popped))

(defstruct compact-graph (names positions offsets targets) final: #t)

(def (capture-compact keys reads edges)
  (def count (length keys))
  (unless (and (fixnum? count) (fixnum? (1+ count)) (fixnum? edges) (<= 0 count 4294967295)
               (<= 0 edges 4294967295))
    (error "compact Graph word range" count edges))
  (def names (list->vector keys))
  (def positions (make-hash-table-symbolic size: count))
  ;; This concrete table is created here, without locks, weak keys or hooks.
  ;; Unwrap once; the standard specialized accessor needs no per-edge interface
  ;; dispatch. Public Graph queries still accept original symbolic owners.
  (def raw-positions (interface-instance-object positions))
  (unless (symbol-hash-table? raw-positions) (error "compact symbolic index representation"))
  (let assign ((rest keys) (index 0))
    (unless (null? rest)
      (unless (symbol? (car rest)) (error "symbolic compact owner required" (car rest)))
      (symbolic-table-set! raw-positions (car rest) index)
      (assign (cdr rest) (fx+ index 1))))
  (unless (= count (hash-length positions)) (error "distinct compact Graph owners required"))
  (def offsets (make-u32vector (fx+ count 1) 0))
  (def targets (make-u32vector edges 0))
  (let owner ((rest keys) (index 0) (cursor 0))
    (u32vector-set! offsets index cursor)
    (if (null? rest)
      (unless (= cursor edges) (error "compact Graph edge count changed" cursor edges))
      (let fill ((pending (hash-ref reads (car rest))) (cursor cursor))
        (if (null? pending) (owner (cdr rest) (fx+ index 1) cursor)
          (begin
            (let* ((dep (car pending))
                   (id (and (symbol? dep) (symbolic-table-ref raw-positions dep #f))))
              ;; Zero is a present ID. Misses retain the ordinary key refusal;
              ;; malformed non-symbols never enter the specialized primitive.
              (unless id
                (if (symbol? dep) (hash-ref positions dep)
                  (error "symbolic compact target required" dep)))
              (u32vector-set! targets cursor id))
            (fill (cdr pending) (fx+ cursor 1)))))))
  (make-compact-graph names positions offsets targets))

;; One owner index serves BOTH source support admission and row ID encoding.
;; Every author is still read independently, in source order. Only the pure
;; support check/encoding interval is shared (normalized_capture_trace law).
(def (capture-graph keys read-owner)
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
  ;; Copy retained row IDs in bounded standard-vector slices. No per-edge
  ;; closure call or counter update; each chunk preserves exact row order.
  (def (append-row-targets start end)
    (let (after (+ edges (- end start)))
      (when packed?
        (if (or (not (fixnum? after)) (> after 4294967295))
          (begin (set! packed? #f) (set! offsets #f)
                 (set! chunks []) (set! chunk #f))
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
              (u32vector-set! row-buffer at id))
            (fill (cdr pending) (fx+ at 1))))
        (let ((token (fx+ owner 1)))
          (let-values (((start unique)
                        (let scan ((read row-length) (write row-length) (unique []))
                          (if (fx= read 0) (values write unique)
                            (let* ((next (fx- read 1)) (id (u32vector-ref row-buffer next)))
                              (if (fx= (u32vector-ref row-marks id) token)
                                (scan next write unique)
                                (let (destination (fx- write 1))
                                  (u32vector-set! row-marks id token)
                                  (u32vector-set! row-buffer destination id)
                                  (scan next destination (cons (vector-ref owner-names id) unique)))))))))
            (append-row-targets start row-length)
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
          (make-compact-graph (or owner-names (list->vector keys)) positions offsets targets)))))
  (values reads index declared edges))

;; Ordered reachability over an already captured graph, never an approval memo.
;; Small walks retain bounded list membership. Large sparse walks use a private
;; ID set; dense marks appear only after N <= 32 * entered (Lean workspace law).
(def (compact-reachable graph root (work #f))
  (def names (compact-graph-names graph))
  (def positions (compact-graph-positions graph))
  (def offsets (compact-graph-offsets graph))
  (def targets (compact-graph-targets graph))
  (def root-id (hash-ref positions root))
  (def count (vector-length names))
  (def first (u32vector-ref offsets root-id))
  (def last (u32vector-ref offsets (fx+ root-id 1)))
  (def (indexed frames cursor end ids seen)
    (def entered (length ids))
    (def marks #f) (def sparse #f)
    (def capacity (max 64 (fx+ (length frames) 1)))
    (def saved-cursors (make-u32vector capacity 0))
    (def saved-ends (make-u32vector capacity 0))
    (when work (vector-set! work 1 (+ (vector-ref work 1) (* 2 capacity))))
    (for ((frame (reverse frames)) (at (in-range (length frames))))
      (u32vector-set! saved-cursors at (car frame))
      (u32vector-set! saved-ends at (cdr frame)))
    (if (<= count (* 32 entered))
      (begin (set! marks (make-u8vector count 0))
             (when work (vector-set! work 0 count))
             (for (id ids) (u8vector-set! marks id 1)))
      (begin (set! sparse (make-hash-table-eq))
             (for (id ids) (hash-put! sparse id #t))))
    (let walk ((top (length frames)) (cursor cursor) (end end) (seen seen))
      (if (fx< cursor end)
        (let* ((dep (u32vector-ref targets cursor)) (next (fx+ cursor 1))
               (known? (if marks (fx= (u8vector-ref marks dep) 1) (hash-key? sparse dep))))
          (if known? (walk top next end seen)
            (begin
              (set! entered (fx+ entered 1))
              (if marks (u8vector-set! marks dep 1)
                (begin
                  (hash-put! sparse dep #t)
                  (when (<= count (* 32 entered))
                    (set! marks (make-u8vector count 0))
                    (when work (vector-set! work 0 count))
                    (for (id (hash-keys sparse)) (u8vector-set! marks id 1))
                    (set! sparse #f))))
              (when (fx= top capacity)
                (let* ((grown (min count (* 2 capacity)))
                       (cursors (make-u32vector grown 0)) (ends (make-u32vector grown 0)))
                  (when work
                    (vector-set! work 1 (+ (vector-ref work 1) (* 2 grown)))
                    (vector-set! work 2 (+ (vector-ref work 2) (* 2 top))))
                  (u32vector-copy! cursors 0 saved-cursors 0 top)
                  (u32vector-copy! ends 0 saved-ends 0 top)
                  (set! saved-cursors cursors) (set! saved-ends ends)
                  (set! capacity grown)))
              (u32vector-set! saved-cursors top next)
              (u32vector-set! saved-ends top end)
              (walk (fx+ top 1) (u32vector-ref offsets dep)
                    (u32vector-ref offsets (fx+ dep 1)) (cons (vector-ref names dep) seen)))))
        (if (fx= top 0) seen
          (let (parent (fx- top 1))
            (walk parent (u32vector-ref saved-cursors parent)
                  (u32vector-ref saved-ends parent) seen))))))
  ;; No N-sized allocation on a small closure, including nonempty source rows.
  (let walk ((frames []) (cursor first) (end last) (ids (list root-id)) (seen (list root)) (entered 1))
    (if (fx< cursor end)
      (let* ((dep (u32vector-ref targets cursor)) (next (fx+ cursor 1)))
        (cond ((memq dep ids) (walk frames next end ids seen entered))
              ((fx< entered 64)
               (walk (cons (cons next end) frames) (u32vector-ref offsets dep)
                     (u32vector-ref offsets (fx+ dep 1)) (cons dep ids)
                     (cons (vector-ref names dep) seen) (fx+ entered 1)))
              (else (indexed frames cursor end ids seen))))
      (if (null? frames) seen
        (let (parent (car frames))
          (walk (cdr frames) (car parent) (cdr parent) ids seen entered))))))

;; The wide-domain fallback keeps bounded list setup and borrows row tails.
(def (wide-reachable reads root)
  (def seen-index #f)
  (let walk ((pending (list (list root))) (seen []) (entered 0))
    (cond ((null? pending) seen)
          ((null? (car pending)) (walk (cdr pending) seen entered))
          (else
           (let* ((key (caar pending)) (rest (cons (cdar pending) (cdr pending)))
                  (known? (if seen-index (hash-key? seen-index key) (memq key seen))))
             (if known? (walk rest seen entered)
               (let (row (hash-ref reads key))
                 (unless seen-index
                   (when (>= entered 64)
                     (set! seen-index (make-hash-table-eq))
                     (for (prior seen) (hash-put! seen-index prior #t))))
                 (when seen-index (hash-put! seen-index key #t))
                 (walk (cons row rest) (cons key seen) (1+ entered)))))))))

;; Separate closure environments retire normalized row copies on the packed
;; path. Only the selected structural layout enters the POO value's kernel.
(def (compact-query index) (lambda (root) (compact-reachable index root)))
(def (wide-query reads) (lambda (root) (wide-reachable reads root)))
(def (reachability-value origin owners declared edges query)
  (.o source: origin owner-count: owners edge-count: edges declared-edges: declared
    .reachable: query))

;; Historical structural index: captured rows/IDs are owned by this POO value.
;; Queries cannot acquire authors again, publish, or authorize currentness.
(def (capture-reachability origin)
  (def keys (.@ origin keys))
  (unless (and (list? keys) (andmap symbol? keys)
               (= (length keys) (length (delete-duplicates/hash keys))))
    (error "distinct finite reachability keys required"))
  (let-values (((reads index declared edges)
                (capture-graph keys (lambda (key) (.call origin .reads key)))))
    (reachability-value origin (length keys) declared edges
      (if index (compact-query index) (wide-query reads)))))

;; Numeric Tarjan over the exact CSR rows. This is the existing algorithm:
;; discovery order, lowlinks and pop order are unchanged. No hash per edge.
;; state 0 = fresh; 1..N = active discovery+1; N+1+component = retired.
(def (compact-discover graph)
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

(def (compact-component-owners graph result)
  (def names (compact-graph-names graph))
  (def count (vector-length names))
  (def state (vector-ref result 0))
  (def owners (make-hash-table-symbolic size: count))
  (def raw-owners (interface-instance-object owners))
  (unless (symbol-hash-table? raw-owners) (error "compact owner index representation"))
  (for (node (in-range count))
    (let (retired (u32vector-ref state node))
      (unless (fx> retired count) (error "compact SCC unretired owner" node retired))
      (symbolic-table-set! raw-owners (vector-ref names node) (fx- (fx- retired count) 1))))
  owners)

(def (compact-discovery-result graph)
  (let (result (compact-discover graph))
    (vector-set! result 0 (compact-component-owners graph result)) result))

;; Private layout refinement of the existing discovery operation. No public
;; representation or Module identity changes, no shared traversal workspace.
;; Word-domain dispatch preserves the original wide representation outside u32.
(def (discover keys reads (captured-edges #f) (captured-index #f))
  (def count (length keys))
  (def edges (or captured-edges (foldl (lambda (key n) (+ n (length (hash-ref reads key)))) 0 keys)))
  (if (and (fixnum? (* 2 count)) (<= (* 2 count) 4294967295)
           (fixnum? edges) (<= edges 4294967295))
    (let (result (compact-discovery-result (or captured-index (capture-compact keys reads edges))))
      (values (vector-ref result 0) (vector-ref result 1) (vector-ref result 2)
              (vector-ref result 3) (vector-ref result 4) (vector-ref result 5)))
    (discover-wide keys reads)))

;; The component-ID map is transient: normalization returns only final indices.
(def (normalize keys owners)
  (def representatives (make-hash-table-eq))
  (def members (make-hash-table-eq)) (def ranks (make-hash-table-eq)) (def order [])
  (for (key keys)
    (let* ((id (hash-ref owners key)) (prior (hash-get representatives id))
           (representative (or prior key)))
      (unless prior
        (hash-put! representatives id key)
        (hash-put! ranks key id)
        (hash-put! members key [])
        (set! order (cons key order)))
      (hash-put! members representative (cons key (hash-ref members representative)))
      (hash-put! owners key representative)))
  (let (groups (for/collect (representative (reverse order))
                (let (group (reverse (hash-ref members representative)))
                  (hash-put! members representative (cons (length group) group)) group)))
    (values groups members ranks)))

(def (partition spec)
  (def keys (.@ spec keys))
  (unless (and (list? keys) (andmap symbol? keys)
               (= (length keys) (length (delete-duplicates/hash keys))))
    (error "distinct finite component keys required"))
  (let-values (((reads index declared-edges captured-edges)
                 (capture-graph keys (lambda (key)
                   (let (code (.call spec .code key)) (if code (.@ code reads) []))))))
    (partition-captured keys reads captured-edges (length keys) declared-edges index)))

;; Pure phase over locally captured immutable rows. Production reaches this only
;; after validating every author. White-box studies may borrow an already
;; certified historical partition, charging zero NEW declaration validation.
(def (partition-captured keys reads captured-edges validation-owners declared-edges (index #f))
  (let-values (((owners next component examined-edges finished popped) (discover keys reads captured-edges index)))
    ;; A tail handoff carries NO packed input or capture construction buffers.
    ;; Keep those roots out of normalization/certificate closure environments.
    (finish-partition keys reads validation-owners declared-edges owners next component examined-edges finished popped)))

(def (finish-partition keys reads validation-owners declared-edges owners next component examined-edges finished popped)
    (let-values (((groups members ranks) (normalize keys owners)))
      ;; Independent ComponentWitness certificate: all quotient edges, and two
      ;; within-group spanning walks. Singleton paths are reflexive. Reverse
      ;; rows retain only internal edges of nontrivial groups (Lean pruning law).
      (let ((reverse-reads (make-hash-table-eq))
            (forward-seen (make-hash-table-eq)) (backward-seen (make-hash-table-eq))
            (certificate-buckets 0) (certificate-edges 0) (quotient-edges 0)
            (certificate-singletons 0) (reverse-edges 0) (quotient-error #f))
        (def (span adjacency seen root)
          (let walk ((pending (list root)))
            (unless (null? pending)
              (let ((key (car pending)) (rest (cdr pending)))
                (if (hash-key? seen key) (walk rest)
                  (let (row (hash-ref adjacency key []))
                    (hash-put! seen key #t)
                    (set! certificate-buckets (1+ certificate-buckets))
                    (set! certificate-edges (+ certificate-edges (length row)))
                    (walk (append (filter (lambda (dep) (eq? (hash-ref owners dep) root)) row) rest))))))))
        ;; Finish EVERY rank read before reusing this private table as group
        ;; coverage. Save the first bad edge; refusal below retains the original
        ;; per-owner order: spanning check, then that owner's quotient check.
        (for (key keys)
          (let* ((consumer (hash-ref owners key))
                 (nontrivial (> (car (hash-ref members consumer)) 1)))
            (for (dep (hash-ref reads key))
              (set! quotient-edges (1+ quotient-edges))
              (let (provider (hash-ref owners dep))
                (if (eq? consumer provider)
                  (when nontrivial
                    (hash-put! reverse-reads dep (cons key (hash-ref reverse-reads dep [])))
                    (set! reverse-edges (1+ reverse-edges)))
                  (unless (or quotient-error (< (hash-ref ranks provider) (hash-ref ranks consumer)))
                    (set! quotient-error (cons key dep))))))))
        (for (group groups)
          (let (root (car group))
            (hash-put! ranks root 'covered)
            (if (null? (cdr group))
              (set! certificate-singletons (1+ certificate-singletons))
              (begin (span reads forward-seen root)
                     (span reverse-reads backward-seen root)))))
        (for (key keys)
          (let* ((owner (hash-ref owners key)) (entry (hash-ref members owner)))
            (unless (and (eq? (hash-get ranks owner) 'covered)
                         (if (= (car entry) 1) (eq? key owner)
                           (and (hash-key? forward-seen key) (hash-key? backward-seen key))))
              (error "invalid SCC spanning certificate" key)))
          (when (and quotient-error (eq? key (car quotient-error)))
            (error "invalid SCC quotient certificate" key (cdr quotient-error))))
        (make-%partition groups (cut hash-ref owners <>) (cut hash-ref reads <>) members
          (work-receipt validation-owners declared-edges next examined-edges finished popped next component
            certificate-buckets certificate-edges quotient-edges certificate-singletons reverse-edges) owners))))
