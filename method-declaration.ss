;;; Nonlocal method fragments use ordinary Slot metadata and inherited computation.
(export MethodDeclaration. method-fragment standard-combination simple-combination
        forwarding-combination inner-combination simula-combination
        typed-method-fragment invoke-declared declared-snapshot)
(import :std/iter (only-in :std/list/list foldr) (only-in :std/list/alist aremq) ./object ./mop ./declaration
        (prefix-in ./method-combination combination.)
        (prefix-in ./declarative-metadata metadata.) (prefix-in ./dispatch-extension extension.))
;; A private marker distinguishes method metadata from arbitrary user Slot fields.
;; Public descriptors remain extensible POO objects; no second declaration AST exists.
(def method-marker (list 'method-fragment))
;; Admit the whole finite group before calling any method body. In particular a
;; mismatched generic combination cannot silently discard another policy's qualifiers.
(def (admit-contributions accept contributions)
  (unless (and (procedure? accept) (list? contributions) (andmap accept contributions))
    (error "invalid method contribution group"))
  contributions)
;; A compiled group retains the exact certified seed, its declaration source and
;; immutable cache owner. It is private transport, not another declaration AST.
(defstruct declared-methods (signature declarations certificate) final: #t)
;; Return only the existing dispatch certificate for explicit revision/publication.
(def (declared-snapshot group) (force (declared-methods-certificate group)))
;; Invoke the established typed dispatcher. Transfer the complete cache successor
;; only after success; do not mutate the receiver or cache approval/body results.
(def (invoke-declared group arguments)
  (defvalues (result next) (apply extension.invoke (declared-snapshot group) arguments))
  (values result (if (eq? next (declared-snapshot group)) group
    (make-declared-methods (declared-methods-signature group)
      (declared-methods-declarations group) (delay next)))))
;; Read the optional signature without treating a stored false as an absent field.
;; A signature is an existing negative-watch certificate, shared by identity.
(def (method-signature metadata)
  (if (.has? metadata signature)
    (let (signature (.@ metadata signature))
      (unless (extension.certificate? signature) (error "invalid declared generic signature")) signature)
    #f))
;; Assemble inherited declaration data; Gerbil promises publish the COMPLETE
;; candidate once, when demanded. Parent groups remain unforced until the whole
;; inherited source is assembled, before checking the completed candidate.
;; Apply ancestor edits before local edits: a derived replacement wins at its
;; path, while each explicit batch keeps existing contribute/register order.
;; Registration and negative failures propagate with their existing phase/cause;
;; no partially installed certificate escapes and no method body runs at construction.
(def (compile-declared signature local parent)
  (unless (or (null? parent)
              (and (declared-methods? parent) (eq? signature (declared-methods-signature parent))))
    (error "inherited generic signature conflicts"))
  (def declarations (append (if (null? parent) [] (declared-methods-declarations parent)) local))
  (make-declared-methods signature declarations
    (delay (let-values (((certificate failure)
                        (extension.publish signature (map metadata.compile declarations))))
      (when failure (raise failure)) certificate))))
;; Each compiled Slot combines its local source-ordered block with the SAME
;; final receiver's delayed inherited group. Slot metadata edits recompile normally.
(def (method-slot name metadata)
  (def descriptor (.o (:: @ (instance Slot))
    (method-fragment method-marker)
    (signature (method-signature metadata))
    (contributions (.@ metadata contributions))
    (admit (if (.has? metadata admit) (.@ metadata admit) combination.standard-contribution?))
    (hidden (let (hidden? (if (.has? metadata hidden) (.@ metadata hidden) #f))
      (unless (boolean? hidden?) (error "method visibility must be Boolean")) hidden?))
    (compute (lambda (self inherited)
      (let* ((local (admit-contributions (.@ @ admit) (.@ @ contributions)))
            (parent (try (inherited)
              (catch (NoApplicableMethod? cause)
                (if (and (eq? (NoApplicableMethod-self cause) self) (eq? (NoApplicableMethod-slot cause) name))
                  [] (raise cause))))))
        (if (.@ @ signature)
          (begin
            (unless (eq? (.@ @ admit) metadata.declaration?) (error "typed generic requires method declarations"))
            (for-each (lambda (declaration) (depend-on-object! @ declaration)) local)
            (compile-declared (.@ @ signature) local parent))
          (begin (unless (list? parent) (error "inherited method slot is not a fragment list"))
            (append local parent))))))))
  (depend-on-object! descriptor metadata)
  (admit-contributions (.@ descriptor admit) (.@ descriptor contributions))
  (when (.@ descriptor signature)
    (unless (eq? (.@ descriptor admit) metadata.declaration?) (error "typed generic requires method declarations"))
    (for-each (lambda (declaration) (depend-on-object! descriptor declaration)) (.@ descriptor contributions)))
  descriptor)
;; Recognize only this protocol's method descriptors, never similarly named records.
(def (method-slot? descriptor)
  (and (object? descriptor) (.has? descriptor method-fragment)
       (eq? (.@ descriptor method-fragment) method-marker)))
;; Combine duplicate method names in first-occurrence order. Ordinary slot collisions,
;; mixed policies or conflicting visibility refuse before receiver construction.
;; The fold accumulator has distinct keys: standard aremq therefore removes its
;; only previous entry, preserving all unrelated pairs and their relative order.
(def (merge-method-fragments entries)
  (foldr (lambda (entry rest)
    (def previous (assq (car entry) rest))
    (if (not previous) (cons entry rest)
      (let ((left (cdr entry)) (right (cdr previous)))
        (unless (and (method-slot? left) (method-slot? right)
                     (eq? (.@ left admit) (.@ right admit))
                     (eq? (.@ left hidden) (.@ right hidden))
                     (eq? (.@ left signature) (.@ right signature)))
          (error "conflicting declaration fragments" (car entry)))
        (def metadata (.o
          (contributions (append (.@ left contributions) (.@ right contributions)))
          (admit (begin (unless (eq? (.@ left admit) (.@ right admit)) (error "revised method policies conflict"))
            (.@ left admit)))
          (hidden (begin (unless (eq? (.@ left hidden) (.@ right hidden)) (error "revised method visibility conflicts"))
            (.@ left hidden)))))
        (depend-on-object! metadata left) (depend-on-object! metadata right)
        (when (.@ left signature)
          (.setslot! metadata signature ($computed-slot-spec (lambda (_self _inherited)
            (unless (eq? (.@ left signature) (.@ right signature)) (error "revised generic signatures conflict"))
            (.@ left signature)))))
        (cons (cons (car entry) (method-slot (car entry) metadata))
          (aremq (car entry) rest))))) [] entries))
;; The SAME .declare syntax expands public/private record slots and method groups.
;; Other kinds use inherited expansion; inherited finalization still sees all groups.
(define-type (MethodDeclaration. @ Declaration.)
  (expand-declaration (inherited) (lambda (context form)
    (if (eq? (.@ form kind) 'method)
      (let (metadata (.@ form descriptor))
        [(cons (.@ form name) (method-slot (.@ form name) metadata))])
      ((inherited) context form))))
  (finalize-declarations (inherited) (lambda (context entries)
    ((inherited) context (merge-method-fragments entries)))))
;; Runtime/computed method names enter the same declaration protocol as static forms.
(def (method-fragment name contributions (accept combination.standard-contribution?) (hidden? #f))
  (declaration-form 'method name
    (object<-alist (list (cons 'contributions contributions) (cons 'admit accept) (cons 'hidden hidden?)))))
;; Typed declarations enter the SAME method form, merge/finalize and inherited
;; Slot path. The existing certified seed owns types, policy, C4 and watches.
;; Keep it shared across compatible fragments; a fresh certificate is a new signature.
(def (typed-method-fragment name certified declarations (hidden? #f))
  (unless (extension.certificate? certified) (error "invalid declared generic signature"))
  (declaration-form 'method name (.o
    (signature certified) (contributions declarations) (admit metadata.declaration?) (hidden hidden?))))
;; Standard, simple, forwarding, inner and Simula adapters all reuse existing
;; interpreters. They are functions suitable for .defgeneric's combination: option.
(def (standard-combination parts arguments)
  (combination.effective (admit-contributions combination.standard-contribution? parts) arguments
    (lambda (_) (error "no primary method"))))
;; Custom simple policies retain their existing short-circuit/failure semantics.
(def (simple-combination policy)
  (lambda (parts arguments)
    (combination.simple-effective policy (admit-contributions combination.simple-contribution? parts) arguments)))
;; Forwarding validates every replacement payload through the supplied Type.
(def (forwarding-combination payload-type)
  (lambda (parts arguments)
    (combination.forward-effective (admit-contributions combination.forward-contribution? parts) arguments
      (lambda (_) (error "no forwarding primary method")) (cut validate payload-type <>))))
;; Inner bodies use their existing next-thunk calling convention and terminal.
(def (inner-combination terminal)
  (lambda (parts arguments)
    (combination.inner-chain (admit-contributions procedure? parts) arguments terminal)))
;; Simula descriptors keep superclass-first prefixes and reverse suffix unwinding.
(def (simula-combination parts arguments)
  (combination.simula-effective (admit-contributions combination.simula-body? parts) arguments))
