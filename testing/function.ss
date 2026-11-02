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
(def (keyword-mode? signatures (read .ref))
  (ormap (lambda (signature) (pair? (read signature 'keywords))) signatures))

;; Capture every declared input Type, but derive only actually supplied children.
;; Overlapping clauses first select a shape with placeholders; promises cannot
;; force a shadowed clause or an omitted optional/keyword/rest input. Shrinking
;; preserves the shape and shares successfully prepared children within this sampler.
(def (argument-generator descriptor function)
  ;; Known Function authority precedes its first metadata getter. The existing
  ;; ledger deduplicates later discoveries without renewing an earlier epoch.
  (def ledger (make-hash-table-eq))
  (def stamps (retain-source-stamps! ledger (snapshot #f (list function))))
  (with-source-stamps stamps
    ;; Validate the complete source row before publishing any new stamp. This
    ;; is pure first-version bookkeeping; checked metadata reads own observers.
    (def (retain! owners)
      (for-each (lambda (owner) (unless (object? owner) (validate Object owner))) owners)
      (def added (retain-source-stamps! ledger
        (map (lambda (owner) (cons owner (object-revision owner))) owners)))
      (unless (null? added) (set! stamps (append stamps added))))
    ;; Raw getter exceptions bypass post-checks unchanged. Pure declaration
    ;; capture happens before returning observers, but its failures remain stored
    ;; until those original source checks finish. False is a legitimate cause.
    (def (read owner name (capture identity))
      (let-values (((value refused? cause)
        (core.with-sources []
          (def returned (.ref owner name))
          (with-catch (lambda (cause) (values #f #t cause))
            (lambda () (values (capture returned) #f #f))))))
        (when refused? (raise cause))
        value))
    ;; Finite declaration rows own their spines, without deriving child samplers.
    (def (inputs owner name)
      (read owner name (lambda (row)
        (using (row :~ proper-list?)
          (def owned (list-copy row)) (retain! owned) owned))))
    ;; Keyword pairs and their returned Types are captured in the same action.
    ;; map itself builds the owned outer spine; no preceding row copy is needed.
    (def (keywords owner)
      (read owner 'keywords (lambda (entries)
        (using (entries :~ proper-list?)
          (def owned (map (lambda (entry) (cons (car entry) (cdr entry))) entries))
          (retain! (map cdr owned)) owned))))
    ;; Rest absence is false, while a present Type acquires its first epoch now.
    (def (source owner name)
      (read owner name (lambda (value) (when value (retain! (list value))) value)))
    (def signatures (inputs function 'signatures))
    ;; Preserve the existing early keyword-mode pass and metadata read order.
    (def keyword-mode (keyword-mode? signatures (lambda (owner _name) (keywords owner))))
    (def types (delete-duplicates/hash (apply append (map-in-order (lambda (signature)
      (let* ((required (inputs signature 'inputs)) (optional (inputs signature 'optional))
             (keys (keywords signature)) (rest (source signature 'rest)))
        (append required optional (map cdr keys)
          (if rest (list (source signature 'rest)) [])))) signatures))))
    ;; One retained observer protects every later shape/cache/promise operation.
    ;; It closes over the completed epoch list, never over a mutable registry.
    (def guard (source-guard stamps))
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
      (lambda (_) []) current?: guard))
    (from-generator descriptor
      (core.generator-bind shapes (lambda (shape) (cdr (product shape))))
      (lambda (arguments) (.call (car (product arguments)) measure arguments))
      shrink:
      (lambda (arguments) (.call (car (product arguments)) shrink arguments))
      ;; Unforced input Types still own the declaration. Forced child samplers add
      ;; their own transitive stamps through product-generator / generator-core.
      dependencies: (append (cons function signatures) types))))

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
