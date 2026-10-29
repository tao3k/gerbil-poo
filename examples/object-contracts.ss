;;; JSON input, persistent lens revision and checked FUN execution on one value.
(export ServiceContract decode-service revise-action)
(import ../object
        ../mop
        ../brace
        ../number
        ../io
        (only-in ../type String Json)
        ../object-contract
        (runtime: :clan/poo/fun)
        (prefix-in (only-in :clan/poo/fun Observation.) fun.))
;; Reuse the Type recognizer protocol for the finite port domain.
(define-type (Port @ Type.)
  .element?: (lambda (value) (and (exact-integer? value) (<= 1 value 65535))))
;; Each independent obligation sees the whole admitted shape and caller's path.
(def (capacity-issues value location)
  (if (<= 0 (.get value used) (.get value capacity)) '()
    (list (.o kind: 'capacity-exceeded path: (append location '(used))))))
;; A separate relation illustrates accumulated obligations without a new DSL.
(def (transport-issues value location)
  (if (or (not (.get value secure)) (= (.get value port) 443)) '()
    (list (.o kind: 'secure-port-required path: (append location '(port))))))
;; Required data shape can be checked before arithmetic or relationship repair.
(def ServiceShape
  (.cc ObjectContract. identity: 'service
    responsibilities: (.o host: String port: Port capacity: Integer used: Integer secure: Bool)))
;; Derive the complete contract without duplicating its shape declarations.
(def ServiceContract
  (.cc ServiceShape
    obligations: (diagnostic-all [capacity-issues transport-issues])))
;; Existing JSON I/O supplies the parse. Preserve every decoded key so shape
;; admission, rather than a decoder silently dropping fields, rejects misspellings.
(def (decode-service text)
  (def decoded (<-json-string Json text))
  (unless (hash-table? decoded) (error "Service JSON must be an object"))
  (object<-alist (map (lambda (entry) (cons (string->symbol (car entry)) (cdr entry)))
                    (hash->list decoded))))
;; Compose persistent lens updates with admission, then the I/O consumer. A failed
;; candidate never reaches output; the original object remains the Reader context.
;; The consumer may return multiple values, as checked-action preserves them.
(def (revise-action additional-use port consume)
  (def admitted (checked-action ServiceContract consume))
  (.call fun.Observation. .bind
    (checked-action ServiceShape (lambda (current)
      (.call (.lens port) .set port
        (.call (.lens used) .set (+ (.get current used) additional-use) current))))
    (lambda (candidate)
      (lambda (_current) (admitted candidate)))))
