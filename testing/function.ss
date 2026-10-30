;;; Function call generation shares structural selection with runtime wrapping.
(export FunctionArguments FunctionArguments.)
(import (only-in :std/list/list map-in-order delete-duplicates/hash)
        :std/struct/lru
        (only-in ../support/base defonce)
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
          ;; Gerbil owns the short-circuit traversal. A false field is the result,
          ;; not a discarded intermediate expression; no later Type is observed.
          (and (andmap (lambda (type value) (core.with-sources [] (element? type value)))
                       (positional-types selected (length (car row))) (car row))
               (every (lambda (entry)
                 (core.with-sources []
                   (element? (cdr (assq (car entry) (.get selected keywords))) (cdr entry)))) (cdr row))
               #t))))))
;; One interpretation applies across clauses, exactly as in the checked wrapper.
(def (keyword-mode? signatures)
  (ormap (lambda (signature) (pair? (.get signature keywords))) signatures))

;; Capture every declared input Type, but derive only actually supplied children.
;; Overlapping clauses first select a shape with placeholders; promises cannot
;; force a shadowed clause or an omitted optional/keyword/rest input. Shrinking
;; preserves the shape and shares successfully prepared children within this sampler.
(def (argument-generator descriptor function)
  (def signatures (.get function signatures))
  (def keyword-mode (keyword-mode? signatures))
  (def types (delete-duplicates/hash (apply append (map (lambda (signature)
    (append (.get signature inputs) (.get signature optional) (map cdr (.get signature keywords))
            (if (.get signature rest) (list (.get signature rest)) []))) signatures))))
  (def samplers (map (lambda (type)
    ;; Reuse the project's promise abstraction; no second cache or lazy Type exists.
    (defonce (sampler) (generator type))
    (cons type sampler)) types))
  ;; First successful demand prepares the real Type generator. A selected
  ;; unsupported Type still fails normally; no alternative Type is substituted.
  (def (child type) ((cdr (assq type samplers))))
  ;; Bounded standard LRU owns prepared layouts, never argument values or random
  ;; state. Reuse also preserves observer identity across trials: the run ledger
  ;; need not retain a fresh equivalent source graph for every generated call.
  (def products (make-LRUCache 128))
  ;; Recover the selected positional/keyword product without invoking any target.
  ;; Decode the current value when unpacking; a layout must not retain its first
  ;; row. Successful preparation alone enters the cache; failed factories retry.
  (def (prepare-product selected count keys)
    (def positionals (positional-types selected count))
    (product-generator descriptor
      (map-in-order child (append positionals (map (lambda (key) (cdr (assq key (.get selected keywords)))) keys)))
      (lambda (arguments)
        (def actual (decode-arguments arguments keyword-mode))
        (append (car actual) (map cdr (cdr actual))))
      (lambda (values)
        (defvalues (pos rest) (split-at values (length positionals)))
        (encode-arguments pos (map cons keys rest) keyword-mode))))
  ;; Clause identity, positional count and ordered keyword names determine the
  ;; layout. Retained product/core guards keep their original epochs; a hit cannot
  ;; refresh an invalidated dependency or admit a revised child sampler.
  (def (product arguments)
    (def selected (select-signature signatures arguments))
    (def row (decode-arguments arguments keyword-mode))
    (def count (length (car row)))
    (def keys (map car (cdr row)))
    (def key (list selected count keys))
    (or (lru-cache-get products key)
      (let* ((sampler (prepare-product selected count keys)) (core (generator-core sampler))
             (entry (cons sampler core)))
        (lru-cache-put! products key entry) entry)))
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
    (core.generator-bind shapes (lambda (shape) (cdr (product shape))))
    (lambda (arguments) (.call (car (product arguments)) measure arguments))
    shrink:
    (lambda (arguments) (.call (car (product arguments)) shrink arguments))
    ;; Unforced input Types still own the declaration. Forced child samplers add
    ;; their own transitive stamps through product-generator / generator-core.
    dependencies: (append (cons function signatures) types)))

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
