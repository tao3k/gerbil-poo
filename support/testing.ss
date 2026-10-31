;;; POO acceptance helpers use the standard TestSuite and typed property protocols.

(export (except-out #t check-typed-property report-typed-property require-kernel-passed))

(import
  (only-in :std/error check-argument)
  (only-in :std/encoding/hex hex-encode)
  (only-in :std/iter for/collect in-range)
  (only-in :std/test do-check!)
  (only-in :std/func compose)
  (only-in ../io module-action)
  (only-in ../type Tuple)
  (only-in ../object .get)
  ./io)

;; Ordinary assertions do not demand the typed generator engine. Standard IO
;; resolves its current binding on each actual check; compose/list forwards the
;; exact argument row, including keyword escapes, without a second dispatcher.
(def check-typed-property
  (compose (module-action "clan/poo/testing/type" 'clan/poo/testing/type#check-property) list))
;; Formatting remains demand-driven too; standard loading owns readiness/errors.
(def report-typed-property
  (compose (module-action "clan/poo/testing/type" 'clan/poo/testing/type#report-diagnostics) list))

;; Keep the existing standard TestError admission policy at the optional owner;
;; ordinary helpers do not import the generic property engine just for this gate.
(def require-kernel-passed
  (compose (module-action "clan/poo/testing/property/test"
    'clan/poo/testing/property/test#require-passed) list))

(defrule (assert-equal! actual expected)
  (let ((actual-value actual) (expected-value expected))
    (unless (equal? actual-value expected-value)
      (error "Comparison failed" 'actual 'expected actual-value expected-value))))

(def (roman-numeral<-digit digit (i "I") (v "V") (x "X"))
  (case digit
    ((0) "") ((1) i) ((2) (string-append i i))
    ((3) (string-append i i i)) ((4) (string-append i v))
    ((5) v) ((6) (string-append v i))
    ((7) (string-append v i i)) ((8) (string-append v i i i))
    ((9) (string-append i x))
    (else (error "incorrect digit" digit))))
(def (roman-numeral<-integer n)
  (check-argument (and (exact-integer? n) (<= 1 n 3999))
                  "integer convertible to roman numeral" n)
  (def units (modulo n 10))
  (def tens (modulo (quotient n 10) 10))
  (def hundreds (modulo (quotient n 100) 10))
  (def thousands (quotient n 1000))
  (string-append
   (roman-numeral<-digit thousands "M" "" "")
   (roman-numeral<-digit hundreds "C" "D" "M")
   (roman-numeral<-digit tens "X" "L" "C")
   (roman-numeral<-digit units "I" "V" "X")))

(def (0x<-random-source (source default-random-source))
  (hex-encode
   (call-with-output-u8vector
    (lambda (port)
      (for-each (lambda (n) (write-uint-u8vector n 4 port))
                (vector->list (random-source-state-ref source)))))))
(def (init-test-random-source!)
  (random-source-randomize! default-random-source)
  (displayln "GERBIL_TEST_RANDOM_SOURCE=" (0x<-random-source)))

;; Assert the actual execution retained by the existing typed Record. Missing
;; execution is an unconditional preparation failure; rendering cannot create it.
;; This also admits reports delivered by ordinary FUN/Reader actions.
(def (require-property-passed report diagnostics: (formatter report-typed-property))
  (def execution (.get report execution))
  (require-kernel-passed execution diagnostics: (lambda (_) (formatter report))
    refusal: (and (not execution) (report-typed-property report))))

;; Typed assertions execute one runner and admit its current report through the
;; same standard boundary as generic checks. This form never returns report data.
(defrule (check-property descriptor predicate options ...)
  (do-check! descriptor descriptor
    (require-property-passed (check-typed-property descriptor predicate options ...))))

;; Fixed Type products reuse Tuple derivation; named bindings remain hygienic.
;; Dependent/refined domains use their existing explicit .generator composition.
(defrule (define-property name ((argument descriptor) ...) body ...)
  (def (name . options)
    (do-check! name name
      (require-property-passed
        (apply check-typed-property (Tuple descriptor ...)
          (lambda (row) (apply (lambda (argument ...) body ...) (vector->list row)))
          name: 'name options)
        diagnostics: (lambda (report) (report-typed-property report bindings: '(argument ...)))))))
