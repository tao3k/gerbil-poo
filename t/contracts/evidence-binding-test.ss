;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (prefix-in :clan/poo/declarative-metadata metadata.))
(export evidence-binding-test)

;; Test-only ordinary result. The library neither constructs nor authenticates it.
(def (result-view value) value)
(def Call
  (metadata.contract
    (metadata.predicate "subject" object?)
    (metadata.predicate "result" object?)
    (lambda (_atom _input _result) #t) metadata.truth))

(def evidence-binding-test
  (test-suite "Public invocation evidence binding without Core"
    (test-case "exact references preserve existing result and next state"
      (def subject-value (.o value: 1))
      (def descriptor-value (.o identity: 'contract))
      (def context-value (.o revision: 1))
      (def result (.o subject: subject-value descriptor: descriptor-value context: context-value))
      (def state (.o revision: 2))
      (def bound (metadata.bind-evidence Call subject-value descriptor-value context-value result-view))
      (defvalues (actual next refusal)
        (metadata.publish bound context-value (lambda (_) (values result state)) subject-value))
      (check-equal? refusal #f)
      (check-equal? (eq? actual result) #t)
      (check-equal? (eq? next state) #t))

    (test-case "each mismatched reference rejects publication and retains the old value"
      (def subject-value (.o value: 1))
      (def descriptor-value (.o identity: 'same-name))
      (def context-value (.o revision: 1))
      (def old (.o state: 'old))
      (def proposed (.o state: 'proposed))
      (def good (.o subject: subject-value descriptor: descriptor-value context: context-value))
      (def bound (metadata.bind-evidence Call subject-value descriptor-value context-value result-view))
      (for-each
        (lambda (wrong)
          (defvalues (result next refusal)
            (metadata.publish bound old (lambda (_) (values wrong proposed)) subject-value))
          (check-equal? result #f)
          (check-equal? (eq? next old) #t)
          (check-equal? (metadata.failure-phase refusal) 'logic))
        (list (.cc good subject: (.cc subject-value))
              (.cc good descriptor: (.cc descriptor-value))
              (.cc good context: (.cc context-value)))))

    (test-case "a wrong invocation request cannot use otherwise matching evidence"
      (def subject-value (.o))
      (def descriptor-value (.o))
      (def context-value (.o))
      (def result (.o subject: subject-value descriptor: descriptor-value context: context-value))
      (def bound (metadata.bind-evidence Call subject-value descriptor-value context-value result-view))
      (defvalues (actual next refusal)
        (metadata.publish bound context-value (lambda (_) (values result subject-value)) (.cc subject-value)))
      (check-equal? actual #f)
      (check-equal? (eq? next context-value) #t)
      (check-equal? (metadata.failure-phase refusal) 'logic))

    (test-case "original rule short-circuits before the result projection"
      (def projections 0)
      (def subject-value (.o))
      (def guarded
        (.cc Call meaning: (lambda (_atom _request _result) #f)
                  rule: (metadata.atom 'evidence-binding)))
      (def bound
        (metadata.bind-evidence guarded subject-value (.o) (.o)
          (lambda (result) (set! projections (+ projections 1)) result)))
      (defvalues (result next refusal)
        (metadata.publish bound subject-value (lambda (_) (values (.o) (.o))) subject-value))
      (check-equal? result #f)
      (check-equal? (eq? next subject-value) #t)
      (check-equal? (metadata.failure-phase refusal) 'logic)
      (check-equal? projections 0))

    (test-case "binding is cold after a parent prepared its invariant checks"
      (def subject-value (.o))
      (def descriptor-value (.o))
      (def context-value (.o))
      (def parent (metadata.with-meaning Call (.get Call meaning)))
      (check-equal? (eq? (.get parent checks) #f) #f)
      (def bound (metadata.bind-evidence parent subject-value descriptor-value context-value result-view))
      (check-equal? (.get bound checks) #f)
      (def result (.o subject: subject-value descriptor: descriptor-value context: context-value))
      (defvalues (actual next) (metadata.invoke bound (lambda (_) (values result context-value)) subject-value))
      (check-equal? (eq? actual result) #t)
      (check-equal? (eq? next context-value) #t))

    (test-case "nested binding cannot discard an earlier context obligation"
      (def subject-value (.o)) (def descriptor-value (.o))
      (def previous (.o revision: 1)) (def current (.o revision: 2))
      (def bound (metadata.bind-evidence Call subject-value descriptor-value previous result-view))
      (def nested (metadata.bind-evidence bound subject-value descriptor-value current result-view))
      (def result (.o subject: subject-value descriptor: descriptor-value context: current))
      (def execute (lambda (_) (values result current)))
      (defvalues (_ state refusal) (metadata.publish nested previous execute subject-value))
      (check (eq? state previous) => #t)
      (check-equal? (metadata.failure-phase refusal) 'logic)
      (def fresh (metadata.bind-evidence Call subject-value descriptor-value current result-view))
      (defvalues (accepted next failure) (metadata.publish fresh previous execute subject-value))
      (check-equal? failure #f)
      (check (eq? accepted result) => #t) (check (eq? next current) => #t))

    (test-case "fused binding keeps fresh atoms and post-specialization rule selection"
      (def subject (.o)) (def descriptor (.o)) (def context (.o))
      (def first (metadata.bind-evidence Call subject descriptor context result-view))
      (def second (metadata.bind-evidence Call subject descriptor context result-view))
      (def left []) (def right [])
      (metadata.holds (.get first rule) (lambda (key) (set! left (cons key left)) #t))
      (metadata.holds (.get second rule) (lambda (key) (set! right (cons key right)) #t))
      (check-equal? (length left) 1) (check-equal? (length right) 1)
      (check (eq? (car left) (car right)) => #f)
      (def projections 0) (def custom #f)
      (set! custom (.cc Call .with-meaning:
        (lambda (meaning (share? #t))
          (.setslot! custom rule ($constant-slot-spec (metadata.deny metadata.truth)))
          (.cc custom meaning: meaning))))
      (def bound (metadata.bind-evidence custom subject descriptor context
        (lambda (result) (set! projections (1+ projections)) result)))
      (def result (.o subject: subject descriptor: descriptor context: context))
      (defvalues (_ next refusal) (metadata.publish bound context (lambda (_) (values result subject)) subject))
      (check-equal? (metadata.failure-phase refusal) 'logic)
      (check (eq? next context) => #t) (check-equal? projections 0))
    (test-case "invalid projections remain explicit failures"
      (check-exception (metadata.bind-evidence Call (.o) (.o) (.o) #f) error?)
      (def subject-value (.o))
      (def bound
        (metadata.bind-evidence Call subject-value (.o) (.o)
          (lambda (_) (error "broken projection"))))
      (defvalues (result next refusal)
        (metadata.publish bound subject-value (lambda (_) (values (.o) (.o))) subject-value))
      (check-equal? result #f)
      (check-equal? (eq? next subject-value) #t)
      (check-equal? (metadata.failure-phase refusal) 'logic)
      (check-equal? (error? (metadata.failure-cause refusal)) #t))))
