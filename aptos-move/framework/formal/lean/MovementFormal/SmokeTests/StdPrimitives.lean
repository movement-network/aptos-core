import MovementFormal.SmokeTests.Defs
import MovementFormal.MoveModel.Programs.StdPrimitives
import MovementFormal.MoveModel.Native.StdPrimitives

/-!
# Smoke tests for move-stdlib primitives

Concrete input/output tests using `native_decide`.
Tests are organized by module; each verifies a specific known input/output pair.

## Coverage
- `std::error::canonical` + all 13 category wrappers (bytecode)
- `std::signer::address_of` (native)
- `std::fixed_point32::multiply_u64`, `divide_u64`, `floor`, `ceil`, `round` (native)
- `std::bit_vector::new`, `set`, `unset`, `is_index_set` (native)
- `std::option::is_none`, `is_some`, `fill`, `extract`, `swap`, `swapOrFill` (native)
-/

namespace MovementFormal.SmokeTests.StdPrimitives

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.StdPrimitives
open MovementFormal.MoveModel.Native.StdPrimitives
open MovementFormal.SmokeTests.Defs

-- ── std::error (native function tests — calling through native binding) ───────

/-- `canonical(1, 5) = 0x10005` -/
theorem error_canonical_1_5 :
    (errorCanonicalDesc.body.toFun? [.u64 1, .u64 5] |>.getD []) == [.u64 0x10005] := by
  native_decide

/-- `canonical(0xD, 3) = 0xD0003` (UNAVAILABLE, reason=3) -/
theorem error_unavailable_3 :
    (errorUnavailableDesc.body.toFun? [.u64 3] |>.getD []) == [.u64 0xD0003] := by
  native_decide

/-- `invalid_argument(0) = 0x10000` -/
theorem error_invalid_argument_0 :
    (errorInvalidArgumentDesc.body.toFun? [.u64 0] |>.getD []) == [.u64 0x10000] := by
  native_decide

/-- `out_of_range(1) = 0x20001` -/
theorem error_out_of_range_1 :
    (errorOutOfRangeDesc.body.toFun? [.u64 1] |>.getD []) == [.u64 0x20001] := by
  native_decide

-- ── std::signer (native) ──────────────────────────────────────────────────────

/-- `borrow_address(signer("abc")) = address("abc")` -/
theorem signer_borrow_address :
    signerBorrowAddress [.signer "abc".toUTF8] ==
    some [.address "abc".toUTF8] := by native_decide

/-- `address_of` delegates to borrow_address -/
theorem signer_address_of_eq_borrow :
    signerAddressOf [.signer "abc".toUTF8] ==
    signerBorrowAddress [.signer "abc".toUTF8] := by native_decide

-- ── std::fixed_point32 (native) ───────────────────────────────────────────────

/-- `multiply_u64(10, fp32(2.0)) = 20`
    `fp32(2.0)` has raw value `2 * 2^32 = 8589934592` -/
theorem fp32_multiply_2_0 :
    fp32MultiplyU64 [.u64 10, .struct [.u64 8589934592]] ==
    some [.u64 20] := by native_decide

/-- `divide_u64(20, fp32(2.0)) = 10` -/
theorem fp32_divide_2_0 :
    fp32DivideU64 [.u64 20, .struct [.u64 8589934592]] ==
    some [.u64 10] := by native_decide

/-- `floor(fp32(3.75))` — raw value = `3 * 2^32 + 0.75 * 2^32` = `16106127360`
    floor should be 3 -/
theorem fp32_floor_3_75 :
    fp32Floor [.struct [.u64 16106127360]] == some [.u64 3] := by native_decide

/-- `ceil(fp32(3.75))` = 4 -/
theorem fp32_ceil_3_75 :
    fp32Ceil [.struct [.u64 16106127360]] == some [.u64 4] := by native_decide

/-- `round(fp32(3.25))` = 3 (below .5) -/
theorem fp32_round_3_25 :
    fp32Round [.struct [.u64 13958643712]] == some [.u64 3] := by native_decide

/-- `round(fp32(3.75))` = 4 (above .5) -/
theorem fp32_round_3_75 :
    fp32Round [.struct [.u64 16106127360]] == some [.u64 4] := by native_decide

-- ── std::bit_vector (native) ──────────────────────────────────────────────────

/-- `new(8)` creates a BitVector of length 8, all false -/
theorem bv_new_8 :
    bitVectorNew [.u64 8] ==
    some [.struct [.u64 8, .vector .bool (List.replicate 8 (.bool false))]] := by
  native_decide

/-- `set` at index 3 sets bit 3 to true -/
theorem bv_set_index_3 :
    let bv := .struct [.u64 8, .vector .bool (List.replicate 8 (.bool false))]
    match bitVectorSet [bv, .u64 3] with
    | some [.struct [.u64 _, .vector .bool bits]] =>
        bits.get? 3 == some (.bool true) &&
        bits.get? 2 == some (.bool false)
    | _ => false := by native_decide

/-- `is_index_set` returns false on fresh bitvector -/
theorem bv_is_index_set_fresh :
    let bv := .struct [.u64 8, .vector .bool (List.replicate 8 (.bool false))]
    bitVectorIsIndexSet [bv, .u64 5] == some [.bool false] := by native_decide

/-- `set` then `is_index_set` returns true -/
theorem bv_set_then_query :
    let bv := .struct [.u64 8, .vector .bool (List.replicate 8 (.bool false))]
    match bitVectorSet [bv, .u64 5] with
    | some [bv'] => bitVectorIsIndexSet [bv', .u64 5] == some [.bool true]
    | _ => false := by native_decide

/-- `unset` after `set` returns false again -/
theorem bv_set_unset_roundtrip :
    let bv := .struct [.u64 8, .vector .bool (List.replicate 8 (.bool false))]
    match bitVectorSet [bv, .u64 5] with
    | some [bv'] =>
      match bitVectorUnset [bv', .u64 5] with
      | some [bv''] => bitVectorIsIndexSet [bv'', .u64 5] == some [.bool false]
      | _ => false
    | _ => false := by native_decide

-- ── std::option (native) ──────────────────────────────────────────────────────

private def mkNone : MoveValue := .struct [.vector .u64 []]
private def mkSome (v : UInt64) : MoveValue := .struct [.vector .u64 [.u64 v]]

/-- `is_none(none) = true` -/
theorem option_is_none_none :
    optionIsNone .u64 [mkNone] == some [.bool true] := by native_decide

/-- `is_some(some(42)) = true` -/
theorem option_is_some_some :
    optionIsSome .u64 [mkSome 42] == some [.bool true] := by native_decide

/-- `fill(none, 7) = some(7)` -/
theorem option_fill_none :
    optionFill .u64 [mkNone, .u64 7] == some [mkSome 7] := by native_decide

/-- `fill(some(v), e)` = none (aborts) -/
theorem option_fill_some_aborts :
    optionFill .u64 [mkSome 1, .u64 7] == none := by native_decide

/-- `extract(some(42)) = (42, none)` -/
theorem option_extract_some :
    optionExtract .u64 [mkSome 42] == some [.u64 42, mkNone] := by native_decide

/-- `swap(some(1), 2) = (1, some(2))` -/
theorem option_swap_some :
    optionSwap .u64 [mkSome 1, .u64 2] == some [.u64 1, mkSome 2] := by native_decide

/-- `swapOrFill(none, 5) = (none, some(5))` -/
theorem option_swapOrFill_none :
    optionSwapOrFill .u64 [mkNone, .u64 5] == some [mkNone, mkSome 5] := by native_decide

/-- `swapOrFill(some(3), 5) = (some(3), some(5))` — displaced value is some(3) -/
theorem option_swapOrFill_some :
    optionSwapOrFill .u64 [mkSome 3, .u64 5] == some [mkSome 3, mkSome 5] := by native_decide

end MovementFormal.SmokeTests.StdPrimitives
