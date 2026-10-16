;;; Executable finite-domain get-put, put-get and put-put controls for native lenses.
(export check-lens-laws lens-check lens-check? run-lens-check with-lens-checks
        lens-law-failure? lens-law-failure-law)
(import :std/iter ./object ./mop)
;; A failed law retains its precise name; it is not a universal proof certificate.
(defstruct lens-law-failure (law) final: #t)
;; A finite check uses actual immutable carrier values and structural equality.
;; It establishes only these supplied points, not laws for every Scheme value.
(def (check-lens-laws focus states values)
  (unless (and (object? focus) (list? states) (list? values)
               (procedure? (.@ focus .get)) (procedure? (.@ focus .set)))
    (error "native lens and finite law domains required"))
  (def get (.@ focus .get)) (def put (.@ focus .set))
  (for (state states)
    (unless (equal? (put (get state) state) state) (raise (make-lens-law-failure 'get-put)))
    (for (value values)
      (unless (equal? (get (put value state)) value) (raise (make-lens-law-failure 'put-get)))
      (for (next values)
        (unless (equal? (put next (put value state)) (put next state))
          (raise (make-lens-law-failure 'put-put))))))
  #t)
;; The constructor captures one immutable lens revision for repeatable checking.
;; Mutable components hidden inside composed-lens closures need explicit sources.
(defstruct law-check (focus values sources versions) final: #t)
;; Recognize only finite operational check descriptors made by this module.
(def lens-check? law-check?)
;; Register the native lens plus explicit dependencies; domain points are immutable
;; caller inputs. Empty value domains cannot exercise either put law and refuse.
(def (lens-check focus values sources: (sources []))
  (unless (and (object? focus) (list? values) (pair? values) (list? sources) (andmap object? sources))
    (error "lens check needs a nonempty focus domain and source objects"))
  (def all (cons focus sources))
  (for-each instantiate-object! all)
  (make-law-check focus values all (map object-revision all)))
;; Refuse changed lens metadata and supported writes while checking actual states.
;; Raw mutation, effects and host nontermination are outside this pure check protocol.
(def (run-lens-check check states)
  (unless (and (lens-check? check) (equal? (law-check-versions check)
                                        (map object-revision (law-check-sources check))))
    (error "stale or invalid lens check"))
  (parameterize ((active-object-constructions (append (law-check-sources check) (active-object-constructions))))
    (check-lens-laws (law-check-focus check) states (law-check-values check))))
;; Protect all check dependencies through a complete staged operation, including
;; raw steps and cooking between checks. This prevents a callback changing a lens
;; after admission and before the next check; supported writes refuse pre-mutation.
(def (with-lens-checks checks action)
  (unless (and (list? checks) (andmap lens-check? checks)
    (andmap (lambda (check) (equal? (law-check-versions check)
      (map object-revision (law-check-sources check)))) checks))
    (error "stale or invalid lens checks"))
  (parameterize ((active-object-constructions
      (append (apply append (map law-check-sources checks)) (active-object-constructions))))
    (action)))
