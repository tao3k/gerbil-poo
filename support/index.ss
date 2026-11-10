;;; Persistent structural snapshots shared by source and Graph preparation.
(export %index %index-project %index-ref %index-fork %index-write!
        %index? %index-base %index-changes)
(import (only-in :std/struct/rbtree RBTree rbtree-copy rbtree-ref rbtree-put!)
        (only-in ./base %compare-symbol-identity))

;; The cold owner retains its admitted table or projection. Forking shares that
;; base and path-copies only the sparse tree. This is the original Graph index,
;; moved below object preparation; it is not a second index or result cache.
(defstruct index (base changes) final: #t)
(defalias %index? index?)
(defalias %index-base index-base)
(defalias %index-changes index-changes)
(def missing-index-entry (gensym 'missing-index-entry))

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
