;;; Deterministic JSON adapters for POO types.

(export string<-json json<-string json-normalize)

(import :std/encoding/json
        (only-in :std/list/walist AList? walist->list))

(def (string<-json value)
  (json->string value sort-keys: #t))

;; V19 deliberately decodes objects as WAList values.  The public POO JSON
;; contract predates WAList and uses ordinary alists, so adapt only that value
;; representation while leaving parsing to :std/encoding/json.
(def (plain-json value)
  (cond
   ((AList? value)
    (map (lambda (entry) (cons (car entry) (plain-json (cdr entry))))
         (walist->list value)))
   ((list? value) (map plain-json value))
   ((vector? value) (vector-map plain-json value))
   (else value)))

(def (json<-string text)
  (plain-json
   (string->json text
                 (JSONReadOptions key-as-symbol: #f
                                  array-as-vector: #f
                                  object-as-hash: #f))))
(def (json-normalize value) (json<-string (string<-json value)))
