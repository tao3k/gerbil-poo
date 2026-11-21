;;; Strongly connected components (SCC): maximal mutually reachable node groups.
;;; Partition computation keys by mutual reachability over their declared reads.
;;; Explicit feedback construction and recursive topology consume these groups;
;;; this does not load namespaces or make ordinary cyclic slot access valid.
(export partition partition? partition-groups partition-owner partition-reads
        partition-members partition-for-each-member partition-group-of partition-group-size partition-work
        partition-owned revise-partition %partition-order-keys %partition-representatives %partition-key-before
        quotient-support-added quotient-support-retired %partition-source-count %partition-key-position
        capture-reachability capture-reachability-procedure)
(import :std/iter
        (only-in :std/error raise-unbound-key)
        (only-in :gerbil/runtime/interface interface-instance-object)
        (only-in :gerbil/runtime/hash symbol-hash-table? gc-hash-table::t)
        (only-in :gerbil/runtime/table symbolic-table-ref symbolic-table-set! raw-table-new
                 &raw-table-table &raw-table-table-set! &raw-table-count &raw-table-count-set!
                 &raw-table-free &raw-table-free-set! make-gc-table gc-table-ref gc-table-set! gc-table-for-each
                 &gc-table-gcht &gc-table-gcht-set!)
        (only-in :gerbil/runtime/thread with-lock)
        (only-in :std/list/list delete-duplicates/hash foldl)
        (only-in :std/list/list-builder with-list-builder)
        (only-in ../support/base %graph-table-seed)
        (only-in ../support/index %roster %roster-width %roster-position %roster-keys %roster-for-each %roster-project
                 %index %index-base %index-ref %index-fork %index-write! %index-retire! %index-overridden?
                 %make-ordinal-buckets %ordinal-bucket-ref %ordinal-roster %roster-cold-index)
        (only-in ./schedule %reverse-bucket-remove %reverse-bucket-add %for-each-reverse-bucket)
        (only-in ../read-route gc-table-route-current? standard-symbol-table-writes?)
        ../object)
(extern namespace: clan/poo/read-route %ordinal-index-routes-current?
  %standard-symbol-table-lookup? %gc-scratch-routes-current? %gc-table-route-backend)
(extern namespace: clan/poo/graph/schedule %declared-row-source %decode-ordinal-row
  %packed-rows? %packed-rows-names %packed-rows-buckets %packed-rows-offsets
  %packed-rows-targets %packed-rows-direction)
(extern namespace: clan/poo/object %ref-owned-list)
;; Public groups/representatives retain source order, independently of DFS order.
(defstruct %partition (groups owner reads members work owners owned) final: #t)
(defstruct owned-partition (roster forward backward owner members shape retired? ranks) final: #t)
(defstruct quotient-support (added retired) final: #t)
(def partition? %partition?)
(def (partition-groups part)
  (def groups (%partition-groups part))
  (cond
   ((procedure? groups) (groups))
   ((%partition-owned part)
    => (lambda (owned)
         (with-list-builder (add)
           (if (eq? (owned-partition-shape owned) 'singletons)
             (%roster-for-each (lambda (key)
               (when (or (not (owned-partition-retired? owned)) (owned-active-owner owned key))
                 (add (list key)))) (owned-partition-roster owned))
             (%roster-for-each (lambda (key)
               (when (eq? key (owned-active-owner owned key))
                 (add (partition-members part key)))) (owned-partition-roster owned))))))
   (else groups)))
(def partition-owner %partition-owner)
(def partition-reads %partition-reads)
(def partition-work %partition-work)
(def (owned-active-owner owned key)
  (%index-ref (owned-partition-owner owned) key #f))
(def (owned-member-list entry)
  (let (row (cdr entry))
    (if (procedure? row) (row #f) row)))
(def (observe-member part representative size?)
  (def owned (%partition-owned part))
  (def members (%partition-members part))
  (if (procedure? members)
    (members representative size?)
    (let (entry (if owned
                  (and (symbol? representative) (%index-ref (owned-partition-members owned) representative #f))
                  (hash-get members representative)))
      (and entry
           (cond (size? (car entry))
                 (owned (let (row (cdr entry)) (if (procedure? row) (row #f) (list-copy row))))
                 (else (cdr entry)))))))
(def (partition-members part representative)
  (observe-member part representative #f))
;; Deliver source-order members of an existing representative. The
;; visitor cannot change the partition's owned member storage.
(def (partition-for-each-member part representative visit)
  (unless (procedure? visit) (error "component member visitor required"))
  (def owned (%partition-owned part))
  (def members (%partition-members part))
  (cond
   ((and owned (procedure? members)) (members representative visit))
   (owned
    (and (symbol? representative)
         (let (entry (%index-ref (owned-partition-members owned) representative #f))
           (and entry (visit-owned-members entry visit)))))
   (else
    (let (row (partition-members part representative))
      (and row (begin (for-each visit row) #t))))))

(def (visit-owned-members entry visit)
  (let (row (cdr entry))
    (if (procedure? row) (row visit)
      (begin (for-each visit row) #t))))

(def (observe-group part node size?)
  (def owned (%partition-owned part))
  (def representative
    (if owned (and (symbol? node) (%index-ref (owned-partition-owner owned) node #f))
      (let (owners (%partition-owners part))
        (if (procedure? owners) (owners node #t) (hash-get owners node)))))
  (and representative (observe-member part representative size?)))
(def (partition-group-of part node)
  (observe-group part node #f))
(def (partition-group-size part node)
  (let (members (%partition-members part))
    (if (and (procedure? members) (%partition-owned part))
      (members node #t)
      (observe-group part node #t))))
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

(defstruct ordinal-capture (buckets adapter) final: #t)
(defstruct compact-graph (names positions offsets targets direction) final: #t)

(def (capture-roster-length keys)
  (if (vector? keys) (vector-length keys) (length keys)))

(def (capture-compact keys reads edges)
  (def count (length keys))
  (unless (and (fixnum? count) (fixnum? (1+ count)) (fixnum? edges) (<= 0 count 4294967295)
               (<= 0 edges 4294967295))
    (error "compact Graph word range" count edges))
  (def names (list->vector keys))
  (def positions (make-hash-table-symbolic size: count seed: (%graph-table-seed)))
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

;; Restore the accepted rows into the original table adapter. Preserve any
;; projected tokens without replaying authors or calling a replaced delegate.
(def (restore-ordinal-rows! keys backend row-at)
  (def restored (make-gc-table (vector-length keys) gc-hash-table::t))
  (for (i (in-range (vector-length keys)))
    (gc-table-set! restored (vector-ref keys i) (row-at i)))
  (&gc-table-gcht-set! backend (&gc-table-gcht restored)))

(def (ordinal-row-reader keys buckets table backend rows (decode #f))
  (def retirement (make-mutex 'captured-rows))
  (def (sparse-row i)
    (gc-table-ref backend (vector-ref keys i) #f))
  (def (retire!)
    (restore-ordinal-rows! keys backend
      (if (eq? rows #t)
        (lambda (i) (or (sparse-row i) (decode i)))
        (cut vector-ref rows <>)))
    (set! rows #f)
    (set! decode #f))
  (def (lookup key empty-default?)
    (if empty-default? (hash-ref table key []) (hash-ref table key)))
  (lambda (key (empty-default? #f))
    (def (position)
      (and (symbol? key) (eq? backend (%gc-table-route-backend table))
           (%ordinal-bucket-ref buckets key)))
    (def current rows)
    (def dense (and (vector? current) (let (i (position)) (and i (vector-ref current i)))))
    (or dense
        (and current
          (with-lock retirement
            (lambda ()
              (and rows
                (let (i (position))
                  (cond
                   ((not i) (retire!) #f)
                   ((eq? rows #t)
                    (or (sparse-row i)
                        (let (row (decode i))
                          (gc-table-set! backend key row)
                          row)))
                   (else (vector-ref rows i))))))))
        (lookup key empty-default?))))

(def (capture-graph keys read-owner (symbolic-rows? #t) (edge-word-ceiling 4294967295)
                    (ordered-rows? 'adjacent) (stable-rows? #f) (compact-rows? #f) (declared-rows #f)
                    (admitted-positions #f))
  ;; The private reduced ceiling exercises exactly the native wide fallback in
  ;; bounded tests. Production always uses the full u32 range; it cannot expand.
  (unless (and (exact-integer? edge-word-ceiling) (<= 0 edge-word-ceiling 4294967295))
    (error "captured edge word ceiling" edge-word-ceiling))
  (def count (capture-roster-length keys))
  (def word-support? (and (fixnum? (* 2 count)) (<= (* 2 count) 4294967295)))
  (def buckets (and word-support? symbolic-rows? (not stable-rows?) (vector? keys)
                    (%ordinal-index-routes-current?) (%make-ordinal-buckets keys)))
  (def positions
    (if (or admitted-positions buckets)
      (begin
        ;; Preserve the native constructor's seed transition without allocating
        ;; a second table sized for the entire graph.
        (make-hash-table-symbolic seed: (%graph-table-seed))
        admitted-positions)
      (make-hash-table-symbolic size: count seed: (%graph-table-seed))))
  (def raw (and positions (interface-instance-object positions)))
  (def (assign! key at)
    (unless (symbol? key) (error "symbolic captured owner required" key))
    (symbolic-table-set! raw key at))
  (when (and positions (not admitted-positions))
    (unless (symbol-hash-table? raw) (error "captured owner index representation"))
    (if (vector? keys)
      (for ((key (in-vector keys)) (at (in-range count)))
        (assign! key at))
      (let assign ((rest keys) (at 0))
        (unless (null? rest)
          (assign! (car rest) at)
          (assign (cdr rest) (1+ at)))))
    (unless (= count (hash-length positions)) (error "distinct captured owners required")))
  (def (position key)
    (if buckets (%ordinal-bucket-ref buckets key) (symbolic-table-ref raw key #f)))
  (def packed? word-support?)
  ;; Per-invocation duplicate membership, allocated only for a multi-key row.
  ;; It never stores source/currentness approvals. Two fresh stamps per owner
  ;; distinguish forward uniqueness from reverse rightmost normalization.
  (def row-marks #f)
  ;; Shape is a routing hint, not evidence for the next row. A repeat sends
  ;; the next two unique multi-target rows through the ordinary reverse scan.
  (def fresh-streak 2)
  (def ordered-trial? (and ordered-rows? (not symbolic-rows?)))
  (def row-buffer #f) (def owner-names (and (vector? keys) keys))
  (def offsets (and packed? (make-u32vector (1+ count) 0)))
  (def small-table (and compact-rows? buckets (make-hash-table-eq)))
  (def row-backend (and small-table (gc-table-route-current? small-table)
                        (interface-instance-object small-table)))
  (def deferred-rows? (and row-backend #t))
  (when (and admitted-positions (not symbolic-rows?) packed?)
    (make-hash-table-symbolic seed: (%graph-table-seed)))
  (def reads (or (and deferred-rows? small-table)
                 (and (or symbolic-rows? (not packed?))
                      (if stable-rows? (make-hash-table-symbolic size: count seed: (%graph-table-seed))
                        (make-hash-table-eq size: count)))))
  (def declared 0) (def edges 0)
  (def direction 3)
  ;; Private, bounded construction chunks, not a retained graph/value cache.
  ;; A small graph pays only its support-sized chunk; an empty graph pays none.
  (def capacity (max 1 (min count 65536)))
  (def chunks []) (def chunk #f) (def used 0)
  ;; Only completed offset intervals belong to the accepted prefix. A
  ;; partially encoded current row is never restored to a symbolic table.
  (def (visit-packed-prefix completed emit)
    (unless owner-names (set! owner-names (list->vector keys)))
    (let ((pending (reverse (if chunk (cons chunk chunks) chunks))) (cursor 0))
      (def (next-id)
        (when (fx= cursor capacity) (set! pending (cdr pending)) (set! cursor 0))
        (unless (pair? pending) (error "incomplete captured row prefix"))
        (let (id (u32vector-ref (car pending) cursor))
          (set! cursor (fx+ cursor 1)) id))
      (for (owner (in-range completed))
        (emit (vector-ref owner-names owner)
          (for/collect (_at (in-range (u32vector-ref offsets owner)
                             (u32vector-ref offsets (fx+ owner 1))))
            (vector-ref owner-names (next-id)))))))
  (def (restore-symbolic-prefix! completed)
    (unless reads
      (set! reads (if stable-rows? (make-hash-table-symbolic size: count seed: (%graph-table-seed))
                    (make-hash-table-eq size: count)))
      (visit-packed-prefix completed (lambda (key row) (hash-put! reads key row)))))
  (def (retire-ordinal-rows! completed)
    (when deferred-rows?
      (let (restored (make-gc-table count gc-hash-table::t))
        (visit-packed-prefix completed (lambda (key row) (gc-table-set! restored key row)))
        (&gc-table-gcht-set! row-backend (&gc-table-gcht restored))
        (set! deferred-rows? #f))))
  (defrule (store-row! key owner row)
    (when (and reads (not (and deferred-rows? (gc-table-route-current? reads))))
      (retire-ordinal-rows! owner)
      (hash-put! reads key row)))
  (def (use-wide-rows! completed)
    (retire-ordinal-rows! completed)
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
  (def (reject-read key deps)
    ;; Refusal irritants are public, so do not expose a declared source row.
    (error "unsupported component read" key (if declared-rows (list-copy deps) deps)))
  (defrule (capture-target! key owner deps id)
    (begin
      (unless id (reject-read key deps))
      (cond ((fx< id owner) (set! direction (fxand direction 1)))
            ((fx> id owner) (set! direction (fxand direction 2))))
      (append-target owner id)
      (set! edges (1+ edges))))
  (for ((key keys) (owner (in-range count)))
    (when packed? (u32vector-set! offsets owner edges))
    (def deps (if declared-rows (or (vector-ref declared-rows owner) []) (read-owner key)))
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
    (cond
     (end
      (let ((first (u32vector-ref chunk used)) (last (u32vector-ref chunk (fx- end 1)))
            (size (fx- end used)))
        (when (fx< (fxmin first last) owner) (set! direction (fxand direction 1)))
        (when (fx> (fxmax first last) owner) (set! direction (fxand direction 2)))
        (set! edges (fx+ edges size))
        (set! declared (+ declared size))
        (set! used end)))
     ((and deferred-rows? (pair? deps) (null? (cdr deps)))
      ;; The admitted roster owns unique symbols. An adjacent identity hit
      ;; identifies the same ordinal as the bucket lookup. A miss still uses
      ;; the bucket index and preserves the original refusal.
      (def dep (car deps))
      (def next (fx+ owner 1))
      (def id (and (symbol? dep)
        (cond ((and (fx< next count) (eq? dep (vector-ref keys next))) next)
              ((and (fx> owner 0) (eq? dep (vector-ref keys (fx- owner 1)))) (fx- owner 1))
              (else (position dep)))))
      (capture-target! key owner deps id)
      (store-row! key owner (list dep))
      (set! declared (1+ declared)))
     (else
      (let ()
        ;; Keep the finite/proper-list guard before any length or hash primitive.
        ;; Symbol admission shares the subsequent ID pass; this pure interval
        ;; contains no author, getter or source-approval callback (fused_row_eq).
        (unless (list? deps)
          (reject-read key deps))
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
                  (let* ((dep (car pending)) (id (and (symbol? dep) (position dep))))
                    (unless id (reject-read key deps))
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
                (store-row! key owner (append deps [])))
              ;; A distinct fresh stamp lets the existing reverse scan keep the
              ;; rightmost occurrence, regardless of how late the first repeat was.
              (let ((token (fx+ forward 1)))
                (let-values (((start unique)
                              (let scan ((read row-length) (write row-length) (unique (and reads (not deferred-rows?) [])))
                                (if (fx= read 0) (values write unique)
                                  (let* ((next (fx- read 1)) (id (u32vector-ref row-buffer next)))
                                    (if (fx= (u32vector-ref row-marks id) token)
                                      (scan next write unique)
                                      (let (destination (fx- write 1))
                                        (u32vector-set! row-marks id token)
                                        (u32vector-set! row-buffer destination id)
                                        (scan next destination (and unique (cons (vector-ref owner-names id) unique))))))))))
                  (unless reads
                    (set! fresh-streak (if (fx= start 0) (fxmin 2 (fx+ fresh-streak 1)) 0)))
                  (append-row-targets owner start row-length)
                  (store-row! key owner (or unique
                    (for/collect (at (in-range start row-length))
                      (vector-ref owner-names (u32vector-ref row-buffer at)))))))))
          ;; Preserve the inexpensive empty/singleton path and the original wide
          ;; domain. Copy singleton spines before the next independent callback.
          (begin
            (unless (andmap symbol? deps) (reject-read key deps))
            (let (unique (cond ((null? deps) []) ((null? (cdr deps)) deps)
                              (else (delete-duplicates/hash deps))))
              (for (dep unique)
                (let (id (position dep))
                  (capture-target! key owner deps id)))
              (store-row! key owner (if (and (pair? unique) (null? (cdr unique)))
                                    (list (car unique)) unique)))))
        (set! declared (+ declared row-length))))))
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
          (make-compact-graph (or owner-names (list->vector keys))
            (if deferred-rows? (make-ordinal-capture buckets reads) positions) offsets targets direction)))))
  (def published
    (if deferred-rows?
      (let* ((targets (compact-graph-targets index))
             (decode (cut %decode-ordinal-row keys offsets targets <>)))
        ;; Singleton certification reads the packed edges. Its existing
        ;; row projection allocates symbolic storage at first demand.
        (if (and (zero? direction) (not declared-rows))
          (let (rows (make-vector count #f))
            (for (owner (in-range count))
              (vector-set! rows owner (decode owner)))
            (ordinal-row-reader keys buckets reads row-backend rows))
          (ordinal-row-reader keys buckets reads row-backend #t decode)))
      reads))
  (values published index declared edges))

;; Return reachable keys in source order using the saved adjacency rows.
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

(def active-tour-evidence (gensym 'active-tour))
(def (certify-active-tour offsets targets parents root tip arc slot count)
  (def edges (u32vector-length targets))
  (def start (u32vector-ref offsets tip))
  (and (fx< slot (fx- (u32vector-ref offsets (fx+ tip 1)) start))
       (fx= (u32vector-ref targets (fx+ start slot)) root)
       (fx> arc 0) (fx<= arc edges) (fx= (u32vector-ref targets (fx- arc 1)) tip)
       (let check ((node tip) (incoming arc) (left count))
         (cond
          ((fx= incoming 0) (and (fx= node root) (fx= left 1)))
          ((or (fx<= left 1) (fx= node root)) #f)
          (else
           (let (prior (u32vector-ref parents node))
             (and (fx<= prior edges)
                  (let* ((parent (if (fx= prior 0) root (u32vector-ref targets (fx- prior 1))))
                         (at (fx- incoming 1)))
                    (and (fx<= (u32vector-ref offsets parent) at)
                         (fx< at (u32vector-ref offsets (fx+ parent 1)))
                         (check parent prior (fx- left 1)))))))))))

;; Streamlined Algorithm T over the same immutable CSR capture. Low/leader bits
;; share one word. The second word changes from active parent-arc link, through
;; follower link, to the final component label. Save the active link BEFORE any
;; postvisit write. No workspace or approval escapes this invocation.
(def (compact-discover graph (stop-when-done? #t) (record-return? #f))
  (def offsets (compact-graph-offsets graph))
  (def targets (compact-graph-targets graph))
  (def count (vector-length (compact-graph-names graph)))
  (unless (and (fixnum? (* 2 count)) (<= (* 2 count) 4294967295))
    (error "compact SCC state word range" count))
  (def infinity (fx+ (fx* 2 count) 1))
  (def lows (make-u32vector count 0))
  (def pointers (make-u32vector count 0))
  (def returns #f)
  (def clock 0) (def component 0) (def followers 0)
  (def examined 0) (def finished 0) (def popped 0)
  (def (enter node parent-arc)
    (set! clock (fx+ clock 2))
    (u32vector-set! lows node clock)
    (u32vector-set! pointers node parent-arc)
    clock)
  (def (remember-return! node at)
    (def slot (fx- at (u32vector-ref offsets node)))
    (unless returns (set! returns (make-u8vector count 255)))
    (if (and (u8vector? returns) (fx< slot 255))
      (u8vector-set! returns node slot)
      (begin
        (when (u8vector? returns)
          (let (wide (make-u32vector count 4294967295))
            (for (i (in-range count))
              (let (choice (u8vector-ref returns i))
                (unless (fx= choice 255) (u32vector-set! wide i choice))))
            (set! returns wide)))
        (u32vector-set! returns node slot))))
  (let search ((root 0))
    (cond
      ((fx= root count)
       (unless (and (fx= clock (fx* 2 count)) (fx= finished count)
                    (fx= popped count) (fx= followers 0))
         (error "shared SCC incomplete owner retirement"))
       (vector pointers count component examined finished popped returns))
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
                (if (fx< dep-low current-low)
                  (begin
                    (when record-return? (remember-return! node cursor))
                    (walk node next end arc (fxior dep-low 1)))
                  (walk node next end arc current-low))))
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
                 ;; An active stack that covers the roster with a closing
                 ;; arc to the root is itself the two-direction certificate.
                 (let (tour? (and returns (fx= followers 0)
                                 (certify-active-tour offsets targets pointers root node arc
                                   (if (u8vector? returns) (u8vector-ref returns node)
                                     (u32vector-ref returns node)) count)))
                   ;; Replay only the pending parent relaxations. Parents that
                   ;; already attained low 3 retain the earlier return arc.
                   (when (and record-return? (not tour?))
                     (let unwind ((arc arc) (parent-arc parent-arc))
                       (unless (fx= arc 0)
                         (let (parent (if (fx= parent-arc 0) root
                                        (u32vector-ref targets (fx- parent-arc 1))))
                           (when (fx> (u32vector-ref lows parent) 3)
                             (remember-return! parent (fx- arc 1)))
                           (unwind parent-arc (u32vector-ref pointers parent))))))
                   (u32vector-fill! pointers (fx+ count 1))
                   (vector pointers count 1 examined finished 0 (if tour? active-tour-evidence returns))))
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
                        (if (fx< child-low parent-low)
                          (begin
                            (when record-return? (remember-return! parent (fx- arc 1)))
                            (walk parent arc (u32vector-ref offsets (fx+ parent 1)) parent-arc
                              (fxior child-low 1)))
                          (walk parent arc (u32vector-ref offsets (fx+ parent 1)) parent-arc
                            parent-low))))))))))))))

(def (compact-rank state count node)
  (let (retired (u32vector-ref state node))
    (unless (fx> retired count) (error "compact SCC unretired owner" node retired))
    (fx- (fx- retired count) 1)))

(def (compact-component-owners graph result (table #f))
  (def names (compact-graph-names graph))
  (def count (vector-length names))
  (def state (vector-ref result 0))
  (def owners (or table (make-hash-table-symbolic size: count seed: (%graph-table-seed))))
  (def raw-owners (interface-instance-object owners))
  (unless (symbol-hash-table? raw-owners) (error "compact owner index representation"))
  (for (node (in-range count))
    (symbolic-table-set! raw-owners (vector-ref names node) (compact-rank state count node)))
  owners)

;; A verified source rank already proves every SCC is a singleton. Assign only
;; the N result labels; do not allocate DFS state or replay E captured edges.
;; Self loops preserve both bits; any cross-owner cycle clears both bits.
;; Counter zeroes mean NO DFS discoveries/finishes/pops or edge visits occurred.
(def (compact-selected-discover graph (record-return? #f))
  (def direction (compact-graph-direction graph))
  (if (fx= direction 0) (compact-discover graph #t record-return?)
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
      (vector state count count 0 0 0 #f))))

(def (compact-discovery-result graph)
  (let (result (compact-selected-discover graph))
    (vector-set! result 0 (compact-component-owners graph result)) result))

;; Private layout refinement of the existing discovery operation. No public
;; representation or Module identity changes, no shared traversal workspace.
;; Word-domain dispatch preserves the original wide representation outside u32.
(def (discover keys reads (captured-edges #f) (captured-index #f))
  (def count (capture-roster-length keys))
  (def (list-keys) (if (vector? keys) (vector->list keys) keys))
  (def edges (or captured-edges
                 (foldl (lambda (key n) (+ n (length (hash-ref reads key)))) 0 (list-keys))))
  (if (and (fixnum? (* 2 count)) (<= (* 2 count) 4294967295)
           (fixnum? edges) (<= edges 4294967295))
    (let (result (compact-discovery-result (or captured-index (capture-compact (list-keys) reads edges))))
      (values (vector-ref result 0) (vector-ref result 1) (vector-ref result 2)
              (vector-ref result 3) (vector-ref result 4) (vector-ref result 5)))
    (discover-wide (list-keys) reads)))

;; The component-ID map is transient: normalization returns only final indices.
(def (normalize keys owners (owned? #f) (state #f))
  (def representatives (make-hash-table-eq))
  (def members (if owned? (make-hash-table-symbolic seed: (%graph-table-seed)) (make-hash-table-eq))) (def ranks (make-hash-table-eq)) (def order [])
  (defrule (add-owner key id)
    (let* ((prior (hash-get representatives id))
           (representative (or prior key)))
      (unless prior
        (hash-put! representatives id key)
        (hash-put! ranks key id)
        (hash-put! members key [])
        (set! order (cons key order)))
      (hash-put! members representative (cons key (hash-ref members representative)))
      (hash-put! owners key representative)))
  (if state
    (let (count (vector-length keys))
      (for ((key (in-vector keys)) (node (in-range count)))
        (let (id (fx- (fx- (u32vector-ref state node) count) 1))
          (add-owner key id))))
    (for (key keys)
      (let (id (hash-ref owners key)) (add-owner key id))))
  (let (groups (for/collect (representative (reverse order))
                (let (group (reverse (hash-ref members representative)))
                  (hash-put! members representative (cons (length group) group)) group)))
    (values groups members ranks)))

(def (partition spec) (capture-partition spec #f))
(def (partition-owned spec) (capture-partition spec #t))

(def (partition-admitted-rows source (owned? #f))
  (def table (make-hash-table-eq))
  (and (gc-table-route-current? table)
    (let* ((keys (%packed-rows-names source))
           (buckets (%packed-rows-buckets source))
           (offsets (%packed-rows-offsets source))
           (targets (%packed-rows-targets source))
           (edges (u32vector-length targets))
           (index (make-compact-graph keys (make-ordinal-capture buckets table)
                    offsets targets (%packed-rows-direction source)))
           (reads (ordinal-row-reader keys buckets table (interface-instance-object table)
                    #t (cut %decode-ordinal-row keys offsets targets <>))))
      ;; Discovery and the independent certificate both run on the borrowed
      ;; arrays. No author getter or structural capture is repeated.
      (if owned?
        (and (%ordinal-index-routes-current?) (%gc-scratch-routes-current?)
             (finish-ordinal-owned index buckets))
        (partition-captured keys reads edges (vector-length keys) edges index #f values #f #t)))))

;; The installed declaration owns the immutable ordinals. Neither an observer
;; nor a changed issuer may borrow the structural publication.
(def (%partition-admitted-owned spec)
  (let* ((source (%declared-row-source spec))
         (part (and (%packed-rows? source) (partition-admitted-rows source #t))))
    (when (and part (not (eq? source (%declared-row-source spec))))
      (error "declared graph source changed during capture"))
    part))

(def (capture-partition spec owned?)
  (def publication (%declared-row-source spec))
  (def (finish source part)
    (when (and source (not (eq? source (%declared-row-source spec))))
      (error "declared graph source changed during capture"))
    part)
  (def packed (and (%packed-rows? publication) (partition-admitted-rows publication owned?)))
  (if packed (finish publication packed)
    (let* ((source (and (vector? publication) publication))
           (keys (if source (%ref-owned-list spec 'keys) (.@ spec keys)))
           (declared (and source (eq? source (%declared-row-source spec)) source)))
      (finish declared
        (capture-partition-rows keys
          (lambda (key)
            (let (code (.call spec .code key)) (if code (.@ code reads) [])))
          owned? declared)))))
(def (capture-partition-rows keys read-owner owned? (declared-rows #f) (roster #f))
  ;; The encoding index admits symbols and uniqueness before any author.
  ;; Keep finite-list admission here, then own the roster; do not build a
  ;; second duplicate table (empty_owner_index_admits_exactly_nodup).
  (unless (list? keys) (error "distinct finite component keys required"))
  (def admitted
    (and owned? roster (%ordinal-index-routes-current?) (%gc-scratch-routes-current?)
         (let (positions (%roster-cold-index roster keys))
           (and positions (not (procedure? positions))
                (standard-symbol-table-writes? positions) (%standard-symbol-table-lookup? positions)
                positions))))
  ;; Own the admitted roster before the first independent author callback.
  ;; The public cold path can use the same private ordered vector for owner
  ;; admission, CSR naming and certificate traversal. The published revision
  ;; path still gives own-partition its original list.
  ;; Declared rows already address owners by ordinal. Opaque sources retain
  ;; the existing size-based admission policy.
  (set! keys (if (and (not owned?) (or declared-rows (>= (length keys) 4194304)))
               (list->vector keys)
               (if admitted keys (append keys []))))
  (let-values (((reads index declared-edges captured-edges)
                 (capture-graph keys read-owner (not admitted) 4294967295 (and (not admitted) 'adjacent)
                   owned? #t declared-rows admitted)))
    (if (and admitted index)
      (finish-ordinal-owned index #f roster declared-edges)
      (let (complete
             (if owned?
               (let ((positions (or admitted (and index (compact-graph-positions index))))
                     (direction (and index (compact-graph-direction index))))
                 (lambda (part inverse cycle?)
                   (own-partition keys reads positions direction part inverse cycle? (and admitted roster))))
               values))
        (partition-captured keys reads captured-edges (capture-roster-length keys)
          declared-edges index owned? complete owned? (and declared-rows #t))))))


;; Compute SCCs from KEYS and validated READS. VALIDATION-OWNERS and
;; DECLARED-EDGES report the work already spent capturing those rows.
(def (partition-captured keys reads captured-edges validation-owners declared-edges
                         (index #f) (owned? #f) (complete values) (retain-inverse? #f)
                         (declared? #f))
  (if (and (not owned?) index (vector? keys) (eq? keys (compact-graph-names index)))
    (let* ((count (vector-length keys))
           (capture (compact-graph-positions index))
           (direction (compact-graph-direction index))
           (ordinal? (and (not retain-inverse?) (not (zero? direction))
                          (ordinal-capture? capture) (%gc-scratch-routes-current?)
                          (%ordinal-index-routes-current?)
                          (gc-table-route-current? (ordinal-capture-adapter capture)))))
      (if ordinal?
        (let* ((owners (make-hash-table-symbolic seed: (%graph-table-seed)))
               (backend (interface-instance-object owners))
               (members (make-hash-table-eq)))
          (if (and (standard-symbol-table-writes? owners) (%standard-symbol-table-lookup? owners)
                   (gc-table-route-current? members))
            (publish-ordinal-singletons keys reads (ordinal-capture-buckets capture)
              owners members validation-owners declared-edges (certify-ordinal-singletons index) complete)
            (begin
              (unless (symbol-hash-table? backend) (error "compact owner index representation"))
              (install-owner-storage! backend (raw-table-new backend count))
              (finish-compact-public keys reads index owners validation-owners declared-edges
                complete retain-inverse?))))
        (finish-compact-public keys reads index #f validation-owners declared-edges
          complete retain-inverse? (and declared? (not retain-inverse?) (ordinal-capture? capture) capture))))
    (let-values (((owners next component examined-edges finished popped) (discover keys reads captured-edges index)))
      ;; Normalization and certification do not retain packed capture buffers.
      (finish-partition keys reads validation-owners declared-edges
        owners next component examined-edges finished popped owned? complete retain-inverse?))))

(def (finish-compact-public keys reads index owners validation-owners declared-edges complete retain-inverse?
                            (capture #f))
  (def count (vector-length keys))
  (def ordinal? (and capture (> count 1)
    (%ordinal-index-routes-current?) (%gc-scratch-routes-current?)
    (gc-table-route-current? (ordinal-capture-adapter capture))))
  (def table (or owners
    (if ordinal? (make-hash-table-symbolic seed: (%graph-table-seed))
      (make-hash-table-symbolic size: count seed: (%graph-table-seed)))))
  (def stock? (and (standard-symbol-table-writes? table)
                   (%standard-symbol-table-lookup? table) (%gc-scratch-routes-current?)))
  (def result (compact-selected-discover index (and ordinal? stock?)))
  (if (and ordinal? stock?)
    (if (= (vector-ref result 2) 1)
      (let (certificate (certify-ordinal-whole index (vector-ref result 0) (vector-ref result 6)))
        (publish-ordinal-whole keys reads (ordinal-capture-buckets capture) table
          validation-owners declared-edges (u32vector-length (compact-graph-targets index))
          result complete certificate))
      (finish-ordinal-components keys reads index (ordinal-capture-buckets capture) table
        validation-owners declared-edges result complete))
    (let (state (and stock? (vector-ref result 0)))
      ;; A public miss exposes the owner table through Gerbil's error.
      (when ordinal?
        (let (backend (interface-instance-object table))
          (unless (symbol-hash-table? backend) (error "compact owner index representation"))
          (install-owner-storage! backend (raw-table-new backend count))))
      (if state
        (for (node (in-range count)) (compact-rank state count node))
        (compact-component-owners index result table))
      (finish-partition keys reads validation-owners declared-edges
        table (vector-ref result 1) (vector-ref result 2) (vector-ref result 3)
        (vector-ref result 4) (vector-ref result 5) #f complete retain-inverse? state))))

(def (certify-ordinal-whole index labels (choices #f))
  (def count (vector-length (compact-graph-names index)))
  (cond
   ;; Discovery consumes the active links in the independent tour check
   ;; before overwriting every label with the same whole-component rank.
   ((eq? choices active-tour-evidence) 'tour)
   ((and choices
         (let valid ((node 0))
           (or (fx= node count)
               (and (fx= 0 (compact-rank labels count node)) (valid (fx+ node 1)))))
         (certify-ordinal-return index choices #f (u32vector count) (make-u8vector count 0)))
    'forest)
   (else (certify-ordinal-whole-transpose index labels) #f)))

;; Keep the independent transpose check for a missing or rejected witness.
(def (certify-ordinal-whole-transpose index labels)
  (def keys (compact-graph-names index))
  (def count (vector-length keys))
  (def offsets (compact-graph-offsets index))
  (def targets (compact-graph-targets index))
  (def incoming (make-u32vector (fx+ count 1) 0))
  (for (node (in-range count))
    (unless (fx= 0 (compact-rank labels count node))
      (error "invalid whole SCC label" (vector-ref keys node))))
  ;; Count into the start cells. After prefix summing, each cell holds an
  ;; exclusive end. Filling backwards moves it to the final start.
  (def edge-count (u32vector-length targets))
  (for (at (in-range edge-count))
    (def target (u32vector-ref targets at))
    (u32vector-set! incoming target (fx+ 1 (u32vector-ref incoming target))))
  (let prefix ((node 0) (end 0))
    (if (fx= node count)
      (u32vector-set! incoming count end)
      (let (next (fx+ end (u32vector-ref incoming node)))
        (u32vector-set! incoming node next)
        (prefix (fx+ node 1) next))))
  (def sources (make-u32vector edge-count))
  (let fill ((node (fx- count 1)))
    (unless (fx< node 0)
      (let row ((at (u32vector-ref offsets node)) (end (u32vector-ref offsets (fx+ node 1))))
        (when (fx< at end)
          (let* ((target (u32vector-ref targets at)) (dst (fx- (u32vector-ref incoming target) 1)))
            (u32vector-set! incoming target dst)
            (u32vector-set! sources dst node)
            (row (fx+ at 1) end))))
      (fill (fx- node 1))))
  (def marks (make-u8vector count 0))
  (def pending (make-u32vector count))
  (def (span starts ends flag)
    (u32vector-set! pending 0 0)
    (u8vector-set! marks 0 (fxior (u8vector-ref marks 0) flag))
    (let visit ((read 0) (end 1))
      (unless (fx= read end)
        (let (node (u32vector-ref pending read))
          (let row ((at (u32vector-ref starts node))
                    (last (u32vector-ref starts (fx+ node 1))) (next end))
            (if (fx= at last)
              (visit (fx+ read 1) next)
              (let* ((dep (u32vector-ref ends at)) (seen (u8vector-ref marks dep)))
                (if (fx= (fxand seen flag) 0)
                  (begin
                    (u8vector-set! marks dep (fxior seen flag))
                    (u32vector-set! pending next dep)
                    (row (fx+ at 1) last (fx+ next 1)))
                  (row (fx+ at 1) last next)))))))))
  (span offsets targets 1)
  (span incoming sources 2)
  (for (node (in-range count))
    (unless (fx= (u8vector-ref marks node) 3)
      (error "invalid SCC spanning certificate" (vector-ref keys node)))))

(def (ordinal-spans offsets targets ranks roots sizes marks span-groups internal-count)
  (def count (u32vector-length ranks))
  (def components (u32vector-length roots))
  (def incoming (make-u32vector (fx+ count 1) 0))
  (def sources (make-u32vector internal-count))
  (def (internal-row node visit)
    (def rank (u32vector-ref ranks node))
    (when (fx= (u8vector-ref span-groups rank) 1)
      (let row ((at (u32vector-ref offsets node)) (end (u32vector-ref offsets (fx+ node 1))))
        (when (fx< at end)
          (let (target (u32vector-ref targets at))
            (when (fx= rank (u32vector-ref ranks target)) (visit target)))
          (row (fx+ at 1) end)))))
  (for (node (in-range count))
    (internal-row node (lambda (target)
      (u32vector-set! incoming target (fx+ (u32vector-ref incoming target) 1)))))
  (let prefix ((node 0) (end 0))
    (if (fx= node count)
      (u32vector-set! incoming count end)
      (let (next (fx+ end (u32vector-ref incoming node)))
        (u32vector-set! incoming node next)
        (prefix (fx+ node 1) next))))
  (let fill ((node (fx- count 1)))
    (unless (fx< node 0)
      (internal-row node (lambda (target)
        (let (dst (fx- (u32vector-ref incoming target) 1))
          (u32vector-set! incoming target dst)
          (u32vector-set! sources dst node))))
      (fill (fx- node 1))))
  (def pending (make-u32vector
    (for/fold (largest 0) (rank (in-range components))
      (if (fx= (u8vector-ref span-groups rank) 1)
        (fxmax largest (u32vector-ref sizes rank)) largest))))
  (u8vector-fill! marks 0)
  (def (span rank starts ends flag)
    (def root (u32vector-ref roots rank))
    (u32vector-set! pending 0 root)
    (u8vector-set! marks root (fxior (u8vector-ref marks root) flag))
    (let visit ((read 0) (end 1))
      (unless (fx= read end)
        (let (node (u32vector-ref pending read))
          (let row ((at (u32vector-ref starts node))
                    (last (u32vector-ref starts (fx+ node 1))) (next end))
            (if (fx= at last)
              (visit (fx+ read 1) next)
              (let* ((dep (u32vector-ref ends at)) (seen (u8vector-ref marks dep)))
                (if (and (fx= rank (u32vector-ref ranks dep)) (fx= (fxand seen flag) 0))
                  (begin
                    (u8vector-set! marks dep (fxior seen flag))
                    (u32vector-set! pending next dep)
                    (row (fx+ at 1) last (fx+ next 1)))
                  (row (fx+ at 1) last next)))))))))
  (for (rank (in-range components))
    (when (fx= (u8vector-ref span-groups rank) 1)
      (span rank offsets targets 1)
      (span rank incoming sources 2))))

;; Each non-root choice names one real outgoing edge. Mark a chain before
;; following it, and finalize the chain only after it reaches its group root
;; or a finalized suffix. A pending mark belongs to the current chain.
(def (certify-ordinal-return index choices ranks sizes marks (span-groups #f))
  (let/cc reject
    (def count (vector-length (compact-graph-names index)))
    (def offsets (compact-graph-offsets index))
    (def targets (compact-graph-targets index))
    (def groups (u32vector-length sizes))
    (def roots (make-u32vector groups count))
    (def narrow? (u8vector? choices))
    (def missing (if narrow? 255 4294967295))
    (def (choice node) (if narrow? (u8vector-ref choices node) (u32vector-ref choices node)))
    (def (rank node) (if ranks (u32vector-ref ranks node) 0))
    (defrule (span? group)
      (if span-groups (fx= (u8vector-ref span-groups group) 1)
        (fx> (u32vector-ref sizes group) 1)))
    (for (node (in-range count))
      (def group (rank node))
      (when (and (span? group) (fx= (choice node) missing))
        (unless (fx= (u32vector-ref roots group) count) (reject #f))
        (u32vector-set! roots group node)
        (u8vector-set! marks node 2)))
    (for (node (in-range count))
      (when (and (span? (rank node)) (fx= (u8vector-ref marks node) 0))
        (let follow ((at node))
          (case (u8vector-ref marks at)
            ((0)
             (let* ((start (u32vector-ref offsets at))
                    (end (u32vector-ref offsets (fx+ at 1)))
                    (slot (choice at)))
               (unless (fx< slot (fx- end start)) (reject #f))
               (let (target (u32vector-ref targets (fx+ start slot)))
                 (unless (fx= (rank at) (rank target)) (reject #f))
                 (u8vector-set! marks at 1)
                 (follow target))))
            ((1) (reject #f))
            (else
             (let settle ((at node))
               (when (fx= (u8vector-ref marks at) 1)
                 (u8vector-set! marks at 2)
                 (settle (u32vector-ref targets (fx+ (u32vector-ref offsets at) (choice at)))))))))))
    (def pending (make-u32vector
      (for/fold (largest 0) (group (in-range groups))
        (if (span? group) (fxmax largest (u32vector-ref sizes group)) largest))))
    ;; The forward walk starts at each DFS leader. Group/member queries
    ;; still use the existing first owner in declaration order.
    (for (group (in-range groups))
      (def size (u32vector-ref sizes group))
      (def root (u32vector-ref roots group))
      (when (span? group)
        (unless (fx< root count) (reject #f))
        (u32vector-set! pending 0 root)
        (u8vector-set! marks root 3)
        (let walk ((read 0) (write 1))
          (if (fx= read write)
            (unless (fx= write size) (reject #f))
            (let (node (u32vector-ref pending read))
              (let row ((at (u32vector-ref offsets node))
                        (end (u32vector-ref offsets (fx+ node 1))) (write write))
                (if (fx= at end)
                  (walk (fx+ read 1) write)
                  (let (target (u32vector-ref targets at))
                    (if (and (fx= (rank target) group) (fx= (u8vector-ref marks target) 2))
                      (begin
                        (u8vector-set! marks target 3)
                        (u32vector-set! pending write target)
                        (row (fx+ at 1) end (fx+ write 1)))
                      (row (fx+ at 1) end write))))))))))
    #t))

;; Check every original cross-group edge. An internal functional group
;; needs only a closed tour. A branching group can use the return choices.
(def (certify-ordinal-components index ranks roots sizes (choices #f))
  (def keys (compact-graph-names index))
  (def count (vector-length keys))
  (def components (u32vector-length roots))
  (def offsets (compact-graph-offsets index))
  (def targets (compact-graph-targets index))
  (def span-groups (make-u8vector components 0))
  (def internal-count 0)
  (def span-edges 0)
  (def singletons 0)
  (def first-bad #f)
  (def bad-provider #f)
  (for (node (in-range count))
    (def rank (u32vector-ref ranks node))
    (def singleton? (fx= (u32vector-ref sizes rank) 1))
    (def start (u32vector-ref offsets node))
    (def stop (u32vector-ref offsets (fx+ node 1)))
    (if singleton? (set! singletons (fx+ singletons 1))
      (set! span-edges (fx+ span-edges (fx- stop start))))
    (let scan ((at start) (internal 0))
      (if (fx= at stop)
        (unless singleton?
          (set! internal-count (fx+ internal-count internal))
          (unless (fx= internal 1) (u8vector-set! span-groups rank 1)))
        (let* ((dep (u32vector-ref targets at)) (provider (u32vector-ref ranks dep)))
          (cond
           ((fx= rank provider) (scan (fx+ at 1) (fx+ internal 1)))
           (else
            (unless (or first-bad (fx< provider rank))
              (set! first-bad node)
              (set! bad-provider dep))
            (scan (fx+ at 1) internal)))))))
  ;; A unique successor at each member makes the first return to the root
  ;; a simple cycle. Its length must agree with the independently counted
  ;; rank size, even when the proposed rank contains other cycles.
  (def (closed-tour-rows root rank size)
    (let walk ((node root) (left size) (rows 0))
      (cond
       ((fx= left 0) (and (fx= node root) rows))
       ((and (fx= node root) (not (fx= left size))) #f)
       (else
        (let* ((start (u32vector-ref offsets node))
               (stop (u32vector-ref offsets (fx+ node 1)))
               (rows (fx+ rows (fx- stop start))))
          (let next ((at start))
            (let (dep (u32vector-ref targets at))
              (if (fx= (u32vector-ref ranks dep) rank)
                (walk dep (fx- left 1) rows)
                (next (fx+ at 1))))))))))
  (let-values (((tour-nodes tour-rows span-count)
                (let certify ((rank 0) (nodes 0) (rows 0) (spans 0))
                  (if (fx= rank components) (values nodes rows spans)
                    (let ((size (u32vector-ref sizes rank)) (next (fx+ rank 1)))
                      (if (fx= size 1) (certify next nodes rows spans)
                        (let (covered (and (fx= (u8vector-ref span-groups rank) 0)
                                            (closed-tour-rows (u32vector-ref roots rank) rank size)))
                          (if covered
                            (certify next (fx+ nodes size) (fx+ rows covered) spans)
                            (begin
                              (u8vector-set! span-groups rank 1)
                              (certify next nodes rows (fx+ spans 1)))))))))))
    (let* ((span-nodes (fx- (fx- count singletons) tour-nodes))
           (marks (and (fx> span-count 0) (make-u8vector count 0)))
           (forest? (and marks choices (certify-ordinal-return index choices ranks sizes marks span-groups)))
           (reverse-edges (if (or (not marks) forest?) 0 (fx- internal-count tour-nodes))))
      (def (refuse-quotient)
        (error "invalid SCC quotient certificate" (vector-ref keys first-bad) (vector-ref keys bad-provider)))
      (cond
       ((and marks (not forest?))
        (ordinal-spans offsets targets ranks roots sizes marks span-groups reverse-edges)
        ;; Without complete coverage, retain source order and report spanning
        ;; before quotient failure at the same owner.
        (for (node (in-range count))
          (when (and (fx= (u8vector-ref span-groups (u32vector-ref ranks node)) 1)
                     (not (fx= (u8vector-ref marks node) 3)))
            (error "invalid SCC spanning certificate" (vector-ref keys node)))
          (when (eqv? node first-bad) (refuse-quotient))))
       (first-bad (refuse-quotient)))
      (values (fx+ tour-nodes (fx* 2 span-nodes))
        (fx+ tour-nodes (fx+ (fx- span-edges tour-rows)
                            (if forest? (fx- span-nodes span-count) reverse-edges)))
        singletons reverse-edges))))

(def (certified-ordinal-components index result)
  (def keys (compact-graph-names index))
  (def count (vector-length keys))
  (def components (vector-ref result 2))
  (def ranks (vector-ref result 0))
  (def roots (make-u32vector components count))
  (def sizes (make-u32vector components 0))
  (def represented 0)
  ;; Retire the discovery labels into their zero-based quotient ranks in
  ;; place. A second full owner map is unnecessary.
  (for (node (in-range count))
    (def rank (compact-rank ranks count node))
    (unless (fx< rank components) (error "invalid compact SCC rank" (vector-ref keys node)))
    (u32vector-set! ranks node rank)
    (def size (u32vector-ref sizes rank))
    (when (fx= size 0)
      (u32vector-set! roots rank node)
      (set! represented (fx+ represented 1)))
    (u32vector-set! sizes rank (fx+ size 1)))
  (unless (fx= represented components) (error "empty compact SCC rank"))
  (def evidence (vector-ref result 6))
  (defvalues (span-buckets span-edges singletons reverse-count)
    (if (eq? evidence active-tour-evidence)
      (values count count 0 0)
      (certify-ordinal-components index ranks roots sizes evidence)))
  (values ranks roots sizes span-buckets span-edges singletons reverse-count))

;; Supply the existing reverse index from immutable ordinal rows. The
;; sparse index fork continues to own edits to individual reader buckets.
(def (dense-ordinal-backward keys offsets targets)
  (def count (vector-length keys))
  (def incoming (make-u32vector (fx+ count 1) 0))
  (def readers (make-u32vector (u32vector-length targets)))
  (let tally ((at 0))
    (unless (fx= at (u32vector-length targets))
      (let (provider (u32vector-ref targets at))
        (u32vector-set! incoming provider (fx+ (u32vector-ref incoming provider) 1))
        (tally (fx+ at 1)))))
  (let prefix ((node 0) (end 0))
    (if (fx= node count)
      (u32vector-set! incoming node end)
      (let (next (fx+ end (u32vector-ref incoming node)))
        (u32vector-set! incoming node next)
        (prefix (fx+ node 1) next))))
  ;; Each bucket reads in the same order as consing sources in own-partition.
  (let fill ((node 0))
    (unless (fx= node count)
      (let row ((at (u32vector-ref offsets node))
                (end (u32vector-ref offsets (fx+ node 1))))
        (unless (fx= at end)
          (let* ((provider (u32vector-ref targets at))
                 (dst (fx- (u32vector-ref incoming provider) 1)))
            (u32vector-set! incoming provider dst)
            (u32vector-set! readers dst node)
            (row (fx+ at 1) end))))
      (fill (fx+ node 1))))
  (cut %decode-ordinal-row keys incoming readers <>))

;; Most narrow rows have at most one reader. Keep the latest source ordinal
;; inline and spill only additional readers, with the latest reader first.
;; Bound the number of spill entries before switching to the dense CSR base.
(def (sparse-ordinal-backward keys offsets targets)
  (let/cc decline
    (def count (vector-length keys))
    (def latest (make-u32vector count count))
    (def remaining (fxmax 4 (fxquotient count 32)))
    (def spill #f)
    (let fill ((node 0))
      (unless (fx= node count)
        (let row ((at (u32vector-ref offsets node))
                  (end (u32vector-ref offsets (fx+ node 1))))
          (unless (fx= at end)
            (let* ((provider (u32vector-ref targets at))
                   (prior (u32vector-ref latest provider)))
              (unless (fx= prior count)
                (when (fx= remaining 0) (decline #f))
                (set! remaining (fx- remaining 1))
                (unless spill (set! spill (make-gc-table 0 gc-hash-table::t)))
                (gc-table-set! spill provider
                  (cons (vector-ref keys prior) (gc-table-ref spill provider []))))
              (u32vector-set! latest provider node)
              (row (fx+ at 1) end))))
        (fill (fx+ node 1))))
    (lambda (provider)
      (let (reader (u32vector-ref latest provider))
        (if (fx= reader count) []
          (cons (vector-ref keys reader)
            (if spill (list-copy (gc-table-ref spill provider [])) [])))))))

(def (ordinal-backward keys offsets targets project)
  (project (or (sparse-ordinal-backward keys offsets targets)
               (dense-ordinal-backward keys offsets targets))))

(def (finish-ordinal-owned index buckets (roster #f) (declared-edges #f))
  (def keys (compact-graph-names index))
  (def count (vector-length keys))
  (def offsets (compact-graph-offsets index))
  (def targets (compact-graph-targets index))
  (def edges (u32vector-length targets))
  (def direction (compact-graph-direction index))
  (def result (compact-selected-discover index #t))
  (defvalues (ranks roots sizes span-buckets span-edges singletons reverse-count)
    (certified-ordinal-components index result))
  (def components (u32vector-length roots))
  (def (position key)
    (and (symbol? key)
         (if buckets (%ordinal-bucket-ref buckets key) (%roster-position roster key))))
  (def (project read)
    (%index (lambda (key default)
      (let (node (position key))
        (if node (read node) default)))))
  (def (rank node) (u32vector-ref ranks node))
  (def forward (project (cut %decode-ordinal-row keys offsets targets <>)))
  (def backward (ordinal-backward keys offsets targets project))
  (def owner (project (lambda (node) (vector-ref keys (u32vector-ref roots (rank node))))))
  ;; A second entry into the same rank identifies a fragmented source
  ;; group. One-run groups can derive every member from their root and size.
  (def fragmented
    (and (fx> components 1) (fx< components count)
         (let scan ((node 0) (previous -1) (flags #f))
           (if (fx= node count) flags
             (let (id (rank node))
               (if (or (fx= id previous) (fx= node (u32vector-ref roots id)))
                 (scan (fx+ node 1) id flags)
                 (let (flags (or flags (make-u8vector components 0)))
                   (u8vector-set! flags id 1)
                   (scan (fx+ node 1) id flags))))))))
  (defrule (fragmented? id) (and fragmented (fx= (u8vector-ref fragmented id) 1)))
  (def links (and fragmented (make-u32vector count)))
  (when links
    (let (heads (make-u32vector components count))
      (let link ((node (fx- count 1)))
        (unless (fx< node 0)
          (let (id (rank node))
            (when (fragmented? id)
              (u32vector-set! links node (u32vector-ref heads id))
              (u32vector-set! heads id node)))
          (link (fx- node 1))))))
  (def (visit-members node id visit)
    (if (fragmented? id)
      (let walk ((at node))
        (unless (fx= at count)
          (visit (vector-ref keys at))
          (walk (u32vector-ref links at))))
      (let ((stop (fx+ node (u32vector-ref sizes id))))
        (let walk ((at node))
          (unless (fx= at stop)
            (visit (vector-ref keys at))
            (walk (fx+ at 1))))))
    #t)
  (def (member-list node id)
    (if (fragmented? id)
      (with-list-builder (add) (visit-members node id add))
      (let build ((end (fx+ node (u32vector-ref sizes id))) (members []))
        (if (fx= end node) members
          (let (at (fx- end 1))
            (build at (cons (vector-ref keys at) members)))))))
  (def members (project (lambda (node)
    (let (id (rank node))
      (and (fx= node (u32vector-ref roots id))
           (cons (u32vector-ref sizes id)
             (lambda (visit)
               (if visit (visit-members node id visit) (member-list node id)))))))))
  ;; A fixed arity keeps the published lookup from collecting its arguments.
  ;; Size accepts any member. Listing and visiting require its root.
  (def (member key request)
    (let* ((node (position key)) (id (and node (rank node))))
      (and id
           (if (eq? request #t) (u32vector-ref sizes id)
             (and (fx= node (u32vector-ref roots id))
                  (if request (visit-members node id request) (member-list node id)))))))
  ;; When the certified root array is small, enumerate just those ordinals
  ;; in source order. Every call constructs fresh member lists.
  (def groups
    (and (fx< components count) (fx<= components 4096)
         (lambda ()
           (with-list-builder (add)
             (for (root (list-sort < (u32vector->list roots)))
               (add (member-list root (rank root))))))))
  ;; The rank is issued only after independent coverage and the original
  ;; boundary-edge checks. Its address is stable across row replacements.
  (owned-snapshot
    (make-owned-partition (or roster (%ordinal-roster keys buckets)) forward backward owner members
      (cond ((positive? direction) direction)
            ((and (fx= components 1) (fx> count 1) (fx= edges count)) 'cycle)
            (else #f)) #f
      (and (zero? direction)
           (lambda (key) (let (node (position key)) (and node (rank node))))))
    (work-receipt count (or declared-edges edges) (vector-ref result 1) (vector-ref result 3)
      (vector-ref result 4) (vector-ref result 5) count components span-buckets span-edges
      edges singletons reverse-count 0 0) groups member))

(def (finish-ordinal-components keys reads index buckets owners validation-owners declared-edges result complete)
  (def count (vector-length keys))
  (def components (vector-ref result 2))
  (defvalues (ranks roots sizes span-buckets span-edges singletons reverse-count)
    (certified-ordinal-components index result))
  (def find-owner (ordinal-owner-reader keys buckets owners #f
    (lambda (node) (vector-ref keys (u32vector-ref roots (u32vector-ref ranks node))))))
  (def members (make-hash-table-eq))
  (defvalues (member groups) (ordinal-component-members keys buckets members ranks roots sizes))
  (def edges (u32vector-length (compact-graph-targets index)))
  (complete
    (make-%partition groups (cut find-owner <>) (cut reads <>) member
      (work-receipt validation-owners declared-edges count (vector-ref result 3)
        (vector-ref result 4) (vector-ref result 5) count components span-buckets span-edges
        edges singletons reverse-count 0 0) find-owner #f)))

(def (certify-ordinal-singletons index)
  ;; Direction selects a proposed ranking. Check the independently captured
  ;; edges in owner and row order before materializing the public groups.
  (def keys (compact-graph-names index))
  (def offsets (compact-graph-offsets index))
  (def targets (compact-graph-targets index))
  (def forward? (zero? (fxand (compact-graph-direction index) 1)))
  (for (owner (in-range (vector-length keys)))
    (let visit ((at (u32vector-ref offsets owner)) (end (u32vector-ref offsets (fx+ owner 1))))
      (unless (fx= at end)
        (let (provider (u32vector-ref targets at))
          (when (if forward? (fx< provider owner) (fx< owner provider))
            (error "invalid SCC quotient certificate" (vector-ref keys owner) (vector-ref keys provider)))
          (visit (fx+ at 1) end)))))
  (u32vector-length targets))

(def (install-owner-storage! backend prepared)
  (&raw-table-table-set! backend (&raw-table-table prepared))
  (&raw-table-count-set! backend (&raw-table-count prepared))
  (&raw-table-free-set! backend (&raw-table-free prepared)))

(def (ordinal-owner-reader keys buckets table (representative #f) (owner-at #f))
  (def backend (interface-instance-object table))
  (def pending? #t)
  (def retirement (make-mutex 'partition-owners))
  (lambda (key (optional? #f))
    (def stock? (and pending? (%standard-symbol-table-lookup? table)))
    (def ordinal (and stock? (symbol? key) (%ordinal-bucket-ref buckets key)))
    (cond
     (ordinal (if owner-at (owner-at ordinal) (or representative key)))
     ((and stock? optional?) #f)
     (else
      ;; A strict miss can expose the table. Populate the original adapter
      ;; with the original seed and source insertion order before delegation.
      (when pending?
        (with-lock retirement
          (lambda ()
            (when pending?
              (let (prepared (raw-table-new backend (vector-length keys)))
                (for ((owner (in-vector keys)) (i (in-range (vector-length keys))))
                  (symbolic-table-set! prepared owner (if owner-at (owner-at i) (or representative owner))))
                (install-owner-storage! backend prepared)
                (set! pending? #f))))))
      (if optional? (hash-get table key) (hash-ref table key))))))

(def (publish-ordinal-whole keys reads buckets owners validation-owners declared-edges edges result complete certificate)
  (def count (vector-length keys))
  (def root (vector-ref keys 0))
  (def find-owner (ordinal-owner-reader keys buckets owners root))
  (def members (make-hash-table-eq))
  (def backend (interface-instance-object members))
  (def lock (make-mutex 'partition-members))
  (def ordered #f)
  (def pending? #t)
  (def (ordered!)
    (unless ordered (set! ordered (list (vector->list keys))))
    ordered)
  (def (groups)
    (or ordered (with-lock lock ordered!)))
  (def (member key size?)
    (if (and pending? (eq? backend (%gc-table-route-backend members)))
      (and (eq? key root) (if size? count (car (groups))))
      (begin
        (when pending?
          (with-lock lock
            (lambda ()
              (when pending?
                (gc-table-set! backend root (cons count (car (ordered!))))
                (set! pending? #f)))))
        (let (entry (hash-get members key))
          (and entry (if size? (car entry) (cdr entry)))))))
  (complete
    (make-%partition groups (cut find-owner <>) (cut reads <>) member
      (work-receipt validation-owners declared-edges count (vector-ref result 3)
        (vector-ref result 4) (vector-ref result 5) count 1
        (if (eq? certificate 'tour) count (* 2 count))
        (case certificate ((tour) count) ((forest) (+ edges (1- count))) (else (* 2 edges)))
        edges 0 (if certificate 0 edges) 0 0) find-owner #f)))

(def (ordinal-component-members keys buckets table ranks roots sizes)
  (def count (vector-length keys))
  (def backend (interface-instance-object table))
  (def retirement (make-mutex 'partition-members))
  (def next #f)
  (def ordered #f)
  (def pending? #t)
  (def absent (gensym 'absent-member))
  (def (group-at! key root rank)
    (or (gc-table-ref backend key #f)
        (let (size (u32vector-ref sizes rank))
          (when (and (fx> size 1) (not next))
            (let ((links (make-u32vector count))
                  (heads (make-u32vector (u32vector-length roots) count)))
              (let link ((node (fx- count 1)))
                (unless (fx< node 0)
                  (let (id (u32vector-ref ranks node))
                    (u32vector-set! links node (u32vector-ref heads id))
                    (u32vector-set! heads id node)
                    (link (fx- node 1)))))
              (set! next links)))
          (def group
            (if (fx= size 1) (list key)
              (let collect ((node root) (members []))
                (if (fx= node count) (reverse! members)
                  (collect (u32vector-ref next node) (cons (vector-ref keys node) members))))))
          (def entry (cons size group))
          (gc-table-set! backend key entry)
          entry)))
  (def (ordered!)
    (unless ordered
      (set! ordered (with-list-builder (add)
        (for (node (in-range count))
          (def rank (u32vector-ref ranks node))
          (when (fx= node (u32vector-ref roots rank))
            (add (cdr (group-at! (vector-ref keys node) node rank)))))))
      (set! next #f))
    ordered)
  (def (groups)
    (or ordered (with-lock retirement ordered!)))
  (def (member key size?)
    (def decision
      (with-lock retirement
        (lambda ()
          (cond
           ((not pending?) #f)
           ((eq? backend (%gc-table-route-backend table))
            (let* ((node (and (symbol? key) (%ordinal-bucket-ref buckets key)))
                   (rank (and node (u32vector-ref ranks node))))
              (cond ((not (and rank (fx= node (u32vector-ref roots rank)))) absent)
                    (size? (u32vector-ref sizes rank))
                    (else (cdr (group-at! key node rank))))))
           (else (ordered!) (set! pending? #f) #f)))))
    (cond ((eq? decision absent) #f)
          (decision decision)
          (else (let (entry (hash-get table key))
            (and entry (if size? (car entry) (cdr entry)))))))
  (values member groups))

(def (ordinal-singleton-members keys buckets table)
  (def backend (interface-instance-object table))
  (def count (vector-length keys))
  (def cells #f)
  (def ordered #f)
  (def pending? #t)
  (def retirement (make-mutex 'partition-members))
  (def absent-member (gensym 'absent-member))
  (def (ensure-cells!)
    (unless cells
      (let (prepared (make-vector count #f))
        (gc-table-for-each backend
          (lambda (key entry)
            (vector-set! prepared (%ordinal-bucket-ref buckets key) (cdr entry))))
        (set! cells prepared))))
  (def (group-at i)
    (or (vector-ref cells i)
        (let (group (list (vector-ref keys i)))
          (vector-set! cells i group)
          group)))
  (def (sparse-group key)
    (let (entry (gc-table-ref backend key #f))
      (if entry (cdr entry)
        (let (group (list key))
          (gc-table-set! backend key (cons 1 group))
          group))))
  (def (table-member key size?)
    (let (entry (hash-get table key))
      (and entry (if size? (car entry) (cdr entry)))))
  (def (member key size?)
    (if (not pending?) (table-member key size?)
      (let (decision
            (with-lock retirement
              (lambda ()
                (cond
                 ((not pending?) #f)
                 ((eq? backend (%gc-table-route-backend table))
                  ;; A stock miss stays private, including when size is asked.
                  (let (i (and (symbol? key) (%ordinal-bucket-ref buckets key)))
                    (cond ((not i) absent-member)
                          (size? 1)
                          (cells (group-at i))
                          (else (sparse-group key)))))
                 (else
                  (ensure-cells!)
                  (restore-ordinal-rows! keys backend (lambda (i) (cons 1 (group-at i))))
                  (set! pending? #f)
                  (when ordered (set! cells #f))
                  #f)))))
        (cond ((eq? decision absent-member) #f)
              (decision decision)
              (else (table-member key size?))))))
  (def (groups)
    (or ordered
        (with-lock retirement
          (lambda ()
            (unless ordered
              (ensure-cells!)
              (set! ordered
                (let build ((end count) (groups []))
                  (if (zero? end) groups
                    (let (i (fx- end 1))
                      (build i (cons (group-at i) groups))))))
              ;; Keep the ordered publication independent of later edits
              ;; made through the original member table.
              (unless pending? (set! cells #f)))
            ordered))))
  (values member groups))

(def (publish-ordinal-singletons keys reads buckets owners members validation-owners declared-edges quotient-edges complete)
  (def count (vector-length keys))
  (defvalues (find-member groups) (ordinal-singleton-members keys buckets members))
  (def find-owner (ordinal-owner-reader keys buckets owners))
  (complete
    (make-%partition groups (cut find-owner <>) (cut reads <>) find-member
      (work-receipt validation-owners declared-edges 0 0 0 0 count count
        0 0 quotient-edges count 0 count quotient-edges) find-owner #f)))

(def (finish-partition keys reads validation-owners declared-edges
                       owners next component examined-edges finished popped (owned? #f) (complete values)
                       (retain-inverse? #f) (rank-state #f))
    (def read-row (if (procedure? reads) (cut reads <>) (cut hash-ref reads <>)))
    (def forward-row (if (procedure? reads) (cut reads <> #t) (cut hash-ref reads <> [])))
    (let-values (((groups members ranks) (normalize keys owners owned? rank-state)))
      ;; Independent ComponentWitness certificate: all quotient edges, and two
      ;; within-group spanning walks. Singleton paths are reflexive. Reverse
      ;; rows retain only internal edges of nontrivial groups (Lean pruning law).
      (def whole? (and retain-inverse? (pair? keys) (pair? (cdr keys)) (null? (cdr groups))))
      (let ((reverse-reads (if whole? (make-hash-table-symbolic size: next seed: (%graph-table-seed))
                             (make-hash-table-eq)))
            (forward-seen (make-hash-table-eq)) (backward-seen (make-hash-table-eq))
            (certificate-buckets 0) (certificate-edges 0) (quotient-edges 0)
            (certificate-singletons 0) (reverse-edges 0) (quotient-error #f))
        (def cycle? whole?)
        (def (reverse-row key) (hash-ref reverse-reads key []))
        (def (span read seen root)
          (let walk ((pending (list root)))
            (unless (null? pending)
              (let ((key (car pending)) (rest (cdr pending)))
                (if (hash-key? seen key) (walk rest)
                  (let (row (read key))
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
            (def row (read-row key))
            (when (and cycle? (not (and (pair? row) (null? (cdr row)))))
              (set! cycle? #f))
            (for (dep row)
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
              (begin (span forward-row forward-seen root)
                     (span reverse-row backward-seen root)))))
        (for (key keys)
          (let* ((owner (hash-ref owners key)) (entry (hash-ref members owner)))
            (unless (and (eq? (hash-get ranks owner) 'covered)
                         (if (= (car entry) 1) (eq? key owner)
                           (and (hash-key? forward-seen key) (hash-key? backward-seen key))))
              (error "invalid SCC spanning certificate" key)))
          (when (and quotient-error (eq? key (car quotient-error)))
            (error "invalid SCC quotient certificate" key (cdr quotient-error))))
        (def result (make-%partition groups (cut hash-ref owners <>) read-row members
          (work-receipt validation-owners declared-edges (if (zero? finished) 0 next)
            examined-edges finished popped next component
            certificate-buckets certificate-edges quotient-edges certificate-singletons reverse-edges
            (if (zero? finished) next 0) (if (zero? finished) quotient-edges 0)) owners #f))
        (if retain-inverse? (complete result (and whole? reverse-reads) cycle?)
          (complete result)))))

;; Owned partition keeps the existing SCC result and only adds the indexes
;; required to revise that result without rereading a declaration.
(def absent-owned-entry (gensym 'absent-owned-entry))
(def (owned-snapshot owned work (groups #f) (member #f))
  (def (require-active! key)
    (when (and (owned-partition-retired? owned) (not (owned-active-owner owned key)))
      (raise-unbound-key partition-owner key)))
  (def (lookup index key)
    (unless (symbol? key) (error "component key must be a symbol" key))
    (require-active! key)
    (if (procedure? (%index-base index))
      (let (value (%index-ref index key absent-owned-entry))
        (if (eq? value absent-owned-entry) (raise-unbound-key partition-owner key) value))
      (%index-ref index key)))
  (make-%partition groups
    (cut lookup (owned-partition-owner owned) <>)
    (lambda (key) (list-copy (lookup (owned-partition-forward owned) key)))
    member work #f owned))

(def (own-partition keys reads captured-positions direction part (inverse #f) (certified-cycle? #f)
                       (roster #f))
  (def positions (or captured-positions (make-hash-table-symbolic seed: (%graph-table-seed))))
  (def backward (or inverse (make-hash-table-symbolic seed: (%graph-table-seed))))
  (def cycle? (if inverse certified-cycle?
                (and (pair? keys) (pair? (cdr keys)) (= (hash-length (%partition-members part)) 1))))
  (unless (and inverse captured-positions)
    (for ((key keys) (position (in-range (length keys))))
      (unless captured-positions (hash-put! positions key position))
      (def row (hash-ref reads key))
      (when (and cycle? (not (and (pair? row) (null? (cdr row)))))
        (set! cycle? #f))
      (unless inverse
        (for (provider row)
          (hash-put! backward provider (cons key (hash-ref backward provider [])))))))
  (owned-snapshot (make-owned-partition (or roster (%roster keys positions)) (%index reads) (%index backward)
                    (%index (%partition-owners part)) (%index (%partition-members part))
                    ;; Capture already authenticated both rank-direction bits.
                    ;; Carry that structural evidence instead of scanning again.
                    (cond (cycle? 'cycle)
                          ((and direction (positive? direction)) direction)
                          (else #f)) #f #f)
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
  (%roster-width (owned-partition-roster (%partition-owned part))))
(def (%partition-key-position part key)
  (or (%roster-position (owned-partition-roster (%partition-owned part)) key)
      (raise-unbound-key %partition-key-position key)))
(def (%partition-key-before part)
  (lambda (a b) (< (%partition-key-position part a) (%partition-key-position part b))))
(def (%partition-order-keys part keys)
  (list-sort (%partition-key-before part) keys))
(def (%partition-representatives part)
  (def owned (%partition-owned part))
  (def roster (owned-partition-roster owned))
  (if (and (eq? (owned-partition-shape owned) 'singletons) (not (owned-partition-retired? owned)))
    (%roster-keys roster)
    (with-list-builder (add)
      (%roster-for-each (lambda (key)
        (when (eq? key (owned-active-owner owned key)) (add key))) roster))))

;; Retire only vertices isolated in this exact, already repaired partition.
;; Keep ordinal and source-order storage borrowed from the predecessor.
(def (%isolated-partition-owner? part key)
  (let (old (%partition-owned part))
    (and old (symbol? key) (eq? key (owned-active-owner old key))
         (null? (%index-ref (owned-partition-forward old) key))
         (call/cc (lambda (return)
           (%for-each-reverse-bucket (lambda (_) (return #f))
             (%index-ref (owned-partition-backward old) key []))
           #t)))))
(def (%retire-partition-isolates prior keys (roster #f))
  (def old (and (partition? prior) (%partition-owned prior)))
  (unless (and old (list? keys)) (error "owned partition and finite retirements required"))
  (if (null? keys) prior
    (let ()
      (def owner (%index-fork (owned-partition-owner old)))
      (def members (%index-fork (owned-partition-members old)))
      (def prior-forward (owned-partition-forward old))
      (def prior-backward (owned-partition-backward old))
      (def forward #f)
      (def backward #f)
      (for (key keys)
        (unless (and (symbol? key) (eq? key (%index-ref owner key #f)))
          (error "component retirement requires an active isolated owner" key))
        (unless (null? (%index-ref (owned-partition-forward old) key))
          (error "component retirement still has providers" key))
        (%for-each-reverse-bucket
          (lambda (reader) (error "component retirement still has readers" key reader))
          (%index-ref (owned-partition-backward old) key []))
        (%index-retire! owner key)
        (%index-retire! members key)
        (when (%index-overridden? prior-forward key)
          (unless forward (set! forward (%index-fork prior-forward)))
          (%index-retire! forward key []))
        (when (%index-overridden? prior-backward key)
          (unless backward (set! backward (%index-fork prior-backward)))
          (%index-retire! backward key [])))
      (owned-snapshot
        (make-owned-partition (or roster (owned-partition-roster old))
          (or forward prior-forward) (or backward prior-backward) owner members
          (owned-partition-shape old) #t (owned-partition-ranks old))
        (if (and roster (partition-work prior))
          (.cc (partition-work prior) retired-owners: (length keys) roster-materialized: 0)
          (.o retired-owners: (length keys) roster-materialized: 0))))))

;; The predecessor inverse certifies that every surviving reader of a
;; retired provider supplies a replacement before author row capture.
(def (%check-partition-retirements prior removed codes)
  (def old (%partition-owned prior))
  (def removed-index (make-hash-table-eq))
  (def edited (make-hash-table-eq))
  (for (key removed)
    (unless (and (symbol? key) (owned-active-owner old key) (not (hash-key? removed-index key)))
      (error "conflicting or stale component membership contributions" key))
    (hash-put! removed-index key #t))
  (for (entry codes)
    (when (pair? entry) (hash-put! edited (car entry) #t)))
  (for (key removed)
    (%for-each-reverse-bucket
      (lambda (reader)
        (unless (or (hash-key? removed-index reader) (hash-key? edited reader))
          (error "component retirement still has an unedited reader" key reader)))
      (%index-ref (owned-partition-backward old) key []))))

;; The component source has already reserved these exact ordinals. Seed empty
;; rows and singleton membership before the existing replacement algorithm.
(def (%append-partition-owners prior roster names)
  (def old (%partition-owned prior))
  (def forward (%index-fork (owned-partition-forward old)))
  (def backward (%index-fork (owned-partition-backward old)))
  (def owner (%index-fork (owned-partition-owner old)))
  (def members (%index-fork (owned-partition-members old)))
  (for (key names)
    (%index-write! forward key [])
    (%index-write! backward key [])
    (%index-write! owner key key)
    (%index-write! members key (list 1 key)))
  (def shape (owned-partition-shape old))
  (owned-snapshot
    (make-owned-partition roster forward backward owner members
      (and (not (eq? shape 'cycle)) shape) (owned-partition-retired? old) #f)
    #f))

(def (revise-partition prior replacements quotient?: (quotient? #f))
  (def old (and (partition? prior) (%partition-owned prior)))
  (unless old (error "owned component partition required"))
  (unless (list? replacements) (error "finite component edit required"))
  (def roster (owned-partition-roster old))
  (def retired? (owned-partition-retired? old))
  (def (supported? key)
    (and (%roster-position roster key) (or (not retired?) (owned-active-owner old key))))
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
        (unless (and (pair? entry) (symbol? (car entry)) (supported? (car entry))
                     (list? (cdr entry)))
          (error "unsupported component row replacement" entry))
        (def key (car entry))
        (when (hash-key? seen key) (error "duplicate component row replacement" key))
        (hash-put! seen key #t)
        (let (owner-rank (and (positive? rank-mask) (%roster-position roster key)))
          (for (dep (cdr entry))
            (unless (and (symbol? dep) (supported? dep))
              (error "unsupported component read" key dep))
            (when (positive? rank-mask)
              (let (provider-rank (%roster-position roster dep))
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
  (def old-owner (owned-partition-owner old))
  (def old-members (owned-partition-members old))
  (def component-edge-checks 0)
  (def certified-rank (owned-partition-ranks old))
  ;; Within a certified rank, only additions inside a current component are
  ;; harmless. A strictly descending edge cannot be part of a merging cycle.
  (def merge-safe?
    (or ranked?
        (let (valid? #t)
          (hash-for-each
            (lambda (consumer providers)
              (for (provider providers)
                (when valid?
                  (set! component-edge-checks (1+ component-edge-checks))
                  (unless (or (eq? (%index-ref old-owner consumer) (%index-ref old-owner provider))
                              (and certified-rank (< (certified-rank provider) (certified-rank consumer))))
                    (set! valid? #f))))) add-forward)
          valid?)))
  (def retained-components?
    (and (not ranked?) merge-safe?
        (let (valid? #t)
          (hash-for-each
            (lambda (provider consumers)
              (hash-for-each
                (lambda (consumer _)
                  (when valid?
                    (set! component-edge-checks (1+ component-edge-checks))
                    (unless (or (eq? consumer provider)
                                (not (eq? (%index-ref old-owner consumer) (%index-ref old-owner provider))))
                      (set! valid? #f)))) consumers)) remove-backward)
          valid?)))
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
  (def deletion-only? (zero? (hash-length add-forward)))
  (def single-removal? (and (pair? roots) (null? (cdr roots)) deletion-only?))
  ;; One deletion breaks a certified functional cycle. Further deletions
  ;; preserve singleton components by edge inclusion.
  (def functional-cut? (and deletion-only? (positive? removed-edges)
                            (eq? (owned-partition-shape old) 'cycle)))
  (def single-owner (and single-removal? (not functional-cut?) (%index-ref old-owner (car roots))))
  ;; If no old groups can merge, only internal removals need recertification.
  ;; This includes mixed edits with certified descending boundary additions.
  (def split-only? (or deletion-only? (and certified-rank merge-safe?)))
  (def dirty-components
    (and split-only? (not functional-cut?) (not single-removal?)
         (not ranked?) (not retained-components?)
      (let (dirty (make-hash-table-symbolic))
        (hash-for-each
          (lambda (provider consumers)
            (def representative (%index-ref old-owner provider))
            (hash-for-each
              (lambda (consumer _)
                (when (and (not (eq? consumer provider))
                           (eq? representative (%index-ref old-owner consumer)))
                  (hash-put! dirty representative #t))) consumers)) remove-backward)
        dirty)))
  (def dirty-keys (and dirty-components (hash-keys dirty-components)))
  (def to (and (not ranked?) (not retained-components?) (not split-only?)
               (edit-region-walk roots forward add-forward forward-work)))
  (def from (and (not ranked?) (not retained-components?) (not split-only?)
                 (edit-region-walk roots backward add-backward backward-work)))
  (def (inside? key)
    (if single-removal? (eq? single-owner (%index-ref old-owner key))
      (and (hash-key? to key) (hash-key? from key))))
  (def region
    (cond ((or ranked? retained-components?) [])
          (functional-cut? [])
          (single-removal? (owned-member-list (%index-ref old-members single-owner)))
          (dirty-keys
           (match dirty-keys
             ([representative] (owned-member-list (%index-ref old-members representative)))
             (else
              (%partition-order-keys prior
                (with-list-builder (add)
                  (for (representative dirty-keys)
                    (for-each add (owned-member-list (%index-ref old-members representative)))))))))
          (else
           (let (smaller (if (< (hash-length to) (hash-length from)) to from))
             (%partition-order-keys prior (filter inside? (hash-keys smaller)))))))
  (def width (if functional-cut? (%roster-width roster) (length region)))
  (def whole? (and (pair? region) (= width (%roster-width roster))))
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
            (if (and whole? (not dirty-components))
              (let (size (length all))
                (set! induced-readers (+ induced-readers size))
                (set! edges (+ edges size))
                all)
              (filter (lambda (dep)
                (set! induced-readers (1+ induced-readers))
                (and (if dirty-components
                       (eq? (%index-ref old-owner key) (%index-ref old-owner dep))
                       (inside? dep))
                     (begin (set! edges (1+ edges)) #t))) all)))
          (hash-put! rows key row))
        (partition-captured region rows edges 0 0 #f #t))))
  ;; If the repair covers the entire graph, use the discovered native tables
  ;; as the new base. One sparse tree write per owner would only copy work.
  (def owner (cond ((or ranked? retained-components?) old-owner)
                   (functional-cut? (%roster-project roster identity))
                   (whole? (%index (%partition-owners local-part)))
                   (else (%index-fork old-owner))))
  (def members (cond ((or ranked? retained-components?) old-members)
                     (functional-cut? (%roster-project roster (lambda (key) (list 1 key))))
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
      (unless (if (and previous (procedure? (cdr previous)))
                 (and replacement (= (car replacement) (car previous))
                      (let/cc mismatch
                        (def remaining (cdr replacement))
                        (visit-owned-members previous
                          (lambda (key)
                            (unless (and (pair? remaining) (eq? key (car remaining))) (mismatch #f))
                            (set! remaining (cdr remaining))))
                        (null? remaining)))
                 (equal? replacement previous))
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
      (make-owned-partition roster next-forward next-backward owner members
        (cond (ranked? rank-mask)
              (functional-cut? 'singletons)
              ((null? roots) (owned-partition-shape old))
              ;; Membership preservation alone does not preserve a one-edge
              ;; cycle certificate: an internal chord changes its outdegree.
              (retained-components?
                (and (eq? (owned-partition-shape old) 'singletons) 'singletons))
              ((and cycle? (= (hash-length (%partition-members local-part)) 1)) 'cycle)
              (else #f)) retired?
        (and merge-safe? certified-rank))
      (.o edited-rows: (hash-length seen) changed-rows: (length roots)
      forward-buckets: (vector-ref forward-work 0) forward-edges: (vector-ref forward-work 1)
      reverse-buckets: (vector-ref backward-work 0) reverse-edges: (vector-ref backward-work 1)
      reverse-writes: (hash-length buckets) reverse-removals: removed-edges reverse-rewrite-edges: 0
      region-owners: width region-edge-visits: induced-readers owner-writes: owner-assignments
      retained-direction: (and ranked? rank-mask) rank-checks: rank-edge-checks
      retained-components: retained-components? component-checks: component-edge-checks
      member-writes: member-assignments rebased-owners: (if whole? width 0)
        projected-singletons: (if functional-cut? width 0)
        quotient-reader-edges: quotient-readers
        local: (and local-part (partition-work local-part)))
      (and (eq? members old-members) (%partition-groups prior))
      (and (eq? owner old-owner) (eq? members old-members) (%partition-members prior))))
  (if quotient?
    (values result (if functional-cut? 'all-representatives changed-groups)
      (cond (functional-cut? 'complete)
            ((or (pair? added) (pair? retired))
             (make-quotient-support (reverse added) (reverse retired)))
            (else #f)))
    result)))
