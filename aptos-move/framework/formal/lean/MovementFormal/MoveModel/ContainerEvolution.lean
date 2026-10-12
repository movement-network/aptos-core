import MovementFormal.MoveModel.State

/-!
# Container store evolution (successive `alloc`)

Small lemmas about **`ContainerStore.alloc`** chains used by step-lemma composition
(`BorrowFieldChains`, `ProvenChains`).

**Source:** `MovementFormal.MoveModel.Value` / `State` — `ContainerStore` is an array of
`MoveValue`; **`alloc`** appends one cell and returns the new **`RefId`** (index).
-/

namespace MovementFormal.MoveModel.ContainerEvolution

open MovementFormal.MoveModel
open MovementFormal.MoveModel.ContainerStore

/-- After two successive allocations, both refs read back the values in order. -/
theorem consecutive_allocs_both_readable (cs : ContainerStore) (v1 v2 : MoveValue) :
    let (cs1, fid1) := cs.alloc v1
    let (cs2, fid2) := cs1.alloc v2
    cs2.read fid1 = some v1 ∧ cs2.read fid2 = some v2 := by
  rcases cs with ⟨arr⟩
  simp only [alloc]
  unfold ContainerStore.read
  constructor
  · -- `fid1 = arr.size`; index still below length after second `push`
    have hlt : arr.size < ((arr.push v1).push v2).size := by
      simp only [Array.size_push]; omega
    rw [dif_pos hlt]
    congr 1
    have hpush1 : arr.size < (arr.push v1).size := by
      simp only [Array.size_push]; omega
    rw [Array.getElem_push_lt (h := hpush1)]
    rw [Array.getElem_push_eq]
  · -- `fid2 = (arr.push v1).size`
    have hlt' : (arr.push v1).size < ((arr.push v1).push v2).size := by
      simp only [Array.size_push]; omega
    rw [dif_pos hlt']
    congr 1
    rw [Array.getElem_push_eq]

end MovementFormal.MoveModel.ContainerEvolution
