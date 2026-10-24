;;; CyclicAccess's ten equations and lossy cooked view on real POO objects.
(export config equations cook services start revise attestation start-attested revise-attested rebase-attested invoke-attested
        attested? attested-memo attested-input attested-enabled attested-closure attestation-failure? attestation-failure-stage attestation-failure-cause)
(import (runtime: :clan/poo/recursive)
        (prefix-in (only-in ../recursive Generator. bind map-interaction request
                   source-error source-error-message source-error? value value-result) recursive.)
        (runtime: :clan/poo/recursive-cache)
        (prefix-in (only-in ../recursive-cache diagnostic? empty receipt-result run) cached.)
        (only-in ../mop Any Bool Type.)
        (only-in :std/values first-value)
        :std/iter
        ../closure
        ../object
        (runtime: :clan/poo/cyclic-publication)
        (prefix-in (only-in ../cyclic-publication invoke prepare publish
                   version-view) cyclic-publication.))
;; Construct immutable trust, training, team and compliance policy.
(def (config (trusted #t) (trained #t) (team-member #t) (compliant #t))
  (.o (trust trusted) (training trained) (team team-member) (compliance compliant)))
;; Compile ten positive equations; cycles cannot invent an unseeded authority.
(def (equations config seed)
  ;; At least two independent policy facts must support review.
  (def (quorum a b c) (either (both a b) (either (both a c) (both b c))))
  (vector (literal seed) (either (fact 0) (fact 2)) (both (fact 1) (literal (.@ config trust)))
          (literal (.@ config training))
          (both (fact 2) (quorum (fact 3) (literal (.@ config team)) (literal (.@ config compliance))))
          (either (fact 4) (fact 6)) (both (fact 5) (literal (.@ config team)))
          (both (fact 6) (fact 8)) (both (fact 2) (literal (.@ config compliance)))
          (either (fact 7) (fact 5))))
;; Expose only the public capabilities and active fact indices.
(def (cook facts)
  (.o (member (closure-ref facts 2)) (approved (closure-ref facts 5)) (release (closure-ref facts 7))
      (active (filter (cut closure-ref facts <>) (iota 10)))))
;; Bind grant/explanation services to this exact cooked immutable snapshot.
(def (services view)
  (list (cons 'grant (lambda (user consent)
                      (cond ((not consent) '(error consent))
                            ((.@ view release) (list 'ok (string-append "release:" user)))
                            (else '(error not-authorized)))))
        (cons 'explain (lambda () (.@ view active)))))
;; Joint approval checks release policy and concrete service observations.
(def (admit require-release candidate)
  (def view (cyclic-publication.version-view candidate))
  (and (or (not require-release) (.@ view release))
       (equal? (first-value (cyclic-publication.invoke candidate 'explain)) (.@ view active))
       (equal? (first-value (cyclic-publication.invoke candidate 'grant "sample" #f)) '(error consent))))
;; Low-level literal-seed construction; use start-attested for checked requests.
(def (start config seed (require-release #f))
  (cyclic-publication.prepare (equations config seed) cook services
                              (cut admit require-release <>)))
;; Re-solve the positive graph from bottom; rejected candidates retain old.
(def (revise old config seed (require-release #f))
  (cyclic-publication.publish old (equations config seed) cook services
                              (cut admit require-release <>)))

;; Native representation of Lean's Nat × mode request: immutable pair, with
;; symbols corresponding to Lean mode strings. Reject malformed keys before reuse.
(def attestation-input (.cc Type. .element?: (lambda (input)
  (and (pair? input) (exact-integer? (car input)) (>= (car input) 0) (symbol? (cdr input))))))
;; A recursive request is an immutable (depth . mode) pair. Shared children expose
;; real memo reuse; a completed false, explicit source error and cycle stay distinct.
(def attestation
  (.cc recursive.Generator. input: attestation-input output: Bool
    generate: (lambda (input)
      (let ((depth (car input)) (mode (cdr input)))
        (cond ((eq? mode 'cycle) (recursive.request input))
          ((eq? mode 'failed) (recursive.source-error "attestation-source"))
          ((not (and (exact-integer? depth) (>= depth 0))) (recursive.source-error "invalid attestation depth"))
          ((= depth 0) (recursive.value (eq? mode 'active)))
          (else
            (let (child (cons (- depth 1) mode))
              (recursive.bind (recursive.request child) (lambda (first)
                (recursive.map-interaction (lambda (second) (and first second)) (recursive.request child)))))))))))
;; Successful publication binds the exact evaluated request to its closed version.
;; This wrapper never substitutes a literal supplied seed for an evaluation receipt.
(defstruct attested (program input enabled receipt memo closure) final: #t)
;; Recursive/source/publication failures retain their distinct provenance.
(defstruct attestation-failure (stage cause) final: #t)
;; Stage recursive evaluation before the existing least closure and atomic publisher.
;; Any failure returns the exact old wrapper/memo; external callback effects are not
;; rolled back. Rebase explicitly starts fresh memo under a different program owner.
(def (prepare-attested previous program input budget configuration require-release rebase?)
  (def memo (if (and previous (not rebase?)) (attested-memo previous) (cached.empty program)))
  (try
    (defvalues (receipt next) (cached.run program input budget memo))
    (cond ((cached.diagnostic? receipt)
           (values previous (make-attestation-failure 'recursive receipt)))
          ((recursive.source-error? (cached.receipt-result receipt))
           (values previous (make-attestation-failure 'source
             (recursive.source-error-message (cached.receipt-result receipt)))))
          (else
            (let (enabled (recursive.value-result (cached.receipt-result receipt)))
              (unless (boolean? enabled) (error "attestation must return Boolean"))
              (defvalues (closure issue)
                (if previous (revise (attested-closure previous) configuration enabled require-release)
                  (start configuration enabled require-release)))
              (if issue (values previous (make-attestation-failure 'publication issue))
                (values (make-attested program input enabled receipt next closure) #f)))))
    (catch (cause) (values previous (make-attestation-failure 'recursive cause)))))
;; Start from a checked recursive request, then materialize/admit the Boolean DAG.
(def (start-attested program input budget configuration (require-release #f))
  (prepare-attested #f program input budget configuration require-release #f))
;; Retain exact program memo while re-solving changed policy from the least bottom.
(def (revise-attested previous input budget configuration (require-release #f))
  (prepare-attested previous (attested-program previous) input budget configuration require-release #f))
;; Code/source changes require new memo; the old public version stays usable on refusal.
(def (rebase-attested previous program input budget configuration (require-release #f))
  (prepare-attested previous program input budget configuration require-release #t))
;; Thread the existing publication's actual service-cache successor while preserving
;; the request/evaluation binding and memo; failed invocation publishes no wrapper.
(def (invoke-attested previous key . arguments)
  (defvalues (answer closure) (apply cyclic-publication.invoke (attested-closure previous) key arguments))
  (values answer (if (eq? closure (attested-closure previous)) previous
    (make-attested (attested-program previous) (attested-input previous) (attested-enabled previous)
      (attested-receipt previous) (attested-memo previous) closure))))
