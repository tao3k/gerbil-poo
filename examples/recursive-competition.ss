;;; Repeated approval invalidation and competing joint revisions over actual SCCs.
(export transitions compete!)
(import (prefix-in ../recursive-approvals approvals.)
        (prefix-in ./recursive-approvals service.)
        (prefix-in ./recursive-topology topology.))

;; Fresh policy objects keep each execution independent. Future proposals can be
;; carried to the next round and explicitly re-staged after a competing publication.
(def (transitions)
  (def primary (make-vector 8 'primary))
  (def secondary (make-vector 8 'secondary))
  (def mixed '#(secondary secondary secondary secondary primary primary primary primary))
  (list (service.policy topology.merged mixed 'notify 108)
    (service.policy topology.split secondary 'auth 128)
    (service.policy topology.crossed secondary 'cache 132)
    (service.policy topology.original primary 'ingress 82)
    (service.policy topology.merged mixed 'notify 108)
    (service.policy topology.split secondary 'auth 128)
    (service.policy topology.original secondary 'delivery 134)
    (service.policy topology.original secondary 'delivery 135 200 3)))

;; Replay historical/drifted requests, then a joint refusal, a winner, a competing
;; future proposal and the winner again. Existing publication guards decide each
;; attempt independently; one FUN observer preserves its actual multi-value result.
(def (compete! owner pending refused winner challenger observer)
  (approvals.submit-sequence! owner
    (map (lambda (request) (cons request observer))
      (append pending (list refused winner challenger winner)))))
