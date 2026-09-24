(export #t)

(import
  :std/iter
  :std/test
  ../support/testing
  (only-in ../support/rationaldict
           list->rationaldict rationaldict-ref rationaldict-fold rationaldict-foldr
           rationaldict=?)
  (only-in ../object .call)
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
    (test-case "rational set iterator respects an inclusive lower bound"
      (def set (.call RationalSet .<-list '(-3 -1 1 3 5)))
      (check (for/collect (element (.call RationalSet .iter<- set)) element)
             => '(-3 -1 1 3 5))
      (check (for/collect (element (.call RationalSet .iter<- set from: 0)) element)
             => '(1 3 5))
      (check (for/collect (element (.call RationalSet .iter<- set from: 3)) element)
             => '(3 5))
      (check (for/collect (element (.call RationalSet .iter<- set from: -1/2)) element)
             => '(1 3 5))
      (check (for/collect (element (.call RationalSet .iter<- set from: 6)) element)
             => '())
      (def dict (.call T .<-list '((-1 . "minus one") (1 . "one") (3 . "three"))))
      (check (for/collect (entry (.call T .iter<- dict 1)) entry)
             => '((1 . "one") (3 . "three")))
      (using ((iterator (.call RationalSet .iter<- set from: 6) :- Iterator))
        (check (iterator.next!) => #!eof)
        (check (iterator.next!) => #!eof)))
    (table-tests T)))
