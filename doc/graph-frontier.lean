import Std

namespace GraphFrontier

-- Observable predicate state includes counters/trace and the first refusal.
abbrev Predicate (A S E : Type) := A → S → Except (E × S) (Bool × S)

def select (pred : Predicate A S E) : List A → S → Except (E × S) (List A × S)
  | [], state => .ok ([], state)
  | key :: rest, state => match pred key state with
      | .error error => .error error
      | .ok (keep, next) => match select pred rest next with
          | .error error => .error error
          | .ok (selected, final) => .ok (if keep then key :: selected else selected, final)

def accumulate (pred : Predicate A S E) : List A → List A → S → Except (E × S) (List A × S)
  | [], reversed, state => .ok (reversed, state)
  | key :: rest, reversed, state => match pred key state with
      | .error error => .error error
      | .ok (keep, next) => accumulate pred rest (if keep then key :: reversed else reversed) next

def finish (tail : List A) (result : Except (E × S) (List A × S)) :=
  Except.map (fun (reversed, state) => (reversed.reverse ++ tail, state)) result

theorem accumulator_exact (pred : Predicate A S E) (row reversed : List A) (state : S) :
    accumulate pred row reversed state =
      Except.map (fun (selected, final) => (selected.reverse ++ reversed, final))
        (select pred row state) := by
  induction row generalizing reversed state with
  | nil => rfl
  | cons key rest ih =>
    simp only [accumulate, select]
    cases hp : pred key state with
    | error error => rfl
    | ok pair =>
      rcases pair with ⟨keep, next⟩
      dsimp only
      rw [ih]
      cases hs : select pred rest next with
      | error error => rfl
      | ok pair =>
        rcases pair with ⟨selected, final⟩
        cases keep <;> simp [Except.map, List.reverse_cons, List.append_assoc]

theorem frontier_exact (pred : Predicate A S E) (row tail : List A) (state : S) :
    finish tail (accumulate pred row [] state) =
      Except.map (fun (selected, final) => (selected ++ tail, final))
        (select pred row state) := by
  rw [accumulator_exact]
  cases h : select pred row state with
  | error error => rfl
  | ok pair =>
    rcases pair with ⟨selected, final⟩
    dsimp [finish, Except.map]
    simp

#print axioms accumulator_exact
#print axioms frontier_exact
end GraphFrontier
