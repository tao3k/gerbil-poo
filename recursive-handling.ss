;;; Functional.RecursiveHandling: current Type admission over source-bound memo.
(export Signature. RequestAction. session session? session-memo call-slot call-action call-batch
        result? result-value result-failure result-next result-reused failure? failure-stage failure-cause)
(import :std/iter ./object (only-in ./mop define-type Type validate element?)
        (prefix-in ./fun fun.) (prefix-in ./recursive recursive.) (prefix-in ./recursive-cache cached.))
;; Native counterpart of a resolved callable signature; registries remain ordinary
;; immutable POO objects. The current descriptor is resolved anew on EVERY call.
(define-type (Signature. @ [] name input output))
;; Published session contains only its program-indexed memo; no admitted output cache.
(defstruct session-state (program memo) final: #t)
;; Retained-state result distinguishes a legitimate #f answer from any failure.
(defstruct result (value failure next reused) final: #t)
;; Boundary failure carries the exact phase/cause; source errors remain explicit.
(defstruct failure (stage cause) final: #t)
;; Start a session for one immutable typed generator, never another program's memo.
(def (session program) (make-session-state program (cached.empty program)))
;; Recognize the private native session carrier without forcing its program.
(def session? session-state?)
;; Inspect memo size/statistics through the cache's read-only API.
(def session-memo session-state-memo)
;; Resolve the CURRENT registry/signature and admit input before entering memo.
;; Completed source errors and output refusals retain completed memo; diagnostics,
;; schema/signature/input failures retain the original session. Reuse is unknown
;; until input admission, matching RecursiveSession's optional Boolean observation.
(def (call-slot current registry slot argument budget)
  (def next current)
  (def reused 'unknown)
  (def stage 'schema)
  (try
    (def signature (.ref registry slot))
    (set! stage 'signature)
    (unless (symbol? (.@ signature name)) (error "signature name must be a symbol"))
    (validate Type (.@ signature input)) (validate Type (.@ signature output))
    (set! stage 'argument)
    (unless (element? (.@ signature input) argument) (error "recursive argument refused"))
    (set! stage 'evaluation)
    (def memo (session-state-memo current))
    (def input (cons (.@ signature name) argument))
    (set! reused (cached.memo-has? memo input))
    (defvalues (receipt updated) (cached.run (session-state-program current) input budget memo))
    (if (cached.diagnostic? receipt)
      (make-result #f (make-failure 'evaluation receipt) current reused)
      (begin
        (set! next (make-session-state (session-state-program current) updated))
        (let (completion (cached.receipt-result receipt))
          (if (recursive.source-error? completion)
            (make-result #f (make-failure 'source (recursive.source-error-message completion)) next reused)
            (begin
              (set! stage 'result)
              (unless (element? (.@ signature output) (recursive.value-result completion))
                (error "recursive output refused"))
              (make-result (recursive.value-result completion) #f next reused))))))
    (catch (cause) (make-result #f (make-failure stage cause) next reused))))
;; Lift a value into a retained-session action, using the native FUN convention.
(def (pure-action value) (lambda (state) (make-result value #f state 'unknown)))
;; Bind threads the exact next session even after output rejection; failures stop
;; the chain without rolling back completed source work or forcing later actions.
(def (bind-action action next)
  (lambda (state)
    (def result (action state))
    (if (result-failure result) result ((next (result-value result)) (result-next result)))))
;; Map successful values while preserving failure/state semantics via the same bind.
(def (map-action transform action) (bind-action action (lambda (answer) (pure-action (transform answer)))))
;; POO/FUN composition of checked requests: actions are state -> retained result.
(define-type (RequestAction. @ fun.ParametricFunctor.)
  .ap: pure-action .bind: bind-action .map: map-action)
;; Capture registry/slot/argument, not an admitted result or stale schema decision.
(def (call-action registry slot argument budget) (cut call-slot <> registry slot argument budget))
;; Traverse checked requests in order using FUN bind. An output refusal preserves
;; its completed memo and stops before remaining requests; the original is untouched.
(def (call-batch current registry requests budget)
  (def action (foldl (lambda (request accumulated)
    (bind-action accumulated (lambda (answers)
      (map-action (cut cons <> answers) (call-action registry (car request) (cdr request) budget)))))
      (pure-action []) requests))
  ((map-action reverse action) current))
