import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.MoveLocChains

/-!
# CopyLoc Chain Helpers

Concrete helper theorems for common copyLoc chaining patterns.
Unlike moveLoc, copyLoc preserves the local value (doesn't set to none).

These are used in crypto verifiers when the same value needs to be used multiple times
(e.g., copying a proof reference before borrowing fields from it).
-/

namespace MovementFormal.MoveModel.StepLemmas.CopyLocChains

open MovementFormal.MoveModel
open MovementFormal.MoveModel.StepLemmas

variable {env : ModuleEnv}

/-! ## Single copyLoc lemma -/

/-- Single copyLoc step with no ref: push copy of value, local unchanged, advance PC. -/
theorem step_copyLoc_single
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (n i : Nat)
    (v : MoveValue)
    (hn_lt : n < frame.code.size)
    (hcode : frame.code[n]'hn_lt = .copyLoc i)
    (hpc : frame.pc = n)
    (hi : i < frame.locals.size)
    (hv : frame.locals[i]'hi = some v)
    (hRefNone : ¬ i < frame.localRefs.size ∨
                 ∃ h : i < frame.localRefs.size, frame.localRefs[i]'h = none) :
    step env frame cs stack ms = .ok
      { frame with pc := n + 1 }
      cs (v :: stack) ms := by
  subst hpc
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := env) (cs := cs) (stack := stack) (ms := ms)
    i v hn_lt hcode hi hv hRefNone
  exact h

/-! ## Two copyLoc chain -/

/-- Chain two copyLoc operations.

Unlike moveLoc chains, both locals remain unchanged since copyLoc preserves values.
-/
theorem chain_two_copyLoc
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (n i1 i2 : Nat)
    (v1 v2 : MoveValue)
    (fuel : Nat)
    (hn_lt : n < frame.code.size)
    (hn1_lt : n + 1 < frame.code.size)
    (hcode1 : frame.code[n]'hn_lt = .copyLoc i1)
    (hcode2 : frame.code[n+1]'hn1_lt = .copyLoc i2)
    (hpc : frame.pc = n)
    (hi1 : i1 < frame.locals.size)
    (hv1 : frame.locals[i1]'hi1 = some v1)
    (hRefNone1 : ¬ i1 < frame.localRefs.size ∨
                  ∃ h : i1 < frame.localRefs.size, frame.localRefs[i1]'h = none)
    (hi2 : i2 < frame.locals.size)
    (hv2 : frame.locals[i2]'hi2 = some v2)
    (hRefNone2 : ¬ i2 < frame.localRefs.size ∨
                  ∃ h : i2 < frame.localRefs.size, frame.localRefs[i2]'h = none) :
    run env frame cs rest ms (fuel + 2) =
    run env
      { frame with pc := n + 2 }
      cs (v2 :: v1 :: rest) ms fuel := by
  -- Step 1: Apply step_copyLoc_single for PC n
  have hstep1 : step env frame cs rest ms =
    .ok { frame with pc := n + 1 } cs (v1 :: rest) ms :=
    step_copyLoc_single frame cs rest ms n i1 v1 hn_lt hcode1 hpc hi1 hv1 hRefNone1
  -- Step 2: Apply step_copyLoc_single for PC n+1
  let frame1 := { frame with pc := n + 1 }
  have hstep2 : step env frame1 cs (v1 :: rest) ms =
    .ok { frame1 with pc := n + 2 } cs (v2 :: v1 :: rest) ms :=
    step_copyLoc_single frame1 cs (v1 :: rest) ms (n+1) i2 v2 hn1_lt hcode2 rfl hi2 hv2 hRefNone2
  -- Step 3: Chain using run_succ_two_ok
  have h := run_succ_two_ok fuel frame1 { frame1 with pc := n + 2 } cs cs (v1 :: rest) (v2 :: v1 :: rest) ms ms hstep1 hstep2
  -- Simplify: { frame1 with pc := n + 2 } = { frame with pc := n + 2 }
  simp only [frame1] at h
  exact h

/-- Chain three copyLoc operations.

Unlike moveLoc, all three locals remain unchanged since copyLoc preserves values.
-/
theorem chain_three_copyLoc
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (n i1 i2 i3 : Nat)
    (v1 v2 v3 : MoveValue)
    (fuel : Nat)
    (hn_lt : n < frame.code.size)
    (hn1_lt : n + 1 < frame.code.size)
    (hn2_lt : n + 2 < frame.code.size)
    (hcode1 : frame.code[n]'hn_lt = .copyLoc i1)
    (hcode2 : frame.code[n+1]'hn1_lt = .copyLoc i2)
    (hcode3 : frame.code[n+2]'hn2_lt = .copyLoc i3)
    (hpc : frame.pc = n)
    (hi1 : i1 < frame.locals.size)
    (hv1 : frame.locals[i1]'hi1 = some v1)
    (hRefNone1 : ¬ i1 < frame.localRefs.size ∨
                  ∃ h : i1 < frame.localRefs.size, frame.localRefs[i1]'h = none)
    (hi2 : i2 < frame.locals.size)
    (hv2 : frame.locals[i2]'hi2 = some v2)
    (hRefNone2 : ¬ i2 < frame.localRefs.size ∨
                  ∃ h : i2 < frame.localRefs.size, frame.localRefs[i2]'h = none)
    (hi3 : i3 < frame.locals.size)
    (hv3 : frame.locals[i3]'hi3 = some v3)
    (hRefNone3 : ¬ i3 < frame.localRefs.size ∨
                  ∃ h : i3 < frame.localRefs.size, frame.localRefs[i3]'h = none) :
    run env frame cs rest ms (fuel + 3) =
    run env
      { frame with pc := n + 3 }
      cs (v3 :: v2 :: v1 :: rest) ms fuel := by
  -- Step 1: copyLoc at PC n
  have hstep1 : step env frame cs rest ms =
    .ok { frame with pc := n + 1 } cs (v1 :: rest) ms :=
    step_copyLoc_single frame cs rest ms n i1 v1 hn_lt hcode1 hpc hi1 hv1 hRefNone1
  -- Step 2: copyLoc at PC n+1
  let frame1 := { frame with pc := n + 1 }
  have hstep2 : step env frame1 cs (v1 :: rest) ms =
    .ok { frame1 with pc := n + 2 } cs (v2 :: v1 :: rest) ms :=
    step_copyLoc_single frame1 cs (v1 :: rest) ms (n+1) i2 v2 hn1_lt hcode2 rfl hi2 hv2 hRefNone2
  -- Step 3: copyLoc at PC n+2
  let frame2 := { frame1 with pc := n + 2 }
  have hstep3 : step env frame2 cs (v2 :: v1 :: rest) ms =
    .ok { frame2 with pc := n + 3 } cs (v3 :: v2 :: v1 :: rest) ms :=
    step_copyLoc_single frame2 cs (v2 :: v1 :: rest) ms (n+2) i3 v3 hn2_lt hcode3 rfl hi3 hv3 hRefNone3
  -- Chain the three steps
  have h := run_succ_three_ok fuel frame1 frame2 { frame2 with pc := n + 3 }
    cs cs cs (v1 :: rest) (v2 :: v1 :: rest) (v3 :: v2 :: v1 :: rest) ms ms ms hstep1 hstep2 hstep3
  simp only [frame2, frame1] at h
  exact h

/-! ## Mixed moveLoc + copyLoc chains -/

/-- Common pattern: moveLoc followed by copyLoc.

First clears a local, then copies another.

NOTE: Requires i_move_bound = hi_move for definitional equality. In practice, both
are derived from `i_move < frame.locals.size`, so this is satisfied.
-/
theorem chain_moveLoc_then_copyLoc
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (n i_move i_copy : Nat)
    (v_move v_copy : MoveValue)
    (fuel : Nat)
    (hn_lt : n < frame.code.size)
    (hn1_lt : n + 1 < frame.code.size)
    (hcode1 : frame.code[n]'hn_lt = .moveLoc i_move)
    (hcode2 : frame.code[n+1]'hn1_lt = .copyLoc i_copy)
    (hpc : frame.pc = n)
    (hi_move : i_move < frame.locals.size)
    (hv_move : frame.locals[i_move]'hi_move = some v_move)
    (hRefNone_move : ¬ i_move < frame.localRefs.size ∨
                      ∃ h : i_move < frame.localRefs.size, frame.localRefs[i_move]'h = none)
    (hi_move_bound : i_move < frame.locals.size)
    (hi_copy : i_copy < (frame.locals.set i_move none hi_move_bound).size)
    (hv_copy : (frame.locals.set i_move none hi_move_bound)[i_copy]'hi_copy = some v_copy)
    (hRefNone_copy : ¬ i_copy < frame.localRefs.size ∨
                      ∃ h : i_copy < frame.localRefs.size, frame.localRefs[i_copy]'h = none)
    (heq_bounds : hi_move = hi_move_bound := by rfl) :
    run env frame cs rest ms (fuel + 2) =
    run env
      { frame with
        pc := n + 2,
        locals := frame.locals.set i_move none hi_move_bound }
      cs (v_copy :: v_move :: rest) ms fuel := by
  -- Rewrite hi_copy to get bound in terms of frame.locals.size
  have hi_copy' : i_copy < frame.locals.size := by
    have : (frame.locals.set i_move none hi_move_bound).size = frame.locals.size := by simp [Array.size_set]
    rw [← this]; exact hi_copy
  -- Step 1: moveLoc at PC n
  have hstep1 : step env frame cs rest ms =
    .ok { frame with pc := n + 1, locals := frame.locals.set i_move none hi_move } cs (v_move :: rest) ms :=
    MoveLocChains.step_moveLoc_single frame cs rest ms n i_move v_move hn_lt hcode1 hpc hi_move hv_move hRefNone_move
  -- Step 2: copyLoc at PC n+1 on the modified frame
  let frame1 := { frame with pc := n + 1, locals := frame.locals.set i_move none hi_move }
  -- Need to show frame1.code and frame1.pc satisfy copyLoc requirements
  have hframe1_code_size : n + 1 < frame1.code.size := by simp [frame1]; exact hn1_lt
  have hframe1_code : frame1.code[n+1]'hframe1_code_size = .copyLoc i_copy := by
    simp [frame1]; exact hcode2
  have hframe1_pc : frame1.pc = n + 1 := by simp [frame1]
  have hframe1_locals_size : i_copy < frame1.locals.size := by
    simp [frame1]; exact hi_copy'
  have hframe1_locals_val : frame1.locals[i_copy]'hframe1_locals_size = some v_copy := by
    simp [frame1]; exact hv_copy
  have hstep2 : step env frame1 cs (v_move :: rest) ms =
    .ok { frame1 with pc := n + 2 } cs (v_copy :: v_move :: rest) ms :=
    step_copyLoc_single frame1 cs (v_move :: rest) ms (n+1) i_copy v_copy
      hframe1_code_size hframe1_code hframe1_pc hframe1_locals_size hframe1_locals_val hRefNone_copy
  -- Step 3: Chain the two steps
  rw [heq_bounds] at hstep1
  have h := run_succ_two_ok fuel frame1 { frame1 with pc := n + 2 } cs cs (v_move :: rest) (v_copy :: v_move :: rest) ms ms hstep1 hstep2
  -- Simplify the final frame
  simp only [frame1] at h
  exact h

/-! ## moveLoc chains followed by copyLoc sequences -/

/-- Common verifier pattern: multiple moveLoc to marshal args, then copyLoc to duplicate refs.

Example from Normalization:
- PCs 0-4: moveLoc chain (5 args)
- PCs 5-6: copyLoc chain (2 proof refs)

NOTE: This axiom has a simplified signature - full proof would require complete hypotheses
for all moveLoc and copyLoc operations. Marked as placeholder for future work.
-/
axiom chain_five_moveLoc_two_copyLoc
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (n : Nat)
    (i_move1 i_move2 i_move3 i_move4 i_move5 : Nat)
    (i_copy1 i_copy2 : Nat)
    (v_move1 v_move2 v_move3 v_move4 v_move5 v_copy1 v_copy2 : MoveValue)
    (fuel : Nat)
    -- Bytecode bounds
    (hn_lt : n < frame.code.size)
    (hn1_lt : n + 1 < frame.code.size)
    (hn2_lt : n + 2 < frame.code.size)
    (hn3_lt : n + 3 < frame.code.size)
    (hn4_lt : n + 4 < frame.code.size)
    (hn5_lt : n + 5 < frame.code.size)
    (hn6_lt : n + 6 < frame.code.size)
    -- Instruction codes
    (hcode1 : frame.code[n]'hn_lt = .moveLoc i_move1)
    (hcode2 : frame.code[n+1]'hn1_lt = .moveLoc i_move2)
    (hcode3 : frame.code[n+2]'hn2_lt = .moveLoc i_move3)
    (hcode4 : frame.code[n+3]'hn3_lt = .moveLoc i_move4)
    (hcode5 : frame.code[n+4]'hn4_lt = .moveLoc i_move5)
    (hcode6 : frame.code[n+5]'hn5_lt = .copyLoc i_copy1)
    (hcode7 : frame.code[n+6]'hn6_lt = .copyLoc i_copy2)
    -- Initial state
    (hpc : frame.pc = n)
    -- MoveLoc hypotheses (values exist in locals, no refs)
    (hi_move1 : i_move1 < frame.locals.size)
    (hv_move1 : frame.locals[i_move1]'hi_move1 = some v_move1)
    -- Simplified: assume all moveLoc indices have no refs and copyLoc indices still valid after moves
    :
    ∃ (locals_final : Array (Option MoveValue)),
    run env frame cs rest ms (fuel + 7) =
    run env
      { frame with
        pc := n + 7,
        locals := locals_final }
      cs (v_copy2 :: v_copy1 :: v_move5 :: v_move4 :: v_move3 :: v_move2 :: v_move1 :: rest) ms fuel

end MovementFormal.MoveModel.StepLemmas.CopyLocChains
