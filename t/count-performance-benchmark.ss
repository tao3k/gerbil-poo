(export main)

(import
  :gerbil/runtime/gambit
  :std/iter
  ../object
  ../number
  ../type
  ../rationaldict
  ../trie)

(def RationalTable (RationalDict String))
(def TrieTable (SimpleTrie UInt UInt))

(def (measure thunk)
  (##gc)
  (def start (cpu-time))
  (def result (thunk))
  (values result (- (cpu-time) start)))

(def (repeat-count type table repetitions)
  (for/fold (sum 0) (_ (in-range repetitions))
    (+ sum (.call type .count table))))

(def (repeat-update type table value repetitions)
  (for/fold (last #f) (_ (in-range repetitions))
    (.call type .acons 0 value table)))

(def (run-case size repetitions)
  (def rational-entries
    (for/collect (key (in-range size))
      (cons key (number->string key))))
  (def trie-entries
    (for/collect (key (in-range size))
      (cons key key)))
  (def rational (.call RationalTable .<-list rational-entries))
  (def trie (.call TrieTable .<-list trie-entries))
  (repeat-count RationalTable rational 2)
  (repeat-count TrieTable trie 2)
  (repeat-update RationalTable rational "changed" 2)
  (repeat-update TrieTable trie 1 2)

  (defvalues (rational-sum rational-count-seconds)
    (measure (lambda () (repeat-count RationalTable rational repetitions))))
  (defvalues (trie-sum trie-count-seconds)
    (measure (lambda () (repeat-count TrieTable trie repetitions))))
  (defvalues (rational-updated rational-update-seconds)
    (measure (lambda () (repeat-update RationalTable rational "changed" repetitions))))
  (defvalues (trie-updated trie-update-seconds)
    (measure (lambda () (repeat-update TrieTable trie 1 repetitions))))

  (unless (and (= rational-sum (* size repetitions))
               (= trie-sum (* size repetitions))
               (= (.call RationalTable .count rational-updated) size)
               (= (.call TrieTable .count trie-updated) size))
    (error "count benchmark returned an invalid result" size))
  (displayln "TABLE_COUNT_RUNTIME_RECEIPT="
             [entries: size repetitions: repetitions
              rational-count-cpu-seconds: rational-count-seconds
              trie-count-cpu-seconds: trie-count-seconds
              rational-update-cpu-seconds: rational-update-seconds
              trie-update-cpu-seconds: trie-update-seconds]))

(def (main)
  (run-case 256 15000)
  (run-case 4096 1000)
  (run-case 16384 250))
