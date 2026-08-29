/-
Copyright (c) Move Industries.

Refinement: `signerCatalogModuleEnv` matches **`MovementFormal.Std.Signer`** on `signer` inputs.

**Source:** `aptos-move/framework/move-stdlib/sources/signer.move`; catalog `MovementFormal.MoveModel.SignerCatalog`.
-/

import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.SignerCatalog

namespace MovementFormal.Refinement.Std.Signer

open MovementFormal.MoveModel
open MovementFormal.MoveModel.SignerCatalog
open MovementFormal.MoveModel.Native.StdPrimitives

private abbrev evalCat (idx : Nat) (args : List MoveValue) (fuel : Nat) :=
  eval signerCatalogModuleEnv idx args fuel

theorem signerCatalog_borrow_address_refines (a : ByteArray) :
    evalCat 0 [.signer a] 80 =
      .returned [.address a] MachineState.empty := by
  simp [evalCat, eval, signerCatalogModuleEnv, signerCatalogFunctions, signerBorrowAddress]

theorem signerCatalog_address_of_refines (a : ByteArray) :
    evalCat 1 [.signer a] 80 =
      .returned [.address a] MachineState.empty := by
  simp [evalCat, eval, signerCatalogModuleEnv, signerCatalogFunctions, signerAddressOf]

theorem signerCatalog_address_of_eq_borrow (a : ByteArray) :
    evalCat 1 [.signer a] 80 = evalCat 0 [.signer a] 80 := by
  simp [evalCat, eval, signerCatalogModuleEnv, signerCatalogFunctions, signerBorrowAddress,
    signerAddressOf]

end MovementFormal.Refinement.Std.Signer
