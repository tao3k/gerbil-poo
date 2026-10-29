;;; Function call generation shares structural selection with runtime wrapping.
(export FunctionArguments FunctionArguments.)
(import (only-in :std/list/list map-in-order delete-duplicates/hash)
        ../object ../mop ../function-signature ./type
        (prefix-in :clan/poo/testing/property/generator core.))

;; A call-row's types depend on supplied counts, never on optional default values.
(def (positional-types signature count)
  (def fixed (append (.get signature inputs) (.get signature optional)))
  (map (lambda (index) (if (< index (length fixed)) (list-ref fixed index) (.get signature rest))) (iota count)))
;; Decode one structurally selected call and check its supplied values only.
(def (arguments-valid? function arguments)
  (and (list? arguments)
    (let* ((signatures (.get function signatures)) (selected (select-signature signatures arguments)))
      (and selected
        (let (row (decode-arguments arguments (keyword-mode? signatures)))
          (and (every identity (map element? (positional-types selected (length (car row))) (car row)))
               (every (lambda (entry) (element? (cdr (assq (car entry) (.get selected keywords))) (cdr entry))) (cdr row))) #t)))))
;; One interpretation applies across clauses, exactly as in the checked wrapper.
(def (keyword-mode? signatures)
  (ormap (lambda (signature) (pair? (.get signature keywords))) signatures))

;; Compile child samplers once. Overlapping clauses first select a shape with
;; placeholders, then draw using the actual first clause's types; no rejection
;; loop or type-based fallback is needed. Shrinking preserves the chosen shape.
(def (argument-generator descriptor function)
  (def signatures (.get function signatures))
  (def keyword-mode (keyword-mode? signatures))
  (def types (delete-duplicates/hash (apply append (map (lambda (signature)
    (append (.get signature inputs) (.get signature optional) (map cdr (.get signature keywords))
            (if (.get signature rest) (list (.get signature rest)) []))) signatures))))
  (def samplers (map (lambda (type) (cons type (generator type))) types))
  ;; Resolve a child by descriptor identity, preserving explicit custom samplers.
  (def (child type) (cdr (assq type samplers)))
  ;; Recover the selected positional/keyword product without invoking any target.
  (def (product arguments)
    (def selected (select-signature signatures arguments))
    (def row (decode-arguments arguments keyword-mode))
    (def positionals (positional-types selected (length (car row))))
    (def keys (map car (cdr row)))
    (product-generator descriptor
      (map child (append positionals (map (lambda (key) (cdr (assq key (.get selected keywords)))) keys)))
      (lambda (_arguments) (append (car row) (map cdr (cdr row))))
      (lambda (values)
        (defvalues (pos rest) (split-at values (length positionals)))
        (encode-arguments pos (map cons keys rest) keyword-mode))))
  (def shapes (core.make-generator
    (lambda (random size)
      (def proposed (list-ref signatures (random (length signatures))))
      (def count (+ (length (.get proposed inputs)) (random (+ (length (.get proposed optional)) 1))
                    (if (.get proposed rest) (random (+ size 1)) 0)))
      (def keys (filter (lambda (entry) (or (memq (car entry) (.get proposed required-keywords)) (= (random 2) 1)))
                        (.get proposed keywords)))
      (def shape (encode-arguments (make-list count #f) (map (lambda (entry) (cons (car entry) #f)) keys) keyword-mode))
      shape)
    (lambda (_) [])))
  (from-generator descriptor
    (core.generator-bind shapes (lambda (shape) (generator-core (product shape))))
    (lambda (arguments) (.call (product arguments) measure arguments))
    shrink:
    (lambda (arguments) (.call (product arguments) shrink arguments))
    dependencies: (append (cons function signatures)
      (apply append (map (lambda (entry) (cons (cdr entry) (.get (cdr entry) sources))) samplers)))))

;; This Type recognizes call rows, not arbitrary procedure implementations. It
;; composes with normal List/Tuple descriptors and the same finite test runner.
(define-type (FunctionArguments. @ Type. function)
  .element?: (lambda (arguments) (arguments-valid? function arguments))
  .generator: (lambda () (argument-generator @ function)))
;; Require actual Function descriptors; malformed custom shapes fail explicitly.
(def (FunctionArguments function)
  (validate Type function)
  (unless (and (.has? function signatures) (pair? (.get function signatures)))
    (error "FunctionArguments requires a Function descriptor"))
  (.cc FunctionArguments. function: function sexp: `(FunctionArguments ,(.get function sexp))))
