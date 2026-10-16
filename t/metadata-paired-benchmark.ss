;;; Each child builds every control in the same order, warms every control a fixed
;;; number of times, then measures ONE side. Nothing from another sample survives.
(export main workload)
(import :gerbil/runtime/gambit :std/iter (only-in :std/values first-value)
        ../object "closure-measure.ss" (prefix-in "metadata-paired-cases.ss" study.)
        (prefix-in ../contract-family contracts.) (prefix-in ../declarative-metadata metadata.) (prefix-in ../generic-family generics.)
        (prefix-in ../staged-publication staged.) (prefix-in ../cyclic-publication publication.)
        (prefix-in ../examples/service-combination qualified.) (prefix-in ../examples/shared-contracts shared.) (prefix-in ../examples/service-bundle bundle.)
        (prefix-in ../examples/construction-workflow workflow.) (prefix-in ../examples/cyclic-access access.)
        (prefix-in ../construction-cache cache.) (prefix-in ../generalized-graph graph.)
        (prefix-in ../dependency-analysis code.))
;; The previous dynamic implementation is a matched benchmark control only.
;; Hold the same immutable costs as selected-source but repeat generic selector
;; lookup on each call. Benchmark reference only; no compatibility API is exported.
(def uncaptured-source (.cc shared.selected-source
  .select: (let (costs (.@ shared.selected-source preparation-costs))
    (lambda (keys) (contracts.choose-preparation costs (length keys))))))
;; Construct all nine controls in fixed side order, even when measuring only one.
;; Keep support, closed projections and publication semantics matched.
(def sources (list shared.independent-source uncaptured-source shared.selected-source shared.cached-source shared.selected-source shared.cached-source
  shared.shared-checks-source (.@ shared.shared-checks-cached-model contract-source) shared.budgeted-source))
;; Reserve/cancel test executor using only the passed current view; returns
;; result and unchanged view. Checked wrappers validate both service observations.
(def (execute key args view)
  (values (case key ((reserve) (list 'ok (- (.@ view capacity) (car args)) #t))
                    ((cancel) (list (car args) (.@ view invoice)))) view))
;; Build all controls before timing and return one checked thunk per side.
;; Family thunks exercise descriptor/binding work; joint/workflow thunks include
;; atomic revision, selective rebuilding and checked current-state calls. Every
;; control first passes the same warm-budget refusal outside the timed region.
;; Isolated inputs/construct/bind/rebind/generics/approval invoke actual stage callbacks.
;; Identical-stage pairs are A/A noise controls, not claimed optimization gains.
;; Timings from separate processes must not be added as an end-to-end breakdown.
;; Unknown scenarios or refused baselines raise instead of producing a timing.
(def (workload scenario)
  (def policy (.cc bundle.Policy. capacity: 10 price: 3 invoice: "invoice:1"))
  (def view (.o (capacity 10) (invoice "invoice:1")))
  (def next-view (.o (capacity 20) (invoice "invoice:2")))
  (case scenario
    ((selector)
     (let ()
     (def keys (.call shared.independent-source keys policy view))
     (cons (lambda () #t)
       (map (lambda (source)
         (let (select (.@ source .select)) (lambda () (eq? (select keys) 'direct)))) (cdr sources)))))
    ;; Charge fresh source/input callback construction for every side. The budgeted
    ;; side additionally creates/validates its policy and compiles mode selection;
    ;; that one-time configuration is separate from repeated cold-family requests.
    ((configure)
     (map (lambda (source index)
       (lambda ()
         (def current (.cc source))
         (def configured (if (= index 8)
           (contracts.choose-source (.cc contracts.SelectionCacheCosts. setup: 2 guard: 1 calls: 1
             collection-price: 1 extra-collections: 1) current (lambda () '(reserve cancel))) current))
         (procedure? (.@ configured .inputs)))) sources '(0 1 2 3 4 5 6 7 8)))
    ((inputs)
     (map (lambda (source)
       ;; Admit the complete projection/constructor composition before isolating inputs.
       (def candidate (contracts.prepare source policy next-view execute))
       (unless (equal? (first-value ((contracts.family-invoker candidate 'reserve) '(2) next-view)) '(ok 18 #t))
         (error "paired input reference"))
       (def keys (.call source keys policy next-view))
       (lambda () (and (.call source .inputs #f policy next-view keys) #t))) sources))
    ((construct)
     (map (lambda (source)
       (def construct (.@ source construct))
       (lambda () (and (metadata.contract? (construct 'reserve 20))
                       (metadata.contract? (construct 'cancel "invoice:2"))))) sources))
    ;; Charge a fresh parent's first invariant compilation, specialization,
    ;; wrapper binding and checked call together; warm templates are not free here.
    ((cold-checks)
     (let (template (shared.construct 'reserve 20))
       (map (lambda (index)
         (lambda ()
           (def parent (.cc template checks: #f))
           (def meaning (.@ parent meaning))
           (def descriptor (if (>= index 6) (metadata.with-meaning parent meaning)
                              (.cc parent meaning: meaning)))
           (def checked (metadata.wrap descriptor (lambda (args current) (execute 'reserve args current))))
           (equal? (first-value (checked '(2) next-view)) '(ok 18 #t)))) '(0 1 2 3 4 5 6 7 8))))
    ((bind)
     (map (lambda (source)
       (def descriptors (map (.@ source construct) '(reserve cancel) '(20 "invoice:2")))
         (lambda ()
           (for/fold (valid #t) ((key '(reserve cancel)) (descriptor descriptors))
             (and valid (procedure? (metadata.wrap descriptor
               (lambda (args current) (execute key args current)))))))) sources))
    ((rebind)
     (let (next-execute (lambda (key args current) (execute key args current)))
       (map (lambda (source)
         (def old (contracts.prepare source policy view execute))
         (lambda ()
           (def next (contracts.refresh source old policy view next-execute))
           (and (null? (contracts.family-built next))
                (equal? (contracts.family-bound next) '(reserve cancel))
                (equal? (first-value ((contracts.family-invoker next 'reserve) '(2) view)) '(ok 8 #t))))) sources)))
    ;; Fresh native source identity charges cold selector/cache preparation and
    ;; descriptor/binding work. No retained family or warm source slot is supplied.
    ((cold-family)
     (map (lambda (source)
       (lambda ()
         (def cold (contracts.prepare (.cc source) policy next-view execute))
         (and (equal? (contracts.family-built cold) '(reserve cancel))
              (equal? (contracts.family-bound cold) '(reserve cancel))
              (equal? (first-value ((contracts.family-invoker cold 'reserve) '(2) next-view)) '(ok 18 #t))))) sources))
    ((family)
     (map (lambda (source)
       (def old (contracts.prepare source policy view execute))
       (lambda ()
         (def next (contracts.refresh source old policy next-view execute))
         (and (equal? (contracts.family-built next) '(reserve cancel))
              (equal? (contracts.family-bound next) '(reserve cancel))
              (equal? (first-value ((contracts.family-invoker next 'reserve) '(2) next-view)) '(ok 18 #t))
              (equal? (first-value ((contracts.family-invoker next 'cancel) '("customer" #t) next-view)) '("customer" "invoice:2"))))) sources))
    ((joint workflow generics approval standard simple)
     (let ()
     (def workflow? (eq? scenario 'workflow))
     (def qualified? (memq scenario '(standard simple)))
     (def base (case scenario ((workflow) shared.workflow-model) ((standard) qualified.standard-model)
                ((simple) qualified.simple-model) (else bundle.model)))
     (def models (map (lambda (source index)
       (.cc base contract-source: source
         generics: (if (and (>= index 4) (not qualified?)) shared.expanded-generics (.@ base generics)))) sources '(0 1 2 3 4 5 6 7 8)))
     (def specification (if workflow? (workflow.graph 30) (access.equations (access.config) #t)))
     (map (lambda (model)
       (defvalues (cold issue) (staged.prepare model specification policy))
       (when issue (error "paired baseline refused" issue))
       (defvalues (_ old) (publication.invoke cold 'reserve 2))
       (def revised-source (if workflow?
         (graph.define (publication.version-source old) 'invoice (code.need 'settlement (cut + <> 9))) specification))
       (def revised-policy (if workflow? policy (.cc policy capacity: 20 invoice: "invoice:2")))
       ;; All controls execute the same late refusal outside the timed region.
       (defvalues (held refused) (staged.publish model old (if workflow? (publication.version-source old) specification) (.cc policy cache-limit: 0)))
       (unless (and (eq? held old) refused (eq? (publication.failure-stage refused) 'admission))
         (error "paired warm-budget refusal"))
       (case scenario
         ((generics)
          (let ()
          (def next-view (.call model cook revised-policy (publication.version-cache old)))
          (lambda ()
            (def next (generics.refresh (.@ model generics) (publication.version-family old) revised-policy next-view))
            (and (equal? (generics.family-built next) '(quote reserve cancel))
                 (equal? (first-value (generics.invoke next 'reserve 2)) '(ok 18 #t))))))
         ((approval)
          (let ()
          (defvalues (candidate issue) (staged.publish model old revised-source revised-policy))
          (when issue (error "paired approval candidate" issue))
          (lambda () (bundle.admit revised-policy candidate old))))
         (else
       (lambda ()
         (defvalues (next issue) (staged.publish model old revised-source revised-policy))
         (and (not issue)
           (equal? (contracts.family-built (publication.version-contract-family next)) '(reserve cancel))
           (equal? (contracts.family-bound (publication.version-contract-family next)) '(reserve cancel))
           (equal? (generics.family-built (publication.version-family next)) '(quote reserve cancel))
           (or (not workflow?)
             (and (equal? (cache.cache-evaluated (publication.version-cache next)) '(invoice release total))
                  (= (length (cache.cache-reused (publication.version-cache next))) 12)))
           (equal? (first-value (publication.invoke next 'reserve 2)) (if workflow? '(ok 39 #t) '(ok 18 #t)))
           (equal? (first-value (publication.invoke next 'cancel "customer" #t))
                   (list "customer" (if workflow? "invoice:33" "invoice:2")))))))) models)))
    (else (error "unknown paired scenario" scenario))))
;; Native child entry: validate fixed scenario/regime/one-character side codes,
;; warm every thunk, optionally collect, then measure exactly the chosen side.
;; Record CPU/wall/GC, signed allocation and prefix counters; allocation becomes
;; unavailable across collections/negative deltas. Oracle failure aborts the sample.
(def (main scenario-text regime-text side-text)
  (def scenario (string->symbol scenario-text))
  (def regime (string->symbol regime-text))
  ;; One-character side codes keep the argv allocation shape constant.
  (def side (string->number side-text))
  (unless (and (memq scenario study.scenarios) (memq regime study.regimes) (memv side '(0 1 2 3 4 5 6 7 8)))
    (error "invalid paired request"))
  (def actions (workload scenario))
  (for* ((_ (in-range study.warmups)) (action actions)) (unless (action) (error "paired prefix oracle")))
  (when (eq? regime 'collected) (##gc))
  (def prefix (##process-statistics))
  (unless (= (f64vector-length prefix) 20) (error "unsupported statistics"))
  (def count (study.repetitions scenario))
  (defvalues (ok metrics) (measure (list-ref actions side) count))
  (unless ok (error "paired measured oracle"))
  (def raw (vector-ref metrics 4))
  (unless (and (= (vector-ref metrics 3) 0) (>= raw 0)) (vector-set! metrics 4 #f))
  (write (vector scenario regime side count metrics raw
    (vector (f64vector-ref prefix 6) (f64vector-ref prefix 7) (f64vector-ref prefix 9))))
  (newline))
