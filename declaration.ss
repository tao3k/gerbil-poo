;;; Nonlocal declaration expansion uses ordinary inherited POO methods and Reader.
(export Declaration. declaration-form declaration-action expand-declarations object<-declaration-forms
        object<-expanded-declarations declaration-forms .declare)
(import :std/iter 
        (only-in :std/list/list foldr map-in-order) ./object ./mop ./reflection (only-in ./type element?)
        (prefix-in (only-in ./fun Observation.) fun.))
;; A declaration is ordinary typed-by-convention metadata, not a second AST engine.
;; Runtime construction supports computed names; .declare provides static syntax.
(def (declaration-form kind name descriptor)
  (unless (and (symbol? kind) (symbol? name) (object? descriptor))
    (error "declaration kind/name/metadata required"))
  (object<-alist (list (cons 'kind kind) (cons 'name name) (cons 'descriptor descriptor))))
;; Force visibility on ordinary Slot formulas using the existing clone/merge path.
;; Metadata expressions are source specifications, as in .cc; instance-only .put!
;; overrides are not source formulas and are not implicitly converted into them.
(def (visible-entry form hidden?)
  (def metadata (.@ form descriptor))
  (def descriptor (.cc (.+ (instance Slot) metadata) hidden: hidden?))
  [(cons (.@ form name) descriptor)])
;; Reflect effective visibility, omitting the two reserved catalog meta-slots.
;; This reads metadata only; it does not demand any declared instance value.
(def (visibility-catalog self hidden?)
  (map car (filter (lambda (entry)
    (and (not (memq (car entry) '(.public-slots .private-slots)))
         (eq? (.@ (cdr entry) hidden) hidden?)))
    (reflect-slots self include-hidden?: #t))))
;; One finalizer contributes two NONLOCAL metadata slots to the complete object.
;; Their usual dependency invalidation is the same as that of ordinary slot values.
(def (catalog-declarations _ entries)
  (append entries (list
    (cons '.public-slots (instance Slot hidden: #t
      compute: (lambda (self inherited) (visibility-catalog self #f))))
    (cons '.private-slots (instance Slot hidden: #t
      compute: (lambda (self inherited) (visibility-catalog self #t)))))))
;; Builtin public/private forms are a small inherited method, not a closed macro
;; dispatcher: users extend expand-declaration/finalize-declarations with .o and
;; inherited continuations, emitting any finite list of existing Slot descriptors.
(define-type (Declaration. @ [])
    expand-declaration: (lambda (context form)
      (case (.@ form kind)
        ((public) (visible-entry form #f))
        ((private) (visible-entry form #t))
        (else (error "unknown declaration kind" (.@ form kind)))))
    finalize-declarations: (lambda (_ entries) entries))
;; Admit each callback's finite fragment result before selecting the suffix.
;; Duplicate names and Slot descriptor validity are checked after finalization.
(def (check-fragment entries)
  (unless (list? entries) (error "declaration expansion must return a list")) entries)
;; Compile one Reader/FUN traversal. Standard map-in-order owns callback order;
;; every fragment is checked immediately, before the next expander can run.
;; Fold only after the complete traversal, retaining the original right-to-left
;; append/copy timing, including changes to an earlier chunk by a later callback.
;; Capture forms individually during preparation: caller edits to the list spine
;; cannot replace/remove a prepared form. No callback runs during preparation.
;; Repeated calls use current contexts, never an old approval or expanded catalog.
;; Captured expander methods belong to one revision. Changed source requires a
;; fresh action, and registered writes during evaluation refuse before mutation.
(def (declaration-action expander forms)
  (unless (and (object? expander) (list? forms)) (error "expander and finite forms required"))
  (instantiate-object! expander)
  (def expand (.@ expander expand-declaration))
  (def finalize (.@ expander finalize-declarations))
  (def revision (object-revision expander))
  (def actions (map-in-order (lambda (form)
    (lambda (context) (check-fragment (expand context form)))) forms))
  (def program (.call fun.Observation. .map
    (lambda (chunks) (foldr append [] chunks))
    (lambda (context) (map-in-order (cut <> context) actions))))
  (def finished (.call fun.Observation. .bind program
    (lambda (entries) (lambda (context) (check-fragment (finalize context entries))))))
  (lambda (context)
    (unless (object? context) (error "declaration context object required"))
    (unless (= revision (object-revision expander)) (error "stale declaration expander"))
    (parameterize ((active-object-constructions (cons expander (active-object-constructions))))
      (instantiate-object! context)
      (parameterize ((active-object-constructions (cons context (active-object-constructions))))
        (finished context)))))
;; Immediate expansion uses the same compiled Reader chain; callback failures
;; stop later forms. Constructing the form list precedes expansion, and arbitrary
;; external I/O is not rolled back on refusal.
(def (expand-declarations expander context forms)
  ((declaration-action expander forms) context))
;; Hold current expander/context sources stable while elaborating the candidate.
;; Registered dependency edits refuse, rather than producing a mixed-version set.
;; Instance construction validates duplicate names/descriptors after full expansion.
(def (object<-declaration-forms expander context forms supers: (supers []) protocol: (protocol #f))
  (unless (and (object? expander) (object? context) (list? forms))
    (error "declaration expander/context objects and finite forms required"))
  (instantiate-object! expander) (instantiate-object! context)
  (parameterize ((active-object-constructions
      (cons expander (cons context (active-object-constructions)))))
    (def entries (expand-declarations expander context forms))
    (object<-expanded-declarations context entries supers: supers protocol: protocol)))
;; Shared publication boundary for direct and safe recursive elaboration. Callers
;; supply fully finalized entries; reserved catalog names still collide and refuse.
(def (object<-expanded-declarations context entries supers: (supers []) protocol: (protocol #f))
  (object<-declarations (catalog-declarations context entries) supers: supers protocol: protocol))
;; Static forms quote their kind/name; Scheme unquote-splicing admits computed
;; runtime forms. let sequences metadata expressions exactly once in source order.
(defrules declaration-forms (unquote-splicing)
  ((_ ) [])
  ((_ (unquote-splicing forms) more ...)
   (let (head forms) (append head (declaration-forms more ...))))
  ((_ (kind name descriptor) more ...)
   (let (head (declaration-form 'kind 'name descriptor))
     (cons head (declaration-forms more ...)))))
;; Construct through the same runtime expansion/validation protocol as dynamic forms.
(defrule (.declare expander context forms ...)
  (object<-declaration-forms expander context (declaration-forms forms ...)))
