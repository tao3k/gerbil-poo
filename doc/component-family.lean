import Std

namespace ComponentFamily
variable {K V S E : Type}

-- A prepared family owns its key sequence. choose may fail or arbitrarily
-- modify caller state, including a caller's original key-list value.
abbrev Choose (K V S E : Type) := K → S → Except E V × S
def capture (choose : Choose K V S E) : List K → S → Except E (List (K × V)) × S
  | [], state => (.ok [], state)
  | key :: rest, state =>
      match choose key state with
      | (.error reason, next) => (.error reason, next)
      | (.ok value, next) =>
          match capture choose rest next with
          | (.error reason, final) => (.error reason, final)
          | (.ok entries, final) => (.ok ((key, value) :: entries), final)

theorem capture_keys (choose : Choose K V S E) (keys : List K) (state : S)
    (entries : List (K × V)) (final : S)
    (accepted : capture choose keys state = (.ok entries, final)) :
    entries.map Prod.fst = keys := by
  induction keys generalizing state entries final with
  | nil =>
    simp only [capture, Prod.mk.injEq, Except.ok.injEq] at accepted
    simp [← accepted.1]
  | cons key rest ih =>
    cases step : choose key state with
    | mk outcome next =>
      cases outcome with
      | error reason => simp [capture, step] at accepted
      | ok value =>
        cases suffix : capture choose rest next with
        | mk result last =>
          cases result with
          | error reason => simp [capture, step, suffix] at accepted
          | ok tail =>
            simp only [capture, step, suffix, Prod.mk.injEq, Except.ok.injEq] at accepted
            rw [← accepted.1]
            simpa using congrArg (List.cons key) (ih next tail last suffix)

variable [DecidableEq K]
def domain (entries : List (K × V)) (key : K) : Bool :=
  decide (key ∈ entries.map Prod.fst)

theorem captured_domain (choose : Choose K V S E) (keys : List K) (state : S)
    (entries : List (K × V)) (final : S)
    (accepted : capture choose keys state = (.ok entries, final)) (query : K) :
    domain entries query = decide (query ∈ keys) := by
  simp only [domain, capture_keys choose keys state entries final accepted]

-- None models a non-symbol member. Refusal position is retained even though
-- today's Scheme public error message does not expose that position.
def firstRefusal (contains : K → Bool) : List (Option K) → Nat → Option Nat
  | [], _ => none
  | member :: rest, offset =>
      if (match member with | none => false | some key => contains key) then
        firstRefusal contains rest (offset + 1)
      else some offset

theorem same_first_refusal (keys : List K) (entries : List (K × V))
    (same : entries.map Prod.fst = keys) (members : List (Option K)) (offset : Nat) :
    firstRefusal (domain entries) members offset =
      firstRefusal (fun key => decide (key ∈ keys)) members offset := by
  have lookup : domain entries = (fun key => decide (key ∈ keys)) := by
    funext query
    simp [domain, same]
  rw [lookup]

-- The admitted continuation is arbitrary, including errors and state effects.
-- Both guards refuse before invoking it, in the SAME original caller state.
def enter (contains : K → Bool) (members : List (Option K))
    (next : S → Except (Option Nat) V × S) (state : S) : Except (Option Nat) V × S :=
  match firstRefusal contains members 0 with
  | some position => (.error (some position), state)
  | none => next state

theorem same_entry (keys : List K) (entries : List (K × V))
    (same : entries.map Prod.fst = keys) (members : List (Option K))
    (next : S → Except (Option Nat) V × S) (state : S) :
    enter (domain entries) members next state =
      enter (fun key => decide (key ∈ keys)) members next state := by
  simp only [enter, same_first_refusal keys entries same members 0]

-- Distinct singleton requests at successive list positions do quadratic
-- memq work. This is cons-cell work, NOT a claim of O(1) hashing or CPU time.
def linearFamilyWork : Nat → Nat
  | 0 => 0
  | n + 1 => linearFamilyWork n + (n + 1)

theorem triangular_work (n : Nat) : 2 * linearFamilyWork n = n * (n + 1) := by
  induction n with
  | zero => rfl
  | succ n ih =>
    simp only [linearFamilyWork, Nat.mul_add, ih]
    simp [Nat.mul_add, Nat.mul_comm]
    omega

example : firstRefusal (fun n : Nat => decide (n ∈ [1, 2]))
    [some 2, none, some 7] 0 = some 1 := by decide
example : domain [(1, false), (2, true)] 1 = true := by decide

#print axioms capture_keys
#print axioms captured_domain
#print axioms same_first_refusal
#print axioms same_entry
#print axioms triangular_work
end ComponentFamily
