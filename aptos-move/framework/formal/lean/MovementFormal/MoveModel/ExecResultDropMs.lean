/-
Copyright (c) Move Industries.

# `ExecResult.dropMs` — project away `MachineState` on returned values

**Source:** same projection as used in registration bytecode refinement
(`MovementFormal.Experimental.ConfidentialAsset.Registration.*`).

Split out of the large `EvalEquiv.lean` so lightweight modules (smoke tests,
fuel-only lemmas) can import **`ExecResult.dropMs`** without pulling the full
registration equivalence proof graph.
-/

import MovementFormal.MoveModel.State

namespace MovementFormal.MoveModel

def ExecResult.dropMs : ExecResult → ExecResult
  | .returned vs _ => .returned vs MachineState.empty
  | r => r

@[simp] theorem ExecResult.dropMs_returned (vs : List MoveValue) (ms : MachineState) :
    ExecResult.dropMs (.returned vs ms) = .returned vs MachineState.empty := rfl

@[simp] theorem ExecResult.dropMs_aborted (code : UInt64) :
    ExecResult.dropMs (.aborted code) = .aborted code := rfl

@[simp] theorem ExecResult.dropMs_error :
    ExecResult.dropMs .error = .error := rfl

theorem ExecResult.dropMs_eq_returned_iff (r : ExecResult) (vs : List MoveValue) :
    r.dropMs = .returned vs MachineState.empty ↔
    ∃ ms, r = .returned vs ms := by
  constructor
  · intro h; cases r with
    | returned vs' ms' =>
      simp [ExecResult.dropMs] at h
      exact ⟨ms', by obtain ⟨rfl, _⟩ := h; rfl⟩
    | aborted _ => simp [ExecResult.dropMs] at h
    | error => simp [ExecResult.dropMs] at h
    | ok _ _ _ _ => simp [ExecResult.dropMs] at h
  · rintro ⟨ms, rfl⟩; simp [ExecResult.dropMs]

theorem ExecResult.dropMs_eq_aborted_iff (r : ExecResult) (code : UInt64) :
    r.dropMs = .aborted code ↔ r = .aborted code := by
  constructor
  · intro h; cases r with
    | returned _ _ => simp [ExecResult.dropMs] at h
    | aborted c =>
      simp [ExecResult.dropMs] at h
      exact congrArg ExecResult.aborted h
    | error => simp [ExecResult.dropMs] at h
    | ok _ _ _ _ => simp [ExecResult.dropMs] at h
  · rintro rfl; rfl

theorem ExecResult.dropMs_ne_error_of_ne_error {r : ExecResult} (h : r ≠ .error) :
    r.dropMs ≠ .error := by
  cases r with
  | returned _ _ => simp [ExecResult.dropMs]
  | aborted _ => simp [ExecResult.dropMs]
  | error => exact absurd rfl h
  | ok _ _ _ _ => simp [ExecResult.dropMs]

end MovementFormal.MoveModel
