(export method-combination-test)
(import :std/test :std/iter (only-in :std/values first-value)
        ../object ../support/option (only-in ../mop Any Bool) (only-in ../number Integer)
        (prefix-in ../method-combination combination.) (prefix-in ../multimethod dispatch.)
        (prefix-in ../dispatch-extension extension.) (prefix-in ../declarative-metadata metadata.)
        (prefix-in ../cyclic-publication publication.) (prefix-in ../generic-family family.)
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
    (test-case "forward payload preserves dispatch and guards while checking replacements"
      (def resolutions 0)
      (def guards 0)
      (def trace [])
      (def (note value) (set! trace (cons value trace)))
      (def seed (dispatch.forwarding-standard Any Integer Integer
        (lambda (d) (set! resolutions (+ 1 resolutions)) (check-equal? d 'request) '((Child Parent)))))
      (def child (list (dispatch.prototype 'Child)))
      (def parent (list (dispatch.prototype 'Parent)))
      (def generic (metadata.install seed
        (list
          (metadata.replace "base" parent (combination.forward-primary (lambda (_ d p) (note (list 'base d p)) p)))
          (metadata.guarded "child" child (lambda (_ p) (set! guards (+ 1 guards)) (> p 0))
            (combination.forward-primary (lambda (next d p) (note (list 'primary d p)) (next (some (+ p 1))))))
          (metadata.contribute "before" child (combination.forward-before (lambda (_ p) (note (list 'before p)))))
          (metadata.contribute "after" child (combination.forward-after (lambda (_ p) (note (list 'after p)))))
          (metadata.contribute "around" child (combination.forward-around (lambda (next _ p) (next (some (+ p 10)))))))))
      (defvalues (result warm) (dispatch.call generic 'request 5))
      (check-equal? result 16)
      (check-equal? resolutions 1)
      (check-equal? guards 1)
      (check-equal? (reverse trace) '((before 15) (primary request 15) (base request 16) (after 15)))
      (check-equal? (first-value (dispatch.call warm 'request 0)) 10)
      (check-equal? guards 2)
      (set! trace [])
      (check-exception (extension.check generic (list (extension.shape '((Child Parent))))) true)
      (check-equal? trace [])
      (check-equal? guards 2)
      (def suffix-ran 0)
      (def invalid (dispatch.register
        (dispatch.register seed parent (combination.forward-primary
          (lambda (_ __ p) (set! suffix-ran (+ suffix-ran 1)) p))) child
        (combination.forward-primary (lambda (next _ __) (next (some "invalid"))))))
      (check-exception (dispatch.call invalid 'request 2) true)
      (check-equal? suffix-ran 0)
      (check-exception (dispatch.register seed child (combination.primary (lambda (_ __) 1))) true)
      (for ((replacement (list #f (some #f))) (expected '(#t #f)))
        (def optional (dispatch.forwarding-standard Any Bool Bool (lambda (_) '((Child)))))
        (def selected (dispatch.contribute
          (dispatch.register optional child (combination.forward-primary (lambda (_ __ p) p))) child
          (combination.forward-around (lambda (next _ __) (next replacement)))))
        (check-equal? (first-value (dispatch.call selected 'request #t)) expected)))
    (test-case "inner and Simula order omission failures and negative watches"
      (def trace [])
      (def (note value) (set! trace (cons value trace)))
      (def child (list (dispatch.prototype 'Child)))
      (def parent (list (dispatch.prototype 'Parent)))
      (def seed (dispatch.inner (list Any) Any (lambda (_) '((Child Parent))) (lambda (_) (note 'terminal) 7)))
      (def generic (dispatch.register (dispatch.register seed parent
        (lambda (inner _) (note 'parent-in) (let (value (inner)) (note 'parent-out) value))) child
        (lambda (inner _) (note 'child-in) (let (value (inner)) (note 'child-out) value))))
      (check-equal? (first-value (dispatch.call generic 0)) 7)
      (check-equal? (reverse trace) '(parent-in child-in terminal child-out parent-out))
      (set! trace [])
      (check-equal? (first-value (dispatch.call (dispatch.register generic parent (lambda (_ __) (note 'stop) 9)) 0)) 9)
      (check-equal? trace '(stop))
      (def simulation (dispatch.simula (list Any) (lambda (_) '((Child Parent)))))
      (def bodies (dispatch.register (dispatch.register simulation parent
        (combination.simula-body (lambda (_) (note 'parent-prefix)) (lambda (_) (note 'parent-suffix)))) child
        (combination.simula-body (lambda (_) (note 'child-prefix)) (lambda (_) (note 'child-suffix)))))
      (set! trace [])
      (dispatch.call bodies 0)
      (check-equal? (reverse trace) '(parent-prefix child-prefix child-suffix parent-suffix))
      (set! trace [])
      (check-exception (extension.check bodies (list (extension.shape '((Child Parent))))) true)
      (check-equal? trace [])
      (def failing (dispatch.register bodies child
        (combination.simula-body (lambda (_) (note 'failure) (error "prefix failed")) (lambda (_) (error "suffix ran")))))
      (check-exception (dispatch.call failing 0) true)
      (check-equal? (reverse trace) '(parent-prefix failure)))
    (test-case "negative checking inspects qualified data without invoking bodies"
      (def executed 0)
      (def generic (dispatch.standard (list Any) Any (lambda (_) '((Object)))))
      (def installed (dispatch.register generic path (combination.primary (lambda (_ arg) (set! executed (+ 1 executed)) arg))))
      (def conflict (caught (cut extension.check installed (list (extension.shape '((Object)))))))
      (check (extension.conflict? conflict) => #t)
      (check-equal? executed 0)
      (check-equal? (first-value (dispatch.call installed 7)) 7))
    (test-case "qualified standard and simple services compose with contract specialization and joint approval"
      (for (model (list combined.standard-model combined.simple-model combined.forwarding-model combined.inner-model combined.simula-model))
        (def policy (.cc bundle.Policy. capacity: 10 price: 3 invoice: "invoice:1"))
        (defvalues (old issue) (combined.start model policy))
        (check-equal? issue #f)
        (defvalues (reserved warm) (publication.invoke old 'reserve 2))
        (check-equal? reserved '(ok 8 #t))
        ;; Enrichment and preflight add an invoice dependency to reserve; an
        ;; invoice-only revision must rebuild that generic, retaining quote.
        (defvalues (invoice-only invoice-issue) (combined.revise model warm (.cc policy invoice: "invoice:2")))
        (check-equal? invoice-issue #f)
        (def enriched? (memq model (list combined.forwarding-model combined.simula-model)))
        (check-equal? (family.family-built (publication.version-family invoice-only))
          (if enriched? '(reserve cancel) '(cancel)))
        (check-equal? (first-value (publication.invoke invoice-only 'reserve 2)) '(ok 8 #t))
        (defvalues (revised accepted) (combined.revise model warm (.cc policy capacity: 20 invoice: "invoice:2")))
        (check-equal? accepted #f)
        (check-equal? (first-value (publication.invoke revised 'reserve 3)) '(ok 17 #t))
        (check-equal? (first-value (publication.invoke revised 'cancel "customer" #t)) '("customer" "invoice:2"))
        (defvalues (held refused) (combined.revise model warm (.cc policy cache-limit: 0)))
        (check (eq? held warm) => #t)
        (check-equal? (publication.failure-stage refused) 'admission)
        (defvalues (protected negative) (combined.revise model warm (.cc policy forbidden-cancel: #t)))
        (check (eq? protected warm) => #t)
        (check-equal? (publication.failure-stage negative) 'services)
        (check-equal? (family.failure-key (publication.failure-cause negative)) 'cancel)
        (check-equal? (family.failure-stage (publication.failure-cause negative)) 'negative)))))
