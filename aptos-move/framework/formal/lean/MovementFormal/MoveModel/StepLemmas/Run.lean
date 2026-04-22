import MovementFormal.MoveModel.Step

/-!
# Step lemmas: `run` unfolding helpers

Convenience lemmas for composing per-PC step theorems through `run`'s recursion. Two forms:

- `run_succ_ok` — when `step` returns `.ok`, `run (n+1)` delegates to `run n` on the new frame.
- `run_succ_error` / `_aborted` / `_returned` — when `step` returns a terminal result, `run` passes it through.

These let per-PC chains be written as a sequence of `rw [run_succ_ok_of_step, step_pc_N]` rather than
repeated `unfold run; rw [step]; simp only`.
-/

set_option linter.unusedSimpArgs false

namespace MovementFormal.MoveModel.StepLemmas

open MovementFormal.MoveModel

variable {env : ModuleEnv} {frame : Frame} {cs : List Frame}
variable {stack : List MoveValue} {ms : MachineState}

/-- `run (fuel+1)` when `step` returns `.ok`: delegates to `run fuel` on the new state. -/
theorem run_succ_ok_of_step
    (fuel : Nat) (frame' : Frame) (cs' : List Frame)
    (stack' : List MoveValue) (ms' : MachineState)
    (hstep : step env frame cs stack ms = .ok frame' cs' stack' ms') :
    run env frame cs stack ms (fuel + 1) =
      run env frame' cs' stack' ms' fuel := by
  simp only [run, hstep]

/-- `run (fuel+1)` when `step` returns `.error`: produces `.error`. -/
theorem run_succ_error_of_step
    (fuel : Nat)
    (hstep : step env frame cs stack ms = .error) :
    run env frame cs stack ms (fuel + 1) = .error := by
  simp only [run, hstep]

/-- `run (fuel+1)` when `step` returns `.aborted code`: passes it through. -/
theorem run_succ_aborted_of_step
    (fuel : Nat) (code : UInt64)
    (hstep : step env frame cs stack ms = .aborted code) :
    run env frame cs stack ms (fuel + 1) = .aborted code := by
  simp only [run, hstep]

/-- `run (fuel+1)` when `step` returns `.returned results ms'`: passes it through. -/
theorem run_succ_returned_of_step
    (fuel : Nat) (results : List MoveValue) (ms' : MachineState)
    (hstep : step env frame cs stack ms = .returned results ms') :
    run env frame cs stack ms (fuel + 1) = .returned results ms' := by
  simp only [run, hstep]

/-- `run 0` is always `.error`. -/
@[simp] theorem run_zero : run env frame cs stack ms 0 = .error := rfl

end MovementFormal.MoveModel.StepLemmas
