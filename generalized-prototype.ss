;;; Generalized prototype hooks advance Appendix B's explicitly deferred future work.
(export Protocol. Prepared? prepare prepare-inheritance prepared-protocol prepared-fragments
        lens-compiler sum-compiler reindex-self assemble step approximate observe observation-action Observation.)
(import (only-in :std/list/list foldr) ./object (only-in ./mop define-type)
        (prefix-in ./fun fun.))
;; Public immutable-in-practice descriptor: compile returns (delayed self, delayed
;; raw parent) -> raw. Cook is the sole raw -> public interface boundary.
(define-type (Protocol. @ [] cook compile))
;; Private compiled snapshot, owned by its exact protocol; callbacks and captured
;; declarations must remain immutable/pure. No global cache or serialized receipt.
(defstruct prepared (protocol fragments program) final: #t)
;; Recognize only snapshots made by prepare; this is provenance, not a proof seal.
(def Prepared? prepared?)
;; Read the protocol that owns this compiled snapshot.
;; Read the most-specific-first immutable fragment list captured at preparation.
;; Appendix B lens-gen, matching Lean lensCompiler: getter remains delayed until
;; the wrapper needs inherited data; setter receives replacement then original raw.
(def (lens-compiler getter setter wrapper)
  (lambda (fragment)
    (lambda (self parent)
      (def raw (parent))
      (setter (wrapper fragment self (lambda () (getter raw))) raw))))
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
  (make-prepared protocol fragments (assemble protocol fragments)))
;; Reuse native checked C4/C3 precedence, including its cycle/inconsistency errors.
;; Declaration callback returns local fragments only; a diamond ancestor occurs once.
;; Mutating graph/declarations/protocol requires a fresh preparation.
(def (prepare-inheritance protocol root declarations)
  (def precedence (compute-precedence-list! root))
  (prepare protocol (apply append (map declarations precedence))))
;; Cook final self lazily and keep raw parent delayed, exactly as Lean Protocol.step.
(def (step snapshot final base)
  ((prepared-program snapshot)
    (lambda () ((.@ (prepared-protocol snapshot) cook) final)) (lambda () base)))
;; Finite self-depth observation; zero returns seed without executing any compiler.
;; This does not assert termination of arbitrary callbacks or fixed-point closure.
(def (approximate snapshot base seed depth)
  (unless (and (exact-integer? depth) (>= depth 0)) (error "invalid observation depth"))
  (let loop ((remaining depth) (raw seed))
    (if (zero? remaining) raw (loop (- remaining 1) (step snapshot raw base)))))
;; Expose the cooked boundary only after the requested finite raw approximation.
(def (observe snapshot base seed depth)
  ((.@ (prepared-protocol snapshot) cook) (approximate snapshot base seed depth)))
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
(def (observation-action snapshot base depth) (lambda (seed) (observe snapshot base seed depth)))
