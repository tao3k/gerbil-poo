;;; Strongly connected components (SCC): maximal mutually reachable node groups.
;;; Iterative Tarjan partitions captured finite POO computation footprints.
;;; Explicit feedback construction and recursive topology consume these groups;
;;; this does not load namespaces or make ordinary cyclic slot access valid.
(export partition partition? partition-groups partition-owner partition-reads
        partition-members partition-group-of partition-group-size partition-work
        partition-owned revise-partition %partition-order-keys %partition-representatives %partition-key-before
        quotient-support-added quotient-support-retired %partition-source-count %partition-key-position
        capture-reachability capture-reachability-procedure)
(import :std/iter
        (only-in :gerbil/runtime/interface interface-instance-object)
        (only-in :gerbil/runtime/hash symbol-hash-table?)
        (only-in :gerbil/runtime/table symbolic-table-ref symbolic-table-set!) (only-in :std/list/list delete-duplicates/hash foldl)
        (only-in :std/list/list-builder with-list-builder)
        (only-in ./generalized-graph %index %index-project %index-ref %index-fork %index-write!
                 %reverse-bucket-remove %reverse-bucket-add %for-each-reverse-bucket)
        ./object)
;; Public groups/representatives retain source order, independently of DFS order.
(defstruct %partition (groups owner reads members work owners owned) final: #t)
(defstruct owned-partition (keys positions forward backward owner members shape) final: #t)
(defstruct quotient-support (added retired) final: #t)
(def partition? %partition?)
(def (partition-groups part)
  (let (owned (%partition-owned part))
    (if owned
      (with-list-builder (add)
        (if (eq? (owned-partition-shape owned) 'singletons)
          (for (key (owned-partition-keys owned)) (add (list key)))
          (for (key (owned-partition-keys owned))
            (when (eq? key ((partition-owner part) key))
              (add (partition-members part key))))))
      (%partition-groups part))))
(def partition-owner %partition-owner)
(def partition-reads %partition-reads)
(def partition-work %partition-work)
;; The existing representative index stores (cardinality . members). The owner
;; index is the same table already captured by partition-owner, not a second cache.
(def (member-entry part representative)
  (let (owned (%partition-owned part))
    (if owned (and (symbol? representative) (%index-ref (owned-partition-members owned) representative #f))
      (hash-get (%partition-members part) representative))))
(def (public-members part entry)
  (and entry (if (%partition-owned part) (list-copy (cdr entry)) (cdr entry))))
(def (partition-members part representative)
  (public-members part (member-entry part representative)))
(def (group-entry part node)
  (def owned (%partition-owned part))
  (def representative
    (if owned (and (symbol? node) (%index-ref (owned-partition-owner owned) node #f))
      (hash-get (%partition-owners part) node)))
  (and representative (member-entry part representative)))
(def (partition-group-of part node)
  (public-members part (group-entry part node)))
(def (partition-group-size part node)
  (let (entry (group-entry part node)) (and entry (car entry))))
(def (work-receipt owner-count input-edges discoveries-count edges-count finish-count
                   pop-count normalized-count group-count span-buckets span-edges quotient-count
                   singleton-count reverse-count ranked-count rank-edge-count)
  (.o validation-owners: owner-count validation-edges: input-edges
      discoveries: discoveries-count edge-visits: edges-count finishes: finish-count
      member-pops: pop-count normalization-owners: normalized-count groups: group-count
      bulk-retired: (if (zero? finish-count) 0 (- discoveries-count pop-count))
      certificate-buckets: span-buckets certificate-edges: span-edges
      quotient-edges: quotient-count certificate-singletons: singleton-count
      reverse-edges: reverse-count rank-owners: ranked-count rank-edges: rank-edge-count))

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

(defstruct compact-graph (names positions offsets targets direction) final: #t)

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
  ;; A bit survives iff EVERY captured non-self edge obeys its direction.
  ;; This is structural evidence owned by these rows, never currentness evidence.
  (def direction 3)
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
              (cond ((fx< id index) (set! direction (fxand direction 1)))
                    ((fx> id index) (set! direction (fxand direction 2))))
              (u32vector-set! targets cursor id))
            (fill (cdr pending) (fx+ cursor 1)))))))
  (make-compact-graph names positions offsets targets direction))

;; One owner index serves BOTH source support admission and row ID encoding.
;; Every author is still read independently, in source order. Only the pure
;; support check/encoding interval is shared (normalized_capture_trace law).
(def (append-ordered-targets! raw deps chunk start names)
  ;; The reserved suffix holds at most 32 words. Until the scan reaches (),
  ;; its writes are outside the captured graph and can be overwritten.
  (def first (car deps))
  (def second (cadr deps))
  (def a (and (symbol? first) (symbolic-table-ref raw first #f)))
  (def b (and (symbol? second) (symbolic-table-ref raw second #f)))
  (and a b (not (fx= a b))
       (let* ((up? (fx< a b)) (step (if up? 1 -1)) (stop (fx+ start 32))
              (limit (if names (vector-length names) 0)))
         (u32vector-set! chunk start a)
         (u32vector-set! chunk (fx+ start 1) b)
         (let write ((rest (cddr deps)) (at (fx+ start 2)) (last b))
           (cond ((null? rest) at)
                 ((and (fx< at stop) (pair? rest))
                  (let* ((key (car rest)) (hint (fx+ last step))
                         (id (if (and (fx>= hint 0) (fx< hint limit)
                                      (eq? (vector-ref names hint) key))
                               hint
                               (and (symbol? key) (symbolic-table-ref raw key #f)))))
                    (and id (if up? (fx< last id) (fx> last id))
                         (begin
                           (u32vector-set! chunk at id)
                           (write (cdr rest) (fx+ at 1) id)))))
                 (else #f))))))

(def (capture-graph keys read-owner (symbolic-rows? #t) (edge-word-ceiling 4294967295)
                    (ordered-rows? 'adjacent) (stable-rows? #f))
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
  ;; It never stores source/currentness approvals. Two fresh stamps per owner
  ;; distinguish forward uniqueness from reverse rightmost normalization.
  (def row-marks #f)
  ;; Shape is a routing hint, not evidence for the next row. A repeat sends
  ;; the next two unique multi-target rows through the ordinary reverse scan.
  (def fresh-streak 2)
  (def ordered-trial? (and ordered-rows? (not symbolic-rows?)))
  (def row-buffer #f) (def owner-names #f)
  (def offsets (and packed? (make-u32vector (1+ count) 0)))
  (def reads (and (or symbolic-rows? (not packed?))
                   (if stable-rows? (make-hash-table-symbolic size: count)
                     (make-hash-table-eq size: count))))
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
    (def end
      (and ordered-trial? packed? chunk
           (fx<= (fx+ used 32) capacity)
           (let (after (+ edges 32)) (and (fixnum? after) (<= after edge-word-ceiling)))
           (pair? deps) (pair? (cdr deps))
           (let* ((names (and (eq? ordered-rows? 'adjacent)
                              (begin
                                (unless owner-names (set! owner-names (list->vector keys)))
                                owner-names)))
                  (end (append-ordered-targets! raw deps chunk used names)))
             ;; Use only this row's scan as evidence. A failed trial routes
             ;; later rows through the existing general normalization.
             (unless end (set! ordered-trial? #f))
             end)))
    (if end
      (let ((first (u32vector-ref chunk used)) (last (u32vector-ref chunk (fx- end 1)))
            (size (fx- end used)))
        (when (fx< (fxmin first last) owner) (set! direction (fxand direction 1)))
        (when (fx> (fxmax first last) owner) (set! direction (fxand direction 2)))
        (set! edges (fx+ edges size))
        (set! declared (+ declared size))
        (set! used end))
      (let ()
        ;; Keep the finite/proper-list guard before any length or hash primitive.
        ;; Symbol admission shares the subsequent ID pass; this pure interval
        ;; contains no author, getter or source-approval callback (fused_row_eq).
        (unless (list? deps)
          (error "unsupported component read" key deps))
        (def row-length (length deps))
        (if (and word-support? (pair? deps) (pair? (cdr deps))
                 (fixnum? row-length) (<= row-length 4294967295))
          (let ()
            (unless row-marks (set! row-marks (make-u32vector count 0)))
            ;; Reuse one numeric row workspace across author callbacks. The unread
            ;; prefix and retained suffix are disjoint (row_buffer_store law).
            ;; Only public symbolic adjacency allocates an output list per edge.
            (unless owner-names (set! owner-names (list->vector keys)))
            (when (or (not row-buffer) (fx< (u32vector-length row-buffer) row-length))
              (set! row-buffer (make-u32vector
                (let (grown (if row-buffer (* 2 (u32vector-length row-buffer)) 0))
                  (if (fixnum? grown) (max row-length grown) row-length)) 0)))
            (def forward (fx+ (fx* owner 2) 1))
            (def repeated?
              (let fill ((pending deps) (at 0) (repeated? (or (and reads #t) (fx< fresh-streak 2))))
                (if (null? pending) repeated?
                  (let* ((dep (car pending)) (id (and (symbol? dep) (symbolic-table-ref raw dep #f))))
                    (unless id (error "unsupported component read" key deps))
                    (cond ((fx< id owner) (set! direction (fxand direction 1)))
                          ((fx> id owner) (set! direction (fxand direction 2))))
                    (let (repeated? (or repeated? (fx= (u32vector-ref row-marks id) forward)))
                      (unless repeated? (u32vector-set! row-marks id forward))
                      (u32vector-set! row-buffer at id)
                      (fill (cdr pending) (fx+ at 1) repeated?))))))
            (if (not repeated?)
              ;; The same ID pass established uniqueness, so the rightmost
              ;; normalizer is identity (fresh_row_skips_normalization).
              (begin
                (append-row-targets owner 0 row-length)
                (when reads (hash-put! reads key (append deps []))))
              ;; A distinct fresh stamp lets the existing reverse scan keep the
              ;; rightmost occurrence, regardless of how late the first repeat was.
              (let ((token (fx+ forward 1)))
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
                  (unless reads
                    (set! fresh-streak (if (fx= start 0) (fxmin 2 (fx+ fresh-streak 1)) 0)))
                  (append-row-targets owner start row-length)
                  (when reads
                    (hash-put! reads key (or unique
                      (for/collect (at (in-range start row-length))
                        (vector-ref owner-names (u32vector-ref row-buffer at))))))))))
          ;; Preserve the inexpensive empty/singleton path and the original wide
          ;; domain. Copy singleton spines before the next independent callback.
          (begin
            (unless (andmap symbol? deps) (error "unsupported component read" key deps))
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
                                      (list (car unique)) unique))))))
        (set! declared (+ declared row-length)))))
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

;; Ordered reachability over an already captured graph, never an approval memo.
;; Small walks retain bounded list membership. Large sparse walks use a private
;; ID set; dense marks appear only after N <= 32 * entered (Lean workspace law).
(def (compact-reachable graph root (work #f) (saturate? #t))
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
              ;; All admitted IDs have now entered in the original preorder.
              ;; None of the remaining row suffixes can change the result.
              (if (and saturate? (fx= entered count))
                (cons (vector-ref names dep) seen)
                (let ()
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
                        (u32vector-ref offsets (fx+ dep 1)) (cons (vector-ref names dep) seen)))))))
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
(def (capture-reachability-components keys read-owner)
  ;; The encoding index admits symbols and uniqueness before any author.
  ;; Keep finite-list admission here, then own the roster; do not build a
  ;; second duplicate table (empty_owner_index_admits_exactly_nodup).
  (unless (list? keys) (error "distinct finite reachability keys required"))
  ;; Own the admitted roster before the first independent author callback.
  (set! keys (append keys []))
  (let-values (((reads index declared edges) (capture-graph keys read-owner #f)))
    (values (if index (compact-query index) (wide-query reads)) (length keys) declared edges)))
;; Functional bridge for owner-private captured data. Internal authority never
;; passes through an extensible Slot or an externally observable synthetic object.
(def (capture-reachability-procedure keys read-owner)
  (let-values (((query _owners _declared _edges)
                (capture-reachability-components keys read-owner))) query))
(def (capture-reachability origin)
  (let-values (((query owners declared edges)
                (capture-reachability-components (.@ origin keys)
                  (lambda (key) (.call origin .reads key)))))
    (reachability-value origin owners declared edges query)))

;; Streamlined Algorithm T over the same immutable CSR capture. Low/leader bits
;; share one word. The second word changes from active parent-arc link, through
;; follower link, to the final component label. Save the active link BEFORE any
;; postvisit write. No workspace or approval escapes this invocation.
(def (compact-discover graph (stop-when-done? #t))
  (def offsets (compact-graph-offsets graph))
  (def targets (compact-graph-targets graph))
  (def count (vector-length (compact-graph-names graph)))
  (unless (and (fixnum? (* 2 count)) (<= (* 2 count) 4294967295))
    (error "compact SCC state word range" count))
  (def infinity (fx+ (fx* 2 count) 1))
  (def lows (make-u32vector count 0))
  (def pointers (make-u32vector count 0))
  (def clock 0) (def component 0) (def followers 0)
  (def examined 0) (def finished 0) (def popped 0)
  (def (enter node parent-arc)
    (set! clock (fx+ clock 2))
    (u32vector-set! lows node clock)
    (u32vector-set! pointers node parent-arc)
    clock)
  (let search ((root 0))
    (cond
      ((fx= root count)
       (unless (and (fx= clock (fx* 2 count)) (fx= finished count)
                    (fx= popped count) (fx= followers 0))
         (error "shared SCC incomplete owner retirement"))
       (vector pointers count component examined finished popped))
      ((not (fx= (u32vector-ref lows root) 0)) (search (fx+ root 1)))
      (else
        (let walk ((node root) (cursor (u32vector-ref offsets root))
                   (end (u32vector-ref offsets (fx+ root 1)))
                   (arc 0) (current-low (enter root 0)))
          (if (fx< cursor end)
            (let* ((dep (u32vector-ref targets cursor))
                   (dep-low (u32vector-ref lows dep)) (next (fx+ cursor 1)))
              (set! examined (fx+ examined 1))
              (if (fx= dep-low 0)
                (begin
                  ;; Suspended ancestors must expose their most recent low value.
                  (u32vector-set! lows node current-low)
                  (let (child-low (enter dep arc))
                    (walk dep (u32vector-ref offsets dep)
                          (u32vector-ref offsets (fx+ dep 1)) next child-low)))
                (walk node next end arc
                  (if (fx< dep-low current-low) (fxior dep-low 1) current-low))))
            (let* ((parent-arc (u32vector-ref pointers node))
                   (leader? (fx= (fxand current-low 1) 0)))
              (set! finished (fx+ finished 1))
              (when (fx> finished count) (error "shared SCC repeated postvisit"))
              (cond
                ;; Algorithm T's stop-when-done rule, restricted to one component
                ;; covering the whole roster. The marked low 3 reaches the first
                ;; DFS root. Active ancestors reach this node and live followers
                ;; reach an active ancestor. Complete entry and no retirement
                ;; therefore allow one label for every owner. The independent
                ;; spanning/quotient check still runs on the original rows.
                ((and stop-when-done? (fx= current-low 3) (fx= clock (fx* 2 count))
                      (fx= popped 0))
                 (u32vector-fill! pointers (fx+ count 1))
                 (vector pointers count 1 examined finished 0))
                (else
                  (if leader?
                    (let (label (fx+ (fx+ count 1) component))
                      (let pop ()
                        (unless (fx= followers 0)
                          (let (member (fx- followers 1))
                            (when (fx>= (u32vector-ref lows member) current-low)
                              (set! followers (u32vector-ref pointers member))
                              (u32vector-set! pointers member label)
                              (u32vector-set! lows member infinity)
                              (set! popped (fx+ popped 1))
                              (pop)))))
                      (u32vector-set! pointers node label)
                      (u32vector-set! lows node infinity)
                      (set! popped (fx+ popped 1))
                      (set! component (fx+ component 1)))
                    (begin
                      (u32vector-set! lows node current-low)
                      (u32vector-set! pointers node followers)
                      (set! followers (fx+ node 1))))
                  (if (fx= arc 0)
                    (begin
                      (unless (fx= followers 0) (error "shared SCC live followers after root"))
                      (search (fx+ root 1)))
                    (begin
                      (let* ((parent (if (fx= parent-arc 0) root
                                       (u32vector-ref targets (fx- parent-arc 1))))
                             (parent-low (u32vector-ref lows parent))
                             (child-low (if leader? infinity current-low)))
                        (walk parent arc (u32vector-ref offsets (fx+ parent 1)) parent-arc
                          (if (fx< child-low parent-low) (fxior child-low 1) parent-low))))))))))))))

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

;; A verified source rank already proves every SCC is a singleton. Assign only
;; the N result labels; do not allocate DFS state or replay E captured edges.
;; Self loops preserve both bits; any cross-owner cycle clears both bits.
;; Counter zeroes mean NO DFS discoveries/finishes/pops or edge visits occurred.
(def (compact-selected-discover graph)
  (def direction (compact-graph-direction graph))
  (if (fx= direction 0) (compact-discover graph)
    (let* ((count (vector-length (compact-graph-names graph)))
           (_ (unless (and (fixnum? (* 2 count)) (<= (* 2 count) 4294967295))
                (error "compact SCC state word range" count)))
           (state (make-u32vector count 0))
           (decreasing? (not (fx= (fxand direction 1) 0))))
      (let assign ((node 0))
        (when (fx< node count)
          (u32vector-set! state node
            (fx+ (fx+ count 1) (if decreasing? node (fx- (fx- count 1) node))))
          (assign (fx+ node 1))))
      (vector state count count 0 0 0))))

(def (compact-discovery-result graph)
  (let (result (compact-selected-discover graph))
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
(def (normalize keys owners (owned? #f))
  (def representatives (make-hash-table-eq))
  (def members (if owned? (make-hash-table-symbolic) (make-hash-table-eq))) (def ranks (make-hash-table-eq)) (def order [])
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

(def (partition spec) (capture-partition spec #f))
(def (partition-owned spec) (capture-partition spec #t))
(def (capture-partition spec owned?)
  (def keys (.@ spec keys))
  ;; The encoding index admits symbols and uniqueness before any author.
  ;; Keep finite-list admission here, then own the roster; do not build a
  ;; second duplicate table (empty_owner_index_admits_exactly_nodup).
  (unless (list? keys) (error "distinct finite component keys required"))
  ;; Own the admitted roster before the first independent author callback.
  (set! keys (append keys []))
  (let-values (((reads index declared-edges captured-edges)
                 (capture-graph keys (lambda (key)
                   (let (code (.call spec .code key)) (if code (.@ code reads) [])))
                   #t 4294967295 'adjacent owned?)))
    (def part (partition-captured keys reads captured-edges (length keys) declared-edges index owned?))
    (if owned? (own-partition keys reads index part) part)))

;; Pure phase over locally captured immutable rows. Production reaches this only
;; after validating every author. White-box studies may borrow an already
;; certified historical partition, charging zero NEW declaration validation.
(def (partition-captured keys reads captured-edges validation-owners declared-edges
                         (index #f) (owned? #f))
  (let-values (((owners next component examined-edges finished popped) (discover keys reads captured-edges index)))
    ;; A tail handoff carries NO packed input or capture construction buffers.
    ;; Keep those roots out of normalization/certificate closure environments.
    (finish-partition keys reads validation-owners declared-edges
      owners next component examined-edges finished popped owned?)))

(def (finish-partition keys reads validation-owners declared-edges
                       owners next component examined-edges finished popped (owned? #f))
    (let-values (((groups members ranks) (normalize keys owners owned?)))
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
          (work-receipt validation-owners declared-edges (if (zero? finished) 0 next)
            examined-edges finished popped next component
            certificate-buckets certificate-edges quotient-edges certificate-singletons reverse-edges
            (if (zero? finished) next 0) (if (zero? finished) quotient-edges 0)) owners #f))))

;; Owned partition keeps the existing SCC result and only adds the indexes
;; required to revise that result without rereading a declaration.
(def (owned-snapshot owned work)
  (def (lookup index key)
    (unless (symbol? key) (error "component key must be a symbol" key))
    (%index-ref index key))
  (make-%partition #f
    (cut lookup (owned-partition-owner owned) <>)
    (lambda (key) (list-copy (lookup (owned-partition-forward owned) key)))
    #f work #f owned))

(def (own-partition keys reads index part)
  (def positions (if index (compact-graph-positions index) (make-hash-table-symbolic)))
  (def backward (make-hash-table-symbolic))
  (def cycle? (and (pair? keys) (pair? (cdr keys)) (= (hash-length (%partition-members part)) 1)))
  (for ((key keys) (position (in-range (length keys))))
    (unless index (hash-put! positions key position))
    (def row (hash-ref reads key))
    (when (and cycle? (not (and (pair? row) (null? (cdr row)))))
      (set! cycle? #f))
    (for (provider row)
      (hash-put! backward provider (cons key (hash-ref backward provider [])))))
  (owned-snapshot (make-owned-partition keys positions (%index reads) (%index backward)
                    (%index (%partition-owners part)) (%index (%partition-members part))
                    ;; Capture already authenticated both rank-direction bits.
                    ;; Carry that structural evidence instead of scanning again.
                    (cond (cycle? 'cycle)
                          ((and index (positive? (compact-graph-direction index)))
                           (compact-graph-direction index))
                          (else #f)))
    (partition-work part)))

;; A node is entered once in each union walk. Mark on enqueue so a wide hub
;; does not place duplicate pending entries on the traversal stack.
(def (edit-region-walk roots index additions counts)
  (def reached (make-hash-table-symbolic))
  (def pending [])
  (def (enter key)
    (unless (hash-key? reached key)
      (hash-put! reached key #t)
      (set! pending (cons key pending))))
  (for-each enter roots)
  (let walk ()
    (unless (null? pending)
      (let (key (car pending))
        (def (visit next)
          (vector-set! counts 1 (1+ (vector-ref counts 1)))
          (enter next))
        (set! pending (cdr pending))
        (vector-set! counts 0 (1+ (vector-ref counts 0)))
        (%for-each-reverse-bucket visit (%index-ref index key []))
        (for-each visit (hash-ref additions key []))
        (walk))))
  reached)

;; Structural edit over the exact predecessor partition and fixed support.
;; The caller above this layer must authenticate where the replacement rows
;; came from. This operation detaches them, checks all keys, and runs no author.
(def (%partition-source-count part)
  (hash-length (owned-partition-positions (%partition-owned part))))
(def (%partition-key-position part key)
  (hash-ref (owned-partition-positions (%partition-owned part)) key))
(def (%partition-key-before part)
  (def positions (owned-partition-positions (%partition-owned part)))
  (lambda (a b) (< (hash-ref positions a) (hash-ref positions b))))
(def (%partition-order-keys part keys)
  (list-sort (%partition-key-before part) keys))
(def (%partition-representatives part)
  (def owned (%partition-owned part))
  (def keys (owned-partition-keys owned))
  (if (eq? (owned-partition-shape owned) 'singletons)
    (list-copy keys)
    (with-list-builder (add)
      (for (key keys)
        (when (eq? key ((partition-owner part) key)) (add key))))))
(def (revise-partition prior replacements quotient?: (quotient? #f))
  (def old (and (partition? prior) (%partition-owned prior)))
  (unless old (error "owned component partition required"))
  (unless (list? replacements) (error "finite component edit required"))
  (def positions (owned-partition-positions old))
  (def forward (owned-partition-forward old))
  (def backward (owned-partition-backward old))
  (def rank-mask
    (let (shape (owned-partition-shape old))
      (if (and (fixnum? shape) (> shape 0) (<= shape 3)) shape 0)))
  (def rank-edge-checks 0)
  (def seen (make-hash-table-symbolic))
  (def next-forward (%index-fork forward))
  (def add-forward (make-hash-table-symbolic))
  (def add-backward (make-hash-table-symbolic))
  (def remove-backward (make-hash-table-symbolic))
  (def buckets (make-hash-table-symbolic))
  (def roots
    (with-list-builder (add)
      (for (entry replacements)
        (unless (and (pair? entry) (symbol? (car entry)) (hash-key? positions (car entry))
                     (list? (cdr entry)))
          (error "unsupported component row replacement" entry))
        (def key (car entry))
        (when (hash-key? seen key) (error "duplicate component row replacement" key))
        (hash-put! seen key #t)
        (let (owner-rank (and (positive? rank-mask) (hash-ref positions key)))
          (for (dep (cdr entry))
            (unless (and (symbol? dep) (hash-key? positions dep))
              (error "unsupported component read" key dep))
            (when (positive? rank-mask)
              (let (provider-rank (hash-ref positions dep))
                (set! rank-edge-checks (1+ rank-edge-checks))
                (cond ((< provider-rank owner-rank) (set! rank-mask (fxand rank-mask 1)))
                      ((> provider-rank owner-rank) (set! rank-mask (fxand rank-mask 2))))))))
        (def row (delete-duplicates/hash (cdr entry) table: (make-hash-table-symbolic)))
        (def previous (%index-ref forward key))
        (unless (equal? row previous)
          (let ()
            (def (membership names)
              (def index (make-hash-table-symbolic))
              (for (name names) (hash-put! index name #t))
              index)
            (def was (membership previous))
            (def now (membership row))
            (add key)
            (%index-write! next-forward key row)
            (for (provider row)
              (unless (hash-key? was provider)
                (hash-put! add-forward key (cons provider (hash-ref add-forward key [])))
                (hash-put! add-backward provider (cons key (hash-ref add-backward provider [])))
                (hash-put! buckets provider #t)))
            (for (provider previous)
              (unless (hash-key? now provider)
                (let (removed (hash-ref remove-backward provider #f))
                  (unless removed
                    (set! removed (make-hash-table-symbolic))
                    (hash-put! remove-backward provider removed))
                  (hash-put! removed key #t)
                  (hash-put! buckets provider #t)))))))))
  ;; Freeze the decision AFTER all replacement validation and mask updates.
  ;; Internal definition ordering is not a temporal snapshot boundary.
  (let (ranked? (positive? rank-mask))
  (def next-backward (%index-fork backward))
  (def removed-edges 0)
  (for (provider (hash-keys buckets))
    (def removed (hash-ref remove-backward provider #f))
    (def row (%index-ref backward provider []))
    (when removed
      (for (consumer (hash-keys removed))
        (set! row (%reverse-bucket-remove row consumer))
        (set! removed-edges (1+ removed-edges))))
    ;; The collected prefix is already in reverse edit order.
    (for (consumer (reverse (hash-ref add-backward provider [])))
      (set! row (%reverse-bucket-add row consumer)))
    (%index-write! next-backward provider row))
  (def forward-work (vector 0 0))
  (def backward-work (vector 0 0))
  ;; Without additions the union IS the old graph. From one edited row,
  ;; its forward/reverse intersection is already the old owner group.
  (def single-removal? (and (pair? roots) (null? (cdr roots)) (zero? (hash-length add-forward))))
  ;; Every key reached the cut owner before this edit. With one successor per
  ;; row, the remaining path to the cut sink precludes any nontrivial SCC.
  (def functional-cut? (and single-removal? (= removed-edges 1)
                            (eq? (owned-partition-shape old) 'cycle)))
  (def old-owner (owned-partition-owner old))
  (def old-members (owned-partition-members old))
  (def single-owner (and single-removal? (not functional-cut?) (%index-ref old-owner (car roots))))
  (def to (and (not ranked?) (not single-removal?) (edit-region-walk roots forward add-forward forward-work)))
  (def from (and (not ranked?) (not single-removal?) (edit-region-walk roots backward add-backward backward-work)))
  (def (inside? key)
    (if single-removal? (eq? single-owner (%index-ref old-owner key))
      (and (hash-key? to key) (hash-key? from key))))
  (def region
    (cond (ranked? [])
          (functional-cut? [])
          (single-removal? (cdr (%index-ref old-members single-owner)))
          (else
           (let (smaller (if (< (hash-length to) (hash-length from)) to from))
             (%partition-order-keys prior (filter inside? (hash-keys smaller)))))))
  (def width (if functional-cut? (hash-length positions) (length region)))
  (def whole? (and (pair? region) (= width (hash-length positions))))
  (def induced-readers 0)
  (def cycle? (and whole? (> width 1)))
  (def local-part
    (and (pair? region)
      (let ()
        (def rows (make-hash-table-symbolic size: width))
        (def edges 0)
        (for (key region)
          (def all (%index-ref next-forward key))
          (when (and cycle? (not (and (pair? all) (null? (cdr all)))))
            (set! cycle? #f))
          (def row
            (if whole?
              (let (size (length all))
                (set! induced-readers (+ induced-readers size))
                (set! edges (+ edges size))
                all)
              (filter (lambda (dep)
                (set! induced-readers (1+ induced-readers))
                (and (inside? dep) (begin (set! edges (1+ edges)) #t))) all)))
          (hash-put! rows key row))
        (partition-captured region rows edges 0 0 #f #t))))
  ;; If the repair covers the entire graph, use the discovered native tables
  ;; as the new base. One sparse tree write per owner would only copy work.
  (def owner (cond (ranked? old-owner)
                   (functional-cut? (%index-project positions identity))
                   (whole? (%index (%partition-owners local-part)))
                   (else (%index-fork old-owner))))
  (def members (cond (ranked? old-members)
                     (functional-cut? (%index-project positions (lambda (key) (list 1 key))))
                     (whole? (%index (%partition-members local-part)))
                     (else (%index-fork old-members))))
  (def owner-assignments 0)
  (def member-assignments 0)
  ;; Every successor group changes on a certified cut. The caller can use
  ;; the admitted source order directly, including any authored edit seeds.
  (def changed-groups (and quotient? (not functional-cut?) (make-hash-table-symbolic)))
  (def added [])
  (def retired [])
  (def remapped [])
  (when (and local-part (or quotient? (not whole?)))
    ;; Explicit #f retires a former representative in the covered region.
    (for (key region)
      (def representative ((partition-owner local-part) key))
      (unless (eq? representative (%index-ref old-owner key))
        (when quotient? (set! remapped (cons key remapped)))
        (unless whole?
          (%index-write! owner key representative)
          (set! owner-assignments (1+ owner-assignments))))
      (def replacement (hash-get (%partition-members local-part) key))
      (def previous (%index-ref old-members key #f))
      (unless (equal? replacement previous)
        (when quotient?
          (cond ((not previous) (set! added (cons key added)))
                ((not replacement) (set! retired (cons key retired))))
          (when replacement (hash-put! changed-groups key #t)))
        (unless whole?
          (%index-write! members key replacement)
          (set! member-assignments (1+ member-assignments))))))
  ;; A reader outside the region can keep its SCC but refer to a different
  ;; representative. Traverse the successor inverse of each remapped owner.
  (def quotient-readers 0)
  (when quotient?
    (for (key remapped)
      (%for-each-reverse-bucket
        (lambda (reader)
          (set! quotient-readers (1+ quotient-readers))
          (hash-put! changed-groups (%index-ref owner reader) #t))
        (%index-ref next-backward key []))))
  (def result
    (owned-snapshot
      (make-owned-partition (owned-partition-keys old) positions next-forward next-backward owner members
        (cond (ranked? rank-mask)
              (functional-cut? 'singletons)
              ((null? roots) (owned-partition-shape old))
              ((and cycle? (= (hash-length (%partition-members local-part)) 1)) 'cycle)
              (else #f)))
      (.o edited-rows: (hash-length seen) changed-rows: (length roots)
      forward-buckets: (vector-ref forward-work 0) forward-edges: (vector-ref forward-work 1)
      reverse-buckets: (vector-ref backward-work 0) reverse-edges: (vector-ref backward-work 1)
      reverse-writes: (hash-length buckets) reverse-removals: removed-edges reverse-rewrite-edges: 0
      region-owners: width region-edge-visits: induced-readers owner-writes: owner-assignments
      retained-direction: (and ranked? rank-mask) rank-checks: rank-edge-checks
      member-writes: member-assignments rebased-owners: (if whole? width 0)
        projected-singletons: (if functional-cut? width 0)
        quotient-reader-edges: quotient-readers
        local: (and local-part (partition-work local-part)))))
  (if quotient?
    (values result (if functional-cut? 'all-representatives changed-groups)
      (cond (functional-cut? 'complete)
            ((or (pair? added) (pair? retired))
             (make-quotient-support (reverse added) (reverse retired)))
            (else #f)))
    result)))
