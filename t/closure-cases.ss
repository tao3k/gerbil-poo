;;; One source of benchmark cases, dimensions and counter columns.
(export cases focus-cases queues scopes seeds trials counters)
(def cases '(("diamond" 256 16) ("diamond" 1024 16) ("dense" 64 16) ("dense" 256 16)
             ("ring" 1024 16) ("skewed" 128 64) ("gated" 1024 16) ("quorum" 256 16)
             ("hubchain" 1024 16) ("bursts" 1024 16)))
(def queues '(append chunked hybrid auto))
(def scopes '(cold warm refresh))
(def seeds '(#t #f))
(def trials 4)
(def counters '(pops evals nodes writes pushes edges copied-queue frames queue-pairs
                 empty shared inline fee engine charge append-bound chunk-bound hybrid-bound
                 mode syntax-nodes index-links selector-visits setup-selector-visits))

(def focus-cases
  (filter (lambda (spec)
            (and (member (car spec) '("diamond" "dense" "ring" "hubchain" "bursts"))
                 (= (cadr spec) (if (equal? (car spec) "dense") 256 1024)))) cases))
