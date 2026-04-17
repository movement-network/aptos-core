import MovementFormal.SmokeTests.Defs
import MovementFormal.MoveModel.Programs

/-!
# Smoke tests for abstract global resources (`GlobalResourceKey`)

**Source:** `MovementFormal.MoveModel.Programs.GlobalSmoke` (see that module’s **Source** anchor).

Indices **21**–**22** in both envs; index **23** (`global_move_signed_borrow_smoke`) only in
`stdModuleEnv` (and at **34** in `realModuleEnv`); see `Programs.lean`.
-/

namespace MovementFormal.SmokeTests.GlobalSmoke

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs
open MovementFormal.SmokeTests.Defs

theorem global_exists_smoke_returns_false :
    returnValues (eval stdModuleEnv 21 [] 20) = some [.bool false] := by
  rfl

theorem global_move_borrow_smoke_returns_seven :
    returnValues (eval stdModuleEnv 22 [] 30) = some [.u64 7] := by
  rfl

theorem global_move_signed_borrow_smoke_returns_seven :
    returnValues (eval stdModuleEnv 23 [] 40) = some [.u64 7] := by
  rfl

end MovementFormal.SmokeTests.GlobalSmoke
