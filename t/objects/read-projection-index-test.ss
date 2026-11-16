;;; Capture-local visitation reuses storage, never an admission verdict.
(import :std/test :std/iter :clan/poo/object
        (only-in :clan/poo/slot-observation %call-with-recorded-slot-reads
                 call-with-slot-read-observer slot-read-key)
        (only-in :std/error Error? Error-message)
        (prefix-in (only-in :gerbil/runtime/mop slot-set!) runtime.)
        (only-in :gerbil/runtime/gambit default-random-source))
(export read-visit-workspace-test)
(extern namespace: #f random-source-state-ref)
(extern namespace: clan/poo/object call-with-issued-reads %bind-current-slot-reads)
(extern namespace: clan/poo/slot-observation %projection-read-visit-index %current-slot-read-frame read-collection-thread read-collection-visit-index)

(def (bound-workspace-witness)
  (def witness (make-hash-table test: eq? weak-keys: #t))
  (def bound #f)
  (%call-with-recorded-slot-reads
    (lambda ()
      ;; A constant Slot avoids a test interpreter thunk retaining this probe's
      ;; entire lexical environment, including its explicit workspace handle.
      (def Owner (object<-alist '((value . #f))))
      (defvalues (_ roots) (%call-with-recorded-slot-reads (lambda () (.get Owner value))))
      (def visit (%projection-read-visit-index))
      (hash-put! witness (car visit) #t)
      (set! bound (%bind-current-slot-reads roots))
      (check (> (hash-length (car visit)) 0) => #t)) unique-roots?: #t)
  (values witness bound))

(def read-visit-workspace-test
  (test-suite "capture-local read traversal generations"
    (test-case "wide graph retains exact dense receiver domain and write guard"
      (def keys (for/collect (i (in-range 128))
        (string->symbol (string-append "field-" (number->string i)))))
      (def owner (object<-alist (map (lambda (key) (cons key #f)) keys)))
      (.def Root result: (map (lambda (key) (.ref owner key)) keys))
      (defvalues (_ roots) (%call-with-recorded-slot-reads (lambda () (.get Root result))))
      (check (> (call-with-current-slot-reads roots values) 128) => #t)
      (for (_ (in-range 2))
        (call-with-issued-reads roots
          (lambda (_reads _current! receivers)
            (check-equal? (hash-length receivers) 2)
            (check-equal? (andmap object? (hash-keys receivers)) #t)
            (check-equal? (list-sort < (hash-values receivers)) '(0 1))) #t))
      (check-exception
        (call-with-issued-reads roots
          (lambda (_reads _current! _receivers) (.put! owner (car keys) #t)) #t) error?)
      (check-equal? (.ref owner (car keys)) #f))
    (test-case "identity-table construction leaves application RNG unchanged"
      (def state (random-source-state-ref default-random-source))
      (make-hash-table-eq)
      (make-hash-table-eq)
      (check-equal? (random-source-state-ref default-random-source) state))
    (test-case "reused native table gives every binding a fresh identity"
      (%call-with-recorded-slot-reads
        (lambda ()
          (def state (random-source-state-ref default-random-source))
          (def first (%projection-read-visit-index))
          (hash-put! (car first) 'old first)
          (def second (%projection-read-visit-index))
          (check-eq? (car first) (car second))
          (check-equal? (eq? first second) #f)
          (check-equal? (eq? (hash-get (car second) 'old) second) #f)
          (check-equal? (random-source-state-ref default-random-source) state)) unique-roots?: #t))
    (test-case "a prior successful binding cannot skip changed issuance"
      (def Owner (object<-alist '((value . #f))))
      (defvalues (_ roots) (%call-with-recorded-slot-reads (lambda () (.get Owner value))))
      (def read (car (filter (lambda (read) (eq? (slot-read-key read) 'value)) roots)))
      (%call-with-recorded-slot-reads
        (lambda ()
          (%bind-current-slot-reads roots)
          (try
            (runtime.slot-set! read 'key 'tampered)
            (def cause (with-catch values (lambda () (%bind-current-slot-reads roots) #f)))
            (check (Error? cause) => #t)
            (check-equal? (Error-message cause) "unissued slot dependency")
            (finally (runtime.slot-set! read 'key 'value)))
          (check (> ((%bind-current-slot-reads roots) values) 0) => #t)) unique-roots?: #t))
    (test-case "open observers keep the original traversal path"
      (%call-with-recorded-slot-reads
        (lambda ()
          (call-with-slot-read-observer void
            (lambda () (check-equal? (%projection-read-visit-index) #f)))) unique-roots?: #t))
    (test-case "a child cannot claim its parent's unallocated workspace"
      (%call-with-recorded-slot-reads
        (lambda ()
          (def child (make-thread (lambda () (%projection-read-visit-index))))
          (thread-start! child)
          (check-equal? (thread-join! child) #f)
          (check (pair? (%projection-read-visit-index)) => #t)) unique-roots?: #t))
    (test-case "normal and exceptional exit revoke the workspace loan"
      (for (mode '(normal failure))
        (def frame #f)
        (def cause
          (with-catch values
            (lambda ()
              (%call-with-recorded-slot-reads
                (lambda ()
                  (set! frame (%current-slot-read-frame))
                  (%projection-read-visit-index)
                  (when (eq? mode 'failure) (error "fixture unwind"))) unique-roots?: #t)
              #f)))
        (check-equal? (Error? cause) (eq? mode 'failure))
        (check-equal? (read-collection-thread frame) #f)
        (check-equal? (read-collection-visit-index frame) #f)))
    (test-case "bound currentness releases the retired capture workspace"
      (defvalues (witness bound) (bound-workspace-witness))
      (##gc)
      (##gc)
      (check-equal? (hash-length witness) 0)
      (check (> (bound values) 0) => #t))))
