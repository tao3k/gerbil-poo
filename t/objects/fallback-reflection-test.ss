;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object (only-in :clan/poo/slot-observation %call-with-recorded-slot-reads))
(export fallback-reflection-test)

(def fallback-reflection-test
  (test-suite "Lazy fallback reflection"
    (test-case "local and reserved slots keep the delegate cold"
      (def constructions 0)
      (def value
        (.mix slots: (list (cons 'local ($constant-slot-spec 1)))
          (fallback-to
            (lambda ()
              (set! constructions (1+ constructions))
              (.o local: 2 remote: 3 reserved: 4))
            reserved: '(reserved))))
      (check-equal? (.slot? value 'local) #t)
      (check-equal? (.slot? value 'reserved) #f)
      (check-exception (.get value reserved) NoApplicableMethod?)
      (check-equal? constructions 0)
      (check-equal? (.slot? value 'remote) #t)
      (check-equal? (.slot? value 'missing) #f)
      (check-equal? (.get value remote) 3)
      (check-equal? (.get value local) 1)
      (check-equal? (filter (lambda (key) (memq key '(local remote reserved))) (.all-slots value))
                    '(local remote))
      (check-equal? constructions 1))
    (test-case "cyclic reflection refuses before publishing a query"
      (def value (fallback-to (lambda () value)))
      (check-exception (.slot? value 'missing) error?)
      (check-exception (.all-slots value) error?))
    (test-case "a new capture after an owner edit supplies current evidence"
      (def owner (.o field: 1))
      (def view (fallback-to (lambda () owner)))
      (defvalues (before old-reads)
        (%call-with-recorded-slot-reads (lambda () (.all-slots view))))
      (check-equal? (and (memq 'field before) #t) #t)
      (call-with-current-slot-reads old-reads void)
      (.putslot! owner 'added ($constant-slot-spec 2))
      (defvalues (after new-reads)
        (%call-with-recorded-slot-reads (lambda () (.all-slots view))))
      (check-equal? (and (memq 'added after) #t) #t)
      (check-exception (call-with-current-slot-reads old-reads void) error?)
      (call-with-current-slot-reads new-reads void))))
