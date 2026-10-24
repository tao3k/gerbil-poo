;;; Finite set algebra is an incremental layer over existing Unit-valued tables.

;; Admit both operands before any merge callback or identity shortcut. Recognition
;; does not normalize Function keys again. Metadata protection covers backend work
;; and all observed Key/Value origins; callback exceptions retain their cause.
(def (with-set-tables table left right action)
  (with-table-sources (table-sources table) (lambda ()
    (unless (eq? (.@ table Value) Unit) (error "set algebra requires Unit values"))
    (require-table table left)
    (require-table table right)
    (action))))

;; Reuse the backend's complete merge algorithm and branch order. Its persistent
;; output is private until complete; a failure never returns a partially built set.
(def (merge-set-tables table choose left right)
  (with-set-tables table left right
    (lambda () (.call table .merge (lambda (_ a b) (choose a b)) left right))))

;; Subset uses the backend's short-circuit traversal and membership primitive.
;; It constructs no merged set and does not compare or rewrap stored elements.
(def (subset-set-tables? table left right)
  (.call table .every (lambda (key _) (.call table .key? right key)) left))

;; Reuse the project Lens constructor and source admission with one typed key.
;; Recognition preserves an already wrapped Function element; it never cooks it.
(def (set-membership-lens table key)
  ;; Both accessors guard the same table origins and refuse invalid element keys.
  (def (observe source action)
    (with-set-tables table source source (lambda ()
      (unless (element? (.@ table Key) key) (raise-type-error (.@ table Key) key))
      (action))))
  (lens-of-get-set
    (lambda (source) (observe source (lambda () (.call table .key? source key))))
    (lambda (present? source)
      (using (present? :~ boolean?)
        (observe source (lambda ()
          (if present? (.call table .acons key (void) source) (.call table .remove source key))))))))

;; Preserve set-specific recognition and declared origins on direct selection,
;; including empty inputs. Table methods own traversal; this only changes arity
;; and admits both returned roots before exposing any result to the caller.
(def (select-set descriptor predicate input split?)
  (using (predicate :~ procedure?)
    (def table (.@ descriptor Table))
    (with-table-sources (append (list descriptor)
      (if (.has? descriptor .sources) (.@ descriptor .sources) []) (table-sources table)) (lambda ()
      (unless (eq? (.@ table Value) Unit) (error "set algebra requires Unit values"))
      (require-table descriptor input)
      (def classify (lambda (element _) (predicate element)))
      (def roots (if split?
        (let-values (((yes no) (.call table .partition classify input))) (list yes no))
        (list (.call table .filter classify input))))
      (for-each (cut require-table descriptor <>) roots)
      (apply values roots)))))

;; Set decomposition protects custom refinements and metadata on both results;
;; only the optional pivot payload is projected to presence, retaining Unit semantics.
(def (split-set descriptor pivot input)
  (def table (.@ descriptor Table))
  (with-table-sources (append (list descriptor)
    (if (.has? descriptor .sources) (.@ descriptor .sources) []) (table-sources table)) (lambda ()
    (with-set-tables table input input (lambda ()
      (require-table descriptor input)
      (defvalues (left found right) (.call table .split pivot input))
      (require-table descriptor left)
      (require-table descriptor right)
      (values left (some? found) right))))))

(define-type (Set<-Table. @ Type. Table sexp)
  ;; Table must be a table from Elt to Unit, i.e. (.@ Table Key) == Elt, (.@ Table Value) == Unit
  Elt: (.@ Table Key) ;; : Type
  .validate: (.@ Table .validate) ;; : @ <- Any
  .element?: (.@ Table .element?) ;; recognition retains the table protocol without normalization
  .empty: (.@ Table .empty)  ;; : @
  .empty?: (.@ Table .empty?) ;; : Bool <- @
  .elt?: (.@ Table .key?) ;; : Bool <- @ Elt
  .cons: (cut .call Table .acons <> (void) <>) ;; : @ <- Elt @
  .singleton: (lambda (elt) (.call Table .singleton elt (void))) ;; : @ <- Elt
  .remove: (.@ Table .remove) ;; : @ <- @ Elt
  .for-each: (lambda (f t) (.call Table .for-each (lambda (e _) (f e)) t)) ;; : Unit <- (Unit <- Elt) @
  .for-each/reverse: (lambda (f t) (.call Table .for-each/reverse (lambda (e _) (f e)) t)) ;; : Unit <- (Unit <- Elt) @
  .foldl: (lambda (f a t) (.call Table .foldl (lambda (e _ a) (f e a)) a t)) ;; : a <- (a <- Elt a)
  .foldr: (lambda (f a t) (.call Table .foldr (lambda (e _ a) (f e a)) a t)) ;; : a <- (a <- Elt a)
  .every: (lambda (f t) (.call Table .every (lambda (e _) (f e)) t)) ;; : Bool <- (Bool <- Elt) @
  .any: (lambda (f t) (.call Table .any (lambda (e _) (f e)) t)) ;; : Bool <- (Bool <- Elt) @
  ;; Checked selection protects custom set refinements as well as backing Types.
  .filter: (lambda (f t) (select-set @ f t #f)) ;; : @ <- (Bool <- Elt) @
  ;; Both branches satisfy the same set descriptor before either escapes.
  .partition: (lambda (f t) (select-set @ f t #t)) ;; : @ @ <- (Bool <- Elt) @
  .count: (.@ Table .count) ;; : Nat <- @
  .list<-: (lambda (t) (map car (.call Table .list<- t))) ;; : (List Elt) <- @
  .<-list: (lambda (l) (foldl .cons .empty l)) ;; : @ <- (List Elt)
  .sexp<-: (lambda (x) `(.call ,sexp .<-list (@list ,@(map (.@ Elt sexp<-) (.list<- x))))) ;; : Sexp <- @
  .min-elt: (lambda (t) (car (.call Table .min-binding t))) ;; : Elt <- @
  .min-elt/opt: (lambda (t) (map/option car (.call Table .min-binding/opt t))) ;; : (Option Elt) <- @
  .max-elt: (lambda (t) (car (.call Table .max-binding t))) ;; : Elt <- @
  .max-elt/opt: (lambda (t) (map/option car (.call Table .max-binding/opt t))) ;; : (Option Elt) <- @
  .choose: .min-elt ;; : Elt <- @
  .choose-opt: .min-elt/opt ;; : (Option Elt) <- @
  ;; Both set roots pass complete admission before the presence observation escapes.
  .split: (lambda (elt t) (split-set @ elt t)) ;; : @ Bool @ <- Elt @
  .find-first/opt: (lambda (f t) (map/option car (.call Table .find-first/opt (lambda (e _) (f e)) t))) ;; : (Option Elt) <- (Bool <- Elt) @
  .find-first: (lambda (f t) (option-ref (.find-first/opt f t))) ;; : Elt <- (Bool <- Elt) @
  .find-last/opt: (lambda (f t) (map/option car (.call Table .find-last/opt (lambda (e _) (f e)) t))) ;; : (Option Elt) <- (Bool <- Elt) @
  .find-last: (lambda (f t) (option-ref (.find-last/opt f t))) ;; : Elt <- (Bool <- Elt) @
  .iter<-: (lambda (t from: (from #f)) ;; : (Iterator Elt) <- @ ?Elt
              (iterator-map car
                            (if (not from)
                              (.call Table .iter<- t)
                              (.call Table .iter<- t from))))
  .<-iter: (lambda (s (t .empty)) (for/fold (t t) (elt s) (.cons elt t))) ;; : @ <- (Iterator Elt) ?@
  .List: (List Elt)
  .json<-: (compose (.@ .List .json<-) .list<-) ;; : Json <- @
  .<-json: (compose .<-list (.@ .List .<-json)) ;; : @ <- Json
  .bytes<-: (compose (.@ .List .bytes<-) .list<-) ;; : Bytes <- @
  .<-bytes: (compose .<-list (.@ .List .<-bytes)) ;; : @ <- Bytes
  .marshal: (lambda (x port) (marshal .List (.list<- x) port))
  .unmarshal: (compose .<-list (.@ .List .unmarshal))
  ;; TODO: for union, inter, diff, compare, equal, subset,
  ;; optimize for full subtables, by caching count in wrapper?
  .union: (lambda (a b) (merge-set-tables Table (lambda (a b) (or a b)) a b)) ;; : @ <- @ @
  .inter: (lambda (a b) (merge-set-tables Table (lambda (a b) (and a b)) a b)) ;; : @ <- @ @
  .diff: (lambda (a b) (merge-set-tables Table (lambda (a b) (and (not b) a)) a b)) ;; : @ <- @ @
  ;; A lexicographic comparison requires the backend's explicit key-order capability.
  .compare: (lambda (a b) (with-set-tables Table a b (lambda ()
    (unless (.has? Table .compare) (error "unsupported set comparison"))
    (.call Table .compare (lambda (_1 _2) 0) a b)))) ;; : : Integer <- @ @
  ;; Symmetric difference preserves the original surviving admitted key objects.
  .symdiff: (lambda (a b) (merge-set-tables Table
    (lambda (a b) (if a (and (not b) a) b)) a b))
  ;; All relations admit both inputs, including the empty and identical cases.
  .subset?: (lambda (a b) (with-set-tables Table a b
    (lambda () (subset-set-tables? Table a b))))
  .disjoint?: (lambda (a b) (with-set-tables Table a b
    (lambda () (.call Table .every (lambda (key _) (not (.call Table .key? b key))) a))))
  ;; Membership equality does not require a backend-specific comparator/equality.
  .=?: (lambda (a b) (with-set-tables Table a b
    (lambda () (and (subset-set-tables? Table a b) (subset-set-tables? Table b a))))) ;; : Bool <- @ @
  ;; Boolean membership focus uses the existing value-before-state Lens law.
  ;; Type refusal and backend failure retain the original persistent source.
  .lens: (lambda (e) (set-membership-lens Table e)))
