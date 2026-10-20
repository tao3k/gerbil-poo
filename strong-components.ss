;;; Automatic strongly connected components of declared finite read graphs.
(export partition partition? partition-groups partition-owner partition-reads)
(import :std/iter (only-in :std/list/list filter foldl delete-duplicates/hash)
        ./object (prefix-in ./generalized-graph graph.))
;; Private admitted partition; representatives are first members in source order.
(defstruct %partition (groups owner reads) final: #t)
;; Recognize only admitted partitions.
(def partition? %partition?)
;; Inspect ordered member lists.
(def partition-groups %partition-groups)
;; Map a supported node to its stable representative.
(def partition-owner %partition-owner)
;; Inspect the validated node footprint.
(def partition-reads %partition-reads)
;; Collect a finite declared reachability set using one tail-recursive worklist.
;; Only sets for the current group remain live; std hash tables own membership.
(def (%reachable reads root)
  (def seen (make-hash-table-eq))
  (let visit ((pending [root]))
    (if (null? pending) seen
      (let ((key (car pending)) (rest (cdr pending)))
        (if (hash-key? seen key) (visit rest)
          (begin
            (hash-put! seen key #t)
            (visit (append (hash-ref reads key) rest))))))))
;; Validate the entire footprint before traversal, including unreachable nodes.
;; Reachability is reflexive; singleton self loops remain atomic groups too.
(def (partition spec)
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
  ;; Preserve source-order representatives while sharing discovery by component.
  ;; A forward set alone would incorrectly merge downstream one-way dependencies.
  (def groups (foldl (lambda (key result)
    (if (hash-key? owners key) result
      (let (members
        ;; An already assigned group is a distinct completed SCC. If every
        ;; non-self predecessor is assigned, no new cycle can enter this key.
        ;; Isolated nodes, self loops and dependency chains need no visited sets.
        (if (andmap (lambda (prior) (or (eq? prior key) (hash-key? owners prior)))
                    (hash-ref reverse-reads key))
          [key]
          (let ((forward (%reachable reads key)) (backward (%reachable reverse-reads key)))
            (filter (lambda (other)
              (and (hash-key? forward other) (hash-key? backward other))) keys))))
        (for-each (lambda (member) (hash-put! owners member key)) members)
        (cons members result)))) [] keys))
  (make-%partition (reverse groups) (cut hash-ref owners <>) (cut hash-ref reads <>)))
