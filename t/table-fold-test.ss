;;; Complete fold-state admission composes with sparse updates and representations.
(export table-fold-test)
(import :std/test :std/iter (only-in :std/error Error? Error-message)
        ../object ../mop ../number ../type ../table ../rationaldict ../support/option
        (only-in ../fun Wrapper.) (prefix-in ../examples/service-collection service.))

;; Refine a backend through its existing complete recognizer, never a new carrier.
(def (even-table table)
  (.cc table .element?: (lambda (root)
    (and (element? table root) (even? (.call table .count root))))))

;; Typed identity preserves the existing isomorphism preparation and child laws.
(def (identity-wrapper type)
  (.cc Wrapper. Domain: type Codomain: type .ap: identity .unap: identity))

;; Failure causes, including arbitrary callback payloads, retain exact identity.
(def (cause-of action) (try (action) #f (catch (cause) cause)))

;; Exercise final-state acceptance through actual public fold and FUN operations.
(def table-fold-test
  (test-suite "complete incremental fold admission"
    (test-case "compatible raw deltas cannot bypass a refined source before projection"
      (def raw (RationalDict Integer)) (def source (even-table raw)) (def calls 0)
      (def folding (table-fold source Integer (lambda (_ value) (set! calls (+ calls 1)) value)))
      (def base (.call raw .<-list '((1 . 10) (2 . 20))))
      (def state (.call folding .ap base))
      (def after (.call raw .remove base 1))
      (def delta (.call raw .diff base after))
      (set! calls 0)
      (check-exception (.call folding .apply-delta state delta) TypeError?)
      (check-equal? calls 0)
      (check (eq? (.call folding .unap state) base) => #t)
      (check-equal? (.call folding .get state) 30)
      ;; An empty request remains a real admission boundary on the captured root.
      (check-equal? (.call folding .get
        (.call folding .apply-delta state (.call raw .diff base base))) 30)
      (check-equal? calls 0))
    (test-case "composed requests admit the final root without demanding valid intermediate roots"
      (def raw (RationalDict Integer)) (def source (even-table raw)) (def calls 0)
      (def folding (table-fold source Integer (lambda (_ value) (set! calls (+ calls 1)) value)))
      (def base (.call raw .<-list '((1 . 10) (2 . 20))))
      (def middle (.call raw .remove base 1))
      (def final (.call raw .acons 3 40 middle))
      (def batch (.call raw .compose-deltas
        (list (.call raw .diff base middle) (.call raw .diff middle final))))
      (def state (.call folding .ap base))
      (set! calls 0)
      (def changed (.call folding .apply-delta state batch))
      (check-equal? calls 2)
      (check (element? source (.call folding .unap changed)) => #t)
      (check-equal? (.call folding .get changed) 60)
      (check-equal? (.call folding .get
        (.call folding .apply-delta changed (invert-table-delta batch))) 30)
      (check-equal? calls 4))
    (test-case "cold and warm target refusal retain the previous pair and support batch retry and undo"
      (def raw (RationalDict Integer)) (def target (even-table raw))
      (def folding (table-fold raw Integer (lambda (_ value) value)))
      (def bridge (.call folding .isomorphism target
        (identity-wrapper (.@ raw Key)) (identity-wrapper Integer)))
      (def derived (.@ bridge Codomain))
      (def base (.call raw .<-list '((1 . 10) (2 . 20))))
      (def state (.call folding .ap base)) (def first (.call bridge .ap state))
      (def middle (.call raw .remove base 1))
      (check-exception (.call bridge .ap (.call folding .ap middle)) TypeError?)
      (check (eq? (.call bridge .ap state) first) => #t)
      (check-exception (.call bridge .apply-delta state (.call raw .diff base middle)) TypeError?)
      (check (eq? (.call bridge .ap state) first) => #t)
      (check (eq? (.call bridge .unap first) state) => #t)
      (def final (.call raw .acons 3 40 middle))
      (def batch (.call raw .compose-deltas
        (list (.call raw .diff base middle) (.call raw .diff middle final))))
      (def changed (.call bridge .apply-delta state batch))
      (check-equal? (.call derived .get changed) 60)
      (check (element? target (.call derived .unap changed)) => #t)
      (def restored (.call bridge .apply-delta (.call bridge .unap changed) (invert-table-delta batch)))
      (check-equal? (.call derived .get restored) 30)
      (check-equal? (.call raw .list<- (.call derived .unap restored)) (.call raw .list<- base)))
    (test-case "source recognizer causes and mutation protection precede aggregate and IO callbacks"
      (def raw (RationalDict Integer)) (def failure (list 'root-refused))
      (def refuse? #f) (def mutate? #f) (def calls 0) (def consumed 0) (def source #f)
      (set! source (.cc raw .element?: (lambda (root)
        (when refuse? (raise failure))
        (when mutate? (.set! source sexp 'interference))
        (element? raw root))))
      (def folding (table-fold source Integer (lambda (_ value) (set! calls (+ calls 1)) value)))
      (def base (.call raw .singleton 1 10)) (def state (.call folding .ap base))
      (def delta (.call raw .diff base (.call raw .acons 1 20 base)))
      (def action (service.fold-ledger-action folding state (lambda (value)
        (set! consumed (+ consumed 1)) value)))
      (set! calls 0) (set! refuse? #t)
      (check (eq? (cause-of (cut action delta)) failure) => #t)
      (check-equal? calls 0) (check-equal? consumed 0)
      (set! refuse? #f) (set! mutate? #t)
      (check-exception (action delta) (lambda (cause)
        (and (Error? cause) (equal? (Error-message cause) "object mutation during computation"))))
      (check-equal? calls 0) (check-equal? consumed 0)
      (set! mutate? #f)
      (check-equal? (.call folding .get (action delta)) 20)
      (check-equal? consumed 1))
    (test-case "service refinements preserve checked Functions through refused publication retry and inverse"
      (def input-callback (lambda (value) (+ value 1)))
      (def ledger (service.make-capacity-ledger
        (list (cons 0 (vector input-callback 10)) (cons 1 (vector input-callback 20)))
        source: even-table
        target: (lambda (table) (.cc table .element?: (lambda (root)
          (and (element? table root)
            (<= (.call table .foldl (lambda (_ row sum) (+ sum (car row))) 0 root) 50)))))))
      (def source (.@ ledger source)) (def folding (.@ ledger folding))
      (def bridge (.@ ledger transport)) (def derived (.@ bridge Codomain))
      (def state (.@ ledger state)) (def base (.call folding .unap state))
      ;; Requests reuse the leaf admitted by this ledger's exact Function Type.
      (def callback (vector-ref (.call source .ref base 0) 0))
      (def first (.call bridge .ap state)) (def consumed 0)
      (def action (service.fold-ledger-action bridge state (lambda (next)
        (set! consumed (+ consumed 1)) next)))
      (def bad (.call source .diff base (.call source .acons 0 (vector callback 45) base)))
      (check-exception (action bad) TypeError?) (check-equal? consumed 0)
      (check (eq? (.call bridge .ap state) first) => #t)
      (def final (.call source .acons 1 (vector callback 25)
        (.call source .acons 0 (vector callback 15) base)))
      (def retry (.call source .diff base final))
      (def changed (action retry))
      (check-equal? consumed 1) (check-equal? (.call derived .get changed) 40)
      (def row (.call (.@ ledger target) .ref (.call derived .unap changed) 1))
      (check (eq? (cdr row) callback) => #t) (check-equal? ((cdr row) 7) 8)
      (check-exception ((cdr row) "wrong") TypeError?)
      (def restored ((service.fold-ledger-action bridge (.call bridge .unap changed)
        (lambda (next) (set! consumed (+ consumed 1)) next)) (invert-table-delta retry)))
      (check-equal? consumed 2) (check-equal? (.call derived .get restored) 30)
      (check (eq? (cdr (.call (.@ ledger target) .ref (.call derived .unap restored) 1)) callback) => #t))))
