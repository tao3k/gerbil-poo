(export method-combination-test)
(import :std/test :std/iter (only-in :std/values first-value)
        ../object ../support/option (only-in ../mop Any Bool)
        (prefix-in ../method-combination combination.) (prefix-in ../multimethod dispatch.)
        (prefix-in ../dispatch-extension extension.) (prefix-in ../declarative-metadata metadata.)
        (prefix-in ../cyclic-publication publication.)
        (prefix-in ../examples/service-combination combined.) (prefix-in ../examples/service-bundle bundle.))
;; Capture only the test's refusal payload; it never becomes successful evidence.
(def (caught thunk) (try (thunk) #f (catch (cause) cause)))
;; The ordinary universal path selects all contributions in explicit insertion order.
(def path (list dispatch.any))
;; Complete carrier/qualifier/effect-order/short-circuit and joint revision controls.
(def method-combination-test
  (test-suite "Appendix B native method combination alignment"
    (test-case "standard effective ordering next and warm guards"
      (def trace [])
      (def (note value) (set! trace (cons value trace)))
      (def base (dispatch.standard (list Any) Any (lambda (_) '((Child Parent)))))
      (def parent (list (dispatch.prototype 'Parent)))
      (def child (list (dispatch.prototype 'Child)))
      (def generic
        (dispatch.contribute
          (dispatch.contribute
            (dispatch.contribute
              (dispatch.contribute
                (dispatch.contribute
                  (dispatch.register base parent (combination.primary (lambda (_ arg) (note 'base) (list arg))))
                  child (combination.primary (lambda (next _) (note 'primary) (cons 'child (next)))))
                child (combination.before (lambda (_) (note 'before-child))))
              parent (combination.before (lambda (_) (note 'before-parent))))
            child (combination.after (lambda (_) (note 'after-child))))
          parent (combination.after (lambda (_) (note 'after-parent)))))
      (def guarded (dispatch.register-when generic child (lambda (arg) (> arg 10))
        (combination.around (lambda (next _) (note 'around-in) (let (value (next)) (note 'around-out) value)))))
      (defvalues (result warm) (dispatch.call guarded 20))
      (check-equal? result '(child 20))
      (check-equal? (reverse trace) '(around-in before-child before-parent primary base after-parent after-child around-out))
      (set! trace [])
      (check-equal? (first-value (dispatch.call warm 1)) '(child 1))
      (check-equal? (reverse trace) '(before-child before-parent primary base after-parent after-child))
      (check-exception (dispatch.register base child (lambda (_) 1)) true)
      (check-exception (dispatch.register base child (combination.item (lambda (_) 1))) true))
    (test-case "simple policies short circuit empties options and around"
      (for ((policy (list combination.sum combination.collect combination.append-policy
                         combination.all-policy combination.any-policy combination.last-policy combination.maximum combination.minimum))
            (expected (list 0 [] [] #t #f #f #f #f)))
        (check-equal? (combination.simple-effective policy [] []) expected))
      (check-equal? (combination.simple-effective combination.last-policy (list (combination.item (lambda () #f))) []) (some #f))
      (check-equal? (combination.simple-effective combination.maximum
        (map (lambda (n) (combination.item (lambda () n))) '(-9 -2 -8)) []) (some -2))
      (def effects [])
      (def generic (dispatch.simple (list Any) Bool (lambda (_) '((Object))) combination.all-policy))
      (def tail (dispatch.register generic path (combination.item (lambda (_) (error "short circuit suffix ran")))))
      (def stopped (dispatch.contribute tail path (combination.item (lambda (_) (set! effects '(first)) #f))))
      (defvalues (result warm) (dispatch.call stopped 1))
      (check-equal? result #f)
      (check-equal? effects '(first))
      (check-equal? (first-value (dispatch.call warm 1)) #f)
      (check-exception (dispatch.register generic path (combination.before (lambda (_) #t))) true)
      (def with-around (list (combination.around (lambda (next) (+ 10 (next))))
                            (combination.item (lambda () 2)) (combination.item (lambda () 3))))
      (check-equal? (combination.simple-effective combination.sum with-around []) 15)
      (check-exception (combination.simple-effective combination.all-policy (list (combination.item (lambda () 'truthy))) []) true))
    (test-case "negative checking inspects qualified data without invoking bodies"
      (def executed 0)
      (def generic (dispatch.standard (list Any) Any (lambda (_) '((Object)))))
      (def installed (dispatch.register generic path (combination.primary (lambda (_ arg) (set! executed (+ 1 executed)) arg))))
      (def conflict (caught (cut extension.check installed (list (extension.shape '((Object)))))))
      (check (extension.conflict? conflict) => #t)
      (check-equal? executed 0)
      (check-equal? (first-value (dispatch.call installed 7)) 7))
    (test-case "qualified standard and simple services compose with contract specialization and joint approval"
      (for (model (list combined.standard-model combined.simple-model))
        (def policy (.cc bundle.Policy. capacity: 10 price: 3 invoice: "invoice:1"))
        (defvalues (old issue) (combined.start model policy))
        (check-equal? issue #f)
        (defvalues (reserved warm) (publication.invoke old 'reserve 2))
        (check-equal? reserved '(ok 8 #t))
        (defvalues (revised accepted) (combined.revise model warm (.cc policy capacity: 20 invoice: "invoice:2")))
        (check-equal? accepted #f)
        (check-equal? (first-value (publication.invoke revised 'reserve 3)) '(ok 17 #t))
        (check-equal? (first-value (publication.invoke revised 'cancel "customer" #t)) '("customer" "invoice:2"))
        (defvalues (held refused) (combined.revise model warm (.cc policy cache-limit: 0)))
        (check (eq? held warm) => #t)
        (check-equal? (publication.failure-stage refused) 'admission)))))
