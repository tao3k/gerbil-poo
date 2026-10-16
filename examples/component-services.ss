;;; Shared quota and cross-service feedback, with automatic merge/split grouping.
(export keys source revise build-group report publish)
(import (only-in :std/list/list foldl) ../object ../mop ../brace ../support/option
        ../generalized-declaration ../generalized-closure ../feedback-cache ../feedback-graph ../lens-laws
        (prefix-in ../generalized-graph graph.) (prefix-in ../dependency-analysis code.)
        (prefix-in ./closed-declarations product.))
;; Stable finite support maps service names onto a non-record vector carrier.
(def keys '(quota left right settlement stable))
;; Each slot denotes a COMPLETE equation; nested lens updates preserve other slots.
(def focuses (map product.vector-focus '(0 1 2 3 4)))
;; Explicit lookup refuses unsupported names instead of silently selecting a slot.
(def (index key)
  (let loop ((rest keys) (n 0))
    (cond ((null? rest) (error "unknown service" key))
          ((eq? key (car rest)) n) (else (loop (cdr rest) (+ n 1))))))
;; Build an inspectable recipe, combining declared reads using existing Computation.
;; Its successful value is the complete component's natural-valued equation.
(def (recipe deps equation)
  (code.map (foldl (lambda (dep previous)
    (code.both previous (code.need dep identity) (lambda (values value) (append values [value]))))
    (code.pure []) deps) equation))
;; Shared quota is a base input; both service branches also form a feedback pair.
(def left-code (recipe '(quota right) (lambda (values) (min (car values) (+ 1 (cadr values))))))
;; Removing right's read of left splits the pair without changing the support set.
(def right-code (recipe '(quota left) (lambda (values) (min (car values) (+ 1 (cadr values))))))
;; A third service consumes both branches; it must rebuild after either changes.
(def settlement-code (recipe '(left right) (lambda (values) (apply + values))))
;; Independent singleton feedback: self-loop convergence must not dirty on merges.
(def stable-code (recipe '(stable) (lambda (values) (min 2 (+ 1 (car values))))))
;; Persistent source: node recipe identities survive quota and graph revisions.
(def (source quota)
  (graph.declaration keys [(cons 'left left-code) (cons 'right right-code)
    (cons 'settlement settlement-code) (cons 'stable stable-code)]
    [(cons 'quota (some (code.make-success quota)))]))
;; Toggle the feedback edge through a genuine persistent body/footprint edit.
(def (revise spec cyclic?)
  (graph.define spec 'right (if cyclic? right-code (recipe '(quota) car))))
;; Read a service value from the exact accepted group's wider non-record carrier.
(def (value group key) (vector-ref (closed-raw (group-closed group)) (index key)))
;; Assemble each discovered SCC from existing declaration fragments and lens laws.
;; Internal reads use the SAME cooked self; external reads use closed predecessors.
;; The finite budget is explicit policy, not an arbitrary convergence guarantee.
(def (build-group members spec external)
  (def base (vector 0 0 0 0 0))
  (def forms (map (lambda (key)
    (def program (.call spec .code key))
    (def part (lens-fragment (list-ref focuses (index key))
      (lambda (_ self inherited)
        (def result (if program (.call program .evaluate (lambda (dep)
          (some (code.make-success (if (memq dep members)
            (vector-ref (self) (index dep)) (value (external dep) dep))))))
          (let (found (.call spec .base key))
            (unless (some? found) (error "missing service input" key)) (some-value found))))
        (unless (code.success? result) (error "service equation failed" key result))
        (code.success-value result)) #f))
    (.o (kind 'fragment) (name key) (descriptor part))) members))
  (close-feedback-group (prepare-fragments GeneralizedDeclaration. (.o) identity forms) base base 32))
;; All observations resolve through the CURRENT automatic partition.
(def (report current)
  (map (lambda (key) (value (graph-cache-ref current key) key)) keys))
;; Both service commitments and settlement must agree before current approval.
;; Policy-only changes cannot skip this Reader suffix, even on complete cache hits.
(def (publish old spec policy builder)
  (publish-feedback-graph old spec build-group (lambda (_ candidate)
    (def values (report candidate))
    (and (eq? (.@ policy allowed) #t) (= (list-ref values 3) (+ (list-ref values 1) (list-ref values 2)))
         (<= (list-ref values 3) (.@ policy limit))))
    guards: [(lens-check (.lens) [policy] sources: [policy])] builder: builder))
