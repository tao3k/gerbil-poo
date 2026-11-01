;;; Portable replay admission uses Gerbil data predicates and ordinary ports.
(export copy-test-cases!)
(import :std/test :std/error :std/iter
        (prefix-in :clan/poo/testing/property/generator generator.)
        (prefix-in :clan/poo/testing/property property.)
        (prefix-in :clan/poo/testing/property/replay replay.))

;; Copy admission covers constructor identities, encoded envelopes and imported
;; data through the same public codec boundary; no private copier is exported.
(def (copy-test-cases!)
  ;; Resource refusal has one established diagnostic across every data carrier.
  (def (budget? cause)
    (and (Error? cause) (equal? (Error-message cause) "replay data budget exceeded")))
  ;; One ordinary error boundary serves codec identities, exports and imports.
  (def (nonportable? cause)
    (and (Error? cause) (equal? (Error-message cause) "nonportable replay datum")))
  (test-case "portable identities refuse fresh symbols and keywords through nested data"
    (for (token (list (gensym 'identity) (string->uninterned-keyword "identity")))
      (for (wrap (list values list vector (cut cons 'format <>)))
        (check-exception (replay.make-codec (wrap token) values values) nonportable?))))
  (test-case "fresh payload tokens refuse before writing any envelope bytes"
    (for (token (list (gensym 'service) (string->uninterned-keyword "service")))
      (def domain (property.make-specification (lambda (value) (or (symbol? value) (keyword? value)))
        (lambda (_) 0)))
      (def report (property.check-property (generator.generator-unit token)
        (lambda (value) (not (eq? value token))) domain cases: 1 shrink-budget: 0))
      (def output (open-output-string))
      (check-exception (replay.write-counterexample report
        (replay.make-codec 'service-v1 vector values) output) nonportable?)
      (check-equal? (get-output-string output) "")))
  (test-case "fresh imported tokens refuse before decoding or property admission"
    (for (token (list (gensym 'service) (string->uninterned-keyword "service")))
      (def decoded 0) (def admitted 0)
      (def output (open-output-string))
      (write (vector 'property-counterexample 1 'service-v1 (vector token)) output)
      (def codec (replay.make-codec 'service-v1 values
        (lambda (value) (set! decoded (1+ decoded)) value)))
      (def domain (property.make-specification
        (lambda (value) (set! admitted (1+ admitted)) (vector? value)) (lambda (_) 0)))
      (check-exception (replay.read-counterexample codec
        (open-input-string (get-output-string output)) domain (lambda (_) #f)) nonportable?)
      (check-equal? (list decoded admitted) '(0 0))))
  (test-case "interned reader-sensitive symbols and keywords preserve exact identity"
    (for (name '("" "a b" "." ":" "#:service"))
      (def symbol (string->symbol name)) (def keyword (string->keyword name))
      (def value (vector symbol keyword (cons #f symbol)))
      (def domain (property.make-specification vector? (lambda (_) 0)))
      ;; Falsity depends on the exact interned identities, not merely spelling.
      (def (property value) (not (and (eq? (vector-ref value 0) symbol)
        (eq? (vector-ref value 1) keyword) (eq? (cdr (vector-ref value 2)) symbol))))
      (def codec (replay.make-codec (vector symbol keyword) values values))
      (def report (property.check-property (generator.generator-unit value) property domain cases: 1))
      (def output (open-output-string))
      (replay.write-counterexample report codec output)
      (check (replay.read-counterexample codec (open-input-string (get-output-string output))
        domain property) => #f)))
  (test-case "portable vector width is admitted before contents and uses remaining fuel"
    (def wide (make-vector 64 #f))
    (vector-set! wide 0 values)
    (check-exception (replay.make-codec wide values values nodes: 8) budget?)
    ;; The first child spends four nodes; only one remains for the next child.
    ;; Its width two is impossible despite fitting the original node allowance.
    (check-exception (replay.make-codec (vector #(a b c) (vector values #f))
      values values nodes: 7) budget?))
  (test-case "portable exact width and depth boundaries preserve empty vectors"
    (check (and (replay.make-codec #(a b) values values nodes: 3 depth: 1) #t) => #t)
    (check-exception (replay.make-codec #(a b) values values nodes: 2 depth: 1) budget?)
    (check (and (replay.make-codec #(#()) values values nodes: 2 depth: 1) #t) => #t)
    (check-exception (replay.make-codec #(#(a)) values values nodes: 3 depth: 1) budget?)
    (def cycle (make-vector 1))
    (vector-set! cycle 0 cycle)
    (check-exception (replay.make-codec cycle values values nodes: 16 depth: 4) budget?))
  (test-case "portable feasible vectors retain forward first-error order"
    (def first (lambda () 'first)) (def last (lambda () 'last))
    (def cause (with-catch values (lambda ()
      (replay.make-codec (vector first last) values values nodes: 8))))
    (check-equal? (Error-message cause) "nonportable replay datum")
    (check-eq? (car (Error-irritants cause)) first))
  (test-case "portable envelope budget is shared and successful copies detach mutable data"
    (def identity (vector 'bounded 1)) (def value (vector 'a 'b)) (def decoded #f)
    (def domain (property.make-specification vector? (lambda (_) 0)))
    (def report (property.check-property (generator.generator-unit value) (lambda (_) #f)
      domain cases: 1 shrink-budget: 0))
    ;; Envelope costs one root, two tags, a three-node identity and a three-node
    ;; payload: nine nodes in total. Per-child counters must not reset that sum.
    (def output (open-output-string))
    (check-exception (replay.write-counterexample report
      (replay.make-codec identity values values nodes: 8 depth: 2) output) budget?)
    (check-equal? (get-output-string output) "")
    (def codec (replay.make-codec identity values
      (lambda (datum) (set! decoded datum) datum) nodes: 9 depth: 2))
    (vector-set! identity 0 'changed)
    (replay.write-counterexample report codec output)
    (vector-set! value 0 'changed)
    (check (replay.read-counterexample codec (open-input-string (get-output-string output))
      domain (lambda (_) #f)) => #f)
    (check-equal? decoded #(a b))
    (check (eq? decoded value) => #f)
    ;; Compact strings/bytes spend payload units from that same node allowance.
    (def mixed (vector "ab" (list->u8vector '(1 2)) #f))
    (def mixed-report (property.check-property (generator.generator-unit mixed) (lambda (_) #f)
      domain cases: 1 shrink-budget: 0))
    (def mixed-output (open-output-string))
    (check-exception (replay.write-counterexample mixed-report
      (replay.make-codec 'mixed values values nodes: 11) mixed-output) budget?)
    (def mixed-codec (replay.make-codec 'mixed values values nodes: 12))
    (replay.write-counterexample mixed-report mixed-codec mixed-output)
    (check (replay.read-counterexample mixed-codec (open-input-string (get-output-string mixed-output))
      domain (lambda (datum) (string-set! (vector-ref datum 0) 0 #\z)
        (u8vector-set! (vector-ref datum 1) 0 9) #f)) => #f)
    (check-equal? (vector-ref mixed 0) "ab")
    (check-equal? (u8vector-ref (vector-ref mixed 1) 0) 1))
  (test-case "portable over-budget import skips decoding and retries without widening limits"
    (def decoded 0) (def properties 0)
    (def codec (replay.make-codec 'bounded values
      (lambda (datum) (set! decoded (1+ decoded)) datum) nodes: 16))
    (def domain (property.make-specification vector? (lambda (_) 0)))
    (def oversized (open-output-string))
    (write (vector 'property-counterexample 1 'bounded (make-vector 64 #f)) oversized)
    (check-exception (replay.read-counterexample codec (open-input-string (get-output-string oversized))
      domain (lambda (_) (set! properties (1+ properties)) #f)) budget?)
    (check-equal? (list decoded properties) '(0 0))
    (def output (open-output-string))
    (def report (property.check-property (generator.generator-unit #(#f)) (lambda (_) #f)
      domain cases: 1 shrink-budget: 0))
    (replay.write-counterexample report codec output)
    (check (replay.read-counterexample codec (open-input-string (get-output-string output))
      domain (lambda (_) (set! properties (1+ properties)) #f)) => #f)
    (check-equal? (list decoded properties) '(1 1))))

