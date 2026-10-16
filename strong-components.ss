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
;; Validate the entire footprint before traversal, including unreachable nodes.
;; Reachability is reflexive; singleton self loops remain atomic groups too.
(def (partition spec)
  (def keys (.@ spec keys))
  (unless (and (list? keys) (andmap symbol? keys)
               (= (length keys) (length (delete-duplicates/hash keys))))
    (error "distinct finite component keys required"))
  (def reads (make-hash-table-eq))
  (def reach (make-hash-table-eq))
  (def owners (make-hash-table-eq))
  (for (key keys)
    (def code (.call spec .code key))
    (def deps (if code (.@ code reads) []))
    (unless (and (list? deps) (andmap (lambda (dep) (memq dep keys)) deps))
      (error "unsupported component read" key deps))
    (hash-put! reads key (delete-duplicates/hash deps)))
  ;; One local visited set per root computes exact finite graph reachability.
  (for (root keys)
    (def seen (make-hash-table-eq))
    (def (visit key)
      (unless (hash-key? seen key)
        (hash-put! seen key #t) (for-each visit (hash-ref reads key))))
    (visit root) (hash-put! reach root seen))
  ;; Mutual reachability is the SCC equivalence; never infer groups from values.
  (def groups (foldl (lambda (key result)
    (if (hash-key? owners key) result
      (let (members (filter (lambda (other)
        (and (hash-key? (hash-ref reach key) other)
             (hash-key? (hash-ref reach other) key))) keys))
        (for-each (lambda (member) (hash-put! owners member key)) members)
        (cons members result)))) [] keys))
  (make-%partition (reverse groups) (cut hash-ref owners <>) (cut hash-ref reads <>)))
