(def Bytes2 (BytesN 2))

(def type-test
  (test-suite "test suite for clan/poo/type"
    ;; Keep suite-private expansion helpers out of the published interface.
    (defrule (check-rep parse unparse rep obj)
      (begin ;;let ((rep rep) (obj obj))
        (check-equal? (parse rep) obj)
        (check-equal? (unparse obj) rep)))
    (test-case "And retains native Type identity and owns only its declaration spine"
      (def exports
        (parameterize ((current-expander-context (make-top-context)))
          (map module-export-name
               (module-context-export (core-import-module ':clan/poo/type)))))
      (check (memq '%ref-owned-list exports) => #f)
      (check (memq '%owned-list-slot-spec exports) => #f)
      (def borrowed-reader
        (parameterize ((current-expander-context (make-top-context)))
          (eval-syntax '(import :gerbil/core :clan/poo/type))
          (with-catch
            (lambda (cause) (if (unbound-global-exception? cause) #f (raise cause)))
            (lambda () (eval-syntax '%ref-owned-list)))))
      (check borrowed-reader => #f)
      (check (eq? (And Integer) Integer) => #t)
      (check (eq? (And) Top) => #t)
      (check-exception (And integer?) TypeError?)
      (def descriptor (And Integer Bool))
      (set-car! (.get descriptor types) #f)
      (check (eq? (car (.get descriptor types)) Integer) => #t)
      (check-exception (.put! descriptor 'types '()) Error?))
    (test-case "And runs ordered normalizers then checks every final membership"
      (def events '())
      (def first (.cc Type. .element?: integer?
        .validate: (lambda (value)
                     (set! events (cons 'first events))
                     (if (string? value) (string->number value) value))))
      (def second (.cc Type. .element?: (lambda (value) (and (integer? value) (> value 0)))
        .validate: (lambda (value) (set! events (cons 'second events)) (+ value 1))))
      (check (validate (And first second) "3") => 4)
      (check-equal? (reverse events) '(first second))
      (def zero (.cc Type. .element?: zero? .validate: (lambda (_) 0)))
      (def one (.cc Type. .element?: (lambda (n) (= n 1)) .validate: (lambda (_) 1)))
      (check-exception (validate (And zero one) 3) TypeError?)
      (def failure (.o cause: 'first-validator))
      (def reject (.cc Type. .element?: integer? .validate: (lambda (_) (raise failure))))
      (set! events '())
      (check-exception (validate (And reject second) 3) (lambda (cause) (eq? cause failure)))
      (check-equal? events '()))
    (test-case "And rechecks original read evidence after membership callbacks"
      (def first (.cc Type. .element?: integer? .validate: identity))
      (def second (.cc Type. .validate: identity
        .element?: (lambda (_)
                     (.put! first '.element? (lambda (_) #f)) #t)))
      (check-exception (validate (And first second) 3)
        (lambda (cause)
          (and (Error? cause) (equal? (Error-message cause) "stale slot dependency"))))
      ;; An enclosing composition must retain the inner Type's original reads.
      (.put! first '.element? integer?)
      (def inner (And first Integer))
      (def edit-after-inner
        (.cc Type. .element?: integer?
          .validate: (lambda (value)
                       (.put! first '.validate (lambda (n) (+ n 1))) value)))
      (check-exception (validate (And inner edit-after-inner) 3)
        (lambda (cause)
          (and (Error? cause) (equal? (Error-message cause) "stale slot dependency")))))
    (test-case "simple tests"

      (def MyRange (IntegerRange min: 100 max: 200))
      (map (λ-match ([type element] (assert! (element? type element))))
           [[MyRange 123]
            [MyRange 100]
            [MyRange 200]])
      (map (λ-match ([type element] (assert! (not (element? type element)))))
           [[MyRange 99]
            [MyRange 201]]))
    (test-case "BytesN test"
      (check-equal? (validate Bytes2 #u8(3 5)) #u8(3 5))
      (check-exception (validate Bytes2 'not-even-bytes) TypeError?)
      ;; too small
      (check-exception (validate Bytes2 #u8(3)) TypeError?)
      ;; too big
      (check-exception (validate Bytes2 #u8(3 5 8)) TypeError?)
      (check-rep (.@ Bytes2 .<-json) (.@ Bytes2 .json<-) "080d" #u8(8 13))
      (check-rep (.@ Bytes2 .<-bytes) (.@ Bytes2 .bytes<-) #u8(34 55) #u8(34 55)))
    (test-case "tuple test"
      (def UInt8 (UIntN 8))
      (def t (Tuple UInt8 UInt8 UInt8))
      (check-rep (.@ t .<-json) (.@ t .json<-) [5 8 13] #(5 8 13))
      (check-rep (.@ t .<-bytes) (.@ t .bytes<-) #u8(#x15 #x22 #x37) #(21 34 55)))
    (test-case "ordered vector mapping preserves callback order"
      (def seen [])
      (check-equal?
       (vector-map-in-order
        (lambda (index value)
          (set! seen (cons index seen))
          value)
        #(10 20 30))
       #(10 20 30))
      (check-equal? (reverse seen) '(0 1 2)))
    (test-case "ordered tuple JSON mapping validates arity"
      (def seen [])
      (check-equal?
       (vector-map2-in-order
        (lambda (index left right)
          (set! seen (cons index seen))
          (+ left right))
        #(1 2 3) #(10 20 30))
       #(11 22 33))
      (check-equal? (reverse seen) '(0 1 2))
      (check-exception (vector-map2-in-order + #(1 2) #(10)) true)
      (def t (Tuple (UIntN 8) (UIntN 8) (UIntN 8)))
      (check-equal? (.call t .<-json #(1 2 3)) #(1 2 3))
      (check-exception (.call t .<-json '(1 2)) true)
      (check-exception (.call t .<-json '(1 2 3 4)) true)
      (check-exception (.call t .json<- #(1 2)) true)
      (check-exception (.call t .json<- #(1 2 3 4)) true)
      (check-exception (.call t .sexp<- #(1 2)) true))
    (test-case "Enum V19 equal-hash indices preserve first occurrence"
      (def E (Enum "alpha" "beta" "alpha" (structured 1)))
      (check-equal? (.call E .element? "alpha") #t)
      (check-equal? (.call E .element? (list 'structured 1)) #t)
      (check-equal? (.call E .element? "missing") #f)
      (check-equal? (.call E .uint<- "alpha") 0)
      (check-equal? (.call E .uint<- (list 'structured 1)) 3)
      (check-equal? (.call E .<-json "alpha") 0)
      (check-equal? (.call E .bytes<- "alpha") #u8(0))
      (check-equal? (.call E .<-bytes #u8(3)) '(structured 1)))
    (test-case "Sum tag indices preserve the public variant model"
      (def UInt8 (UIntN 8))
      (def Message (Sum ok: UInt8 payload: Bytes2))
      (def ok (.call Message make 'ok 42))
      (def payload (.call Message make 'payload #u8(3 5)))
      (check-equal? (.@ Message variant-names) '(ok payload))
      (check-equal? (.call Message .bytes<- ok) #u8(0 42))
      (check-equal? (.call Message .bytes<- payload) #u8(1 3 5))
      (def decoded-ok (.call Message .<-bytes #u8(0 42)))
      (def decoded-payload (.call Message .<-bytes #u8(1 3 5)))
      (check-equal? (.@ decoded-ok tag) 'ok)
      (check-equal? (.@ decoded-ok value) 42)
      (check-equal? (.@ decoded-payload tag) 'payload)
      (check-equal? (.@ decoded-payload value) #u8(3 5)))
    (test-case "Sum roundtrips first, middle, and last tags at scale"
      (def variant-count 256)
      (def UInt8 (UIntN 8))
      (def tags
        (for/collect (tag-n (in-range variant-count))
          (string->symbol (format "variant-%d" tag-n))))
      (def variants
        (foldr (lambda (tag plist) [(make-keyword tag) UInt8 . plist]) [] tags))
      (def ScaledSum (apply Sum variants))
      (check-equal? (.@ ScaledSum variant-names) tags)
      (for (tag-n [0 (quotient variant-count 2) (1- variant-count)])
        (def value (.call ScaledSum make (list-ref tags tag-n) 42))
        (def bytes (.call ScaledSum .bytes<- value))
        (def decoded (.call ScaledSum .<-bytes bytes))
        (check-equal? (.@ decoded tag) (.@ value tag))
        (check-equal? (.@ decoded value) (.@ value value))))
    (test-case "function tests"
      (def (f x y) (values 1 x y))
      (check-equal? (values->list ((validate (Fun Number String Symbol <- String Symbol) f) "a" 'b))
                    '(1 "a" b))
      (check-exception ((validate (Fun Any <- String) f) 2 3) true)
      (check-exception ((validate (Fun Any <- Any Any) f) 2 3) true)
      (check-exception ((validate (Fun String Number Number <- Any Any) f) 2 3) true))
    (test-case "Record test"
      (def Foo (Record x: [(UIntN 8)] y: [Bytes32]))
      ;; TODO: test Record ...
      (void))
    ))

;; Return the original suites from this lexical scope.
(values type-test)
