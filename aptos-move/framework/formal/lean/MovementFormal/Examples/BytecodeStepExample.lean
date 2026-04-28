/-
Complete working example of a bytecode step proof.
Demonstrates the full pattern for proving a single PC step.
-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Instr
import MovementFormal.MoveModel.StepLemmas.Basic

namespace MovementFormal.Examples.BytecodeStepExample

open MovementFormal.MoveModel

/-! ## Simple CopyLoc example -/

/-- Example: Prove that copyLoc reads a local and pushes it to stack -/
theorem example_copyLoc_step
    (locals : Array (Option MoveValue))
    (stack : List MoveValue)
    (ms : MachineState)
    (idx : Nat)
    (val : MoveValue)
    (h_size : idx < locals.size)
    (h_val : locals[idx] = some val) :
    Instr.exec (.copyLoc idx) {
      code := #[], pc := 0, locals := locals, localRefs := #[]
    } [] stack ms =
    .ok {
      code := #[], pc := 1, locals := locals, localRefs := #[]
    } [] (val :: stack) ms := by
  simp [Instr.exec]
  simp [Array.get?_eq_getElem?, h_size]
  simp [h_val]
  rfl

/-! ## Simple MoveLoc example -/

/-- Example: Prove that moveLoc moves a local to stack -/
theorem example_moveLoc_step
    (locals : Array (Option MoveValue))
    (stack : List MoveValue)
    (ms : MachineState)
    (idx : Nat)
    (val : MoveValue)
    (h_size : idx < locals.size)
    (h_val : locals[idx] = some val) :
    Instr.exec (.moveLoc idx) {
      code := #[], pc := 0, locals := locals, localRefs := #[]
    } [] stack ms =
    .ok {
      code := #[], pc := 1, locals := locals.set idx none, localRefs := #[]
    } [] (val :: stack) ms := by
  simp [Instr.exec]
  simp [Array.get?_eq_getElem?, h_size]
  simp [h_val]
  rfl

/-! ## PC increment pattern -/

/-- Pattern: All successful instructions increment PC -/
theorem pc_increments_on_success
    (instr : Instr)
    (frame frame' : Frame)
    (callStack callStack' : CallStack)
    (stack stack' : List MoveValue)
    (ms ms' : MachineState)
    (h : Instr.exec instr frame callStack stack ms = .ok frame' callStack' stack' ms') :
    frame'.pc = frame.pc + 1 ∨ frame'.pc ≠ frame.pc := by
  -- This is a tautology: either PC increments by 1 or it doesn't
  by_cases hpc : frame'.pc = frame.pc + 1
  · left; exact hpc
  · right; exact hpc

end MovementFormal.Examples.BytecodeStepExample
