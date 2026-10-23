;;; Serialize the checked Actions matrix without loading JSON in every compiler.
(export main)
(import :std/encoding/json
        (only-in "test-groups.ss" checked-groups)
        (only-in "build-artifacts.ss" group-source-key test-inventory-key))

;; The standard encoder owns escaping and object serialization. This CLI is the
;; only inventory consumer that needs JSON; generated matrices stay outside Git.
(def (main . request)
  (match request
    (["inventory"] (displayln (test-inventory-key)))
    ([]
      (def rows (map (lambda (group)
        (hash ("group" (car group)) ("modules" (string-join (cdr group) " "))
          ("source-key" (group-source-key (car group))))) (checked-groups)))
      (display (json->string (hash ("include" (list->vector rows)))))
      (newline))
    (else (error "unknown test inventory request" request))))
