(export start-release revise-release)
(import (only-in :clan/poo/object .o .get)
        (only-in :clan/poo/mop .defgeneric)
        (only-in :clan/poo/object/declaration .declare)
        (only-in :clan/poo/mop/methods/declaration MethodDeclaration. standard-combination)
        (only-in :clan/poo/mop/methods/combination primary around)
        (only-in :clan/poo/graph/closure literal fact both either closure-ref)
        (prefix-in :clan/poo/graph/cyclic-publication release.))

;; Facts 0 and 1 form a cycle. Canary promotion needs an external approval
;; to get started, then successful smoke checks can support the stable track.
(def (equations signals)
  (vector
    (both (literal (.get signals healthy?)) (either (literal (.get signals approved?)) (fact 1)))
    (both (fact 0) (literal (.get signals smoke-passed?)))
    (both (fact 1) (literal (.get signals window-open?)))))

(def (release-view facts)
  (.o canary?: (closure-ref facts 0)
      stable?: (closure-ref facts 1)
      promote?: (closure-ref facts 2)))

;; A receiver-slot generic assembles policy from method fragments.
(.defgeneric (command policy environment) slot: .command combination: standard-combination)

(def (release-services view)
  (def policy
    (.declare MethodDeclaration. view
      (method .command
        (.o contributions:
          (list (primary (lambda (_next environment)
                           (list (if (.get view promote?) 'deploy 'hold) environment)))
                (around (lambda (next environment)
                          (if (eq? environment 'production)
                            (next)
                            (list 'unsupported-environment environment)))))))))
  (list (cons 'command (lambda (environment) (command policy environment)))))

(def (admit mode)
  (lambda (candidate)
    (def view (release.version-view candidate))
    (case mode
      ((promote) (.get view promote?))
      ((pause) (not (.get view promote?)))
      (else (error "unknown release mode" mode)))))

(def (start-release signals mode)
  (release.prepare (equations signals) release-view release-services (admit mode)))

(def (revise-release previous signals mode)
  (release.publish previous (equations signals) release-view release-services (admit mode)))
