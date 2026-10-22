;;; Self-hosted declaration expansion followed by shared service publication.
(export make-service-expander service-action report)
(import ../object
        ../mop
        ../number
        ../brace
        ../reflection
        ../meta-prototype
        ../declaration
        (runtime: :clan/poo/generalized-prototype)
        (prefix-in (only-in ../generalized-prototype Observation.) gp.))
;; One property expands nonlocally into its public slot/getter and private revision
;; annotation. Ordinary metadata carries the current context; no slot body runs here.
(def (property-declarations context form inherited)
  (def name (.@ form name))
  (append (inherited context (declaration-form 'public name (.@ form descriptor)))
    (list
      (cons (make-symbol 'read- name) (instance Slot compute:
        (lambda (self parent) (lambda () (read-slot self name)))))
      (cons (make-symbol name '-revision)
        (instance Slot hidden: #t constant: (.@ context revision))))))
;; The self-hosted root interprets its own expand-declaration metadata using its
;; pinned compiler. Extension uses inherited POO methods; no separate dispatcher
;; registry, evaluator or Lean checkout participates in this workflow.
(def (make-service-expander log)
  (bootstrap-protocol
    (.o (:: @ Declaration.)
      (compute-precedence-list (lambda (_ next) (next)))
      (compute-slot (lambda (self next name)
        (def body (next))
        (if (eq? name 'expand-declaration)
          (lambda ()
            (def expand (body))
            (lambda (context form) (log (.@ form kind)) (expand context form)))
          body)))
      (expand-declaration (inherited)
        (lambda (context form)
          (case (.@ form kind)
            ((require) (unless (.@ context approved) (error "service declaration refused")) [])
            ((property) (property-declarations context form (inherited)))
            (else ((inherited) context form))))))))
;; Construct one candidate only after every declaration/finalizer has succeeded.
;; A shared root feeds two branches and their diamond; metadata/caches follow the
;; same ordinary inheritance and invalidation rules as other POO objects.
(def (build-service expander amount context)
  (def declared (.declare expander context
    (require approval (.o))
    (property amount (.o (type Integer) (default amount)))
    (private secret (.o (constant 'token)))))
  (def source (make-object supers: [declared] protocol: expander))
  (def billing (.mix source)) (def risk (.mix source))
  (object<-alist (list (cons 'source source) (cons 'billing billing)
    (cons 'risk risk) (cons 'join (.mix billing risk)))))
;; Demand the generated public getter at each branch, never the private annotation.
(def (report family)
  (map (lambda (name) ((read-slot (.ref family name) 'read-amount))) '(billing risk join)))
;; A reusable Reader/FUN action reads CURRENT approval/revision on each invocation.
;; Source edits still need fresh elaboration; previous approval/catalog is not cached.
(def (service-action expander amount)
  (.call gp.Observation. .map (lambda (family) (cons (report family) family))
    (lambda (context) (build-service expander amount context))))
