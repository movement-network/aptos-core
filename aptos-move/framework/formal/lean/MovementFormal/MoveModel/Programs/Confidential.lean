import MovementFormal.MoveModel.Programs

/-!
# Confidential-asset `ModuleEnv` (stub)

Full CA bytecode was removed from this branch (move-stdlib–only formal).
`confidentialModuleEnv` is a placeholder so `DiffTest.Runner` elaborates;
stdlib-only oracles never select `useConfidentialEnv`.
-/

namespace MovementFormal.MoveModel.Programs.Confidential

open MovementFormal.MoveModel.Programs

/-- Not used when the JSON oracle has no CA rows (`useConfidentialEnv`). -/
def confidentialModuleEnv : ModuleEnv :=
  stdModuleEnv

end MovementFormal.MoveModel.Programs.Confidential
