(export release-control-test)
(import (only-in :std/test test-suite test-case check check-equal?)
        (only-in :clan/poo/object .o .get .mix)
        (only-in :clan/poo/graph/cyclic-publication version-view probe failure-stage)
        "../../release-control/policy.ss")

(def candidate
  (.o artifact: 'build-42 requested-by: 'release-bot
      reviewed-by: 'pending reviewed-artifact: 'build-42
      analysis: 'inconclusive analyzed-artifact: 'build-42
      stable-artifact: 'build-41 window-open?: #t))

(def release-control-test
  (test-suite "Progressive release with revision-bound review"
    (test-case "Hold for independent review and canary analysis, then roll back a failed build"
      (defvalues (pending failure) (start-release candidate 'hold))
      (check-equal? failure #f)
      (check-equal? (probe pending 'command 'production) '(hold production build-42 awaiting-review))

      (def self-review (.mix (.o reviewed-by: 'release-bot analysis: 'passed) candidate))
      (defvalues (retained refusal) (revise-release pending self-review 'promote))
      (check (eq? retained pending) => #t)
      (check-equal? (failure-stage refusal) 'admission)

      (def reviewed (.mix (.o reviewed-by: 'operator) candidate))
      (defvalues (observing issue) (revise-release pending reviewed 'hold))
      (check-equal? issue #f)
      (check-equal? (probe observing 'command 'production) '(hold production build-42 awaiting-analysis))

      (def passed (.mix (.o analysis: 'passed) reviewed))
      (def closed-window (.mix (.o window-open?: #f) passed))
      (defvalues (waiting window-issue) (revise-release observing closed-window 'hold))
      (check-equal? window-issue #f)
      (check-equal? (probe waiting 'command 'production) '(hold production build-42 awaiting-window))

      (defvalues (active promotion-issue) (revise-release waiting passed 'promote))
      (check-equal? promotion-issue #f)
      (check-equal? (.get (version-view active) stable?) #t)
      (check-equal? (probe active 'command 'production) '(deploy production build-42))
      (check-equal? (probe active 'command 'staging) '(unsupported-environment staging))

      (def next-build (.mix (.o artifact: 'build-43) passed))
      (defvalues (prior stale-review) (revise-release active next-build 'promote))
      (check (eq? prior active) => #t)
      (check-equal? (failure-stage stale-review) 'admission)

      ;; A new approval still needs analysis for this exact build.
      (def fresh-review (.mix (.o reviewed-artifact: 'build-43) next-build))
      (defvalues (new-canary analysis-issue) (revise-release active fresh-review 'hold))
      (check-equal? analysis-issue #f)
      (check-equal? (probe new-canary 'command 'production)
                    '(hold production build-43 awaiting-analysis))

      (def failed (.mix (.o analysis: 'failed) passed))
      (defvalues (rollback rollback-issue) (revise-release active failed 'hold))
      (check-equal? rollback-issue #f)
      (check-equal? (probe rollback 'command 'production) '(rollback production build-42 build-41))
      (check-equal? (probe active 'command 'production) '(deploy production build-42)))))
