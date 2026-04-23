import MovementFormal.MoveModel.OpaqueFrames
import MovementFormal.MoveModel.Programs.Withdrawal
import MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv

/-!
# Concrete helper lemmas for Withdrawal composition proof

This module provides concrete-index helpers that work around the array indexing blocker.
Instead of generic lemmas for any index, we prove specific instances for indices 0-7
(the 8 parameters of verify_withdrawal_proof).

## Strategy

Rather than:
```lean
theorem frameAfter_moveLoc_N (idx : Nat) ... -- generic, hits array blocker
```

We prove:
```lean
theorem frameAfter_moveLoc_0 ... -- concrete index 0, works
theorem frameAfter_moveLoc_1 ... -- concrete index 1, works
...
```

These can be used in the composition proof for withdrawal_eval_equiv_functional_sim.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Withdrawal.ConcreteHelpers

open MovementFormal.MoveModel
open MovementFormal.MoveModel.OpaqueFrames
open MovementFormal.MoveModel.Programs.Withdrawal
open MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv

/-! ## Concrete moveLoc helpers for withdrawal (indices 0-5) -/

/-- Helper for moveLoc at index 0 (chainId). -/
def frameAfter_moveLoc_0 (initFrame : Frame) (h : 0 < initFrame.locals.size) : Frame :=
  frameAfterMoveLoc initFrame 0 h

theorem frameAfter_moveLoc_0_pc (initFrame : Frame) (h : 0 < initFrame.locals.size) :
    (frameAfter_moveLoc_0 initFrame h).pc = initFrame.pc + 1 := by
  simp [frameAfter_moveLoc_0, frameAfterMoveLoc_pc]

theorem frameAfter_moveLoc_0_code (initFrame : Frame) (h : 0 < initFrame.locals.size) :
    (frameAfter_moveLoc_0 initFrame h).code = initFrame.code := by
  simp [frameAfter_moveLoc_0, frameAfterMoveLoc_code]

/-- Helper for moveLoc at index 1 (sender). -/
def frameAfter_moveLoc_1 (frame1 : Frame) (h : 1 < frame1.locals.size) : Frame :=
  frameAfterMoveLoc frame1 1 h

theorem frameAfter_moveLoc_1_pc (frame1 : Frame) (h : 1 < frame1.locals.size) :
    (frameAfter_moveLoc_1 frame1 h).pc = frame1.pc + 1 := by
  simp [frameAfter_moveLoc_1, frameAfterMoveLoc_pc]

/-- Helper for moveLoc at index 2 (contract). -/
def frameAfter_moveLoc_2 (frame2 : Frame) (h : 2 < frame2.locals.size) : Frame :=
  frameAfterMoveLoc frame2 2 h

theorem frameAfter_moveLoc_2_pc (frame2 : Frame) (h : 2 < frame2.locals.size) :
    (frameAfter_moveLoc_2 frame2 h).pc = frame2.pc + 1 := by
  simp [frameAfter_moveLoc_2, frameAfterMoveLoc_pc]

/-- Helper for moveLoc at index 3 (ekRef). -/
def frameAfter_moveLoc_3 (frame3 : Frame) (h : 3 < frame3.locals.size) : Frame :=
  frameAfterMoveLoc frame3 3 h

theorem frameAfter_moveLoc_3_pc (frame3 : Frame) (h : 3 < frame3.locals.size) :
    (frameAfter_moveLoc_3 frame3 h).pc = frame3.pc + 1 := by
  simp [frameAfter_moveLoc_3, frameAfterMoveLoc_pc]

/-- Helper for moveLoc at index 4 (amount). -/
def frameAfter_moveLoc_4 (frame4 : Frame) (h : 4 < frame4.locals.size) : Frame :=
  frameAfterMoveLoc frame4 4 h

theorem frameAfter_moveLoc_4_pc (frame4 : Frame) (h : 4 < frame4.locals.size) :
    (frameAfter_moveLoc_4 frame4 h).pc = frame4.pc + 1 := by
  simp [frameAfter_moveLoc_4, frameAfterMoveLoc_pc]

/-- Helper for moveLoc at index 5 (curBalRef). -/
def frameAfter_moveLoc_5 (frame5 : Frame) (h : 5 < frame5.locals.size) : Frame :=
  frameAfterMoveLoc frame5 5 h

theorem frameAfter_moveLoc_5_pc (frame5 : Frame) (h : 5 < frame5.locals.size) :
    (frameAfter_moveLoc_5 frame5 h).pc = frame5.pc + 1 := by
  simp [frameAfter_moveLoc_5, frameAfterMoveLoc_pc]

/-! ## Concrete copyLoc helpers for withdrawal (indices 6-7) -/

/-- Helper for copyLoc at index 6 (newBalRef). -/
def frameAfter_copyLoc_6 (frame6 : Frame) : Frame :=
  frameAfterCopyLoc frame6 6

theorem frameAfter_copyLoc_6_pc (frame6 : Frame) :
    (frameAfter_copyLoc_6 frame6).pc = frame6.pc + 1 := by
  simp [frameAfter_copyLoc_6, frameAfterCopyLoc_pc]

theorem frameAfter_copyLoc_6_locals (frame6 : Frame) :
    (frameAfter_copyLoc_6 frame6).locals = frame6.locals := by
  simp [frameAfter_copyLoc_6, frameAfterCopyLoc_locals]

/-- Helper for copyLoc at index 7 (proofRef). -/
def frameAfter_copyLoc_7 (frame7 : Frame) : Frame :=
  frameAfterCopyLoc frame7 7

theorem frameAfter_copyLoc_7_pc (frame7 : Frame) :
    (frameAfter_copyLoc_7 frame7).pc = frame7.pc + 1 := by
  simp [frameAfter_copyLoc_7, frameAfterCopyLoc_pc]

theorem frameAfter_copyLoc_7_locals (frame7 : Frame) :
    (frameAfter_copyLoc_7 frame7).locals = frame7.locals := by
  simp [frameAfter_copyLoc_7, frameAfterCopyLoc_locals]

/-! ## Concrete immBorrowField helpers -/

/-- Helper for immBorrowField (no index variation, just PC advancement). -/
def frameAfter_immBorrowField_8 (frame8 : Frame) : Frame :=
  frameAfterImmBorrowField frame8

theorem frameAfter_immBorrowField_8_pc (frame8 : Frame) :
    (frameAfter_immBorrowField_8 frame8).pc = frame8.pc + 1 := by
  simp [frameAfter_immBorrowField_8, frameAfterImmBorrowField_pc]

def frameAfter_immBorrowField_12 (frame12 : Frame) : Frame :=
  frameAfterImmBorrowField frame12

theorem frameAfter_immBorrowField_12_pc (frame12 : Frame) :
    (frameAfter_immBorrowField_12 frame12).pc = frame12.pc + 1 := by
  simp [frameAfter_immBorrowField_12, frameAfterImmBorrowField_pc]

/-! ## Concrete call helpers -/

/-- Helper for call at PC 9 (verifySigmaProof). -/
def frameAfter_call_9 (frame9 : Frame) : Frame :=
  frameAfterCall frame9

theorem frameAfter_call_9_pc (frame9 : Frame) :
    (frameAfter_call_9 frame9).pc = frame9.pc + 1 := by
  simp [frameAfter_call_9, frameAfterCall_pc]

/-- Helper for call at PC 13 (verifyRangeProof). -/
def frameAfter_call_13 (frame13 : Frame) : Frame :=
  frameAfterCall frame13

theorem frameAfter_call_13_pc (frame13 : Frame) :
    (frameAfter_call_13 frame13).pc = frame13.pc + 1 := by
  simp [frameAfter_call_13, frameAfterCall_pc]

/-! ## Chained helpers for withdrawal pattern -/

/-- Chain PCs 0-5: six consecutive moveLocs. -/
def frameAfter_moveLocs_0_to_5 (initFrame : Frame)
    (h0 : 0 < initFrame.locals.size)
    (h1 : 1 < (frameAfter_moveLoc_0 initFrame h0).locals.size)
    (h2 : 2 < (frameAfter_moveLoc_1 (frameAfter_moveLoc_0 initFrame h0) h1).locals.size)
    (h3 : 3 < (frameAfter_moveLoc_2 (frameAfter_moveLoc_1 (frameAfter_moveLoc_0 initFrame h0) h1) h2).locals.size)
    (h4 : 4 < (frameAfter_moveLoc_3 (frameAfter_moveLoc_2 (frameAfter_moveLoc_1 (frameAfter_moveLoc_0 initFrame h0) h1) h2) h3).locals.size)
    (h5 : 5 < (frameAfter_moveLoc_4 (frameAfter_moveLoc_3 (frameAfter_moveLoc_2 (frameAfter_moveLoc_1 (frameAfter_moveLoc_0 initFrame h0) h1) h2) h3) h4).locals.size) : Frame :=
  frameAfter_moveLoc_5
    (frameAfter_moveLoc_4
      (frameAfter_moveLoc_3
        (frameAfter_moveLoc_2
          (frameAfter_moveLoc_1
            (frameAfter_moveLoc_0 initFrame h0)
            h1)
          h2)
        h3)
      h4)
    h5

theorem frameAfter_moveLocs_0_to_5_pc (initFrame : Frame)
    (h0 : 0 < initFrame.locals.size)
    (h1 : 1 < (frameAfter_moveLoc_0 initFrame h0).locals.size)
    (h2 : 2 < (frameAfter_moveLoc_1 (frameAfter_moveLoc_0 initFrame h0) h1).locals.size)
    (h3 : 3 < (frameAfter_moveLoc_2 (frameAfter_moveLoc_1 (frameAfter_moveLoc_0 initFrame h0) h1) h2).locals.size)
    (h4 : 4 < (frameAfter_moveLoc_3 (frameAfter_moveLoc_2 (frameAfter_moveLoc_1 (frameAfter_moveLoc_0 initFrame h0) h1) h2) h3).locals.size)
    (h5 : 5 < (frameAfter_moveLoc_4 (frameAfter_moveLoc_3 (frameAfter_moveLoc_2 (frameAfter_moveLoc_1 (frameAfter_moveLoc_0 initFrame h0) h1) h2) h3) h4).locals.size) :
    (frameAfter_moveLocs_0_to_5 initFrame h0 h1 h2 h3 h4 h5).pc = initFrame.pc + 6 := by
  simp [frameAfter_moveLocs_0_to_5,
        frameAfter_moveLoc_5_pc, frameAfter_moveLoc_4_pc, frameAfter_moveLoc_3_pc,
        frameAfter_moveLoc_2_pc, frameAfter_moveLoc_1_pc, frameAfter_moveLoc_0_pc]

/-- Chain PCs 6-7: two consecutive copyLocs. -/
def frameAfter_copyLocs_6_to_7 (frame6 : Frame) : Frame :=
  frameAfter_copyLoc_7 (frameAfter_copyLoc_6 frame6)

theorem frameAfter_copyLocs_6_to_7_pc (frame6 : Frame) :
    (frameAfter_copyLocs_6_to_7 frame6).pc = frame6.pc + 2 := by
  simp [frameAfter_copyLocs_6_to_7, frameAfter_copyLoc_7_pc, frameAfter_copyLoc_6_pc]

theorem frameAfter_copyLocs_6_to_7_locals (frame6 : Frame) :
    (frameAfter_copyLocs_6_to_7 frame6).locals = frame6.locals := by
  simp [frameAfter_copyLocs_6_to_7, frameAfter_copyLoc_7_locals, frameAfter_copyLoc_6_locals]

/-! ## Integration with step theorems

These show how to use concrete helpers with the existing step theorems.

Example pattern:
```lean
have hstep0 := step_withdrawal_pc0 o initFrame [] [] initMs ...
have frame1 := frameAfter_moveLoc_0 initFrame (by decide)
-- Now can use frame1 in subsequent steps without array indexing errors
```
-/

/-! ## Usage in composition proof

The concrete helpers allow the composition proof to avoid the array indexing blocker:

```lean
theorem withdrawal_eval_equiv_functional_sim ... := by
  rw [eval_withdrawal_eq_run]

  -- Initial frame
  let initFrame : Frame := { code := verifyWithdrawalProofCode, pc := 0,
                             locals := #[some (.u8 chainId), some (.address sender), ...],
                             localRefs := #[] }

  -- PCs 0-5: Use chained helper
  let frame6 := frameAfter_moveLocs_0_to_5 initFrame (by decide) (by decide) ...
  have hpc6 : frame6.pc = 6 := by
    simp [frame6]; apply frameAfter_moveLocs_0_to_5_pc

  -- PCs 6-7: Use chained helper
  let frame8 := frameAfter_copyLocs_6_to_7 frame6
  have hpc8 : frame8.pc = 8 := by
    simp [frame8]; rw [frameAfter_copyLocs_6_to_7_pc, hpc6]; decide

  -- Now can apply step theorems without hitting the blocker
  have hstep8 := step_withdrawal_pc8 o frame8 [] stack8 ms8 ...
  ...
```

This avoids the "free variable constraint" error by using concrete defs instead
of generic array manipulation.
-/

end MovementFormal.Experimental.ConfidentialAsset.Withdrawal.ConcreteHelpers
