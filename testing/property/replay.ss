;;; Portable counterexamples are data with application-owned codec identity.
(export make-codec write-counterexample read-counterexample)
(import :std/error :std/iter ../property)
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
  ;; Recursive copying owns one shared node budget, including strings and vectors.
  (def (copy datum depth)
    (set! remaining (1- remaining))
    (when (or (< remaining 0) (< depth 0)) (error "replay data budget exceeded"))
    (cond
      ((pair? datum) (cons (copy (car datum) (1- depth)) (copy (cdr datum) (1- depth))))
      ((vector? datum) (list->vector (map (cut copy <> (1- depth)) (vector->list datum))))
      ((u8vector? datum)
       (set! remaining (- remaining (u8vector-length datum)))
       (when (< remaining 0) (error "replay data budget exceeded")) (u8vector-copy datum))
      ((string? datum)
       (set! remaining (- remaining (string-length datum)))
       (when (< remaining 0) (error "replay data budget exceeded")) (string-copy datum))
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
  (check)
  (begin0 (action) (check)))
;; Prepare a complete source-current envelope before entering the port write.
;; The port boundary is not a transaction: an I/O failure may leave partial bytes.
(def (write-counterexample report codec port)
  (unless (eq? (report-status report) 'failed) (error "failed property report required"))
  (def (current) (report-current? report))
  (let (envelope (with-codec codec (lambda ()
      (when (replay-counterexample report) (error "property witness no longer fails"))
      (let (datum (copy-data ((replay-codec-encode codec) (report-counterexample report))
          (replay-codec-nodes codec) (replay-codec-depth codec)))
        (copy-data (vector 'property-counterexample 1 (replay-codec-identity codec) datum)
          (replay-codec-nodes codec) (replay-codec-depth codec)))) current))
    (with-codec codec (lambda () (write envelope port) (newline port)) current)))
;; Identity admission precedes application callbacks. Decoding and execution have
;; separate source brackets, so a stale decoder cannot open a property fixture.
(def (read-counterexample codec port specification property policy: (policy (make-policy)))
  (unless (policy? policy) (error "property policy required"))
  (def envelope (copy-data (read port) (replay-codec-nodes codec) (replay-codec-depth codec)))
  (unless (and (vector? envelope) (= (vector-length envelope) 4)
    (eq? (vector-ref envelope 0) 'property-counterexample)
    (eqv? (vector-ref envelope 1) 1)
    (equal? (vector-ref envelope 2) (replay-codec-identity codec))) (error "replay identity mismatch"))
  (unless (eof-object? (read port)) (error "trailing replay data"))
  (def (current) (specification-current? specification))
  (let (value (with-codec codec
      (lambda () ((replay-codec-decode codec) (vector-ref envelope 3))) current))
    ;; The shared witness boundary observes codec/domain sources between each
    ;; admission callback. Labels and required coverage belong only to generation.
    (check-counterexample value property specification policy: policy
      current?: (replay-codec-current codec))))
