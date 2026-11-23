;; Sum : {Kw Type} ... -> Type
;; Sum types aka tagged unions, each kw is a tag
;; A nominal carrier protocol lets bounded consumers recognize Sum without
;; guessing from user-defined slot names or parsing its printed declaration.
(define-type (Sum. @ [methods.bytes<-marshal Type.]))
(def (Sum . plist)
  ;; a : [Assocof Symbol Type]
  (def a (map (match <> ([kw . type] (cons (make-symbol kw) type))) (plist->alist plist)))
  (def sum-variant-names (map car a))
  (def variant-names@ (list->vector sum-variant-names))
  (def variant-indices
    (object<-alist
     (for/collect ((tag sum-variant-names)
                   (tag-n (in-range (length sum-variant-names))))
       (cons tag tag-n))))
  (def tag-marsh-t (UIntN (integer-length (max 0 (1- (vector-length variant-names@))))))
  {(:: @ [Sum.])
      sexp: ['Sum (apply append (map-in-order (match <> ([k . t] [(make-keyword k) (.@ t sexp)])) a))...]
      variants: (object<-alist a)
      variant-names: sum-variant-names
      types: (map cdr a)
      make: (lambda (tag value) {(tag) (value)})
      .validate: (lambda (value) (validate-sum @ variants value))
      .diagnose: (lambda (value location) (sum-shape @ variants value location diagnose-value))
      .diagnose-shape: (lambda (value location (check-field diagnose-structure))
                         (sum-shape @ variants value location check-field))
      ;; Recognize tag before payload too; a record pattern would demand both.
      .element?: (lambda (value) (null? (sum-shape @ variants value '() diagnose-value)))
      .sexp<-: (lambda (v)
                 (def tag (.@ v tag))
                 `(.call ,sexp make ',tag ,(sexp<- (.ref variants tag) (.@ v value))))
      .json<-: (lambda (v)
                 (def tag (.@ v tag))
                 (def tagj (symbol->string tag))
                 (def valj (json<- (.ref variants tag) (.@ v value)))
                 (hash ("tag" tagj) ("value" valj)))
      .<-json: (lambda (j)
                 (def tag (string->symbol (hash-ref j "tag")))
                 (make tag (<-json (.ref variants tag) (hash-ref j "value"))))
      .marshal: (lambda (v port)
                  (def tag (.@ v tag))
                  (def tag-n (.ref variant-indices tag))
                  (marshal tag-marsh-t tag-n port)
                  (marshal (.ref variants tag) (.@ v value) port))
      .unmarshal: (lambda (port)
                    (def tag-n (unmarshal tag-marsh-t port))
                    (def tag (vector-ref variant-names@ tag-n))
                    (def value (unmarshal (.ref variants tag) port))
                    (make tag value))})

(begin-syntax
  (def ((sum-constructor-match-transformer tag-sym) stx)
    (syntax-case stx ()
      ((_ p) (with-syntax ((tag* tag-sym)) #'(.o tag: 'tag* value: p)))))
  (def ((sum-constructor-expr-transformer sum-id tag-sym) stx)
    (syntax-case stx ()
      ((_ e) (with-syntax ((sum sum-id) (tag* tag-sym)) #'(.call sum make 'tag* e))))))
(defsyntax (define-sum-constructors stx)
  (syntax-case stx ()
    ((_ sum-id variant-id ...)
     (with-syntax (((sum-variant-id ...)
                    (stx-map (lambda (variant)
                               (stx-identifier #'sum-id #'sum-id "-" variant))
                             #'(variant-id ...))))
       #'(begin
           (defsyntax-for-match sum-variant-id
             (sum-constructor-match-transformer 'variant-id)
             (sum-constructor-expr-transformer #'sum-id 'variant-id))
           ...)))))
