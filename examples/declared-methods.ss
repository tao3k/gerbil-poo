;;; A shared C3 declaration family, qualified methods and current Reader data.
(export replayed-summary-action configured-summary configured-summary-action summary-observation charge make-account make-family observation summarize checked-summarize typed-summary-action summary-prototypes prototype-summary-action make-reporting-family summary-action checked-summary-action make-scoped-account scoped-action inspected-action batch-expander batch-action prefixed-action)
(import (only-in ../number Integer) ../object ../mop ../brace ../declaration ../method-declaration
        (prefix-in ../method-combination combination.) (prefix-in ../generalized-prototype gp.)
        (only-in ../reflection read-slot) (only-in ../proto compose-proto*))
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

;; Snapshot the initial rate once, but retain lexical aliases for current receiver
;; fields. FUN admission precedes current public method reflection and combined
;; dispatch. Capturing this action caches neither approval nor method metadata;
;; refusal has no method effects and the same action can be retried after edits.
(def (prefixed-action account units)
  (with-prefixed-slots (account- rate .type) account
    (def-prefixed-slots (initial- rate) account)
    (.call gp.Observation. .bind
      (lambda (context)
        (with-prefixed-slots (approval- approved) context
          (unless approval-approved (error "current approval refused"))
          account))
      (lambda (current)
        (lambda (_)
          (read-slot account-.type '.charge)
          (values initial-rate account-rate (charge current units)))))))

;; Core lambda evaluates defaults/keyword conventions; the generic forwards each
;; resolved value and the original receiver into the existing item combination.
(.defgeneric (summarize account required (optional #f) label: (label 'default) . rest)
  from: type slot: .summary combination: (simple-combination combination.collect))

;; Core predicate contracts guard resolved bindings; the dependent default belongs
;; to the core definition, not the POO forwarder. Keywords and rest data retain the
;; same call format as summarize, including false and literal keyword payloads.
(.defgeneric (checked-summarize account (required :~ fixnum?)
    (optional required :~ fixnum?) label: (label #f) . rest)
  from: type slot: .summary combination: (simple-combination combination.collect))

;; Core defrule keeps the generic callee statically known, preserving its native
;; default/keyword lowering without an additional runtime forwarding closure.
;; Capture family and units exactly once before building the ordinary FUN chain.
;; Reflection is current on every call; refusal prevents summary and charge bodies.
;; The four-argument form also selects a statically known charging generic, so a
;; different charging policy shares the complete Reader chain without an indirect
;; optional/keyword call or a duplicated workflow implementation.
(defrules summary-observation ()
 ((_ family units generic) (summary-observation family units generic charge))
 ((_ family units generic charging)
  (let ((owner family) (count units))
    (.call gp.Observation. .bind
      (lambda (context) (make-account owner (.@ context rate)))
      (lambda (account)
        (.call gp.Observation. .map
          (lambda (summary) (values (charging account count) summary))
          (lambda (_context)
            (read-slot owner '.summary)
            (read-slot owner '.charge)
            (generic account count label: #f #!rest payload: #f))))))))

;; Bind the statically known contracted call before crossing the Reader boundary.
;; The native macro adds no runtime adapter or reimplementation of defaults.
(def (typed-summary-action family units)
  (summary-observation family units checked-summarize))

;; Select a current public combiner at each invocation, before resolving the raw
;; inherited fragment slot. Core signature bindings own contracts and defaults;
;; the complete canonical keyword/rest row is passed directly to that combiner.
(.defgeneric (configured-summary account (required :~ fixnum?)
    (optional required :~ fixnum?) label: (label #f) . rest)
  from: type slot: .summary
  combination: (read-slot (.get account .type) '.summary-combination))

;; Reuse the same Reader/reflection/C3 workflow with a live, declared combination.
;; No captured action freezes combiner admission or method metadata. A source edit
;; is read again on retry, and refusal stops before any summary/charge body.
(def (configured-summary-action family units)
  (summary-observation family units configured-summary))

;; Replay resolved required/optional/label bindings and one structured payload.
;; reads current metadata and selects the current combiner; caller request spines
;; are never handed to callbacks. Refusal stops the batch before charging, and a
;; retry uses the new context rather than retaining a prior result or admission.
(def (replayed-summary-action family units requests)
  (.call gp.Observation. .bind
    (lambda (context) (make-account family (.@ context rate)))
    (lambda (account)
      (.call gp.Observation. .map
        (lambda (summaries) (values (charge account units) summaries))
        (lambda (_context)
          (map (lambda (request)
            (read-slot family '.summary)
            (read-slot family '.charge)
            ;; Keep the contracted callee, arity and keyword statically known.
            ;; The message is one argument, even if it contains keyword data.
            ;; This pattern does not emulate core defaults or keyword dispatch.
            (match request ([required optional label payload]
              (configured-summary account required optional label: label #!rest payload)))) requests))))))

;; Four first-class prototype layers assemble Reader actions without executing
;; them. Approval and reflected policy precede the typed generic; tag/observation
;; follow successful summary and C3 charging. Each invocation reads current Slot
;; metadata. A later refusal retains earlier callback effects, without settlement.
(def (summary-prototypes policy record)
  (list
    (lambda (family inherited)
      (.call gp.Observation. .bind
        (lambda (context)
          (unless (.@ context approved) (error "current approval refused"))
          (read-slot family '.charge)
          (record 'approval) context)
        (lambda (_) inherited)))
    (lambda (_family inherited)
      (lambda (context)
        (record 'offset)
        (inherited (.cc context 'rate (+ (.@ context rate) (read-slot policy 'offset))))))
    (lambda (_family inherited)
      (.call gp.Observation. .map
        (lambda (result) (record 'observed) result) inherited))
    (lambda (_family inherited)
      (.call gp.Observation. .map
        (lambda (result) (record 'tag) (cons (read-slot policy 'tag) result)) inherited))))

;; Reuse the existing typed/default/keyword/rest workflow as the terminal action.
;; Captured long-chain heads stay fixed; suffix edits are selected on the next
;; application. Both returned values are retained with standard call/values.
(def (prototype-summary-action family units layers)
  (def program (compose-proto* layers))
  (lambda (context)
    ((program family (lambda (current)
       (call/values (lambda () ((typed-summary-action family units) current)) list))) context)))

;; Extend the shared diamond with one fragment and a private override of label.
;; Reflection must select this override before checking visibility, hiding the base.
(def (make-reporting-family record)
  (object<-declaration-forms MethodDeclaration. (.o)
    (list (declaration-form 'private 'label (.o (constant 'restricted)))
      (method-fragment '.summary
        [(combination.item
           (lambda (account required (optional #f) label: (label 'default) . rest)
             (record 'summary) (list (.@ account rate) required optional label rest)))]
        combination.simple-contribution?))
    supers: [(make-family record)]))

;; One FUN observation resolves a fresh account, then returns both actual dispatch
;; results. Neither methods nor reflection cache a previous context's observation.
(def (summary-action family required)
  (.call gp.Observation. .map
    (lambda (account)
      (values (charge account required)
              (summarize account required #f label: 'review 'audit)))
    (lambda (context) (make-account family (.@ context rate)))))

;; Compose descriptor admission with type-provided combined dispatch and FUN.
;; The keyword token in rest is data across BOTH wrappers, while label stays a
;; real keyword binding. The generic's omitted default is still owned by lambda.
(def (checked-summary-action family required)
  (def checked (validate (Function [Any] [Object Integer] optional: [Any]
                          keywords: (list (cons label: Any)) rest: Any) summarize))
  (.call gp.Observation. .map
    (lambda (account) (checked account required #f label: 'review #!rest payload: #f))
    (lambda (context) (make-account family (.@ context rate)))))

;; A nested object shadows rate locally while retaining a callable lexical read
;; of its enclosing account. Both closures use the public core binding mechanism;
;; inherited qualified methods still receive the exact final outer account.
(def (make-scoped-account family current-rate)
  (.o self: account
    (.type family)
    (rate current-rate)
    (read-rate (lambda () rate))
    (nested (.o
      (rate 7)
      (outer read-rate)
      (local (lambda () rate))
      (run (lambda (units) (values (outer) (local) (charge account units))))))))

;; FUN creates independent receiver scopes from current contexts and preserves
;; all three observations. No method body runs while this action is assembled.
(def (scoped-action family units)
  (.call gp.Observation. .map
    (lambda (account) (.call (.@ account nested) run units))
    (lambda (context) (make-scoped-account family (.@ context rate)))))

;; Brace construction and nested matching share .o's core binding, including the
;; final outer receiver captured by run. Current PUBLIC method metadata is admitted
;; before invocation, so visibility/metadata refusal emits no method effects. FUN
;; retains code, not an earlier catalog approval or a previous context's result.
(def (inspected-action family units)
  (.call gp.Observation. .map
    (lambda (account)
      (read-slot family '.charge)
      (match account
        ({nested: {run: run outer: outer local: local}}
         (values (.@ family .public-slots) (outer) (local)
                 (call/values (lambda () (run units)) list)))))
    (lambda (context)
      {self: account
       .type: family rate: (.@ context rate)
       nested: {rate: 7 outer: (lambda () (.@ account rate))
                local: (lambda () rate)
                run: (lambda (amount)
                       (values (outer) (local) (charge account amount)))}})))

;; An inherited expander contributes a whole qualifier group from one form.
;; Ordinary record/private forms still use MethodDeclaration.'s inherited path;
;; the same finalizer merges methods only after CURRENT whole-batch approval.
;; Capture scalar surcharge/tenant values during this expansion, not a mutable
;; context in an escaping method body. Expansion effects are not rolled back.
(def (batch-expander record)
  (.o (:: @ MethodDeclaration.)
    (expand-declaration (inherited) (lambda (context form)
      (record (.@ form name))
      (case (.@ form kind)
        ((tenant) ((inherited) context
          (declaration-form 'public 'tenant (instance Slot constant: (.@ context tenant)))))
        ((charge)
         (let (surcharge (.@ context surcharge))
           (append
             ((inherited) context (method-fragment '.charge
               [(combination.before (lambda (_ units) (record 'batch-before)))]))
             ((inherited) context (method-fragment '.charge
               [(combination.primary (lambda (next _ units) (record 'batch-primary) (+ surcharge (next))))]))
             ((inherited) context (method-fragment '.charge
               [(combination.after (lambda (_ units) (record 'batch-after)))])))))
        (else ((inherited) context form)))))
    (finalize-declarations (inherited) (lambda (context entries)
      (record 'finalize)
      (unless (.@ context approved) (error "batch approval refused"))
      ((inherited) context entries)))))

;; Static and spliced forms enter ONE prepared traversal and one finalizer.
;; FUN binds complete entries to the same context before deriving a C3 family;
;; current reflection gates the inherited generic and never demands the token.
(def (batch-action family expander units)
  (def private-forms [(declaration-form 'private 'token (instance Slot constant: 'secret))])
  (def forms (declaration-forms (tenant tenant (.o)) ,@private-forms (charge .charge (.o))))
  (.call gp.Observation. .bind (declaration-action expander forms)
    (lambda (entries) (lambda (context)
      (def current (object<-expanded-declarations context entries supers: [family]))
      (read-slot current '.charge)
      (values (read-slot current 'tenant) (.@ current .public-slots)
        (charge (make-account current (.@ context rate)) units))))))
