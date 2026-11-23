;;-*- Gerbil -*-
;;; Number Type descriptors for POO and its MOP

;; TODO: a better type hierarchy
;; TODO: clear contracts for + vs add (overflow check vs modular?), etc.
(export #t)

(import
  (only-in :std/error check-argument)
  (only-in :std/vector/u8vector big u8vector-double-ref u8vector-double-set!
           sint->u8vector u8vector->sint uint->u8vector u8vector->uint)
  (only-in :std/hash/misc hash-ensure-ref)
  (only-in :std/number/misc uint? uint-below? n-bits->n-u8 div-mod
           uint-of-length? sint-of-length? normalize-sint normalize-uint)
  (only-in :std/func compose)
  (only-in ./support/base λ number-comparer)
  (only-in ./support/io write-varuint read-varuint write-varint read-varint)
  (only-in ./mop/prototype define-type Type.)
  (only-in ./brace @method)
  (only-in ./io methods.marshal<-fixed-length-bytes))

;; TODO: basic interface for arithmetics, with proper type signatures.
(define-type (Number @ Type. .validate)
  .element?: number?
  .sexp<-: identity
  .add: +
  .sub: -
  .neg: -
  .mul: *
  .div: /
  .inv: /
  .zero: 0
  .one: 1
  .<-string: (lambda (x) (.validate (string->number x)))
  .string<-: number->string
  .=?: (cut = <> <>))

(define-type (Real @ Number)
  .element?: real?
  ;; function taking two entries a, b.
  ;; -- If a = b then returns 0;
  ;; -- If a > b then returns 1
  ;; -- If a < b then returns -1
  ;; (-- If the numbers are not comparable, returns #f)
  .comparer: number-comparer
  .non-negative?: (cut <= 0 <>)
  .sign: (cut number-comparer <> 0)
  .<-json: identity
  .json<-: identity
  .<: <
  .<=: <=
  .>: >
  .>=: >=
  .intscale: *
  .max: max
  .min: min)

(define-type (Integer @ [Real] .string<- .<-string)
  .element?: exact-integer?
  .json<-: (lambda (x) (if (<= (integer-length x) 53) x (.string<- x)))
  .<-json: (lambda (x) (if (exact-integer? x) x (.<-string x)))
  .marshal: write-varint
  .unmarshal: read-varint
  .bytes<-: sint->u8vector ;; note: encoding shorter (and thus different) from the marshalling
  .<-bytes: u8vector->sint
  .div: floor-quotient
  .inv: (lambda (x) (case x ((1 -1) x) (else (error "Cannot invert integer" x))))
  .mod: modulo
  .logand: bitwise-and
  .logor: bitwise-ior
  .logxor: bitwise-xor
  .lognot: bitwise-not ;; more bitwise operations, see Gambit
  .shift-left: arithmetic-shift
  .shift-right: (λ (x n) (arithmetic-shift x (- n)))
  ;; extract-bit-field test-bit-field? integer-length integer-length<? ...
  .succ: 1+
  .pred: 1-)

;; Unsigned values must satisfy recognition as well as representation metadata.
;; Function/container validation uses this predicate before marshal arithmetic.
(define-type (UInt @ Integer)
  .element?: (lambda (value) (and (exact-integer? value) (>= value 0)))
  .marshal: write-varuint
  .unmarshal: read-varuint
  .bytes<-: uint->u8vector ;; note: encoding shorter (and thus different) from the marshalling
  .<-bytes: u8vector->uint
  .sub: (lambda (x y) (if (>= x y) (- x y) (error "Overflow" '.sub x y)))
  .neg: (lambda (x) (if (zero? x) 0 (error "Overflow" '.neg x)))
  .pred: (lambda (x) (if (zero? x) (error "Overflow" '.pred x) (1- x)))
  .non-negative?: true)

;; IntegerRange between .most-negative and .most-positive included
(define-type (IntegerRange. @ Integer .most-negative .most-positive)
  .element?:
   (match (vector .most-negative .most-positive)
     ((vector #f #f) exact-integer?)
     ((vector _ #f) (λ (x) (and (exact-integer? x) (<= .most-negative x))))
     ((vector #f _) (λ (x) (and (exact-integer? x) (<= x .most-positive))))
     ((vector _ _) (λ (x) (and (exact-integer? x) (<= .most-negative x .most-positive))))))
(def (IntegerRange min: (.most-negative #f) max: (.most-positive #f))
  (check-argument (or (not .most-negative) (exact-integer? .most-negative))
                  "integer or false" .most-negative)
  (check-argument (or (not .most-positive) (exact-integer? .most-positive))
                  "integer or false" .most-positive)
  {(:: @ IntegerRange.) (.most-negative) (.most-positive)
   sexp: `(IntegerRange ,@(if .most-negative `(min: ,.most-negative) '())
                        ,@(if .most-positive `(max: ,.most-positive) '()))})

(def (unary-pre-op-check op check info x)
  (if (check x) (op x)
      (error "attempted operation but the arguments are out of range"
        (car info) (cdr info) x)))

(def (binary-pre-op-check op check info x y)
  (if (check x y) (op x y)
      (error "attempted operation but the arguments are out of range"
        (car info) (cdr info) x y)))

(def (unary-post-op-check op check info x)
  (def y (op x))
  (if (check y) y
      (error "attempted operation but the arguments are out of range"
        (car info) (cdr info) x)))

(def (binary-post-op-check op check info x y)
  (def z (op x y))
  (if (check z) z
      (error "attempted operation but the arguments are out of range"
        (car info) (cdr info) x y)))

(include "number/modular.ss")

(def (bytes<-double d)
  (def bytes (make-u8vector 8))
  (u8vector-double-set! bytes 0 d big)
  bytes)

(def (double<-bytes bytes)
  (u8vector-double-ref bytes 0 big))

(define-type (Float @ [methods.marshal<-fixed-length-bytes Real] .validate)
  .element?: flonum?
  .length-in-bytes: 8
  .json<-: identity
  .<-json: .validate
  .bytes<-: bytes<-double
  .<-bytes: double<-bytes)

(include "number/exponentiation.ss")
