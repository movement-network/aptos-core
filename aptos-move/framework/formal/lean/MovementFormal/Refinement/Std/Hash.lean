/-
Copyright (c) Move Industries.

Refinement: `hashCatalogModuleEnv` matches **`MovementFormal.Std.Hash.Sha2_256`** /
**`Sha3_256`** on `vector<u8>` inputs (same definitions as `MoveModel.Native`).

**Source:** `aptos-move/framework/move-stdlib/sources/hash.move`; catalog `MovementFormal.MoveModel.HashCatalog`.
-/

import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.HashCatalog
import MovementFormal.Std.Hash.Sha2_256
import MovementFormal.Std.Hash.Sha3_256

namespace MovementFormal.Refinement.Std.Hash

open MovementFormal.MoveModel
open MovementFormal.MoveModel.HashCatalog
open MovementFormal.MoveModel.Native
open MovementFormal.Std.Hash.Sha2_256
open MovementFormal.Std.Hash.Sha3_256

private abbrev evalCat (idx : Nat) (args : List MoveValue) (fuel : Nat) :=
  eval hashCatalogModuleEnv idx args fuel

theorem hashCatalog_sha2_refines (elems : List MoveValue) (ba : ByteArray)
    (hvec : u8ElemsToByteArray elems = some ba) :
    evalCat 0 [.vector .u8 elems] 80 =
      .returned [bytesToMoveVec (sha2_256 ba)] MachineState.empty := by
  simp [evalCat, eval, hashCatalogModuleEnv, hashCatalogFunctions, sha2_256_native, hvec]

theorem hashCatalog_sha3_refines (elems : List MoveValue) (ba : ByteArray)
    (hvec : u8ElemsToByteArray elems = some ba) :
    evalCat 1 [.vector .u8 elems] 80 =
      .returned [bytesToMoveVec (sha3_256 ba)] MachineState.empty := by
  simp [evalCat, eval, hashCatalogModuleEnv, hashCatalogFunctions, sha3_256_native, hvec]

end MovementFormal.Refinement.Std.Hash
