;;; Several native joint candidates share ONE proposed approval object and source.
(export approve-revisions)
(import ../object
        ../mop
        ../brace
        (runtime: :clan/poo/joint-publication)
        (prefix-in (only-in ../joint-publication approve current stage-at) joint.)
        (prefix-in ./component-rounds rounds.))
;; Capture one current bundle for all described alternatives. Each alternative is
;; an endpoint/Change. list using the existing phase/input declaration protocol.
;; Shared policy identity deliberately remains shared across approved receipts.
;; A preparation/admission failure raises before this helper installs anything;
;; a competing publication is never silently used as a new preparation source.
(def (approve-revisions owner alternatives policy builder)
  (def expected (joint.current owner))
  (map (lambda (changes)
    (def edits (map (lambda (entry) (cons (car entry)
      (rounds.contributions (.@ (cdr entry) phase) (.@ (cdr entry) inputs)))) changes))
    (call-with-values (lambda () (joint.approve owner
      (joint.stage-at owner expected [(cons 'shared policy)] edits builder: builder)))
      (lambda (receipt failure) (if failure (raise failure) receipt)))) alternatives))
