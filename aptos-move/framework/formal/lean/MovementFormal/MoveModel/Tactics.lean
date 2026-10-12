/-
Custom tactics and automation for Move bytecode proofs.

Provides specialized tactics for common proof patterns in EvalEquiv proofs.
-/

import Lean
import Mathlib.Tactic.Common

namespace MovementFormal.MoveModel.Tactics

open Lean Elab Tactic

/-- Tactic to solve array bounds obligations using omega.
    Usage: `array_bounds` -/
syntax "array_bounds" : tactic
macro_rules
  | `(tactic| array_bounds) => `(tactic| first | omega | decide)

/-- Tactic to unfold step and simplify for bytecode step proofs.
    Usage: `step_simp` -/
syntax "step_simp" : tactic
macro_rules
  | `(tactic| step_simp) => `(tactic| simp only [step, Instr.exec])

/-- Tactic to solve fuel arithmetic goals.
    Usage: `fuel_arith` -/
syntax "fuel_arith" : tactic
macro_rules
  | `(tactic| fuel_arith) => `(tactic| omega)

/-- Tactic for container store equality after allocation.
    Usage: `container_eq` -/
syntax "container_eq" : tactic
macro_rules
  | `(tactic| container_eq) => `(tactic| simp only []; congr)

/-- Tactic to prove run chain equalities by reflexivity after simplification.
    Usage: `run_chain_rfl` -/
syntax "run_chain_rfl" : tactic
macro_rules
  | `(tactic| run_chain_rfl) => `(tactic| (simp only []; rfl))

end MovementFormal.MoveModel.Tactics
