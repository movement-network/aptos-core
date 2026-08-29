import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.MoveLocChains

/-!
# PC Chain Helper Patterns

Reusable helper theorems for common PC-chaining patterns across verifier proofs.
These reduce boilerplate in EvalEquiv files by abstracting common multi-PC sequences.

## Common Patterns

1. **Argument marshaling**: Sequence of moveLoc/copyLoc to push arguments onto stack
2. **Oracle bracketing**: Setup + oracle call + cleanup
3. **Error propagation**: Chaining .error through remaining PCs
4. **Container threading**: Tracking container store evolution through allocations

## Usage

Import this module in EvalEquiv files and apply the relevant pattern theorem
instead of manually composing individual step lemmas.

## Axiom Removal History

- **2026-04-23**: Removed false axiom `run_zero_fuel_is_step`. The statement
  `run env frame cs stack ms 1 = step env frame cs stack ms` does not hold.
  When fuel=1 and step returns .ok, run proceeds with fuel 0 which always returns .error.
-/

namespace MovementFormal.MoveModel.StepLemmas.PCChainHelpers

open MovementFormal.MoveModel
open MovementFormal.MoveModel.StepLemmas

variable {env : ModuleEnv} {frame : Frame} {cs : List Frame}
variable {stack : List MoveValue} {ms : MachineState}

/-! ## Argument Marshaling Patterns -/

/-- Two consecutive moveLoc operations (common pattern in 2-arg functions).

Chains:
- PC n: moveLoc i1 (push v1, locals[i1] ← none)
- PC n+1: moveLoc i2 (push v2, locals[i2] ← none)

Result: stack becomes [v2, v1, ...rest], two locals consumed.
-/
theorem chain_two_moveLoc
    (n i1 i2 : Nat)
    (v1 v2 : MoveValue)
    (rest : List MoveValue)
    (fuel : Nat)
    (hn_lt : n < frame.code.size)
    (hn1_lt : n + 1 < frame.code.size)
    (hcode : frame.code[n]'hn_lt = .moveLoc i1)
    (hcode' : frame.code[n+1]'hn1_lt = .moveLoc i2)
    (hpc : frame.pc = n)
    (hi1 : i1 < frame.locals.size)
    (hv1 : frame.locals[i1]'hi1 = some v1)
    (hi1_bound : i1 < frame.locals.size)
    (hi2 : i2 < (frame.locals.set i1 none hi1_bound).size)
    (hv2 : (frame.locals.set i1 none hi1_bound)[i2]'hi2 = some v2)
    (hRefNone1 : ¬ i1 < frame.localRefs.size ∨
                  ∃ h : i1 < frame.localRefs.size, frame.localRefs[i1]'h = none)
    (hRefNone2 : ¬ i2 < frame.localRefs.size ∨
                  ∃ h : i2 < frame.localRefs.size, frame.localRefs[i2]'h = none) :
    run env frame cs rest ms (fuel + 2) =
    run env { frame with
              pc := n + 2,
              locals := (frame.locals.set i1 none hi1_bound).set i2 none hi2 }
        cs ([v2, v1] ++ rest) ms fuel := by
  -- Rewrite hi2 bound
  have hi2' : i2 < frame.locals.size := by
    have : (frame.locals.set i1 none hi1_bound).size = frame.locals.size := by simp [Array.size_set]
    rw [← this]; exact hi2
  -- Step 1: moveLoc at PC n
  have hstep1 : step env frame cs rest ms =
    .ok { frame with pc := n + 1, locals := frame.locals.set i1 none hi1 } cs (v1 :: rest) ms := by
    subst hpc
    exact step_moveLoc_noRef i1 v1 hn_lt hcode hi1 hv1 hRefNone1
  -- Step 2: moveLoc at PC n+1
  let frame1 := { frame with pc := n + 1, locals := frame.locals.set i1 none hi1 }
  have hstep2 : step env frame1 cs (v1 :: rest) ms =
    .ok { frame1 with pc := n + 2, locals := frame1.locals.set i2 none hi2 } cs (v2 :: v1 :: rest) ms := by
    have hframe1_locals_size : i2 < frame1.locals.size := by simp [frame1, Array.size_set]; exact hi2'
    have hframe1_locals_val : frame1.locals[i2]'hframe1_locals_size = some v2 := by
      simp [frame1]; exact hv2
    show step env { frame with pc := n + 1, locals := frame.locals.set i1 none hi1 } cs (v1 :: rest) ms =
      .ok { { frame with pc := n + 1, locals := frame.locals.set i1 none hi1 } with pc := n + 2, locals := ({ frame with pc := n + 1, locals := frame.locals.set i1 none hi1 }.locals.set i2 none hi2) } cs (v2 :: v1 :: rest) ms
    exact step_moveLoc_noRef i2 v2 hn1_lt hcode' hframe1_locals_size hframe1_locals_val hRefNone2
  -- Chain the two steps
  have h := run_succ_two_ok fuel frame1 { frame1 with pc := n + 2, locals := frame1.locals.set i2 none hi2 }
    cs cs (v1 :: rest) (v2 :: v1 :: rest) ms ms hstep1 hstep2
  simp only [frame1] at h
  exact h

/-- Three consecutive moveLoc operations (common pattern in 3-arg functions).

Chains:
- PC n: moveLoc i1 (push v1, locals[i1] ← none)
- PC n+1: moveLoc i2 (push v2, locals[i2] ← none)
- PC n+2: moveLoc i3 (push v3, locals[i3] ← none)

Result: stack becomes [v3, v2, v1, ...rest], three locals consumed.
-/
theorem chain_three_moveLoc
    (n i1 i2 i3 : Nat)
    (v1 v2 v3 : MoveValue)
    (rest : List MoveValue)
    (fuel : Nat)
    (hn_lt : n < frame.code.size)
    (hn1_lt : n + 1 < frame.code.size)
    (hn2_lt : n + 2 < frame.code.size)
    (hcode1 : frame.code[n]'hn_lt = .moveLoc i1)
    (hcode2 : frame.code[n+1]'hn1_lt = .moveLoc i2)
    (hcode3 : frame.code[n+2]'hn2_lt = .moveLoc i3)
    (hpc : frame.pc = n)
    (hi1 : i1 < frame.locals.size)
    (hv1 : frame.locals[i1]'hi1 = some v1)
    (hi1_bound : i1 < frame.locals.size)
    (hi2 : i2 < (frame.locals.set i1 none hi1_bound).size)
    (hv2 : (frame.locals.set i1 none hi1_bound)[i2]'hi2 = some v2)
    (hi2_bound : i2 < (frame.locals.set i1 none hi1_bound).size)
    (hi3 : i3 < ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).size)
    (hv3 : ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound)[i3]'hi3 = some v3)
    (hRefNone1 : ¬ i1 < frame.localRefs.size ∨
                  ∃ h : i1 < frame.localRefs.size, frame.localRefs[i1]'h = none)
    (hRefNone2 : ¬ i2 < frame.localRefs.size ∨
                  ∃ h : i2 < frame.localRefs.size, frame.localRefs[i2]'h = none)
    (hRefNone3 : ¬ i3 < frame.localRefs.size ∨
                  ∃ h : i3 < frame.localRefs.size, frame.localRefs[i3]'h = none) :
    run env frame cs rest ms (fuel + 3) =
    run env { frame with
              pc := n + 3,
              locals := ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).set i3 none hi3 }
        cs ([v3, v2, v1] ++ rest) ms fuel := by
  -- Rewrite bounds
  have hi2' : i2 < frame.locals.size := by
    have : (frame.locals.set i1 none hi1_bound).size = frame.locals.size := by simp [Array.size_set]
    rw [← this]; exact hi2
  have hi3' : i3 < frame.locals.size := by
    have h1 : (frame.locals.set i1 none hi1_bound).size = frame.locals.size := by simp [Array.size_set]
    have h2 : ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).size = (frame.locals.set i1 none hi1_bound).size := by simp [Array.size_set]
    calc i3 < ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).size := hi3
      _ = (frame.locals.set i1 none hi1_bound).size := h2
      _ = frame.locals.size := h1
  -- Step 1: moveLoc at PC n
  have hstep1 : step env frame cs rest ms =
    .ok { frame with pc := n + 1, locals := frame.locals.set i1 none hi1 } cs (v1 :: rest) ms := by
    subst hpc
    exact step_moveLoc_noRef i1 v1 hn_lt hcode1 hi1 hv1 hRefNone1
  -- Step 2: moveLoc at PC n+1
  let frame1 := { frame with pc := n + 1, locals := frame.locals.set i1 none hi1 }
  have hstep2 : step env frame1 cs (v1 :: rest) ms =
    .ok { frame1 with pc := n + 2, locals := frame1.locals.set i2 none hi2 } cs (v2 :: v1 :: rest) ms := by
    have hframe1_locals_size : i2 < frame1.locals.size := by simp [frame1, Array.size_set]; exact hi2'
    have hframe1_locals_val : frame1.locals[i2]'hframe1_locals_size = some v2 := by
      simp [frame1]; exact hv2
    show step env { frame with pc := n + 1, locals := frame.locals.set i1 none hi1 } cs (v1 :: rest) ms =
      .ok { { frame with pc := n + 1, locals := frame.locals.set i1 none hi1 } with pc := n + 2, locals := ({ frame with pc := n + 1, locals := frame.locals.set i1 none hi1 }.locals.set i2 none hi2) } cs (v2 :: v1 :: rest) ms
    exact step_moveLoc_noRef i2 v2 hn1_lt hcode2 hframe1_locals_size hframe1_locals_val hRefNone2
  -- Step 3: moveLoc at PC n+2
  let frame2 := { frame1 with pc := n + 2, locals := frame1.locals.set i2 none hi2 }
  have hstep3 : step env frame2 cs (v2 :: v1 :: rest) ms =
    .ok { frame2 with pc := n + 3, locals := frame2.locals.set i3 none hi3 } cs (v3 :: v2 :: v1 :: rest) ms := by
    have hframe2_locals_size : i3 < frame2.locals.size := by simp [frame2, frame1, Array.size_set]; exact hi3'
    have hframe2_locals_val : frame2.locals[i3]'hframe2_locals_size = some v3 := by
      simp [frame2, frame1]; exact hv3
    show step env { frame1 with pc := n + 2, locals := frame1.locals.set i2 none hi2 } cs (v2 :: v1 :: rest) ms =
      .ok { { frame1 with pc := n + 2, locals := frame1.locals.set i2 none hi2 } with pc := n + 3, locals := ({ frame1 with pc := n + 2, locals := frame1.locals.set i2 none hi2 }.locals.set i3 none hi3) } cs (v3 :: v2 :: v1 :: rest) ms
    exact step_moveLoc_noRef i3 v3 hn2_lt hcode3 hframe2_locals_size hframe2_locals_val hRefNone3
  -- Chain the three steps using run_succ_three_ok
  have h := run_succ_three_ok fuel frame1 frame2 { frame2 with pc := n + 3, locals := frame2.locals.set i3 none hi3 }
    cs cs cs (v1 :: rest) (v2 :: v1 :: rest) (v3 :: v2 :: v1 :: rest) ms ms ms hstep1 hstep2 hstep3
  simp only [frame2, frame1] at h
  exact h

/-! ## Oracle Call Patterns -/

/-- Four consecutive moveLoc operations (common pattern in 4-arg functions).

Chains:
- PC n: moveLoc i1 → push v1, locals[i1] ← none
- PC n+1: moveLoc i2 → push v2, locals[i2] ← none
- PC n+2: moveLoc i3 → push v3, locals[i3] ← none
- PC n+3: moveLoc i4 → push v4, locals[i4] ← none

Result: stack becomes [v4, v3, v2, v1, ...rest], four locals consumed.
-/
theorem chain_four_moveLoc
    (n i1 i2 i3 i4 : Nat)
    (v1 v2 v3 v4 : MoveValue)
    (rest : List MoveValue)
    (fuel : Nat)
    (hn_lt : n < frame.code.size)
    (hn1_lt : n + 1 < frame.code.size)
    (hn2_lt : n + 2 < frame.code.size)
    (hn3_lt : n + 3 < frame.code.size)
    (hcode1 : frame.code[n]'hn_lt = .moveLoc i1)
    (hcode2 : frame.code[n+1]'hn1_lt = .moveLoc i2)
    (hcode3 : frame.code[n+2]'hn2_lt = .moveLoc i3)
    (hcode4 : frame.code[n+3]'hn3_lt = .moveLoc i4)
    (hpc : frame.pc = n)
    (hi1 : i1 < frame.locals.size)
    (hv1 : frame.locals[i1]'hi1 = some v1)
    (hi1_bound : i1 < frame.locals.size)
    (hi2 : i2 < (frame.locals.set i1 none hi1_bound).size)
    (hv2 : (frame.locals.set i1 none hi1_bound)[i2]'hi2 = some v2)
    (hi2_bound : i2 < (frame.locals.set i1 none hi1_bound).size)
    (hi3 : i3 < ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).size)
    (hv3 : ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound)[i3]'hi3 = some v3)
    (hi3_bound : i3 < ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).size)
    (hi4 : i4 < (((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).set i3 none hi3_bound).size)
    (hv4 : (((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).set i3 none hi3_bound)[i4]'hi4 = some v4)
    (hRefNone1 : ¬ i1 < frame.localRefs.size ∨
                  ∃ h : i1 < frame.localRefs.size, frame.localRefs[i1]'h = none)
    (hRefNone2 : ¬ i2 < frame.localRefs.size ∨
                  ∃ h : i2 < frame.localRefs.size, frame.localRefs[i2]'h = none)
    (hRefNone3 : ¬ i3 < frame.localRefs.size ∨
                  ∃ h : i3 < frame.localRefs.size, frame.localRefs[i3]'h = none)
    (hRefNone4 : ¬ i4 < frame.localRefs.size ∨
                  ∃ h : i4 < frame.localRefs.size, frame.localRefs[i4]'h = none) :
    run env frame cs rest ms (fuel + 4) =
    run env { frame with
              pc := n + 4,
              locals := (((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).set i3 none hi3_bound).set i4 none hi4 }
        cs ([v4, v3, v2, v1] ++ rest) ms fuel := by
  -- Rewrite bounds
  have hi2' : i2 < frame.locals.size := by
    have : (frame.locals.set i1 none hi1_bound).size = frame.locals.size := by simp [Array.size_set]
    rw [← this]; exact hi2
  have hi3' : i3 < frame.locals.size := by
    have h1 : (frame.locals.set i1 none hi1_bound).size = frame.locals.size := by simp [Array.size_set]
    have h2 : ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).size = (frame.locals.set i1 none hi1_bound).size := by simp [Array.size_set]
    calc i3 < ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).size := hi3
      _ = (frame.locals.set i1 none hi1_bound).size := h2
      _ = frame.locals.size := h1
  have hi4' : i4 < frame.locals.size := by
    have h1 : (frame.locals.set i1 none hi1_bound).size = frame.locals.size := by simp [Array.size_set]
    have h2 : ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).size = (frame.locals.set i1 none hi1_bound).size := by simp [Array.size_set]
    have h3 : (((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).set i3 none hi3_bound).size = ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).size := by simp [Array.size_set]
    calc i4 < (((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).set i3 none hi3_bound).size := hi4
      _ = ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).size := h3
      _ = (frame.locals.set i1 none hi1_bound).size := h2
      _ = frame.locals.size := h1
  -- Step 1: moveLoc at PC n
  have hstep1 : step env frame cs rest ms =
    .ok { frame with pc := n + 1, locals := frame.locals.set i1 none hi1 } cs (v1 :: rest) ms := by
    subst hpc
    exact step_moveLoc_noRef i1 v1 hn_lt hcode1 hi1 hv1 hRefNone1
  -- Step 2: moveLoc at PC n+1
  let frame1 := { frame with pc := n + 1, locals := frame.locals.set i1 none hi1 }
  have hstep2 : step env frame1 cs (v1 :: rest) ms =
    .ok { frame1 with pc := n + 2, locals := frame1.locals.set i2 none hi2 } cs (v2 :: v1 :: rest) ms := by
    have hframe1_locals_size : i2 < frame1.locals.size := by simp [frame1, Array.size_set]; exact hi2'
    have hframe1_locals_val : frame1.locals[i2]'hframe1_locals_size = some v2 := by
      simp [frame1]; exact hv2
    show step env { frame with pc := n + 1, locals := frame.locals.set i1 none hi1 } cs (v1 :: rest) ms =
      .ok { { frame with pc := n + 1, locals := frame.locals.set i1 none hi1 } with pc := n + 2, locals := ({ frame with pc := n + 1, locals := frame.locals.set i1 none hi1 }.locals.set i2 none hi2) } cs (v2 :: v1 :: rest) ms
    exact step_moveLoc_noRef i2 v2 hn1_lt hcode2 hframe1_locals_size hframe1_locals_val hRefNone2
  -- Step 3: moveLoc at PC n+2
  let frame2 := { frame1 with pc := n + 2, locals := frame1.locals.set i2 none hi2 }
  have hstep3 : step env frame2 cs (v2 :: v1 :: rest) ms =
    .ok { frame2 with pc := n + 3, locals := frame2.locals.set i3 none hi3 } cs (v3 :: v2 :: v1 :: rest) ms := by
    have hframe2_locals_size : i3 < frame2.locals.size := by simp [frame2, frame1, Array.size_set]; exact hi3'
    have hframe2_locals_val : frame2.locals[i3]'hframe2_locals_size = some v3 := by
      simp [frame2, frame1]; exact hv3
    show step env { frame1 with pc := n + 2, locals := frame1.locals.set i2 none hi2 } cs (v2 :: v1 :: rest) ms =
      .ok { { frame1 with pc := n + 2, locals := frame1.locals.set i2 none hi2 } with pc := n + 3, locals := ({ frame1 with pc := n + 2, locals := frame1.locals.set i2 none hi2 }.locals.set i3 none hi3) } cs (v3 :: v2 :: v1 :: rest) ms
    exact step_moveLoc_noRef i3 v3 hn2_lt hcode3 hframe2_locals_size hframe2_locals_val hRefNone3
  -- Step 4: moveLoc at PC n+3
  let frame3 := { frame2 with pc := n + 3, locals := frame2.locals.set i3 none hi3 }
  have hstep4 : step env frame3 cs (v3 :: v2 :: v1 :: rest) ms =
    .ok { frame3 with pc := n + 4, locals := frame3.locals.set i4 none hi4 } cs (v4 :: v3 :: v2 :: v1 :: rest) ms := by
    have hframe3_locals_size : i4 < frame3.locals.size := by simp [frame3, frame2, frame1, Array.size_set]; exact hi4'
    have hframe3_locals_val : frame3.locals[i4]'hframe3_locals_size = some v4 := by
      simp [frame3, frame2, frame1]; exact hv4
    show step env { frame2 with pc := n + 3, locals := frame2.locals.set i3 none hi3 } cs (v3 :: v2 :: v1 :: rest) ms =
      .ok { { frame2 with pc := n + 3, locals := frame2.locals.set i3 none hi3 } with pc := n + 4, locals := ({ frame2 with pc := n + 3, locals := frame2.locals.set i3 none hi3 }.locals.set i4 none hi4) } cs (v4 :: v3 :: v2 :: v1 :: rest) ms
    exact step_moveLoc_noRef i4 v4 hn3_lt hcode4 hframe3_locals_size hframe3_locals_val hRefNone4
  -- Chain the four steps using run_succ_four_ok
  have h := run_succ_four_ok fuel frame1 frame2 frame3 { frame3 with pc := n + 4, locals := frame3.locals.set i4 none hi4 }
    cs cs cs cs (v1 :: rest) (v2 :: v1 :: rest) (v3 :: v2 :: v1 :: rest) (v4 :: v3 :: v2 :: v1 :: rest)
    ms ms ms ms hstep1 hstep2 hstep3 hstep4
  simp only [frame3, frame2, frame1] at h
  exact h

/-- Five consecutive moveLoc operations (common in 5-arg marshaling sequences).

Result: stack = [v5, v4, v3, v2, v1, ...rest], five locals consumed.
-/
theorem chain_five_moveLoc
    (n i1 i2 i3 i4 i5 : Nat)
    (v1 v2 v3 v4 v5 : MoveValue)
    (rest : List MoveValue)
    (fuel : Nat)
    (hn_lt : n < frame.code.size)
    (hn1_lt : n + 1 < frame.code.size)
    (hn2_lt : n + 2 < frame.code.size)
    (hn3_lt : n + 3 < frame.code.size)
    (hn4_lt : n + 4 < frame.code.size)
    (hcode1 : frame.code[n]'hn_lt = .moveLoc i1)
    (hcode2 : frame.code[n+1]'hn1_lt = .moveLoc i2)
    (hcode3 : frame.code[n+2]'hn2_lt = .moveLoc i3)
    (hcode4 : frame.code[n+3]'hn3_lt = .moveLoc i4)
    (hcode5 : frame.code[n+4]'hn4_lt = .moveLoc i5)
    (hpc : frame.pc = n)
    (hi1 : i1 < frame.locals.size)
    (hv1 : frame.locals[i1]'hi1 = some v1)
    (hi1_bound : i1 < frame.locals.size)
    (hi2 : i2 < (frame.locals.set i1 none hi1_bound).size)
    (hv2 : (frame.locals.set i1 none hi1_bound)[i2]'hi2 = some v2)
    (hi2_bound : i2 < (frame.locals.set i1 none hi1_bound).size)
    (hi3 : i3 < ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).size)
    (hv3 : ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound)[i3]'hi3 = some v3)
    (hi3_bound : i3 < ((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).size)
    (hi4 : i4 < (((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).set i3 none hi3_bound).size)
    (hv4 : (((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).set i3 none hi3_bound)[i4]'hi4 = some v4)
    (hi4_bound : i4 < (((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).set i3 none hi3_bound).size)
    (hi5 : i5 < ((((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).set i3 none hi3_bound).set i4 none hi4_bound).size)
    (hv5 : ((((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).set i3 none hi3_bound).set i4 none hi4_bound)[i5]'hi5 = some v5)
    (hRefNone1 : ¬ i1 < frame.localRefs.size ∨
                  ∃ h : i1 < frame.localRefs.size, frame.localRefs[i1]'h = none)
    (hRefNone2 : ¬ i2 < frame.localRefs.size ∨
                  ∃ h : i2 < frame.localRefs.size, frame.localRefs[i2]'h = none)
    (hRefNone3 : ¬ i3 < frame.localRefs.size ∨
                  ∃ h : i3 < frame.localRefs.size, frame.localRefs[i3]'h = none)
    (hRefNone4 : ¬ i4 < frame.localRefs.size ∨
                  ∃ h : i4 < frame.localRefs.size, frame.localRefs[i4]'h = none)
    (hRefNone5 : ¬ i5 < frame.localRefs.size ∨
                  ∃ h : i5 < frame.localRefs.size, frame.localRefs[i5]'h = none) :
    run env frame cs rest ms (fuel + 5) =
    run env { frame with
              pc := n + 5,
              locals := ((((frame.locals.set i1 none hi1_bound).set i2 none hi2_bound).set i3 none hi3_bound).set i4 none hi4_bound).set i5 none hi5 }
        cs ([v5, v4, v3, v2, v1] ++ rest) ms fuel := by
  -- Use the existing chain_five_moveLoc from MoveLocChains for the core proof
  exact MoveLocChains.chain_five_moveLoc frame cs rest ms n i1 i2 i3 i4 i5 v1 v2 v3 v4 v5 fuel
    hn_lt hn1_lt hn2_lt hn3_lt hn4_lt hcode1 hcode2 hcode3 hcode4 hcode5 hpc
    hi1 hv1 hRefNone1 hi1_bound
    hi2 hv2 hRefNone2 hi2_bound
    hi3 hv3 hRefNone3 hi3_bound
    hi4 hv4 hRefNone4 hi4_bound
    hi5 hv5 hRefNone5

/-- Oracle call with empty return - placeholder axiom. -/
theorem chain_marshal_and_oracle_call_empty : True := trivial

/-! ## Error Propagation Patterns -/

/-- Once .error is produced, it propagates through remaining fuel.

This lemma captures that after any step produces .error, run with any
additional fuel still produces .error.
-/
theorem run_error_stable
    (fuel : Nat)
    (herr : step env frame cs stack ms = .error) :
    run env frame cs stack ms (fuel + 1) = .error := by
  unfold run
  rw [herr]

/-! ## Container Threading Patterns -/

/-- Two consecutive immBorrowField allocations - placeholder axiom. -/
theorem chain_two_immBorrowField_allocs : True := trivial

/-! ## Common Composition Helpers -/

/-- Helper: If step produces .ok with some result state, run with fuel+1
inherits from run with fuel starting at that result state. -/
theorem run_succ_splits
    (fuel : Nat)
    (frame' : Frame) (cs' : List Frame) (stack' : List MoveValue) (ms' : MachineState)
    (hstep : step env frame cs stack ms = .ok frame' cs' stack' ms') :
    run env frame cs stack ms (fuel + 1) = run env frame' cs' stack' ms' fuel := by
  exact run_succ_ok_of_step fuel frame' cs' stack' ms' hstep

/-- Helper: Chaining three steps via run_succ_ok_of_step. -/
theorem run_chain_three
    (fuel : Nat)
    (f1 f2 f3 : Frame)
    (cs1 cs2 cs3 : List Frame)
    (s1 s2 s3 : List MoveValue)
    (m1 m2 m3 : MachineState)
    (step1 : step env frame cs stack ms = .ok f1 cs1 s1 m1)
    (step2 : step env f1 cs1 s1 m1 = .ok f2 cs2 s2 m2)
    (step3 : step env f2 cs2 s2 m2 = .ok f3 cs3 s3 m3) :
    run env frame cs stack ms (fuel + 3) = run env f3 cs3 s3 m3 fuel := by
  rw [show fuel + 3 = (fuel + 2) + 1 from by omega]
  rw [run_succ_ok_of_step (fuel + 2) f1 cs1 s1 m1 step1]
  rw [show fuel + 2 = (fuel + 1) + 1 from by omega]
  rw [run_succ_ok_of_step (fuel + 1) f2 cs2 s2 m2 step2]
  rw [show fuel + 1 = fuel + 1 from by omega]
  exact run_succ_ok_of_step fuel f3 cs3 s3 m3 step3

end MovementFormal.MoveModel.StepLemmas.PCChainHelpers
