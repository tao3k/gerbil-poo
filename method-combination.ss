;;; Appendix B method combination; executable counterpart of Object.MethodCombination.
(export Contribution Contribution. primary before after around item
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
