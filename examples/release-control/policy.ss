(export start-release revise-release)
(import (only-in :clan/poo/object .o .cc .get)
        (only-in :clan/poo/type Symbol Bool Enum validate)
        (only-in :clan/poo/types/object-contract ObjectContract.)
        (only-in :clan/poo/mop .defgeneric)
        (only-in :clan/poo/object/declaration .declare)
        (only-in :clan/poo/mop/methods/declaration MethodDeclaration. standard-combination)
        (only-in :clan/poo/mop/methods/combination primary around)
        (only-in :clan/poo/graph/closure literal fact both either closure-ref)
        (prefix-in :clan/poo/graph/cyclic-publication release.))

(def Analysis (Enum passed inconclusive failed))

(def ReleaseRequest
  (.cc ObjectContract. identity: 'release-request
    responsibilities:
      (.o artifact: Symbol requested-by: Symbol reviewed-by: Symbol reviewed-artifact: Symbol
          analysis: Analysis analyzed-artifact: Symbol stable-artifact: Symbol window-open?: Bool)))

(def (independent-review? request)
  (and (not (eq? (.get request reviewed-by) 'pending))
       (not (eq? (.get request reviewed-by) (.get request requested-by)))
       (eq? (.get request reviewed-artifact) (.get request artifact))))

(def (analysis-status request)
  (if (eq? (.get request analyzed-artifact) (.get request artifact))
    (.get request analysis) 'inconclusive))

;; Approval seeds canary readiness. A successful analysis lets stable
;; readiness support the canary within this revision of the policy.
(def (equations request)
  (vector
    (either (literal (independent-review? request)) (fact 1))
    (both (fact 0) (literal (eq? (analysis-status request) 'passed)))
    (both (fact 1) (literal (.get request window-open?)))))

(def (release-view request facts)
  (.o artifact: (.get request artifact) stable-artifact: (.get request stable-artifact)
      canary?: (closure-ref facts 0)
      stable?: (closure-ref facts 1)
      promote?: (closure-ref facts 2)
      status:
        (cond
          ((eq? (analysis-status request) 'failed) 'rollback)
          ((not canary?) 'awaiting-review)
          ((not stable?) 'awaiting-analysis)
          ((not promote?) 'awaiting-window)
          (else 'approved))))

(.defgeneric (command policy environment) slot: .command combination: standard-combination)

(def (release-services view)
  (def policy
    (.declare MethodDeclaration. view
      (method .command
        (.o contributions:
          (list (primary (lambda (_next environment)
                           (def artifact (.get view artifact))
                           (case (.get view status)
                             ((approved) (list 'deploy environment artifact))
                             ((rollback) (list 'rollback environment artifact (.get view stable-artifact)))
                             (else (list 'hold environment artifact (.get view status))))))
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
      ((hold) (not (.get view promote?)))
      (else (error "unknown release mode" mode)))))

(def (start-release input mode)
  (def request (validate ReleaseRequest input))
  (release.prepare (equations request) (cut release-view request <>) release-services (admit mode)))

(def (revise-release previous input mode)
  (def request (validate ReleaseRequest input))
  (release.publish previous (equations request) (cut release-view request <>) release-services (admit mode)))
