test:
    gerbil test -v 3 t/cli-test.ss t/debug-test.ss t/object-test.ss t/mop-test.ss t/number-test.ss t/type-test.ss t/fq-test.ss t/polynomial-test.ss t/rationaldict-test.ss t/trie-test.ss

clean:
    gxi build.ss clean

build:
    gxi build.ss
