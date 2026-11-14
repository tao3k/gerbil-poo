/- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later -/
namespace Poo.CLOS.CallValidation

inductive Descriptor where
  | generic
  | method
  deriving DecidableEq

/-- Native evidence must cover the exact descriptor, field policy, and all
    transitive dependencies. Their interpretation belongs to the runtime. -/
structure Support where
  descriptor : Descriptor
  receiver : Nat
  policy : Nat
  roots : List Nat
  payload : List Nat
  deriving DecidableEq

structure Checked where
  support : Support
  epoch : Nat
  deriving DecidableEq

inductive Boundary where
  | closed
  | observer
  | author
  | replacement
  | publicEntry
  deriving DecidableEq

def canReplay (boundary : Boundary) (epoch : Nat) (current : Support)
    (issued : Checked) : Bool :=
  decide (boundary = .closed ∧ issued.epoch = epoch ∧ issued.support = current)

theorem replay_requires_exact_support {boundary epoch current issued}
    (h : canReplay boundary epoch current issued = true) :
    boundary = .closed ∧ issued.epoch = epoch ∧ issued.support = current := by
  simpa [canReplay] using h

/-- Replaying is equivalent only with a current native witness and the intact
    original delivery order. The hypothesis is a Scheme proof obligation,
    not a claim that descriptor identity alone proves currentness. -/
theorem reuse_preserves_success_and_delivery
    (check : Support → Bool) (boundary : Boundary) (epoch : Nat)
    (current : Support) (issued : Checked)
    (admitted : check issued.support = true)
    (reuse : canReplay boundary epoch current issued = true) :
    (true, issued.support.roots) = (check current, current.roots) := by
  obtain ⟨_, _, same⟩ := replay_requires_exact_support reuse
  rw [← same, admitted]

theorem effect_boundary_requires_check (boundary : Boundary) (epoch : Nat)
    (current : Support) (issued : Checked) (effect : boundary ≠ .closed) :
    canReplay boundary epoch current issued = false := by
  simp [canReplay, effect]

theorem change_requires_check (epoch : Nat) (current : Support) (issued : Checked)
    (changed : issued.support ≠ current) :
    canReplay .closed epoch current issued = false := by
  simp [canReplay, changed]

/-- Earlier failures still win, even when the later nested descriptor can be
    reused. A miss invokes the ordinary validator at its original position. -/
def validateField (earlier nested later : Bool) : Nat :=
  if !earlier then 1 else if !nested then 2 else if !later then 3 else 0

theorem reuse_preserves_first_failure (earlier later : Bool)
    (check : Support → Bool) (epoch : Nat) (current : Support) (issued : Checked)
    (admitted : check issued.support = true)
    (reuse : canReplay .closed epoch current issued = true) :
    validateField earlier true later = validateField earlier (check current) later := by
  obtain ⟨_, _, same⟩ := replay_requires_exact_support reuse
  rw [← same, admitted]


theorem replay_after_epoch_change_refused (current : Support) (issued : Checked) :
    canReplay .closed (issued.epoch + 1) current issued = false := by
  simp [canReplay]

theorem receiver_identity_is_insufficient (issued : Checked) (current : Support)
    (differentPolicy : issued.support.policy ≠ current.policy) :
    canReplay .closed issued.epoch current issued = false := by
  apply change_requires_check
  intro same
  exact differentPolicy (congrArg Support.policy same)

theorem generic_evidence_cannot_certify_method (issued : Checked) (current : Support)
    (generic : issued.support.descriptor = .generic)
    (method : current.descriptor = .method) :
    canReplay .closed issued.epoch current issued = false := by
  apply change_requires_check
  intro same
  have equality := congrArg Support.descriptor same
  rw [generic, method] at equality
  contradiction


/-- A Slot can retain the same list identity and issuance while a pair's
    contents change. The membership predicate sees the contents. -/
structure MutableMethodSpine where
  slotIdentity : Nat
  qualifiers : List Nat

def BuiltinMethodSpineValid (spine : MutableMethodSpine) : Bool :=
  spine.qualifiers.all (· < 4)

theorem slot_identity_does_not_prove_method_spine :
    ∃ previous current : MutableMethodSpine,
      previous.slotIdentity = current.slotIdentity ∧
      BuiltinMethodSpineValid previous = true ∧
      BuiltinMethodSpineValid current = false := by
  exact ⟨⟨1, [0, 1]⟩, ⟨1, [0, 4]⟩, rfl, rfl, rfl⟩

/-- The fast interval never inherits approval from an earlier call. -/
inductive CheckStep where
  | admit (checked : Checked)
  | boundary
  | finish

def activeSupport (steps : List CheckStep) : Option Checked :=
  steps.foldl (fun _ step => match step with
    | .admit checked => some checked
    | .boundary | .finish => none) none

theorem support_revoked_at_boundary (steps : List CheckStep) :
    activeSupport (steps ++ [.boundary]) = none := by
  simp [activeSupport, List.foldl_append]

theorem support_does_not_escape_call (steps : List CheckStep) :
    activeSupport (steps ++ [.finish]) = none := by
  simp [activeSupport, List.foldl_append]


/-- Proof of the first-failure rule when the optimized path can decline. -/
def checkOrReuse (boundary : Boundary) (epoch : Nat) (current : Support)
    (issued : Checked) (ordinary : Support → Bool) : Bool :=
  if canReplay boundary epoch current issued then true else ordinary current

theorem checkOrReuse_eq (boundary : Boundary) (epoch : Nat)
    (current : Support) (issued : Checked) (ordinary : Support → Bool)
    (admitted : ordinary issued.support = true) :
    checkOrReuse boundary epoch current issued ordinary = ordinary current := by
  unfold checkOrReuse
  split
  · rename_i reuse
    obtain ⟨_, _, same⟩ := replay_requires_exact_support reuse
    rw [← same, admitted]
  · rfl

theorem pair_payload_is_part_of_support (issued : Checked) (current : Support)
    (changed : issued.support.payload ≠ current.payload) :
    canReplay .closed issued.epoch current issued = false := by
  apply change_requires_check
  intro same
  exact changed (congrArg Support.payload same)

end Poo.CLOS.CallValidation
