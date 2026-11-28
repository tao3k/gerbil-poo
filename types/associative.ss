(define-type (Map. @ [methods.string&bytes&marshal<-json Type.] Key Value)
  .gerbil-type: HashTable::interface
  .validate: (lambda (value) (validate-map @ Key Value value))
  .diagnose: (lambda (value location) (map-shape @ Key Value value location diagnose-value))
  .diagnose-shape: (lambda (value location (check-field diagnose-structure))
                     (map-shape @ Key Value value location check-field))
  .element?: (lambda (x) (and (hash-table? x)
                         (let/cc return
                           (hash-for-each
                            (lambda (k v) (unless (and (element? Key k) (element? Value v))
                                       (return #f)))
                            x) #t)))
  .empty: (make-hash-table)
  .json<-: (lambda (m) (hash-key-value-map (lambda (k v) (cons (string<- Key k) (json<- Value v))) m))
  .<-json: (lambda (j) (hash-key-value-map (lambda (k v) (cons (<-string Key k) (<-json Value v))) j)))
(defrules Map (<- ->)
  ((_ Value <- Key) {(:: @ Map.) Key: Key Value: Value
                     sexp: `(Map ,(.@ Value sexp) <- ,(.@ Key sexp))})
  ((_ Key -> Value) (Map Value <- Key)))

;; Normalize declared Record options into the existing effective Slot metadata.
(def (RecordSlot type . options)
  (validate Type type)
  (object<-alist
   (acons 'type type
          (map (match <> ([k . v] (cons (make-symbol k) v))) (plist->alist options)))))

;; Record inherits effective Class slots through existing C3 prototype composition.
;; Initialization-time defaults/compute/optional policy remains owned by Slot.
(def (Record . args)
  (def supers (if (or (null? args) (keyword? (car args))) [] (pop! args)))
  (def field-specs (plist->alist args))
  (def normalized
    (map (match <> ([kw type . options]
                    (cons (make-symbol kw) (apply RecordSlot type options))))
         field-specs))
  {(:: @ (cons supers Class.))
   sexp: `(Record ,@(append-map
                      (match <> ([kw type . options]
                                 (list kw (cons (.@ type sexp) options))))
                      field-specs))
   slots: =>.+ (object<-alist normalized)})
