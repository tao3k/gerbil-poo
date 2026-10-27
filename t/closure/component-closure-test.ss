(export component-closure-test)
(import :std/test :clan/poo/object :clan/poo/mop :clan/poo/brace :clan/poo/support/option :clan/poo/component-closure :clan/poo/feedback-graph
        (prefix-in :clan/poo/generalized-graph graph.) (prefix-in :clan/poo/dependency-analysis code.)
        (prefix-in :clan/poo/construction-cache cache.))
;; Standalone integer carrier uses the same public native Lens abstraction.
(def (identity-focus) (lens-of-get-set identity (lambda (value _) value)))
;; Focus capture and provider locality are part of the shared builder abstraction.
(def component-closure-test
  (test-suite "complete component lens preparation"
    (test-case "focus selection is once per supported key, never once per read or rebuild"
      (def count 0)
      (def build (component-group-builder '(a) (lambda (_) (set! count (+ count 1)) (identity-focus)) 0 0 8))
      (def source (graph.declaration '(a) [(cons 'a (code.pure 7))]))
      (defvalues (old error) (publish-feedback-graph #f source build (lambda (_ __) #t)))
      (check-equal? error #f) (check-equal? count 1)
      (defvalues (next ok) (publish-feedback-graph old
        (graph.define (graph-cache-source old) 'a (code.pure 8)) build (lambda (_ __) #t)))
      (check-equal? ok #f) (check-equal? count 1))
    (test-case "extra projection metadata is guarded through reused group admission"
      (def metadata (.o (version 1)))
      (def focus (identity-focus))
      (def build (component-group-builder '(a) (lambda (_) focus) 0 0 8 sources: [metadata]))
      (defvalues (old _) (publish-feedback-graph #f
        (graph.declaration '(a) [(cons 'a (code.pure 7))]) build (lambda (_ __) #t)))
      (.putslot! metadata 'version ($constant-slot-spec 2))
      (def reached? #f)
      (defvalues (held stale) (publish-feedback-graph old (graph-cache-source old) build
        (lambda (_ __) (set! reached? #t) #t) builder: (.cc cache.Builder. allow: (lambda (_) #f))))
      (check (eq? held old) => #t) (check (not (not stale)) => #t) (check-equal? reached? #f))
    (test-case "undeclared internal reads cannot hide behind another SCC member"
      (def focus (identity-focus))
      (def build (component-group-builder '(a) (lambda (_) focus) 0 0 8))
      (def malicious (.cc code.Computation. reads: [] .evaluate: (lambda (provider) (provider 'a) (code.make-success 7))))
      (def reached? #f)
      (defvalues (held failure) (publish-feedback-graph #f
        (graph.declaration '(a) [(cons 'a malicious)]) build (lambda (_ __) (set! reached? #t) #t)))
      (check-equal? held #f) (check (not (not failure)) => #t) (check-equal? reached? #f))
    (test-case "duplicate lens support is rejected before selecting any focus"
      (def reached? #f)
      (check-exception (component-group-builder '(a a) (lambda (_) (set! reached? #t) (identity-focus)) 0 0 1) true)
      (check-equal? reached? #f))))
