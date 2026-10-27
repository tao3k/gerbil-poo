(export typed-method-declaration-test)
(import :std/test :std/error :clan/poo/object :clan/poo/mop :clan/poo/brace :clan/poo/reflection :clan/poo/declaration :clan/poo/method-declaration
        (only-in :clan/poo/number Integer)
        (prefix-in :clan/poo/examples/declared-methods service.)
        (prefix-in :clan/poo/multimethod dispatch.) (prefix-in :clan/poo/dispatch-extension extension.)
        (prefix-in :clan/poo/declarative-metadata metadata.) (prefix-in :clan/poo/method-combination combination.))
;; The ordinary macro forwards the complete instance row and cache successor.
(.defgeneric (evaluate owner value) slot: .evaluate combination: invoke-declared)
;; Type-selected declarations validate the original instance as the first input.
(.defgeneric (evaluate-instance self value) from: type slot: .evaluate combination: invoke-declared)
;; Construct one declaration receiver using the existing nonlocal form protocol.
(def (receiver signature declarations (supers []))
  (object<-declaration-forms MethodDeclaration. (.o)
    [(typed-method-fragment '.evaluate signature declarations)] supers: supers))
;; Capture refusal identity as well as its existing registration/negative phase.
(def (caught thunk) (try (thunk) #f (catch (cause) cause)))
(def typed-method-declaration-test
  (test-suite "one method declaration protocol for typed dispatch"
    (test-case "shared diamond, two dispatch axes, FUN approval and IO refusal/retry"
      (def events [])
      (def consumed [])
      ;; One trace checks both shared-base uniqueness and current dynamic guards.
      (def family (service.make-dispatch-family (lambda (event) (set! events (cons event events)))))
      (def action (service.typed-charge-action family 12 (lambda (value) (set! consumed (cons value consumed)))))
      (check-exception (action (.o approved: #f tier: 'Premium rate: 3)) Error?)
      (check-equal? events [])
      (check-equal? consumed [])
      (defvalues (amount next) (action (.o approved: #t tier: 'Premium rate: 3)))
      (check-equal? amount 72)
      (check-equal? (reverse events) '(around-enter base around-exit))
      (check-equal? consumed '(72))
      (check-equal? (dispatch.effective-cache-size (extension.snapshot (declared-snapshot next))) 0)
      (set! events [])
      ;; Same cached candidate shape, but guards MUST run against this new row.
      (def account (.o (.type family) (tier 'Premium) (rate 4)))
      (defvalues (larger _) (invoke-declared next [account 24]))
      (check-equal? larger 192)
      (check-equal? (reverse events) '(around-enter audit base around-exit)))
    (test-case "derived erasure cancels an unforced forbidden ancestor declaration"
      (def path [(dispatch.prototype 'blocked)])
      (def signature (extension.check (dispatch.make [Integer] Integer (lambda (_) [['number]]))
        [(extension.shape [['blocked]])]))
      (def ancestor (receiver signature [(metadata.replace "temporary" path identity)]))
      (def owner (receiver signature
        [(metadata.remove "remove" path)
         (metadata.replace "number" [(dispatch.prototype 'number)] identity)] [ancestor]))
      (defvalues (value _) (evaluate owner 7))
      (check-equal? value 7))
    (test-case "derived replacement and erasure win over inherited paths"
      (def certified (extension.check (dispatch.make [Integer] Integer (lambda (_) [['number]])) []))
      (def path [(dispatch.prototype 'number)])
      (def base (receiver certified [(metadata.replace "base" path (lambda (_) 1))]))
      (def child (receiver certified [(metadata.replace "child" path (lambda (_) 2))] [base]))
      (defvalues (value _) (evaluate child 0))
      (check-equal? value 2)
      (def erased (receiver certified [(metadata.remove "remove" path)] [base]))
      (check-exception (evaluate erased 0) dispatch.dispatch-error?))
    (test-case "all existing combination policies share declaration lowering"
      (def precedence (lambda (_) [['number]]))
      (def path [(dispatch.prototype 'number)])
      (for-each (lambda (entry)
        (def certified (extension.check (car entry) []))
        (def owner (receiver certified [(metadata.contribute "policy" path (cadr entry))]))
        (defvalues (value next) (evaluate owner 2))
        (check-equal? value (caddr entry))
        (check-equal? (dispatch.effective-cache-size (extension.snapshot (declared-snapshot next))) 1))
        (list
          (list (dispatch.prepared-simple [Integer] Integer precedence combination.sum)
            (combination.item (lambda (n) (* 3 n))) 6)
          (list (dispatch.prepared-inner [Integer] Integer precedence (lambda (_) 1))
            (lambda (inner n) (+ n (inner))) 3)
          (list (dispatch.prepared-simula [Integer] precedence)
            (combination.simula-body (lambda (_) (void)) (lambda (_) (void))) (void)))))
    (test-case "replacement payload validation survives typed forwarding declaration"
      (def certified (extension.check
        (dispatch.prepared-forwarding-standard Integer Integer Integer (lambda (_) [['number]])) []))
      (def owner (receiver certified
        [(metadata.contribute "replace" [(dispatch.prototype 'number)]
          (combination.forward-primary (lambda (_ dispatch payload) (+ dispatch payload))))]))
      ;; Direct invocation shares the same two-argument bridge used by core formals.
      (defvalues (value next) (invoke-declared (.@ owner .evaluate) [2 3]))
      (check-equal? value 5)
      (check-exception (invoke-declared next [2 #f]) true))
    (test-case "compile once, forward calls and retain immutable successor"
      (def compiled 0)
      (def installed 0)
      (def calls 0)
      ;; Count actual registration admission, independently of cached .compile reads.
      (def (admit-method body) (set! installed (+ installed 1)) (procedure? body))
      (def seed (dispatch.make [Integer] Integer (lambda (_) [['number]])
        (lambda (methods args) (apply (car methods) args)) 1 admit-method))
      (def signature (extension.check seed [(extension.shape [['forbidden]])]))
      (def declaration (.cc metadata.Declaration. name: "increment" .compile:
        (begin (set! compiled (+ compiled 1))
          (extension.register [(dispatch.prototype 'number)]
            (lambda (n) (set! calls (+ calls 1)) (+ n 1))))))
      (def owner (receiver signature [declaration]))
      (defvalues (first next) (evaluate owner 4))
      (check-equal? first 5)
      (check-equal? compiled 1)
      (check-equal? calls 1)
      (check-equal? (dispatch.cache-size (extension.snapshot (declared-snapshot next))) 1)
      (defvalues (second after) (invoke-declared next [8]))
      (check-equal? second 9)
      (check-equal? compiled 1)
      (check-equal? installed 1)
      (check-equal? calls 2)
      (check (dispatch.index-shared? (extension.snapshot (declared-snapshot next))
        (extension.snapshot (declared-snapshot after))) => #t)
      (check-exception (evaluate owner #f) true)
      (check-equal? calls 2)
      ;; A successful cached owner must also observe a supported declaration edit.
      (.setslot! declaration .compile ($constant-slot-spec
        (extension.register [(dispatch.prototype 'number)] (lambda (n) (+ n 20)))))
      (defvalues (revised _) (evaluate owner 4))
      (check-equal? revised 24)
      (check-equal? installed 2)
      ;; The explicitly retained old snapshot remains an immutable old definition.
      (defvalues (held __) (invoke-declared next [4]))
      (check-equal? held 5))
    (test-case "revised contribution membership registers dependencies for new declarations"
      (def certified (extension.check (dispatch.make [Integer] Integer (lambda (_) [['number]])) []))
      (def path [(dispatch.prototype 'number)])
      (def old (metadata.replace "old" path (lambda (_) 1)))
      (def owner (receiver certified [old]))
      (defvalues (first _) (evaluate owner 0))
      (check-equal? first 1)
      (def descriptor (cdr (assq '.evaluate (reflect-slots owner))))
      (def revised (metadata.replace "new" path (lambda (_) 2)))
      (.setslot! descriptor contributions ($constant-slot-spec [revised]))
      (defvalues (second __) (evaluate owner 0))
      (check-equal? second 2)
      (.setslot! revised .compile ($constant-slot-spec (extension.register path (lambda (_) 3))))
      (defvalues (third ___) (evaluate owner 0))
      (check-equal? third 3))
    (test-case "same-slot fragments and inherited guarded qualified declarations"
      (def events [])
      ;; Standard dispatch already owns qualifier admission and effective order.
      (def seed (dispatch.standard [Integer] Integer (lambda (_) [['number]])))
      (def signature (extension.check seed []))
      (def path [(dispatch.prototype 'number)])
      (def base (receiver signature
        [(metadata.contribute "base" path (combination.primary (lambda (_ n) n)))]))
      (def owner (object<-declaration-forms MethodDeclaration. (.o)
        [(typed-method-fragment '.evaluate signature
          [(metadata.guarded "positive" path (lambda (n) (> n 0))
            (combination.before (lambda (_) (set! events (cons 'before events)))))])
         (typed-method-fragment '.evaluate signature
          [(metadata.contribute "around" path (combination.around (lambda (next _) (* 2 (next)))))] )]
        supers: [base]))
      (defvalues (positive _) (evaluate owner 3))
      (check-equal? positive 6)
      (check-equal? events '(before))
      (defvalues (negative __) (evaluate owner -2))
      (check-equal? negative -4)
      (check-equal? events '(before)))
    (test-case "completed negative check refuses before bodies and retry recompiles"
      (def calls 0)
      (def path [(dispatch.prototype 'blocked)])
      (def signature (extension.check (dispatch.make [Integer] Integer (lambda (_) [['number]]))
        [(extension.shape [['blocked]])]))
      (def bad (metadata.replace "blocked" path (lambda (n) (set! calls (+ calls 1)) n)))
      (def owner (receiver signature [bad]))
      (def issue (caught (cut evaluate owner 1)))
      (check (extension.failure? issue) => #t)
      (check-equal? (extension.failure-stage issue) 'negative)
      (check-equal? calls 0)
      ;; Same metadata object and receiver: dependency invalidation must clear failure.
      (.setslot! bad .compile ($constant-slot-spec
        (extension.register [(dispatch.prototype 'number)] (lambda (n) (+ n 10)))))
      (defvalues (value _) (evaluate owner 2))
      (check-equal? value 12))
    (test-case "signature, carrier, arity and output failures retain distinct boundaries"
      (def seed (dispatch.make [Integer] Integer (lambda (_) [['number]])))
      (def first (extension.check seed []))
      (def other (extension.check seed []))
      (check-exception (object<-declaration-forms MethodDeclaration. (.o)
        [(typed-method-fragment '.evaluate first []) (typed-method-fragment '.evaluate other [])]) Error?)
      (check-exception (evaluate (receiver other [] [ (receiver first []) ]) 1) Error?)
      (check-exception (receiver first [#f]) Error?)
      (def bad-arity (receiver first [(metadata.replace "arity" [] identity)]))
      (def issue (caught (cut evaluate bad-arity 1)))
      (check-equal? (extension.failure-stage issue) 'registration)
      (def bad-output (receiver first
        [(metadata.replace "output" [(dispatch.prototype 'number)] (lambda (_) #f))]))
      (check-exception (evaluate bad-output 1) true)
      (check-equal? (dispatch.cache-size seed) 0))
    (test-case "from type validates original instance and ordinary record fields coexist"
      (def signature (extension.check (dispatch.make [Any Integer] Integer (lambda (_) [['account] []])) []))
      (def certified signature)
      (def owner (.declare MethodDeclaration. (.o)
        (public label (.o (constant 'service)))
        (method .evaluate (.o (signature certified) (admit metadata.declaration?)
          (contributions [(metadata.replace "total" [(dispatch.prototype 'account) dispatch.any]
            (lambda (account n) (+ (.@ account rate) n)))])))))
      (def instance (.o (.type owner) (rate 10)))
      ;; Default combiner invokes the first procedure; use a separate ordinary seed.
      (defvalues (value _) (evaluate-instance instance 2))
      (check-equal? value 12)
      (check-equal? (.@ owner label) 'service))))
