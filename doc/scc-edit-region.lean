import Std

namespace SccEditRegion
variable {V : Type}

inductive Path (edge : V → V → Prop) : V → V → Prop where
  | nil (a : V) : Path edge a a
  | step : edge a b → Path edge b c → Path edge a c

theorem Path.append {edge : V → V → Prop} {a b c : V}
    (p : Path edge a b) (q : Path edge b c) : Path edge a c := by
  induction p with
  | nil => exact q
  | step e _ ih => exact .step e (ih q)

theorem Path.lift {edge next : V → V → Prop} {a b : V}
    (p : Path edge a b) (includeEdge : ∀ x y, edge x y → next x y) : Path next a b := by
  induction p with
  | nil => exact .nil _
  | step e _ ih => exact .step (includeEdge _ _ e) ih

def Union (old next : V → V → Prop) (a b : V) : Prop := old a b ∨ next a b
def Added (old next : V → V → Prop) (a b : V) : Prop := next a b ∧ ¬ old a b

-- Scheme borrows the old index and layers only additions during each walk.
theorem old_with_additions_exact {old next : V → V → Prop} {a b : V} :
    Union old (Added old next) a b ↔ Union old next a b := by
  classical
  unfold Union Added
  constructor
  · rintro (h | ⟨h, _⟩)
    · exact Or.inl h
    · exact Or.inr h
  · by_cases h : old a b <;> simp [h]
def Mutual (edge : V → V → Prop) (a b : V) : Prop := Path edge a b ∧ Path edge b a
def Region (edge : V → V → Prop) (root : V → Prop) (a : V) : Prop :=
  (∃ r, root r ∧ Path edge r a) ∧ (∃ r, root r ∧ Path edge a r)

theorem one_root_region {edge : V → V → Prop} {root a : V} :
    Region edge (· = root) a ↔ Mutual edge root a := by
  simp [Region, Mutual]

-- The specialized cut needs one successor per old row, every owner reaching
-- cut, and an exact deletion of the cut row. No enumeration of new SCCs is
-- needed to establish the singleton owner/member projections.
inductive Steps (edge : V → V → Prop) : V → V → Nat → Prop where
  | nil (a : V) : Steps edge a a 0
  | step : edge a b → Steps edge b c n → Steps edge a c (n + 1)

def Cut (edge : V → V → Prop) (sink : V) (a b : V) := edge a b ∧ a ≠ sink

theorem cut_reaches_sink {edge : V → V → Prop} {a sink : V} (p : Path edge a sink) :
    ∃ n, Steps (Cut edge sink) a sink n := by
  classical
  induction p with
  | nil => exact ⟨0, .nil _⟩
  | @step x y z e _ ih =>
    by_cases atSink : x = z
    · subst x
      exact ⟨0, .nil _⟩
    · obtain ⟨n, tail⟩ := ih
      exact ⟨n + 1, .step ⟨e, atSink⟩ tail⟩

def Functional (edge : V → V → Prop) : Prop := ∀ a b c, edge a b → edge a c → b = c

theorem cut_distance_unique {edge : V → V → Prop} {a b sink : V} {n m : Nat}
    (one : Functional edge) (p : Steps (Cut edge sink) a b n)
    (q : Steps (Cut edge sink) a b m) (endpoint : b = sink) : n = m := by
  induction p generalizing m with
  | nil =>
    cases q with
    | nil => rfl
    | step e _ => exact False.elim (e.2 endpoint)
  | @step x y z k first _ ih =>
    cases q with
    | nil => exact False.elim (first.2 endpoint)
    | @step _ w _ l other tail =>
      have same := one x y w first.1 other.1
      subst w
      exact congrArg (· + 1) (ih tail endpoint)

theorem cut_path_descends {edge : V → V → Prop} {sink a b : V} {n : Nat}
    (one : Functional edge) (p : Path (Cut edge sink) a b)
    (dist : Steps (Cut edge sink) a sink n) :
    ∃ m, Steps (Cut edge sink) b sink m ∧ m ≤ n ∧ (a ≠ b → m < n) := by
  induction p generalizing n with
  | nil => exact ⟨n, dist, Nat.le_refl _, fun h => False.elim (h rfl)⟩
  | @step x y z first _ ih =>
    cases dist with
    | nil => exact False.elim (first.2 rfl)
    | @step _ w _ k other tail =>
      have same := one x y w first.1 other.1
      subst w
      obtain ⟨m, d, le, _⟩ := ih tail
      exact ⟨m, d, Nat.le_trans le (Nat.le_succ k), fun _ => Nat.lt_succ_of_le le⟩

theorem functional_cut_singletons {edge : V → V → Prop} {sink a b : V}
    (one : Functional edge) (reaches : ∀ v, Path edge v sink) :
    Mutual (Cut edge sink) a b ↔ a = b := by
  constructor
  · intro pair
    classical
    by_cases sameVertex : a = b
    · exact sameVertex
    · obtain ⟨n, atA⟩ := cut_reaches_sink (reaches a)
      obtain ⟨m, atB, _, down⟩ := cut_path_descends one pair.1 atA
      obtain ⟨k, back, le, _⟩ := cut_path_descends one pair.2 atB
      have same := cut_distance_unique one back atA rfl
      exact False.elim (Nat.not_lt_of_ge (same ▸ le) (down sameVertex))
  · rintro rfl
    exact ⟨.nil _, .nil _⟩

theorem functional_replacement_exact {old next : V → V → Prop} {cut : V}
    (one : Functional old) (removed : ∃ dep, old cut dep ∧ ¬ next cut dep)
    (deletesOnly : ∀ a b, next a b → old a b)
    (otherRows : ∀ a b, a ≠ cut → old a b → next a b) :
    next = Cut old cut := by
  funext a b
  apply propext
  constructor
  · intro e
    have prior := deletesOnly a b e
    refine ⟨prior, ?_⟩
    rintro rfl
    obtain ⟨dep, before, absent⟩ := removed
    have same := one a b dep prior before
    exact absent (same ▸ e)
  · rintro ⟨before, outside⟩
    exact otherRows a b outside before

theorem functional_repair_exact {old next : V → V → Prop} {cut a b : V}
    (one : Functional old) (reaches : ∀ v, Path old v cut)
    (removed : ∃ dep, old cut dep ∧ ¬ next cut dep)
    (deletesOnly : ∀ a b, next a b → old a b)
    (otherRows : ∀ a b, a ≠ cut → old a b → next a b) :
    Mutual next a b ↔ a = b := by
  rw [functional_replacement_exact one removed deletesOnly otherRows]
  exact functional_cut_singletons one reaches

-- Even the old representative's group changes. Every owner belongs to a
-- different group after a certified cut of a nontrivial whole component.
theorem every_group_changed {old next : V → V → Prop} (owner : V)
    (nontrivial : ∃ a b : V, a ≠ b) (whole : ∀ a b, Mutual old a b)
    (split : ∀ a b, Mutual next a b ↔ a = b) :
    ∃ other, Mutual old owner other ∧ ¬ Mutual next owner other := by
  classical
  obtain ⟨a, b, different⟩ := nontrivial
  by_cases same : owner = a
  · exact ⟨b, whole owner b, fun s => different (same.symm.trans ((split owner b).mp s))⟩
  · exact ⟨a, whole owner a, fun s => same ((split owner a).mp s)⟩

-- The old graph may still be one SCC after an internal chord. The chord
-- can preserve a nontrivial SCC when a different row is later removed.
private def chordedRing (a b : Fin 3) : Prop :=
  (a = 0 ∧ (b = 1 ∨ b = 2)) ∨ (a = 1 ∧ b = 2) ∨ (a = 2 ∧ b = 0)

example : ¬ Functional chordedRing := by
  intro one
  have contradiction : (1 : Fin 3) = 2 := one 0 1 2
    (by unfold chordedRing; decide) (by unfold chordedRing; decide)
  exact (by decide : (1 : Fin 3) ≠ 2) contradiction

example : Mutual (Cut chordedRing 1) 0 2 := by
  have forward : Cut chordedRing 1 0 2 := by unfold Cut chordedRing; decide
  have backward : Cut chordedRing 1 2 0 := by unfold Cut chordedRing; decide
  exact ⟨.step forward (.nil _), .step backward (.nil _)⟩

#print axioms one_root_region
#print axioms functional_replacement_exact
#print axioms functional_repair_exact
#print axioms every_group_changed

-- Follow the first row in the path that is allowed to differ. If there is
-- no such row, the complete path survives with its exact orientation.
theorem path_or_root {edge next : V → V → Prop} {root : V → Prop} {a b : V}
    (unchanged : ∀ x y, ¬ root x → edge x y → next x y) (p : Path edge a b) :
    Path next a b ∨ ∃ r, root r ∧ Path edge a r ∧ Path edge r b := by
  classical
  induction p with
  | nil => exact Or.inl (.nil _)
  | @step x y z e tail ih =>
    by_cases atRoot : root x
    · exact Or.inr ⟨x, atRoot, .nil x, .step e tail⟩
    · rcases ih with found | ⟨r, edited, before, after⟩
      · exact Or.inl (.step (unchanged x y atRoot e) found)
      · exact Or.inr ⟨r, edited, .step e before, after⟩

theorem preserve_outside_one_way {edge next union : V → V → Prop}
    {root : V → Prop} {a b : V}
    (unchanged : ∀ x y, ¬ root x → edge x y → next x y)
    (includes : ∀ x y, edge x y → union x y)
    (outside : ¬ Region union root a) (scc : Mutual edge a b) : Mutual next a b := by
  have forward := scc.1.lift includes
  have backward := scc.2.lift includes
  constructor
  · rcases path_or_root unchanged scc.1 with p | ⟨r, edited, before, after⟩
    · exact p
    · exact False.elim (outside ⟨⟨r, edited, (after.lift includes).append backward⟩,
                                  ⟨r, edited, before.lift includes⟩⟩)
  · rcases path_or_root unchanged scc.2 with p | ⟨r, edited, before, after⟩
    · exact p
    · exact False.elim (outside ⟨⟨r, edited, after.lift includes⟩,
                                  ⟨r, edited, forward.append (before.lift includes)⟩⟩)

theorem outside_membership_exact {old next : V → V → Prop} {root : V → Prop} {a b : V}
    (unchanged : ∀ x y, ¬ root x → (old x y ↔ next x y))
    (outside : ¬ Region (Union old next) root a) : Mutual old a b ↔ Mutual next a b := by
  constructor
  · exact preserve_outside_one_way (fun x y h => (unchanged x y h).mp)
      (fun _ _ => Or.inl) outside
  · exact preserve_outside_one_way (fun x y h => (unchanged x y h).mpr)
      (fun _ _ => Or.inr) outside

def Induced (edge : V → V → Prop) (inside : V → Prop) (a b : V) : Prop :=
  edge a b ∧ inside a ∧ inside b

-- Region is path-convex in the union, hence also in the successor. This
-- needs no assumption that the two reaching roots are the same root.
theorem restrict_path {edge union : V → V → Prop} {root : V → Prop} {a b : V}
    (includes : ∀ x y, edge x y → union x y) (p : Path edge a b)
    (start : Region union root a) (finish : Region union root b) :
    Path (Induced edge (Region union root)) a b := by
  induction p with
  | nil => exact .nil _
  | @step x y z e tail ih =>
    obtain ⟨r, rootR, toX⟩ := start.1
    obtain ⟨s, rootS, fromZ⟩ := finish.2
    have insideY : Region union root y :=
      ⟨⟨r, rootR, toX.append (.step (includes x y e) (.nil y))⟩,
       ⟨s, rootS, (tail.lift includes).append fromZ⟩⟩
    exact .step ⟨e, start, insideY⟩ (ih insideY finish)

theorem induced_membership_exact {old next : V → V → Prop} {root : V → Prop} {a b : V}
    (ha : Region (Union old next) root a) (hb : Region (Union old next) root b) :
    Mutual (Induced next (Region (Union old next) root)) a b ↔ Mutual next a b := by
  constructor
  · intro p
    exact ⟨p.1.lift (fun _ _ e => e.1), p.2.lift (fun _ _ e => e.1)⟩
  · intro p
    exact ⟨restrict_path (fun _ _ => Or.inr) p.1 ha hb,
           restrict_path (fun _ _ => Or.inr) p.2 hb ha⟩

theorem no_crossing_component {edge union : V → V → Prop} {root : V → Prop} {a b : V}
    (includes : ∀ x y, edge x y → union x y) (ha : Region union root a)
    (p : Mutual edge a b) : Region union root b := by
  obtain ⟨⟨r, rootR, toA⟩, ⟨s, rootS, fromA⟩⟩ := ha
  exact ⟨⟨r, rootR, toA.append (p.1.lift includes)⟩,
         ⟨s, rootS, (p.2.lift includes).append fromA⟩⟩

-- Patch by replacing only whole old components in the region. The resulting
-- equivalence relation is the cold successor relation, including mixed pairs.
theorem patch_exact {old next : V → V → Prop} {root : V → Prop} {a b : V}
    (unchanged : ∀ x y, ¬ root x → (old x y ↔ next x y)) :
    let inside := Region (Union old next) root
    ((¬ inside a ∧ Mutual old a b) ∨
      (inside a ∧ inside b ∧ Mutual (Induced next inside) a b)) ↔ Mutual next a b := by
  dsimp only
  constructor
  · rintro (⟨outside, prior⟩ | ⟨ha, hb, localPair⟩)
    · exact (outside_membership_exact unchanged outside).mp prior
    · exact (induced_membership_exact ha hb).mp localPair
  · intro cold
    classical
    by_cases ha : Region (Union old next) root a
    · have hb := no_crossing_component (union := Union old next) (fun _ _ => Or.inr) ha cold
      exact Or.inr ⟨ha, hb, (induced_membership_exact ha hb).mpr cold⟩
    · exact Or.inl ⟨ha, (outside_membership_exact unchanged ha).mpr cold⟩

-- One changed row with deletions only: the old member index supplies the
-- exact induced repair region without any forward or reverse walk.
theorem single_removal_exact {old next : V → V → Prop} {cut a b : V}
    (deletesOnly : ∀ x y, next x y → old x y)
    (unchanged : ∀ x y, x ≠ cut → (old x y ↔ next x y)) :
    let inside := Mutual old cut
    ((¬ inside a ∧ Mutual old a b) ∨
      (inside a ∧ inside b ∧ Mutual (Induced next inside) a b)) ↔ Mutual next a b := by
  have union : Union old next = old := by
    funext x y
    exact propext ⟨fun e => e.elim id (deletesOnly x y), Or.inl⟩
  have region : Region old (· = cut) = Mutual old cut := by
    funext x
    exact propext one_root_region
  have general := patch_exact (old := old) (next := next) (root := (· = cut))
    (a := a) (b := b) unchanged
  simpa only [union, region] using general

#print axioms single_removal_exact

-- On the same source roster, exact membership also fixes the representative
-- chosen by the first-member rule. This does not assume discovery order.
theorem first_representative_exact (roster : List V) (patched cold : V → Bool)
    (same : ∀ v, patched v = cold v) :
    roster.find? patched = roster.find? cold := by
  rw [show patched = cold from funext same]

-- A consumer is dirty if it can follow dependencies to any edited owner.
-- This is exactly the direction enumerated by a reverse walk from the roots.
def Dirty (edge : V → V → Prop) (root : V → Prop) (consumer : V) : Prop :=
  ∃ provider, root provider ∧ Path edge consumer provider

theorem dirty_one_way {old next : V → V → Prop} {root : V → Prop} {consumer : V}
    (unchanged : ∀ x y, ¬ root x → old x y → next x y)
    (dirty : Dirty old root consumer) : Dirty next root consumer := by
  obtain ⟨target, edited, path⟩ := dirty
  induction path with
  | nil => exact ⟨_, edited, .nil _⟩
  | @step x y z edge _ ih =>
    classical
    by_cases atRoot : root x
    · exact ⟨x, atRoot, .nil x⟩
    · obtain ⟨provider, isRoot, suffix⟩ := ih edited
      exact ⟨provider, isRoot, .step (unchanged x y atRoot edge) suffix⟩

-- Fixed support, with every edited reader in the seed set. Walking the
-- predecessor is exact even if the ticket changes multiple dependency rows.
theorem old_inverse_exact {old next : V → V → Prop} {root : V → Prop} {consumer : V}
    (unchanged : ∀ x y, ¬ root x → (old x y ↔ next x y)) :
    Dirty old root consumer ↔ Dirty next root consumer :=
  ⟨dirty_one_way (fun x y h => (unchanged x y h).mp),
   dirty_one_way (fun x y h => (unchanged x y h).mpr)⟩

-- Before deduplication, group-code visits ordered members and their ordered
-- rows. Its output keeps both the actual provider node and its representative.
def routes (group : V) (owner : V → V) [DecidableEq V] : List V → List (V × V)
  | [] => []
  | node :: rest =>
    if owner node = group then routes group owner rest
    else (node, owner node) :: routes group owner rest

theorem routes_unchanged [DecidableEq V] (group : V) (old next : V → V)
    (row : List V) (stable : ∀ node ∈ row, old node = next node) :
    routes group old row = routes group next row := by
  induction row with
  | nil => rfl
  | cons node rest ih =>
    have same := stable node (List.mem_cons_self ..)
    have tail := ih (fun dep member => stable dep (List.mem_cons_of_mem node member))
    simp only [routes, same, tail]

-- Contrapositive of exact row projection: a changed route on an unchanged
-- row needs a remapped successor provider. The native successor inverse of
-- that provider must include this reader, even outside the SCC repair region.
theorem changed_route_requires_remapped_provider [DecidableEq V]
    (group : V) (old next : V → V) (row : List V)
    (changed : routes group old row ≠ routes group next row) :
    ∃ provider ∈ row, old provider ≠ next provider := by
  classical
  by_cases found : ∃ provider ∈ row, old provider ≠ next provider
  · exact found
  · apply False.elim
    apply changed
    apply routes_unchanged
    intro provider member
    exact Classical.byContradiction (fun remapped => found ⟨provider, member, remapped⟩)

-- The actual walk marks the reader's successor group, not the provider's
-- old group. Assume the successor inverse is the exact transpose of rows.
theorem changed_group_is_seeded [DecidableEq V] (old next : V → V)
    (row : V → List V) (readers : V → V → Prop) (reader : V)
    (transpose : ∀ r p, p ∈ row r ↔ readers p r)
    (changed : routes (next reader) old (row reader) ≠
               routes (next reader) next (row reader)) :
    ∃ p r, old p ≠ next p ∧ readers p r ∧ next r = next reader := by
  obtain ⟨provider, member, remapped⟩ :=
    changed_route_requires_remapped_provider (next reader) old next (row reader) changed
  exact ⟨provider, reader, remapped, (transpose reader provider).mp member, rfl⟩

private def twoCycle (a b : Bool) : Prop := a ≠ b
private def cut (a b : Bool) : Prop := a = true ∧ b = false
private def cutRoot (a : Bool) : Prop := a = false

private theorem cut_sink {b : Bool} (p : Path cut false b) : b = false := by
  cases p with
  | nil => rfl
  | step e _ => simp [cut] at e

-- Cutting false → true splits the old cycle. Walking only the new graph
-- misses true, even though its old SCC membership changes.
example : ¬ Region cut cutRoot true ∧
    Mutual twoCycle false true ∧ ¬ Mutual cut false true := by
  refine ⟨?_, ⟨.step (by simp [twoCycle]) (.nil _), .step (by simp [twoCycle]) (.nil _)⟩, ?_⟩
  · intro h
    obtain ⟨r, isRoot, p⟩ := h.1
    change r = false at isRoot
    subst r
    cases cut_sink p
  · intro h
    cases cut_sink h.1

#print axioms old_with_additions_exact
#print axioms outside_membership_exact
#print axioms induced_membership_exact
#print axioms no_crossing_component
#print axioms patch_exact
#print axioms first_representative_exact
#print axioms old_inverse_exact
#print axioms routes_unchanged
#print axioms changed_route_requires_remapped_provider
#print axioms changed_group_is_seeded
end SccEditRegion
