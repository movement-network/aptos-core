/-
Reusable proof patterns for bytecode verification.

Common lemmas and patterns that appear repeatedly in EvalEquiv proofs.
-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Instr

namespace MovementFormal.MoveModel.ProofPatterns

open MovementFormal.MoveModel

/-! ## Fuel arithmetic lemmas -/

theorem fuel_ge_succ_of_ge_n {fuel n : Nat} (h : fuel ≥ n + 1) : fuel ≥ 1 := by omega

theorem fuel_sub_one_ge_of_ge_succ {fuel n : Nat} (h : fuel ≥ n + 1) : fuel - 1 ≥ n := by omega

theorem fuel_sub_n_add_n {fuel n : Nat} (h : fuel ≥ n) : (fuel - n) + n = fuel := by omega

/-! ## Stack manipulation lemmas -/

theorem stack_cons_head {α : Type u} (x : α) (xs : List α) : (x :: xs).head? = some x := rfl

theorem stack_cons_tail {α : Type u} (x : α) (xs : List α) : (x :: xs).tail = xs := rfl

theorem stack_length_cons {α : Type u} (x : α) (xs : List α) :
    (x :: xs).length = xs.length + 1 := by simp [List.length_cons]

/-! ## Frame update lemmas -/

theorem frame_update_pc_preserves_locals {f : Frame} {pc : Nat} :
    { f with pc := pc }.locals = f.locals := rfl

theorem frame_update_pc_preserves_code {f : Frame} {pc : Nat} :
    { f with pc := pc }.code = f.code := rfl

/-! ## MachineState update lemmas -/

theorem machine_update_containers_preserves_globals {ms : MachineState} {cs : ContainerStore} :
    { ms with containers := cs }.globals = ms.globals := rfl

theorem machine_update_globals_preserves_containers {ms : MachineState} {g : GlobalStore} :
    { ms with globals := g }.containers = ms.containers := rfl

/-! ## Oracle and match reduction helpers -/

theorem match_some_empty_reduces {α : Type u} {β : Type v} (x : β)
    (f : List α → β → γ) (g : γ) :
    (match some ([], x) with
     | some ([], y) => f [] y
     | _ => g) = f [] x := rfl

theorem match_none_reduces {α : Type u} (g : α) (f : α) :
    (match none with
     | some _ => f
     | none => g) = g := rfl

/-! ## Locals access lemmas -/

theorem locals_get_of_bounds {arr : Array (Option α)} {i : Nat} (h : i < arr.size) :
    arr[i]?.isSome = true ↔ arr[i]'h ≠ none := by
  simp [Array.get?_eq_getElem?]
  cases arr[i]
  · simp
  · simp

/-! ## PC bounds from fuel -/

theorem pc_within_code_length {code : ByteArray} {pc : Nat} {fuel : Nat}
    (h : pc < code.size) (hfuel : fuel > 0) : pc < code.size := h

end MovementFormal.MoveModel.ProofPatterns
