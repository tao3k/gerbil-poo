;;; Recursive.Interaction: explicit final-self requests, separate from source errors.
(export Interaction. Generator. value value? value-result source-error source-error? source-error-message
        request bind map-interaction fold interaction? generate solve pending? close)
(import ./object (only-in ./mop define-type Type validate element?) (prefix-in ./fun fun.))
;; Closed native nodes; public builders never expose mutation or cache receipts.
(defstruct returned (result) final: #t)
;; Explicit source-language failure, not a caught host exception or machine diagnostic.
(defstruct failed (message) final: #t)
;; A local continuation must terminate and be pure, matching Lean's finite Interaction.
(defstruct called (input next) final: #t)
;; Exhausted source observation depth carries no claim of divergence.
(defstruct unresolved () final: #t)
;; Share the immutable pending observation, never a successful answer.
(def pending (make-unresolved))
;; Introduce a pure completed local computation; the generator checks final output.
(def (value result) (make-returned result))
;; Recognize a returned computation/observation without forcing any recursive call.
(def value? returned?)
;; Read the actual source result; callers must first establish value?.
(def value-result returned-result)
;; Introduce an explicit source failure; memo may retain it once evaluation completes.
(def (source-error message)
  (unless (string? message) (error "source error requires a string"))
  (make-failed message))
;; Recognize only explicit source failures, excluding cycle and budget diagnostics.
(def source-error? failed?)
;; Read an explicit failure's unchanged source message.
(def source-error-message failed-message)
;; Recognize an unresolved finite source observation, not a source failure.
(def pending? unresolved?)
;; Test the closed interaction constructors; no callback executes here.
(def (interaction? tree) (or (returned? tree) (failed? tree) (called? tree)))
;; Request the final self at input; binding supplies the rest of the local computation.
(def (request input) (make-called input value))
;; Structural monadic composition keeps failure order and delays recursive callbacks.
(def (bind tree next)
  (cond ((returned? tree) (next (returned-result tree)))
        ((failed? tree) tree)
        ((called? tree) (make-called (called-input tree)
          (lambda (answer) (bind ((called-next tree) answer) next))))
        (else (error "expected recursive interaction"))))
;; Eliminate a request node for alternate evaluators without exposing constructors.
;; Values/errors are handled before this operation; malformed trees fail closed.
(def (fold tree on-request)
  (unless (called? tree) (error "expected recursive request"))
  (on-request (called-input tree) (called-next tree)))
;; Map a pure result through the same bind protocol; errors/requests retain order.
(def (map-interaction transform tree) (bind tree (lambda (answer) (value (transform answer)))))
;; Native FUN interface: .ap/.bind/.map compose explicit requests, not unsafe thunks.
(define-type (Interaction. @ fun.ParametricFunctor.)
  .ap: value .bind: bind .map: map-interaction)
;; Invoke one immutable typed generator. Membership checks preserve values rather
;; than coercing cache keys; callbacks and request/result values must be immutable.
(def (generate program input)
  (unless (element? (.@ program input) input) (error "recursive input type refused" input))
  (def tree ((.@ program generate) input))
  (unless (interaction? tree) (error "generator returned no interaction"))
  tree)
;; Interpret a finite local tree against one shallower source oracle. Local callbacks
;; are trusted pure/terminating; depth bounds final-self requests, not host execution.
(def (interpret program tree oracle)
  (cond ((returned? tree) tree) ((failed? tree) tree)
        ((called? tree)
         (let (head (oracle (called-input tree)))
           (if (returned? head) (interpret program ((called-next tree) (returned-result head)) oracle) head)))
        (else (error "continuation returned no interaction"))))
;; Observe at finite source self-depth, independently of the memo machine budget.
(def (solve program depth input)
  (unless (and (exact-integer? depth) (>= depth 0)) (error "invalid source depth"))
  (if (= depth 0) pending
    (let (observed (interpret program (generate program input) (cut solve program (- depth 1) <>)))
      (when (and (returned? observed) (not (element? (.@ program output) (returned-result observed))))
        (error "recursive output type refused"))
      observed)))
;; Close existing prototypes with explicit final-self requests, preserving inherited
;; generators. A fresh descriptor owns a new program identity even for equal code.
(def (close prototype base input output)
  (.cc Generator. input: input output: output generate: (prototype request base)))
;; Program descriptors reuse POO inheritance and carry explicit runtime Type domains.
;; Changing code/domain requires a new descriptor; published descriptors stay immutable.
(define-type (Generator. @ [] input output generate)
  .solve: (lambda (depth argument) (solve @ depth argument)))
