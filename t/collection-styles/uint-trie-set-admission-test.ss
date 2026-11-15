;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/test
        (only-in :clan/poo/object .cc .call .ref)
        (only-in :clan/poo/mop TypeError?)
        (only-in :clan/poo/slot-observation
                 call-with-slot-read-observer slot-read-key slot-read-receiver)
        (only-in :clan/poo/trie UIntTrieSet make-Leaf))
(export uint-trie-set-admission-test)

(def (record-fold descriptor input)
  (reverse (.call descriptor .foldl cons [] input)))

(def uint-trie-set-admission-test
  (test-suite "UIntTrieSet fold admission"
    (test-case "stock fold preserves ascending keys and empty folds"
      (check-equal? (record-fold UIntTrieSet (.call UIntTrieSet .<-list '(32 5 0 5)))
                    '(0 5 32))
      (check-equal? (record-fold UIntTrieSet (.call UIntTrieSet .<-list [])) []))
    (test-case "backing-invalid input never reaches a refinement or fold callback"
      (def events [])
      (def descriptor (.cc UIntTrieSet .element?: (lambda (_)
        (set! events (cons 'recognize events))
        #t)))
      (def (fold key tail)
        (set! events (cons key events))
        tail)
      (def invalid (make-Leaf 'invalid-unit))
      (check-exception (.call UIntTrieSet .foldl fold [] invalid) TypeError?)
      (check-exception (.call descriptor .foldl fold [] invalid) TypeError?)
      (check-equal? events []))
    (test-case "custom refusal precedes fold and custom success visits once"
      (def events [])
      (def allowed? #f)
      (def descriptor (.cc UIntTrieSet .element?: (lambda (_)
        (set! events (cons 'recognize events))
        allowed?)))
      (def (fold key tail)
        (set! events (cons key events))
        tail)
      (def input (.call UIntTrieSet .<-list '(1 0)))
      (check-exception (.call descriptor .foldl fold [] input) TypeError?)
      (check-equal? events '(recognize))
      (set! events [])
      (set! allowed? #t)
      (.call descriptor .foldl fold [] input)
      (check-equal? (reverse events) '(recognize 0 1)))
    (test-case "observed stock folds admit the backing before invoking callbacks"
      (def input (.call UIntTrieSet .<-list '(5 0)))
      (def table (.ref UIntTrieSet 'Table))
      (def events [])
      (def (observe read)
        (when (and (eq? table (slot-read-receiver read))
                   (eq? '.element? (slot-read-key read)))
          (set! events (cons 'admit events))))
      (def (fold key tail)
        (set! events (cons key events))
        (cons key tail))
      (check-equal? (call-with-slot-read-observer observe
                      (lambda () (.call UIntTrieSet .foldl fold [] input)))
                    '(5 0))
      (check-equal? (reverse events) '(admit admit 0 5)))))
