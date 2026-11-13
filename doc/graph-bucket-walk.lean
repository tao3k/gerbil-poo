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

namespace GraphDeletionRegion

variable {K : Type}

inductive Path (edge : K → K → Prop) : K → K → Prop
  | nil (key : K) : Path edge key key
  | cons {a b c : K} : edge a b → Path edge b c → Path edge a c

theorem Path.append {edge : K → K → Prop} {a b c : K}
    (left : Path edge a b) (right : Path edge b c) : Path edge a c := by
  induction left with
  | nil => exact right
  | cons h _ ih => exact .cons h (ih right)

theorem Path.map {old next : K → K → Prop} {a b : K}
    (sub : ∀ ⦃x y⦄, next x y → old x y) (p : Path next a b) : Path old a b := by
  induction p with
  | nil k => exact .nil k
  | cons h _ ih => exact .cons (sub h) ih

def Same (edge : K → K → Prop) (a b : K) : Prop :=
  Path edge a b ∧ Path edge b a

def Changed (old next : K → K → Prop) (key : K) : Prop :=
  ∃ a b, Same old key a ∧ Same old key b ∧ old a b ∧ ¬ next a b

-- A path with a return route stays inside its old SCC. If that SCC has
-- no deleted internal edge, replay the path in the successor.
theorem replay {old next : K → K → Prop} {a b : K}
    (p : Path old a b) (back : Path old b a) (clean : ¬ Changed old next a) :
    Path next a b := by
  induction p with
  | nil k => exact .nil k
  | @cons a mid b edge rest ih =>
    have hop : Path old a mid := .cons edge (.nil mid)
    have midBack : Path old mid a := rest.append back
    have keep : next a mid := Classical.byContradiction fun lost =>
      clean ⟨a, mid, ⟨.nil a, .nil a⟩, ⟨hop, midBack⟩, edge, lost⟩
    have cleanMid : ¬ Changed old next mid := by
      rintro ⟨x, y, hx, hy, oldEdge, lost⟩
      exact clean ⟨x, y, ⟨hop.append hx.1, hx.2.append midBack⟩,
        ⟨hop.append hy.1, hy.2.append midBack⟩, oldEdge, lost⟩
    exact .cons keep (ih (back.append hop) cleanMid)

theorem clean_exact {old next : K → K → Prop} {a b : K}
    (sub : ∀ ⦃x y⦄, next x y → old x y) (clean : ¬ Changed old next a) :
    Same next a b ↔ Same old a b := by
  constructor
  · exact fun h => ⟨h.1.map sub, h.2.map sub⟩
  · intro h
    have cleanB : ¬ Changed old next b := by
      rintro ⟨x, y, hx, hy, edge, lost⟩
      exact clean ⟨x, y, ⟨h.1.append hx.1, hx.2.append h.2⟩,
        ⟨h.1.append hy.1, hy.2.append h.2⟩, edge, lost⟩
    exact ⟨replay h.1 h.2 clean, replay h.2 h.1 cleanB⟩

theorem restrict_path {old next : K → K → Prop} {root a b : K}
    (sub : ∀ ⦃x y⦄, next x y → old x y) (p : Path next a b)
    (enter : Path old root a) (leave : Path old b root) :
    Path (fun x y => next x y ∧ Same old root x ∧ Same old root y) a b := by
  induction p with
  | nil k => exact .nil k
  | @cons a mid b edge rest ih =>
    have enterMid := enter.append (.cons (sub edge) (.nil mid))
    have leaveMid := (rest.map sub).append leave
    exact .cons ⟨edge, ⟨enter, .cons (sub edge) leaveMid⟩, ⟨enterMid, leaveMid⟩⟩
      (ih enterMid leave)

-- A self edge can always be skipped, including in a one-vertex SCC.
theorem skip_self_edges {edge : K → K → Prop} {a b : K} (p : Path edge a b) :
    Path (fun x y => edge x y ∧ x ≠ y) a b := by
  classical
  induction p with
  | nil k => exact .nil k
  | @cons a mid b h _ ih =>
    by_cases eq : a = mid
    · simpa [eq] using ih
    · exact .cons ⟨h, eq⟩ ih

theorem restricted_exact {old next : K → K → Prop} {root a b : K}
    (sub : ∀ ⦃x y⦄, next x y → old x y)
    (ha : Same old root a) (hb : Same old root b) :
    Same (fun x y => next x y ∧ Same old root x ∧ Same old root y) a b ↔
      Same next a b := by
  constructor
  · have drop : ∀ ⦃x y⦄, (next x y ∧ Same old root x ∧ Same old root y) → next x y :=
      fun {_ _} e => e.1
    exact fun h => ⟨h.1.map drop, h.2.map drop⟩
  · exact fun h => ⟨restrict_path sub h.1 ha.1 hb.2, restrict_path sub h.2 hb.1 ha.2⟩

-- For a surviving edge, comparing the provider's representatives is the
-- exact test for whether that edge contributes a different quotient target.
-- A deleted edge is covered by the authored row edit, so it contributes no
-- extra successor-inverse seed.
def QuotientSeed (next : K → K → Prop) (before after : K → K)
    (consumer : K) : Prop :=
  ∃ provider, next consumer provider ∧ before provider ≠ after provider

theorem quotient_seed_exact {next : K → K → Prop} {before after : K → K}
    {consumer : K} :
    QuotientSeed next before after consumer ↔
      ∃ provider, (before provider ≠ after provider) ∧ next consumer provider := by
  constructor <;> rintro ⟨provider, h₁, h₂⟩ <;> exact ⟨provider, h₂, h₁⟩

theorem unchanged_projection {next : K → K → Prop} {before after : K → K}
    {consumer : K} (clean : ¬ QuotientSeed next before after consumer) :
    ∀ provider, next consumer provider → before provider = after provider := by
  intro provider live
  exact Classical.byContradiction fun changed => clean ⟨provider, live, changed⟩

theorem unchanged_row_projection {next : K → K → Prop} {before after : K → K}
    {consumer : K} (clean : ¬ QuotientSeed next before after consumer)
    (row : List K) (valid : ∀ provider ∈ row, next consumer provider) :
    row.map before = row.map after := by
  induction row with
  | nil => rfl
  | cons provider rest ih =>
    rw [List.map_cons, List.map_cons,
      unchanged_projection clean provider (valid provider (by simp))]
    exact congrArg (List.cons (after provider)) (ih fun key h => valid key (by simp [h]))

-- Member rows already follow source order. For one dirty component the
-- old concatenation was that member row, and sorting it is the identity.
theorem single_dirty_component_order {members : List K} {before : K → K → Bool}
    (ordered : members.Pairwise (fun a b => before a b)) :
    ([members].flatten).mergeSort before = members := by
  simpa using (List.mergeSort_of_pairwise ordered)

#print axioms clean_exact
#print axioms restrict_path
#print axioms skip_self_edges

end GraphDeletionRegion

namespace WholeComponentInverse

variable {K : Type}

-- Both inverse builders visit consumer rows in source order and prepend
-- readers. The certificate keeps only internal edges of nontrivial groups.
def readers (rows : List (K × List K)) (provider : K)
    (edge : K → K → Bool) [DecidableEq K] : List K :=
  rows.foldl (fun acc (owner, deps) =>
    if provider ∈ deps ∧ edge owner provider then owner :: acc else acc) []

theorem certificate_inverse_eq [DecidableEq K] (representative : K → K)
    (root provider : K) (rows : List (K × List K))
    (whole : ∀ owner, representative owner = root)
    (nontrivial : Bool) (size : nontrivial = true) :
    readers rows provider (fun owner dep =>
      decide (representative owner = representative dep) && nontrivial) =
    readers rows provider (fun _ _ => true) := by
  simp [readers, whole, size]

end WholeComponentInverse
