(export mop-test)

(import
  :std/assert :std/format
  :std/test
  ../support/base ../support/debug ../support/testing
  ../object ../mop ../number ../type ../brace)

(def mop-test
  (test-suite "test suite for clan/poo/mop"
    (test-case "simple tests"
      (map (λ-match ([type element] (assert! (element? type element))))
           [[Bool #t]
            [Integer 1984]
            [Integer -1984]])
      (map (λ-match ([type element] (assert! (not (element? type element)))))
           [[Bool 5]
            [Integer 3.14159]]))
    (test-case "class tests"
      (define-type (Amount @ Class.)
        slots: =>.+
        {quantity: {type: Number}
         unit: {type: Symbol}})
      (define-type (LocatedAmount @ Amount)
        slots: =>.+
        {location: {type: Symbol}
         unit: =>.+ {default: 'BTC}}
        sealed: #t)
      (.defgeneric (location x) slot: location default: 'unknown)
      (def stolen (.new LocatedAmount (location 'MtGox) (quantity 744408)))
      (def grand (.new Amount quantity: 1000 (unit 'USD)))
      (check-equal? (.get stolen location) 'MtGox)
      (check-equal? (.get stolen quantity) 744408)
      (check-equal? (.get stolen unit) 'BTC)
      (check-equal? (location stolen) 'MtGox)
      (check-exception (.@ grand location) true)
      (check-equal? (.get grand quantity) 1000)
      (check-equal? (.get grand unit) 'USD)
      (check-equal? (location grand) 'unknown)
      (map (λ-match ([type element] (validate type element)))
           [[Object stolen]
            [Amount stolen]
            [LocatedAmount stolen]
            [Amount (.new Amount (quantity 50) (unit 'ETH))]
            [Amount (.o (:: @ (.new Amount (unit 'USD))) (quantity 20))]
            [LocatedAmount (.new LocatedAmount (location 'Binance) (quantity 100))] ;; default unit
            [LocatedAmount (.o (location 'BitShares) (quantity 50) (unit 'ETH))] ;; missing .type is OK
            ])
      (map (λ-match ([type element] (assert! (not (element? type element)))))
           [[Object 5]
            [Amount (.new Amount (quantity 100))] ;; missing unit
            ]))
    (test-case "Lenses"
      (check-equal?
       (.alist (.call Lens .modify (slot-lens 'a) 1+ {a: 1 b: 6}))
       '((a . 2) (b . 6))))))
