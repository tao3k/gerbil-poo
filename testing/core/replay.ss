;;; Portable counterexamples are data with application-owned codec identity.
(export make-codec write-counterexample read-counterexample)
(import :std/error :std/iter ./property (only-in ./generator generator-unit))
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
;; Currentness is checked around application callbacks; no closure is serialized.
(def (with-codec codec action)
  (unless (eq? ((replay-codec-current codec)) #t) (error "stale replay codec"))
  (begin0 (action)
    (unless (eq? ((replay-codec-current codec)) #t) (error "stale replay codec"))))
;; Construct the complete envelope before writing so codec refusal emits no prefix.
;; Failed reports must still be current and false before they can become a corpus.
(def (write-counterexample report codec port)
  (unless (eq? (report-status report) 'failed) (error "failed property report required"))
  (when (replay-counterexample report) (error "property witness no longer fails"))
  (def datum (with-codec codec
    (lambda () (copy-data ((replay-codec-encode codec) (report-counterexample report))
      (replay-codec-nodes codec) (replay-codec-depth codec)))))
  (def envelope (copy-data (vector 'property-counterexample 1 (replay-codec-identity codec) datum)
    (replay-codec-nodes codec) (replay-codec-depth codec)))
  (write envelope port)
  (newline port))
;; Refuse a changed protocol before decoding or opening an application fixture.
;; The application's decoder reconstructs logical handles, never runtime owners.
(def (read-counterexample codec port specification property)
  (def envelope (copy-data (read port) (replay-codec-nodes codec) (replay-codec-depth codec)))
  (unless (and (vector? envelope) (= (vector-length envelope) 4)
    (eq? (vector-ref envelope 0) 'property-counterexample)
    (eqv? (vector-ref envelope 1) 1)
    (equal? (vector-ref envelope 2) (replay-codec-identity codec))) (error "replay identity mismatch"))
  (unless (eof-object? (read port)) (error "trailing replay data"))
  (with-codec codec
    (lambda ()
      (def value ((replay-codec-decode codec) (vector-ref envelope 3)))
      ;; Reuse the public property runner's domain/currentness gate with no draws
      ;; from an external source and zero shrinking. One constant witness only.
      (def report (check-property
        (generator-unit value) property specification cases: 1 shrink-budget: 0))
      (case (report-status report)
        ((passed) #t) ((failed) #f)
        ((error) (raise (report-cause report)))
        (else (error "replay witness refused" report))))))
