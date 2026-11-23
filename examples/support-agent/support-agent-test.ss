(export support-agent-test)
(import (only-in :std/test test-suite test-case check check-equal? check-exception)
        (only-in :clan/poo/object .o .get .call seal-object!)
        (only-in :std/error Error? Error-message)
        (only-in :clan/poo/graph/computation success-value error?)
        "./triage.ss")

(def (ticket id sensitive-request?)
  (.o question: "How do I update my delivery address?"
      article-id: id sensitive?: sensitive-request?))

(def (article edition advice)
  (seal-object! (.o revision: edition body: advice)))

(def catalogue
  (.call ArticleTable .<-list
    (list (cons 17 (article 1 "Update the address in Orders before the order ships.")))))

(def (stale-draft? cause)
  (and (Error? cause) (equal? (Error-message cause) "draft is no longer current for delivery")))

(def support-agent-test
  (test-suite "Triage support tickets with a model provider"
    (test-case "Recheck a reviewed draft after the tenant changes policy"
      (def requests [])
      (def delivered [])
      (def (deliver text) (set! delivered (cons text delivered)))
      (def environment
        (.o articles: catalogue provider:
          (lambda (question article)
            (set! requests (cons (list question article) requests))
            "{\"draft\":\"Open Orders to update your address.\",\"confidence\":91,\"review\":false}")))
      (def first (start-triage (ticket 17 #f) environment (.o)))
      (def draft (success-value (triage-decision first)))
      (check-equal? (.get draft route) 'draft-for-review)
      (check-equal? (.get draft article-id) 17)
      (check-equal? (.get draft draft) "Open Orders to update your address.")
      (def revised (revise-triage first (.o minimum-confidence: 95)))
      (def handoff (success-value (triage-decision revised)))
      (check-equal? (list (.get handoff route) (.get handoff reason)) '(human low-confidence))
      (check-equal? (.get (success-value (triage-decision first)) route) 'draft-for-review)
      (check-exception (deliver-approved-draft revised draft deliver)
        stale-draft?)
      (check-equal? delivered '())

      ;; An operator restores the normal policy and approves the new draft.
      (def restored (revise-triage revised (.o)))
      (def reviewed (success-value (triage-decision restored)))
      (deliver-approved-draft restored reviewed deliver)
      (check-equal? delivered '("Open Orders to update your address."))
      (check-equal? requests
        '(("How do I update my delivery address?"
           "Update the address in Orders before the order ships."))))
    (test-case "Refresh only when the approved article for the ticket changes"
      (def looked-up [])
      (def environment
        (.o articles: catalogue provider:
          (lambda (_question article-text)
            (set! looked-up (cons article-text looked-up))
            (string-append "{\"draft\":\"" article-text "\",\"confidence\":98,\"review\":false}"))))
      (def first (start-triage (ticket 17 #f) environment (.o)))
      (def draft (success-value (triage-decision first)))

      (def expanded (.call ArticleTable .acons 29 (article 1 "Return unopened orders.") catalogue))
      (check (eq? (refresh-knowledge first expanded) first) => #t)

      (def corrected (.call ArticleTable .acons 17 (article 2 "Use the order change form.") expanded))
      (def latest (refresh-knowledge first corrected))
      (check-exception (deliver-approved-draft latest draft (lambda (_) (error "must not deliver"))) stale-draft?)
      (def reviewed (success-value (triage-decision latest)))
      (check-equal? (.get reviewed article-revision) 2)
      (check-equal? (deliver-approved-draft latest reviewed identity) "Use the order change form.")
      (check-equal? (reverse looked-up)
        '("Update the address in Orders before the order ships." "Use the order change form.")))
    (test-case "Route sensitive or ungrounded requests to a person"
      (def environment
        (.o articles: catalogue provider: (lambda _ (error "model must not run"))))
      (for-each
        (lambda (request reason)
          (def handoff (success-value (triage-decision (start-triage request environment (.o)))))
          (check-equal? (list (.get handoff route) (.get handoff reason)) (list 'human reason)))
        (list (ticket 17 #t) (ticket 404 #f))
        '(sensitive-ticket unknown-article)))
    (test-case "Honor a provider review request even when its confidence is high"
      (def environment
        (.o articles: catalogue provider:
          (lambda _ "{\"draft\":\"Needs a second opinion\",\"confidence\":99,\"review\":true}")))
      (def decision (success-value (triage-decision (start-triage (ticket 17 #f) environment (.o)))))
      (check-equal? (list (.get decision route) (.get decision reason))
                    '(human model-requested-review)))
    (test-case "Reject a malformed provider reply before drafting"
      (def environment
        (.o articles: catalogue provider:
          (lambda _ "{\"draft\":\"Unverified\",\"confidence\":150,\"review\":false}")))
      (check (error? (triage-decision (start-triage (ticket 17 #f) environment (.o)))) => #t))))
