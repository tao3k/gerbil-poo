;;; Explicit constant-base bootstrapping for self-describing inheritance protocols.
(export bootstrap-protocol bootstrap-protocol? close-protocol)
(import ./object ./closure)
;; Recognize the explicit self-hosted root, not any object with a protocol cycle.
;; This is native representation provenance, not a proof seal or security predicate.
(def (bootstrap-protocol? value)
  (and (object? value) (eq? (object-%protocol value) value)
       (pair? (object-%bootstrap value))))
;; Capture ordinary inherited hook values as the finite constant base described
;; by the paper. The root is its own meta-object; all NON-anchor metadata is still
;; compiled by its own compute-slot hook, with checked C3. The two pinned functions
;; are ordinary reflected slots and can be read while the root is constructing.
;; Anchors are a captured version, not a mutable alias to the input's future hooks.
;; A different kernel requires fresh bootstrap; ancestor metadata still invalidates
;; derived fields normally. Arbitrary callback effects remain caller obligations.
(def (bootstrap-protocol source)
  (unless (object? source) (error "protocol source object required"))
  (def anchors (map (lambda (name)
    (def hook (.ref source name))
    (unless (procedure? hook) (error "bootstrap hook must be a procedure" name))
    (cons name hook)) '(compute-precedence-list compute-slot)))
  (def root (make-object supers: [source] bootstrap: anchors
    slots: (map (lambda (entry) (cons (car entry) ($constant-slot-spec (cdr entry)))) anchors)))
  (object-protocol-set! root root)
  (instantiate-object! root)
  (seal-object! root))
;; Close positive recursive METADATA equations from false before cooking the hook
;; kernel. Reuse the existing finite least solver; no warm facts can self-support.
;; The inherited cook callback builds an ordinary protocol source from this exact
;; solution. Its result then goes through the same checked constant-base bootstrap.
;; This covers finite Boolean meta components, not arbitrary recursive procedures.
(def (close-protocol source)
  (unless (object? source) (error "recursive protocol source required"))
  (instantiate-object! source)
  (parameterize ((active-object-constructions (cons source (active-object-constructions))))
    (def facts (construct-closure (.ref source 'equations)))
    (def cooked ((.ref source 'cook) facts))
    (unless (object? cooked) (error "recursive protocol cook must return an object"))
    (bootstrap-protocol (.+ cooked (object<-alist [(cons 'facts facts)])))))
