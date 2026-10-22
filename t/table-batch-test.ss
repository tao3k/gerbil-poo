;;; Ordered table batches retain intermediate conflict checks and origin lineage.
(export table-batch-test)
(import :std/test :std/iter :std/error
        ../object ../mop ../number ../type ../table ../rationaldict ../support/option
        (only-in ../fun Wrapper.) (only-in ../trie SimpleTrie)
        (prefix-in ../examples/service-collection service.))

;; Match protocol failures without accepting unrelated backend exceptions.
(def (message? text)
  (lambda (cause) (and (Error? cause) (equal? (Error-message cause) text))))

;; Explicit typed identity conversion retains admitted values, including procedures.
(def (identity-wrapper descriptor)
  (.cc Wrapper. Domain: descriptor Codomain: descriptor .ap: identity .unap: identity))

;; Exercise public installation, conversion, folds and FUN rather than private edits.
(def table-batch-test
  (test-suite "ordered persistent revision batches"
    (test-case "ordered repeated-key batches compose associate and undo on both carriers"
      (for (table (list (RationalDict Integer) (SimpleTrie UInt Integer)))
        (def base (.call table .<-list '((1 . 10) (9 . 90))))
        (def middle (.call table .acons 1 20 base))
        (def deleted (.call table .remove middle 1))
        (def final (.call table .acons 1 30 deleted))
        (def one (.call table .diff base middle))
        (def two (.call table .diff middle deleted))
        (def three (.call table .diff deleted final))
        (def batch (.call table .compose-deltas (list one two three)))
        (check-equal? (table-delta-count batch) 3)
        (check-equal? (.call table .list<- (.call table .apply-delta base batch)) (.call table .list<- final))
        (for (grouped (list (.call table .compose-deltas
                              (list (.call table .compose-deltas (list one two)) three))
                            (.call table .compose-deltas
                              (list one (.call table .compose-deltas (list two three))))))
          (check-equal? (.call table .list<- (.call table .apply-delta base grouped)) (.call table .list<- final)))
        (check-equal? (.call table .list<- (.call table .apply-delta final (invert-table-delta batch)))
                      (.call table .list<- base))
        (check (eq? (.call table .apply-delta base (.call table .compose-deltas [])) base) => #t)))
    (test-case "stored false remains distinct from absence through batch undo"
      (for (table (list (RationalDict Bool) (SimpleTrie UInt Bool)))
        (def base (.call table .<-list '((1 . #f))))
        (def absent (.call table .remove base 1))
        (def batch (.call table .compose-deltas
          (list (.call table .diff base absent) (.call table .diff absent base))))
        (def installed (.call table .apply-delta base batch))
        (check (.call table .key? installed 1) => #t)
        (check (.call table .ref installed 1) => #f)
        (check-equal? (.call table .list<- (.call table .apply-delta installed (invert-table-delta batch)))
                      (.call table .list<- base))))
    (test-case "cancelling edits retain old-value checks and late failure suppresses fold IO"
      (def table (RationalDict Integer))
      (def base (.call table .<-list '((1 . 10) (2 . 20))))
      (def middle (.call table .acons 1 11 base))
      (def one (.call table .diff base middle))
      (def undo (invert-table-delta one))
      (def cancelled (.call table .compose-deltas (list one undo)))
      (check-equal? (table-delta-count cancelled) 2)
      (check-exception (.call table .apply-delta (.call table .acons 1 99 base) cancelled) table-conflict?)
      (def calls 0) (def consumed 0)
      (def folding (table-fold table Integer (lambda (_ v) (set! calls (+ calls 1)) v)))
      (def state (.call folding .ap base))
      (def action (service.batch-ledger-action table folding state
        (lambda (v) (set! consumed (+ consumed 1)) v)))
      (def wrong (.call table .diff base (.call table .acons 1 12 base)))
      (set! calls 0)
      (check-exception (action (list one wrong)) table-conflict?)
      (check-equal? calls 0) (check-equal? consumed 0)
      (check-equal? (.call folding .get state) 30)
      (def retried (action (list one undo)))
      (check-equal? (.call folding .get retried) 30)
      (check-equal? calls 4) (check-equal? consumed 1))
    (test-case "composition neither enumerates snapshots nor forgets empty origin revisions"
      (def source (RationalDict Integer))
      (def base (.call source .<-list '((1 . 10))))
      (def delta (.call source .diff base (.call source .acons 1 11 base)))
      (def empty (.call source .diff base base))
      (def receiver (.cc source
        .foldl: (lambda _ (error "snapshot scan"))
        .validate-shape: (lambda _ (error "snapshot admission"))))
      (def batch (.call receiver .compose-deltas (list empty delta)))
      (check-equal? (table-delta-count batch) 1)
      (check-exception (.call (RationalDict String) .compose-deltas (list delta))
        (message? "stale or incompatible table delta"))
      (.set! source sexp 'revised)
      (check-exception (.call receiver .compose-deltas (list empty))
        (message? "stale or incompatible table delta"))
      (check-exception (.call receiver .apply-delta base batch)
        (message? "stale or incompatible table delta")))
    (test-case "isomorphic transport preserves each intermediate value and inverse"
      (def source (RationalDict Integer))
      (def target (SimpleTrie UInt Integer))
      (def keys (.cc Wrapper. Domain: (.@ source Key) Codomain: UInt
        .ap: (cut + <> 1) .unap: (cut - <> 1)))
      (def mapping (table-isomorphism source target keys (identity-wrapper Integer)))
      (def base (.call source .<-list '((1 . 10))))
      (def middle (.call source .acons 1 20 base))
      (def final (.call source .acons 1 30 middle))
      (def batch (.call source .compose-deltas
        (list (.call source .diff base middle) (.call source .diff middle final))))
      (def staged (.call (.@ mapping Delta) .ap (cons base batch)))
      (def installed (.call target .apply-delta (car staged) (cdr staged)))
      (check-equal? (.call target .ref installed 2) 30)
      (check-equal? (.call target .ref
        (.call target .apply-delta installed (invert-table-delta (cdr staged))) 2) 10)
      (def recovered (.call (.@ mapping Delta) .unap staged))
      (check-equal? (.call source .ref (.call source .apply-delta (car recovered) (cdr recovered)) 1) 30))
    (test-case "temporary keys and admitted Function leaves survive transport and undo"
      (def callback (Fun Integer <- Integer))
      (def source (RationalDict callback))
      (def target (SimpleTrie UInt callback))
      (def base (validate source (.call source .<-list (list (cons 1 (lambda (x) (+ x 1)))))))
      (def f (.call source .ref base 1))
      (def temporary (.call source .acons 2 f base))
      (def batch (.call source .compose-deltas
        (list (.call source .diff base temporary) (.call source .diff temporary base))))
      (def mapping (table-isomorphism source target
        (.cc Wrapper. Domain: (.@ source Key) Codomain: UInt .ap: identity .unap: identity)
        (identity-wrapper callback)))
      (def staged (.call (.@ mapping Delta) .ap (cons base batch)))
      (check-equal? (table-delta-count (cdr staged)) 2)
      (def installed (.call target .apply-delta (car staged) (cdr staged)))
      (check (eq? (.call target .ref installed 1) f) => #t)
      (check (.call target .key? installed 2) => #f)
      (check-exception (f "wrong") TypeError?)
      (check-equal? (.call target .list<-
        (.call target .apply-delta installed (invert-table-delta (cdr staged))))
        (.call target .list<- (car staged))))
    (test-case "fold transport retains ownership after a deletion followed by reinsertion"
      (def source (.cc (RationalDict Integer) Key: UInt))
      (def target (SimpleTrie UInt Integer))
      (def keys (.cc Wrapper. Domain: UInt Codomain: UInt
        .ap: (lambda (k) (if (= k 2) 0 k)) .unap: identity))
      (def folding (table-fold source Integer (lambda (_ v) v)))
      (def mapping (.call folding .isomorphism target keys (identity-wrapper Integer)))
      (def target-fold (.@ mapping Codomain))
      (def base (.call source .<-list '((0 . 10))))
      (def state (.call folding .ap base))
      (def absent (.call source .remove base 0))
      (def final (.call source .acons 0 30 absent))
      (def batch (.call source .compose-deltas
        (list (.call source .diff base absent) (.call source .diff absent final))))
      (def installed (.call mapping .apply-delta state batch))
      (check-equal? (.call target-fold .get installed) 30)
      (def updated (.call mapping .unap installed))
      (def collision (.call source .diff final (.call source .acons 2 40 final)))
      (def cause (try (.call mapping .apply-delta updated collision) #f (catch (e) e)))
      (check (table-isomorphism-failure? cause) => #t)
      (check-equal? (table-isomorphism-failure-kind cause) 'collision)
      ;; Failed translation retains the last accepted pair for a valid retry.
      (check (eq? (.call mapping .ap updated) installed) => #t)
      (def retry (.call source .diff final (.call source .acons 3 40 final)))
      (check-equal? (.call target-fold .get (.call mapping .apply-delta updated retry)) 70))))
