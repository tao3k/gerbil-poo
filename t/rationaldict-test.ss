(export #t)

(import
  :std/test
  ../support/testing
  (only-in ../support/rationaldict
           list->rationaldict rationaldict-fold rationaldict-foldr)
  ../mop ../rationaldict ../type
  ./table-testing)

(def T (RationalDict String))

(def rationaldict-test
  (test-suite "test suite for clan/poo/rationaldict"
    (init-test-random-source!)
    (test-case "native RBTree folds preserve table order"
      (def dict (list->rationaldict '((3 . "three") (1 . "one") (2 . "two"))))
      (def collect-key (lambda (key _value keys) (cons key keys)))
      (check (rationaldict-fold collect-key '() dict) => '(3 2 1))
      (check (rationaldict-foldr collect-key '() dict) => '(1 2 3)))
    (table-tests T)))
