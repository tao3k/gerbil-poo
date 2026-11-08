;;; Strongly connected components (SCC): maximal mutually reachable node groups.
;;; Iterative Tarjan partitions captured finite POO computation footprints.
;;; Explicit feedback construction and recursive topology consume these groups;
;;; this does not load namespaces or make ordinary cyclic slot access valid.
(export partition partition? partition-groups partition-owner partition-reads
        partition-members partition-group-of partition-group-size partition-work)
(import :std/iter (only-in :std/list/list delete-duplicates/hash)
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
(def (discover keys reads)
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
  (def reads (make-hash-table-eq))
  (def supported (make-hash-table-eq))
  (def declared-edges 0)
  (for (key keys) (hash-put! supported key #t))
  ;; Validate every declaration before DFS, including disconnected owners.
  (for (key keys)
    (def code (.call spec .code key))
    (def deps (if code (.@ code reads) []))
    (unless (and (list? deps) (andmap (cut hash-key? supported <>) deps))
      (error "unsupported component read" key deps))
    (hash-put! reads key (delete-duplicates/hash deps))
    (set! declared-edges (+ declared-edges (length deps))))
  (let-values (((owners next component examined-edges finished popped) (discover keys reads)))
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
          (work-receipt next declared-edges next examined-edges finished popped next component
            certificate-buckets certificate-edges quotient-edges certificate-singletons reverse-edges) owners)))))
