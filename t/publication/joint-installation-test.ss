(export joint-installation-test)
(import :std/test :clan/poo/object :clan/poo/mop :clan/poo/brace :clan/poo/feedback-graph
        (prefix-in :clan/poo/joint-publication joint.) (prefix-in :clan/poo/construction-cache cache.)
        (prefix-in :clan/poo/examples/component-rounds rounds.) (prefix-in :clan/poo/examples/joint-topology service.))
;; Independent feedback is never eligible for reconstruction in these revisions.
(def builder (.cc cache.Builder. allow: (lambda (key) (not (eq? key 'stable)))))
;; Describe native declared lifecycle edits with the existing POO descriptor.
(def (change phase) (.cc service.Change. phase: phase))
;; Obtain an opaque receipt only AFTER the public local/joint approval phase returns.
;; Approval must leave the authoritative bundle unchanged until explicit installation.
(def (approve owner request)
  (def before (joint.current owner))
  (defvalues (receipt failure) (joint.approve owner request))
  (check-equal? failure #f) (check (eq? before (joint.current owner)) => #t)
  receipt)
;; Failed installation preserves the whole CURRENT bundle, including winner policies.
(def (refuse owner receipt)
  (def before (joint.current owner))
  (defvalues (held failure) (joint.install! owner receipt))
  (check (eq? before held) => #t) (check (not (not failure)) => #t))
;; Ordinary FUN revision construction still uses the one-call composition on retries.
(def (publish owner changes ceiling budget)
  (defvalues (next failure) (joint.submit! owner (service.stage-current owner changes ceiling budget builder)))
  (check-equal? failure #f) next)
;; Concrete barriers are the returned opaque receipts: there is no scheduler timing
;; assumption or side-effecting joint callback to simulate post-approval execution.
(def joint-installation-test
  (test-suite "approved receipts recheck joint snapshots and shared metadata at installation"
    (test-case "approved bridge additions lose to a different SCC winner and freshly restage"
      (def owner (service.start)) (def original (joint.current owner))
      (def slow (approve owner (service.stage-current owner [(cons 'a (change 'merge))] 24 36 builder)))
      (def rival (approve owner (service.stage-current owner [(cons 'b (change 'merge))] 24 36 builder)))
      (defvalues (winner ok) (joint.install! owner rival))
      (check-equal? ok #f) (refuse owner slow) (refuse owner rival)
      (check-equal? (service.value winner 'a) 12) (check-equal? (service.value winner 'b) 24)
      (def fresh (publish owner [(cons 'a (change 'merge)) (cons 'b (change 'replace))] 24 40))
      (check-equal? (service.value fresh 'a) 24) (check-equal? (service.value fresh 'b) 16)
      (check-exception (graph-cache-ref (joint.head fresh 'b) 'b) true)
      (publish owner [(cons 'a (change 'replace))] 16 32)
      (def restored (publish owner [(cons 'a (change 'restore)) (cons 'b (change 'restore))] 12 24))
      (for-each (lambda (receipt) (refuse owner receipt)) [slow rival])
      (for-each (lambda (key)
        (check-equal? (service.value restored key) 12)
        (check (eq? (graph-cache-ref (joint.head original key) 'stable)
                    (graph-cache-ref (joint.head restored key) 'stable)) => #t)
        (for-each (lambda (removed) (check-exception (graph-cache-ref (joint.head restored key) removed) true)) '(e f))) '(a b)))
    (test-case "approved proposed shared policy drifts and returns to equal values before installation"
      (def owner (service.start)) (def original (joint.current owner))
      (def policy (.cc (joint.approval original 'shared) limit: 24 budget: 48))
      (def edits [(cons 'a (rounds.contributions 'merge)) (cons 'b (rounds.contributions 'merge))])
      (def request (joint.stage owner [(cons 'shared policy)] edits builder: builder))
      (def receipt (approve owner request))
      ;; Change only uninstalled metadata AFTER the joint predicate returned true.
      ;; Both budgets still admit 24+24, so revision drift is the refusal cause.
      (.putslot! policy 'budget ($constant-slot-spec 49))
      (refuse owner receipt)
      (.putslot! policy 'budget ($constant-slot-spec 48))
      (refuse owner receipt)
      (check (eq? original (joint.current owner)) => #t)
      (check-equal? (.@ (joint.approval original 'shared) budget) 24)
      ;; A stale request cannot mint a refreshed receipt; explicit staging is required.
      (defvalues (invalid failure) (joint.approve owner request))
      (check-equal? invalid #f) (check (not (not failure)) => #t)
      (def fresh (approve owner (joint.stage owner [(cons 'shared policy)] edits builder: builder)))
      (defvalues (merged ok) (joint.install! owner fresh))
      (check-equal? ok #f) (check (eq? policy (joint.approval merged 'shared)) => #t)
      (publish owner [(cons 'a (change 'replace)) (cons 'b (change 'replace))] 16 32)
      (def restored (publish owner [(cons 'a (change 'restore)) (cons 'b (change 'restore))] 12 24))
      (refuse owner receipt) (check-equal? (service.value restored 'b) 12))
    (test-case "metadata drift and a rival publication together retain the actual whole winner"
      (def owner (service.start)) (def old (joint.current owner))
      (def policy (.cc (joint.approval old 'shared) limit: 24 budget: 48))
      (def slow (approve owner (joint.stage owner [(cons 'shared policy)]
        [(cons 'a (rounds.contributions 'merge)) (cons 'b (rounds.contributions 'merge))] builder: builder)))
      (def rival (approve owner (service.stage-current owner [(cons 'a (change 'merge))] 24 36 builder)))
      (.putslot! policy 'budget ($constant-slot-spec 49))
      (defvalues (winner ok) (joint.install! owner rival)) (check-equal? ok #f)
      (refuse owner slow)
      (check (eq? winner (joint.current owner)) => #t)
      (check-equal? (.@ (joint.approval winner 'shared) budget) 36)
      (check-equal? (service.value winner 'b) 12)
      (def fresh (publish owner [(cons 'b (change 'merge))] 24 48))
      (check-equal? (service.value fresh 'b) 24))
    (test-case "foreign or unapproved values cannot enter the installation phase"
      (def owner (service.start)) (def other (service.start))
      (def request (service.stage-current owner [(cons 'a (change 'merge))] 24 36 builder))
      (refuse owner request) (refuse owner #f)
      (defvalues (denied failure) (joint.approve owner
        (service.stage-current owner [(cons 'a (change 'merge))] 24 35 builder)))
      (check-equal? denied #f) (check (not (not failure)) => #t)
      (def receipt (approve owner request)) (refuse other receipt)
      (defvalues (_ ok) (joint.install! owner receipt)) (check-equal? ok #f))))
