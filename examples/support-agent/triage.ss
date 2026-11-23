(export ArticleTable start-triage revise-triage refresh-knowledge triage-decision deliver-approved-draft)
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
(def default-policy (.o minimum-confidence: 85))

(def Article
  (.cc ObjectContract. identity: 'approved-article
    responsibilities: (.o revision: UInt body: String)))

(def ArticleTable (RationalDict Article))

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
      ((.get environment provider) question (.get article body)))))

(def (handoff cause)
  (.o route: 'human reason: cause))

(def (propose ticket article environment)
  (cond
    ((.get ticket sensitive?) (handoff 'sensitive-ticket))
    ((not article) (handoff 'unknown-article))
    (else
      (def response ((suggest (.get ticket question) article) environment))
      (.o route: 'draft-for-review
          article-id: (.get ticket article-id) article-revision: (.get article revision)
          reply: response))))

(def (decide proposal confidence)
  (if (eq? (.get proposal route) 'human) proposal
    (let (reply (.get proposal reply))
      (cond
        ((.get reply review?) (handoff 'model-requested-review))
        ((< (.get reply confidence) confidence) (handoff 'low-confidence))
        (else (.o route: 'draft-for-review draft: (.get reply draft)
                  article-id: (.get proposal article-id)
                  article-revision: (.get proposal article-revision)))))))

(def (base key value) (cons key (some (step.make-success value))))
(def (selected-article catalogue ticket)
  (option-get/default (.call ArticleTable .ref/opt catalogue (.get ticket article-id))))

(def (policy-input overrides)
  (base 'minimum-confidence
    (validate Confidence (.get (.mix overrides default-policy) minimum-confidence))))

(def (start-triage ticket environment overrides)
  (def request (validate Ticket ticket))
  (plan.start-owned
    (graph.schedule-owned
      '(ticket article proposal minimum-confidence decision)
      (list
        (cons 'proposal
          (step.both (step.need 'ticket identity) (step.need 'article identity)
            (lambda (current-ticket article) (propose current-ticket article environment))))
        (cons 'decision
          (step.both (step.need 'proposal identity) (step.need 'minimum-confidence identity)
            (lambda (proposal confidence) (seal-object! (decide proposal confidence))))))
      (list (base 'ticket request)
            (base 'article (selected-article (.get environment articles) request))
            (policy-input overrides)))))

(def (replace-input previous input)
  (plan.refresh-revision previous (plan.revision previous [] (list input))))

;; Changing policy reuses the existing proposal.
(def (revise-triage previous overrides)
  (replace-input previous (policy-input overrides)))

;; The catalogue is a persistent Table of approved snapshots. Other article
;; edits leave the selected row and its accepted decision valid.
(def (refresh-knowledge previous catalogue)
  (def (prior-input key) (step.success-value (some-value (plan.cache-ref previous key))))
  (def article (selected-article catalogue (prior-input 'ticket)))
  (if (eq? article (prior-input 'article)) previous
    (replace-input previous (base 'article article))))

;; Malformed provider replies arrive here as Computation errors.
(def (triage-decision triage)
  (some-value (plan.cache-ref triage 'decision)))

;; The application supplies its current run when a person approves a draft.
(def (deliver-approved-draft current reviewed deliver)
  (def decision (triage-decision current))
  (unless (and (step.success? decision)
               (eq? (step.success-value decision) reviewed)
               (eq? (.get reviewed route) 'draft-for-review))
    (error "draft is no longer current for delivery"))
  (deliver (.get reviewed draft)))
