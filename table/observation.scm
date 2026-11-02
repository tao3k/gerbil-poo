;;; Complete Table observations share admission; backends retain their traversal.

 ;; Dynamic extent uses Gerbil's standard parameters. Only
;; admission is active: a completed observation may legitimately nest another.
(def active-table-observations (make-parameter []))

;; Reject the same receiver/snapshot during its own recognizer. Set admission
;; supplies its existing backing/refinement sequence; distinct receivers remain legal.
(def (admit-table-observation descriptor input (admit require-table))
  (def active (active-table-observations))
  (when (ormap (lambda (entry) (and (eq? (car entry) descriptor) (eq? (cdr entry) input))) active)
    (error "recursive table observation admission"))
  (parameterize ((active-table-observations (cons (cons descriptor input) active)))
    (admit descriptor input)))

;; Protect current descriptors for the whole eager observation. Recognize the
;; complete snapshot before any backend work; retain opaque Function leaves.
(def (observe-table descriptor input action)
  (with-table-sources (table-sources descriptor) (lambda ()
    (admit-table-observation descriptor input)
    (action))))

;; Admit once before creating a backend iterator. Delayed pulls reuse the
;; standard mapped Iterator guard, including repeated EOF, without rescanning a
;; persistent root or retaining metadata protection across caller suspension.
(def (iterate-table descriptor input from)
  (def sources (table-sources descriptor))
  (def versions (map object-revision sources))
  ;; Source/Key/Value/origin changes refuse before the next backend pull.
  (def (guard action)
    (with-table-sources sources action sources versions "stale table iterator"))
  (guard (lambda ()
    (admit-table-observation descriptor input)
    (when from (require-table-key descriptor from))
    (iterator-map identity
      (if from (.call descriptor .iter/key input from) (.call descriptor .iter/key input))
      guard))))
