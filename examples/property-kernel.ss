;;; Independent-library examples: standard Gerbil plus the generic testing modules.
(export property-kernel-test)
(import (prefix-in :clan/poo/testing/property/test assertion.) :std/test :std/error :std/iter (only-in :std/list/list take drop)
        (prefix-in :clan/poo/testing/property/generator generator.)
        (prefix-in :clan/poo/testing/property property.)
        (prefix-in :clan/poo/testing/property/model model.)
        (only-in ./property-products product-test-cases!)
        (only-in ./property-numbers rational-test-cases! integer-range-test-cases!)
        (only-in ./property-filters filter-test-cases! proposal-test-cases!)
        (only-in ./property-scopes declaration-test-cases! copy-test-cases! function-test-cases! assertion-test-cases! scope-test-cases! nested-scope-test-cases! classification-test-cases! codec-scope-test-cases!)
        (only-in ./property-sizes size-test-cases! collection-source-test-cases!)
        (only-in ./property-traces trace-lazy-test-cases! trace-draw-test-cases! trace-sequence-test-cases! trace-action-test-cases!))

;; A dependent packet exposes its generated count and its matching payload.
(defstruct packet (count payload) final: #t)
;; Domain admission is explicit; neither the kernel nor the example assumes Any.
(def (packet-valid? value)
  (and (packet? value) (exact-integer? (packet-count value)) (>= (packet-count value) 0)
    (list? (packet-payload value)) (= (packet-count value) (length (packet-payload value)))
    (every exact-integer? (packet-payload value))))
;; Count drives the tested failure; payload changes deliberately have zero cost.
(def packet-domain (property.make-specification packet-valid? packet-count))
;; Parent shrinking stays in its own nonnegative domain before dependent selection.
(def (count-shrinks count)
  (if (zero? count) [] (list 0 (quotient count 2) (1- count))))
;; Strict protocol diagnostics distinguish stale refusal from unrelated host errors.
(def (message? text)
  (lambda (cause) (and (Error? cause) (equal? (Error-message cause) text))))
;; Equal seed replay compares observable evidence, not private closure identity.
(def (same-failure left right)
  (check-equal? (property.report-status right) 'failed)
  (check-equal? (property.report-original right) (property.report-original left))
  (check-equal? (property.report-counterexample right) (property.report-counterexample left))
  (check-equal? (property.report-attempts right) (property.report-attempts left)))

;; A standard named property can bind later draws to earlier generated arguments.
(def signed-domain (property.make-specification exact-integer? abs))
;; Fixed domains are prepared once; dependent generation uses the existing bind tree.
(assertion.define-property balanced-arguments
  ((left (generator.make-generator (lambda (random size) (- (random (1+ (* 2 size))) size))
          generator.integer-shrinks) signed-domain)
   (right (generator.generator-unit (- left)) signed-domain))
  (= (+ left right) 0))
;; Names that coincide with implementation temporaries remain ordinary user bindings.
(assertion.define-property shadowed-arguments
  ((options (generator.generator-unit 2) signed-domain)
   (domain (generator.generator-unit (1+ options)) signed-domain)
   (report (generator.generator-unit (+ options domain)) signed-domain))
  (= report (+ options domain)))

;; One ordinary generator fixture exercises callback stages with the same source
;; leaf. Child drawing is separate so forbidden downstream effects are observable.
(def (revision-generator stage mutate guard draw-child)
  (def source (generator.make-generator (lambda (_random _size)
    (when (eq? stage 'draw) (mutate)) 1) (lambda (_) []) current?: guard))
  (def child (generator.make-generator (lambda (random size)
    (when (eq? stage 'child) (mutate)) (draw-child random size)) (lambda (_) [])))
  (case stage
    ((draw) source)
    ((map) (generator.generator-map source (lambda (value) (mutate) value)))
    ((bind child) (generator.generator-bind source (lambda (_)
      (when (eq? stage 'bind) (mutate)) child)))
    ((sized) (generator.generator-sized (lambda (_) (mutate) child) current?: guard))
    ((delay) (generator.generator-delay (lambda () (mutate) child) current?: guard))
    ((pack) (generator.make-tree-generator (lambda (random size)
      (generator.sample-sequence (list (generator.generate source random size))
        (lambda (values) (mutate) values)))))
    (else (error "unknown callback stage" stage))))
;; Keep bounded named registration groups in this module, without extra images.
(include "property-kernel/cases.scm")

;; This suite can be copied with testing/property.ss and testing/property/{generator,model,replay,test}.ss into a
;; fresh Gerbil project and run without POO modules, descriptors or object hooks.
(def property-kernel-test
  (test-suite "independent Gerbil property kernel"
    (product-test-cases!)
    (rational-test-cases!)
    (integer-range-test-cases!)
    (filter-test-cases!)
    (proposal-test-cases!)
    (scope-test-cases!)
    (nested-scope-test-cases!)
    (classification-test-cases!)
    (codec-scope-test-cases!)
    (assertion-test-cases!)
    (declaration-test-cases!)
    (function-test-cases!)
    (copy-test-cases!)
    (size-test-cases!)
    (collection-source-test-cases!)
    (trace-draw-test-cases!)
    (trace-lazy-test-cases!)
    (trace-sequence-test-cases!)
    (trace-action-test-cases!)
    (policy-domain-test-cases!)
    (source-list-test-cases!)
    (data-inspection-test-cases!)
    (binding-policy-test-cases!)
    (replay-tree-test-cases!)
    (trace-model-test-cases!)
))
