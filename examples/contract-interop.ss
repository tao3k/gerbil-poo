;;; Gerbil typed consumers composed with recursively checked POO service rows.
(export make-sink sink-count admit-to-sink publish-from-sink)
(import (only-in ../support/base require-value) ../object ../mop ../object-contract-flow
        (prefix-in ./row-services rows.))

;; Ordinary host state uses Gerbil's generated struct/class machinery directly.
(defstruct %sink (count) final: #t)
;; Expose the generated accessor without a second implementation.
(defalias sink-count %sink-count)
;; Keep host construction independent of POO descriptors and evidence identities.
(def (make-sink) (make-%sink 0))
;; Class-aware using exposes generated accessors to an actual IO consumer. FUN
;; admission and refinement finish first; one accepted observation increments once.
;; Multiple return values and later body errors are not caught by contract adapters.
(def (admit-to-sink instance target maximum)
  (using (target : %sink)
    (rows.admit-service instance maximum
      (lambda (checked)
        (set! target.count (+ target.count 1))
        (values checked target.count)))))

;; Admission/refinement and host observation precede exact subject/context binding.
;; Build evidence from the current checked value; returning stale evidence preserves
;; old state. Observation is not rolled back if subsequent evidence publication fails.
(def (publish-from-sink instance target maximum candidate context evidence-for old-state)
  (require-value evidence-for procedure? (lambda () (error "Evidence builder must be a procedure")))
  (let-values (((checked _count) ((admit-to-sink instance target maximum) candidate)))
    (rows.publish-service instance checked context (evidence-for checked context) old-state)))
