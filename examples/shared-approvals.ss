;;; Independent service publications share explicit approval objects and one domain.
(export start stage submit-current! value)
(import (prefix-in ../component-publication publication.) (prefix-in ./component-requests service.))
;; Each service keeps its own local policy and head, but observes the identical
;; shared approval object. Map reuses native construction and standard list order.
;; Shared/local objects remain guarded; policy-management writes use these owners.
(def (start shared locals)
  (def domain (publication.approval-domain))
  (map (lambda (local) (service.start (list shared local) domain: domain)) locals))
;; Reuse staged whole-graph closure and current joint approval on each endpoint.
(def stage service.stage)
;; Reprepare once against that endpoint's head and all current captured policies.
(def submit-current! service.submit-current!)
;; Current SCC receipts supply values independently for each endpoint.
(def value service.value)
