;;; Nonlocal method fragments use ordinary Slot metadata and inherited computation.
(export MethodDeclaration. method-fragment standard-combination simple-combination
        forwarding-combination inner-combination simula-combination)
(import :std/iter (only-in :std/list/list foldr) ./object ./mop ./declaration
        (prefix-in ./method-combination combination.))
;; A private marker distinguishes method metadata from arbitrary user Slot fields.
;; Public descriptors remain extensible POO objects; no second declaration AST exists.
(def method-marker (list 'method-fragment))
;; Admit the whole finite group before calling any method body. In particular a
;; mismatched generic combination cannot silently discard another policy's qualifiers.
(def (admit-contributions accept contributions)
  (unless (and (procedure? accept) (list? contributions) (andmap accept contributions))
    (error "invalid method contribution group"))
  contributions)
;; Missing inherited groups are empty, but errors raised by real parent computation
;; propagate unchanged. Stored false and ordinary procedure slots are malformed groups.
(def (inherited-contributions self name inherited)
  (try (let (parts (inherited))
    (unless (list? parts) (error "inherited method slot is not a fragment list")) parts)
    (catch (NoApplicableMethod? cause)
      (if (and (eq? (NoApplicableMethod-self cause) self) (eq? (NoApplicableMethod-slot cause) name))
        [] (raise cause)))))
;; Each compiled Slot prepends its local source-ordered contributions to the SAME
;; final receiver's delayed inherited group. Slot metadata edits recompile normally.
(def (method-slot name metadata)
  (def descriptor (.o (:: @ (instance Slot))
    (method-fragment method-marker)
    (contributions (.@ metadata contributions))
    (admit (if (.has? metadata admit) (.@ metadata admit) combination.standard-contribution?))
    (hidden (let (hidden? (if (.has? metadata hidden) (.@ metadata hidden) #f))
      (unless (boolean? hidden?) (error "method visibility must be Boolean")) hidden?))
    (compute (lambda (self inherited)
      (append (admit-contributions (.@ @ admit) (.@ @ contributions))
        (inherited-contributions self name inherited))))))
  (depend-on-object! descriptor metadata)
  (admit-contributions (.@ descriptor admit) (.@ descriptor contributions))
  descriptor)
;; Recognize only this protocol's method descriptors, never similarly named records.
(def (method-slot? descriptor)
  (and (object? descriptor) (.has? descriptor method-fragment)
       (eq? (.@ descriptor method-fragment) method-marker)))
;; Combine duplicate method names in first-occurrence order. Ordinary slot collisions,
;; mixed policies or conflicting visibility refuse before receiver construction.
(def (merge-method-fragments entries)
  (foldr (lambda (entry rest)
    (def previous (assq (car entry) rest))
    (if (not previous) (cons entry rest)
      (let ((left (cdr entry)) (right (cdr previous)))
        (unless (and (method-slot? left) (method-slot? right)
                     (eq? (.@ left admit) (.@ right admit))
                     (eq? (.@ left hidden) (.@ right hidden)))
          (error "conflicting declaration fragments" (car entry)))
        (def metadata (.o
          (contributions (append (.@ left contributions) (.@ right contributions)))
          (admit (begin (unless (eq? (.@ left admit) (.@ right admit)) (error "revised method policies conflict"))
            (.@ left admit)))
          (hidden (begin (unless (eq? (.@ left hidden) (.@ right hidden)) (error "revised method visibility conflicts"))
            (.@ left hidden)))))
        (depend-on-object! metadata left) (depend-on-object! metadata right)
        (cons (cons (car entry) (method-slot (car entry) metadata))
          (filter (lambda (other) (not (eq? (car other) (car entry)))) rest))))) [] entries))
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
;; Standard, simple, forwarding, inner and Simula adapters all reuse existing
;; interpreters. They are functions suitable for .defgeneric's combination: option.
(def (standard-combination parts arguments)
  (combination.effective (admit-contributions combination.standard-contribution? parts) arguments
    (lambda (_) (error "no primary method"))))
;; Custom simple policies retain their existing short-circuit/failure semantics.
(def (simple-combination policy)
  (lambda (parts arguments)
    (combination.simple-effective policy (admit-contributions combination.simple-contribution? parts) arguments)))
;; Forwarding validates every replacement payload through the supplied native Type.
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
