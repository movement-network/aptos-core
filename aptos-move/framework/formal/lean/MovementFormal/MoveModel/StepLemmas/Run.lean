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

/-! ## Extended multi-step bundle helpers

Additional bundled helpers for 4, 5, 6, 7, and 8 consecutive OK steps. These reduce boilerplate
in PC-chaining proofs for longer instruction sequences, particularly useful for the Phase 4
verifier operations that chain 5+ moveLoc/copyLoc instructions before reaching native calls.

The pattern follows run_succ_three_ok: decompose fuel arithmetic, apply first step, then
delegate to the (n-1)-step helper. -/

/-- Four consecutive OK steps. -/
theorem run_succ_four_ok
    (fuel : Nat)
    (frame2 frame3 frame4 frame5 : Frame)
    (cs2 cs3 cs4 cs5 : List Frame)
    (stack2 stack3 stack4 stack5 : List MoveValue)
    (ms2 ms3 ms4 ms5 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3)
    (hstep3 : step env frame3 cs3 stack3 ms3 = .ok frame4 cs4 stack4 ms4)
    (hstep4 : step env frame4 cs4 stack4 ms4 = .ok frame5 cs5 stack5 ms5) :
    run env frame cs stack ms (fuel + 4) =
      run env frame5 cs5 stack5 ms5 fuel := by
  rw [show fuel + 4 = (fuel + 3) + 1 from by omega]
  rw [run_succ_ok_of_step (fuel + 3) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_three_ok (env := env) (frame := frame2) (cs := cs2) (stack := stack2) (ms := ms2)
    fuel frame3 frame4 frame5 cs3 cs4 cs5 stack3 stack4 stack5 ms3 ms4 ms5 hstep2 hstep3 hstep4

/-- Five consecutive OK steps. -/
theorem run_succ_five_ok
    (fuel : Nat)
    (frame2 frame3 frame4 frame5 frame6 : Frame)
    (cs2 cs3 cs4 cs5 cs6 : List Frame)
    (stack2 stack3 stack4 stack5 stack6 : List MoveValue)
    (ms2 ms3 ms4 ms5 ms6 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3)
    (hstep3 : step env frame3 cs3 stack3 ms3 = .ok frame4 cs4 stack4 ms4)
    (hstep4 : step env frame4 cs4 stack4 ms4 = .ok frame5 cs5 stack5 ms5)
    (hstep5 : step env frame5 cs5 stack5 ms5 = .ok frame6 cs6 stack6 ms6) :
    run env frame cs stack ms (fuel + 5) =
      run env frame6 cs6 stack6 ms6 fuel := by
  rw [show fuel + 5 = (fuel + 4) + 1 from by omega]
  rw [run_succ_ok_of_step (fuel + 4) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_four_ok (env := env) (frame := frame2) (cs := cs2) (stack := stack2) (ms := ms2)
    fuel frame3 frame4 frame5 frame6 cs3 cs4 cs5 cs6
    stack3 stack4 stack5 stack6 ms3 ms4 ms5 ms6 hstep2 hstep3 hstep4 hstep5

/-- Six consecutive OK steps. -/
theorem run_succ_six_ok
    (fuel : Nat)
    (frame2 frame3 frame4 frame5 frame6 frame7 : Frame)
    (cs2 cs3 cs4 cs5 cs6 cs7 : List Frame)
    (stack2 stack3 stack4 stack5 stack6 stack7 : List MoveValue)
    (ms2 ms3 ms4 ms5 ms6 ms7 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3)
    (hstep3 : step env frame3 cs3 stack3 ms3 = .ok frame4 cs4 stack4 ms4)
    (hstep4 : step env frame4 cs4 stack4 ms4 = .ok frame5 cs5 stack5 ms5)
    (hstep5 : step env frame5 cs5 stack5 ms5 = .ok frame6 cs6 stack6 ms6)
    (hstep6 : step env frame6 cs6 stack6 ms6 = .ok frame7 cs7 stack7 ms7) :
    run env frame cs stack ms (fuel + 6) =
      run env frame7 cs7 stack7 ms7 fuel := by
  rw [show fuel + 6 = (fuel + 5) + 1 from by omega]
  rw [run_succ_ok_of_step (fuel + 5) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_five_ok (env := env) (frame := frame2) (cs := cs2) (stack := stack2) (ms := ms2)
    fuel frame3 frame4 frame5 frame6 frame7 cs3 cs4 cs5 cs6 cs7
    stack3 stack4 stack5 stack6 stack7 ms3 ms4 ms5 ms6 ms7 hstep2 hstep3 hstep4 hstep5 hstep6

/-- Seven consecutive OK steps. -/
theorem run_succ_seven_ok
    (fuel : Nat)
    (frame2 frame3 frame4 frame5 frame6 frame7 frame8 : Frame)
    (cs2 cs3 cs4 cs5 cs6 cs7 cs8 : List Frame)
    (stack2 stack3 stack4 stack5 stack6 stack7 stack8 : List MoveValue)
    (ms2 ms3 ms4 ms5 ms6 ms7 ms8 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3)
    (hstep3 : step env frame3 cs3 stack3 ms3 = .ok frame4 cs4 stack4 ms4)
    (hstep4 : step env frame4 cs4 stack4 ms4 = .ok frame5 cs5 stack5 ms5)
    (hstep5 : step env frame5 cs5 stack5 ms5 = .ok frame6 cs6 stack6 ms6)
    (hstep6 : step env frame6 cs6 stack6 ms6 = .ok frame7 cs7 stack7 ms7)
    (hstep7 : step env frame7 cs7 stack7 ms7 = .ok frame8 cs8 stack8 ms8) :
    run env frame cs stack ms (fuel + 7) =
      run env frame8 cs8 stack8 ms8 fuel := by
  rw [show fuel + 7 = (fuel + 6) + 1 from by omega]
  rw [run_succ_ok_of_step (fuel + 6) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_six_ok (env := env) (frame := frame2) (cs := cs2) (stack := stack2) (ms := ms2)
    fuel frame3 frame4 frame5 frame6 frame7 frame8 cs3 cs4 cs5 cs6 cs7 cs8
    stack3 stack4 stack5 stack6 stack7 stack8 ms3 ms4 ms5 ms6 ms7 ms8
    hstep2 hstep3 hstep4 hstep5 hstep6 hstep7

/-- Eight consecutive OK steps. -/
theorem run_succ_eight_ok
    (fuel : Nat)
    (frame2 frame3 frame4 frame5 frame6 frame7 frame8 frame9 : Frame)
    (cs2 cs3 cs4 cs5 cs6 cs7 cs8 cs9 : List Frame)
    (stack2 stack3 stack4 stack5 stack6 stack7 stack8 stack9 : List MoveValue)
    (ms2 ms3 ms4 ms5 ms6 ms7 ms8 ms9 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3)
    (hstep3 : step env frame3 cs3 stack3 ms3 = .ok frame4 cs4 stack4 ms4)
    (hstep4 : step env frame4 cs4 stack4 ms4 = .ok frame5 cs5 stack5 ms5)
    (hstep5 : step env frame5 cs5 stack5 ms5 = .ok frame6 cs6 stack6 ms6)
    (hstep6 : step env frame6 cs6 stack6 ms6 = .ok frame7 cs7 stack7 ms7)
    (hstep7 : step env frame7 cs7 stack7 ms7 = .ok frame8 cs8 stack8 ms8)
    (hstep8 : step env frame8 cs8 stack8 ms8 = .ok frame9 cs9 stack9 ms9) :
    run env frame cs stack ms (fuel + 8) =
      run env frame9 cs9 stack9 ms9 fuel := by
  rw [show fuel + 8 = (fuel + 7) + 1 from by omega]
  rw [run_succ_ok_of_step (fuel + 7) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_seven_ok (env := env) (frame := frame2) (cs := cs2) (stack := stack2) (ms := ms2)
    fuel frame3 frame4 frame5 frame6 frame7 frame8 frame9 cs3 cs4 cs5 cs6 cs7 cs8 cs9
    stack3 stack4 stack5 stack6 stack7 stack8 stack9 ms3 ms4 ms5 ms6 ms7 ms8 ms9
    hstep2 hstep3 hstep4 hstep5 hstep6 hstep7 hstep8

end MovementFormal.MoveModel.StepLemmas
