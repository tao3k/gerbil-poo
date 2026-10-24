;;; Structural Function admission below the Type bootstrap; validators are injected.
(export covers-signatures? decode-arguments signature-shape? select-signature normalize-arguments encode-arguments wrap-function check-results)
(import (only-in ./support/base require-value) (only-in :std/list/list map-in-order delete-duplicates/hash)
        (only-in :std/list/plist alist->plist)
        (only-in ./object .get))

;; Decode Gerbil's keyword escapes without executing defaults or validators.
;; With no declared keyword API, retain positional keyword values verbatim.
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
;; Standard alist->plist preserves supplied keyword order and exact payloads.
;; Gerbil's #!rest escape prevents keyword-valued positional arguments from being
;; reinterpreted by the target's keyword dispatcher.
(def (encode-arguments positionals keywords keyword-mode?)
  (if keyword-mode?
    (append (alist->plist keywords) (cons #!rest positionals)) positionals))
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
;; Check the exact returned row before transporting any cache successor. Each
;; Type may replace its value with a recursively wrapped Function/container.
(def (check-results descriptor signature results check refuse)
  (def outputs (.get signature outputs))
  (unless (= (length outputs) (length results)) (refuse descriptor results))
  (map-in-order check outputs results))
;; Validate arguments before one body invocation, then validate every returned value.
;; Target body/default errors propagate exactly and cannot cause overload fallback.
(def (wrap-function descriptor procedure signatures check refuse)
  (require-value procedure procedure? (lambda () (refuse descriptor procedure)))
  (let (keyword-mode? (ormap (lambda (signature) (pair? (.get signature keywords))) signatures))
    (lambda arguments
      (def signature (select-signature signatures arguments))
      (unless signature (refuse descriptor arguments))
      (def normalized (normalize-arguments signature arguments keyword-mode? check))
    (call/values (lambda () (apply procedure normalized))
        (lambda results
          (apply values (check-results descriptor signature results check refuse)))))))

;; Compare first-selected clauses in the actual wire modes. Keyword decoding
;; bounds raw length by n+2k through 2n+2k+1; all arities above the largest fixed
;; prefix share one rest representative. Cross-mode positional sources are chosen
;; by RAW arity, never by the target's decoded arity or a preferred later case.
;; Callbacks receive the target row, source row and independent raw/decoded precision ceilings.
;; The precision ceiling includes every bounded target raw spelling, not only arity.
;; The Type layer may discharge an impossible SUPPLIED row only after first
;; selection; shape-only coverage passes a false witness and retains every row.
(def (covers-signatures? source target work related wire-related row-empty?)
  ;; One interpretation applies to every clause of each ordered descriptor.
  (def source-mode? (and (ormap (lambda (s) (pair? (.get s keywords))) source) #t))
  ;; The target supplies the decoded shape regions and declared key universe.
  (def target-mode? (and (ormap (lambda (s) (pair? (.get s keywords))) target) #t))
  ;; A shared mode keeps the original selector/normalizer path.
  (def same-mode? (eq? source-mode? target-mode?))
  (let* ((signatures (append source target))
         (maximum (foldl (lambda (s largest)
           (work)
           (def width (+ (length (.get s inputs)) (length (.get s optional))))
           (max largest width (if (and (not source-mode?) target-mode? (memq s target))
             (+ (* 2 width) (* 2 (length (.get s keywords))) 1) 0))) 0 signatures))
         (decoded-maximum (if (and (not source-mode?) target-mode?)
           (foldl (lambda (s largest) (work) (max largest (+ (length (.get s inputs)) (length (.get s optional))))) 0 target)
           maximum))
         (limits (cons maximum decoded-maximum))
         (keys (delete-duplicates/hash
           (apply append (map-in-order (lambda (s) (work) (map car (.get s keywords))) target)))))
    ;; Stream raw length representatives; clamping the interval retains every
    ;; possible first source clause and each repeated rest Type exactly once.
    (def (raw-covered? expected arguments count keys)
      (def minimum (+ count (* 2 (length keys))))
      (def maximum-raw (if (> count decoded-maximum) (1+ maximum)
        (+ (* 2 count) (* 2 (length keys)) 1)))
      (let rows ((raw-count (min minimum (1+ maximum))))
        (work)
        (def raw-arguments (make-list raw-count #f))
        (def actual (select-signature source raw-arguments))
        (def wire (wire-related actual expected arguments source-mode? target-mode? raw-arguments limits))
        (and wire
          (or (eq? wire 'empty)
              (and actual (related actual expected arguments source-mode? target-mode? raw-arguments limits)))
          (or (= raw-count (min maximum-raw (1+ maximum))) (rows (1+ raw-count))))))
    ;; Canonical masks describe presence, not the caller's wire order/spelling.
    (def (row-covered? count keys)
      (work)
      (def arguments (encode-arguments (make-list count 'Any)
        (map (lambda (key) (cons key 'Any)) keys) target-mode?))
      (def expected (select-signature target arguments))
      ;; Commit to the original first target clause before consulting its
      ;; supplied-Type witness. A dead clause never exposes a later overload.
      (or (not expected) (row-empty? expected arguments target-mode?)
        (if (and (not source-mode?) target-mode?)
          (raw-covered? expected arguments count keys)
          (let (actual (select-signature source arguments))
            (and actual
              (or same-mode? (wire-related actual expected arguments source-mode? target-mode? arguments limits))
              (related actual expected arguments source-mode? target-mode? arguments limits))))))
    ;; Stream key subsets and arity cells under the SAME admission quota.
    (let counts ((count 0))
      (and (let subsets ((remaining keys) (supplied []))
             (work)
             (if (null? remaining) (row-covered? count (reverse supplied))
               (and (subsets (cdr remaining) supplied)
                    (subsets (cdr remaining) (cons (car remaining) supplied)))))
           (or (= count (+ decoded-maximum 1)) (counts (+ count 1)))))))
