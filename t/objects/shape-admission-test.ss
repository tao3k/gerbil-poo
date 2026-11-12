;;; Closed scalar metadata admission; ordinary methods retain their effects.
(export shape-admission-test)
(import :std/test :std/error :std/iter :clan/poo/object :clan/poo/slot-layout
        (only-in :clan/poo/support/base %graph-table-seed %with-graph-table-seeds
                 %with-application-table-seeds)
        (prefix-in (only-in :gerbil/runtime/mop slot-ref slot-set! object-class
                           &class-type-interface &class-type-interface-set!
                           &class-type-slot-table class-slot-offset) runtime.)
        (only-in :gerbil/runtime/hash symbol-hash-table::t HashTable::interface)
        (only-in :gerbil/runtime/interface &interface-descriptor-index prototype-table-table interface-instance-object)
        (only-in :gerbil/runtime/table symbolic-table-ref symbolic-table-set!)
        (only-in :gerbil/runtime/gambit default-random-source
                 string->uninterned-symbol))
(extern namespace: #f random-source-state-ref random-source-state-set!)
(extern namespace: clan/poo/slot-layout scalar-shape-routes-current? ordinary-shape-for-names
  intern-ordered-shape shapes shape-names shape-indices)

(def (prototype)
  (vector-ref (prototype-table-table (runtime.&class-type-interface symbol-hash-table::t))
    (&interface-descriptor-index HashTable::interface)))
(def (sample-state initial action)
  (def saved (random-source-state-ref default-random-source))
  (dynamic-wind
    (lambda () (random-source-state-set! default-random-source initial))
    (lambda ()
      (let* ((result (with-catch values action))
             (after (random-source-state-ref default-random-source)))
        (list result after)))
    (lambda () (random-source-state-set! default-random-source saved))))

(def shape-admission-test
  (test-suite "scalar shape admission ownership and effects"
    (test-case "standard cached adapter is admitted without consuming randomness"
      (make-hash-table-symbolic seed: 0)
      (def start (random-source-state-ref default-random-source))
      (def observed (sample-state start scalar-shape-routes-current?))
      (check-eq? (car observed) #t)
      (check-equal? (cadr observed) start))
    (test-case "cold adapter falls through to Gerbil and becomes eligible"
      (def saved (runtime.&class-type-interface symbol-hash-table::t))
      (def observed
        (dynamic-wind
          (lambda () (set! (runtime.&class-type-interface symbol-hash-table::t) #f))
          (lambda ()
            (let* ((before (scalar-shape-routes-current?))
                   (layout (make-slot-layout '(cold-adapter) #f absent-value))
                   (after (scalar-shape-routes-current?)))
              (list before after layout)))
          (lambda () (set! (runtime.&class-type-interface symbol-hash-table::t) saved))))
      (check-eq? (car observed) #f)
      (check-eq? (cadr observed) #t)
      (check-equal? (slot-layout-index (caddr observed) 'cold-adapter) 0))
    (test-case "empty hit miss and invalid scalar keep exactly one seed draw"
      (def anchor (make-slot-layout '(seed-hit) #f absent-value))
      ;; Admit the standard error machinery outside the random-state window.
      (with-catch void (lambda () (make-slot-layout '(17) #f absent-value)))
      (for (names (list [] '(seed-hit) (list (string->uninterned-symbol "seed-miss")) '(17)))
        (def start (random-source-state-ref default-random-source))
        (def expected (sample-state start (lambda () (make-hash-table-symbolic))))
        (def actual (sample-state start (lambda () (make-slot-layout names #f absent-value))))
        (check-equal? (cadr actual) (cadr expected)))
      (check-equal? (slot-layout-index anchor 'seed-hit) 0))
    (test-case "explicit zero seed is used on an intern miss without a second draw"
      (def key (string->uninterned-symbol "zero-seed"))
      (def start (random-source-state-ref default-random-source))
      (def observed (sample-state start (lambda () (intern-ordered-shape (list key) #f 0))))
      (check-equal? (cadr observed) start)
      (check-equal? (runtime.slot-ref (interface-instance-object (shape-indices (car observed))) 'seed) 0))
    (test-case "native shape seeding preserves ordinary seed effects at application entry"
      (make-slot-layout '(native-seed-entry) #f absent-value)
      (def initial (random-source-state-ref default-random-source))
      (def ordinary (sample-state initial (lambda () (make-slot-layout '(native-seed-entry) #f absent-value))))
      (def observed
        (sample-state initial (lambda ()
          (%with-graph-table-seeds (lambda ()
            (make-slot-layout '(native-seed-entry) #f absent-value)
            (make-slot-layout '(two-native-keys second) #f absent-value)
            (def refused
              (with-catch values (lambda ()
                (%with-application-table-seeds (lambda ()
                  (when (%graph-table-seed) (error "private seed reached application"))
                  (make-slot-layout '(native-seed-entry) #f absent-value)
                  (error "application refusal"))))))
            (unless (equal? (Error-message refused) "application refusal") (raise refused))
            (make-slot-layout '(native-seed-entry) #f absent-value)
            (%graph-table-seed))))))
      (check-equal? (car observed) 0)
      (check-equal? (cadr observed) (cadr ordinary))
      (check-eq? (%graph-table-seed) #f))
    (test-case "caller names cannot edit the intern key and receiver cells remain independent"
      (def names (list 'owned-key))
      (def first (make-slot-layout names #f absent-value))
      (set-car! names 'edited-key)
      (def second (make-slot-layout '(owned-key) #f absent-value))
      (check-eq? (slot-layout-shape first) (slot-layout-shape second))
      (check-equal? (shape-names (slot-layout-shape first)) '(owned-key))
      (slot-layout-set! first 0 #f)
      (check-eq? (slot-layout-ref first 0) #f)
      (check-eq? (slot-layout-ref second 0) absent-value))
    (test-case "equal printed names keep distinct symbol identities"
      (def left (string->uninterned-symbol "same-name"))
      (def right (string->uninterned-symbol "same-name"))
      (def a (make-slot-layout (list left) #f absent-value))
      (def b (make-slot-layout (list right) #f absent-value))
      (check-equal? (slot-layout-index a left) 0)
      (check-eq? (slot-layout-index a right) #f)
      (check-equal? (slot-layout-index b right) 0)
      (check-eq? (slot-layout-index b left) #f))
    (test-case "general admission keeps duplicates and rightmost refusal behavior"
      (def a (make-slot-layout '(two one two) #f absent-value))
      (def b (make-slot-layout '(one two) #f absent-value))
      (check-eq? (slot-layout-shape a) (slot-layout-shape b))
      (def failure (with-catch values (lambda () (make-slot-layout '(17 value 23) #f absent-value))))
      (check (contract-violation-error? failure) => #t)
      (check-equal? (cadr (memq value: (Error-irritants failure))) 23))
    (test-case "custom constructor methods retain their ordered callback effects"
      (def anchor (make-slot-layout '(method-key) #f absent-value))
      (def proto (prototype))
      (for (field '(ref set!))
        (def original (runtime.slot-ref proto field))
        (def events [])
        (def observed
          (dynamic-wind
            (lambda ()
              (runtime.slot-set! proto field
                (lambda arguments
                  (set! events (cons field events))
                  (apply original arguments))))
            (lambda ()
              (let* ((admitted (scalar-shape-routes-current?))
                     (guard-events events)
                     (_ (set! events []))
                     (reference (ordinary-shape-for-names '(method-key) #f))
                     (reference-events (reverse events))
                     (_ (set! events []))
                     (actual (make-slot-layout '(method-key) #f absent-value))
                     (actual-events (reverse events)))
                (list admitted guard-events reference-events actual-events reference actual)))
            (lambda () (runtime.slot-set! proto field original))))
        (check-eq? (car observed) #f)
        (check-equal? (cadr observed) [])
        (check-equal? (caddr observed) (list field))
        (check-equal? (list-ref observed 3) (list field))
        (check-eq? (list-ref observed 4) (slot-layout-shape anchor))
        (check-eq? (slot-layout-shape (list-ref observed 5)) (slot-layout-shape anchor))))
    (test-case "interner callback changing future adapters cannot move construction past it"
      (def proto (prototype))
      (def original-set (runtime.slot-ref proto 'set!))
      (def original-ref (runtime.slot-ref shapes 'ref))
      (def events [])
      (def observed
        (dynamic-wind
          (lambda ()
            (runtime.slot-set! shapes 'ref
              (lambda (backend key default)
                (set! events (cons 'interner events))
                (runtime.slot-set! proto 'set!
                  (lambda arguments
                    (set! events (cons 'late-set events))
                    (apply original-set arguments)))
                (original-ref backend key default))))
          (lambda ()
            (let* ((admitted (scalar-shape-routes-current?))
                   (_ (set! events []))
                   (reference (ordinary-shape-for-names (list (string->uninterned-symbol "late-a")) #f))
                   (before (reverse events))
                   (_ (runtime.slot-set! proto 'set! original-set))
                   (_ (set! events []))
                   (actual (make-slot-layout (list (string->uninterned-symbol "late-b")) #f absent-value))
                   (after (reverse events)))
              (list admitted before after reference actual)))
          (lambda ()
            (runtime.slot-set! shapes 'ref original-ref)
            (runtime.slot-set! proto 'set! original-set))))
      (check-eq? (car observed) #f)
      (check-equal? (cadr observed) '(interner))
      (check-equal? (caddr observed) '(interner))
      (check-equal? (length (shape-names (list-ref observed 3))) 1)
      (check-equal? (length (shape-names (slot-layout-shape (list-ref observed 4)))) 1))
    (test-case "moved slot metadata selects the unchanged fallback"
      (def wrapper (runtime.object-class shapes))
      (def slots (runtime.&class-type-slot-table wrapper))
      (def saved (symbolic-table-ref slots 'ref #f))
      (def anchor (make-slot-layout '(moved-route) #f absent-value))
      (def observed
        (dynamic-wind
          (lambda () (symbolic-table-set! slots 'ref (runtime.class-slot-offset wrapper 'set!)))
          (lambda ()
            (let* ((admitted (scalar-shape-routes-current?))
                   (reference (ordinary-shape-for-names '(moved-route) #f))
                   (actual (make-slot-layout '(moved-route) #f absent-value)))
              (list admitted reference actual)))
          (lambda () (symbolic-table-set! slots 'ref saved))))
      (check-eq? (car observed) #f)
      (check-eq? (cadr observed) (slot-layout-shape anchor))
      (check-eq? (slot-layout-shape (caddr observed)) (slot-layout-shape anchor)))))
