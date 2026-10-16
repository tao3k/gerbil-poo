;;; Appendix B method combination; executable counterpart of Object.MethodCombination.
(export ForwardContribution ForwardContribution. forward-primary forward-before forward-after forward-around
        forward-contribution? forward-effective inner-chain SimulaBody SimulaBody. simula-body simula-body? simula-effective
        Contribution Contribution. primary before after around item
        standard-contribution? simple-contribution? effective simple-effective
        SimplePolicy. sum collect append-policy all-policy any-policy last-policy maximum minimum)
(import :std/iter (only-in :std/list/list foldr) ./object
        (only-in ./mop define-type Type. element?) ./support/option)

;; Public extensible qualifier descriptor; each body follows its qualifier's calling
;; convention. Primary/around receive a zero-argument next thunk followed by args;
;; before/after/item receive only args. No method body runs during registration.
(define-type (Contribution @ Type.)
  .element?: (lambda (value) (and (object? value) (.has? value .type)
    (eq? (.@ value .type) @) (.has? value qualifier) (.has? value body)
    (procedure? (.@ value body)))))
;; Native contribution prototype; registration validates the admitted qualifier set.
(define-type (Contribution. @ [] qualifier body) .type: Contribution)
;; Construct one validated native qualifier/body pair; invalid bodies raise now.
(def (contribution qualifier body)
  (unless (procedure? body) (error "method body must be a procedure"))
  (.cc Contribution. qualifier: qualifier body: body))
;; Primary method: next retains this invocation's original complete argument row.
(def (primary body) (contribution 'primary body))
;; Before side method: no next; execution follows most-specific-first order.
(def (before body) (contribution 'before body))
;; After side method: no next; execution reverses the selected precedence order.
(def (after body) (contribution 'after body))
;; Around method wraps the whole effective computation and may skip/call next.
(def (around body) (contribution 'around body))
;; Simple method item: no next, one item result for the selected reduction policy.
(def (item body) (contribution 'item body))
;; Standard registration admits only the four Appendix B standard qualifiers.
(def (standard-contribution? value)
  (and (element? Contribution value) (memq (.@ value qualifier) '(primary before after around)) #t))
;; Simple registration admits items and around wrappers; side/primary groups differ.
(def (simple-contribution? value)
  (and (element? Contribution value) (memq (.@ value qualifier) '(item around)) #t))
;; Extract one qualifier group in already-resolved C4/index order. Guards have
;; already filtered candidates; grouping never invokes a method or changes order.
(def (group contributions qualifier)
  (foldr (lambda (method rest)
    (if (eq? (.@ method qualifier) qualifier) (cons (.@ method body) rest) rest)) [] contributions))
;; Compose next-method thunks through a right fold. Every next uses the SAME args;
;; exceptions stop the suffix and no ambient receiver is substituted.
(def (call-chain methods exhausted args)
  ((foldr (lambda (method next) (lambda () (apply method next args)))
          (lambda () (exhausted args)) methods)))
;; Standard effective method: around -> before -> primary -> reversed after.
;; Missing primary invokes on-missing; any raised failure stops subsequent effects.
;; This is value/effect sequencing, not rollback of arbitrary external side effects.
(def (effective contributions args on-missing)
  (call-chain (group contributions 'around)
    (lambda (current)
      (for-each (cut apply <> current) (group contributions 'before))
      (def result (call-chain (group contributions 'primary) on-missing current))
      (for-each (cut apply <> current) (reverse (group contributions 'after)))
      result) args))

;; Open simple-reduction protocol matching Lean SimplePolicy: item/accumulator/
;; result may differ. stop is tested only AFTER the first item; empty has no method.
(define-type (SimplePolicy. @ [] stop empty first step finish))
;; Fold methods most-specific-first with exact short-circuiting of the suffix.
;; Around methods enclose the complete reduction. Captured callbacks are native
;; procedures; stop must return Boolean. Errors propagate without invoking later items.
(def (simple-effective policy contributions args)
  (def stop (.@ policy stop))
  (def first (.@ policy first))
  (def step (.@ policy step))
  (def finish (.@ policy finish))
  (call-chain (group contributions 'around)
    (lambda (current)
      (def methods (group contributions 'item))
      (finish (if (null? methods) (.@ policy empty)
        (let loop ((acc (first (apply (car methods) current))) (rest (cdr methods)))
          (if (null? rest) acc
            (let (done (stop acc))
              (unless (boolean? done) (error "simple stop must be Boolean"))
              (if done acc (loop (step (apply (car rest) current) acc) (cdr rest))))))))) args))
;; Sum all items in selected order; empty sum is zero.
(def sum (.cc SimplePolicy. stop: (lambda (_) #f) empty: 0 first: identity
              step: (lambda (value acc) (+ acc value)) finish: identity))
;; Collect in selected order, cons in the loop and reverse once at the boundary.
(def collect (.cc SimplePolicy. stop: (lambda (_) #f) empty: [] first: list step: cons finish: reverse))
;; Persistent concatenation, matching Lean append (not destructive CLOS nconc).
(def append-policy (.cc SimplePolicy. stop: (lambda (_) #f) empty: [] first: identity
                        step: (lambda (value acc) (append acc value)) finish: identity))
;; Require Boolean item values for the two Boolean policies, even when a caller
;; chooses a wider output Type. Truthy arbitrary data must not short-circuit approval.
(def (boolean-value value)
  (unless (boolean? value) (error "simple Boolean item required")) value)
;; Boolean conjunction; false stops later item bodies. Empty group is true.
(def all-policy (.cc SimplePolicy. stop: not empty: #t first: boolean-value
                     step: (lambda (value acc) (and acc (boolean-value value))) finish: identity))
;; Boolean disjunction; true stops later item bodies. Empty group is false.
(def any-policy (.cc SimplePolicy. stop: identity empty: #f first: boolean-value
                     step: (lambda (value acc) (or acc (boolean-value value))) finish: identity))
;; Execute every item and distinguish no result from a legitimate false result.
(def last-policy (.cc SimplePolicy. stop: (lambda (_) #f) empty: #f first: (lambda (value) (some value))
                      step: (lambda (value _) (some value)) finish: identity))
;; Optional maximum; empty has no invented extremum, negative values are preserved.
(def maximum (.cc SimplePolicy. stop: (lambda (_) #f) empty: #f first: (lambda (value) (some value))
                  step: (lambda (value acc) (some (max (some-value acc) value))) finish: identity))
;; Optional minimum with the same explicit empty-result convention.
(def minimum (.cc SimplePolicy. stop: (lambda (_) #f) empty: #f first: (lambda (value) (some value))
                  step: (lambda (value acc) (some (min (some-value acc) value))) finish: identity))

;; Forwarding has a distinct carrier: next accepts #f (retain payload) or
;; (some payload), including (some #f). Dispatch arguments cannot be replaced.
(define-type (ForwardContribution @ Type.)
  .element?: (lambda (value) (and (object? value) (.has? value .type)
    (eq? (.@ value .type) @) (.has? value qualifier) (.has? value body)
    (procedure? (.@ value body)))))
;; Extensible forwarding descriptor using the same qualifier grouping protocol.
(define-type (ForwardContribution. @ [] qualifier body) .type: ForwardContribution)
;; Validate and construct a forwarding body; no body executes at registration.
(def (forward-contribution qualifier body)
  (unless (procedure? body) (error "forward method must be a procedure"))
  (.cc ForwardContribution. qualifier: qualifier body: body))
;; Forward primary receives (next dispatch payload); next preserves dispatch.
(def (forward-primary body) (forward-contribution 'primary body))
;; Forward before observes the inner combination's current dispatch/payload pair.
(def (forward-before body) (forward-contribution 'before body))
;; Forward after observes that same pair, not a primary's replacement payload.
(def (forward-after body) (forward-contribution 'after body))
;; Forward around may replace payload for the complete inner combination.
(def (forward-around body) (forward-contribution 'around body))
;; Admit only correctly typed standard forwarding qualifiers without invoking them.
(def (forward-contribution? value)
  (and (element? ForwardContribution value)
       (memq (.@ value qualifier) '(primary before after around)) #t))
;; Fold forwarding continuations over one fixed dispatch value. Every replacement
;; is validated before the next body, retaining #f and some #f as distinct cases.
;; A replacement cannot trigger another candidate lookup or change dispatch axes.
(def (call-forward-chain methods exhausted dispatch payload validate-payload)
  ((foldr (lambda (method next)
     (lambda (current)
       (method (lambda (replacement)
         (unless (or (not replacement) (some? replacement)) (error "expected optional forwarded payload"))
         (next (if replacement (validate-payload (some-value replacement)) current))) dispatch current)))
     (lambda (current) (exhausted (list dispatch current))) methods) payload))
;; Standard forwarding order. Around changes reach before/primary/after; primary
;; changes affect only the remaining primary suffix. Raised failures stop effects.
(def (forward-effective contributions args on-missing validate-payload)
  (def dispatch (car args))
  (call-forward-chain (group contributions 'around)
    (lambda (current)
      (for-each (cut apply <> current) (group contributions 'before))
      (def result (call-forward-chain (group contributions 'primary) on-missing
                     (car current) (cadr current) validate-payload))
      (for-each (cut apply <> current) (reverse (group contributions 'after))) result)
    dispatch (cadr args) validate-payload))
;; BETA control: reverse resolved C4 methods, then reuse original-args next thunks.
;; A superclass omitting inner stops descendants; missing descendants use terminal.
(def (inner-chain methods args terminal) (call-chain (reverse methods) terminal args))
;; Simula body Type keeps prefix/suffix callbacks as native extensible POO data.
(define-type (SimulaBody @ Type.)
  .element?: (lambda (value) (and (object? value) (.has? value .type)
    (eq? (.@ value .type) @) (.has? value prefix-part) (.has? value suffix-part)
    (procedure? (.@ value prefix-part)) (procedure? (.@ value suffix-part)))))
;; Prefix/suffix representation corresponds directly to Lean SimulaBody fields.
(define-type (SimulaBody. @ [] prefix-part suffix-part) .type: SimulaBody)
;; Construct a validated body; prefix/suffix receive only the original arguments.
(def (simula-body prefix suffix)
  (unless (and (procedure? prefix) (procedure? suffix)) (error "Simula parts must be procedures"))
  (.cc SimulaBody. prefix-part: prefix suffix-part: suffix))
;; Carrier admission for Simula generics; validation does not execute either part.
(def (simula-body? body) (element? SimulaBody body))
;; Automatic inner: general-first prefixes, specific-first suffixes. Any exception
;; stops the suffix; this is sequencing, not unwind-protect or effect rollback.
(def (simula-effective methods args)
  (for-each (lambda (body) (apply (.@ body prefix-part) args)) (reverse methods))
  (for-each (lambda (body) (apply (.@ body suffix-part) args)) methods)
  (void))
