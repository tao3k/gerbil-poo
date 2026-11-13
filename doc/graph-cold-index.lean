import Std

namespace GraphColdIndex
variable {K : Type} [DecidableEq K]

-- This default belongs ONLY to inverse rows. Owner support is a different
-- admitted index; a missing inverse bucket does not mean a missing owner.
abbrev Rows (K : Type) := K → Option (List K)
def row (rows : Rows K) (key : K) : List K := (rows key).getD []
def dense (keys : List K) : Rows K := fun key => if key ∈ keys then some [] else none
def sparse : Rows K := fun _ => none
def Same (left right : Rows K) := ∀ key, row left key = row right key

theorem initial_same (keys : List K) : Same (dense keys) sparse := by
  intro key
  by_cases h : key ∈ keys <;> simp [row, dense, sparse, h]

def insert (rows : Rows K) (provider consumer : K) : Rows K :=
  fun key => if key = provider then some (consumer :: row rows provider) else rows key

theorem insert_same (left right : Rows K) (provider consumer : K)
    (h : Same left right) : Same (insert left provider consumer) (insert right provider consumer) := by
  intro key
  by_cases found : key = provider
  · simp [row, insert, found]
    exact h provider
  · simpa [row, insert, found] using h key

def build (edges : List (K × K)) (rows : Rows K) : Rows K :=
  edges.foldl (fun current edge => insert current edge.2 edge.1) rows

theorem build_same (edges : List (K × K)) (left right : Rows K)
    (h : Same left right) : Same (build edges left) (build edges right) := by
  induction edges generalizing left right with
  | nil => exact h
  | cons edge rest ih =>
    exact ih _ _ (insert_same left right edge.2 edge.1 h)

theorem dense_sparse_ordered (keys : List K) (edges : List (K × K)) :
    Same (build edges (dense keys)) (build edges sparse) :=
  build_same edges _ _ (initial_same keys)

-- Explicitly reject extending this representation rule to arbitrary defaults.
example : (none : Option (List Nat)).getD [7] ≠ (some []).getD [7] := by decide

-- The zero-edge specialization of the old DFS. Supported owners have no child
-- calls; repeated roots would be suppressed, so uniqueness is indispensable.
def emptyVisit : List K → List K → List K
  | [], _ => []
  | key :: rest, seen =>
      if key ∈ seen then emptyVisit rest seen
      else key :: emptyVisit rest (key :: seen)

theorem empty_order (keys seen : List K) (unique : keys.Nodup)
    (fresh : ∀ key ∈ keys, key ∉ seen) : emptyVisit keys seen = keys := by
  induction keys generalizing seen with
  | nil => rfl
  | cons key rest ih =>
    have absent := fresh key (by simp)
    simp only [emptyVisit, absent, ↓reduceIte]
    congr 1
    apply ih (key :: seen) (List.nodup_cons.mp unique).2
    intro other member
    simp only [List.mem_cons, not_or]
    exact ⟨fun eq => (List.nodup_cons.mp unique).1 (eq ▸ member),
      fresh other (by simp [member])⟩

theorem admitted_empty_order (keys : List K) (unique : keys.Nodup) :
    emptyVisit keys [] = keys := empty_order keys [] unique (by simp)

-- The Scheme classifier encodes these disjoint states as #f / symbol / #t.
-- Once multiple providers are seen it must never return to the empty state.
inductive Shape (K : Type) where
  | empty | one (provider : K) | many
  deriving DecidableEq

def see (shape : Shape K) (dependencies : List K) : Shape K :=
  match shape, dependencies with
  | .many, _ => .many
  | shape, [] => shape
  | .empty, [key] => .one key
  | .one old, [key] => if old = key then .one old else .many
  | _, _ => .many

theorem see_empty (shape : Shape K) (dependencies : List K) :
    see shape dependencies = .empty ↔ shape = .empty ∧ dependencies = [] := by
  cases shape <;> cases dependencies with
  | nil => simp [see]
  | cons key rest =>
    cases rest <;> simp [see]
    all_goals (split <;> simp_all)

def noEdges (rows : List (List K)) := ∀ dependencies ∈ rows, dependencies = []

theorem fold_empty (rows : List (List K)) (shape : Shape K) :
    rows.foldl see shape = .empty ↔ shape = .empty ∧ noEdges rows := by
  induction rows generalizing shape with
  | nil => simp [noEdges]
  | cons dependencies rest ih =>
    rw [List.foldl_cons, ih, see_empty]
    simp [noEdges, and_assoc]

-- Capacity is a native implementation hint, never a membership certificate.
-- Only point reads of these private tables are used; schedule order is explicit.
structure Reserved (K V : Type) where
  capacity : Nat
  entries : K → Option V

def reserve (capacity : Nat) : Reserved K V := ⟨capacity, fun _ => none⟩
def put (table : Reserved K V) (key : K) (value : V) : Reserved K V :=
  ⟨table.capacity, fun query => if query = key then some value else table.entries query⟩

theorem reserve_empty (a b : Nat) :
    (reserve a : Reserved K V).entries = (reserve b : Reserved K V).entries := rfl

theorem put_capacity_independent (a b : Reserved K V) (key : K) (value : V)
    (same : a.entries = b.entries) : (put a key value).entries = (put b key value).entries := by
  funext query
  simp [put, same]

theorem batch_capacity_independent (writes : List (K × V)) (a b : Reserved K V)
    (same : a.entries = b.entries) :
    (writes.foldl (fun current item => put current item.1 item.2) a).entries =
      (writes.foldl (fun current item => put current item.1 item.2) b).entries := by
  induction writes generalizing a b with
  | nil => exact same
  | cons item rest ih =>
    exact ih _ _ (put_capacity_independent a b item.1 item.2 same)

#print axioms initial_same
#print axioms insert_same
#print axioms build_same
#print axioms dense_sparse_ordered
#print axioms empty_order
#print axioms admitted_empty_order
#print axioms see_empty
#print axioms fold_empty
#print axioms reserve_empty
#print axioms put_capacity_independent
#print axioms batch_capacity_independent

-- Cold capture stores one immutable admitted row per owner. Reading that
-- row directly is extensionally equal to materializing the same mapping.
def admittedRow (supported : K → Bool) (captured : K → List K) (key : K) :
    Option (List K) :=
  if supported key then some (captured key) else none

theorem cold_projection_preserves_missing (supported : K → Bool)
    (captured : K → List K) (key : K) (absent : supported key = false) :
    admittedRow supported captured key = none := by
  simp [admittedRow, absent]

theorem cold_projection_exact (supported : K → Bool)
    (captured : K → List K) (materialized : K → Option (List K))
    (live : ∀ key, supported key = true → materialized key = some (captured key))
    (missing : ∀ key, supported key = false → materialized key = none) :
    admittedRow supported captured = materialized := by
  funext key
  cases found : supported key with
  | false => simp [admittedRow, found, missing key found]
  | true => simp [admittedRow, found, live key found]

end GraphColdIndex
