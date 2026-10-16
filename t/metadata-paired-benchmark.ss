;;; Each child builds every control in the same order, warms every control a fixed
;;; number of times, then measures ONE side. Nothing from another sample survives.
(export main workload)
(import :gerbil/runtime/gambit :std/iter (only-in :std/values first-value)
        ../object "closure-measure.ss" (prefix-in "metadata-paired-cases.ss" study.)
        (prefix-in ../contract-family contracts.) (prefix-in ../generic-family generics.)
        (prefix-in ../staged-publication staged.) (prefix-in ../cyclic-publication publication.)
        (prefix-in ../examples/service-combination qualified.) (prefix-in ../examples/service-bundle bundle.)
        (prefix-in ../examples/cyclic-access access.) (prefix-in ../multimethod dispatch.))
;; Build the SAME ten strategy controls in each fresh process. Compiled context
;; staged lifecycle composition retain the old contracts, watches and admission.
(def (models)
  (list qualified.simula-model qualified.context-prepared-simula-model
    qualified.prepared-simula-model qualified.prepared-simula-model
    qualified.staged-simula-model qualified.staged-simula-model
    qualified.compiled-context-model qualified.context-prepared-simula-model
    qualified.shape-prepared-simula-model qualified.cached-simula-model))
;; Each child builds all ten controls before timing and executes the same warmup
;; prefix. Configure charges protected child construction/declared preparation;
;; generics isolates changed heterogeneous constructors without invoking a body.
;; Probe drops successors as admission does; transfer additionally commits the
;; family/version successor and readmits its actual cache. Cold charges initial
;; joint publication plus its first checked call. Pure compiled context charges
;; fresh code/wrappers; staged lifecycle charges its wrapper and captured child.
;; Bind isolates pure-context template reuse; staged keeps its same cold path.
;; Module initialization is common fixed-prefix work outside all phase timings.
;; Warm threads
;; returned versions. Revision/repeated charge construction, binding, admission
;; and one/eight checked calls under the changed capacity AND invoice dependency.
;; Every model first proves its unchanged-snapshot late-admission refusal outside
;; timing. No accumulated cache or timing is imported from another process.
(def (workload scenario)
  (def phase (case scenario
    ((simula-configure) 'configure) ((simula-generics) 'generics)
    ((simula-probe) 'probe) ((simula-transfer) 'transfer)
    ((simula-cold) 'cold) ((simula-bind) 'bind) ((simula-warm) 'warm)
    ((simula-stage) 'stage) ((simula-revision simula-allocation) 'revision)
    ((simula-repeated) 'repeated)
    (else (error "unknown paired scenario" scenario))))
  (def policy (.cc bundle.Policy. capacity: 10 price: 3 invoice: "invoice:1"))
  (def revised (.cc policy capacity: 20 invoice: "invoice:2"))
  (def view (.o (capacity 10) (invoice "invoice:1") (release #t)))
  (def source (access.equations (access.config) #t))
  (map (lambda (model index)
    (defvalues (cold issue) (staged.prepare model source policy))
    (when issue (error "paired baseline refused" issue))
    (defvalues (result old) (publication.invoke cold 'reserve 2))
    (unless (equal? result '(ok 8 #t)) (error "paired reference observation"))
    (defvalues (held refused) (staged.publish model old source (.cc policy cache-limit: 0)))
    (unless (and (eq? held old) refused (eq? (publication.failure-stage refused) 'admission))
      (error "paired warm-budget refusal"))
    (case phase
      ((configure)
       (lambda ()
         (def child (if (memv index '(1 6 7)) (qualified.context-preflight (= index 6))
           (qualified.preflight view (and (<= 2 index) (< index 9)) (memv index '(8)))))
         (and (dispatch.multimethod? child)
           (= (dispatch.cache-size child) (if (memv index '(1 6 7 8)) 1 0)))))
      ((generics)
       (let (next-view (.call model cook revised (publication.version-cache old)))
         (lambda ()
           (def next (generics.refresh (.@ model generics) (publication.version-family old) revised next-view))
           (and (equal? (generics.family-built next) '(quote reserve cancel))
                (= (length (generics.family-keys next)) 3)))))
      ((probe transfer)
       (let-values (((candidate issue) (staged.publish model old source revised)))
         (when issue (error "paired candidate refused" issue))
         (if (eq? phase 'probe)
           (lambda () (equal? (publication.probe candidate 'reserve 2) '(ok 18 #t)))
           (lambda ()
             (defvalues (answer successor) (publication.invoke candidate 'reserve 2))
             (and (equal? answer '(ok 18 #t))
               (if (memv index '(1 4 5 6 7 8)) (eq? successor candidate) #t))))))
      ((cold bind)
       (lambda ()
         ;; Pure context cold charges fresh code/fused construction; bind reuses
         ;; its template. Staged cold/bind charge a new workflow wrapper and
         ;; the captured child actually constructed by its initial publisher.
         (def selected (case index ((1 7) (qualified.context-simula-model))
           ((4 5) (qualified.simula-workflow-model))
           ((6) (if (eq? phase 'cold)
             (qualified.compiled-context-simula-model (qualified.context-preflight #t) #f)
             (qualified.compiled-context-simula-model))) (else model)))
         (defvalues (version failure) (staged.prepare selected source policy))
         (and (not failure) (equal? (first-value (publication.invoke version 'reserve 2)) '(ok 8 #t)))))
      ((warm)
       ;; State is local to this benchmark control, never a production hidden cache.
       (lambda ()
         (defvalues (answer next) (publication.invoke old 'reserve 2))
         (set! old next)
         (equal? answer '(ok 8 #t))))
      (else
       (lambda ()
         (defvalues (next failure) (staged.publish model old source revised))
         (and (not failure)
           (equal? (contracts.family-built (publication.version-contract-family next)) '(reserve cancel))
           (equal? (contracts.family-bound (publication.version-contract-family next)) '(reserve cancel))
           (equal? (generics.family-built (publication.version-family next)) '(quote reserve cancel))
           (for/fold (ok #t) (_ (in-range (case phase ((stage) 0) ((repeated) 8) (else 1))))
             (let-values (((answer successor) (publication.invoke next 'reserve 2)))
               (set! next successor)
               (and ok (equal? answer '(ok 18 #t)))))
           (or (eq? phase 'stage)
             (equal? (first-value (publication.invoke next 'cancel "customer" #t)) '("customer" "invoice:2"))))))))
    (models) '(0 1 2 3 4 5 6 7 8 9)))
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
