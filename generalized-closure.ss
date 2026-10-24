;;; Bounded adjacent-raw stabilization of existing generalized fragment programs.
(export close-fragments publish-closure closure-action closed-fragments? closed-raw closed-interface closed-steps
        closure-failure? closure-failure-kind closure-failure-steps closure-failure-cause)
(import ./generalized-declaration ./lens-laws)
;; Only a completed equality check followed by cooking constructs this receipt.
;; Returned raw data must remain immutable; this native provenance is not a proof seal.
(defstruct closed-fragments (owner base raw interface steps) final: #t)
;; Report machine budget, finite lens counterexamples and source/callback errors
;; distinctly. No partial raw prefix or speculative cooked interface is returned.
(defstruct closure-failure (kind steps cause) final: #t)
;; Inspect the actual retained raw fixed point, not a sampled callable observation.
(def closed-raw closed-fragments-raw)
;; Consume the cooked snapshot from the successful raw closure and same source owner.
(def closed-interface closed-fragments-interface)
;; Count all raw transitions, including the final adjacent-equality verification.
(def closed-steps closed-fragments-steps)
;; Check optional finite lens domains on every visited raw state. This is additional
;; operational admission; general laws require the separate universal Lean premises.
(def (check-state checks state) (for-each (lambda (check) (run-lens-check check [state])) checks))
;; Budget bounds the number of raw steps, not total callback time. Structural equal?
;; is used directly: no user comparator can authorize an unequal state or a sampled
;; function equivalence. Fresh closure identities may therefore exhaust the budget.
;; Pure deterministic callbacks and immutable inputs/returned values are premises.
(def (close-fragments prepared base seed budget checks: (checks []))
  (def steps 0)
  (try
    (unless (and (exact-integer? budget) (>= budget 0) (list? checks) (andmap lens-check? checks))
      (error "nonnegative closure budget and finite lens checks required"))
    (with-fragment-sources prepared (lambda () (with-lens-checks checks (lambda ()
      (let loop ((current seed))
        (if (= steps budget) (values #f (make-closure-failure 'budget steps #f))
          (begin
            (check-state checks current)
            (let (next (step-fragments prepared current base))
              (set! steps (+ steps 1))
              (check-state checks next)
              (if (equal? next current)
                (values (make-closed-fragments prepared base current (observe-fragments prepared current current 0) steps) #f)
                (loop next))))))))))
    (catch (cause)
      (values #f (make-closure-failure (if (lens-law-failure? cause) 'lens 'source) steps cause)))))
;; Stage a whole candidate before replacing the published receipt. Any source,
;; budget, law or cooking refusal retains EXACTLY the previous publication.
;; External callback effects are sequenced and never claimed to roll back.
(def (publish-closure old prepared base seed budget checks: (checks []))
  (defvalues (candidate failure) (close-fragments prepared base seed budget checks: checks))
  (values (if failure old candidate) failure))
;; Native Reader/FUN introduction: successful closure is one value for .map/.bind;
;; a typed refusal raises before selecting the remaining observation chain.
(def (closure-action prepared base budget checks: (checks []))
  (lambda (seed)
    (defvalues (closed failure) (close-fragments prepared base seed budget checks: checks))
    (if failure (raise failure) closed)))
