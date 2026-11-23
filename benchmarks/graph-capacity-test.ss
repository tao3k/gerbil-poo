;;; Opt-in 10M-owner study. Run each exported suite in a fresh Gerbil process.
(export graph-capacity-chain-test graph-capacity-ring-test graph-capacity-mixed-test)
(import :std/test :clan/poo/object
        (prefix-in :clan/poo/graph/schedule graph.)
        (prefix-in :clan/poo/graph/scc scc.)
        (only-in ./closure-measure measure qualified-metrics))

(def owner-count 10000000)
(def query-count 100000)

(def (record phase . values)
  (write (cons phase values))
  (newline)
  (force-output))

(def (phase name action)
  (record 'GRAPH-CAPACITY-BEGIN name)
  (defvalues (result measures) (measure action 1))
  (record 'GRAPH-CAPACITY-PHASE name (qualified-metrics measures))
  result)

(def (names count)
  (def keys (make-vector count))
  (let fill ((i 0))
    (unless (fx= i count)
      (vector-set! keys i (string->uninterned-symbol "capacity-owner" i))
      (fill (fx+ i 1))))
  keys)

;; Mixed has ten cyclic groups, a chord in five groups, and nine forward edges
;; between groups. The known group sizes and source order are independent controls.
(def (packed-edges shape count width)
  (def edges (case shape ((chain) (fx- count 1)) ((mixed) (fx+ count 14)) (else count)))
  (def offsets (make-u32vector (fx+ count 1) 0))
  (def targets (make-u32vector edges))
  (let fill ((node 0) (edge 0) (group 0) (start 0) (last (fx- width 1)))
    (u32vector-set! offsets node edge)
    (cond
     ((fx= node count) (check-equal? edge edges))
     ((eq? shape 'chain)
      (if (fx= node 0) (fill 1 0 group start last)
        (begin
          (u32vector-set! targets edge (fx- node 1))
          (fill (fx+ node 1) (fx+ edge 1) group start last))))
     (else
      (def next (fx+ node 1))
      (def next-edge (fx+ edge 1))
      (u32vector-set! targets edge (if (fx= node last) start next))
      (cond
       ((fx= node last)
        (if (and (eq? shape 'mixed) (fx< next count))
          (begin
            (u32vector-set! targets next-edge next)
            (fill next (fx+ next-edge 1) (fx+ group 1) next (fx+ last width)))
          (fill next next-edge group start last)))
       ((and (eq? shape 'mixed) (fx= node start) (fx= (fxand group 1) 0))
        (u32vector-set! targets next-edge (fx+ node 2))
        (fill next (fx+ next-edge 1) group start last))
       (else (fill next next-edge group start last))))))
  (values offsets targets))

(def (verify-members part keys representative width)
  (def visited 0)
  (check (scc.partition-for-each-member part (vector-ref keys representative)
    (lambda (name)
      (unless (eq? name (vector-ref keys (fx+ representative visited)))
        (error "membership order differs" representative visited))
      (set! visited (fx+ visited 1)))) => #t)
  (check-equal? visited width)
  visited)

(def (sample-queries part keys)
  (def count (vector-length keys))
  (let loop ((query 0) (total 0))
    (if (fx= query query-count) total
      (loop (fx+ query 1)
        (fx+ total (scc.partition-group-size part
          (vector-ref keys (fxmodulo (fx* query 97) count))))))))

(def (edit-chain part keys)
  (def count (vector-length keys))
  (def consumer (vector-ref keys (fxquotient count 2)))
  (def original (list (vector-ref keys (fx- (fxquotient count 2) 1))))
  (def replacement (append original (list (vector-ref keys 0))))
  (def next (phase 'local-edit
    (lambda () (scc.revise-partition part (list (cons consumer replacement))))))
  (check-equal? ((scc.partition-reads part) consumer) original)
  (check-equal? ((scc.partition-reads next) consumer) replacement)
  (check-equal? (scc.partition-group-size next consumer) 1)
  (def work (scc.partition-work next))
  (check-equal? (.get work rank-checks) 2)
  (check-equal? (.get work region-owners) 0)
  (record 'GRAPH-CAPACITY-EDIT (.get work rank-checks) (.get work region-owners)))

(def (verify-capacity shape)
  (def count owner-count)
  (def width (case shape ((chain) 1) ((mixed) (fxquotient count 10)) (else count)))
  (record 'GRAPH-CAPACITY shape count)
  (defvalues (result complete)
    (measure
      (lambda ()
        (def keys (phase 'names (lambda () (names count))))
        (def source
          (let (rows (phase 'edges (lambda ()
                        (call-with-values (lambda () (packed-edges shape count width)) cons))))
            (phase 'admission (lambda ()
              (graph.declaration/rows keys (car rows)
                (lambda _ (error "structural Graph must not call the provider"))
                targets: (cdr rows))))))
        (cons keys (phase 'partition (lambda () (scc.partition-owned source))))) 1))
  (record 'GRAPH-CAPACITY-PHASE 'complete-cold (qualified-metrics complete))
  (def keys (car result))
  (def part (cdr result))
  (def work (scc.partition-work part))
  (def edges (case shape ((chain) (fx- count 1)) ((mixed) (fx+ count 14)) (else count)))
  (check-equal? (.get work groups) (fxquotient count width))
  (check-equal? (.get work validation-owners) count)
  (check-equal? (.get work validation-edges) edges)
  (check-equal? (phase 'group-size-queries (lambda () (sample-queries part keys)))
                (fx* query-count width))
  (phase 'ordered-members
    (lambda ()
      (if (eq? shape 'chain)
        (verify-members part keys (fx- count 1) 1)
        (let loop ((start 0))
          (unless (fx= start count)
            (verify-members part keys start width)
            (loop (fx+ start width)))))))
  (when (eq? shape 'chain) (edit-chain part keys))
  (record 'GRAPH-CAPACITY-OK shape count edges (.get work groups) query-count))

(def graph-capacity-chain-test
  (test-suite "10M packed DAG chain"
    (test-case "certify, query and edit one row" (verify-capacity 'chain))))
(def graph-capacity-ring-test
  (test-suite "10M packed single SCC"
    (test-case "certify and stream ordered members" (verify-capacity 'ring))))
(def graph-capacity-mixed-test
  (test-suite "10M packed mixed SCCs"
    (test-case "certify cycles, chords and cross-group edges" (verify-capacity 'mixed))))
