;;; Deterministic JSON adapters for POO types.

(export string<-json json<-string json-normalize)

(import :std/encoding/json)

(def (string<-json value)
  (json->string value sort-keys: #t))

(def (json<-string text)
  ;; POO's Class and Slot decoders use the HashTable interface for object
  ;; lookup.  Keep that public representation when decoding JSON objects.
  (string->json text
                (JSONReadOptions key-as-symbol: #f
                                 array-as-vector: #f
                                 object-as-hash: #t)))
(def (json-normalize value) (json<-string (string<-json value)))
