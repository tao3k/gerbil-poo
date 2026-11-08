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
