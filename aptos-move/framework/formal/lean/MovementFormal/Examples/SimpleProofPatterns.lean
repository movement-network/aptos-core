/-
Working examples demonstrating proof patterns for CA verification.
These are complete, compilable proofs showing common patterns.
-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Instr
import MovementFormal.MoveModel.ProofPatterns

namespace MovementFormal.Examples.SimpleProofPatterns

open MovementFormal.MoveModel
open MovementFormal.MoveModel.ProofPatterns

/-! ## Example 1: Fuel arithmetic -/

example (fuel : Nat) (h : fuel ≥ 10) : fuel ≥ 1 :=
  fuel_ge_succ_of_ge_n (by omega : fuel ≥ 1)

example (fuel : Nat) (h : fuel ≥ 5) : fuel - 1 ≥ 4 :=
  fuel_sub_one_ge_of_ge_succ h

/-! ## Example 2: Stack manipulation -/

example : ([42].head? : Option Nat) = some 42 :=
  stack_cons_head 42 []

example : ([1, 2, 3].tail : List Nat) = [2, 3] :=
  stack_cons_tail 1 [2, 3]

/-! ## Example 3: Frame updates preserve structure -/

example (f : Frame) (newPc : Nat) :
    { f with pc := newPc }.locals = f.locals :=
  frame_update_pc_preserves_locals

example (f : Frame) (newPc : Nat) :
    { f with pc := newPc }.code = f.code :=
  frame_update_pc_preserves_code

/-! ## Example 4: MachineState updates -/

example (ms : MachineState) (cs : ContainerStore) :
    { ms with containers := cs }.globals = ms.globals :=
  machine_update_containers_preserves_globals

/-! ## Example 5: Match reduction -/

example : (match some ([], 42) with
           | some ([], x) => x + 1
           | _ => 0) = 43 :=
  match_some_empty_reduces 42 (fun _ x => x + 1) 0

example : (match (none : Option (List Nat × Nat)) with
           | some _ => 1
           | none => 42) = 42 :=
  match_none_reduces 42 1

/-! ## Example 6: Combining patterns for run chain proof -/

/-- Example of a simple PC increment proof using the patterns -/
example (f : Frame) (ms : MachineState) :
    { { f with pc := f.pc + 1 } with pc := f.pc + 2 }.locals = f.locals := by
  rw [frame_update_pc_preserves_locals, frame_update_pc_preserves_locals]

/-- Example of container update preserving globals -/
example (ms1 ms2 : MachineState) (cs1 cs2 : ContainerStore) :
    { { ms1 with containers := cs1 } with containers := cs2 }.globals = ms1.globals := by
  rw [machine_update_containers_preserves_globals, machine_update_containers_preserves_globals]

end MovementFormal.Examples.SimpleProofPatterns
