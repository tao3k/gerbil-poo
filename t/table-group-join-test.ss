;;; Finite multivalued association through the existing grouped join protocol.
(export table-group-join-test)
(import :std/test :std/error :std/iter
        ../object ../mop ../type ../number ../table ../rationaldict ../support/option
        (only-in ../trie SimpleTrie) (only-in ./table-testing alist-table)
        (prefix-in ../examples/service-collection service.))

;; Reuse the ordinary join with explicitly multivalued classification; target
;; collisions still belong to its existing heterogeneous projection boundary.
(def (membership-join source target project (origins []))
  (table-group-join source source target (SimpleTrie UInt Unit)
    (alist-table (Pair (.@ source Key) (.@ source Key)) Unit)
    (lambda (_ row) (vector-ref row 0)) (lambda (_ row) (vector-ref row 0))
    project origins multiple?: #t))

;; Observe ordinary Cartesian rows independently of the maintained group indexes.
;; Overlap is existential: several shared memberships never duplicate a pair.
(def (membership-oracle source target left right)
  (.call target .<-list
    (foldl (lambda (l rows)
      (append (filter-map (lambda (r)
        (and (ormap (cut member <> (vector-ref (cdr r) 0)) (vector-ref (cdr l) 0))
          (cons (+ (* (car l) 100) (car r)) (+ (vector-ref (cdr l) 1) (vector-ref (cdr r) 1)))))
        (.call source .list<- right)) rows)) [] (.call source .list<- left))))

;; Cover pair ownership, selective repair and the existing atomic publication chain.
(def table-group-join-test
  (test-suite "finite multivalued grouped joins"
    (test-case "shared groups project once and a later missing group cannot erase a match"
      (def source (SimpleTrie UInt (Tuple (List UInt) Integer)))
      (def target (SimpleTrie UInt Integer)) (def calls [])
      (def join (membership-join source target (lambda (lk lv rk rv)
        (set! calls (cons (cons lk rk) calls))
        (some (cons (+ (* lk 100) rk) (+ (vector-ref lv 1) (vector-ref rv 1)))))))
      (def l (.call source .<-list '((1 . #((10 10 20) 1)) (9 . #((90) 9)))))
      (def r (.call source .<-list '((3 . #((10 20) 30)) (8 . #((90) 80)))))
      (def state (.call join .ap (cons l r)))
      (check-equal? (length calls) 2)
      (def la (.call source .acons 1 '#((10 30 30) 11) l))
      (set! calls [])
      (def dl (.call source .diff l la)) (def dr (.call source .diff r r))
      (defvalues (next output) (.call join .apply-deltas state dl dr values))
      (check-equal? calls '((1 . 3)))
      (check-equal? (.call target .list<- (.call join .get next)) '((103 . 41) (908 . 89)))
      ;; Existing projection delivery retracts then inserts the changed owner.
      (check-equal? (table-delta-count output) 2)
      (check-equal? (.call target .list<- (.call target .apply-delta (.call join .get next)
        (invert-table-delta output))) (.call target .list<- (.call join .get state)))
      (check-equal? (.call target .list<- (.call join .get
        (.call join .apply-deltas next (invert-table-delta dl) (invert-table-delta dr))))
        (.call target .list<- (.call join .get state))))
    (test-case "joint migration deletion and retry agree with a Cartesian oracle on two backends"
      (for (backend (list (lambda (value) (SimpleTrie UInt value)) RationalDict))
        (def source (backend (Tuple (List UInt) Integer))) (def target (backend Integer))
        (def join (membership-join source target (lambda (lk lv rk rv)
          (some (cons (+ (* lk 100) rk) (+ (vector-ref lv 1) (vector-ref rv 1)))))))
        (def state (.call join .ap (cons (.@ source .empty) (.@ source .empty))))
        (for (round (in-range 24))
          (def roots (.call join .unap state))
          (def lk (modulo round 4)) (def rk (modulo (+ round 1) 5))
          (def l (if (= (modulo round 5) 4) (.call source .remove (car roots) lk)
            (.call source .acons lk (vector (list-ref '((10 20 10) (20 30) () (30 10)) (modulo round 4)) round) (car roots))))
          (def r (.call source .acons rk
            (vector (list-ref '((20 10) () (30 20 30)) (modulo round 3)) (- round)) (cdr roots)))
          (def dl (.call source .diff (car roots) l)) (def dr (.call source .diff (cdr roots) r))
          (defvalues (next output) (.call join .apply-deltas state dl dr values))
          (check-equal? (.call target .list<- (.call join .get next))
            (.call target .list<- (membership-oracle source target l r)))
          (check-equal? (.call target .list<- (.call target .apply-delta (.call join .get state) output))
            (.call target .list<- (.call join .get next)))
          (check-equal? (.call target .list<- (.call join .get
            (.call join .apply-deltas next (invert-table-delta dl) (invert-table-delta dr))))
            (.call target .list<- (.call join .get state)))
          (set! state next))))
    (test-case "checked service Functions survive joint migration and all five style publications"
      (def signature (Fun Integer <- Integer))
      (def f (validate signature (lambda (n) (+ n 7))))
      (def services (SimpleTrie UInt (Tuple (List UInt) signature)))
      (def workers (SimpleTrie UInt (Tuple (List UInt) Bool)))
      (def pairs (alist-table (Pair UInt UInt) Unit))
      (def target (alist-table (Pair UInt UInt) signature))
      (def join (service.make-service-placement-join services workers target
        (SimpleTrie UInt Unit) pairs multiple?: #t))
      (def l (.call services .<-list (list (cons 1 (vector '(10 20 10) f)))))
      (def r (.call workers .<-list '((3 . #((10 20) #t)) (4 . #((30) #t)))))
      (def state (.call join .ap (cons l r)))
      (def dl (.call services .delta/opt 1 (lambda (_) (some (vector '(20 30) f))) l))
      (def dr (.call workers .diff r r))
      (for (name '(Pure Mutable Linear Posh Classy))
        (def protocol (.ref (table-styles target) name)) (def effects 0)
        (def result ((service.publish-join-action join dl dr protocol
          (lambda (_) (set! effects (+ effects 1))))
          (object<-alist (list (cons 'state state) (cons 'target (.call protocol .ap (.call join .get state)))))))
        (def output (.call protocol .unap (.@ result target)))
        (check-equal? effects 1)
        ;; Reinstall the surviving pair, then add its newly matching neighbor.
        (check-equal? (table-delta-count (.@ result delta)) 3)
        (check (eq? (.call target .ref output '(1 . 3)) f) => #t)
        (check (eq? (.call target .ref output '(1 . 4)) f) => #t)
        (check-equal? ((.call target .ref output '(1 . 4)) 5) 12)))
    (test-case "malformed membership and stale source expectations refuse before projection"
      (def source (SimpleTrie UInt Integer)) (def target (SimpleTrie UInt Integer))
      (for (bad (list #f '(10 . bad) '(10 bad)))
        (def calls 0) (def effects 0)
        (def join (table-group-join source source target (SimpleTrie UInt Unit)
          (alist-table (Pair UInt UInt) Unit)
          (lambda (_ value) (if (= value 77) bad '(10 20))) (lambda (_ _value) '(10 20))
          (lambda (_lk lv _rk rv) (set! calls (+ calls 1)) (some (cons 1 (+ lv rv)))) multiple?: #t))
        (def l (.call source .<-list '((1 . 3)))) (def r (.call source .<-list '((2 . 4))))
        (def state (.call join .ap (cons l r))) (set! calls 0)
        (def dl (.call source .delta/opt 1 (lambda (_) (some 77)) l))
        (def dr (.call source .diff r r))
        (check-exception (.call join .apply-deltas state dl dr (lambda args (set! effects (+ effects 1))))
          (lambda (cause) (or (TypeError? cause) (ContractViolation? cause))))
        (check-equal? calls 0) (check-equal? effects 0)
        (def next (.call join .apply-deltas state (.call source .delta/opt 1 (lambda (_) (some 5)) l) dr))
        (check-equal? (.call target .list<- (.call join .get next)) '((1 . 9)))
        (check-exception (.call join .apply-deltas next dl dr) table-conflict?)
        (check-equal? calls 1)))
    (test-case "distinct pairs still collide downstream and old cache retries after refusal"
      (def source (SimpleTrie UInt (Tuple (List UInt) Integer))) (def target (SimpleTrie UInt Integer))
      (def origin (.o epoch: 0)) (def effects 0)
      (def join (membership-join source target (lambda (_lk lv _rk rv)
        (some (cons (vector-ref rv 1) (vector-ref lv 1)))) (list origin)))
      (def l (.call source .<-list '((1 . #((10 20) 7)))))
      (def r (.call source .<-list '((3 . #((10 20) 30)) (4 . #((30) 30)))))
      (def state (.call join .ap (cons l r)))
      (def dl (.call source .diff l l))
      (def bad (.call source .acons 4 '#((10 20 10) 30) r))
      (check-exception (.call join .apply-deltas state dl (.call source .diff r bad)
        (lambda args (set! effects (+ effects 1)))) table-index-conflict?)
      (check-equal? effects 0)
      (check-equal? (.call target .list<- (.call join .get state)) '((30 . 7)))
      (def repaired (.call source .acons 4 '#((10 20) 40) r))
      (def next (.call join .apply-deltas state dl (.call source .diff r repaired)))
      (check-equal? (.call target .list<- (.call join .get next)) '((30 . 7) (40 . 7)))
      (.set! origin epoch 1)
      (check-exception (.call join .get next) Error?))
    (test-case "single list-valued group keys remain distinct from explicit membership lists"
      (def source (SimpleTrie UInt Integer)) (def target (SimpleTrie UInt Integer))
      (def groups (alist-table (List UInt) Unit)) (def pairs (alist-table (Pair UInt UInt) Unit))
      (def l (.call source .<-list '((1 . 3)))) (def r (.call source .<-list '((2 . 4))))
      (def join (table-group-join source source target groups pairs
        (lambda (_ _row) '(10 20)) (lambda (_ _row) '(10 20))
        (lambda (_lk lv _rk rv) (some (cons 1 (+ lv rv))))))
      (check-equal? (.call target .list<- (.call join .get (.call join .ap (cons l r)))) '((1 . 7)))
      (check-exception (table-group-join source source target groups pairs
        (lambda (_ _row) '((10 20))) (lambda (_ _row) '((10 20)))
        (lambda (_lk lv _rk rv) (some (cons 1 (+ lv rv)))) multiple?: 'unknown) ContractViolation?))))
