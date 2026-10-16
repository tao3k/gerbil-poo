;;; Generalized prototype hooks advance Appendix B's explicitly deferred future work.
(export Protocol. Prepared? prepare prepare-inheritance prepared-protocol prepared-fragments
        lens-compiler focus-compiler sum-compiler reindex-self cook-fields bind-observer
        assemble step approximate observe observation-action Observation.)
(import (only-in :std/list/list foldr delete-duplicates/hash) ./object (only-in ./mop define-type)
        (prefix-in ./fun fun.))
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
;; Reuse native checked C4/C3 precedence, including its cycle/inconsistency errors.
;; Declaration callback returns local fragments only; a diamond ancestor occurs once.
;; Mutating graph/declarations/protocol requires a fresh preparation.
(def (prepare-inheritance protocol root declarations)
  (def precedence (compute-precedence-list! root))
  (prepare protocol (apply append (map declarations precedence))))
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
;; Expose the same cooked boundary for a one-off observation.
(def (observe snapshot base seed depth) ((bind-observer snapshot base depth) seed))
;; Reader/FUN introduction keeps one seed shared by all composed observations.
(def (pure-observation value) (lambda (_) value))
;; Reader bind runs the next observation with the same seed; host errors stop it.
(def (bind-observation action next)
  (lambda (seed) ((next (action seed)) seed)))
;; Map a cooked result without altering the raw seed or forcing another observation.
(def (map-observation transform action)
  (bind-observation action (lambda (value) (pure-observation (transform value)))))
;; Native FUN protocol for observations; no invented I/O interpreter or global state.
(define-type (Observation. @ fun.ParametricFunctor.)
  .ap: pure-observation .bind: bind-observation .map: map-observation)
;; Lift one compiled observation into the native FUN composition chain.
(def observation-action bind-observer)
