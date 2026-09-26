(export mop-test)

(import
  :std/assert :std/format
  :std/test
  ../support/base ../support/debug ../support/testing
  ../object ../mop ../number ../type ../brace ../io)

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
    (test-case "source expressions extend through prototype slots"
      (def base (.o (sexp '(base))))
      (def derived (.mix (.o (sexp '(derived))) base))
      (check (:sexp base) => '(base))
      (check (:sexp derived) => '(derived))
      (check (:sexp base) => '(base)))
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
    (test-case "custom slot definitions observe incremental state"
      (def observed '())
      (def snapshot #f)
      (define-type (ObservingSlot @ Slot)
        .slot.define:
        (lambda (_ slot-name object)
          (set! observed (map car (object-slots object)))
          (.putslot! object slot-name ($constant-slot-spec 2))
          (.putslot! object 'c ($constant-slot-spec 99))
          (set! snapshot (object-slots object))))
      (def descriptors
        (object<-alist
         (list (cons 'a (.new Slot constant: 1))
               (cons 'b (.new ObservingSlot constant: 2))
               (cons 'c (.new Slot constant: 3)))))
      (def descriptor
        (object<-alist (list (cons 'slots descriptors)) supers: [Class.]))
      (def proto (.ref descriptor 'proto))
      (check-equal? observed '(a))
      (check-equal? (.all-slots proto) '(a b c))
      (check-equal? (.alist proto) '((a . 1) (b . 2) (c . 3)))
      (check-equal? (.ref (make-object slots: snapshot) 'c) 99))
    (test-case "Lenses"
      (check-equal?
       (.alist (.call Lens .modify (slot-lens 'a) 1+ {a: 1 b: 6}))
       '((a . 2) (b . 6))))
    (test-case "class JSON string round trip preserves the object contract"
      (define-type (JsonRecord @ Class.)
        slots: =>.+
        {name: {type: String}
         values: {type: (List Integer)}}
        sealed: #t)
      (def value (.new JsonRecord name: "example" values: '(1 2 3)))
      (def roundtrip
        (<-json-string JsonRecord (json-string<- JsonRecord value)))
      (check-equal? (.get roundtrip name) "example")
      (check-equal? (.get roundtrip values) '(1 2 3)))))
