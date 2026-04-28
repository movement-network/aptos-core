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

/-- Nine consecutive OK steps. -/
theorem run_succ_nine_ok
    (fuel : Nat)
    (frame2 frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 : Frame)
    (cs2 cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 : List Frame)
    (stack2 stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 : List MoveValue)
    (ms2 ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3)
    (hstep3 : step env frame3 cs3 stack3 ms3 = .ok frame4 cs4 stack4 ms4)
    (hstep4 : step env frame4 cs4 stack4 ms4 = .ok frame5 cs5 stack5 ms5)
    (hstep5 : step env frame5 cs5 stack5 ms5 = .ok frame6 cs6 stack6 ms6)
    (hstep6 : step env frame6 cs6 stack6 ms6 = .ok frame7 cs7 stack7 ms7)
    (hstep7 : step env frame7 cs7 stack7 ms7 = .ok frame8 cs8 stack8 ms8)
    (hstep8 : step env frame8 cs8 stack8 ms8 = .ok frame9 cs9 stack9 ms9)
    (hstep9 : step env frame9 cs9 stack9 ms9 = .ok frame10 cs10 stack10 ms10) :
    run env frame cs stack ms (fuel + 9) =
      run env frame10 cs10 stack10 ms10 fuel := by
  rw [show fuel + 9 = (fuel + 8) + 1 from by omega]
  rw [run_succ_ok_of_step (fuel + 8) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_eight_ok (env := env) (frame := frame2) (cs := cs2) (stack := stack2) (ms := ms2)
    fuel frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10
    cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10
    stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10
    ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10
    hstep2 hstep3 hstep4 hstep5 hstep6 hstep7 hstep8 hstep9

/-- Ten consecutive OK steps. -/
theorem run_succ_ten_ok
    (fuel : Nat)
    (frame2 frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11 : Frame)
    (cs2 cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 cs11 : List Frame)
    (stack2 stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 stack11 : List MoveValue)
    (ms2 ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 ms11 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3)
    (hstep3 : step env frame3 cs3 stack3 ms3 = .ok frame4 cs4 stack4 ms4)
    (hstep4 : step env frame4 cs4 stack4 ms4 = .ok frame5 cs5 stack5 ms5)
    (hstep5 : step env frame5 cs5 stack5 ms5 = .ok frame6 cs6 stack6 ms6)
    (hstep6 : step env frame6 cs6 stack6 ms6 = .ok frame7 cs7 stack7 ms7)
    (hstep7 : step env frame7 cs7 stack7 ms7 = .ok frame8 cs8 stack8 ms8)
    (hstep8 : step env frame8 cs8 stack8 ms8 = .ok frame9 cs9 stack9 ms9)
    (hstep9 : step env frame9 cs9 stack9 ms9 = .ok frame10 cs10 stack10 ms10)
    (hstep10 : step env frame10 cs10 stack10 ms10 = .ok frame11 cs11 stack11 ms11) :
    run env frame cs stack ms (fuel + 10) =
      run env frame11 cs11 stack11 ms11 fuel := by
  rw [show fuel + 10 = (fuel + 9) + 1 from by omega]
  rw [run_succ_ok_of_step (fuel + 9) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_nine_ok (env := env) (frame := frame2) (cs := cs2) (stack := stack2) (ms := ms2)
    fuel frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11
    cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 cs11
    stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 stack11
    ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 ms11
    hstep2 hstep3 hstep4 hstep5 hstep6 hstep7 hstep8 hstep9 hstep10

/-- Eleven consecutive OK steps. -/
theorem run_succ_eleven_ok
    (fuel : Nat)
    (frame2 frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11 frame12 : Frame)
    (cs2 cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 cs11 cs12 : List Frame)
    (stack2 stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 stack11 stack12 : List MoveValue)
    (ms2 ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 ms11 ms12 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3)
    (hstep3 : step env frame3 cs3 stack3 ms3 = .ok frame4 cs4 stack4 ms4)
    (hstep4 : step env frame4 cs4 stack4 ms4 = .ok frame5 cs5 stack5 ms5)
    (hstep5 : step env frame5 cs5 stack5 ms5 = .ok frame6 cs6 stack6 ms6)
    (hstep6 : step env frame6 cs6 stack6 ms6 = .ok frame7 cs7 stack7 ms7)
    (hstep7 : step env frame7 cs7 stack7 ms7 = .ok frame8 cs8 stack8 ms8)
    (hstep8 : step env frame8 cs8 stack8 ms8 = .ok frame9 cs9 stack9 ms9)
    (hstep9 : step env frame9 cs9 stack9 ms9 = .ok frame10 cs10 stack10 ms10)
    (hstep10 : step env frame10 cs10 stack10 ms10 = .ok frame11 cs11 stack11 ms11)
    (hstep11 : step env frame11 cs11 stack11 ms11 = .ok frame12 cs12 stack12 ms12) :
    run env frame cs stack ms (fuel + 11) =
      run env frame12 cs12 stack12 ms12 fuel := by
  rw [show fuel + 11 = (fuel + 10) + 1 from by omega]
  rw [run_succ_ok_of_step (fuel + 10) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_ten_ok (env := env) (frame := frame2) (cs := cs2) (stack := stack2) (ms := ms2)
    fuel frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11 frame12
    cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 cs11 cs12
    stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 stack11 stack12
    ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 ms11 ms12
    hstep2 hstep3 hstep4 hstep5 hstep6 hstep7 hstep8 hstep9 hstep10 hstep11

/-- Twelve consecutive OK steps. -/
theorem run_succ_twelve_ok
    (fuel : Nat)
    (frame2 frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11 frame12 frame13 : Frame)
    (cs2 cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 cs11 cs12 cs13 : List Frame)
    (stack2 stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 stack11 stack12 stack13 : List MoveValue)
    (ms2 ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 ms11 ms12 ms13 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3)
    (hstep3 : step env frame3 cs3 stack3 ms3 = .ok frame4 cs4 stack4 ms4)
    (hstep4 : step env frame4 cs4 stack4 ms4 = .ok frame5 cs5 stack5 ms5)
    (hstep5 : step env frame5 cs5 stack5 ms5 = .ok frame6 cs6 stack6 ms6)
    (hstep6 : step env frame6 cs6 stack6 ms6 = .ok frame7 cs7 stack7 ms7)
    (hstep7 : step env frame7 cs7 stack7 ms7 = .ok frame8 cs8 stack8 ms8)
    (hstep8 : step env frame8 cs8 stack8 ms8 = .ok frame9 cs9 stack9 ms9)
    (hstep9 : step env frame9 cs9 stack9 ms9 = .ok frame10 cs10 stack10 ms10)
    (hstep10 : step env frame10 cs10 stack10 ms10 = .ok frame11 cs11 stack11 ms11)
    (hstep11 : step env frame11 cs11 stack11 ms11 = .ok frame12 cs12 stack12 ms12)
    (hstep12 : step env frame12 cs12 stack12 ms12 = .ok frame13 cs13 stack13 ms13) :
    run env frame cs stack ms (fuel + 12) =
      run env frame13 cs13 stack13 ms13 fuel := by
  rw [show fuel + 12 = (fuel + 11) + 1 from by omega]
  rw [run_succ_ok_of_step (fuel + 11) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_eleven_ok (env := env) (frame := frame2) (cs := cs2) (stack := stack2) (ms := ms2)
    fuel frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11 frame12 frame13
    cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 cs11 cs12 cs13
    stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 stack11 stack12 stack13
    ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 ms11 ms12 ms13
    hstep2 hstep3 hstep4 hstep5 hstep6 hstep7 hstep8 hstep9 hstep10 hstep11 hstep12

/-- Thirteen consecutive OK steps. -/
theorem run_succ_thirteen_ok
    (fuel : Nat)
    (frame2 frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11 frame12 frame13 frame14 : Frame)
    (cs2 cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 cs11 cs12 cs13 cs14 : List Frame)
    (stack2 stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 stack11 stack12 stack13 stack14 : List MoveValue)
    (ms2 ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 ms11 ms12 ms13 ms14 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3)
    (hstep3 : step env frame3 cs3 stack3 ms3 = .ok frame4 cs4 stack4 ms4)
    (hstep4 : step env frame4 cs4 stack4 ms4 = .ok frame5 cs5 stack5 ms5)
    (hstep5 : step env frame5 cs5 stack5 ms5 = .ok frame6 cs6 stack6 ms6)
    (hstep6 : step env frame6 cs6 stack6 ms6 = .ok frame7 cs7 stack7 ms7)
    (hstep7 : step env frame7 cs7 stack7 ms7 = .ok frame8 cs8 stack8 ms8)
    (hstep8 : step env frame8 cs8 stack8 ms8 = .ok frame9 cs9 stack9 ms9)
    (hstep9 : step env frame9 cs9 stack9 ms9 = .ok frame10 cs10 stack10 ms10)
    (hstep10 : step env frame10 cs10 stack10 ms10 = .ok frame11 cs11 stack11 ms11)
    (hstep11 : step env frame11 cs11 stack11 ms11 = .ok frame12 cs12 stack12 ms12)
    (hstep12 : step env frame12 cs12 stack12 ms12 = .ok frame13 cs13 stack13 ms13)
    (hstep13 : step env frame13 cs13 stack13 ms13 = .ok frame14 cs14 stack14 ms14) :
    run env frame cs stack ms (fuel + 13) =
      run env frame14 cs14 stack14 ms14 fuel := by
  rw [show fuel + 13 = (fuel + 12) + 1 from by omega]
  rw [run_succ_ok_of_step (fuel + 12) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_twelve_ok (env := env) (frame := frame2) (cs := cs2) (stack := stack2) (ms := ms2)
    fuel frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11 frame12 frame13 frame14
    cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 cs11 cs12 cs13 cs14
    stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 stack11 stack12 stack13 stack14
    ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 ms11 ms12 ms13 ms14
    hstep2 hstep3 hstep4 hstep5 hstep6 hstep7 hstep8 hstep9 hstep10 hstep11 hstep12 hstep13

/-- Fourteen consecutive OK steps. -/
theorem run_succ_fourteen_ok
    (fuel : Nat)
    (frame2 frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11 frame12 frame13 frame14 frame15 : Frame)
    (cs2 cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 cs11 cs12 cs13 cs14 cs15 : List Frame)
    (stack2 stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 stack11 stack12 stack13 stack14 stack15 : List MoveValue)
    (ms2 ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 ms11 ms12 ms13 ms14 ms15 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3)
    (hstep3 : step env frame3 cs3 stack3 ms3 = .ok frame4 cs4 stack4 ms4)
    (hstep4 : step env frame4 cs4 stack4 ms4 = .ok frame5 cs5 stack5 ms5)
    (hstep5 : step env frame5 cs5 stack5 ms5 = .ok frame6 cs6 stack6 ms6)
    (hstep6 : step env frame6 cs6 stack6 ms6 = .ok frame7 cs7 stack7 ms7)
    (hstep7 : step env frame7 cs7 stack7 ms7 = .ok frame8 cs8 stack8 ms8)
    (hstep8 : step env frame8 cs8 stack8 ms8 = .ok frame9 cs9 stack9 ms9)
    (hstep9 : step env frame9 cs9 stack9 ms9 = .ok frame10 cs10 stack10 ms10)
    (hstep10 : step env frame10 cs10 stack10 ms10 = .ok frame11 cs11 stack11 ms11)
    (hstep11 : step env frame11 cs11 stack11 ms11 = .ok frame12 cs12 stack12 ms12)
    (hstep12 : step env frame12 cs12 stack12 ms12 = .ok frame13 cs13 stack13 ms13)
    (hstep13 : step env frame13 cs13 stack13 ms13 = .ok frame14 cs14 stack14 ms14)
    (hstep14 : step env frame14 cs14 stack14 ms14 = .ok frame15 cs15 stack15 ms15) :
    run env frame cs stack ms (fuel + 14) =
      run env frame15 cs15 stack15 ms15 fuel := by
  rw [show fuel + 14 = (fuel + 13) + 1 from by omega]
  rw [run_succ_ok_of_step (fuel + 13) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_thirteen_ok (env := env) (frame := frame2) (cs := cs2) (stack := stack2) (ms := ms2)
    fuel frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11 frame12 frame13 frame14 frame15
    cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 cs11 cs12 cs13 cs14 cs15
    stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 stack11 stack12 stack13 stack14 stack15
    ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 ms11 ms12 ms13 ms14 ms15
    hstep2 hstep3 hstep4 hstep5 hstep6 hstep7 hstep8 hstep9 hstep10 hstep11 hstep12 hstep13 hstep14

/-- Fifteen consecutive OK steps. -/
theorem run_succ_fifteen_ok
    (fuel : Nat)
    (frame2 frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11 frame12 frame13 frame14 frame15 frame16 : Frame)
    (cs2 cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 cs11 cs12 cs13 cs14 cs15 cs16 : List Frame)
    (stack2 stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 stack11 stack12 stack13 stack14 stack15 stack16 : List MoveValue)
    (ms2 ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 ms11 ms12 ms13 ms14 ms15 ms16 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3)
    (hstep3 : step env frame3 cs3 stack3 ms3 = .ok frame4 cs4 stack4 ms4)
    (hstep4 : step env frame4 cs4 stack4 ms4 = .ok frame5 cs5 stack5 ms5)
    (hstep5 : step env frame5 cs5 stack5 ms5 = .ok frame6 cs6 stack6 ms6)
    (hstep6 : step env frame6 cs6 stack6 ms6 = .ok frame7 cs7 stack7 ms7)
    (hstep7 : step env frame7 cs7 stack7 ms7 = .ok frame8 cs8 stack8 ms8)
    (hstep8 : step env frame8 cs8 stack8 ms8 = .ok frame9 cs9 stack9 ms9)
    (hstep9 : step env frame9 cs9 stack9 ms9 = .ok frame10 cs10 stack10 ms10)
    (hstep10 : step env frame10 cs10 stack10 ms10 = .ok frame11 cs11 stack11 ms11)
    (hstep11 : step env frame11 cs11 stack11 ms11 = .ok frame12 cs12 stack12 ms12)
    (hstep12 : step env frame12 cs12 stack12 ms12 = .ok frame13 cs13 stack13 ms13)
    (hstep13 : step env frame13 cs13 stack13 ms13 = .ok frame14 cs14 stack14 ms14)
    (hstep14 : step env frame14 cs14 stack14 ms14 = .ok frame15 cs15 stack15 ms15)
    (hstep15 : step env frame15 cs15 stack15 ms15 = .ok frame16 cs16 stack16 ms16) :
    run env frame cs stack ms (fuel + 15) =
      run env frame16 cs16 stack16 ms16 fuel := by
  rw [show fuel + 15 = (fuel + 14) + 1 from by omega]
  rw [run_succ_ok_of_step (fuel + 14) frame2 cs2 stack2 ms2 hstep1]
  exact run_succ_fourteen_ok (env := env) (frame := frame2) (cs := cs2) (stack := stack2) (ms := ms2)
    fuel frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11 frame12 frame13 frame14 frame15 frame16
    cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 cs11 cs12 cs13 cs14 cs15 cs16
    stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 stack11 stack12 stack13 stack14 stack15 stack16
    ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 ms11 ms12 ms13 ms14 ms15 ms16
    hstep2 hstep3 hstep4 hstep5 hstep6 hstep7 hstep8 hstep9 hstep10 hstep11 hstep12 hstep13 hstep14 hstep15

/-- Twenty-four consecutive OK steps (for Transfer). -/
theorem run_succ_twenty_four_ok
    (fuel : Nat)
    (frame2 frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11 frame12 frame13 frame14 frame15 frame16 frame17 frame18 frame19 frame20 frame21 frame22 frame23 frame24 frame25 : Frame)
    (cs2 cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 cs11 cs12 cs13 cs14 cs15 cs16 cs17 cs18 cs19 cs20 cs21 cs22 cs23 cs24 cs25 : List Frame)
    (stack2 stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 stack11 stack12 stack13 stack14 stack15 stack16 stack17 stack18 stack19 stack20 stack21 stack22 stack23 stack24 stack25 : List MoveValue)
    (ms2 ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 ms11 ms12 ms13 ms14 ms15 ms16 ms17 ms18 ms19 ms20 ms21 ms22 ms23 ms24 ms25 : MachineState)
    (hstep1 : step env frame cs stack ms = .ok frame2 cs2 stack2 ms2)
    (hstep2 : step env frame2 cs2 stack2 ms2 = .ok frame3 cs3 stack3 ms3)
    (hstep3 : step env frame3 cs3 stack3 ms3 = .ok frame4 cs4 stack4 ms4)
    (hstep4 : step env frame4 cs4 stack4 ms4 = .ok frame5 cs5 stack5 ms5)
    (hstep5 : step env frame5 cs5 stack5 ms5 = .ok frame6 cs6 stack6 ms6)
    (hstep6 : step env frame6 cs6 stack6 ms6 = .ok frame7 cs7 stack7 ms7)
    (hstep7 : step env frame7 cs7 stack7 ms7 = .ok frame8 cs8 stack8 ms8)
    (hstep8 : step env frame8 cs8 stack8 ms8 = .ok frame9 cs9 stack9 ms9)
    (hstep9 : step env frame9 cs9 stack9 ms9 = .ok frame10 cs10 stack10 ms10)
    (hstep10 : step env frame10 cs10 stack10 ms10 = .ok frame11 cs11 stack11 ms11)
    (hstep11 : step env frame11 cs11 stack11 ms11 = .ok frame12 cs12 stack12 ms12)
    (hstep12 : step env frame12 cs12 stack12 ms12 = .ok frame13 cs13 stack13 ms13)
    (hstep13 : step env frame13 cs13 stack13 ms13 = .ok frame14 cs14 stack14 ms14)
    (hstep14 : step env frame14 cs14 stack14 ms14 = .ok frame15 cs15 stack15 ms15)
    (hstep15 : step env frame15 cs15 stack15 ms15 = .ok frame16 cs16 stack16 ms16)
    (hstep16 : step env frame16 cs16 stack16 ms16 = .ok frame17 cs17 stack17 ms17)
    (hstep17 : step env frame17 cs17 stack17 ms17 = .ok frame18 cs18 stack18 ms18)
    (hstep18 : step env frame18 cs18 stack18 ms18 = .ok frame19 cs19 stack19 ms19)
    (hstep19 : step env frame19 cs19 stack19 ms19 = .ok frame20 cs20 stack20 ms20)
    (hstep20 : step env frame20 cs20 stack20 ms20 = .ok frame21 cs21 stack21 ms21)
    (hstep21 : step env frame21 cs21 stack21 ms21 = .ok frame22 cs22 stack22 ms22)
    (hstep22 : step env frame22 cs22 stack22 ms22 = .ok frame23 cs23 stack23 ms23)
    (hstep23 : step env frame23 cs23 stack23 ms23 = .ok frame24 cs24 stack24 ms24)
    (hstep24 : step env frame24 cs24 stack24 ms24 = .ok frame25 cs25 stack25 ms25) :
    run env frame cs stack ms (fuel + 24) =
      run env frame25 cs25 stack25 ms25 fuel := by
  rw [show fuel + 24 = (fuel + 15) + 9 from by omega]
  rw [run_succ_fifteen_ok (env := env) (frame := frame) (cs := cs) (stack := stack) (ms := ms)
    (fuel + 9) frame2 frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11 frame12 frame13 frame14 frame15 frame16
    cs2 cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10 cs11 cs12 cs13 cs14 cs15 cs16
    stack2 stack3 stack4 stack5 stack6 stack7 stack8 stack9 stack10 stack11 stack12 stack13 stack14 stack15 stack16
    ms2 ms3 ms4 ms5 ms6 ms7 ms8 ms9 ms10 ms11 ms12 ms13 ms14 ms15 ms16
    hstep1 hstep2 hstep3 hstep4 hstep5 hstep6 hstep7 hstep8 hstep9 hstep10 hstep11 hstep12 hstep13 hstep14 hstep15]
  exact run_succ_nine_ok (env := env) (frame := frame16) (cs := cs16) (stack := stack16) (ms := ms16)
    fuel frame17 frame18 frame19 frame20 frame21 frame22 frame23 frame24 frame25
    cs17 cs18 cs19 cs20 cs21 cs22 cs23 cs24 cs25
    stack17 stack18 stack19 stack20 stack21 stack22 stack23 stack24 stack25
    ms17 ms18 ms19 ms20 ms21 ms22 ms23 ms24 ms25
    hstep16 hstep17 hstep18 hstep19 hstep20 hstep21 hstep22 hstep23 hstep24

end MovementFormal.MoveModel.StepLemmas
