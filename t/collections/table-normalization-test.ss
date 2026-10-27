;;; Whole-primary normalization preserves atomic derived collection construction.
(export table-normalization-test)
(import :std/test :std/error :std/iter :clan/poo/object :clan/poo/mop :clan/poo/type :clan/poo/number :clan/poo/table :clan/poo/rationaldict
        :clan/poo/support/option (only-in :clan/poo/support/base number-comparer)
        (only-in :clan/poo/t/table-testing alist-table)
        (prefix-in :clan/poo/examples/service-collection service.))

;; Match a precise protocol refusal without accepting unrelated callback errors.
(def (message? text)
  (lambda (cause) (and (Error? cause) (equal? (Error-message cause) text))))

;; A paired service family admits both complete rank assignments. Child cooking
;; swaps ranks atomically and wraps the callback; no one-row business root is valid.
(def (fixture rank)
  (def callback (Fun Integer <- Integer))
  (def raw (RationalDict (Tuple rank callback)))
  (def source (.cc raw .element?: (lambda (root)
    (and (element? raw root) (= (.call raw .count root) 2)))))
  (defvalues (indexed _source comparer _key) (service.make-ordered-services source))
  (values (table-order indexed comparer) indexed source callback))

;; Compare rank/callback observations without depending on private index carriers.
(def (rank-of table root key) (vector-ref (.call table .ref root key) 0))

;; Complete normalization and fresh ownership publication share existing validators.
(def table-normalization-test
  (test-suite "complete source normalization through order and index views"
    (test-case "paired unique-index swaps normalize once and preserve unchanged identity"
      (def calls [])
      (def rank (.cc Integer .validate: (lambda (n)
        (set! calls (cons n calls)) (- 30 (validate Integer n)))))
      (defvalues (ordered indexed source signature) (fixture rank))
      (def raw (lambda (_) "wrong result"))
      (def root (.call ordered .<-list (list (cons 1 (vector 10 raw)) (cons 2 (vector 20 raw)))))
      (def checked (validate ordered root))
      (check-equal? (reverse calls) '(10 20))
      (check-equal? (list (rank-of ordered checked 1) (rank-of ordered checked 2)) '(20 10))
      (check-equal? (list (rank-of ordered root 1) (rank-of ordered root 2)) '(10 20))
      (check-equal? (some-value (.call indexed .index-ref/opt checked 'priority -20)) 1)
      (check-equal? (some-value (.call indexed .index-ref/opt checked 'priority -10)) 2)
      (check-exception ((vector-ref (.call ordered .ref checked 1) 1) 1) TypeError?)
      (check (eq? (vector-ref (.call ordered .ref root 1) 1) raw) => #t)
      ;; Function validation need not be idempotent: test identity reuse with
      ;; a source validator that actually returns its existing scalar leaves.
      (def plain (RationalDict Integer))
      (def builds 0)
      (def plain-indexed (table-indexes plain (list (.cc Type. name: 'identity unique?: #t
        table: (RationalDict (.@ plain Key)) project: (lambda (key _)
          (set! builds (+ builds 1)) key)))))
      ;; Observe a prepared cache before counting normalization work, so deferred
      ;; construction cannot be mistaken for a rebuild of an existing generation.
      (let* ((ready (.call plain-indexed .singleton 1 7))
             (initial (.call plain-indexed .index-ref/opt ready 'identity 1))
             (prepared builds))
        (check-equal? (some-value initial) 1)
        (check (eq? ready (validate plain-indexed ready)) => #t)
        (check-equal? builds prepared)))
    (test-case "all styles stage normalization before IO and retain failed source owners"
      (def fail? #t) (def effects 0)
      (def cause (list 'late-child-refusal))
      (def rank (.cc Integer .validate: (lambda (n)
        (when (and fail? (= n 20)) (raise cause)) (- 30 n))))
      (defvalues (ordered indexed source signature) (fixture rank))
      (def raw (lambda (n) (+ n 1)))
      (def root (.call ordered .<-list (list (cons 1 (vector 10 raw)) (cons 2 (vector 20 raw)))))
      (for (name '(Pure Mutable Linear Posh Classy))
        (def protocol (.ref (table-styles ordered) name))
        (def owner (.call protocol .ap root))
        (def action (service.admit-ledger-action protocol (lambda (value)
          (set! effects (+ effects 1)) value)))
        (set! fail? #t)
        (check-exception (action root) (lambda (value) (eq? value cause)))
        (check-equal? (rank-of protocol owner 1) 10)
        (set! fail? #f)
        (def admitted (action root))
        (check-equal? (rank-of protocol admitted 1) 20)
        (check-equal? ((vector-ref (.call protocol .ref admitted 1) 1) 2) 3)
        (check-equal? (rank-of protocol owner 1) 10))
      (check-equal? effects 5))
    (test-case "normalized unique conflicts retain complete old caches and permit retry"
      (def collide? #t)
      (def rank (.cc Integer .validate: (lambda (n) (if collide? 10 (- 30 n)))))
      (defvalues (ordered indexed source signature) (fixture rank))
      (def f (lambda (n) n))
      (def root (.call ordered .<-list (list (cons 1 (vector 10 f)) (cons 2 (vector 20 f)))))
      (check-exception (validate ordered root) table-index-conflict?)
      (check-equal? (some-value (.call indexed .index-ref/opt root 'priority -20)) 2)
      (set! collide? #f)
      (def checked (validate ordered root))
      (check-equal? (some-value (.call indexed .index-ref/opt checked 'priority -20)) 1))
    (test-case "view validation still honors inherited child Types and result refinements"
      (def source (RationalDict Integer))
      (def comparer (table-comparer (.@ source Key) number-comparer))
      (def ordered (table-order source comparer))
      (def cooked (.cc Integer .validate: abs))
      (def inherited (.cc ordered Value: cooked))
      (def root (.call source .singleton 1 -10))
      (check-equal? (.call inherited .ref (validate inherited root) 1) 10)
      (def denied (.cc ordered .element?: (lambda (_) #f)))
      (check-exception (validate denied root) TypeError?))
    (test-case "validation holds receiver origins and rejects stale views before children"
      (def calls 0) (def ordered #f)
      (def value (.cc Integer .validate: (lambda (n)
        (set! calls (+ calls 1)) (.set! ordered revision-marker 'mutation) n)))
      (def source (RationalDict value))
      (set! ordered (table-order source (table-comparer (.@ source Key) number-comparer)))
      (def root (.call source .singleton 1 10))
      (def revision (object-revision ordered))
      (check-exception (validate ordered root) (message? "object mutation during computation"))
      (check-equal? (object-revision ordered) revision)
      (check-equal? calls 1)
      (.set! source sexp 'changed-source)
      (check-exception (validate ordered root) (message? "stale table order"))
      (check-equal? calls 1))
    (test-case "Set elements retain source validation and callable wrappers"
      (def signature (Fun Integer <- Integer))
      (def source (alist-table signature Unit))
      (def indexed (table-indexes source []))
      (def set (.cc Set<-Table. Table: indexed sexp: 'indexed-callbacks))
      (def raw (lambda (_) 'bad))
      (def root (.call set .singleton raw))
      (def checked (validate set root))
      (def callback (car (.call set .list<- checked)))
      (check-exception (callback 1) TypeError?)
      (check (eq? (car (.call set .list<- root)) raw) => #t)))

)
