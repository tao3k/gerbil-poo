;;; Backend equality governs cache work, without weakening sequential conflicts.
(export table-index-equivalence-test)
(import :std/test :std/error ../object ../mop ../type ../number ../table
        ../rationaldict ../support/option
        (prefix-in ../examples/service-collection service.))

;; The standard rational backend deliberately identifies exact/inexact aliases.
;; All rows retain the same admitted Function while priority and team migrate.
(def (fixture)
  (def signature (Fun Integer <- Integer))
  (def f (validate signature (lambda (n) (+ n 3))))
  (def source (RationalDict (Tuple UInt UInt signature)))
  (defvalues (indexed _) (service.make-ordered-service-indexes source RationalDict))
  (def root (.call source .<-list
    (list (cons 1 (vector 10 7 f)) (cons 2 (vector 20 7 f)))))
  (values indexed source root f))

;; Capture every old-value expectation at its own intermediate primary.
(def (revision source root first second f)
  (def a (.call source .delta/opt first (lambda (_) (some (vector 11 8 f))) root))
  (def b (.call source .delta/opt second (lambda (_) (some (vector 12 9 f)))
    (.call source .apply-delta root a)))
  (.call source .compose-deltas (list a b)))

;; Exercise whole indexed revisions, admitted callbacks and ownership publication.
(def table-index-equivalence-test
  (test-suite "backend-equivalent incremental cache work"
    (test-case "numeric aliases and repeated edits rebuild one final unique owner"
      (defvalues (indexed source root f) (fixture))
      (for-each (lambda (keys)
        (def state (.call indexed .wrap root))
        (def delta (revision source root (car keys) (cadr keys) f))
        (check-equal? (table-delta-count delta) 2)
        (def next (.call indexed .apply-delta state delta))
        (check-equal? (.call indexed .index-ref/opt next 'priority 10) #f)
        (check-equal? (.call indexed .index-ref/opt next 'priority 11) #f)
        (check-equal? (.call indexed .index-ref/opt next 'priority 12) (some (car keys)))
        (check-eq? (vector-ref (.call indexed .ref next 1) 2) f)
        (check-equal? (.call source .count
          (some-value (.call indexed .index-ref/opt next 'team 9))) 1)
        (def restored (.call indexed .apply-delta next (invert-table-delta delta)))
        (check-equal? (.call indexed .count restored) (.call source .count root))
        (check-equal? (.call indexed .ref restored 1) (.call source .ref root 1))
        (check-equal? (.call indexed .ref restored 2) (.call source .ref root 2)))
        '((1 1.0) (1.0 1) (1 1))))
    (test-case "all five presentations publish the composed revision and undo"
      (defvalues (indexed source root f) (fixture))
      (def base (.call indexed .wrap root))
      (def delta (revision source root 1 1.0 f))
      (for-each (lambda (name)
        (def style (.ref (table-styles indexed) name))
        (def owner (.call style .ap base))
        (def next (.call style .apply-delta owner delta))
        (check-equal? (vector-ref (.call style .ref next 1) 0) 12)
        (def undo (.call style .apply-delta next (invert-table-delta delta)))
        (check-equal? (.call style .ref undo 1) (.call source .ref root 1))
        (check-equal? (.call style .count undo) (.call source .count root))) '(Pure Mutable Linear Posh Classy)))
    (test-case "stale intermediate expectations refuse before projection and retry"
      (defvalues (indexed source root f) (fixture))
      (def a (.call source .delta/opt 1 (lambda (_) (some (vector 11 8 f))) root))
      ;; This request was captured against the original, not the intermediate row.
      (def stale (.call source .delta/opt 1.0 (lambda (_) (some (vector 99 7 f))) root))
      (def state (.call indexed .wrap root))
      (check-exception (.call indexed .apply-delta state
        (.call source .compose-deltas (list a stale))) table-conflict?)
      (check-equal? (.call indexed .list<- state) (.call source .list<- root))
      (def next (.call indexed .apply-delta state (revision source root 1 1.0 f)))
      (check-equal? (vector-ref (.call indexed .ref next 1) 0) 12))
    (test-case "service FUN publication consumes only an admitted complete revision"
      (defvalues (indexed source root f) (fixture))
      (def base (.call indexed .wrap root)) (def effects 0)
      (def delta (revision source root 1.0 1 f))
      (def published (service.apply-indexed-revision indexed base delta
        (lambda (state) (set! effects (+ effects 1)) state)))
      (check-equal? effects 1)
      (check-equal? (vector-ref (.call indexed .ref published 1) 0) 12)
      (check-eq? (vector-ref (.call indexed .ref published 1) 2) f)
      (def bad (.call source .delta/opt 2 (lambda (_) (some (vector 10 7 f))) root))
      (check-exception (service.apply-indexed-revision indexed base bad
        (lambda (_) (set! effects (+ effects 1)))) table-index-conflict?)
      (check-equal? effects 1)
      (check-equal? (.call indexed .ref base 1) (.call source .ref root 1)))
    (test-case "old and final projections run once per backend owner"
      (def source (RationalDict Integer)) (def calls 0)
      (def indexed (table-indexes source (list (.o name: 'unique unique?: #t
        table: (RationalDict Rational)
        project: (lambda (_ row) (set! calls (+ calls 1)) row)))))
      (def root (.call source .<-list '((1 . 10))))
      (def state (.call indexed .wrap root))
      (def a (.call source .delta/opt 1 (lambda (_) (some 11)) root))
      (def middle (.call source .apply-delta root a))
      (def b (.call source .delta/opt 1.0 (lambda (_) (some 12)) middle))
      (set! calls 0)
      (def next (.call indexed .apply-delta state (.call source .compose-deltas (list a b))))
      (check-equal? calls 2)
      (check-equal? (.call indexed .ref next 1) 12)
      (set! calls 0)
      (check-exception (.call indexed .apply-delta state
        (.call source .compose-deltas (list a a))) table-conflict?)
      (check-equal? calls 0)
      (def cancel (.call source .compose-deltas (list a (invert-table-delta a))))
      (check-equal? (table-delta-count cancel) 2)
      (check-equal? (.call indexed .ref (.call indexed .apply-delta state cancel) 1) 10)
      (check-exception (.call indexed .apply-delta next cancel) table-conflict?))
    (test-case "distinct primary owners still collide on one unique index key"
      (defvalues (indexed source root f) (fixture))
      (def state (.call indexed .wrap root))
      (def bad (.call source .delta/opt 2 (lambda (_) (some (vector 10 7 f))) root))
      (check-exception (.call indexed .apply-delta state bad) table-index-conflict?)
      (check-equal? (.call indexed .list<- state) (.call source .list<- root)))
    (test-case "multivalued group aliases refold one logical bucket with exact Functions"
      (def signature (Fun Integer <- Integer)) (def calls 0)
      (def f (validate signature (lambda (_) (set! calls (+ calls 1)) 3)))
      (def source (RationalDict (Tuple (List Rational) signature)))
      (def target (RationalDict Integer))
      (def view (service.make-service-membership-fold source target))
      (def root (.call source .<-list (list (cons 1 (vector '(10 10.0 20) f)))))
      (def state (.call view .ap root))
      (check-equal? (.call target .count (.call view .get state)) 2)
      (check-equal? calls 2)
      (set! calls 0)
      (def next (.call view .apply-delta state (.call source .delta/opt 1.0
        (lambda (_) (some (vector '(20.0 20 30) f))) root)))
      (check-equal? calls 2)
      (check-equal? (.call target .ref (.call view .get next) 20) 3)
      (check-equal? (.call target .ref (.call view .get next) 30) 3))))
