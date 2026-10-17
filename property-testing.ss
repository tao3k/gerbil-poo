;;; Descriptor-driven finite testing; pseudo-random sources belong to one run.
(export make-generator generator product-generator check-property replay-property property-action)
(import :std/error :std/iter (only-in :std/list/list map-in-order delete-duplicates/hash)
        ./object ./mop (only-in ./type List. Tuple. Pair. String)
        (only-in ./number Integer UInt)
        (prefix-in ./generalized-prototype observation.))
;; Gambit's SRFI-27 operations are host builtins, kept local to this module.
(extern namespace: #f make-random-source random-source-pseudo-randomize! random-source-make-integers)

;; Public samplers use ordinary extensible objects. Dependencies name every Type
;; or callback object captured by this sampler; ambient mutable state is excluded.
(def (make-generator descriptor draw shrink measure dependencies: (dependencies []))
  (validate Type descriptor)
  (unless (and (procedure? draw) (procedure? shrink) (procedure? measure)
               (list? dependencies) (every object? dependencies))
    (error "invalid generator protocol"))
  (.o bind-these: #f descriptor: descriptor draw: draw shrink: shrink measure: measure
      sources: (cons descriptor dependencies)))

;; Snapshot both descriptor and sampler identities; prototype revisions propagate
;; through object-revision, including inherited declaration changes.
(def (generator-sources sampler)
  (cons sampler (.get sampler sources)))
;; Capture mutable sources once before the first trial.
(def (snapshot sampler dependencies)
  (map (lambda (source) (cons source (object-revision source)))
       (delete-duplicates/hash (append (generator-sources sampler) dependencies))))
;; Refuse result admission after any declared source changed, including callbacks.
(def (current? sources)
  (every (lambda (entry) (= (cdr entry) (object-revision (car entry)))) sources))
;; Measures are natural numbers; malformed callbacks cannot admit shrink steps.
(def (weight sampler value)
  (def n (.call sampler measure value))
  (unless (and (exact-integer? n) (>= n 0)) (error "invalid shrink measure" n))
  n)
;; Replace one coordinate through a persistent reconstruction callback.
(def (coordinate-shrinks children values pack)
  (let loop ((children children) (values values) (before []))
    (if (null? children) []
      (append
        (map (lambda (smaller) (pack (append (reverse before) (cons smaller (cdr values)))))
             (.call (car children) shrink (car values)))
        (loop (cdr children) (cdr values) (cons (car values) before))))))
;; Products share draw/shrink/measure composition for tuples, pairs and call rows.
(def (product-generator descriptor children unpack pack)
  (make-generator descriptor
    (lambda (random size) (pack (map-in-order (lambda (child) (.call child draw random size)) children)))
    (lambda (value) (coordinate-shrinks children (unpack value) pack))
    (lambda (value) (apply + (map weight children (unpack value))))
    dependencies: (apply append (map generator-sources children))))

;; Integer shrinking decreases absolute magnitude and reaches zero without using
;; floating point. The runner independently enforces domain and strict descent.
(def (integer-shrinks value)
  (if (zero? value) []
    (delete-duplicates/hash (list 0 (quotient value 2) (- value (if (> value 0) 1 -1))))))
;; Derive only recognized finite descriptor families. Unsupported/refined Types
;; must supply an explicit .generator callback; they never produce a vacuous pass.
;; The depth limit refuses recursive descriptor expansion rather than diverging.
(def (generator descriptor (depth 32))
  (validate Type descriptor)
  (unless (and (exact-integer? depth) (> depth 0)) (error "generator descriptor depth exhausted"))
  (cond
    ((.has? descriptor .generator)
     (let (sampler (.call descriptor .generator))
       (unless (and (object? sampler) (eq? (.get sampler descriptor) descriptor))
         (error "generator descriptor mismatch")) sampler))
    ((eq? descriptor Bool)
     (make-generator descriptor (lambda (random _) (= (random 2) 1))
       (lambda (x) (if x [#f] [])) (lambda (x) (if x 1 0))))
    ((or (eq? descriptor Integer) (eq? descriptor UInt))
     (make-generator descriptor
       (lambda (random size) (if (eq? descriptor UInt) (random (+ size 1)) (- (random (+ (* 2 size) 1)) size)))
       integer-shrinks abs))
    ((eq? descriptor String)
     (make-generator descriptor
       (lambda (random size) (list->string (map (lambda (_) (integer->char (+ 97 (random 26)))) (iota (random (+ size 1))))))
       (lambda (x) (if (zero? (string-length x)) [] (list "" (substring x 0 (quotient (string-length x) 2)))))
       string-length))
    (else
      (def ancestors (compute-precedence-list! descriptor))
      (cond
        ((memq Tuple. ancestors)
         (product-generator descriptor (map (cut generator <> (- depth 1)) (.get descriptor type-list)) vector->list list->vector))
        ((memq Pair. ancestors)
         (product-generator descriptor (map (cut generator <> (- depth 1)) (list (.get descriptor left) (.get descriptor right)))
           (lambda (x) (list (car x) (cdr x))) (lambda (xs) (cons (car xs) (cadr xs)))))
        ((memq List. ancestors)
         (def child (generator (.get descriptor type) (- depth 1)))
         (make-generator descriptor
           (lambda (random size) (map-in-order (lambda (_) (.call child draw random size)) (iota (random (+ size 1)))))
           (lambda (xs) (if (null? xs) []
             (append (list [] (cdr xs)) (coordinate-shrinks (map (lambda (_) child) xs) xs identity))))
           (lambda (xs) (+ (length xs) (apply + (map (cut weight child <>) xs))))
           dependencies: (generator-sources child)))
        (else (error "descriptor requires an explicit .generator" descriptor))))))

;; Shrink a witnessed false result. Every proposed candidate consumes one unit,
;; even if invalid/nondecreasing; restart only on a smaller valid false result.
;; The callbacks must terminate and return finite proper lists. External process
;; watchdogs bound arbitrary host callbacks; fuel bounds this algorithm's attempts.
(def (shrink-failure sampler property original budget sources)
  (let/cc return
    (let loop ((best original) (remaining budget) (attempts 0) (steps 0))
      (unless (current? sources) (return (list 'stale best attempts steps #f)))
      (def candidates (.call sampler shrink best))
      (unless (list? candidates) (error "shrinker must return a finite proper list"))
      (let scan ((rest candidates) (remaining remaining) (attempts attempts))
        (unless (current? sources) (return (list 'stale best attempts steps #f)))
        (cond
          ((null? rest) (list 'failed best attempts steps #t))
          ((zero? remaining) (list 'failed best attempts steps #f))
          (else
            (def value (car rest))
            (def eligible (and (element? (.get sampler descriptor) value)
                               (< (weight sampler value) (weight sampler best))))
            (unless (current? sources) (return (list 'stale best (+ attempts 1) steps #f)))
            (def outcome (if eligible (property value) #t))
            (unless (boolean? outcome) (error "property must return a boolean" outcome))
            (unless (current? sources) (return (list 'stale best (+ attempts 1) steps #f)))
            (if (not outcome) (loop value (- remaining 1) (+ attempts 1) (+ steps 1))
              (scan (cdr rest) (- remaining 1) (+ attempts 1)))))))))

;; Finite seeded testing is evidence, not universal verification. Errors retain
;; their cause; neither generation errors nor property exceptions become passes.
;; minimal? means no smaller failing immediate supplied candidate, never global.
(def (check-property descriptor property seed: (seed 0) cases: (cases 100)
                     size: (size 20) shrink-budget: (shrink-budget 100) sampler: (supplied #f) dependencies: (dependencies []))
  (unless (and (procedure? property) (every (lambda (n) (and (exact-integer? n) (>= n 0)))
                          (list seed size shrink-budget)) (exact-integer? cases) (> cases 0))
    (error "invalid property testing configuration"))
  (def sampler (or supplied (generator descriptor)))
  (unless (eq? (.get sampler descriptor) descriptor) (error "sampler descriptor mismatch"))
  (unless (and (list? dependencies) (every object? dependencies)) (error "invalid property dependencies"))
  (def sources (snapshot sampler dependencies))
  (def source (make-random-source))
  (random-source-pseudo-randomize! source 0 seed)
  (def random (random-source-make-integers source))
  (def trial 0)
  (def original #f)
  ;; One report shape supports replay and FUN/IO consumers without serialized logs.
  (def (report status counterexample attempts steps minimal? (cause #f))
    (.o bind-these: #f status: status descriptor: descriptor property: property sampler: sampler
        seed: seed cases: cases size: size shrink-budget: shrink-budget sources: sources
        trial: trial original: original counterexample: counterexample attempts: attempts
        steps: steps minimal?: minimal? cause: cause dependencies: dependencies))
  (with-catch
    (lambda (cause) (report (if (current? sources) 'error 'stale) original 0 0 #f cause))
    (lambda ()
      (let/cc return
        (for (_ (in-range cases))
          (unless (current? sources) (return (report 'stale #f 0 0 #f)))
          (set! trial (+ trial 1))
          (set! original (.call sampler draw random size))
          (unless (element? descriptor original) (error "generator produced a value outside its descriptor" original))
          (unless (current? sources) (return (report 'stale original 0 0 #f)))
          (def outcome (property original))
          (unless (boolean? outcome) (error "property must return a boolean" outcome))
          (unless (current? sources) (return (report 'stale original 0 0 #f)))
          (unless outcome
            (let (result (shrink-failure sampler property original shrink-budget sources))
              (return (apply report result)))))
        (report 'passed #f 0 0 #f)))))

;; Replay the exact configuration only while descriptor and callback revisions
;; remain current. Repeatability assumes stable callback behavior and host PRNG.
(def (replay-property report)
  (unless (current? (.get report sources)) (error "stale property replay"))
  (check-property (.get report descriptor) (.get report property)
    seed: (.get report seed) cases: (.get report cases) size: (.get report size)
    shrink-budget: (.get report shrink-budget) sampler: (.get report sampler)
    dependencies: (.get report dependencies)))

;; Reader/FUN composition makes the test run one observation followed by the
;; supplied consumer, which may be an existing IO action or an evidence gate.
(def (property-action descriptor property consume)
  (.call observation.Observation. .bind
    (lambda (configuration) (check-property descriptor property
      seed: (.get configuration seed) cases: (.get configuration cases)
      size: (.get configuration size) shrink-budget: (.get configuration shrink-budget)))
    (lambda (report) (lambda (_configuration) (consume report)))))
