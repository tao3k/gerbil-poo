;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/type TypeError?) :std/test
        (only-in :clan/poo/object .cc .call .ref .put!)
        (only-in :clan/poo/object/slot-observation
                 call-with-slot-read-observer slot-read-key slot-read-receiver
                 %call-with-recorded-slot-reads)
        (only-in :clan/poo/trie UIntTrieSet make-Leaf make-Branch make-Skip make-Empty Branch-right-set!))
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

(export uint-trie-shape-test)
(def uint-trie-shape-test
  (test-suite "Stock trie shape protocol and root ownership"
    (test-case "every nine-key subset agrees under observed and ordinary admission"
      (for-each
        (lambda (mask)
          (def keys (filter (lambda (key) (bit-set? key mask)) (iota 9)))
          (def tree (.call UIntTrieSet .<-list keys))
          (check-equal? (record-fold UIntTrieSet tree) keys)
          (check-equal? (call-with-slot-read-observer (lambda (_) (void))
                          (lambda () (record-fold UIntTrieSet tree))) keys))
        (iota 512)))
    (test-case "dependency capture retains each backing unwrap read"
      (def tree (.call UIntTrieSet .<-list '(0 1 5)))
      (def table (.ref UIntTrieSet 'Table))
      (let-values (((actual reads)
                    (%call-with-recorded-slot-reads
                      (lambda () (record-fold UIntTrieSet tree)))))
        (check-equal? actual '(0 1 5))
        (check-equal?
          (any (lambda (read)
                 (and (eq? (slot-read-receiver read) table)
                      (eq? (slot-read-key read) '.unwrap))) reads) #t)))
    (test-case "malformed shape refuses before the first fold callback"
      (for-each
        (lambda (tree)
          (def calls 0)
          (check-exception
            (.call UIntTrieSet .foldl
              (lambda (_ result) (set! calls (+ calls 1)) result) [] tree)
            true)
          (check-equal? calls 0))
        (list (make-Branch 1 (make-Leaf (void)) (make-Leaf (void)))
              (make-Branch 0 (make-Empty) (make-Leaf (void)))
              (make-Branch 1/2 (make-Leaf (void)) (make-Leaf (void)))
              (make-Skip 0 1 0 (make-Leaf (void)))
              (make-Skip 0 0 -1 (make-Leaf (void)))
              (make-Skip 0 0 2 (make-Leaf (void)))
              (make-Skip 1 0 0 (make-Leaf (void)))
              (make-Leaf 'invalid-unit))))
    (test-case "later mutation of an admitted root is checked again"
      (def tree (make-Branch 0 (make-Leaf (void)) (make-Leaf (void))))
      (check-equal? (record-fold UIntTrieSet tree) '(0 1))
      (Branch-right-set! tree (make-Skip 0 0 2 (make-Leaf (void))))
      (check-exception (record-fold UIntTrieSet tree) true))
    (test-case "stock backing method replacement keeps its callback and refusal"
      (def table (.ref UIntTrieSet 'Table))
      (def unwrap (.ref table '.unwrap))
      (def tree (.call UIntTrieSet .<-list '(0 1)))
      (def cause (list 'replacement-unwrap))
      (def calls 0)
      (unwind-protect
        (begin
          (.put! table '.unwrap
            (lambda (_)
              (set! calls (+ calls 1))
              (raise cause)))
          (check-equal? (eq? cause (with-catch values
                           (lambda () (record-fold UIntTrieSet tree)))) #t)
          (check-equal? calls 1))
        (.put! table '.unwrap unwrap))
      (check-equal? (record-fold UIntTrieSet tree) '(0 1)))))
