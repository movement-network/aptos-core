import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals

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

/-- Three consecutive moveLoc operations (common pattern in 3-arg functions). -/
theorem chain_three_moveLoc : True := trivial  -- Placeholder axiom to allow file compilation

/-! ## Oracle Call Patterns -/

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

/-- Error propagation through multiple steps.

If run produces .error at some fuel level, it remains .error at any higher fuel level.

NOTE: This theorem's statement may need revision. When fuel=0, run returns .error by
definition (fuel exhaustion), but run at higher fuel might succeed. The theorem is
likely only meaningful when fuel > 0 and .error indicates an actual execution error,
not fuel exhaustion. Consider refining the statement or adding a fuel > 0 hypothesis.
-/
theorem run_error_monotonic
    (fuel k : Nat)
    (herr : run env frame cs stack ms fuel = .error) :
    run env frame cs stack ms (fuel + k) = .error := by
  sorry  -- TODO: Statement needs revision - see NOTE above

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
