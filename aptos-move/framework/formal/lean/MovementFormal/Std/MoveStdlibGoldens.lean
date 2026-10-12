/-
Copyright (c) Move Industries.

Machine-checked alignment between `MovementFormal` models and **Move stdlib** expectations.

**Source:** Move stdlib tests `aptos-move/framework/move-stdlib/tests/hash_tests.move`,
`aptos-move/framework/move-stdlib/tests/bcs_tests.move`; curated copies `aptos-move/framework/move-stdlib/tests/formal_goldens_*.move`.
-/

import MovementFormal.Std.Bcs.Primitives
import MovementFormal.Std.Hash.Sha3_256

namespace MovementFormal.Std.MoveStdlibGoldens

open MovementFormal.Std.Bcs
open MovementFormal.Std.Hash.Sha3_256

/-! ## `std::hash::sha3_256` (see `hash_tests.move`) -/

example : sha3_256 (ByteArray.mk #[97, 98, 99]) = expectedSha3_256_abc := by native_decide

/-! ## `std::bcs` (see `bcs_tests.move`) -/

example : boolBytes true = ByteArray.mk #[1] := by native_decide

example : boolBytes false = ByteArray.mk #[0] := by native_decide

example : u8Bytes 1 = ByteArray.mk #[1] := by native_decide

example : u64Le 1 = ByteArray.mk #[1, 0, 0, 0, 0, 0, 0, 0] := by native_decide

example : u128LeNat 1 = ByteArray.mk #[
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] := by native_decide

example : vectorU8Short (ByteArray.mk #[0x0f]) (by decide) = ByteArray.mk #[1, 0x0f] := by native_decide

example : vectorU8Short ByteArray.empty (by decide) = ByteArray.mk #[0] := by native_decide

end MovementFormal.Std.MoveStdlibGoldens
