;; Modular Arithmetics on Integer Ring Z/nZ
(define-type (Z/. @ [methods.marshal<-fixed-length-bytes UInt] n .validate)
  .element?: (cut uint-below? <> n)
  .length-in-bits: (integer-length .most-positive)
  .length-in-bytes: (n-bits->n-u8 .length-in-bits)
  .bytes<-: (cut uint->u8vector <> big .length-in-bytes)
  .<-bytes: (compose .validate u8vector->uint)
  .normalize: (λ (x) (modulo x n))
  .most-positive: (- n 1)
  .most-negative: 0
  .add-carry?: (λ (x y) (<= n (+ x y)))
  .add-negative-overflow?: false
  .sub-carry?: false
  .sub-negative-overflow?: (λ (x y) (< x y))
  .add: (λ (x y) (def z (+ x y)) (if (<= z .most-positive) z (- z n)))
  .sub: (λ (x y) (def z (- x y)) (if (negative? z) (+ z n) z))
  .neg: (λ (x) (if (zero? x) 0 (- n x)))
  .mul: (λ (x y) (.normalize (* x y)))
  .div: (lambda (x y) (.normalize (div-mod x y n)))
  .inv: (lambda (x) (.div 1 x))
  .intscale: .mul
  .succ: (λ (x) (if (= x .most-positive) 0 (1+ x)))
  .pred: (λ (x) (if (zero? x) .most-positive (1- x)))
  ;; function taking two entries a, b.
  ;; -- If a = b then returns 0;
  ;; -- If a > b then returns 1
  ;; -- If a < b then returns -1
  ;; (-- If the numbers are not comparable, returns #f)
  .comparer: number-comparer
  ;; TODO: range-checked arithmetics
  ;; add-valid? sum? mul-valid? product?
  .max: max
  .min: min)
(def (Z/ n) {(:: @ Z/.) (n) sexp: `(Z/ ,n)})



(define-type (UIntN. @ Z/. .length-in-bits .length-in-bytes .most-positive .validate)
  n: (arithmetic-shift 1 .length-in-bits)
  .element?: (cut uint-of-length? <> .length-in-bits)
  .bytes<-: (cut uint->u8vector <> big .length-in-bytes)
  .<-bytes: (compose .validate u8vector->uint)
  .normalize: (cut normalize-uint <> .length-in-bits)) ;; maybe faster? (λ (x) (bitwise-and x .most-positive))
(def UIntN<-length-in-bits (make-hash-table))
(def (UIntN .length-in-bits)
  (hash-ensure-ref UIntN<-length-in-bits .length-in-bits
                   (lambda () {(:: @ UIntN.) (.length-in-bits) sexp: `(UIntN ,.length-in-bits)})))
(define-type (UInt256 @ (UIntN 256)))

(define-type (IntN. @ Z/. .length-in-bits .length-in-bytes)
  n: (arithmetic-shift 1 .length-in-bits)
  .most-positive: (1- (arithmetic-shift 1 (1- .length-in-bits)))
  .most-negative: (- (arithmetic-shift 1 (1- .length-in-bits)))
  .element?: (cut sint-of-length? <> .length-in-bits)
  .bytes<-: (cut sint->u8vector <> big .length-in-bytes)
  .<-bytes: (cut u8vector->sint <> big .length-in-bytes)
  .normalize: (cut normalize-sint <> .length-in-bits)
  ;; Addition overflow occurs iff we add two operands of same sign and get result of opposite sign
  .add-overflow?: (λ (x y) (let (n (+ x y)) (not (= n (.normalize n))))) ;; TODO: simplify
  ;; Subtraction overflow occurs iff we subtract two operands of opposite sign and
  ;; get result of sign opposite the first operand, same as second operand.
  .sub-overflow?: (λ (x y) (let (n (- x y)) (not (= n (.normalize n))))) ;; TODO: simplify
  .succ: (λ (x) (if (= x .most-positive) .most-negative (1+ x)))
  .pred: (λ (x) (if (= x .most-negative) .most-positive (1- x))))

(def IntN<-length-in-bits (make-hash-table))
(def (IntN .length-in-bits)
  (hash-ensure-ref IntN<-length-in-bits .length-in-bits
                   (lambda () {(:: @ IntN.) (.length-in-bits) sexp: `(IntN ,.length-in-bits)})))
(define-type (JsInt @ (IntN 54))) ; From -2**53 to 2**53-1 included.
