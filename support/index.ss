;;; Persistent structural snapshots shared by source and Graph preparation.
(export %index %index-project %index-ref %index-fork %index-write! %index-retire!
        %index? %index-base %index-changes %index-overridden?
        %roster %roster-width %roster-position %roster-keys %roster-for-each
        %roster-project %roster-append %roster-retire
        %make-ordinal-buckets %ordinal-bucket-ref %ordinal-roster %roster-cold-index)
(import (only-in :std/struct/rbtree RBTree rbtree-copy rbtree-ref rbtree-put!
                 rbtree-remove! rbtree-for-each)
        (only-in :std/error raise-unbound-key)
        (only-in :std/list/list-builder with-list-builder)
        (only-in :gerbil/runtime/table symbolic-hash)
        (only-in ./base %compare-symbol-identity))

;; The cold owner retains its admitted table or projection. Forking shares that
;; base and path-copies only the sparse tree. This is the original Graph index,
;; moved below object preparation; it is not a second index or result cache.
(defstruct index (base changes) final: #t)
(defalias %index? index?)
(defalias %index-base index-base)
(defalias %index-changes index-changes)
(def missing-index-entry (gensym 'missing-index-entry))

;; The existing owner vector supplies identity. Buckets hold only u32
;; positions and boundaries. Excessive collisions select the ordinary table
;; before any owner callback. No ranges or values are published during build.
(defstruct ordinal-buckets (keys offsets positions mask) final: #t)
(def (ordinal-bucket key mask) (fxand (symbolic-hash key) mask))

;; A successful probe publishes one slot vector. It replaces the count,
;; scatter and final lookup passes for a large, normally distributed roster.
;; The same bound applies to insertion and lookup. A long cluster declines
;; admission so the existing bucketed path can process the original roster.
(def (ordinal-probe keys slots mask key (insert #f))
  (let scan ((slot (ordinal-bucket key mask)) (left 256))
    (and (fx> left 0)
         (let (entry (u32vector-ref slots slot))
           (cond
            ((fx= entry 0)
             (and insert (begin (u32vector-set! slots slot (fx+ insert 1)) #t)))
            ((eq? key (vector-ref keys (fx- entry 1)))
             (and (not insert) (fx- entry 1)))
            (else (scan (fxand (fx+ slot 1) mask) (fx- left 1))))))))

(def (probe-ordinal-roster keys)
  (def count (vector-length keys))
  (def width (arithmetic-shift 1 (integer-length (fx+ count (fxquotient count 2)))))
  (def mask (fx- width 1))
  (def slots (make-u32vector width 0))
  (let admit ((node 0))
    (if (fx= node count) (make-ordinal-buckets keys #f slots mask)
      (let (key (vector-ref keys node))
        (and (symbol? key) (ordinal-probe keys slots mask key node)
             (admit (fx+ node 1)))))))

(def (%make-ordinal-buckets keys)
  (or (and (fx>= (vector-length keys) 65536) (probe-ordinal-roster keys))
      (bucket-ordinal-roster keys)))

(def (bucket-ordinal-roster keys)
  (def count (vector-length keys))
  (def width (arithmetic-shift 1 (integer-length (fxquotient count 4))))
  (def mask (fx- width 1))
  (def offsets (make-u32vector (fx+ width 1) 0))
  (def (scan i)
    (or (fx= i count)
        (let (key (vector-ref keys i))
          (and (symbol? key)
               (let* ((id (ordinal-bucket key mask))
                      (size (u32vector-ref offsets id)))
                 (and (fx< size 24)
                      (begin
                        (u32vector-set! offsets id (fx+ size 1))
                        (scan (fx+ i 1)))))))))
  (and (scan 0)
    (let (positions (make-u32vector count 0))
      (let prefix ((id 0) (end 0))
        (if (fx= id width) (u32vector-set! offsets width end)
          (let (end (fx+ end (u32vector-ref offsets id)))
            (u32vector-set! offsets id end)
            (prefix (fx+ id 1) end))))
      ;; Scatter backwards so decrementing each end preserves roster order.
      (let scatter ((i (fx- count 1)))
        (unless (fx< i 0)
          (let* ((id (ordinal-bucket (vector-ref keys i) mask))
                 (at (fx- (u32vector-ref offsets id) 1)))
            (u32vector-set! offsets id at)
            (u32vector-set! positions at i)
            (scatter (fx- i 1)))))
      (let (index (make-ordinal-buckets keys offsets positions mask))
        (let distinct ((i 0))
          (if (fx= i count) index
            (and (eqv? i (%ordinal-bucket-ref index (vector-ref keys i)))
                 (distinct (fx+ i 1)))))))))

(def (%ordinal-bucket-ref index key)
  (using (index :- ordinal-buckets)
    (if index.offsets
      (let* ((id (ordinal-bucket key index.mask))
             (end (u32vector-ref index.offsets (fx+ id 1))))
        (let scan ((at (u32vector-ref index.offsets id)))
          (and (fx< at end)
               (let (i (u32vector-ref index.positions at))
                 (if (eq? (vector-ref index.keys i) key) i
                   (scan (fx+ at 1)))))))
      (ordinal-probe index.keys index.positions index.mask key))))

(def (%index base) (make-index base #f))
(def (%index-fork source)
  (let (changes (index-changes source))
    (make-index (index-base source)
      (if changes (rbtree-copy changes) (RBTree %compare-symbol-identity)))))
(def (%index-ref source key (default missing-index-entry))
  (def changes (index-changes source))
  (def edited (if changes (rbtree-ref changes key missing-index-entry) missing-index-entry))
  (if (eq? edited missing-index-entry)
    (let (base (index-base source))
      (if (procedure? base) (base key default)
        (if (eq? default missing-index-entry) (hash-ref base key)
          (hash-ref base key default))))
    edited))
(def (%index-project support project)
  (%index (lambda (key default)
    (if (hash-key? support key) (project key)
      (if (eq? default missing-index-entry) (hash-ref support key) default)))))
;; Only a private fork is writable. The cold base and previously published
;; roots remain unchanged; callers already own that publication discipline.
(def (%index-write! source key value) (rbtree-put! (index-changes source) key value))
(def (%index-overridden? source key)
  (let (changes (index-changes source))
    (and changes (not (eq? (rbtree-ref changes key missing-index-entry) missing-index-entry)))))

;; An absent cold key needs no override. A cold value stays borrowed
;; by historical snapshots and must be masked in the private fork.
(def absent-cold-entry (gensym 'absent-cold-entry))
(def (%index-retire! source key (absent #f))
  (def base (index-base source))
  (def present?
    (if (procedure? base)
      (not (eq? (base key absent-cold-entry) absent-cold-entry))
      (hash-key? base key)))
  (if present? (%index-write! source key absent)
    (rbtree-remove! (index-changes source) key)))

;; The cold order is shared. The suffix index contains only active ordinals.
;; Width is the witness address high-water mark, independent of live count.
(defstruct roster (initial appended positions width) final: #t)
(def (%roster keys positions)
  (make-roster keys #f (%index positions) (hash-length positions)))
(def (%ordinal-roster keys buckets)
  (make-roster keys #f
    (%index (lambda (key default)
      (or (and (symbol? key) (%ordinal-bucket-ref buckets key)) default)))
    (vector-length keys)))
(def %roster-width roster-width)
;; A dense source traversal must use the exact unedited ordinal order.
(def (%roster-cold-index roster keys)
  (let (positions (roster-positions roster))
    (and (eq? keys (roster-initial roster)) (not (%index-changes positions))
         (%index-base positions))))
(def (%roster-position roster key)
  (%index-ref (roster-positions roster) key #f))
(def (%roster-project roster project)
  (def positions (roster-positions roster))
  (if (and (not (%index-changes positions)) (not (procedure? (%index-base positions))))
    (%index-project (%index-base positions) project)
    (%index (lambda (key default)
      (if (%roster-position roster key) (project key)
        (if (eq? default missing-index-entry) (raise-unbound-key %roster-project key) default))))))
(def (%roster-for-each visit roster)
  (def initial (roster-initial roster))
  (def edited? (%index-changes (roster-positions roster)))
  (def ordinal 0)
  (def (next key)
    (when (or (not edited?) (eqv? ordinal (%roster-position roster key))) (visit key))
    (set! ordinal (1+ ordinal)))
  (if (vector? initial)
    (let walk ((at 0))
      (unless (fx= at (vector-length initial))
        (next (vector-ref initial at))
        (walk (fx+ at 1))))
    (if edited? (for-each next initial) (for-each visit initial)))
  (let (appended (roster-appended roster))
    (when appended (rbtree-for-each (lambda (_ key) (visit key)) appended))))
(def (%roster-keys roster)
  (def initial (roster-initial roster))
  (if (not (%index-changes (roster-positions roster)))
    (if (vector? initial) (vector->list initial) (list-copy initial))
    (with-list-builder (add) (%roster-for-each add roster))))
(def (%roster-append roster names)
  (def positions (%index-fork (roster-positions roster)))
  (def appended (if (roster-appended roster) (rbtree-copy (roster-appended roster)) (RBTree -)))
  (def next (roster-width roster))
  (for-each (lambda (key)
              (unless (and (symbol? key) (not (%index-ref positions key #f)))
                (error "distinct new component owner required" key))
              (%index-write! positions key next)
              (rbtree-put! appended next key)
              (set! next (1+ next))) names)
  (make-roster (roster-initial roster) appended positions next))
(def (%roster-retire roster names)
  (def positions (%index-fork (roster-positions roster)))
  (def old (roster-appended roster))
  (def appended (and old (rbtree-copy old)))
  (for-each (lambda (key)
              (def ordinal (%index-ref positions key #f))
              (unless ordinal (error "active component owner required" key))
              (when appended (rbtree-remove! appended ordinal))
              (%index-retire! positions key)) names)
  (make-roster (roster-initial roster) appended positions (roster-width roster)))
