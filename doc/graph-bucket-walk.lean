import Std

namespace GraphBucketWalk

-- Failure carries the prefix state too: the model preserves the first refusal
-- and every incident-counter/trace update preceding it, not merely success.
abbrev Step (A S E : Type) := A → S → Except (E × S) S

def walk (step : Step A S E) : List A → S → Except (E × S) S
  | [], state => .ok state
  | key :: rest, state => (step key state).bind (walk step rest)

def maskedWalk (keep : A → Bool) (step : Step A S E) : List A → S → Except (E × S) S
  | [], state => .ok state
  | key :: rest, state =>
      if keep key then (step key state).bind (maskedWalk keep step rest)
      else maskedWalk keep step rest state

theorem walk_append (step : Step A S E) (left right : List A) (state : S) :
    walk step (left ++ right) state =
      (walk step left state).bind (walk step right) := by
  induction left generalizing state with
  | nil => rfl
  | cons key rest ih =>
    simp only [List.cons_append, walk]
    cases h : step key state with
    | error error => rfl
    | ok next => exact ih next

theorem masked_exact (keep : A → Bool) (step : Step A S E) (base : List A) (state : S) :
    maskedWalk keep step base state = walk step (base.filter keep) state := by
  induction base generalizing state with
  | nil => rfl
  | cons key rest ih =>
    cases h : keep key
    · simpa [maskedWalk, List.filter_cons, h] using ih state
    · simp only [maskedWalk, h, ↓reduceIte, List.filter_cons, walk]
      cases step key state with
      | error error => rfl
      | ok next => exact ih next

-- Added owners follow the same ascending tree traversal as foldr cons;
-- retained base owners follow their original order with edited owners masked.
theorem streaming_exact (keep : A → Bool) (step : Step A S E)
    (added base : List A) (state : S) :
    (walk step added state).bind (maskedWalk keep step base) =
      walk step (added ++ base.filter keep) state := by
  rw [walk_append]
  cases walk step added state with
  | error error => rfl
  | ok next => exact masked_exact keep step base next

def searchEdge (accept : A → Bool) : Step A (List A × Nat) Unit :=
  fun key (reversed, edges) =>
    .ok (if accept key then key :: reversed else reversed, edges + 1)

theorem searchRow_exact (accept : A → Bool) (row reversed : List A) (edges : Nat) :
    walk (searchEdge accept) row (reversed, edges) =
      .ok ((row.filter accept).reverse ++ reversed, edges + row.length) := by
  induction row generalizing reversed edges with
  | nil => simp [walk]
  | cons key rest ih =>
    cases hk : accept key <;>
      simp [walk, searchEdge, Except.bind, hk, ih, List.reverse_cons, List.append_assoc,
        Nat.add_assoc, Nat.add_comm 1 rest.length]

def finishSearch (rest : List A) (state : List A × Nat) : List A × Nat :=
  (state.1.reverse ++ rest, state.2)

theorem editedSearch_exact (keep accept : A → Bool) (added base rest : List A) :
    ((walk (searchEdge accept) added ([], 0)).bind
      (maskedWalk keep (searchEdge accept) base)).map (finishSearch rest) =
        .ok (((added ++ base.filter keep).filter accept) ++ rest,
             (added ++ base.filter keep).length) := by
  rw [streaming_exact, searchRow_exact]
  simp [Except.map, finishSearch]

#print axioms walk_append
#print axioms masked_exact

/-- Removing an inserted owner needs a retained mask exactly when the
borrowed row contains that owner. -/
theorem discard_absent_base_mask [DecidableEq A] (owner : A) (base : List A)
    (absent : owner ∉ base) (keep : A → Bool) :
    base.filter (fun key => key != owner && keep key) = base.filter keep := by
  induction base with
  | nil => rfl
  | cons key rest ih =>
    have ne : key ≠ owner := fun h => absent (by simp [h])
    have tail : owner ∉ rest := fun h => absent (by simp [h])
    simp [List.filter_cons, ne, ih tail]

#print axioms discard_absent_base_mask

theorem first_insertion_then_removal_restores_row [DecidableEq A]
    (owner : A) (base : List A) (fresh : owner ∉ base) :
    (owner :: base).filter (fun key => key != owner) = base := by
  simp
  intro key member same
  exact fresh (same ▸ member)

#print axioms first_insertion_then_removal_restores_row
#print axioms streaming_exact
#print axioms editedSearch_exact
end GraphBucketWalk
