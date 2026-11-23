;;; Common declarations and methods for tables

(export methods.table Set<-Table. PreZipping. Zipping. FocusableZipping.
        with-set-tables fold-set/shared-backing iterator-map table-element? validate-table table-for-each-change table-styles set-styles table-indexes
        table-comparer table-comparer-wrapper table-order table-ordered-cursor
        table-key-space table-index-conflict? table-index-conflict-name table-index-conflict-key
        table-index-conflict-existing table-index-conflict-incoming
        table-delta? table-delta-count invert-table-delta table-isomorphism table-fold table-group-fold table-projection table-group-join table-lookup-join set-image set-combination table-combination table-wrapper
        table-projection-compose
        table-isomorphism-failure? table-isomorphism-failure-kind table-isomorphism-failure-value
        table-conflict? table-conflict-key)

(import
  (only-in ./types/variant-validation validate-bindings rebuild-bindings)
  (only-in ./slot-observation %slot-read-active?)
  (only-in :gerbil/runtime/thread with-lock)
  :std/interface
  :std/iter
  (only-in :std/list/list-builder with-list-builder)
  (only-in :std/list/list delete-duplicates/hash append-map find)
  (only-in :std/list/alist acons)
  (only-in :std/func compose)
  (only-in :std/number/misc uint?)
  (only-in ./support/option some some? option-ref option-get/default map/option some-value)
  (only-in ./brace @method @@method)
  (only-in ./io marshal)
  (only-in ./mop/prototype define-type Type. Function. Any validate element? raise-type-error TypeError? Lens lens-of-get-set)
  (only-in ./fun Wrapper. Wrap.)
  (only-in ./types/function-signature signature-shape?)
  (only-in ./object .o object<-alist .all-slots .@ .ref .slot? .call .cc .mix .has? object-revision active-object-constructions instantiate-object!)
  (only-in ./type List Pair Sum Unit Bool))

(defstruct %mapped-iterator (source transform guard) final: #t)
;; Pull through the standard Iterator exactly once; preserve EOF without mapping it.
(def (%mapped-next source transform)
  (using (source :- Iterator)
    (def value (source.next!))
    (if (eq? value #!eof) #!eof (transform value))))
(implement Iterator %mapped-iterator
  (next! (lambda (self)
    (if self.guard (self.guard (lambda () (%mapped-next self.source self.transform)))
      (%mapped-next self.source self.transform)))))

;; Optional guards cover the complete pull, even EOF. Ordinary iterator mapping
;; keeps its original unguarded path and allocates no per-pull guard thunk.
(def (iterator-map transform source (guard #f))
  (Iterator (%mapped-iterator (iter source) transform guard)))

;; Persistent seek backends admit roots by identity. Point-update outputs may be
;; recorded only under the explicit .shape-preserving? law, after an admitted input
;; and Key. Weak keys retain no snapshots; failures and arbitrary inputs never gain
;; provenance. Callers guard metadata before either admission or output recording.
(def (table-shape-checker source)
  (if (.has? source Comparer .seek<-)
    (let ((admitted (make-table test: eq? weak-keys: #t))
          (preserves? (and (.has? source .shape-preserving?) (eq? (.@ source .shape-preserving?) #t))))
      (lambda (root (updated? #f))
        (cond
          (updated? (when preserves? (table-set! admitted root #t)))
          ((not (table-ref admitted root #f))
            (.call source .validate-shape root)
            (table-set! admitted root #t))) root))
    (lambda (root (updated? #f)) (if updated? root (.call source .validate-shape root)))))

;; Recognize carrier and child membership without constructing normalized wrappers.
;; Catch only typed refusal; user/backend exceptions preserve their original cause.
(def (table-element? descriptor source)
  (try
    (.call descriptor .validate-shape source)
    ;; Recognition must not reenter the public query's complete-root admission.
    (not (table-entry-match descriptor
      (lambda (key value)
        (and (element? (.@ descriptor Key) key) (element? (.@ descriptor Value) value))) source #f #f))
    (catch (TypeError? _) #f)))

;; Validate a persistent table through its current public representation protocol.
;; Admit the carrier, normalize children, then privately rebuild and recognize the result.
(def (validate-table descriptor source (normalize #f))
  (with-table-sources (table-sources descriptor) (lambda ()
    (.call descriptor .validate-shape source)
    ;; Same-child-Type views may supply a complete source normalization. The
    ;; shared boundary still owns receiver refinements and metadata protection.
    ;; Ordinary backends retain their original child and collision/error order.
    (require-table descriptor
      (if normalize (normalize source)
        (let* ((key (.@ descriptor Key)) (value (.@ descriptor Value)))
          (validate-bindings (cut validate key <>) (cut validate value <>) source
            (.call descriptor .list<- source)
            (lambda (checked)
              (rebuild-bindings descriptor source checked (lambda () (.@ descriptor .empty))
                (.@ descriptor .key?) (.@ descriptor .acons))))))))))

;; Share whole-source normalization only when both child Type identities match.
;; An inherited view with overridden Types retains the ordinary validator instead
;; of assuming that two unrelated normalization functions commute.
(def (table-view-validator descriptor source normalize)
  (cut validate-table descriptor <>
    (and (eq? (.@ descriptor Key) (.@ source Key))
         (eq? (.@ descriptor Value) (.@ source Value)) normalize)))

(include "table/delta.ss")

(include "table/fold.ss")

(include "table/translation.ss")

(include "table/protocol.ss")

;; Set presentation and algebra remain in the existing table module.
(include "table/sets.ss")
(include "table/io.ss")

(define-type (PreZipping. @ [Type.]
  ;; StepF :: Type <- Type
  ;; PathF :: Type <- Type
  .path-step ;; (OrFalse (Pair (StepF a) (PathF a))) <- (PathF a)
  .step-down)) ;; (PathF a) <- (StepF a) (PathF a)

(define-type (Zipping. @ [PreZipping.]
  ;; Zipper = (Pair Node (PathF Node))
  .zipper<- ;; Zipper <- T
  .<-top-zipper ;; T <- Zipper
  .stepUp)) ;; node <- (StepF Node) Node

(define-type (FocusableZipping. @ [Zipping.]
  .refocus)) ;; Zipper <- FocusKey Zipper

(include "table/focus.ss")
(include "table/observation.ss")
(include "table/mapping.ss")

;; Derive style ownership in the existing interface; .admit normalizes raw input,
;; whereas .ap and transitions retain admitted Function wrappers and batch ordering.
(include "table/styles.ss")

;; Correlated indexes share the same public table namespace and backend contracts.
(include "table/indexes.ss")

(include "table/order.ss")
