(export start-triage revise-triage triage-decision deliver-approved-draft ArticleTable)
(import (only-in :clan/poo/object .o .cc .get .call .mix seal-object!)
        (only-in :clan/poo/type String Bool validate)
        (only-in :clan/poo/number UInt IntegerRange)
        (only-in :clan/poo/fun Observation.)
        (only-in :clan/poo/table/rationaldict RationalDict)
        (only-in :clan/poo/types/object-contract ObjectContract.)
        (only-in :clan/poo/support/json json<-string)
        (only-in :clan/poo/support/option some some-value option-get/default)
        (prefix-in :clan/poo/graph/computation step.)
        (prefix-in :clan/poo/graph/schedule graph.)
        (prefix-in :clan/poo/graph/construction plan.))

(def Confidence (IntegerRange min: 0 max: 100))
(def ArticleTable (RationalDict String))
(def default-policy (.o minimum-confidence: 85))

(def Ticket
  (.cc ObjectContract. identity: 'support-ticket
    responsibilities: (.o question: String article-id: UInt sensitive?: Bool)))

(def ModelReply
  (.cc ObjectContract. identity: 'model-reply
    responsibilities: (.o draft: String confidence: Confidence review?: Bool)))

(def (decode-reply json)
  (def fields (json<-string json))
  (validate ModelReply
    (.o draft: (hash-ref fields "draft")
        confidence: (hash-ref fields "confidence")
        review?: (hash-ref fields "review"))))

;; Use the provider from the environment and decode its JSON response.
(def (suggest question article)
  (.call Observation. .map decode-reply
    (lambda (environment)
      ((.get environment provider) question article))))

(def (choose-route ticket article reply policy)
  (cond
    ((.get ticket sensitive?) (.o route: 'human reason: 'sensitive-ticket))
    ((not article) (.o route: 'human reason: 'unknown-article))
    ((.get reply review?) (.o route: 'human reason: 'model-requested-review))
    ((< (.get reply confidence) policy) (.o route: 'human reason: 'low-confidence))
    (else (.o route: 'draft-for-review article-id: (.get ticket article-id)
              draft: (.get reply draft)))))

(def (policy-input overrides)
  (cons 'minimum-confidence
        (some (step.make-success
          (validate Confidence (.get (.mix overrides default-policy) minimum-confidence))))))

(def (start-triage ticket environment overrides)
  (def request (validate Ticket ticket))
  (def id (.get request article-id))
  (plan.start-owned
    (graph.schedule-owned
      '(article reply minimum-confidence decision)
      (list
        (cons 'article (step.map (step.pure id)
          (lambda (key)
            (option-get/default (.call ArticleTable .ref/opt (.get environment articles) key)))))
        (cons 'reply (step.need 'article
          (lambda (article)
            (and article (not (.get request sensitive?))
                 ((suggest (.get request question) article) environment)))))
        (cons 'decision
          (step.both (step.both (step.need 'article identity) (step.need 'reply identity) cons)
                     (step.need 'minimum-confidence identity)
                     (lambda (context confidence)
                       (seal-object! (choose-route request (car context) (cdr context) confidence))))))
      (list (policy-input overrides)))))

;; Updating policy re-runs the decision; it does not re-query the model.
(def (revise-triage previous overrides)
  (plan.refresh-revision previous (plan.revision previous [] (list (policy-input overrides)))))

;; A malformed provider reply arrives here as a Computation error.
(def (triage-decision triage)
  (some-value (plan.cache-ref triage 'decision)))

;; The application supplies its current run when a person approves a draft.
;; An earlier view cannot authorize an effect after the decision changes.
(def (deliver-approved-draft current reviewed deliver)
  (def decision (triage-decision current))
  (unless (and (step.success? decision)
               (eq? (step.success-value decision) reviewed)
               (eq? (.get reviewed route) 'draft-for-review))
    (error "draft is no longer current for delivery"))
  (deliver (.get reviewed draft)))
