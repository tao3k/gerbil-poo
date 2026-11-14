;;; Compare the old retained-capture frame with the projected ownership handoff.
(export cold-handoff-test cold-handoff-contract-test)
(import :std/test :std/iter :clan/poo/object
        (prefix-in :clan/poo/strong-components scc.)
        (only-in :clan/poo/benchmarks/closure-measure measure qualified-metrics))
(extern namespace: clan/poo/strong-components
  capture-graph partition-captured own-partition
  compact-graph-positions compact-graph-direction compact-graph-names
  compact-graph-offsets compact-graph-targets)

;; Frozen former control flow, using the SAME capture, discovery, certificate
;; and ownership implementation. Projecting after the call retains the CSR.
(def (retained-partition source)
  (def keys (.get source keys))
  (unless (list? keys) (error "distinct finite component keys required"))
  (set! keys (append keys []))
  (let-values (((reads index declared edges)
                (capture-graph keys
                  (lambda (key)
                    (let (code (.call source .code key)) (if code (.get code reads) [])))
                  #t 4294967295 'adjacent #t)))
    (def part (partition-captured keys reads edges (length keys) declared index #t))
    (own-partition keys reads
      (and index (compact-graph-positions index))
      (and index (compact-graph-direction index)) part)))

(def (fixture count)
  (def names (list->vector (for/collect (i (in-range count))
    (string->symbol (string-append "cold-handoff-" (number->string i))))))
  (def rows (make-hash-table-symbolic size: count))
  (for (i (in-range count))
    (hash-put! rows (vector-ref names i)
      (list (vector-ref names (if (= i (1- count)) 0 (1+ i))))))
  (values (vector->list names) rows))

;; Observe payload lifetime at the private post-certificate boundary. Explicit
;; GC belongs only to this diagnostic; natural timing below does not force it.
(def (payload-live? keys rows early?)
  (def weak (make-table test: eq? weak-values: #t))
  (def (observe)
    (##gc)
    (map (lambda (key) (and (table-ref weak key #f) #t))
      '(capture names offsets targets positions)))
  (def (start)
    (let-values (((reads index declared edges)
                  (capture-graph keys (cut hash-ref rows <>) #t 4294967295 'adjacent #t)))
      (table-set! weak 'capture index)
      (table-set! weak 'names (compact-graph-names index))
      (table-set! weak 'offsets (compact-graph-offsets index))
      (table-set! weak 'targets (compact-graph-targets index))
      (table-set! weak 'positions (compact-graph-positions index))
      (def complete
        (if early?
          (let ((positions (compact-graph-positions index))
                (direction (compact-graph-direction index)))
            (lambda (part)
              (list (observe) (own-partition keys reads positions direction part))))
          (lambda (part)
            (list (observe)
              (own-partition keys reads (compact-graph-positions index)
                (compact-graph-direction index) part)))))
      (partition-captured keys reads edges (length keys) declared index #t complete)))
  (start))

(def cold-handoff-contract-test
  (test-suite "cold Graph ownership payload lifetime"
    (test-case "only ownership fields survive the certificate handoff"
      (defvalues (keys rows) (fixture 4096))
      (def before (payload-live? keys rows #f))
      (def after (payload-live? keys rows #t))
      (check-equal? (car before) '(#t #t #t #t #t))
      (check-equal? (car after) '(#f #f #f #f #t))
      (check-equal? (scc.partition-groups (cadr before))
        (scc.partition-groups (cadr after))))))

(def cold-handoff-test
  (test-suite "cold Graph ownership handoff"
    (test-case "100K and 1M identical cold capture and certification, ABBA"
      (for (count '(100000 1000000))
        (defvalues (keys rows) (fixture count))
        (def owner-keys keys)
        (def authors 0)
        (def source (.o keys: owner-keys .code: (lambda (key)
          (set! authors (1+ authors)) (.o reads: (hash-ref rows key)))))
        (for (side '(retained projected projected retained))
          (set! authors 0)
          (defvalues (part clocks)
            (measure (lambda ()
              ((if (eq? side 'retained) retained-partition scc.partition-owned) source)) 1))
          (check-equal? authors count)
          (check-equal? (scc.partition-group-size part (car keys)) count)
          (check-equal? ((scc.partition-reads part) (car keys)) (hash-ref rows (car keys)))
          (def work (scc.partition-work part))
          (check-equal? (.get work validation-owners) count)
          (check-equal? (.get work quotient-edges) count)
          (displayln (list 'COLD-GRAPH-HANDOFF count side
            (qualified-metrics clocks) 'raw-allocation (vector-ref clocks 4)))
          ;; Full membership/order/row output is independently charged. Never
          ;; keep the other arm's million-owner result alive during timing.
          (defvalues (valid output-clocks)
            (measure (lambda ()
              (and (equal? (scc.partition-groups part) (list keys))
                (andmap (lambda (key)
                  (and (eq? ((scc.partition-owner part) key) (car keys))
                    (equal? ((scc.partition-reads part) key) (hash-ref rows key)))) keys))) 1))
          (check-equal? valid #t)
          (check-equal? authors count)
          (displayln (list 'COLD-GRAPH-HANDOFF-OUTPUT count side
            (qualified-metrics output-clocks)))
          (force-output))))))
