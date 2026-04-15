import AptosFormal.Move.State
import AptosFormal.Std.Signer
import AptosFormal.Std.FixedPoint32
import AptosFormal.Std.BitVector
import AptosFormal.Std.Option

/-!
# Native bindings for move-stdlib primitives

Lean-level native function implementations for all move-stdlib functions
that require native semantics: `std::signer`, `std::fixed_point32`,
`std::bit_vector` (mutation), and `std::option` (mutation).

Each binding has type `List MoveValue → Option (List MoveValue)`, matching
the `FuncBody.native` calling convention established by `Move/Native.lean`.

## MoveValue representation
- `signer(a)` → `.signer a`
- `address(a)` → `.address a`
- `FixedPoint32{value}` → `.struct [.u64 value]`
- `BitVector{length, bit_field}` → `.struct [.u64 length, .vector .bool bits]`
- `Option<T> (none)` → `.struct [.vector t []]`
- `Option<T> (some v)` → `.struct [.vector t [v]]`

**Source:** `aptos-move/framework/move-stdlib/sources/`
-/

namespace AptosFormal.Move.Native.StdPrimitives

open AptosFormal.Move
open AptosFormal.Std.Signer
open AptosFormal.Std.FixedPoint32 (FixedPoint32)
open AptosFormal.Std.BitVector    (MvBitVector)
open AptosFormal.Std.Option       (MoveOption)

-- ── Helpers ──────────────────────────────────────────────────────────────────

private def boolListToArray (vs : List MoveValue) : Option (Array Bool) :=
  vs.foldlM (fun acc v => match v with | .bool b => some (acc.push b) | _ => none) #[]

private def boolArrayToList (bs : Array Bool) : List MoveValue :=
  bs.toList.map .bool

private def mvBitVectorToMoveValue (bv : MvBitVector) : MoveValue :=
  .struct [.u64 bv.length, .vector .bool (boolArrayToList bv.bit_field)]

private def moveValueToMvBitVector : MoveValue → Option MvBitVector
  | .struct [.u64 len, .vector .bool bits] =>
    match boolListToArray bits with
    | some arr =>
      if h : arr.size = len.toNat then some ⟨len, arr, h⟩
      else none
    | none => none
  | _ => none

private def fp32ToMoveValue (fp : FixedPoint32) : MoveValue :=
  .struct [.u64 fp.value]

private def moveValueToFp32 : MoveValue → Option FixedPoint32
  | .struct [.u64 v] => some ⟨v⟩
  | _ => none

-- MoveOption as a struct wrapping a vector (matching Move runtime layout)
private def moveOptionToMvOption (t : MoveType) : MoveValue → Option (MoveOption MoveValue)
  | .struct [.vector _t elems] =>
    if elems.length ≤ 1 then some ⟨elems, Nat.le_of_eq_of_le rfl (by omega)⟩
    else none
  | _ => none

private def mvOptionToMoveValue (t : MoveType) (opt : MoveOption MoveValue) : MoveValue :=
  .struct [.vector t opt.vec]

-- ── std::signer ───────────────────────────────────────────────────────────────

/-- `signer::borrow_address(s: &signer): &address`
    In value semantics: returns the address embedded in the signer. -/
def signerBorrowAddress : List MoveValue → Option (List MoveValue)
  | [.signer a] => some [.address a]
  | _           => none

/-- `signer::address_of(s: &signer): address` — same as borrow_address at value level. -/
def signerAddressOf : List MoveValue → Option (List MoveValue)
  | [.signer a] => some [.address a]
  | _           => none

-- ── std::fixed_point32 ────────────────────────────────────────────────────────

/-- `fixed_point32::create_from_rational(num, den): FixedPoint32` -/
def fp32CreateFromRational : List MoveValue → Option (List MoveValue)
  | [.u64 num, .u64 den] =>
    match AptosFormal.Std.FixedPoint32.create_from_rational num den with
    | .ok fp => some [fp32ToMoveValue fp]
    | .error _ => none  -- aborts in Move; native returns none here
  | _ => none

/-- `fixed_point32::create_from_u64(val): FixedPoint32` -/
def fp32CreateFromU64 : List MoveValue → Option (List MoveValue)
  | [.u64 val] =>
    match AptosFormal.Std.FixedPoint32.create_from_u64 val with
    | .ok fp => some [fp32ToMoveValue fp]
    | .error _ => none
  | _ => none

/-- `fixed_point32::multiply_u64(val, mult): u64` -/
def fp32MultiplyU64 : List MoveValue → Option (List MoveValue)
  | [.u64 val, fp_mv] =>
    match moveValueToFp32 fp_mv with
    | some fp =>
      match AptosFormal.Std.FixedPoint32.multiply_u64 val fp with
      | .ok result => some [.u64 result]
      | .error _ => none
    | none => none
  | _ => none

/-- `fixed_point32::divide_u64(val, divisor): u64` -/
def fp32DivideU64 : List MoveValue → Option (List MoveValue)
  | [.u64 val, fp_mv] =>
    match moveValueToFp32 fp_mv with
    | some fp =>
      match AptosFormal.Std.FixedPoint32.divide_u64 val fp with
      | .ok result => some [.u64 result]
      | .error _ => none
    | none => none
  | _ => none

/-- `fixed_point32::get_raw_value(fp): u64` -/
def fp32GetRawValue : List MoveValue → Option (List MoveValue)
  | [fp_mv] =>
    match moveValueToFp32 fp_mv with
    | some fp => some [.u64 fp.value]
    | none => none
  | _ => none

/-- `fixed_point32::is_zero(fp): bool` -/
def fp32IsZero : List MoveValue → Option (List MoveValue)
  | [fp_mv] =>
    match moveValueToFp32 fp_mv with
    | some fp => some [.bool (AptosFormal.Std.FixedPoint32.is_zero fp)]
    | none => none
  | _ => none

/-- `fixed_point32::floor(fp): u64` -/
def fp32Floor : List MoveValue → Option (List MoveValue)
  | [fp_mv] =>
    match moveValueToFp32 fp_mv with
    | some fp => some [.u64 (AptosFormal.Std.FixedPoint32.floor fp)]
    | none => none
  | _ => none

/-- `fixed_point32::ceil(fp): u64` -/
def fp32Ceil : List MoveValue → Option (List MoveValue)
  | [fp_mv] =>
    match moveValueToFp32 fp_mv with
    | some fp => some [.u64 (AptosFormal.Std.FixedPoint32.ceil fp)]
    | none => none
  | _ => none

/-- `fixed_point32::round(fp): u64` -/
def fp32Round : List MoveValue → Option (List MoveValue)
  | [fp_mv] =>
    match moveValueToFp32 fp_mv with
    | some fp => some [.u64 (AptosFormal.Std.FixedPoint32.round fp)]
    | none => none
  | _ => none

/-- `fixed_point32::min(x, y): FixedPoint32` -/
def fp32Min : List MoveValue → Option (List MoveValue)
  | [x_mv, y_mv] =>
    match moveValueToFp32 x_mv, moveValueToFp32 y_mv with
    | some x, some y => some [fp32ToMoveValue (AptosFormal.Std.FixedPoint32.min x y)]
    | _, _ => none
  | _ => none

/-- `fixed_point32::max(x, y): FixedPoint32` -/
def fp32Max : List MoveValue → Option (List MoveValue)
  | [x_mv, y_mv] =>
    match moveValueToFp32 x_mv, moveValueToFp32 y_mv with
    | some x, some y => some [fp32ToMoveValue (AptosFormal.Std.FixedPoint32.max x y)]
    | _, _ => none
  | _ => none

-- ── std::bit_vector ───────────────────────────────────────────────────────────

/-- `bit_vector::new(length: u64): BitVector` -/
def bitVectorNew : List MoveValue → Option (List MoveValue)
  | [.u64 len] =>
    match AptosFormal.Std.BitVector.new len with
    | .ok bv => some [mvBitVectorToMoveValue bv]
    | .error _ => none
  | _ => none

/-- `bit_vector::set(bv: &mut BitVector, i: u64)` — returns updated struct -/
def bitVectorSet : List MoveValue → Option (List MoveValue)
  | [bv_mv, .u64 i] =>
    match moveValueToMvBitVector bv_mv with
    | some bv =>
      match AptosFormal.Std.BitVector.set bv i with
      | .ok bv' => some [mvBitVectorToMoveValue bv']
      | .error _ => none
    | none => none
  | _ => none

/-- `bit_vector::unset(bv: &mut BitVector, i: u64)` — returns updated struct -/
def bitVectorUnset : List MoveValue → Option (List MoveValue)
  | [bv_mv, .u64 i] =>
    match moveValueToMvBitVector bv_mv with
    | some bv =>
      match AptosFormal.Std.BitVector.unset bv i with
      | .ok bv' => some [mvBitVectorToMoveValue bv']
      | .error _ => none
    | none => none
  | _ => none

/-- `bit_vector::is_index_set(bv: &BitVector, i: u64): bool` -/
def bitVectorIsIndexSet : List MoveValue → Option (List MoveValue)
  | [bv_mv, .u64 i] =>
    match moveValueToMvBitVector bv_mv with
    | some bv =>
      match AptosFormal.Std.BitVector.is_index_set bv i with
      | .ok b => some [.bool b]
      | .error _ => none
    | none => none
  | _ => none

/-- `bit_vector::shift_left(bv: &mut BitVector, amount: u64)` -/
def bitVectorShiftLeft : List MoveValue → Option (List MoveValue)
  | [bv_mv, .u64 amt] =>
    match moveValueToMvBitVector bv_mv with
    | some bv => some [mvBitVectorToMoveValue (AptosFormal.Std.BitVector.shift_left bv amt)]
    | none => none
  | _ => none

-- ── std::option ───────────────────────────────────────────────────────────────

private def withOpt (t : MoveType) (args : List MoveValue)
    (f : MoveOption MoveValue → Option (List MoveValue)) : Option (List MoveValue) :=
  match args with
  | [mv] => match moveOptionToMvOption t mv with | some opt => f opt | none => none
  | _    => none

/-- `option::is_none(t: &Option<T>): bool` -/
def optionIsNone (t : MoveType) : List MoveValue → Option (List MoveValue) :=
  withOpt t · fun opt => some [.bool (AptosFormal.Std.Option.isNone opt)]

/-- `option::is_some(t: &Option<T>): bool` -/
def optionIsSome (t : MoveType) : List MoveValue → Option (List MoveValue) :=
  withOpt t · fun opt => some [.bool (AptosFormal.Std.Option.isSome opt)]

/-- `option::contains(t: &Option<T>, e: &T): bool` -/
def optionContains (t : MoveType) : List MoveValue → Option (List MoveValue)
  | [mv, e] =>
    match moveOptionToMvOption t mv with
    | some opt => some [.bool (AptosFormal.Std.Option.contains' opt e)]
    | none => none
  | _ => none

/-- `option::borrow(t: &Option<T>): &T` — returns the inner value (value semantics) -/
def optionBorrow (t : MoveType) : List MoveValue → Option (List MoveValue) :=
  withOpt t · fun opt =>
    match AptosFormal.Std.Option.borrow' opt with
    | some v => some [v]
    | none   => none

/-- `option::fill(t: &mut Option<T>, e: T)` — fills none; aborts on some -/
def optionFill (t : MoveType) : List MoveValue → Option (List MoveValue)
  | [mv, e] =>
    match moveOptionToMvOption t mv with
    | some opt =>
      match AptosFormal.Std.Option.fill' opt e with
      | .ok opt' => some [mvOptionToMoveValue t opt']
      | .error _ => none
    | none => none
  | _ => none

/-- `option::extract(t: &mut Option<T>): T` -/
def optionExtract (t : MoveType) : List MoveValue → Option (List MoveValue) :=
  withOpt t · fun opt =>
    match AptosFormal.Std.Option.extract' opt with
    | .ok (v, opt') => some [v, mvOptionToMoveValue t opt']
    | .error _      => none

/-- `option::swap(t: &mut Option<T>, e: T): T` -/
def optionSwap (t : MoveType) : List MoveValue → Option (List MoveValue)
  | [mv, e] =>
    match moveOptionToMvOption t mv with
    | some opt =>
      match AptosFormal.Std.Option.swap' opt e with
      | .ok (old, opt') => some [old, mvOptionToMoveValue t opt']
      | .error _        => none
    | none => none
  | _ => none

/-- `option::swap_or_fill(t: &mut Option<T>, e: T): Option<T>` -/
def optionSwapOrFill (t : MoveType) : List MoveValue → Option (List MoveValue)
  | [mv, e] =>
    match moveOptionToMvOption t mv with
    | some opt =>
      let (displaced, updated) := AptosFormal.Std.Option.swapOrFill opt e
      some [mvOptionToMoveValue t displaced, mvOptionToMoveValue t updated]
    | none => none
  | _ => none

/-- `option::destroy_none(t: Option<T>)` — aborts if some -/
def optionDestroyNone (t : MoveType) : List MoveValue → Option (List MoveValue) :=
  withOpt t · fun opt =>
    match AptosFormal.Std.Option.destroyNone opt with
    | .ok () => some []
    | .error _ => none

/-- `option::destroy_some(t: Option<T>): T` -/
def optionDestroySome (t : MoveType) : List MoveValue → Option (List MoveValue) :=
  withOpt t · fun opt =>
    match AptosFormal.Std.Option.destroySome opt with
    | .ok v    => some [v]
    | .error _ => none

end AptosFormal.Move.Native.StdPrimitives
