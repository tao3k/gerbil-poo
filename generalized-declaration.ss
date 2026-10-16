;;; Declaration elaboration for arbitrary raw/cooked carriers using Appendix B lenses.
(export Fragment Fragment. lens-fragment GeneralizedDeclaration. prepare-fragments .prototype
        prepared-fragments? fragment-names observe-fragments bind-fragments
        with-fragment-sources step-fragments fragment-descriptors)
(import :std/iter (only-in :std/list/list delete-duplicates/hash)
        ./object ./mop ./declaration (prefix-in ./generalized-prototype gp.))
;; The public descriptor is ordinary extensible POO metadata. Lens laws and local
;; pure callback termination are premises; admission checks only executable shape.
(define-type (Fragment @ Type.)
  .element?: (lambda (value)
    (and (object? value) (.has? value .type) (eq? (.@ value .type) @)
      (.has? value focus wrapper method sources .compile)
      (object? (.@ value focus)) (.has? (.@ value focus) .get .set)
      (procedure? (.@ (.@ value focus) .get)) (procedure? (.@ (.@ value focus) .set))
      (procedure? (.@ value wrapper)) (list? (.@ value sources))
      (andmap object? (.@ value sources)))))
;; Each fragment may have a different focus/method type on the SAME raw carrier.
;; .compile uses the existing lens compiler; compilation never invokes the wrapper.
(define-type (Fragment. @ [] focus wrapper method)
  .type: Fragment sources: []
  .compile: ((gp.focus-compiler focus wrapper) method))
;; Construct a validated lens fragment. Explicit extra sources cover callback and
;; payload metadata that cannot be inferred from arbitrary Scheme closures/data.
(def (lens-fragment focus wrapper method sources: (sources []))
  (validate Fragment (.cc Fragment. focus: focus wrapper: wrapper method: method sources: sources)))
;; The shared declaration Reader supports inherited custom forms and finalizers.
;; Labels identify contributions for reflection; lenses select actual raw locations.
(define-type (GeneralizedDeclaration. @ Declaration.)
  (expand-declaration (inherited) (lambda (context form)
    (if (eq? (.@ form kind) 'fragment)
      [(cons (.@ form name) (validate Fragment (.@ form descriptor)))]
      ((inherited) context form)))))
;; Only constructors in this module create prepared receipts; sources/versions are
;; private snapshots. This provenance is not a proof seal or raw mutation sandbox.
(defstruct prepared-fragments (snapshot sources versions names) final: #t)
;; Return a fresh label list without exposing the receipt's source/version storage.
(def (fragment-names prepared) (map identity (prepared-fragments-names prepared)))
;; Inspect the already expanded complete stream without rerunning a nonlocal
;; finalizer on subsets. Descriptor edits invalidate the owning preparation.
(def (fragment-descriptors prepared)
  (with-fragment-sources prepared (lambda ()
    (map identity (gp.prepared-fragments (prepared-fragments-snapshot prepared))))))
;; Stable source admission applies to zero-depth observation and cooking too.
;; Supported writes during callbacks refuse; external effects are never rolled back.
(def (with-fragment-sources prepared action)
  (unless (prepared-fragments? prepared) (error "prepared fragment source required"))
  (unless (equal? (prepared-fragments-versions prepared)
                 (map object-revision (prepared-fragments-sources prepared)))
    (error "stale generalized declaration sources"))
  (parameterize ((active-object-constructions
      (append (prepared-fragments-sources prepared) (active-object-constructions))))
    (action)))
;; Expand/finalize the whole ordered source, admit every descriptor, then compile
;; with the existing generalized assembler. No raw carrier or cooked result is built
;; until observation. Cook/get/set/wrapper callbacks must be pure and locally total.
(def (prepare-fragments expander context cook forms)
  (unless (and (object? expander) (object? context) (procedure? cook) (list? forms)
               (andmap object? forms)) (error "generalized declaration sources required"))
  (for-each instantiate-object! (cons expander (cons context forms)))
  (def initial (append (list expander context) forms (map (lambda (form) (.@ form descriptor)) forms)))
  (for-each instantiate-object! initial)
  (parameterize ((active-object-constructions (append initial (active-object-constructions))))
    (def entries (expand-declarations expander context forms))
    (unless (and (list? entries) (andmap (lambda (entry)
      (and (pair? entry) (symbol? (car entry)) (element? Fragment (cdr entry)))) entries)
      (= (length entries) (length (delete-duplicates/hash (map car entries)))))
      (error "distinct named generalized fragments required"))
    (def descriptors (map cdr entries))
    (def sources (delete-duplicates/hash
      (append initial descriptors (map (lambda (part) (.@ part focus)) descriptors)
        (apply append (map (lambda (part) (.@ part sources)) descriptors))) table: (make-hash-table-eq)))
    (for-each instantiate-object! sources)
    (parameterize ((active-object-constructions (append sources (active-object-constructions))))
      (def protocol (.cc gp.Protocol. cook: cook compile: (lambda (part)
        (def compiled (.@ part .compile))
        (unless (procedure? compiled) (error "fragment compiler must return a delayed prototype")) compiled)))
      (def snapshot (gp.prepare protocol descriptors))
      (make-prepared-fragments snapshot sources (map object-revision sources) (map car entries)))))
;; Same source grammar and computed splicing as .declare, with an arbitrary cooked
;; representation instead of the record-only object<-declarations constructor.
(defrule (.prototype expander context cook forms ...)
  (prepare-fragments expander context cook (declaration-forms forms ...)))
;; Finite raw self unfolding followed by one cooked interface boundary. The caller
;; supplies base/seed and depth; finite observation is not a general fixed-point proof.
(def (observe-fragments prepared base seed depth)
  (with-fragment-sources prepared
    (lambda () (gp.observe (prepared-fragments-snapshot prepared) base seed depth))))
;; One actual raw transition for controlled closure; no cooking of the result or
;; equality guess is performed here. It has the same source guard as observation.
(def (step-fragments prepared final base)
  (with-fragment-sources prepared
    (lambda () (gp.step (prepared-fragments-snapshot prepared) final base))))
;; Bind as native FUN Reader, reusing the existing observer and checking current
;; registered source versions on EACH seed; no result/approval is cached across calls.
(def (bind-fragments prepared base depth)
  (unless (prepared-fragments? prepared) (error "prepared fragment source required"))
  (def action (gp.bind-observer (prepared-fragments-snapshot prepared) base depth))
  (lambda (seed) (with-fragment-sources prepared (lambda () (action seed)))))
