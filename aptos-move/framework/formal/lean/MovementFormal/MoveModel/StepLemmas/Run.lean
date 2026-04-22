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

/-! ## Multi-step bundle helpers

Chain multiple `run_succ_ok_of_step` applications in a single lemma — reduces the boilerplate
in PC-threading compositions that peel multiple `fuel + 1`s off. -/

/-- Two consecutive OK steps: if step1 at `frame → frame2` and step2 at `frame2 → frame3`,
then `run (fuel+2) on frame` = `run fuel on frame3`. -/
theorem run_succ_two_ok
    (fuel : Nat) (frame2 frame3 : Frame) (cs2 cs3 : List Frame)
    (stack2 stack3 : List MoveValue) (ms2 ms3 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3) :
    run env frame cs stack ms (fuel + 2) =
      run env frame3 cs3 stack3 ms3 fuel := by
  rw [show fuel + 2 = (fuel + 1) + 1 from rfl]
  rw [run_succ_ok_of_step (fuel + 1) frame2 cs2 stack2 ms2 hstep1]
  rw [run_succ_ok_of_step fuel frame3 cs3 stack3 ms3 hstep2]

/-- Three consecutive OK steps. -/
theorem run_succ_three_ok
    (fuel : Nat)
    (frame2 frame3 frame4 : Frame) (cs2 cs3 cs4 : List Frame)
    (stack2 stack3 stack4 : List MoveValue) (ms2 ms3 ms4 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3)
    (hstep3 : step env frame3 cs3 stack3 ms3 = .ok frame4 cs4 stack4 ms4) :
    run env frame cs stack ms (fuel + 3) =
      run env frame4 cs4 stack4 ms4 fuel := by
  rw [show fuel + 3 = (fuel + 2) + 1 from rfl]
  rw [run_succ_ok_of_step (fuel + 2) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_two_ok (env := env) (frame := frame2) (cs := cs2) (stack := stack2) (ms := ms2)
    fuel frame3 frame4 cs3 cs4 stack3 stack4 ms3 ms4 hstep2 hstep3

/-- Consecutive OK then error: succeed at first step, fail at second → `run (fuel+2)` = `.error`. -/
theorem run_succ_ok_then_error
    (fuel : Nat) (frame2 : Frame) (cs2 : List Frame)
    (stack2 : List MoveValue) (ms2 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .error) :
    run env frame cs stack ms (fuel + 2) = .error := by
  rw [show fuel + 2 = (fuel + 1) + 1 from rfl]
  rw [run_succ_ok_of_step (fuel + 1) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_error_of_step fuel hstep2

/-- Consecutive OK then aborted: → `.aborted code`. -/
theorem run_succ_ok_then_aborted
    (fuel : Nat) (frame2 : Frame) (cs2 : List Frame)
    (stack2 : List MoveValue) (ms2 : MachineState) (code : UInt64)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .aborted code) :
    run env frame cs stack ms (fuel + 2) = .aborted code := by
  rw [show fuel + 2 = (fuel + 1) + 1 from rfl]
  rw [run_succ_ok_of_step (fuel + 1) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_aborted_of_step fuel code hstep2

end MovementFormal.MoveModel.StepLemmas
