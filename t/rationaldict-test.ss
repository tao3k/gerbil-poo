(export #t)

(import
  :std/test
  ../support/testing
  (only-in ../support/rationaldict
           list->rationaldict rationaldict-ref rationaldict-fold rationaldict-foldr
           rationaldict=?)
  ../mop ../rationaldict ../type
  ./table-testing)

(def T (RationalDict String))

(def rationaldict-test
  (test-suite "test suite for clan/poo/rationaldict"
    (init-test-random-source!)
    (test-case "native RBTree folds preserve table order"
      (def dict (list->rationaldict '((3 . "three") (1 . "one") (2 . "two"))))
      (def duplicate (list->rationaldict '((1 . "earlier") (2 . "two") (1 . "later"))))
      (def collect-key (lambda (key _value keys) (cons key keys)))
      (check (rationaldict-fold collect-key '() dict) => '(3 2 1))
      (check (rationaldict-foldr collect-key '() dict) => '(1 2 3))
      (check (rationaldict-ref duplicate 1) => "later"))
    (test-case "native RBTree iterators compare dictionaries"
      (def empty (list->rationaldict '()))
      (def left (list->rationaldict '((3 . "three") (1 . "one") (2 . "two"))))
      (def same (list->rationaldict '((2 . "two") (3 . "three") (1 . "one"))))
      (def shorter (list->rationaldict '((1 . "one") (2 . "two"))))
      (def different-key (list->rationaldict '((1 . "one") (2 . "two") (4 . "three"))))
      (def different-value (list->rationaldict '((1 . "ONE") (2 . "two") (3 . "three"))))
      (check (rationaldict=? empty empty) => #t)
      (check (rationaldict=? left same) => #t)
      (check (rationaldict=? left shorter) => #f)
      (check (rationaldict=? shorter left) => #f)
      (check (rationaldict=? left different-key) => #f)
      (check (rationaldict=? left different-value) => #f)
      (check (rationaldict=? left different-value string-ci=?) => #t))
    (table-tests T)))
