;;; GenericFamily.Model: native construction of checked heterogeneous generics.
(export Model. Projection. methods.instantiate<-shared-expansion methods.refresh<-projection build prepare refresh
        family? family-ref family-has? family-keys family-built family-reused invoke failure? failure-key failure-stage failure-cause)
(import :std/iter (only-in :std/list/list-builder with-list-builder) (only-in :std/list/list delete-duplicates/hash)
        ./object (only-in ./mop define-type .defgeneric)
        (prefix-in ./multimethod multimethod.)
        (prefix-in ./dispatch-extension dispatch-extension.))
;; Families own provenance and warm certificates; tables never escape.
;; Private owner-bound generic collection. Contexts justify reuse, services retain
;; warm certificates, and built/reused record actual selected constructor branches.
(defstruct family (owner contexts services built reused) final: #t)
;; Return the checked service for key; missing keys raise through hash-ref.
(def (family-ref current key) (hash-ref (family-services current) key))
;; Test current support without constructing or invoking a generic.
(def (family-has? current key) (hash-key? (family-services current) key))
;; List current service keys; hash iteration order is not a declaration order.
(def (family-keys current) (hash-keys (family-services current)))
;; Invoke the current checked generic and transport its cache successor.
;; Return the same family on a cache hit; otherwise privately copy the service table.
(def (invoke current key . args)
  (def prior (family-ref current key))
  (defvalues (result next) (apply dispatch-extension.invoke prior args))
  (if (eq? prior next) (values result current)
    (let (services (hash-copy (family-services current)))
      (hash-put! services key next)
      (values result (make-family (family-owner current) (family-contexts current) services
                                 (family-built current) (family-reused current))))))
;; Validate the complete generic association list and stage a private cold table.
;; Invalid certificates and duplicate bindings raise before publication.
(def (cold-family owner bindings)
  (def services (make-hash-table-eq))
  (unless (list? bindings) (error "expected generic association list"))
  (for (entry bindings)
    (unless (and (pair? entry) (symbol? (car entry)) (dispatch-extension.certificate? (cdr entry)))
      (error "invalid generic binding" entry))
    (when (hash-key? services (car entry)) (error "duplicate generic binding" (car entry)))
    (hash-put! services (car entry) (cdr entry)))
  (make-family owner #f services (map car bindings) []))
;; Closed per-key projection and its constructor protocol. The default expands
;; separately for seed and methods, preserving custom identity-sensitive behavior.
;; .instantiate returns a checked generic or raises a keyed registration/negative
;; failure. Opt into shared expansion only for pure immutable reconstructed inputs.
(define-type (Projection. @ [] project expand)
  .instantiate:
  (lambda (seed methods watches key context)
    (build-generic
      (lambda (name inputs _)
        (defvalues (policy cooked) (.call @ expand name inputs)) (seed name policy cooked))
      (lambda (name inputs _)
        (defvalues (policy cooked) (.call @ expand name inputs)) (methods name policy cooked))
      watches key context #f)))
;; Derive one closed expansion per changed generic. Both existing constructors
;; receive the same immutable reconstructed policy/cooked values, with no adapter
;; closures. Retained generics never reach this callback. Expand failures retain
;; registration provenance; seed validation and negative watches still execute.
;; This is opt-in: callbacks must permit sharing and must not observe fresh identity
;; or mutate the reconstructed values between seed and method construction.
(define-type (methods.instantiate<-shared-expansion @ [] expand)
  .instantiate:
  (lambda (seed methods watches key context)
    (defvalues (policy cooked) (at-stage key 'registration (cut expand key context)))
    (build-generic seed methods watches key policy cooked)))
;; Project closed contexts in key order and retain only same-owner equal contexts.
;; Changed entries invoke the projection's instantiation protocol; keyed failures
;; propagate without publishing a partial table. Repeated keys keep the first entry.
(def (project-family owner projection keys seed methods watches previous policy cooked)
  (unless (and (list? keys) (andmap symbol? keys)) (error "generic keys must be symbols"))
  (def prior (and previous (eq? owner (family-owner previous)) (family-contexts previous) previous))
  (def contexts (make-hash-table-eq))
  ;; Capture the owner-bound constructor callback once, not once per changed key.
  (def instantiate (.@ projection .instantiate))
  (def services (if prior (family-services prior) (make-hash-table-eq)))
  (def copied? (not prior))
  (def built [])
  (def reused [])
  (for (key keys)
    (unless (hash-key? contexts key)
      (let (context (at-stage key 'projection (cut .call projection project key policy cooked)))
      (hash-put! contexts key context)
      (if (and prior (hash-key? (family-contexts prior) key)
               (equal? context (hash-ref (family-contexts prior) key)))
        (set! reused (cons key reused))
        (begin
          (unless copied? (set! services (hash-copy services)) (set! copied? #t))
          (hash-put! services key
            (instantiate seed methods watches key context))
          (set! built (cons key built)))))))
  (make-family owner contexts services (reverse built) (reverse reused)))
;; Only the projected context reaches compilation. Equal version labels or a
;; caller's clean-key predicate cannot authorize reuse. Model identity binds code.
;; Derive cold build and retained refresh from the same closed projection protocol.
;; Only projected values reach constructors; model identity also binds code/watches.
(define-type (methods.refresh<-projection @ [] projection keys seed methods watches)
  .build: (lambda (policy cooked)
    (def current (project-family @ projection keys seed methods watches #f policy cooked))
    (map (lambda (key) (cons key (family-ref current key)))
         (delete-duplicates/hash keys from-end?: #t)))
  .prepare: (lambda (policy cooked) (project-family @ projection keys seed methods watches #f policy cooked))
  .refresh: (lambda (previous policy cooked) (project-family @ projection keys seed methods watches previous policy cooked)))
;; Private failure provenance: service key, registration/negative/projection phase
;; and original cause; atomic publishers retain their old version on refusal.
(defstruct failure (key stage cause) final: #t)
;; Evaluate a possibly multiple-valued callback and attach key/phase on exceptions.
;; Success values are forwarded unchanged; arbitrary callback effects are not rolled back.
(def (at-stage key phase thunk)
  (try (thunk) (catch (cause) (raise (make-failure key phase cause)))))
;; Construct a cold seed, install declared methods and check negative watches.
;; A nonempty seed cache or failed registration/watch raises a typed keyed failure.
(def (build-generic seed methods watches key policy cooked)
  (def candidate
    (at-stage key 'registration
      (lambda ()
        (def base (seed key policy cooked))
        (unless (= (multimethod.cache-size base) 0) (error "generic seed must have an empty cache"))
        (dispatch-extension.patch base (methods key policy cooked)))))
  (at-stage key 'negative (lambda () (dispatch-extension.check candidate (watches key)))))
;; Native generic-family model. The default prepares cold bindings; projection
;; mixins replace refresh with closed-context reuse while retaining seed/watch checks.
(define-type (Model. @ [] keys seed watches)
  methods: (lambda (_ __ ___) [])
  .prepare: (lambda (policy cooked) (cold-family @ (.build policy cooked)))
  .refresh: (lambda (_ policy cooked) (.prepare policy cooked))
  .build:
  (lambda (policy cooked)
    (unless (and (list? keys) (andmap symbol? keys)) (error "generic keys must be symbols"))
    (def installed (make-hash-table-eq))
    (with-list-builder (add)
      (for (key keys)
        ;; Like Lean Partial.build, repeated keys retain the first installation.
        (unless (hash-key? installed key)
          (add (cons key (build-generic seed methods watches key policy cooked)))
          (hash-put! installed key #t))))))
;; Build the model's checked association list from policy and cooked view; errors propagate.
(.defgeneric (build model policy cooked) slot: .build)

;; Prepare a complete cold family under this model's owner and projection protocol.
(.defgeneric (prepare model policy cooked) slot: .prepare)
;; Refresh a complete family; projected models retain equal closed contexts.
;; An incompatible owner or the default model takes the cold construction path.
(.defgeneric (refresh model previous policy cooked) slot: .refresh)
