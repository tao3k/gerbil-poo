;;; Each child builds every control in the same order, warms every control a fixed
;;; number of times, then measures ONE side. Nothing from another sample survives.
(export main workload)
(import :gerbil/runtime/gambit :std/iter (only-in :std/values first-value)
        ../object "closure-measure.ss" (prefix-in "metadata-paired-cases.ss" study.)
        (prefix-in ../contract-family contracts.) (prefix-in ../generic-family generics.)
        (prefix-in ../staged-publication staged.) (prefix-in ../cyclic-publication publication.)
        (prefix-in ../examples/service-combination qualified.) (prefix-in ../examples/service-bundle bundle.)
        (prefix-in ../examples/cyclic-access access.) (prefix-in ../multimethod dispatch.))
;; Select a fixed ten-side model row. Contract preparation, shared expansion and
;; admission policy are identical; only nested combination/cache ownership varies.
(def (models forwarding?)
  (def original (if forwarding? qualified.forwarding-model qualified.simula-model))
  (def compiled (if forwarding? qualified.compiled-forwarding-model qualified.compiled-simula-model))
  (def prepared (if forwarding? qualified.prepared-forwarding-model qualified.prepared-simula-model))
  (def cached (if forwarding? qualified.cached-forwarding-model qualified.cached-simula-model))
  (list original original compiled compiled prepared prepared prepared prepared cached cached))
;; Each child builds all ten controls before timing and executes the same warmup
;; prefix. Configure charges the complete protected child construction; cold
;; charges initial joint publication plus its first checked call. Warm threads
;; returned versions. Revision/repeated charge construction, binding, admission
;; and one/eight checked calls under the changed capacity AND invoice dependency.
;; Every model first proves its unchanged-snapshot late-admission refusal outside
;; timing. No accumulated cache or timing is imported from another process.
(def (workload scenario)
  (def forwarding? (memq scenario '(forwarding-configure forwarding-cold forwarding-warm forwarding-revision forwarding-repeated)))
  (def phase (case scenario
    ((forwarding-configure simula-configure) 'configure)
    ((forwarding-cold simula-cold) 'cold)
    ((forwarding-warm simula-warm) 'warm)
    ((forwarding-revision simula-revision) 'revision)
    ((forwarding-repeated simula-repeated) 'repeated)
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
         (def child ((if forwarding? qualified.forwarder qualified.preflight) view (and (<= 2 index) (< index 8))))
         (and (dispatch.multimethod? child) (= (dispatch.cache-size child) 0))))
      ((cold)
       (lambda ()
         (defvalues (version failure) (staged.prepare model source policy))
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
           (for/fold (ok #t) (_ (in-range (if (eq? phase 'repeated) 8 1)))
             (let-values (((answer successor) (publication.invoke next 'reserve 2)))
               (set! next successor)
               (and ok (equal? answer '(ok 18 #t)))))
           (equal? (first-value (publication.invoke next 'cancel "customer" #t)) '("customer" "invoice:2")))))))
    (models forwarding?) '(0 1 2 3 4 5 6 7 8 9)))
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
