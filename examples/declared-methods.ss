;;; A shared C3 declaration family, qualified methods and current Reader data.
(export charge make-account make-family observation)
(import ../object ../mop ../brace ../declaration ../method-declaration
        (prefix-in ../method-combination combination.) (prefix-in ../generalized-prototype gp.))
;; Type-provided methods receive the original account exactly once, then units.
(.defgeneric (charge account units) from: type slot: .charge combination: standard-combination)
;; Two branches refine one shared base through ordinary inherited fragment slots.
;; No method body executes when the declarations are assembled.
(def (make-family record)
  (def base (.declare MethodDeclaration. (.o)
    (public label (.o (constant 'shared)))
    (method .charge (.o (contributions [(combination.primary (lambda (_ account units)
      (record 'base) (* (.@ account rate) units)))])))))
  (def billing (object<-declaration-forms MethodDeclaration. (.o)
    (list
      (method-fragment '.charge [(combination.before (lambda (_ units) (record 'billing-before)))])
      (method-fragment '.charge [(combination.primary (lambda (next account units)
        (record 'billing-primary) (+ 3 (next))))])
      (method-fragment '.charge [(combination.after (lambda (_ units) (record 'billing-after)))])
      (method-fragment '.charge [(combination.around (lambda (next account units)
        (record 'around-enter) (let (result (next)) (record 'around-exit) (* 2 result))))]))
    supers: [base]))
  (def risk (object<-declaration-forms MethodDeclaration. (.o)
    (list (method-fragment '.charge [(combination.before (lambda (_ units) (record 'risk-before)))])
          (method-fragment '.charge [(combination.after (lambda (_ units) (record 'risk-after)))]))
    supers: [base]))
  (.mix billing risk))
;; Independent receivers share fragments while retaining separate instance data.
(def (make-account family current-rate) (.o (.type family) (rate current-rate)))
;; FUN Reader composes current context with generic invocation without result caching.
(def (observation family units)
  (.call gp.Observation. .map (lambda (account) (charge account units))
    (lambda (context) (make-account family (.@ context rate)))))
