;;; -*- Gerbil -*-
;;; The lightweight and full MOP imports share native type identity.

(export mop-core-test)
(import :std/test
        ../mop
        (prefix-in ../mop-core core-))

(def mop-core-test
  (test-suite "lightweight POO MOP identity"
    (test-case "public facade reexports the same native type objects"
      (check (eq? core-Type Type) => #t)
      (check (eq? core-Type. Type.) => #t)
      (check (eq? core-Class Class) => #t)
      (check (eq? core-Class. Class.) => #t)
      (check (eq? core-Bool Bool) => #t)
      (check (core-validate core-Bool #t) => #t))))
