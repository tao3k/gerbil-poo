import Std

namespace GraphRoster
variable {K : Type} [DecidableEq K]

-- K is the already validated symbol-identity domain. This algorithm does not
-- replace proper-list/symbol validation, constructor effects or author checks.
abbrev Membership (K : Type) := K → Bool
def empty : Membership K := fun _ => false
def mark (seen : Membership K) (key : K) : Membership K :=
  fun query => if query = key then true else seen query

-- Current first-occurrence normalization, followed by a separate support pass.
def firsts : List K → Membership K → List K
  | [], _ => []
  | key :: rest, seen =>
      if seen key then firsts rest seen else key :: firsts rest (mark seen key)

def twoPass (keys : List K) : List K × Membership K :=
  let names := firsts keys empty
  (names, fun query => decide (query ∈ names))

-- Proposed one-pass state transition, returning BOTH admitted observations.
def admit : List K → Membership K → List K × Membership K
  | [], seen => ([], seen)
  | key :: rest, seen =>
      if seen key then admit rest seen
      else let next := admit rest (mark seen key)
           (key :: next.1, next.2)

theorem same_order (keys : List K) (seen : Membership K) :
    (admit keys seen).1 = firsts keys seen := by
  induction keys generalizing seen with
  | nil => rfl
  | cons key rest ih =>
    cases h : seen key <;> simp [admit, firsts, h, ih]

theorem final_membership (keys : List K) (seen : Membership K) (query : K) :
    (admit keys seen).2 query = (seen query || decide (query ∈ keys)) := by
  induction keys generalizing seen with
  | nil => simp [admit]
  | cons key rest ih =>
    by_cases eq : query = key
    · subst query
      cases h : seen key <;> simp [admit, mark, h, ih]
    · cases h : seen key <;> simp [admit, mark, h, ih, eq]

theorem firsts_membership (keys : List K) (seen : Membership K) (query : K) :
    query ∈ firsts keys seen ↔ query ∈ keys ∧ seen query = false := by
  induction keys generalizing seen with
  | nil => simp [firsts]
  | cons key rest ih =>
    by_cases eq : query = key
    · subst query
      cases h : seen key <;> simp [firsts, mark, h, ih]
    · cases h : seen key <;> simp [firsts, mark, h, ih, eq]

theorem firsts_unique (keys : List K) (seen : Membership K) :
    (firsts keys seen).Nodup := by
  induction keys generalizing seen with
  | nil => simp [firsts]
  | cons key rest ih =>
    cases h : seen key
    · simp only [firsts, h, Bool.false_eq_true, ↓reduceIte, List.nodup_cons]
      constructor
      · simp [firsts_membership, mark]
      · exact ih _
    · simpa [firsts, h] using ih seen

theorem one_pass_exact (keys : List K) : admit keys empty = twoPass keys := by
  apply Prod.ext
  · exact same_order keys empty
  · funext query
    rw [final_membership]
    simp only [empty, Bool.false_or, twoPass]
    congr 1
    exact propext (firsts_membership keys empty query |>.trans (by simp [empty])) |>.symm

-- Validation stays before normalization. Its error payload is opaque here:
-- this theorem cannot authorize a different native validator or refusal order.
def checked {E : Type} (normalize : List K → List K × Membership K)
    (validated : Except E (List K)) : Except E (List K × Membership K) :=
  validated.map normalize

theorem checked_exact {E : Type} (validated : Except E (List K)) :
    checked (fun keys => admit keys empty) validated =
      checked twoPass validated := by
  cases validated with
  | error reason => rfl
  | ok keys => simp [checked, one_pass_exact]

-- A downstream computation may inspect order and membership, or fail. Equal
-- inputs preserve it, provided effectful construction/checks stay external.
theorem continuation_exact {E R : Type} (validated : Except E (List K))
    (next : Except E (List K × Membership K) → R) :
    next (checked (fun keys => admit keys empty) validated) =
      next (checked twoPass validated) := by
  rw [checked_exact]

-- Persistent mathematical state never alters an older membership function.
-- Scheme's mutable-table implementation still owes a separate ownership proof.
theorem mark_other (seen : Membership K) (key query : K) (different : query ≠ key) :
    mark seen key query = seen query := by
  simp [mark, different]

-- Matching the returned roster is insufficient if native constructors expose
-- different effects. Trace equality is an explicit, necessary obligation.
theorem with_trace_exact {Event : Type} (keys : List K)
    (oldTrace newTrace : List Event) (effects : newTrace = oldTrace) :
    (admit keys empty, newTrace) = (twoPass keys, oldTrace) := by
  rw [one_pass_exact, effects]

theorem trace_mismatch_rejects {Event : Type} (keys : List K)
    (oldTrace newTrace : List Event) (different : newTrace ≠ oldTrace) :
    (admit keys empty, newTrace) ≠ (twoPass keys, oldTrace) := by
  intro equal
  exact different (congrArg Prod.snd equal)

#print axioms same_order
#print axioms final_membership
#print axioms firsts_membership
#print axioms firsts_unique
#print axioms one_pass_exact
#print axioms checked_exact
#print axioms continuation_exact
#print axioms mark_other
#print axioms with_trace_exact
#print axioms trace_mismatch_rejects
end GraphRoster
