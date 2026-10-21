;;; Known directory sources invalidate retained Types through the existing graph.
(export catalog-inference-test)
(import :std/test :std/error ../object ../mop ../number ../prototype-types ../type-relation ../method-declaration
        (only-in ../type RecordSlot)
        (only-in ../optional-validation call-with-current-catalogs)
        (only-in ../slot-observation call-with-slot-read-observer slot-read-receiver slot-read-key)
        (prefix-in ../examples/signature-service signature.))
;; Refusal must come from stale bound admission, not an unrelated host exception.
(def (bounds? cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) 'bounds)))
;; One fresh Class directory owns aliases, unused members and an explicit root.
;; Its Slot metadata is deliberately absent from the residual callable signature.
(def (fixture consume)
  (def policy (.o approved: #t))
  (def slot (RecordSlot (Function (list UInt) (list Integer))))
  (def record (.cc Class. slots: (.o callback: slot)))
  (def provider (.o Item: record Alias: record Unused: UInt))
  (def directory (capture-type-catalog provider '(Item Alias Unused) sources: (list policy)))
  (check (eq? (agetq 'Item directory) (agetq 'Alias directory)) => #t)
  (consume provider policy slot (agetq 'Item directory)))
;; All entry paths share existing bound revision checks and the same work quotas.
(def catalog-inference-test
  (test-suite "Retained catalog Type sources and declaration publication"
    (test-case "whole requests reject cross-directory drift even on false or nonunique results"
      (for-each (lambda (request)
        (def first (.o Item: UInt)) (def second (.o Item: UInt))
        (def left (agetq 'Item (capture-type-catalog first '(Item))))
        (def right (agetq 'Item (capture-type-catalog second '(Item))))
        (def changed? #f)
        ;; Later directory delivery revises a previously admitted, independent root.
        (def (observe read)
          (when (and (not changed?) (eq? (slot-read-receiver read) second))
            (set! changed? #t) (.setslot! first Item ($constant-slot-spec Bool))))
        (check-exception (call-with-slot-read-observer observe
          (lambda () (request left right)))
          (lambda (cause) (and (Error? cause) (equal? (error-message cause) "stale slot dependency"))))
        (check-equal? changed? #t))
        (list
          (lambda (left right) (subtype-expression? (list 'Tuple left right) '(Tuple Bool Bool)))
          (lambda (left right) (function-covers? (list 'Function (list left right) '(Integer))
            '(Function (UInt) (Integer Integer))))
          (lambda (left right) (expression-type (list 'Tuple left right)))
          (lambda (left right) (prototype-type (.o .parameters: '(T)) '(T) (list 'Tuple left right) []))
          (lambda (left right) (infer-prototype
            (prototype-type (.o .parameters: '(T)) '(T) 'T [])
            (list left right) '((T UInt))))
          (lambda (left right) (infer-prototype
            (prototype-type (.o .parameters: '(T)) '(T) 'T [])
            '(UInt Bool) (list (list left right))))
          (lambda (left right) (infer-prototype-calls
            (prototype-type (.o .parameters: '(T)) '(T) '(Function (T) (Integer)) [])
            '(UInt Bool) (list (list [] '(Integer) (list (list 'Tuple left right)))))))))
    (test-case "whole declaration frame retains unused candidate directories until publication"
      (def provider (.o Item: UInt))
      (def token (agetq 'Item (capture-type-catalog provider '(Item))))
      (def residual (signature.catalog-service-type 'Bool 'Integer))
      (def queries '((Output UInt) (UInt Output)))
      (def bodies 0) (def staged 0) (def consumed 0) (def subject #f)
      (def context (.o approved: #t))
      ;; The unused candidate does not occur in the selected Type or bound slots.
      (def (stage _instance)
        (set! staged (1+ staged)) (.setslot! provider Item ($constant-slot-spec Bool)))
      (def (operation value) (set! bodies (1+ bodies)) (values (abs value) abs))
      (def (consume value) (set! consumed (1+ consumed)) (set! subject value))
      (def pending (signature.staged-service-action residual (list token 'UInt 'Bool) queries
        operation stage -7 context consume))
      (check-exception (pending context)
        (lambda (cause) (and (Error? cause) (equal? (error-message cause) "stale slot dependency"))))
      (check-equal? staged 1) (check-equal? bodies 0) (check-equal? consumed 0)
      ;; Source effects persist; a fresh directory/request can independently retry.
      (def fresh (agetq 'Item (capture-type-catalog provider '(Item))))
      (def denied (signature.staged-service-action residual (list fresh 'UInt 'Bool) queries
        operation void -7 context consume #f))
      (check-exception (denied context) TypeError?)
      (check-equal? bodies 1) (check-equal? consumed 0)
      (def action (signature.staged-service-action residual (list fresh 'UInt 'Bool) queries
        operation void -7 context consume))
      (defvalues (evidence next issue) (action context))
      (check-equal? issue #f) (check-equal? bodies 2) (check-equal? consumed 1)
      (check-equal? ((.get subject callback) -9) 9)
      (check-exception ((.get subject callback) #f) TypeError?)
      (check (eq? (.get evidence subject) subject) => #t)
      (check (eq? (.get evidence context) context) => #t) (check (eq? next context) => #t))
    (test-case "nested public requests keep independent final checks and original failures"
      (def first (.o Item: UInt)) (def second (.o Item: UInt))
      (def left (agetq 'Item (capture-type-catalog first '(Item))))
      (def right (agetq 'Item (capture-type-catalog second '(Item))))
      (def cause (list 'directory-callback-failed)) (def edited? #f)
      ;; A real callback failure must precede any later success-only stale fence.
      (def (fail read)
        (when (eq? (slot-read-receiver read) second)
          (set! edited? #t) (.setslot! first Item ($constant-slot-spec Bool)) (raise cause)))
      (check (try (call-with-slot-read-observer fail
        (cut subtype-expression? (list 'Tuple left right) '(Tuple Bool Bool))) #f
        (catch (actual) (eq? actual cause))) => #t)
      (check-equal? edited? #t)
      (def renewed (agetq 'Item (capture-type-catalog first '(Item))))
      (def nested? #f) (def nested-refused? #f)
      ;; A nested public request cannot defer its own invalid source until the
      ;; enclosing request returns; its local failure is observable immediately.
      (def (observe read)
        (when (and (not nested?) (eq? (slot-read-receiver read) second))
          (set! nested? #t)
          (set! nested-refused? (try (subtype-expression? left left) #f (catch (_) #t)))))
      (check (call-with-slot-read-observer observe
        (cut subtype-expression? (list 'Tuple renewed right) '(Tuple Bool Bool))) => #f)
      (check-equal? nested-refused? #t)
      ;; Aliases share one directory replay: final checks deliver no extra reads.
      (def observed 0)
      (def (count read) (when (eq? (slot-read-receiver read) second) (set! observed (1+ observed))))
      (def delivered #f)
      (call-with-slot-read-observer count
        (lambda ()
          (call-with-current-catalogs (type-work 8192)
            (lambda ()
              (check (subtype-expression? right right) => #t)
              (set! delivered observed)))))
      (check (> delivered 0) => #t)
      (check-equal? observed delivered))
    (test-case "new Type stamps precede binding getters and later directory compilation"
      (fixture (lambda (_provider policy _slot token)
        (def prototype (.o .parameters: '(Policy Output)))
        (def schema (prototype-type prototype '(Policy Output) '(Function (Output) (Integer)) []))
        (def reads 0)
        ;; The second parameter read occurs after the new Policy Type compiled.
        (def (revise read)
          (when (and (eq? (slot-read-receiver read) prototype) (eq? (slot-read-key read) '.parameters))
            (set! reads (1+ reads))
            (when (= reads 2) (.setslot! policy approved ($constant-slot-spec #f)))))
        (check-exception (call-with-slot-read-observer revise
          (cut specialize-prototype-type schema (list token))) bounds?)
        (check-equal? reads 2)))
      (for-each (lambda (arguments)
        (fixture (lambda (first _policy _slot left)
          (fixture (lambda (second _other-policy _other-slot right)
            (def terms (arguments left right))
            (def names (if (= (length terms) 1) '(Left Output) '(Left Right Output)))
            (def schema (prototype-type (.o .parameters: names) names '(Function (Output) (Integer)) []))
            (def reads 0)
            ;; Test both later parameters and later children of ONE parameter.
            ;; Independent directories share no source admission frame.
            (def (revise read)
              (when (and (eq? (slot-read-receiver read) second) (eq? (slot-read-key read) 'Item))
                (set! reads (1+ reads))
                (when (= reads 2) (.setslot! first Item ($constant-slot-spec Bool)))))
            (check-exception (call-with-slot-read-observer revise
              (cut specialize-prototype-type schema terms)) bounds?)
            (check-equal? reads 2))))))
        (list (lambda (left right) (list (list 'List left) right))
              (lambda (left right) (list (list 'Tuple left right))))))
    (test-case "later argument compilation cannot invalidate the emitted descriptor"
      (fixture (lambda (first _policy _slot left)
        (fixture (lambda (second _other-policy _other-slot right)
          (def schema (prototype-type (.o .parameters: '(T)) '(T)
            (list 'Function (list left) '(Integer)) []))
          (def reads 0)
          ;; The result Type is compiled before the unused parameter's directory.
          (def (revise read)
            (when (and (eq? (slot-read-receiver read) second) (eq? (slot-read-key read) 'Item))
              (set! reads (1+ reads))
              (when (= reads 2) (.setslot! first Item ($constant-slot-spec Bool)))))
          (check-exception (call-with-slot-read-observer revise
            (cut instantiate-prototype schema (list right))) bounds?)
          (check-equal? reads 2))))))
    (test-case "every residual entry rejects revised known directory sources"
      (def builders 0)
      ;; This effect distinguishes early bound refusal from later installation.
      (def (build _) (set! builders (1+ builders)) [])
      (def drivers
        (list bound-parameters
          (cut specialize-prototype-type <> [])
          (cut specialize-prototype-type <> '(UInt))
          (cut instantiate-prototype <> '(UInt))
          (cut infer-prototype <> '(UInt) '((Output UInt) (UInt Output)))
          (cut infer-prototype-calls <> '(UInt) '((() (Integer) (UInt (Function (UInt) (Integer))))))
          (cut instantiate-declared <> '(UInt) build)
          (cut infer-declared <> '(UInt) '((Output UInt) (UInt Output)) build)
          (cut infer-declared-calls <> '(UInt) '((() (Integer) (UInt (Function (UInt) (Integer))))) build)))
      (for-each (lambda (revise)
        (fixture (lambda (provider policy slot token)
          (def residuals (map (lambda (term) (signature.catalog-service-type term 'Integer))
            (list token (list 'List token) (list 'Pair 'UInt token)
              (list 'Function (list token) '(Integer)) (list 'TypeValuePair token))))
          (def stamps (map (lambda (residual)
            (def bound (.get residual prototype Policy))
            (check-equal? (bound-parameters residual) '(Policy Input))
            (cons bound (object-revision bound))) residuals))
          (revise provider policy slot)
          ;; Shared paths and aliases invalidate each direct/composite owner once.
          (for-each (lambda (stamp)
            (check-equal? (object-revision (car stamp)) (1+ (cdr stamp)))) stamps)
          (for-each (lambda (residual)
            (for-each (lambda (request) (check-exception (request residual) bounds?)) drivers)) residuals)
          (check-equal? builders 0))))
        (list
          (lambda (provider _policy _slot) (.setslot! provider Item ($constant-slot-spec Bool)))
          (lambda (provider _policy _slot) (.setslot! provider Unused ($constant-slot-spec Bool)))
          (lambda (_provider policy _slot) (.setslot! policy approved ($constant-slot-spec #f)))
          (lambda (_provider _policy slot) (.setslot! slot type ($constant-slot-spec Bool))))))
    (test-case "unrelated edits retain bindings and source callback failures keep their cause"
      (fixture (lambda (_provider _policy _slot token)
        (def residual (signature.catalog-service-type token 'Integer))
        (def bound (.get residual prototype Policy)) (def revision (object-revision bound))
        (def unrelated (.o value: 1))
        (.setslot! unrelated value ($constant-slot-spec 2))
        (check-equal? (object-revision bound) revision)
        (check-equal? (bound-parameters (instantiate-prototype residual '(UInt))) '(Policy Input Output))))
      (def cause (list 'policy-validator-failed))
      (def custom (.cc Type. .element?: (lambda (_) (raise cause))))
      (def token (agetq 'Policy (capture-type-catalog (.o Policy: custom) '(Policy))))
      (def descriptor (expression-type token))
      (check (try (validate descriptor 7) #f (catch (actual) (eq? actual cause))) => #t))
    (test-case "stale pending publication refuses before effects and fresh directory retries"
      (fixture (lambda (provider policy _slot token)
        (def residual (signature.catalog-service-type token 'Integer))
        (def context (.o approved: #t)) (def bodies 0) (def consumed 0) (def subject #f)
        ;; Both outputs retain recursive Function wrapping after fresh inference.
        (def (operation value) (set! bodies (1+ bodies)) (values (abs value) abs))
        ;; One existing Reader/FUN request selects the output Type in both directions.
        (def (requests _context) '((Output UInt) (UInt Output)))
        ;; The same action constructor supplies both refusal and independent retry.
        (def (action source allowed?)
          (signature.specialized-action source [] '(UInt Bool) requests operation -7 context
            (lambda (value) (set! consumed (1+ consumed)) (set! subject value)) allowed?))
        (def pending (action residual #t))
        (.setslot! policy approved ($constant-slot-spec #f))
        (check-exception (pending context) bounds?)
        (check-equal? bodies 0) (check-equal? consumed 0)
        (def renewed (agetq 'Item (capture-type-catalog provider '(Item Alias Unused) sources: (list policy))))
        (def fresh (signature.catalog-service-type renewed 'Integer))
        (check-exception ((action fresh #f) context) TypeError?)
        (check-equal? bodies 1) (check-equal? consumed 0)
        (defvalues (evidence next issue) ((action fresh #t) context))
        (check-equal? issue #f) (check-equal? bodies 2) (check-equal? consumed 1)
        (check-equal? (.get subject answer) 7)
        (check-equal? ((.get subject callback) -9) 9)
        (check-exception ((.get subject callback) #f) TypeError?)
        (check (eq? (.get evidence subject) subject) => #t)
        (check (eq? (.get evidence context) context) => #t)
        (check (eq? next context) => #t)
        (check-exception (bound-parameters residual) bounds?))))))
