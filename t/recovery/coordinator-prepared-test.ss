(export coordinator-prepared-test)
(import :std/test :clan/poo/object :clan/poo/mop :clan/poo/brace
        (prefix-in :clan/poo/joint-publication joint.)
        (prefix-in :clan/poo/construction-cache cache.)
        (prefix-in :clan/poo/examples/joint-topology service.)
        (prefix-in :clan/poo/examples/joint-receipts receipts.)
        :clan/poo/examples/coordinator-rejoining)
;; Collect one checkpoint from each live name without prescribing arrival order.
;; Replies remain one-shot capabilities belonging to their current incarnation.
(def (collect next expected)
  (def checkpoints [])
  (for-each (lambda (_)
    (next (lambda (name payload reply)
      (check-equal? (car payload) expected)
      (check (not (assq name checkpoints)) => #t)
      (set! checkpoints (cons (cons name (cons payload reply)) checkpoints))))) '(c d))
  checkpoints)
;; Resume both prepared coordinators in either order; no timing/sleep controls.
(def (resume checkpoints order)
  (for-each (lambda (name) ((cddr (assq name checkpoints)) 'resume)) order))
;; A six-round merge/delete/split/restore workflow keeps successful preparations
;; suspended while peers publish, then invalidates registered shared approvals.
;; Both names retry explicitly; fresh checks still do not reserve installation.
(def (check-prepared order)
  (def owner (service.start)) (def historical []) (def refusals 0) (def joined 0)
  (for-each (lambda (row)
    (def receipts []) (def failures []) (def installations [])
    ;; Each attempt constructs/approves once, preserving that exact opaque receipt.
    (def operation
      (rejoin-checked
        (lambda (_)
          (def source (joint.current owner))
          (car (receipts.approve-revisions owner [[]]
            (.cc (joint.approval source 'shared)) (.cc cache.Builder.))))
        (lambda (exchange receipt)
          (exchange ['prepared receipt])
          (call-with-values (lambda () (joint.check-approved owner receipt))
            (lambda (_ failure) (when failure (raise failure)))))
        (lambda (exchange receipt)
          ;; Both names must pass observation before either starts installation.
          (exchange ['checked receipt])
          (call-with-values (lambda () (joint.install! owner receipt))
            (lambda (snapshot failure) (exchange ['installed snapshot failure]))))))
    (call-with-rejoining-coordinators
      (map (lambda (name) (cons name operation)) '(c d))
      (lambda (next)
        (def prepared (collect next 'prepared))
        (set! receipts (map (lambda (entry) (cadar (cdr entry))) prepared))
        (def before (joint.current owner))
        ;; A real peer publication changes component membership and SCC grouping
        ;; after preparation succeeds, while both recovery threads are suspended.
        (def winner (car (receipts.approve-revisions owner
          [[(cons 'a (.cc service.Change. phase: (car row)))
            (cons 'b (.cc service.Change. phase: (car row)))]]
          (.cc (joint.approval before 'shared) limit: (cadr row) budget: (caddr row))
          (.cc cache.Builder.))))
        (call-with-values (lambda () (joint.install! owner winner))
          (lambda (_ failure) (check-equal? failure #f)))
        (resume prepared order)
        (set! prepared (collect next 'prepared))
        (set! receipts (append (map (lambda (entry) (cadar (cdr entry))) prepared) receipts))
        (check-equal? (length failures) 2)
        (def observed (joint.current owner))
        (def shared (joint.approval observed 'shared)) (def budget (.@ shared budget))
        ;; Same-value ABA restores observations but cannot restore guard revisions.
        (.putslot! shared 'budget ($constant-slot-spec (+ budget 1)))
        (.putslot! shared 'budget ($constant-slot-spec budget))
        (resume prepared (reverse order))
        (set! prepared (collect next 'prepared))
        (set! receipts (append (map (lambda (entry) (cadar (cdr entry))) prepared) receipts))
        (check-equal? (length failures) 4)
        (check (eq? observed (joint.current owner)) => #t)
        (resume prepared order)
        (def checked (collect next 'checked))
        (set! joined (+ joined 2))
        (resume checked (reverse order))
        (def installed (collect next 'installed))
        (set! installations (map (lambda (entry) (caddar (cdr entry))) installed))
        (check-equal? (length (filter not installations)) 1)
        (resume installed order)
        ;; Every receipt from previous generations or failed preparation must
        ;; refuse without replacing the exact current whole bundle.
        (for-each (lambda (receipt)
          (def current (joint.current owner))
          (call-with-values (lambda () (joint.install! owner receipt))
            (lambda (snapshot failure)
              (check (not (not failure)) => #t) (check (eq? snapshot current) => #t)))) historical))
      (lambda (_ outcome)
        (try (outcome) #f
          (catch (failure)
            (set! failures (cons failure failures)) (set! refusals (+ refusals 1)) operation))))
    (set! historical (append receipts historical)))
    '((merge 24 48) (replace 16 32) (restore 12 24)
      (merge 24 48) (replace 16 32) (restore 12 24)))
  (check-equal? refusals 24) (check-equal? joined 12)
  (check-equal? (service.value (joint.current owner) 'a) 12))
;; Reverse releases to cover either recovering name becoming the first contender.
(def coordinator-prepared-test
  (test-suite "successful preparation is rechecked before rejoining"
    (test-case "c/d publication, shared-guard drift and retries" (check-prepared '(c d)))
    (test-case "d/c publication, shared-guard drift and retries" (check-prepared '(d c)))))
