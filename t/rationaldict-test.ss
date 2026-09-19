(export #t)

(import
  :std/test
  ../support/testing
  ../mop ../rationaldict ../type
  ./table-testing)

(def T (RationalDict String))

(def rationaldict-test
  (test-suite "test suite for clan/poo/rationaldict"
    (init-test-random-source!)
    (table-tests T)))
