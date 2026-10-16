;;; Each child builds every control in the same order, warms every control a fixed
;;; number of times, then measures ONE side. Nothing from another sample survives.
(export main workload)
(import :gerbil/runtime/gambit :std/iter (only-in :std/values first-value)
        ../object "closure-measure.ss" (prefix-in "metadata-paired-cases.ss" study.)
        (prefix-in ../contract-family contracts.) (prefix-in ../generic-family generics.)
        (prefix-in ../staged-publication staged.) (prefix-in ../cyclic-publication publication.)
        (prefix-in ../examples/service-combination qualified.) (prefix-in ../examples/service-bundle bundle.)
        (prefix-in ../examples/cyclic-access access.) (prefix-in ../multimethod dispatch.))
;; One view-independent child supplies the actual no-binding control. Construction
;; is common module setup, not silently charged to any timed binding sample.
(def shared-context-program (qualified.context-preflight #t))
;; Every child constructs the SAME ten controls; duplicate indices share exact
;; model identity. Module setup stays outside measured publication/call phases.
(def (models)
  (list qualified.staged-simula-model qualified.empty-storage-simula-model qualified.bound-simula-model
    qualified.bound-simula-model qualified.staged-simula-model qualified.empty-storage-simula-model
    qualified.compiled-context-model qualified.prepared-simula-model
    qualified.shape-prepared-simula-model qualified.cached-simula-model))
;; Each control prepares its initial captured version AND performs a real first
;; checked owner handoff before timing. One-shot first/next-revision allocations
;; are separate from threaded post-handoff calls. Full handoff, contract binding,
;; negative approval, readmission and cache checks remain in the timed workflow.
;; A fixed 256-request burst tests the complete call-heavy horizon, including
;; publication, every contract/readmission and cancel; counts never adapt to time.
;; Every side also proves its current zero-budget refusal outside timing.
(def (workload scenario)
  (def policy (.cc bundle.Policy. capacity: 10 price: 3 invoice: "invoice:1"))
  (def revised (.cc policy capacity: 20 invoice: "invoice:2"))
  (def later (.cc policy capacity: 30 invoice: "invoice:3"))
  (def source (access.equations (access.config) #t))
  (map (lambda (model strategy)
    (defvalues (cold issue) (staged.prepare model source policy))
    (when issue (error "paired baseline refused" issue))
    (defvalues (result old) (publication.invoke cold 'reserve 2))
    (unless (equal? result '(ok 8 #t)) (error "paired initial observation"))
    (defvalues (switched switched-issue) (staged.publish model old source revised))
    (when switched-issue (error "paired owner handoff refused" switched-issue))
    (defvalues (answer current) (publication.invoke switched 'reserve 2))
    (unless (equal? answer '(ok 18 #t)) (error "paired post-handoff observation"))
    (defvalues (held refused) (staged.publish model current source (.cc revised cache-limit: 0)))
    (unless (and (eq? held current) refused (eq? (publication.failure-stage refused) 'admission))
      (error "paired warm-budget refusal"))
    (case scenario
      ;; Isolate binding over an already reconstructed immutable view. The shared
      ;; argument-context control returns its exact template; bound modes allocate
      ;; only their typed context owner. No methods, contracts or publication here.
      ((simula-bind-allocation)
       (let (view (publication.version-view switched))
         (lambda () (dispatch.multimethod?
           (if (memq strategy '(bound bound-aa empty-storage empty-storage-aa))
             (qualified.bound-preflight view) shared-context-program)))))
      ;; Isolate later generic construction, keeping cooking and contracts outside
      ;; this phase. Full workflows below still include ALL those costs.
      ((simula-next-generics-allocation)
       (let (view (.call model cook later (publication.version-cache current)))
         (lambda ()
           (def next (generics.refresh (.@ model generics) (publication.version-family current) later view))
           (equal? (generics.family-built next) '(quote reserve cancel)))))
      ((simula-generics-allocation)
       (let (view (.call model cook revised (publication.version-cache old)))
         (lambda ()
           (def next (generics.refresh (.@ model generics) (publication.version-family old) revised view))
           (equal? (generics.family-built next) '(quote reserve cancel)))))
      ((simula-contracts-allocation)
       (let ((view (publication.version-view switched))
             (available (cut generics.family-has? (publication.version-family switched) <>))
             (execute (lambda _ (error "allocation control must not invoke wrappers"))))
         (lambda ()
           (def next (.call model .contracts old revised view execute available))
           (and (equal? (contracts.family-built next) '(reserve cancel))
             (equal? (contracts.family-bound next) '(reserve cancel))))))
      ((simula-post-warm simula-post-allocation)
       (lambda ()
         (defvalues (answer next) (publication.invoke current 'reserve 2))
         (set! current next)
         (equal? answer '(ok 18 #t))))
      ((simula-post-probe)
       (lambda () (equal? (publication.probe current 'reserve 2) '(ok 18 #t))))
      (else
       (let ((subsequent? (memq scenario '(simula-next simula-next-allocation simula-unchanged)))
             (unchanged? (eq? scenario 'simula-unchanged)))
       (lambda ()
         (defvalues (next failure) (staged.publish model (if subsequent? current old) source
           (if (and subsequent? (not unchanged?)) later revised)))
         (and (not failure)
           (equal? (contracts.family-built (publication.version-contract-family next))
             (if unchanged? [] '(reserve cancel)))
           (equal? (generics.family-built (publication.version-family next))
             (if unchanged? [] '(quote reserve cancel)))
           (or (not unchanged?)
             (eq? (generics.family-ref (publication.version-family next) 'reserve)
               (generics.family-ref (publication.version-family current) 'reserve)))
           (for/fold (ok #t) (_ (in-range (case scenario ((simula-handoff) 0) ((simula-repeated) 8) ((simula-burst) 256) (else 1))))
             (let-values (((answer successor) (publication.invoke next 'reserve 2)))
               (set! next successor)
               (and ok (equal? answer (if (and subsequent? (not unchanged?)) '(ok 28 #t) '(ok 18 #t))))))
           (or (eq? scenario 'simula-handoff)
             (equal? (first-value (publication.invoke next 'cancel "customer" #t))
               (list "customer" (if (and subsequent? (not unchanged?)) "invoice:3" "invoice:2"))))))))))
    (models) study.strategies))
;; Native child entry: validate fixed scenario/regime/one-character side codes,
;; warm every thunk, optionally collect, then measure exactly the chosen side.
;; Record CPU/wall/GC, signed allocation and prefix counters; allocation becomes
;; unavailable across collections/negative deltas. Oracle failure aborts the sample.
(def (main scenario-text regime-text side-text)
  (def scenario (string->symbol scenario-text))
  (def regime (string->symbol regime-text))
  ;; One-character side codes keep the argv allocation shape constant.
  (def side (string->number side-text))
  (unless (and (memq scenario study.scenarios) (memq regime study.regimes) (memv side '(0 1 2 3 4 5 6 7 8 9)))
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
