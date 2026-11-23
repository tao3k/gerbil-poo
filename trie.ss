;;; Pure Big Endian Patricia Trees (Tries), mapping natural integers to values.
;;; See article "Fast Mergable Integer Maps" by Chris Okasaki & Andrew Gill, 1998
;;; http://www.eecs.usma.edu/webs/people/okasaki/ml98maps.ps

(export (except-out #t uint-trie-shape-height stock-uint-trie-shape?))

(import
  (only-in ./object/slot-observation slot-read-observers-compatible? %slot-read-active?)
  :std/format :std/iter :std/number/misc :std/values
  ./support/base ./support/option
  ./object ./mop/prototype ./brace ./number ./type ./fun ./io ./table)

#;(defrule (aver cond msg expr ...)
  (unless cond
    (DBG msg expr ...)
    (with-catch/cont
     (lambda (_ k)
       (eprintf "In thread ~a:\n" (thread-name (current-thread)))
       (display-continuation-backtrace k (current-error-port) #t #t 20 20))
     (cut error "foo"))
    (##repl-debug)))

(include "trie/representation.ss")

(include "trie/changes.ss")

(include "trie/protocol.ss")

(include "trie/types.ss")
