;;; Persistent storage and guarded layouts are exercised through real object APIs.
(export representation-test)
(import :std/test :std/error (only-in :gerbil/runtime/gambit string->uninterned-symbol) ../object ../prototype-map ../slot-layout
        (prefix-in ../examples/representation-service service.))

;; Match protocol refusal rather than accepting unrelated arithmetic exceptions.
(def (message? text)
  (lambda (cause) (and (Error? cause) (equal? (error-message cause) text))))

;; Every case composes storage, inheritance and invalidation instead of testing an
;; independent cache model that the object engine does not actually use.
(def representation-test
  (test-suite "persistent prototype maps and coherent access sites"
    (test-case "persistent replacement keeps repeated contributions and caller ownership"
      (let* ((input (list (cons 'a 1) (cons 'b #f) (cons 'a 2)))
             (old (prototype-map input)) (next (prototype-map-put old 'a 3)))
        (set-cdr! (car input) 99)
        (check-equal? (prototype-map-list old) '((a . 1) (b . #f) (a . 2)))
        (check-equal? (prototype-map-list next) '((a . 3) (b . #f) (a . 2)))
        (check-equal? (prototype-map-list (prototype-map-remove next 'a)) '((b . #f)))
        (let (view (prototype-map-list old)) (set-cdr! (car view) 50))
        (check-equal? (prototype-map-list old) '((a . 1) (b . #f) (a . 2)))))
    (test-case "uninterned identities do not collapse to printed names"
      (let* ((a (string->uninterned-symbol "same")) (b (string->uninterned-symbol "same"))
             (source (prototype-map (list (cons a 1) (cons b 2))))
             (next (prototype-map-put source a 3)))
        (check (eq? a b) => #f)
        (check-equal? (map cdr (prototype-map-list next)) '(3 2))))
    (test-case "live equal shapes share mapping but never receiver values"
      (let ((a (.o x: 1 disabled: #f)) (b (.o disabled: #f x: 2)) (site (make-slot-cache 'x)))
        (check-equal? (.ref/inline a site) 1)
        (check-equal? (.ref/inline b site) 2)
        (check (eq? (slot-layout-shape (object-layout a)) (slot-layout-shape (object-layout b))) => #t)
        (check-equal? (.ref/inline a site) 1)
        (check (.ref/inline a (make-slot-cache 'disabled)) => #f)))
    (test-case "shared-parent diamond invalidates vector and ordinary computed caches once"
      (let* ((root (.o x: 2)) (left (.o inherit: [root] left: 1))
             (right (.o inherit: [root] right: 2))
             (child (.o self: self inherit: [left right] (sum (+ (.get self x) (.get self left) (.get self right)))))
             (site (make-slot-cache 'sum)) (before (object-revision child)))
        (check-equal? (.ref/inline child site) 5)
        (.putslot! root 'x ($constant-slot-spec 7))
        (check-equal? (object-revision child) (+ before 1))
        (check-equal? (.ref/inline child site) 10)
        (check-equal? (.get child sum) 10)
        (.putslot! root 'x ($constant-slot-spec 2))
        (check-equal? (.ref/inline child site) 5)))
    (test-case "slot removal, defaults and topology replacement change effective layout"
      (let* ((parent (.o x: 4)) (child (.o inherit: [parent] x: 8)) (site (make-slot-cache 'x)))
        (check-equal? (.ref/inline child site) 8)
        (.removeslot! child 'x)
        (check-equal? (.ref/inline child site) 4)
        (.removeslot! parent 'x)
        (check-exception (.ref/inline child site) NoApplicableMethod?)
        (.putdefault! parent 'x #f)
        (check (.ref/inline child site) => #f)
        (.removedefault! parent 'x)
        (check-exception (.ref/inline child site) NoApplicableMethod?)
        (replace-object-supers! child [(.o x: 11 y: 9)])
        (check-equal? (.ref/inline child site) 11)
        (check-equal? (.get child y) 9)))
    (test-case "rejected edits retain revision and warmed guards"
      (let* ((obj (.o x: 5)) (site (make-slot-cache 'x)) (before (object-revision obj)))
        (check-equal? (.ref/inline obj site) 5)
        (check-exception (object-slots-set! obj '(("bad" . 1))) (message? "symbolic specification required"))
        (check-equal? (object-revision obj) before)
        (seal-object! obj)
        (check-exception (.putslot! obj 'x ($constant-slot-spec 9)) (message? "sealed prototype"))
        (check-equal? (object-revision obj) before)
        (check-equal? (.ref/inline obj site) 5)))
    (test-case "persistent clones rebind computed fields and keep checked FUN effects gated"
      (let* ((source (.cc service.Service capacity: 20)) (old (object-%slots source))
             (changed (.cc source capacity: 30)) (calls 0)
             (action (service.checked-total-action
               (lambda (_ amount) (set! calls (+ calls 1)) amount))))
        (check-equal? (action source) 63)
        (check-equal? (action changed) 93)
        (check-equal? (action source) 63)
        (check-equal? (prototype-map-list old) (object-slots source))
        (check-exception (action (.cc source capacity: -1)) error?)
        (check-equal? calls 3)))
    (test-case "cycle refusal leaves no successful value and permits a corrected retry"
      (let* ((obj (.o self: self (x (.get self x)))) (site (make-slot-cache 'x)))
        (check-exception (.ref/inline obj site) CyclicSlot?)
        (.putslot! obj 'x ($constant-slot-spec #f))
        (check (.ref/inline obj site) => #f)
        (.put! obj 'x 9)
        (check-equal? (.ref/inline obj site) 9)))))
