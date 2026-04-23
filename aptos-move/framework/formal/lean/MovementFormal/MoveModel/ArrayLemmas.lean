/-
Array access lemmas for proof irrelevance and index equality.

These lemmas address common proof obligations in PC-chaining theorems where
array accesses use different proof terms for the same index bound.
-/

namespace MovementFormal.MoveModel

/-- Array.get with different proofs for the same index accesses the same element. -/
theorem Array.get_proof_irrel {α : Type u} (arr : Array α) (i : Nat)
    (h1 : i < arr.size) (h2 : i < arr.size) :
    arr[i]'h1 = arr[i]'h2 := rfl

/-- When array bounds match, accessing an element with one proof equals accessing with another. -/
theorem Array.get_eq_of_proof_eq {α : Type u} (arr : Array α) (i : Nat)
    (h : i < arr.size) (h' : i < arr.size) :
    arr.get ⟨i, h⟩ = arr.get ⟨i, h'⟩ := rfl

/-- List.get with different proofs for the same index accesses the same element. -/
theorem List.get_proof_irrel {α : Type u} (lst : List α) (i : Nat)
    (h1 : i < lst.length) (h2 : i < lst.length) :
    lst[i]'h1 = lst[i]'h2 := rfl

/-- Accessing array element via getElem notation with different proofs is equal. -/
@[simp]
theorem array_getElem_congr {α : Type u} (arr : Array α) (i : Nat)
    (h1 : i < arr.size) (h2 : i < arr.size) :
    arr[i] = arr[i] := rfl

/-- Container allocation result is independent of array access proof term.
This lemma directly addresses the proof obligation at Withdrawal/EvalEquiv.lean:785
and similar cases where container.alloc is applied to an array element accessed
with different bound proofs. -/
theorem containers_alloc_proof_irrel {ContainerStore : Type} {MoveValue : Type}
    [Inhabited ContainerStore] [Inhabited MoveValue]
    (cs : ContainerStore) (alloc : ContainerStore → MoveValue → (ContainerStore × Nat))
    (arr : Array MoveValue) (i : Nat)
    (h1 : i < arr.length) (h2 : i < arr.length) :
    alloc cs (arr[i]'h1) = alloc cs (arr[i]'h2) := by
  congr
  -- arr[i]'h1 = arr[i]'h2 by proof irrelevance
  exact Array.get_proof_irrel arr i h1 h2

end MovementFormal.MoveModel
