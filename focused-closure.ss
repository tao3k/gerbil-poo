;;; Close narrow raw components inside a wider non-record computation.
(export closure-focus focus-closure-action focused-closures-action publish-focused-closures)
(import (only-in :std/list/list foldr) ./object ./mop ./lens-laws
        ./generalized-declaration ./generalized-closure
        (prefix-in (only-in ./fun Observation.) fun.))
;; A stage retains one existing preparation, captured outer lens, immutable local
;; base, transition budget and local law checks. Sources are guarded as one family.
(defstruct focused-program (prepared check base budget checks) final: #t)
;; Describe a local closure without running it or inventing a new fragment compiler.
;; The outer lens-check captures mutable composed-lens dependencies explicitly.
(def (closure-focus prepared check base budget checks: (checks []))
  (unless (and (prepared-fragments? prepared) (lens-check? check)
               (exact-integer? budget) (>= budget 0) (list? checks) (andmap lens-check? checks))
    (error "prepared closure, captured outer lens and nonnegative budget required"))
  (make-focused-program prepared check base budget checks))
;; Hold EVERY stage's preparation and lens sources through the entire chain and
;; final cooking, so a later callback cannot invalidate an earlier accepted stage.
(def (with-focused-sources stages action)
  (unless (and (list? stages) (andmap focused-program? stages))
    (error "finite focused closure stages required"))
  ((foldr (lambda (stage rest) (lambda ()
      (with-fragment-sources (focused-program-prepared stage) (lambda ()
        (with-lens-checks (cons (focused-program-check stage) (focused-program-checks stage)) rest)))))
    action stages)))
;; One Reader maps the wider seed to its persistently replaced local fixed point.
;; Actual old/new child values join the finite law domain: an unlisted closure
;; result cannot silently pass put-get. Callback purity/immutability remain premises.
(def (focus-closure-action stage)
  (lambda (whole)
    (with-focused-sources [stage] (lambda ()
      (def check (focused-program-check stage))
      (def focus (lens-check-focus check))
      (def seed ((.@ focus .get) whole))
      (run-lens-check check [whole] extra-values: [seed])
      (defvalues (closed failure) (close-fragments (focused-program-prepared stage)
        (focused-program-base stage) seed (focused-program-budget stage)
        checks: (focused-program-checks stage)))
      (when failure (raise failure))
      (def raw (closed-raw closed))
      (run-lens-check check [whole] extra-values: [seed raw])
      (def updated ((.@ focus .set) raw whole))
      (run-lens-check check [updated] extra-values: [seed raw])
      updated))))
;; Revalidate each local equation against the FINAL wider raw value. Individually
;; lawful lenses may overlap: later replacement must not invalidate earlier closure.
;; This costs one additional raw step per stage, outside its search budget.
(def (validate-focused stage whole)
  (def check (focused-program-check stage))
  (def raw ((.@ (lens-check-focus check) .get) whole))
  (run-lens-check check [whole] extra-values: [raw])
  (for-each (lambda (local) (run-lens-check local [raw])) (focused-program-checks stage))
  (unless (equal? raw (step-fragments (focused-program-prepared stage) raw (focused-program-base stage)))
    (error "later focused update invalidated an earlier raw closure")))
;; Compose ordered persistent updates, final equation checks, then cooking with
;; the existing FUN Reader .map. No intermediate wider value is published.
(def (focused-closures-action stages cook)
  (unless (procedure? cook) (error "focused closure cooking procedure required"))
  (def chain (foldr (lambda (stage rest)
    (.call fun.Observation. .map rest (focus-closure-action stage))) identity stages))
  (lambda (whole)
    (with-focused-sources stages (lambda ()
      ((.call fun.Observation. .map (lambda (raw)
        (for-each (lambda (stage) (validate-focused stage raw)) stages)
        (cook raw)) chain) whole)))))
;; Publish only the final cooked family; any stage, validation or cooking failure
;; returns the exact old publication and original exception. No external-I/O rollback.
(def (publish-focused-closures old stages seed cook)
  (try (values ((focused-closures-action stages cook) seed) #f)
    (catch (failure) (values old failure))))
