;;; Gerbil v0.19 typed-kernel, nullable contract, Record/ClassType/InterfaceType bridge,
;;; and subclassability checks.
(export typed-kernel-test)
(import :std/test :std/error
        (only-in :gerbil/runtime/hash HashTable::interface)
        :clan/poo/object :clan/poo/object/slot-layout
        :clan/poo/object/prototype-map :clan/poo/object/state
        :clan/poo/support/option :clan/poo/support/rationaldict
        :clan/poo/type
        :clan/poo/number
        (only-in :clan/poo/types/object-contract ObjectContract. diagnose))

;; Downstream Yuanxu extends $computed-slot-spec for source-located slots.
;; Keep $computed-slot-spec non-final and verify subclassing stays valid.
(defstruct (test-located-slot $computed-slot-spec) (location) final: #t)

;; Sealed v0.19 struct used to verify ClassType + Record integration.
(defstruct kernel-point (x y) transparent: #t final: #t)

(def typed-kernel-test
  (test-suite "Gerbil v0.19 typed-kernel contracts, nullables, and type bridge"
    (test-case "nullable layout and state boundaries accept #f and reject foreign values"
      (def base (make-slot-layout '(a b) #f absent-value))
      (def st (make-object-state))
      (def derived (make-slot-layout '(a b c) #f absent-value previous: base state: st))
      (check-equal? (slot-layout-index derived 'a) 0)
      (check-equal? (slot-layout-index derived 'missing) #f)
      (check-exception (make-slot-layout '(a) #f absent-value previous: 42) contract-violation-error?)
      (check-exception (make-slot-layout '(a) #f absent-value state: 'bad) contract-violation-error?)
      (check-exception (make-slot-values '(a) #f '() absent-value previous: "bad") contract-violation-error?)
      (check-exception (make-slot-values '(a) #f '() absent-value state: 99) contract-violation-error?)
      (check-eq? (slot-values-layout (make-hash-table-symbolic)) #f)
      (check (layout? (slot-values-layout (make-slot-values '(a) #f '() absent-value))) => #t))

    (test-case "slot-cache nullable layout and access-cache contracts"
      (def owner (.o a: 10 b: 20))
      (def site (make-slot-cache 'a shapes: 2))
      (check-eq? (slot-cache-layout site) #f)
      (check-eq? (slot-cache-hit? site owner (object-revision owner) #f) #f)
      (check-eq? (slot-cache-hit? site owner (object-revision owner) 'not-a-layout) #f)
      (check-equal? (.ref/inline owner site) 10)
      (check (layout? (slot-cache-layout site)) => #t)
      (check (fixnum? (slot-cache-hit? site owner (object-revision owner) (object-%layout owner))) => #t)
      (check-eq? (slot-cache-hit? site owner (object-revision owner) 'not-a-layout) #f)
      (check-exception (slot-cache-hit? 'not-a-cache owner 0 #f) contract-violation-error?)
      (check-exception (slot-cache-layout 'not-a-cache) contract-violation-error?)
      (check-exception (slot-cache-offset 'not-a-cache (object-%layout owner)) contract-violation-error?))

    (test-case "prototype-map and rationaldict typed boundary contracts"
      (def pm (prototype-map '((a . 1) (b . 2)) policy: 'compact))
      (check-eq? (prototype-map-policy pm) 'compact)
      (check-equal? (prototype-map-ref pm 'a) 1)
      (check-equal? (prototype-map-ref pm 'z 'none) 'none)
      (check-exception (prototype-map-policy 'bad) contract-violation-error?)
      (check-exception (prototype-map-keys 'bad) contract-violation-error?)
      (check-exception (prototype-map-list 'bad) contract-violation-error?)
      (check-exception (prototype-map-remove 'bad 'a) contract-violation-error?)
      (check-exception (prototype-map-filter 'bad (lambda (_k _v) #t)) contract-violation-error?)
      (def rd (list->rationaldict '((1 . one) (2 . two))))
      (check-eq? (rationaldict-empty? rd) #f)
      (check-eq? (rationaldict-ref rd 2) 'two)
      (check-eq? (rationaldict-has-key? rd 3) #f)
      (check-exception (rationaldict-empty? 'bad) contract-violation-error?)
      (check-exception (rationaldict-ref 'bad 1) contract-violation-error?)
      (check-exception (rationaldict-put 'bad 1 'x) contract-violation-error?)
      (check-exception (rationaldict-remove 'bad 1) contract-violation-error?)
      (check-exception (rationaldict-has-key? 'bad 1) contract-violation-error?))

    (test-case "object protocol nullable path, safe invalid-receiver refusal, and $computed-slot-spec subclassability"
      (def plain (.o x: 1))
      (instantiate-object! plain)
      (check-eq? (object-protocol plain) #f)
      (check-exception (object-revision #f) RuntimeException?)
      (def proto (.o))
      (def with-proto (make-object slots: (list (cons 'x ($constant-slot-spec 2))) protocol: proto))
      (instantiate-object! with-proto)
      (check-eq? (object-protocol with-proto) proto)
      ;; Subclassing $computed-slot-spec remains supported for downstream consumers.
      (def loc-spec (make-test-located-slot (lambda (_self _super) 99) "test.ss:1"))
      (check ($computed-slot-spec? loc-spec) => #t)
      (check-equal? (test-located-slot-location loc-spec) "test.ss:1")
      (def loc-obj (make-object slots: (list (cons 'v loc-spec))))
      (check-equal? (.ref loc-obj 'v) 99))

    (test-case "ClassType, InterfaceType, Nullable, Record, and .gerbil-type bidirectional bridge"
      (def PointT (ClassType kernel-point::t))
      (def HashT (InterfaceType HashTable::interface))
      (def MaybeStrT (Nullable String))
      (def pt (make-kernel-point 3 4))
      (def ht (make-hash-table-eq))
      (check (element? Type PointT) => #t)
      (check (element? Type HashT) => #t)
      (check (element? Type MaybeStrT) => #t)
      (check (.@ PointT final?) => #t)
      (check-equal? (.@ PointT slots) '(x y))
      (check-eq? (type-gerbil-descriptor PointT) kernel-point::t)
      (check-eq? (type-gerbil-descriptor HashT) HashTable::interface)
      (check-equal? (type-gerbil-descriptor MaybeStrT) (list 'nullable string::t))
      (check-eq? (type-gerbil-descriptor String) string::t)
      (check-eq? (type-gerbil-descriptor Symbol) symbol::t)
      (check-eq? (type-gerbil-descriptor Keyword) keyword::t)
      (check-eq? (type-gerbil-descriptor Bytes) u8vector::t)
      (check-eq? (type-gerbil-descriptor Bool) boolean::t)
      (check-eq? (type-gerbil-descriptor (List String)) list::t)
      (check-eq? (type-gerbil-descriptor (Tuple String Bool)) vector::t)
      (check-eq? (type-gerbil-descriptor (Pair Symbol String)) pair::t)
      (check-eq? (type-gerbil-descriptor (Map Symbol -> String)) HashTable::interface)
      (check-eq? (type-gerbil-descriptor Object) object::t)
      (check-eq? (type-gerbil-descriptor ObjectContract.) object::t)
      (check-eq? (type-gerbil-descriptor Number) number::t)
      (check-eq? (type-gerbil-descriptor Real) real::t)
      (check-eq? (type-gerbil-descriptor Integer) integer::t)
      (check-eq? (type-gerbil-descriptor UInt) integer::t)
      (check-eq? (type-gerbil-descriptor Float) flonum::t)
      (check-eq? (type-gerbil-descriptor Null) null::t)
      (check-eq? (type-gerbil-descriptor Unit) void::t)
      (check-eq? (type-gerbil-descriptor (Sum ok: String err: Symbol)) object::t)
      (check (element? PointT pt) => #t)
      (check (element? PointT '(3 4)) => #f)
      (check-eq? (validate PointT pt) pt)
      (check-exception (validate PointT 'bad) TypeError?)
      (check-equal? (length (diagnose PointT 'bad '(origin))) 1)
      (check (element? HashT ht) => #t)
      (check (element? HashT 42) => #f)
      (check-eq? (validate HashT ht) ht)
      (check-exception (validate HashT 42) TypeError?)
      (check (memq 'ref (.@ HashT methods)) ? pair?)
      (check (element? MaybeStrT #f) => #t)
      (check (element? MaybeStrT "ok") => #t)
      (check (element? MaybeStrT 123) => #f)
      (check-exception (ClassType 'not-a-class) contract-violation-error?)
      (check-exception (InterfaceType 'not-an-interface) contract-violation-error?)
      ;; Open POO Record seamlessly composes ClassType, InterfaceType, and Nullable fields.
      (def NodeRecord
        (Record origin: [PointT]
                index: [HashT]
                label: [MaybeStrT default: #f]))
      (check-eq? (type-gerbil-descriptor NodeRecord) object::t)
      (check (pair? (.@ NodeRecord sexp)) => #t)
      (def valid-node (.o origin: pt index: ht label: #f))
      (check (element? NodeRecord valid-node) => #t)
      (check-eq? (.@ (validate NodeRecord valid-node) origin) pt)
      (check (element? NodeRecord (.o origin: 'bad index: ht label: "x")) => #f)
      (check-exception (Record bad: ['not-a-type]) TypeError?)
      ;; Reverse direction: POO Record / Type -> Gerbil v0.19 `:~` contract predicate.
      (def node? (type-predicate NodeRecord))
      (def check-node (type-contract-validator NodeRecord))
      (check-eq? (using (n valid-node :~ node?) (.@ n origin)) pt)
      (check-exception (using (n (.o origin: 'bad index: ht) :~ node?) n) contract-violation-error?)
      (check-eq? (.@ (check-node valid-node) origin) pt)
      (check-exception (type-predicate 'not-a-type) TypeError?))))
