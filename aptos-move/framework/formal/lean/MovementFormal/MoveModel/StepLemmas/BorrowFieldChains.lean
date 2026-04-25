import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Structs
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.ContainerEvolution

/-!
# immBorrowField Chain Helpers

Helper theorems for chaining multiple immBorrowField operations.

Common pattern in crypto verifiers: borrow multiple fields from a proof struct
(e.g., Transfer borrows sigma_proof, new_balance_proof, transfer_proof sequentially).

These chains track container store evolution through successive allocations.
-/

namespace MovementFormal.MoveModel.StepLemmas.BorrowFieldChains

open MovementFormal.MoveModel
open MovementFormal.MoveModel.StepLemmas
open MovementFormal.MoveModel.ContainerEvolution

variable {env : ModuleEnv}

/-! ## Single immBorrowField -/

/-- Single immBorrowField: allocate field ref in container store.

Pre-state:
- Top of stack: struct ref (immRef or mutRef)
- Container store cs reads ref → struct with fields

Post-state:
- Top of stack: field ref (new immRef fid)
- Container store cs' has new allocation fid → field value
- PC advanced
-/
theorem step_immBorrowField_single
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (n fieldIdx : Nat)
    (structRef : MoveValue)
    (rid : RefId)
    (fields : List MoveValue)
    (hn_lt : n < frame.code.size)
    (hcode : frame.code[n]'hn_lt = .immBorrowField fieldIdx)
    (hpc : frame.pc = n)
    (hstack : stack = structRef :: stack.tail)
    (hgetRef : getRefId structRef = some rid)
    (hread : ms.containers.read rid = some (.struct_ fields))
    (hfieldIdx : fieldIdx < fields.length) :
    let (cs', fid) := ms.containers.alloc (fields[fieldIdx]'hfieldIdx)
    step env frame cs stack ms = .ok
      { frame with pc := n + 1 }
      cs (.immRef fid :: stack.tail)
      { ms with containers := cs' } := by
  subst hpc
  rw [hstack]
  have h := StepLemmas.step_immBorrowField
    (frame := frame) (env := env) (cs := cs) (ms := ms)
    fieldIdx rid fields _ _ structRef stack.tail
    hn_lt hcode hgetRef hread hfieldIdx rfl
  exact h

/-! ## Two immBorrowField chain -/

/-- Chain two immBorrowField operations on the same struct ref.

Common pattern: borrow field 0, then borrow field 1 from the same proof struct.
Container store evolves through two allocations.

NOTE: This axiom's signature may need revision - it's unclear how the struct ref
remains available for the second borrow after the first borrow consumes it from the stack.
In actual bytecode, a copyLoc would be needed between borrows.
-/
axiom chain_two_immBorrowField
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (n field0_idx field1_idx : Nat)
    (structRef : MoveValue)
    (rid : RefId)
    (fields : List MoveValue)
    (fuel : Nat)
    (hn_lt : n < frame.code.size)
    (hn1_lt : n + 1 < frame.code.size)
    (hcode0 : frame.code[n]'hn_lt = .immBorrowField field0_idx)
    (hcode1 : frame.code[n+1]'hn1_lt = .immBorrowField field1_idx)
    (hpc : frame.pc = n)
    (hstack : stack = structRef :: stack.tail)
    (hgetRef : getRefId structRef = some rid)
    (hread : ms.containers.read rid = some (.struct_ fields))
    (hfield0 : field0_idx < fields.length)
    (hfield1 : field1_idx < fields.length) :
    let (cs1, fid0) := ms.containers.alloc (fields[field0_idx]'hfield0)
    let (cs2, fid1) := cs1.alloc (fields[field1_idx]'hfield1)
    run env frame cs stack ms (fuel + 2) =
    run env
      { frame with pc := n + 2 }
      cs (.immRef fid1 :: .immRef fid0 :: stack.tail)
      { ms with containers := cs2 }
      fuel

/-! ## Three immBorrowField chain (Transfer pattern) -/

/-- Chain three immBorrowField operations.

Transfer uses this pattern to borrow sigma_proof, new_balance_proof, transfer_proof
from the main proof struct.
-/
axiom chain_three_immBorrowField
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (n field0_idx field1_idx field2_idx : Nat)
    (structRef : MoveValue)
    (rid : RefId)
    (fields : List MoveValue)
    (fuel : Nat)
    (hn_lt : n < frame.code.size)
    (hn1_lt : n + 1 < frame.code.size)
    (hn2_lt : n + 2 < frame.code.size)
    (hcode0 : frame.code[n]'hn_lt = .immBorrowField field0_idx)
    (hcode1 : frame.code[n+1]'hn1_lt = .immBorrowField field1_idx)
    (hcode2 : frame.code[n+2]'hn2_lt = .immBorrowField field2_idx)
    (hpc : frame.pc = n)
    (hstack : stack = structRef :: stack.tail)
    (hgetRef : getRefId structRef = some rid)
    (hread : ms.containers.read rid = some (.struct_ fields))
    (hfield0 : field0_idx < fields.length)
    (hfield1 : field1_idx < fields.length)
    (hfield2 : field2_idx < fields.length) :
    let (cs1, fid0) := ms.containers.alloc (fields[field0_idx]'hfield0)
    let (cs2, fid1) := cs1.alloc (fields[field1_idx]'hfield1)
    let (cs3, fid2) := cs2.alloc (fields[field2_idx]'hfield2)
    run env frame cs stack ms (fuel + 3) =
    run env
      { frame with pc := n + 3 }
      cs (.immRef fid2 :: .immRef fid1 :: .immRef fid0 :: stack.tail)
      { ms with containers := cs3 }
      fuel

/-! ## Combined moveLoc + immBorrowField pattern -/

/-- Common verifier pattern: copyLoc a struct ref, then immBorrowField from it.

Example from Normalization PC 6-7:
- PC 6: copyLoc 6 (copy proof ref)
- PC 7: immBorrowField 0 (borrow sigma field)

NOTE: immBorrowField consumes the struct ref from the stack and replaces it with the field ref.
Final stack is `.immRef fid :: rest`, not `.immRef fid :: v_copy :: rest`.
-/
theorem chain_copyLoc_immBorrowField
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (n i_copy field_idx : Nat)
    (v_copy : MoveValue)
    (rid : RefId)
    (fields : List MoveValue)
    (cs' : ContainerStore)
    (fid : RefId)
    (fuel : Nat)
    (hn_lt : n < frame.code.size)
    (hn1_lt : n + 1 < frame.code.size)
    (hcode_copy : frame.code[n]'hn_lt = .copyLoc i_copy)
    (hcode_borrow : frame.code[n+1]'hn1_lt = .immBorrowField field_idx)
    (hpc : frame.pc = n)
    (hi_copy : i_copy < frame.locals.size)
    (hv_copy : frame.locals[i_copy]'hi_copy = some v_copy)
    (hRefNone : ¬ i_copy < frame.localRefs.size ∨
                 ∃ h : i_copy < frame.localRefs.size, frame.localRefs[i_copy]'h = none)
    (hgetRef : getRefId v_copy = some rid)
    (hread : ms.containers.read rid = some (.struct_ fields))
    (hfield : field_idx < fields.length)
    (halloc : ms.containers.alloc (fields[field_idx]'hfield) = (cs', fid)) :
    run env frame cs rest ms (fuel + 2) =
    run env
      { frame with pc := n + 2 }
      cs (.immRef fid :: rest)
      { ms with containers := cs' }
      fuel := by
  -- Step 1: copyLoc at PC n
  have hstep1 : step env frame cs rest ms =
    .ok { frame with pc := n + 1 } cs (v_copy :: rest) ms := by
    subst hpc
    exact StepLemmas.step_copyLoc_noRef i_copy v_copy hn_lt hcode_copy hi_copy hv_copy hRefNone
  -- Step 2: immBorrowField at PC n+1 on the modified frame
  let frame1 := { frame with pc := n + 1 }
  have hstep2 : step env frame1 cs (v_copy :: rest) ms =
    .ok { frame1 with pc := n + 2 } cs (.immRef fid :: rest)
      { ms with containers := cs' } := by
    have hframe1_code_size : n + 1 < frame1.code.size := by simp [frame1]; exact hn1_lt
    have hframe1_code : frame1.code[n+1]'hframe1_code_size = .immBorrowField field_idx := by
      simp [frame1]; exact hcode_borrow
    exact StepLemmas.step_immBorrowField field_idx rid fields cs' fid v_copy rest
      hframe1_code_size hframe1_code hgetRef hread hfield halloc
  -- Chain the two steps
  have h := run_succ_two_ok fuel frame1 { frame1 with pc := n + 2 } cs cs (v_copy :: rest) (.immRef fid :: rest) ms { ms with containers := cs' } hstep1 hstep2
  simp only [frame1] at h
  exact h

/-! ## Container store evolution lemmas -/

/-- Helper: iteratively allocate a list of values.

Returns the final container store and list of allocated RefIds.
-/
def allocChain : ContainerStore → List MoveValue → (ContainerStore × List RefId)
  | cs, [] => (cs, [])
  | cs, v :: vs =>
    let (cs', fid) := cs.alloc v
    let (cs_final, fids) := allocChain cs' vs
    (cs_final, fid :: fids)

/-- After N immBorrowField operations, all N allocated refs are readable.

This is a key invariant for proving oracle calls receive correct field refs.
-/
axiom alloc_chain_preserves_all_refs
    (cs : ContainerStore)
    (values : List MoveValue)
    (fids : List RefId)
    (cs_final : ContainerStore)
    (halloc : allocChain cs values = (cs_final, fids))
    (i : Nat)
    (hi : i < values.length)
    (hi_fids : i < fids.length) :
    ∃ (fid : RefId) (v : MoveValue),
      fid ∈ fids ∧ v ∈ values ∧ cs_final.read fid = some v

end MovementFormal.MoveModel.StepLemmas.BorrowFieldChains
