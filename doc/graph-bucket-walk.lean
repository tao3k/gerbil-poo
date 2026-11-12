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

#print axioms walk_append
#print axioms masked_exact
#print axioms streaming_exact
end GraphBucketWalk
