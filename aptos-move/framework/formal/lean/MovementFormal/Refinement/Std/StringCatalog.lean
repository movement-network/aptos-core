/-
Copyright (c) Move Industries.

Refinement: `stringCatalogModuleEnv` matches **`MovementFormal.Std.String`** on the same
`vector<u8>` / index inputs as `MoveModel.Native.StdPrimitives.stringOracle*`.

**Source:** `aptos-move/framework/move-stdlib/sources/string.move`; natives `aptos-move/framework/move-stdlib/src/natives/string.rs`.
-/

import MovementFormal.MoveModel.Native.StdPrimitives
import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.StringCatalog
import MovementFormal.Std.String

namespace MovementFormal.Refinement.Std.StringCatalog

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native
open MovementFormal.MoveModel.Native.StdPrimitives
open MovementFormal.MoveModel.StringCatalog
open MovementFormal.Std.String

private abbrev evalCat (idx : Nat) (args : List MoveValue) (fuel : Nat) :=
  eval stringCatalogModuleEnv idx args fuel

theorem string_catalog_check_utf8_refines (elems : List MoveValue) (ba : ByteArray)
    (hvec : u8ElemsToByteArray elems = some ba) :
    evalCat 0 [.vector .u8 elems] 80 =
      .returned [.bool (utf8_bytes_well_formed ba.toList)] MachineState.empty := by
  simp [evalCat, eval, stringCatalogModuleEnv, stringCatalogFunctions,
    stringOracleInternalCheckUtf8, hvec]

theorem string_catalog_sub_string_refines (elems : List MoveValue) (ba : ByteArray) (i j : UInt64)
    (hvec : u8ElemsToByteArray elems = some ba)
    (hi : i.toNat ≤ ba.toList.length) (hj : j.toNat ≤ ba.toList.length) (hij : i.toNat ≤ j.toNat) :
    evalCat 1 [.vector .u8 elems, .u64 i, .u64 j] 80 =
      .returned
        [Native.bytesToMoveVec (ByteArray.mk
          ((internalSubStringBytes ba.toList i.toNat j.toNat).toArray))]
        MachineState.empty := by
  simp [evalCat, eval, stringCatalogModuleEnv, stringCatalogFunctions,
    stringOracleInternalSubString, hvec, hi, hj, hij, Nat.not_lt_of_le]

theorem string_catalog_index_of_refines (hayE needE : List MoveValue) (hay need : ByteArray)
    (hhay : u8ElemsToByteArray hayE = some hay) (hneed : u8ElemsToByteArray needE = some need) :
    evalCat 2 [.vector .u8 hayE, .vector .u8 needE] 80 =
      .returned [.u64 (UInt64.ofNat (byteIndexOf hay.toList need.toList))] MachineState.empty := by
  simp [evalCat, eval, stringCatalogModuleEnv, stringCatalogFunctions,
    stringOracleInternalIndexOf, hhay, hneed]

theorem string_catalog_is_char_boundary_refines (elems : List MoveValue) (ba : ByteArray) (i : UInt64)
    (hvec : u8ElemsToByteArray elems = some ba) :
    evalCat 3 [.vector .u8 elems, .u64 i] 80 =
      .returned [.bool (utf8CharBoundaryAt ba.toList i.toNat)] MachineState.empty := by
  simp [evalCat, eval, stringCatalogModuleEnv, stringCatalogFunctions,
    stringOracleInternalIsCharBoundary, hvec]

theorem string_catalog_native_check_utf8_eq (elems : List MoveValue) (ba : ByteArray)
    (hvec : u8ElemsToByteArray elems = some ba) :
    stringOracleInternalCheckUtf8 [.vector .u8 elems] =
      some [.bool (utf8_bytes_well_formed ba.toList)] := by
  simp [stringOracleInternalCheckUtf8, hvec]

theorem string_catalog_native_is_char_boundary_eq (elems : List MoveValue) (ba : ByteArray) (i : UInt64)
    (hvec : u8ElemsToByteArray elems = some ba) :
    stringOracleInternalIsCharBoundary [.vector .u8 elems, .u64 i] =
      some [.bool (utf8CharBoundaryAt ba.toList i.toNat)] := by
  simp [stringOracleInternalIsCharBoundary, hvec]

end MovementFormal.Refinement.Std.StringCatalog
