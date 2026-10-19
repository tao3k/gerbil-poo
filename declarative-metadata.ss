;;; DeclarativeMetadata: declarations and contracts use the existing POO MOP.
(export Declaration Declaration. Formula Formula. Predicate Predicate. Contract Contract.
        methods.check<-holds methods.invoke<-wrap
        replace contribute guarded remove of-edit named declaration? declaration-name compile install family
        truth atom both either implies deny formula? holds check
        predicate typed predicate? contract contract? with-meaning bind-evidence wrap invoke publish
        failure? failure-phase failure-name failure-cause)
(import (only-in ./support/base require-value) :std/iter (only-in :std/func compose)
        ./object (only-in ./mop define-type .defgeneric Type Type. validate element?)
        (prefix-in ./dispatch-extension dispatch-extension.))

;; Open descriptors and derived methods follow fun.ss and io.ss. Private records
;; are reserved for failure payloads; public metadata is extensible POO data.
;; Phase/name/cause payload for checked metadata refusal; public callers may inspect it.
(defstruct failure (phase name cause) final: #t)
;; Raise typed metadata refusal while preserving the original phase and cause.
(def (refuse phase name cause) (raise (make-failure phase name cause)))
;; Require Boolean predicate/formula results; truthy arbitrary values cannot approve metadata.
(def (boolean! value)
  (require-value value boolean? (lambda () (error "metadata decision must be Boolean"))))
;; Validate and privately copy a declaration/predicate name so callers cannot mutate its identity.
(def (name! name)
  (require-value name string? (lambda () (error "metadata name must be a string")))
  (string-copy name))
;; Recognize native open metadata objects by their explicit type descriptor identity.
(def (metadata? descriptor value)
  (and (object? value) (.has? value .type) (eq? (.@ value .type) descriptor)))

;; Native Type descriptor for extensible method-edit declarations.
(define-type (Declaration @ Type.) .element?: (cut metadata? @ <>))
;; Named native declaration with a compiled dispatch edit; overrides remain ordinary MOP slots.
(define-type (Declaration. @ [] name .compile) .type: Declaration)
;; Obtain the actual dispatch edit through the declaration's native compile method.
(.defgeneric (compile declaration) slot: .compile)
;; Recognize a native declaration; malformed data is refused by its consuming protocol.
(def (declaration? value) (element? Declaration value))
;; Return a private copy of the declaration name.
(def (declaration-name declaration) (string-copy (.@ declaration name)))
;; Bind a validated name to one existing dispatch edit without inventing another effect protocol.
(def (of-edit label edit) (.cc Declaration. name: (name! label) .compile: edit))
;; Declare unconditional replacement of a method at its dispatch path.
(def (replace name path body) (of-edit name (dispatch-extension.register path body)))
;; Declare a contribution to the existing method-combination protocol at path.
(def (contribute name path body) (of-edit name (dispatch-extension.contribute path body)))
;; Declare a method whose applicability is decided by the existing runtime guard.
(def (guarded name path guard body) (of-edit name (dispatch-extension.register-when path guard body)))
;; Declare removal at path; actual completed-candidate checks remain in dispatch publication.
(def (remove name path) (of-edit name (dispatch-extension.erase path)))
;; Compile declarations and patch the seed; registration failures propagate.
(def (install seed declarations) (dispatch-extension.patch seed (map compile declarations)))
;; Derive declaration-driven methods while preserving the model's seed, watches and owner protocol.
(def (family base declarations)
  ;; Rebinding methods preserves the native model's seed, watches and overrides.
  (.cc base methods: (lambda (key policy cooked) (map compile (declarations key policy cooked)))))
;; Label a sequence of edits by stable order for diagnostic provenance.
(def (named label edits)
  (for/collect ((edit edits) (index (in-range (length edits))))
    (of-edit (string-append label ":" (number->string index)) edit)))

;; Formula.Holds is composed at construction. There is no tag interpreter in
;; the invocation path. Scheme's and/or preserve left-to-right short circuiting.
;; Native Type descriptor for composed executable logical formulas.
(define-type (Formula @ Type.) .element?: (cut metadata? @ <>))
;; Derive logical refusal from a Boolean holds callback; false raises logic failure.
(define-type (methods.check<-holds @ [] .holds)
  .check: (lambda (meaning) (unless (boolean! (.holds meaning)) (refuse 'logic #f #f)) #t))
;; Open formula prototype composing its holds callback with the existing check method.
(define-type (Formula. @ [methods.check<-holds] .holds) .type: Formula)
;; Evaluate formula truth under the supplied atom interpretation, preserving short circuiting.
(.defgeneric (holds formula meaning) slot: .holds)
;; Require formula truth or raise typed logic refusal.
(.defgeneric (check formula meaning) slot: .check)
;; Recognize native formula descriptors for construction validation.
(def (formula? value) (element? Formula value))
;; Formula accepting every interpretation without evaluating any atom.
(def truth (.cc Formula. .holds: (lambda (_) #t)))
;; Build a symbol-named logical atom with a strictly Boolean interpretation.
(def (atom key)
  (unless (symbol? key) (error "logic atom must be a symbol"))
  (.cc Formula. .holds: (lambda (meaning) (boolean! (meaning key)))))
;; Validate and capture a formula's actual holds callback, enforcing Boolean decisions.
(def (decision formula) (compose boolean! (.@ (validate Formula formula) .holds)))
;; Compose conjunction with left-to-right short circuiting; skipped atoms never execute.
(def (both left right)
  (let ((l (decision left)) (r (decision right)))
    (.cc Formula. .holds: (lambda (meaning) (and (l meaning) (r meaning))))))
;; Compose disjunction with left-to-right short circuiting.
(def (either left right)
  (let ((l (decision left)) (r (decision right)))
    (.cc Formula. .holds: (lambda (meaning) (or (l meaning) (r meaning))))))
;; Compose implication using the same short-circuiting formula operations.
(def (implies premise conclusion) (either (deny premise) conclusion))
;; Negate a validated Boolean formula decision.
(def (deny body) (.cc Formula. .holds: (compose not (decision body))))

;; Predicates ARE native Type descriptors: refinement and typed metadata both
;; participate in the existing element?/validate protocol.
;; Native Type descriptor for input/output refinement predicates.
(define-type (Predicate @ Type.) .element?: (cut metadata? @ <>))
;; Named refinement Type using the existing element?/validate protocol.
(define-type (Predicate. @ Type. name) .type: Predicate)
;; Recognize a native named predicate descriptor.
(def (predicate? value) (element? Predicate value))
;; Construct a named refinement from a procedure; invalid callbacks raise immediately.
(def (predicate label test)
  (unless (procedure? test) (error "metadata predicate must be a procedure"))
  (.cc Predicate. name: (name! label) .element?: test))
;; Lift a validated existing Type into a named Boolean metadata refinement.
(def (typed label type)
  (validate Type type)
  (predicate label (lambda (value) (and (element? type value) #t))))
;; Evaluate a predicate and retain input/output phase and name for false results or exceptions.
(def (accepts phase type value)
  (def valid (try (boolean! (element? type value))
               (catch (cause) (refuse phase (.@ type name) cause))))
  (unless valid (refuse phase (.@ type name) #f)))

;; A Contract is an invocation wrapper, so it composes with ordinary calls,
;; typed dispatch, and publication without defining another effect system.
;; Native Type descriptor for extensible checked invocation contracts.
(define-type (Contract @ Type.) .element?: (cut metadata? @ <>))
;; Derive ordinary checked invocation from the contract's wrapper method.
(define-type (methods.invoke<-wrap @ [] .wrap)
  .invoke: (lambda (execute args) ((.wrap execute) args)))
;; Private immutable compiled checks retain their exact metadata sources. A child
;; may reuse them only while input/output/rule identities all match current slots.
;; They contain no invocation results, executor, meaning or previous snapshot.
(defstruct contract-checks (input output rule in out decide) final: #t)
;; Compile the invariant predicate/formula callbacks once for specialization.
;; Validation errors propagate at preparation; callback execution keeps its normal
;; input/output/logic failure phase in checked-wrapper below.
(def (compile-checks input output rule)
  (make-contract-checks input output rule (cut accepts 'input input <>)
                       (cut accepts 'output output <>) (decision rule)))
;; Identity stamps are a sufficient reuse guard under immutable native metadata.
;; Any derived predicate/formula requires fresh checks, even if outputs look equal.
(def (matching-checks? checks input output rule)
  (and (contract-checks? checks) (eq? input (contract-checks-input checks))
       (eq? output (contract-checks-output checks)) (eq? rule (contract-checks-rule checks))))
;; Compose invariant checks with the CURRENT dependent meaning and executor.
;; Check input before source, then output and logic; business failures stay values,
;; raised source failures retain phase, and success returns exact result/state.
(def (checked-wrapper in out decide meaning)
  (lambda (execute)
    (lambda (args . context)
      (in args)
      (defvalues (result state)
        (try (apply execute args context) (catch (cause) (refuse 'source #f cause))))
      (out result)
      (def valid
        (try (decide (cut meaning <> args result))
          (catch (cause) (refuse 'logic #f cause))))
      (unless valid (refuse 'logic #f #f))
      (values result state))))
;; Open contract prototype. Ordinary construction keeps fresh check preparation;
;; with-meaning specializes dependent meaning; sharing is opt-in at the call
;; boundary (default true), while share? false leaves invariant preparation lazy.
;; Later input/output/rule overrides fail the stamp guard and prepare fresh checks.
(define-type (Contract. @ [methods.invoke<-wrap] input output meaning rule)
  .type: Contract
  checks: #f
  ;; Lazy template-owned preparation: fresh specialization never forces this.
  .invariant-checks: (if (matching-checks? checks input output rule) checks (compile-checks input output rule))
  .with-meaning:
  (lambda (next-meaning (share? #t))
    (unless (and (procedure? next-meaning) (boolean? share?)) (error "invalid meaning specialization"))
    (if share?
      (.cc @ meaning: next-meaning checks: (.@ @ .invariant-checks))
      (if checks (.cc @ meaning: next-meaning checks: #f) (.cc @ meaning: next-meaning))))
  .wrap:
  (if (matching-checks? checks input output rule)
    (checked-wrapper (contract-checks-in checks) (contract-checks-out checks)
                     (contract-checks-decide checks) meaning)
    (checked-wrapper (cut accepts 'input input <>) (cut accepts 'output output <>)
                     (decision rule) meaning)))
;; Specialize a descriptor through its native method, preserving extensible slots.
;; Sharing applies only to immutable invariant sources; the new meaning is always
;; used at invocation. Derived invariant changes still take the fresh-check path.
;; share? false avoids initial shared-record preparation for a single cold call.
(.defgeneric (with-meaning contract meaning (share? #t)) slot: .with-meaning)
;; Add an exact subject/descriptor/context relation to an existing invocation
;; Contract. The view projects an existing result; no receipt type or authority
;; is created. All references and their contents must remain immutable.
(def (bind-evidence invocation subject descriptor context evidence-view)
  (validate Contract invocation)
  (require-value evidence-view procedure? (lambda () (error "Evidence view must be a procedure")))
  (let ((binding-key (gensym 'evidence-binding))
        (previous-meaning (.@ invocation meaning)))
    (.cc
      (with-meaning invocation
        (lambda (key request evidence)
          (if (eq? key binding-key)
            (and (eq? request subject)
                 (let (view (evidence-view evidence))
                   (and (eq? subject (.@ view subject))
                        (eq? descriptor (.@ view descriptor))
                        (eq? context (.@ view context)))))
            (previous-meaning key request evidence)))
        #f)
      ;; Fuse the known fresh atom with conjunction: one Formula object instead
      ;; of an intermediate atom plus both. Capture the current parent decision
      ;; after with-meaning, preserving custom specialization effects and order.
      rule: (let (previous (decision (.@ invocation rule)))
              (.cc Formula. .holds: (lambda (meaning)
                (and (previous meaning) (boolean! (meaning binding-key)))))))))
;; Bind the current executor to a descriptor's checked wrapper; state remains an invocation argument.
(.defgeneric (wrap contract execute) slot: .wrap)
;; Execute through the descriptor's native checked invocation method.
(.defgeneric (invoke contract execute args) slot: .invoke)
;; Recognize an open native Contract descriptor before family construction/binding.
(def (contract? value) (element? Contract value))
;; Validate invariant predicate/formula descriptors and dependent meaning, then derive a contract.
(def (contract input-type output-type interpretation formula)
  (validate Predicate input-type)
  (validate Predicate output-type)
  (validate Formula formula)
  (require-value interpretation procedure? (lambda () (error "metadata meaning must be a procedure")))
  (.cc Contract. input: input-type output: output-type meaning: interpretation rule: formula))
;; Invoke atomically at the value boundary: metadata refusal returns exact old state.
;; Other exceptions propagate; arbitrary external callback effects are not rolled back.
(def (publish contract old execute args)
  (try
    (defvalues (result next) (invoke contract execute args))
    (values result next #f)
    (catch (cause)
      (if (failure? cause) (values #f old cause) (raise cause)))))
