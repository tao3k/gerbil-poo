;;; Prepared traversal study over the actual private production index.
(extern namespace: clan/poo/strong-components
  capture-compact compact-graph-names compact-graph-positions compact-graph-offsets compact-graph-targets
  compact-discover compact-component-owners compact-discovery-result)

(def (compact-row graph key)
  (def node (hash-ref (compact-graph-positions graph) key))
  (def offsets (compact-graph-offsets graph))
  (def targets (compact-graph-targets graph))
  (def names (compact-graph-names graph))
  (for/collect (at (in-range (u32vector-ref offsets node) (u32vector-ref offsets (fx+ node 1))))
    (vector-ref names (u32vector-ref targets at))))

(def (compact-reachable graph root)
  ;; Current cursor/end live in loop arguments. Save a parent frame only when
  ;; entering a child: visited cross edges do not read/write frame storage.
  (def names (compact-graph-names graph))
  (def offsets (compact-graph-offsets graph))
  (def targets (compact-graph-targets graph))
  (def root-id (hash-ref (compact-graph-positions graph) root))
  (def count (vector-length names))
  (def first (u32vector-ref offsets root-id))
  (def last (u32vector-ref offsets (fx+ root-id 1)))
  (if (fx= first last) (list root)
    (let ((visited (make-u8vector count 0))
          (saved-cursors (make-u32vector count 0)) (saved-ends (make-u32vector count 0)))
      (u8vector-set! visited root-id 1)
      (let walk ((top 0) (cursor first) (end last) (seen (list root)))
        (if (fx< cursor end)
          (let ((dep (u32vector-ref targets cursor)) (next (fx+ cursor 1)))
            (if (fx= (u8vector-ref visited dep) 0)
              (begin
                (u8vector-set! visited dep 1)
                (u32vector-set! saved-cursors top next)
                (u32vector-set! saved-ends top end)
                (walk (fx+ top 1) (u32vector-ref offsets dep)
                      (u32vector-ref offsets (fx+ dep 1)) (cons (vector-ref names dep) seen)))
              (walk top next end seen)))
          (if (fx= top 0) seen
            (let (parent (fx- top 1))
              (walk parent (u32vector-ref saved-cursors parent)
                    (u32vector-ref saved-ends parent) seen))))))))

(def (compact-study)
  (for* ((size '(100000 1000000)) (family '(chain ring band)))
    ;; Data fixture preparation is explicit and outside both candidate windows.
    ;; This studies graph nodes, not a Module/provider per vertex.
    (defvalues (input preparation)
      (measure (lambda ()
        (let* ((names (names size)) (keys (vector->list names)) (rows (make-hash-table-eq)) (edges 0))
          (for (i (in-range size))
            (let (row (family-reads family names size i))
              (hash-put! rows (vector-ref names i) row) (set! edges (+ edges (length row)))))
          (vector keys rows edges))) 1))
    (def keys (vector-ref input 0)) (def rows (vector-ref input 1)) (def edges (vector-ref input 2))
    (def reverse-keys (reverse keys))
    (def root (car (if (eq? family 'band) reverse-keys keys)))
    (def expected (if (eq? family 'band) keys reverse-keys))
    ;; Charge encoding AND first query in one enclosing cold window. Inner
    ;; diagnostics do not let conversion disappear from the reported total.
    (defvalues (bundle cold)
      (measure (lambda ()
        (defvalues (index encoded) (measure (cut capture-compact keys rows edges) 1))
        (defvalues (answer first) (measure (cut compact-reachable index root) 1))
        (vector index encoded first answer)) 1))
    (unless (equal? (vector-ref bundle 3) expected) (error "compact cold order" family size))
    (vector-set! bundle 3 #f)
    (def index (vector-ref bundle 0))
    (def samples [])
    (for (side '(hash compact compact hash))
      (let-values (((answer costs) (measure
                     (lambda () (if (eq? side 'hash) (hash-reachable rows root) (compact-reachable index root))) 1)))
        (unless (equal? answer expected) (error "compact paired order" family size side))
        (set! samples (cons (list side costs) samples))))
    ;; Complete SCC traversal and symbolic output are separate charged phases.
    ;; Its actual counters require N entries/finishes/pops and EVERY input edge.
    (defvalues (scc-result scc-cost) (measure (cut compact-discover index) 1))
    (defvalues (owner-map owner-cost) (measure (cut compact-component-owners index scc-result) 1))
    (vector-set! scc-result 0 owner-map)
    (check-discovery scc-result keys (family-groups family size) size
      (if (eq? family 'ring) 1 size) edges)
    (display "GRAPH-COMPACT-SCC ")
    (write (list family size edges (cons 'discovery scc-cost) (cons 'symbolic-output owner-cost)))
    (newline) (force-output)
    (display "GRAPH-COMPACT-PAIR ")
    (write (list family size edges (cons 'input-preparation preparation)
                 (cons 'cold-encode-and-first-query cold) (cons 'encoding (vector-ref bundle 1))
                 (cons 'first-query (vector-ref bundle 2)) (reverse samples)))
    (newline) (force-output))
  (displayln "GRAPH-COMPACT-OK nodes=100000,1000000 shapes=chain,ring,band"))
