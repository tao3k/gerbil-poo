;;; StagedPublication.Model: bind one model to the existing cyclic lifecycle.
;;; Finite positive graphs only; this does not implement selective graph rebuilds.
(export Model. prepare publish)
(import ./object (only-in ./mop define-type .defgeneric)
        (prefix-in ./generic-family generic-family.)
        (prefix-in ./cyclic-publication cyclic-publication.))
(define-type (Model. @ [] cook generics contracts admit)
  .prepare:
  (lambda (equations policy)
    (cyclic-publication.prepare equations (cut cook policy <>)
      (cut generic-family.build generics policy <>) (cut admit policy <>)
      (cut contracts policy <>) (cut admit policy <>)))
  .publish:
  (lambda (old equations policy)
    (cyclic-publication.publish old equations (cut cook policy <>)
      (cut generic-family.build generics policy <>) (cut admit policy <>) #t
      (cut contracts policy <>) (cut admit policy <>))))
(.defgeneric (prepare model equations policy) slot: .prepare)
(.defgeneric (publish model old equations policy) slot: .publish)
