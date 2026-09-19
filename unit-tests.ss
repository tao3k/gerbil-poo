;;; Canonical Gerbil V19 test module for gerbil-poo.

(import
  :std/test/base
  ./t/cli-test
  ./t/debug-test
  ./t/object-test
  ./t/mop-test
  ./t/number-test
  ./t/type-test
  ./t/fq-test
  ./t/polynomial-test
  ./t/rationaldict-test
  ./t/trie-test)

(def suites
  [cli-test debug-test object-test mop-test number-test type-test fq-test polynomial-test
   rationaldict-test trie-test])
(def module
  (TestModule "clan/poo" suites [] void void))
(def harness
  (TestHarness "clan/poo" (TestConfig VERBOSITY-CHATTY #f) [module]))
(unless (test-result-ok? (test-run! harness))
  (error "gerbil-poo tests failed"))
