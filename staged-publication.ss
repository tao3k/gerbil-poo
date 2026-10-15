;;; StagedPublication.Model: bind one model to the existing cyclic lifecycle.
;;; Positive closure or selective DAG construction share one atomic lifecycle.
(export Model. methods.construction<-cache methods.contracts<-projection prepare publish)
(import ./closure ./object (only-in ./mop define-type .defgeneric)
        (prefix-in ./contract-family contract-family.)
        (prefix-in ./generic-family generic-family.)
        (prefix-in ./construction-cache construction-cache.)
        (prefix-in ./cyclic-publication cyclic-publication.))
(define-type (methods.construction<-cache @ [] builder)
  .construct:
  (lambda (source)
    (def cache (construction-cache.start source builder))
    (values (construction-cache.cache-source cache) cache))
  .refresh:
  (lambda (old source)
    (def cache (construction-cache.refresh (cyclic-publication.version-cache old) source builder))
    (values (construction-cache.cache-source cache) cache)))
(define-type (methods.contracts<-projection @ [] contract-source contracts-source contracts)
  .contracts: (lambda (old policy view execute available)
    (if (eq? contracts contracts-source)
      (contract-family.refresh contract-source (and old (cyclic-publication.version-contract-family old)) policy view execute available)
      (contracts policy view))))
(define-type (Model. @ [] cook generics contracts admit)
  ;; Default remains full admission. Overrides must justify stability of omitted
  ;; checks under cache-only invocation; every new publication still runs admit.
  .contracts: (lambda (_ policy view __ ___) (contracts policy view))
  admit-source: #f
  .admit-refresh: (lambda (_ policy candidate) (admit policy candidate))
  .readmit: (lambda (policy candidate) (admit policy candidate))
  .construct:
  (lambda (equations)
    (def plan (compile-closure equations 'cold))
    (values plan (solve-closure plan)))
  .refresh:
  (lambda (old equations)
    (def plan (reconfigure-closure (cyclic-publication.version-source old) equations))
    (values plan (solve-closure plan)))
  .prepare:
  (lambda (source policy)
    (cyclic-publication.stage-from #f (cut .construct source) (cut cook policy <>)
      (cut generic-family.prepare generics policy <>) (cut admit policy <>)
      (cut contracts policy <>) (cut .readmit policy <>) admit (cut .contracts #f policy <> <> <>)))
  .publish:
  (lambda (old source policy)
    (cyclic-publication.stage-from old (cut .refresh old source) (cut cook policy <>)
      (cut generic-family.refresh generics (cyclic-publication.version-family old) policy <>)
      (if (and (eq? admit-source admit) (eq? admit (cyclic-publication.version-admission-source old)))
        (cut .admit-refresh old policy <>) (cut admit policy <>))
      (cut contracts policy <>) (cut .readmit policy <>) admit (cut .contracts old policy <> <> <>))))
(.defgeneric (prepare model source policy) slot: .prepare)
(.defgeneric (publish model old source policy) slot: .publish)
