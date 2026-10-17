;;; Structural Function admission below the Type bootstrap; validators are injected.
(export decode-arguments signature-shape? select-signature normalize-arguments encode-arguments wrap-function)
(import (only-in ./support/base require-value) (only-in :std/list/list map-in-order)
        (only-in ./object .get))

;; Decode Gerbil's keyword escapes without executing defaults or validators.
;; With no declared keyword API, retain legacy positional keyword values verbatim.
(def (decode-arguments arguments keyword-mode?)
  (if (not keyword-mode?) (cons arguments [])
    (let loop ((rest arguments) (pos []) (keys []))
      (match rest
        ([] (cons (reverse pos) (reverse keys)))
        ([#!rest . tail] (cons (append (reverse pos) tail) (reverse keys)))
        ([#!key value . tail] (loop tail (cons value pos) keys))
        ([#!key] #f)
        ([(? keyword? key) value . tail]
         (and (not (assq key keys)) (loop tail pos (cons (cons key value) keys))))
        ([(? keyword?) ] #f)
        ([value . tail] (loop tail (cons value pos) keys))))))
;; Match arity and keyword presence only. A rejected shape executes no child check.
(def (row-shape? signature row)
  (and row
    (let* ((count (length (car row))) (required (length (.get signature inputs)))
           (optional (.get signature optional)) (keys (cdr row)))
      (and (>= count required)
           (or (.get signature rest) (<= count (+ required (length optional))))
           (every (lambda (entry) (assq (car entry) (.get signature keywords))) keys)
           (every (lambda (key) (assq key keys)) (.get signature required-keywords))))))
;; Share one keyword interpretation across all clauses; overlapping shapes select
;; the first clause, like case-lambda. Type refusal never tries a later clause.
(def (signature-shape? signature arguments (keyword-mode? (pair? (.get signature keywords))))
  (and (row-shape? signature (decode-arguments arguments keyword-mode?)) #t))
;; Return the original descriptor identity so generators can report the chosen clause.
(def (select-signature signatures arguments)
  (def keyword-mode? (ormap (lambda (signature) (pair? (.get signature keywords))) signatures))
  (def row (decode-arguments arguments keyword-mode?))
  (find (lambda (signature) (row-shape? signature row)) signatures))
;; Canonical keyword forwarding uses Gerbil's own #!rest escape, so a keyword-valued
;; positional argument cannot be reinterpreted by the target's keyword dispatcher.
(def (encode-arguments positionals keywords keyword-mode?)
  (if keyword-mode?
    (append (apply append (map (lambda (entry) (list (car entry) (cdr entry))) keywords))
            (cons #!rest positionals)) positionals))
;; Omitted defaults stay omitted and execute in the target; only supplied positions
;; acquire checks. Nested Function validators return wrappers through the same map.
(def (normalize-arguments signature arguments keyword-mode? check)
  (def row (decode-arguments arguments keyword-mode?))
  (def types (append (.get signature inputs) (.get signature optional)))
  (def positionals
    (let loop ((values (car row)) (types types))
      (if (null? values) []
        (cons (check (if (pair? types) (car types) (.get signature rest)) (car values))
              (loop (cdr values) (if (pair? types) (cdr types) []))))))
  (def keywords (map-in-order (lambda (entry)
    (cons (car entry) (check (cdr (assq (car entry) (.get signature keywords))) (cdr entry)))) (cdr row)))
  (encode-arguments positionals keywords keyword-mode?))
;; Validate arguments before one body invocation, then validate every returned value.
;; Native body/default errors propagate exactly and cannot cause overload fallback.
(def (wrap-function descriptor procedure signatures check refuse)
  (require-value procedure procedure? (lambda () (refuse descriptor procedure)))
  (let (keyword-mode? (ormap (lambda (signature) (pair? (.get signature keywords))) signatures))
    (lambda arguments
      (def signature (select-signature signatures arguments))
      (unless signature (refuse descriptor arguments))
      (def normalized (normalize-arguments signature arguments keyword-mode? check))
    (call/values (lambda () (apply procedure normalized))
        (lambda results
          (def outputs (.get signature outputs))
          (unless (= (length outputs) (length results)) (refuse descriptor results))
          (apply values (map-in-order check outputs results)))))))
