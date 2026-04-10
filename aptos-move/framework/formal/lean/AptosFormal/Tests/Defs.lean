import AptosFormal.Move.Step
import AptosFormal.Move.Programs

/-!
# Test helpers

Shared definitions for smoke tests (`native_decide` on concrete inputs).
-/

namespace AptosFormal.Tests.Defs

open AptosFormal.Move
open AptosFormal.Move.Programs

abbrev evalProg (idx : FuncIndex) (args : List MoveValue) (fuel : Nat) :=
  eval stdModuleEnv idx args fuel

abbrev evalReal (idx : FuncIndex) (args : List MoveValue) (fuel : Nat) :=
  eval realModuleEnv idx args fuel

def returnValues : ExecResult → Option (List MoveValue)
  | .returned vs _ => some vs
  | _ => none

def u64Vec (ns : List Nat) : MoveValue :=
  .vector .u64 (ns.map fun n => .u64 n.toUInt64)

end AptosFormal.Tests.Defs
