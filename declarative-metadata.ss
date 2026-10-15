;;; DeclarativeMetadata: declarations and contracts use the existing POO MOP.
(export Declaration Declaration. Formula Formula. Predicate Predicate. Contract Contract.
        methods.check<-holds methods.invoke<-wrap
        replace contribute guarded remove of-edit named declaration? declaration-name compile install family
        truth atom both either implies deny formula? holds check
        predicate typed predicate? contract contract? wrap invoke publish
        failure? failure-phase failure-name failure-cause)
(import :std/iter (only-in :std/func compose)
        ./object (only-in ./mop define-type .defgeneric Type Type. validate element?)
        (prefix-in ./dispatch-extension dispatch-extension.))

;; Open descriptors and derived methods follow fun.ss and io.ss. Private records
;; are reserved for failure payloads; public metadata is extensible POO data.
(defstruct failure (phase name cause) final: #t)
(def (refuse phase name cause) (raise (make-failure phase name cause)))
(def (boolean! value)
  (unless (boolean? value) (error "metadata decision must be Boolean")) value)
(def (name! name)
  (unless (string? name) (error "metadata name must be a string"))
  (string-copy name))
(def (metadata? descriptor value)
  (and (object? value) (.has? value .type) (eq? (.@ value .type) descriptor)))

(define-type (Declaration @ Type.) .element?: (cut metadata? @ <>))
(define-type (Declaration. @ [] name .compile) .type: Declaration)
(.defgeneric (compile declaration) slot: .compile)
(def (declaration? value) (element? Declaration value))
(def (declaration-name declaration) (string-copy (.@ declaration name)))
(def (of-edit label edit) (.cc Declaration. name: (name! label) .compile: edit))
(def (replace name path body) (of-edit name (dispatch-extension.register path body)))
(def (contribute name path body) (of-edit name (dispatch-extension.contribute path body)))
(def (guarded name path guard body) (of-edit name (dispatch-extension.register-when path guard body)))
(def (remove name path) (of-edit name (dispatch-extension.erase path)))
(def (install seed declarations) (dispatch-extension.patch seed (map compile declarations)))
(def (family base declarations)
  ;; Rebinding methods preserves the native model's seed, watches and overrides.
  (.cc base methods: (lambda (key policy cooked) (map compile (declarations key policy cooked)))))
(def (named label edits)
  (for/collect ((edit edits) (index (in-range (length edits))))
    (of-edit (string-append label ":" (number->string index)) edit)))

;; Formula.Holds is composed at construction. There is no tag interpreter in
;; the invocation path. Scheme's and/or preserve left-to-right short circuiting.
(define-type (Formula @ Type.) .element?: (cut metadata? @ <>))
(define-type (methods.check<-holds @ [] .holds)
  .check: (lambda (meaning) (unless (boolean! (.holds meaning)) (refuse 'logic #f #f)) #t))
(define-type (Formula. @ [methods.check<-holds] .holds) .type: Formula)
(.defgeneric (holds formula meaning) slot: .holds)
(.defgeneric (check formula meaning) slot: .check)
(def (formula? value) (element? Formula value))
(def truth (.cc Formula. .holds: (lambda (_) #t)))
(def (atom key)
  (unless (symbol? key) (error "logic atom must be a symbol"))
  (.cc Formula. .holds: (lambda (meaning) (boolean! (meaning key)))))
(def (decision formula) (compose boolean! (.@ (validate Formula formula) .holds)))
(def (both left right)
  (let ((l (decision left)) (r (decision right)))
    (.cc Formula. .holds: (lambda (meaning) (and (l meaning) (r meaning))))))
(def (either left right)
  (let ((l (decision left)) (r (decision right)))
    (.cc Formula. .holds: (lambda (meaning) (or (l meaning) (r meaning))))))
(def (implies premise conclusion) (either (deny premise) conclusion))
(def (deny body) (.cc Formula. .holds: (compose not (decision body))))

;; Predicates ARE native Type descriptors: refinement and typed metadata both
;; participate in the existing element?/validate protocol.
(define-type (Predicate @ Type.) .element?: (cut metadata? @ <>))
(define-type (Predicate. @ Type. name) .type: Predicate)
(def (predicate? value) (element? Predicate value))
(def (predicate label test)
  (unless (procedure? test) (error "metadata predicate must be a procedure"))
  (.cc Predicate. name: (name! label) .element?: test))
(def (typed label type)
  (validate Type type)
  (predicate label (lambda (value) (and (element? type value) #t))))
(def (accepts phase type value)
  (def valid (try (boolean! (element? type value))
               (catch (cause) (refuse phase (.@ type name) cause))))
  (unless valid (refuse phase (.@ type name) #f)))

;; A Contract is an invocation wrapper, so it composes with ordinary calls,
;; typed dispatch, and publication without defining another effect system.
(define-type (Contract @ Type.) .element?: (cut metadata? @ <>))
(define-type (methods.invoke<-wrap @ [] .wrap)
  .invoke: (lambda (execute args) ((.wrap execute) args)))
(define-type (Contract. @ [methods.invoke<-wrap] input output meaning rule)
  .type: Contract
  .wrap:
  (let ((in (cut accepts 'input input <>))
        (out (cut accepts 'output output <>))
        (decide (decision rule)))
    (lambda (execute)
      (lambda (args . context)
        (in args)
        ;; Only raised source exceptions are wrapped. Business errors stay values.
        (defvalues (result state)
          (try (apply execute args context) (catch (cause) (refuse 'source #f cause))))
        (out result)
        (def valid
          (try (decide (cut meaning <> args result))
            (catch (cause) (refuse 'logic #f cause))))
        (unless valid (refuse 'logic #f #f))
        (values result state)))))
(.defgeneric (wrap contract execute) slot: .wrap)
(.defgeneric (invoke contract execute args) slot: .invoke)
(def (contract? value) (element? Contract value))
(def (contract input-type output-type interpretation formula)
  (validate Predicate input-type)
  (validate Predicate output-type)
  (validate Formula formula)
  (unless (procedure? interpretation) (error "metadata meaning must be a procedure"))
  (.cc Contract. input: input-type output: output-type meaning: interpretation rule: formula))
(def (publish contract old execute args)
  (try
    (defvalues (result next) (invoke contract execute args))
    (values result next #f)
    (catch (cause)
      (if (failure? cause) (values #f old cause) (raise cause)))))
