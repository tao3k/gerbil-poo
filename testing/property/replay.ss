;;; Portable counterexamples are data with application-owned codec identity.
(export make-codec write-counterexample read-counterexample)
(import :std/error :std/iter (only-in :std/vector/vector vector-fold/index)
        ../property (only-in ./generator with-sources with-generation-check))
;; The codec owns format/specification/generator identity and bounded data admission.
(defstruct replay-codec (identity encode decode current nodes depth) final: #t constructor: :init!)
;; Capture codec identity as finite data rather than retaining a mutable caller key.
(defmethod {:init! replay-codec}
  (lambda (self identity encode decode current nodes depth)
    (unless (and (procedure? encode) (procedure? decode) (procedure? current)
      (exact-integer? nodes) (> nodes 0) (exact-integer? depth) (> depth 0))
      (error "invalid replay codec"))
    (set! (replay-codec-nodes self) nodes) (set! (replay-codec-depth self) depth)
    (set! (replay-codec-identity self) (copy-data identity nodes depth))
    (set! (replay-codec-encode self) encode) (set! (replay-codec-decode self) decode)
    (set! (replay-codec-current self) current)))
;; Application identities should include format, specification and generator revisions.
(def (make-codec identity (encode : :procedure) (decode : :procedure)
                 current?: (current (lambda () #t)) nodes: (nodes 4096) depth: (depth 64))
  (make-replay-codec identity encode decode current nodes depth))
;; Bound and copy proper/improper data trees; cycles consume fuel and are refused.
;; Reader allocation itself stays under the existing process heap/time guard.
(def (copy-data datum nodes depth)
  (def remaining nodes)
  ;; Nodes and compact payload units spend the same invocation-owned allowance.
  (def (charge! amount)
    (set! remaining (- remaining amount))
    (when (< remaining 0) (error "replay data budget exceeded")))
  ;; Recursive copying owns one shared node budget, including strings and vectors.
  (def (copy datum depth)
    (charge! 1)
    (when (< depth 0) (error "replay data budget exceeded"))
    (cond
      ((pair? datum) (cons (copy (car datum) (1- depth)) (copy (cdr datum) (1- depth))))
      ((vector? datum)
       (def width (vector-length datum))
       ;; Each child needs at least one node. Reject impossible width/depth before
       ;; allocating the destination or inspecting children. Empty vectors fit at
       ;; depth zero. Standard forward fold fixes shared-budget admission order.
       (when (or (> width remaining) (and (positive? width) (zero? depth)))
         (error "replay data budget exceeded"))
       (vector-fold/index (lambda (index output value)
         (vector-set! output index (copy value (1- depth))) output)
         (make-vector width) datum))
      ((u8vector? datum)
       (charge! (u8vector-length datum)) (u8vector-copy datum))
      ((string? datum)
       (charge! (string-length datum)) (string-copy datum))
      ((or (null? datum) (boolean? datum) (symbol? datum) (keyword? datum)
           (char? datum) (exact-integer? datum)) datum)
      (else (error "nonportable replay datum" datum))))
  (copy datum depth))
;; Both codec and application provenance bracket each stage. Guards are the
;; existing pure Boolean observers; exceptions retain their original identity.
(def (with-codec codec action (current (lambda () #t)))
  ;; Preserve the codec refusal before observing the application context.
  (def (check)
    (unless (eq? ((replay-codec-current codec)) #t) (error "stale replay codec"))
    (unless (eq? (current) #t) (error "stale replay context")))
  ;; Parent authority brackets the complete local stage, without being stored
  ;; in the codec. Ordinary callback exceptions bypass trailing checks unchanged.
  (with-sources []
    (check)
    ;; Local codec/context authority also belongs to nested checked actions.
    ;; The standard dynamic scope unwinds on every exit and is not retained by
    ;; a decoded value, generated tree or nested report.
    (with-generation-check check
      (begin0 (action) (check)))))
;; Prepare a complete source-current envelope before entering the port write.
;; The port boundary is not a transaction: an I/O failure may leave partial bytes.
(def (write-counterexample report codec port)
  (unless (eq? (report-status report) 'failed) (error "failed property report required"))
  (def (current) (report-current? report))
  ;; Reconfirmation is a separate source-current stage: it can invalidate the
  ;; codec even when the report's own dependencies remain current.
  (with-codec codec (lambda ()
    (when (replay-counterexample report) (error "property witness no longer fails"))) current)
  (let (envelope (with-codec codec (lambda ()
      (let (datum (copy-data ((replay-codec-encode codec) (report-counterexample report))
          (replay-codec-nodes codec) (replay-codec-depth codec)))
        (copy-data (vector 'property-counterexample 1 (replay-codec-identity codec) datum)
          (replay-codec-nodes codec) (replay-codec-depth codec)))) current))
    (with-codec codec (lambda () (write envelope port) (newline port)) current)))
;; Source preflight precedes reading. Identity admission precedes decoding or
;; property callbacks; each later stage retains its own currentness boundary.
(def (read-counterexample codec port specification property policy: (policy (make-policy)))
  (unless (policy? policy) (error "property policy required"))
  ;; Reject stale preparation before consuming a caller-owned input. A read or
  ;; decoder error still keeps its exact cause; consumed bytes are not rolled back.
  (def (current) (specification-current? specification))
  (def envelope (with-codec codec (lambda ()
    (copy-data (read port) (replay-codec-nodes codec) (replay-codec-depth codec))) current))
  (unless (and (vector? envelope) (= (vector-length envelope) 4)
    (eq? (vector-ref envelope 0) 'property-counterexample)
    (eqv? (vector-ref envelope 1) 1)
    (equal? (vector-ref envelope 2) (replay-codec-identity codec))) (error "replay identity mismatch"))
  (with-codec codec (lambda ()
    (unless (eof-object? (read port)) (error "trailing replay data"))) current)
  (let (value (with-codec codec
      (lambda () ((replay-codec-decode codec) (vector-ref envelope 3))) current))
    ;; The shared witness boundary observes codec/domain sources between each
    ;; admission callback. Labels and required coverage belong only to generation.
    (check-counterexample value property specification policy: policy
      current?: (replay-codec-current codec))))
