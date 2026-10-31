;;; Generalized prototype hooks advance Appendix B's explicitly deferred future work.
(export Protocol. Prepared? prepare prepare-inheritance prepared-protocol prepared-fragments
        lens-compiler focus-compiler focus-protocol prepare-focused prepare-focused-inheritance sum-compiler reindex-self cook-fields bind-observer bind-context-observer
        assemble step approximate observe observation-action)
(import (only-in :std/list/list foldr delete-duplicates/hash) ./object (only-in ./mop define-type))
;; Public immutable-in-practice descriptor: compile returns (delayed self, delayed
;; raw parent) -> raw. Cook is the sole raw -> public interface boundary.
(define-type (Protocol. @ [] cook compile))
;; Private compiled snapshot, owned by its exact protocol; callbacks and captured
;; declarations must remain immutable/pure. No global cache or serialized receipt.
(defstruct prepared (protocol fragments program cook) final: #t)
;; Recognize only snapshots made by prepare; this is provenance, not a proof seal.
(def Prepared? prepared?)
;; Generated read-only selectors expose the owning protocol and ordered fragments.
;; Appendix B lens-gen, matching Lean lensCompiler: getter remains delayed until
;; the wrapper needs inherited data; setter receives replacement then original raw.
(def (lens-compiler getter setter wrapper)
  (lambda (fragment)
    (lambda (self parent)
      (def raw (parent))
      (setter (wrapper fragment self (lambda () (getter raw))) raw))))
;; Adapt the existing native Lens protocol, including nested Lens.compose, without
;; introducing a second lens representation or redoing method lookup per fragment.
(def (focus-compiler lens wrapper)
  (lens-compiler (.@ lens .get) (.@ lens .set) wrapper))
;; Tag fragment families with (left . fragment)/(right . fragment), sharing raw/self.
(def (sum-compiler left right)
  (lambda (fragment)
    (case (car fragment)
      ((left) (left (cdr fragment))) ((right) (right (cdr fragment)))
      (else (error "unknown generalized fragment family" (car fragment))))))
;; Adapt the public self interface. Equal observations require the caller's law
;; view(cook(raw)) = old-cook(raw); arbitrary functions do not establish that law.
(def (reindex-self protocol view cook)
  (def compiler (.@ protocol compile))
  (.cc Protocol. cook: cook compile: (lambda (fragment)
    (def compiled (compiler fragment))
    (lambda (self parent) (compiled (lambda () (view (self))) parent)))))
;; Compile each fragment once, then compose delayed inheritance with standard foldr.
;; Unlike strict raw folding, a wrapper may ignore its inherited suffix completely.
(def (assemble protocol fragments)
  (foldr (lambda (compiled rest)
    (lambda (self parent) (compiled self (lambda () (rest self parent)))))
    (lambda (_ parent) (parent)) (map (.@ protocol compile) fragments)))
;; Capture the exact compiler and ordered declarations without running method bodies.
(def (prepare protocol fragments)
  (make-prepared protocol fragments (assemble protocol fragments) (.@ protocol cook)))
;; Capture native checked C4/C3 declarations once, retaining its exact order/errors.
(def (inheritance-fragments root declarations)
  (apply append (map declarations (compute-precedence-list! root))))
;; Reuse checked inheritance for the general per-fragment construction path.
;; Mutating graph/declarations/protocol requires fresh immutable source preparation.
(def (prepare-inheritance protocol root declarations)
  (prepare protocol (inheritance-fragments root declarations)))
;; Lift one complete delayed local program into a surrounding raw focus. Getter,
;; setter and public-self projection are captured once, not looked up per fragment.
(def (focus-program focus view program)
  (def getter (.@ focus .get)) (def setter (.@ focus .set))
  (lambda (self parent)
    (def raw (parent))
    (setter (program (lambda () (view (self))) (lambda () (getter raw))) raw)))
;; Reference semantics of a focused protocol: each local fragment updates the
;; outer carrier. Callbacks must not inspect allocation identity or raw ancestry.
(def (focus-protocol protocol focus view cook)
  (def compiler (.@ protocol compile))
  (.cc Protocol. cook: cook compile:
    (lambda (fragment) (focus-program focus view (compiler fragment)))))
;; Compose LOCAL fragments first and write the outer focus once per stage.
;; Explicit opt-in requires pure extensional callbacks and get-put/put-get/put-put
;; lens laws. Raw identities, inheritance ancestry and arbitrary effects are NOT
;; preserved. Empty fragments retain the exact parent without calling the lens.
(def (prepare-focused protocol focus view cook fragments)
  (def outer (focus-protocol protocol focus view cook))
  (def program (if (null? fragments) (lambda (_ parent) (parent))
    (focus-program focus view (assemble protocol fragments))))
  (make-prepared outer fragments program cook))
;; Checked inheritance and focused assembly compose without a second C3 engine.
(def (prepare-focused-inheritance protocol focus view cook root declarations)
  (prepare-focused protocol focus view cook (inheritance-fragments root declarations)))
;; Construct a callable cooked interface from named raw -> field preparations.
;; Standard promises share only demanded fields, including #f results. No method
;; preparation runs here; exceptions in an unused field remain unobserved. This
;; transformation requires pure/extensional preparations for reference equivalence.
(def (cook-fields fields)
  (unless (and (list? fields)
      (andmap (lambda (field) (and (pair? field) (symbol? (car field)) (procedure? (cdr field)))) fields)
      (= (length fields) (length (delete-duplicates/hash (map car fields)))))
    (error "distinct named cooking callbacks required"))
  (lambda (raw)
    (def delayed (map (lambda (field) (cons (car field) (delay ((cdr field) raw)))) fields))
    (lambda (slot)
      (def found (assq slot delayed))
      (unless found (error "unknown cooked field" slot))
      (force (cdr found)))))
;; Bind one step to captured compiler/cook callbacks. Native delay/force shares
;; cooked self across all method demands within that raw stage; never across seeds.
;; Local purity is required; this does not preserve arbitrary callback side effects.
(def (bound-step program cook final base)
  (def cooked (delay (cook final)))
  (program (lambda () (force cooked)) (lambda () base)))
;; One public step uses the exact immutable callbacks captured during preparation.
(def (step snapshot final base)
  (bound-step (prepared-program snapshot) (prepared-cook snapshot) final base))
;; Validate finite self-depth once at the binding boundary, including zero.
(def (check-depth depth)
  (unless (and (exact-integer? depth) (>= depth 0)) (error "invalid observation depth")))
;; Tail-recursive iteration keeps the prepared program/cook out of descriptor lookup.
;; Zero returns seed; finite depth does not imply arbitrary callback termination.
(def (iterate program cook base seed depth)
  (let loop ((remaining depth) (raw seed))
    (if (zero? remaining) raw (loop (- remaining 1) (bound-step program cook raw base)))))
;; Observe raw state without the final cooked boundary; all updates remain functional.
(def (approximate snapshot base seed depth)
  (check-depth depth)
  (iterate (prepared-program snapshot) (prepared-cook snapshot) base seed depth))
;; Capture snapshot/base/depth once as a native Reader/FUN action. Repeated calls
;; may use DIFFERENT seeds; no observed value or admission is cached by this binder.
(def (bind-observer snapshot base depth)
  (check-depth depth)
  (def program (prepared-program snapshot)) (def cook (prepared-cook snapshot))
  (lambda (seed) (cook (iterate program cook base seed depth))))
;; Capture only the immutable program/cook/depth. Read BOTH base and seed from
;; the CURRENT context on every call, so revisions do not allocate another binder
;; or reuse an old policy/value. Selectors must be pure and source stays immutable.
(def (bind-context-observer snapshot depth context-base context-seed)
  (check-depth depth)
  (def program (prepared-program snapshot)) (def cook (prepared-cook snapshot))
  ;; Native identity selectors need neither captured selector nor two callbacks.
  ;; Specialize only the known standard identity; arbitrary selectors stay general.
  (if (and (eq? context-base identity) (eq? context-seed identity))
    (lambda (raw) (cook (iterate program cook raw raw depth)))
    (lambda (context)
      (cook (iterate program cook (context-base context) (context-seed context) depth)))))
;; One-off observation executes directly; it does not allocate an escaping Reader
;; only to invoke it immediately. The same iterate/cook semantics remain shared.
(def (observe snapshot base seed depth)
  (check-depth depth)
  ((prepared-cook snapshot)
    (iterate (prepared-program snapshot) (prepared-cook snapshot) base seed depth)))
;; Lift one compiled observation into the native FUN composition chain.
(def observation-action bind-observer)
