(export cli-test)

(import
  :std/test
  (only-in :std/cli/getopt flag)
  ../cli)

(def cli-test
  (test-suite "test suite for clan/poo/cli"
    (test-case "POO option composition"
      (check (length (->getopt-spec options/backtrace)) => 1))
    (test-case "V19 standard fallback"
      (check (length (->getopt-spec [(flag 'quiet "--quiet")])) => 1))))
