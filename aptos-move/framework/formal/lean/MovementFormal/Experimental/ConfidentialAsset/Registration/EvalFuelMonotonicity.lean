/-
Copyright (c) Move Industries.

# Fuel monotonicity for `run` / `eval`

**Source:** `MovementFormal.MoveModel.Step` (`run`, `eval`).

These lemmas were split out of `EvalEquiv.lean` so callers that only need
fuel-independence facts (e.g. smoke tests with hard-coded fuel) can import
this file instead of the full registration bytecode equivalence module.
-/

import MovementFormal.MoveModel.ExecResultDropMs
import MovementFormal.MoveModel.Step

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv

open MovementFormal.MoveModel

/-! ## Fuel monotonicity -/

theorem run_fuel_ge (env : ModuleEnv) (frame : Frame) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) :
    ∀ (fuel₁ fuel₂ : Nat), fuel₁ ≤ fuel₂ →
      run env frame cs stack ms fuel₁ ≠ .error →
      run env frame cs stack ms fuel₂ = run env frame cs stack ms fuel₁ := by
  intro fuel₁
  induction fuel₁ generalizing frame cs stack ms with
  | zero => intro _ _ hne; simp [run] at hne
  | succ n ih =>
    intro fuel₂ hle hne
    obtain ⟨m, rfl⟩ : ∃ m, fuel₂ = m + 1 := ⟨fuel₂ - 1, by omega⟩
    simp only [run]
    cases hStep : step env frame cs stack ms with
    | ok frame' cs' stack' ms' =>
      exact ih frame' cs' stack' ms' m (by omega) (by simp [run, hStep] at hne; exact hne)
    | returned _ _ => rfl
    | aborted _ => rfl
    | error => simp [run, hStep] at hne

theorem eval_fuel_ge (env : ModuleEnv) (funcIdx : FuncIndex) (args : List MoveValue)
    (fuel₁ fuel₂ : Nat) (ms : MachineState) :
    fuel₁ ≤ fuel₂ →
    eval env funcIdx args fuel₁ ms ≠ .error →
    eval env funcIdx args fuel₂ ms = eval env funcIdx args fuel₁ ms := by
  intro hle hne
  simp only [eval] at hne ⊢
  by_cases hBound : funcIdx < env.functions.size
  · simp only [dite_true, hBound] at hne ⊢
    cases hBody : env.functions[funcIdx].body with
    | native impl => rfl
    | nativeAbort impl => rfl
    | nativeRef impl => rfl
    | bytecode code numLocals =>
      simp only [hBody] at hne ⊢
      exact run_fuel_ge _ _ _ _ _ _ _ hle hne
  · simp only [dite_false, hBound] at hne; exact absurd rfl hne

theorem eval_fuel_ge_dropMs (env : ModuleEnv) (funcIdx : FuncIndex) (args : List MoveValue)
    (fuel₁ fuel₂ : Nat) (ms : MachineState) :
    fuel₁ ≤ fuel₂ →
    eval env funcIdx args fuel₁ ms ≠ .error →
    (eval env funcIdx args fuel₂ ms).dropMs = (eval env funcIdx args fuel₁ ms).dropMs := by
  intro hle hne
  exact congrArg ExecResult.dropMs (eval_fuel_ge env funcIdx args fuel₁ fuel₂ ms hle hne)

end MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv
