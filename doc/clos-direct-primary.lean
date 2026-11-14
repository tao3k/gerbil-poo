/- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later -/
namespace Poo.CLOS.DirectPrimary

inductive Read where
  | source (key : Nat)
  | privateCarrier (key : Nat)
  deriving DecidableEq, Repr

inductive Failure where
  | arity | applicability | keyword | effective | frame | body
  deriving DecidableEq, Repr

abbrev Phase (S A : Type) := S → Except Failure A × S × List Read

def thenRun (first : Phase S A) (next : A → Phase S B) : Phase S B :=
  fun state =>
    match first state with
    | (.error failure, after, reads) => (.error failure, after, reads)
    | (.ok value, after, reads) =>
      let (result, final, later) := next value after
      (result, final, reads ++ later)

def visible : List Read → List Read
  | [] => []
  | .source key :: rest => .source key :: visible rest
  | .privateCarrier _ :: rest => visible rest

theorem visible_append (left right : List Read) :
    visible (left ++ right) = visible left ++ visible right := by
  induction left with
  | nil => rfl
  | cons head rest ih => cases head <;> simp [visible, ih]

def observe (entry : Phase S A) (state : S) :=
  let (answer, after, reads) := entry state
  (answer, after, visible reads)

/-- The shared admission includes arity, applicability, keyword and the live
    external descriptor checks. The remaining private step must succeed,
    preserve state, and contribute only unobservable carrier reads. -/
theorem eliminate_private_carriers (admission : Phase S P)
    (carriers : P → Phase S C) (ordinaryBody : P → C → Phase S A)
    (directBody : P → Phase S A)
    (privateOnly : ∀ payload state, ∃ carrier reads,
      carriers payload state = (.ok carrier, state, reads) ∧ visible reads = [] ∧
      ordinaryBody payload carrier state = directBody payload state)
    (state : S) :
    observe (thenRun admission (fun payload => thenRun (carriers payload) (ordinaryBody payload))) state =
    observe (thenRun admission directBody) state := by
  unfold observe thenRun
  cases h : admission state with
  | mk outcome tail =>
    rcases tail with ⟨after, prior⟩
    cases outcome with
    | error failure => rfl
    | ok payload =>
      obtain ⟨carrier, reads, admitted, hidden, body⟩ := privateOnly payload after
      simp [admitted, hidden, body, visible_append]

inductive Route where
  | closedPrimary | openObserver | openCallback | replacement | publicCarrier | nextMethod
  deriving DecidableEq

def invoke (route : Route) (qualified : Bool) (ordinary direct : Phase S A) : Phase S A :=
  if route = .closedPrimary ∧ qualified then direct else ordinary

theorem effect_or_escape_uses_ordinary (route : Route) (qualified : Bool)
    (ordinary direct : Phase S A) (outside : route ≠ .closedPrimary) :
    invoke route qualified ordinary direct = ordinary := by
  simp [invoke, outside]

/-- An arbitrary observer can inspect the carrier read itself. Such a trace
    cannot use the projection in eliminate_private_carriers. -/
theorem raw_carrier_delivery_is_observable :
    ([Read.privateCarrier 0] : List Read) ≠ [] := by decide


/-- A direct entry cannot use the theorem when the omitted step would refuse.
    Running the actual admission sequence is necessary even for one method. -/
theorem failing_carrier_cannot_be_erased :
    let admission : Phase Unit Unit := fun s => (.ok (), s, [])
    let carrier : Unit → Phase Unit Unit := fun _ s => (.error .frame, s, [])
    let body : Unit → Phase Unit Unit := fun _ s => (.ok (), s, [])
    observe (thenRun admission (fun value => thenRun (carrier value) fun _ => body value)) () ≠
      observe (thenRun admission body) () := by
  dsimp [observe, thenRun]
  intro same
  cases same

end Poo.CLOS.DirectPrimary

namespace Poo.CLOS.DirectPrimary

/-- A carrier allocation can be deferred for a lexical entry that cannot
    refer to the frame. The failure from a body keeps the same position. -/
theorem frame_free_body_preserves_failure {S A : Type}
    (body : Phase S A) (state : S) (carrier : Nat) :
    observe
      (thenRun (fun current => (.ok carrier, current, [.privateCarrier 0]))
        (fun _ => body)) state = observe body state := by
  simp [observe, thenRun, visible]

/-- A snapshot of the full external trace is not required by this
    transformation. The external admission itself is performed in both. -/
example (admission : Phase Unit Unit) (body : Phase Unit Unit) :
    observe
      (thenRun admission (fun _ =>
        thenRun (fun current => (.ok (), current, [.privateCarrier 0]))
          (fun _ => body))) () =
    observe (thenRun admission (fun _ => body)) () := by
  apply eliminate_private_carriers
  intro _ state
  exact ⟨(), [.privateCarrier 0], rfl, rfl, rfl⟩

end Poo.CLOS.DirectPrimary
