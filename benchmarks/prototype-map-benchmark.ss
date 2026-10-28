;;; Existing prototype-map studies share the same paired measurement engine.
(export +traversal-phases+ traversal-workload +catalog-phases+ catalog-workload
        +declaration-phases+ declaration-workload declaration-preparation-workload reference-reflection reference-read-slot)
(import :std/error :std/iter (only-in :std/list/list delete-duplicates/hash foldr)
        (only-in :clan/poo/slot-observation %slot-read-active? call-with-slot-read-observer) :clan/poo/object :clan/poo/prototype-map :clan/poo/mop :clan/poo/number
        (only-in :clan/poo/io module-action)
        (only-in :clan/poo/slot-layout make-slot-cache)
        (only-in :clan/poo/reflection reflect-slots read-slot)
        (prefix-in :clan/poo/examples/representation-service service.))

;; These controls compare current safe public snapshot composition with direct
;; ordered traversal/root sharing, including single-field and complete workflows.
(def +traversal-phases+ '(map-traverse map-keys map-compose map-compose-single map-compose-workflow))
;; Rebuild the same selected policy through public owned snapshots. The fresh
;; receiver has the SAME parents/protocol/declarations and no inherited cache.
(def (snapshot-compose base override)
  (make-object
    slots: (prototype-map (object-slots override) policy: (prototype-map-policy (object-%slots override)))
    defaults: (prototype-map (object-defaults override) policy: (prototype-map-policy (object-%defaults override)))
    supers: [(object-supers override)... base]
    protocol: (object-%protocol override) declarations: (object-%declarations override)))
;; Every result and callback order is checked inside timing; whole workflows also
;; charge template construction, warming, refinement, publication and retry.
(def (traversal-workload size scenario)
  (def entries (append (for/collect (n (in-range size)) (cons (make-symbol "field-" n) n))
    (list (cons 'target #f) (cons 'target identity))))
  (def source (prototype-map entries policy: 'compact))
  (def expected (map car entries))
  (def single? (eq? scenario 'map-compose-single))
  (def shared-parent (.o parent-marker: #f))
  (def override (make-object slots: (prototype-map
    (map (lambda (entry) (cons (car entry) ($constant-slot-spec (cdr entry))))
      (if single? (list (cons 'target identity)) entries)) policy: 'compact)
    defaults: (prototype-map (if single? [] (list (cons 'enabled #f) (cons 'callback identity))) policy: 'compact)))
  (.put! override 'total -999)
  (def enter (module-action "clan/poo/examples/representation-service"
    'clan/poo/examples/representation-service#composition-workflow))
  ;; An admitted map callback sees ordered values, never a mutable private pair.
  (def (walk direct?)
    (def seen '())
    ;; Charge the consumer's own output equally on both traversal paths.
    (def (consume key value) (set! seen (cons (cons key value) seen)))
    (if direct? (prototype-map-for-each source consume)
      (for (entry (prototype-map-list source)) (consume (car entry) (cdr entry))))
    (unless (equal? (reverse seen) entries) (error "prototype traversal oracle")))
  ;; Composition starts from identical warmed templates, then observes every field.
  (def (compose-and-read compose)
    (def receiver (compose service.Service override))
    (def fields (.alist receiver))
    (unless (and (= (.get receiver total) 33) (eq? (cdr (assq 'target fields)) identity)
                 (or single? (and (not (cdr (assq 'enabled fields)))
                                  (eq? (cdr (assq 'callback fields)) identity))))
      (error "prototype composition oracle")))
  ;; One standard action factory retains every public boundary on each side.
  (def (action direct?)
    (def combine (if direct? .+ snapshot-compose))
    ;; Both sides replace warmed topology through the SAME checked setter. The
    ;; reference pays its owned parent snapshot; the engine can borrow privately.
    ;; Parent admission, invalidation and result ownership stay inside timing.
    (def (compose base override)
      (object-supers-set! override [shared-parent])
      (let (result (combine base override))
        (unless (eq? (car (object-supers result)) shared-parent)
          (error "composed parent identity oracle"))
        result))
    (lambda ()
      (case scenario
        ((map-traverse) (walk direct?))
        ((map-keys)
          (unless (equal? (if direct? (prototype-map-keys source) (map car (prototype-map-list source))) expected)
            (error "prototype keys oracle")))
        ((map-compose map-compose-single) (compose-and-read compose))
        ((map-compose-workflow)
          (unless (equal? (enter (list size compose: compose policy: 'compact)) '#(24 30 36 6))
            (error "prototype publication oracle"))))
      #t))
  (values (action #f) (action #t)))

;; Empty control, full capture, cloning, public reflection and the checked module
;; workflow are separate phases. Neither side aliases public mutable pairs.
(def +catalog-phases+ '(catalog-empty catalog-single catalog-cold catalog-clone catalog-reflect catalog-workflow))
;; Reference recaptures an owned snapshot; candidate shares immutable catalog roots.
;; Initial descriptor capture, all demanded values and full publication stay charged
;; in cold/workflow phases. This compares supported current strategies, not an
;; unsafe old alias or a claim about historical compiler performance.
(def (catalog-workload width scenario)
  (def size (if (eq? scenario 'catalog-single) 1 width))
  ;; Shared descriptor construction uses explicit finite types, not Any fallback.
  (def (template)
    (make-object declarations: (prototype-map
      (for/collect (n (in-range size))
        (cons (make-symbol "field-" n) (.new Slot type: Integer constant: n))) policy: 'compact)))
  (def warm (template))
  (def enter (module-action "clan/poo/examples/representation-service"
    'clan/poo/examples/representation-service#catalog-workflow))
  ;; Both fresh receivers use identical metadata, policy and normal lazy admission.
  (def (copy source direct?)
    (make-object slots: (object-%slots source) defaults: (object-%defaults source)
      supers: (object-supers source) protocol: (object-%protocol source)
      declarations: (if direct? (object-%declarations source)
        (prototype-map (object-declarations source) policy: 'compact))))
  ;; Demand every declared value and compare complete public names in source order.
  (def (observe owner)
    (unless (and (equal? (map car (reflect-slots owner))
                         (for/collect (n (in-range size)) (make-symbol "field-" n)))
                 (= (for/fold (sum 0) (n (in-range size))
                      (+ sum (read-slot owner (make-symbol "field-" n))))
                    (quotient (* size (1- size)) 2)))
      (error "catalog observation oracle")))
  ;; Each timed action contains its oracle and preserves the exact original error.
  (def (action direct?)
    (lambda ()
      (case scenario
        ((catalog-empty)
          (unless (and (zero? (prototype-map-length (object-%declarations (make-object))))
                       (null? (reflect-slots (make-object)))) (error "empty catalog oracle")))
        ((catalog-single catalog-cold) (observe (copy (template) direct?)))
        ((catalog-clone) (observe (copy warm direct?)))
        ((catalog-reflect)
          (let (view (reflect-slots warm))
            (set-car! (car view) 'client-only)
            (observe warm)))
        ((catalog-workflow)
          (unless (equal? (enter (list size recapture?: (not direct?) policy: 'compact)) '#(24 30 36 6))
            (error "catalog publication oracle"))))
      #t))
  (values (action #f) (action #t)))

;; An independent safe scan oracle retains owned snapshots and the original
;; ordered visibility fold. Include the new owner-membership observation/fence
;; on BOTH sides, so timing does not compare different dependency guarantees.
(def (reference-reflection owner)
  (def revision (object-revision owner))
  (instantiate-object! owner)
  (when (%slot-read-active?) (.all-slots owner))
  (unless (= revision (object-revision owner)) (error "object changed during declaration reflection"))
  (let (result (foldr (lambda (entry rest)
    (if (.@ (cdr entry) hidden) rest (cons entry rest))) []
    (delete-duplicates/hash
      (apply append (map object-declarations (object-%precedence-list owner)))
      key: car table: (make-hash-table-symbolic) from-end?: #t)))
    (unless (= revision (object-revision owner)) (error "object changed during declaration reflection"))
    result))
;; Reuse the actual Slot validation protocol after the independent scan; every
;; call still checks its concrete value and propagates the original exception.
(def (reference-read-slot owner name)
  (def revision (object-revision owner))
  (def descriptor (cdr (or (assq name (reference-reflection owner))
    (error "slot is hidden or undeclared" name))))
  (def value (.ref owner name))
  (unless (.call (.@ descriptor .type) .slot.check descriptor name (object<-alist [(cons name value)]))
    (error "declared slot value rejected" name))
  (unless (= revision (object-revision owner)) (error "object changed during declaration reflection"))
  value)
;; Cold and single cases pay metadata construction/index preparation. Hot/missing
;; and observed controls retain their own explicit setup. Full module workflows
;; include every initial descriptor, refinement, consumer and revision/refusal/retry.
(def +declaration-phases+ '(declaration-directory declaration-directory-shared declaration-visibility declaration-visibility-mixed declaration-private-filter
  declaration-construction declaration-empty declaration-single declaration-cold declaration-hot-single
  declaration-hot declaration-missing declaration-observed declaration-workflow declaration-workflow-shared))
;; Compare indexed public access with safe scan selection on the same admitted
;; receiver and through identical Slot checks. Reflection outputs remain owned.
(def (declaration-workload width scenario)
  (def size (if (memq scenario '(declaration-single declaration-hot-single)) 1 width))
  (def name (make-symbol "field-" (1- size)))
  ;; Each cold receiver owns its descriptor graph; warm paths share only setup.
  (def (fresh)
    (make-object declarations: (for/collect (n (in-range size))
      (cons (make-symbol "field-" n) (.new Slot type: Integer constant: n)))))
  (def owner (and (memq scenario '(declaration-hot-single declaration-hot declaration-missing declaration-observed)) (fresh)))
  (when owner (read-slot owner name) (reference-read-slot owner name))
  (def enter (module-action "clan/poo/examples/representation-service"
    'clan/poo/examples/representation-service#catalog-workflow))
  ;; The full publication's inspector demands every typed declared field before
  ;; returning ordinary values to the existing shared FUN/refinement pipeline.
  (def (inspect read)
    (lambda (candidate)
      (for (entry (reflect-slots candidate)) (read candidate (car entry)))
      (.alist candidate)))
  ;; Observed timing charges the owner query on both sides, preserving ordered
  ;; descriptor deliveries. It does not cache a prior successful Type check.
  (def (action read reflect)
    (lambda ()
      (case scenario
        ((declaration-empty)
          (unless (equal? (reflect (make-object)) []) (error "empty reflection oracle")))
        ((declaration-construction)
          ;; Both sides construct and instantiate the same fresh descriptor graph.
          ;; This A/A phase exposes shared preparation/GC noise, not query savings.
          (let (candidate (fresh))
            (instantiate-object! candidate)
            (unless (= (prototype-map-length (object-%declarations candidate)) size)
              (error "declaration construction oracle"))))
        ((declaration-single declaration-cold)
          (unless (= (read (fresh) name) (1- size)) (error "cold declaration oracle")))
        ((declaration-hot-single declaration-hot)
          (unless (= (read owner name) (1- size)) (error "hot declaration oracle")))
        ((declaration-missing)
          (unless (Error? (with-catch identity (cut read owner 'missing))) (error "missing declaration oracle")))
        ((declaration-observed)
          (let (events [])
            (unless (and (= (call-with-slot-read-observer
              (lambda (event) (set! events (cons event events))) (cut read owner name)) (1- size))
              (pair? events)) (error "observed declaration oracle"))))
        ((declaration-workflow declaration-workflow-shared)
          (unless (equal? (enter (list size policy: 'compact shared?: (eq? scenario 'declaration-workflow-shared) inspect: (inspect read))) '#(24 30 36 6))
            (error "declaration publication oracle"))))
      #t))
  (values (action reference-read-slot reference-reflection) (action read-slot reflect-slots)))

;; Original directory preparation, isolated for a matched construction diagnostic.
;; Private input maps are identical on both sides, including empty C3 catalogs.
(def (materialized-directory sources)
  (prototype-map (delete-duplicates/hash
    (apply append (map prototype-map-list sources))
    key: car table: (make-hash-table-eq) from-end?: #t) policy: 'compact))
;; Original visibility preparation preserves callback order and always rebuilds.
;; This is a benchmark counterfactual, not another production cache/registry.
(def (materialized-visibility source)
  (prototype-map (foldr (lambda (entry rest)
    (if (.@ (cdr entry) hidden) rest (cons entry rest))) []
    (prototype-map-list source)) policy: (prototype-map-policy source)))
;; Previous all-pass-sharing filter, retained only as an attribution control.
;; It exports private input first; both sides retain the same final-root shortcut.
(def (snapshot-visibility source keep?)
  (using (keep? :~ procedure?)
    (def retained 0)
    (def entries (foldr (lambda (entry rest)
      (if (keep? (car entry) (cdr entry))
        (begin (set! retained (1+ retained)) (cons entry rest)) rest)) [] (prototype-map-list source)))
    (if (= retained (prototype-map-length source)) source
      (prototype-map entries policy: (prototype-map-policy source)))))
;; Separate directory/index building from current visibility reads. Both sides
;; pay the same result oracle. Main cold/workflow phases still charge everything.
(def (declaration-preparation-workload size scenario)
  (def mixed? (eq? scenario 'declaration-visibility-mixed))
  (def entries (for/collect (n (in-range size))
    (cons (make-symbol "field-" n) (.new Slot type: Integer constant: n hidden: (and mixed? (zero? (modulo n 4)))))))
  (def source (prototype-map entries policy: 'compact))
  (def shared? (eq? scenario 'declaration-directory-shared))
  (def sources (if shared?
    (list (prototype-map (take entries (quotient size 2)) policy: 'compact)
          source (prototype-map (reverse entries) policy: 'tree))
    (list (prototype-map []) source (prototype-map []))))
  ;; Warm descriptor values only for this isolated component diagnostic.
  (for (entry entries) (.@ (cdr entry) hidden))
  (def expected (if mixed? (- size (quotient (+ size 3) 4)) size))
  ;; Directory controls compare identical ordered roots, including shared overlaps;
  ;; both pay deduplication/result capture, with only the input export differing.
  ;; Visibility controls measure old filtered-map construction versus all-pass reuse.
  (def (action direct?)
    (lambda ()
      (let (result (if (memq scenario '(declaration-directory declaration-directory-shared))
        (if direct? (prototype-map-merge-first sources policy: 'compact) (materialized-directory sources))
        (if direct? (prototype-map-filter source (lambda (_name descriptor) (not (.@ descriptor hidden))))
          (if (eq? scenario 'declaration-private-filter) (snapshot-visibility source (lambda (_name descriptor) (not (.@ descriptor hidden))))
            (materialized-visibility source)))))
        (unless (= (prototype-map-length result) expected) (error "declaration preparation oracle"))
        #t)))
  (values (action #f) (action #t)))
