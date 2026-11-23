(export release-control-test)
(import (only-in :std/test test-suite test-case check check-equal?)
        (only-in :clan/poo/object .o .get .mix)
        (only-in :clan/poo/graph/cyclic-publication version-view probe failure-stage)
        "./release-control/policy.ss")

(def release-control-test
  (test-suite "Publish or pause a release with dependent approvals"
    (test-case "Require an approval, retain the accepted release on refusal, then revoke"
      (def checks (.o healthy?: #t smoke-passed?: #t window-open?: #t approved?: #f))
      (defvalues (paused failure) (start-release checks 'pause))
      (check-equal? failure #f)
      (check-equal? (.get (version-view paused) canary?) #f)
      (check-equal? (probe paused 'command 'production) '(hold production))

      (def approved (.mix (.o approved?: #t) checks))
      (defvalues (active issue) (revise-release paused approved 'promote))
      (check-equal? issue #f)
      (check-equal? (.get (version-view active) stable?) #t)
      (check-equal? (probe active 'command 'production) '(deploy production))
      (check-equal? (probe active 'command 'staging) '(unsupported-environment staging))

      (defvalues (retained refusal) (revise-release active checks 'promote))
      (check (eq? retained active) => #t)
      (check-equal? (failure-stage refusal) 'admission)

      (defvalues (revoked revoke-issue) (revise-release active checks 'pause))
      (check-equal? revoke-issue #f)
      (check-equal? (probe revoked 'command 'production) '(hold production))
      (check-equal? (probe active 'command 'production) '(deploy production)))))
