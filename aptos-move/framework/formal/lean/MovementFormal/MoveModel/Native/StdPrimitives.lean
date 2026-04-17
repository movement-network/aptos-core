import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native
import MovementFormal.Std.Signer
import MovementFormal.Std.FixedPoint32
import MovementFormal.Std.BitVector
import MovementFormal.Std.Option
import MovementFormal.Std.Acl
import MovementFormal.Std.Cmp
import MovementFormal.Std.String

/-!
# Native bindings for move-stdlib primitives

Lean-level native function implementations for all move-stdlib functions
that require native semantics: `std::signer`, `std::fixed_point32`,
`std::bit_vector` (mutation), `std::option` (mutation), `std::acl` (value-shaped ACL wire),
and `std::string` UTF-8 natives used by `StringCatalog` (`internal_check_utf8`, `internal_sub_string`,
`internal_index_of`, `internal_is_char_boundary`), plus `std::cmp` on **`u64` / `bool` / `u8` / `u16` / `u32` / `u128` / `u256` / `address`**
(`compare` + `is_*`) used by `CmpCatalog`.

Each binding has type `List MoveValue → Option (List MoveValue)` (or `Option (Except UInt64 (List MoveValue))` for
`FuncBody.nativeAbort`), matching the `FuncBody.native` / `nativeAbort` calling convention in `MoveModel/Native.lean`.

## MoveValue representation
- `signer(a)` → `.signer a`
- `address(a)` → `.address a`
- `FixedPoint32{value}` → `.struct_ [.u64 value]`
- `BitVector{length, bit_field}` → `.struct_ [.u64 length, .vector .bool bits]`
- `Option<T> (none)` → `.struct_ [.vector t []]`
- `Option<T> (some v)` → `.struct_ [.vector t [v]]`
- `ACL { list: vector<address> }` → `.struct_ [.vector .address …]`

**Source:** `aptos-move/framework/move-stdlib/sources/`
-/

namespace MovementFormal.MoveModel.Native.StdPrimitives

open MovementFormal.MoveModel
open MovementFormal.Std.Signer
open MovementFormal.Std.FixedPoint32 (FixedPoint32)
open MovementFormal.Std.BitVector    (MvBitVector)
open MovementFormal.Std.Option
  (MoveOption none' some' isNone isSome borrowWithDefault toVec fromVec borrow' fill' extract' swap'
    destroyNone destroySome EOPTION_IS_SET EOPTION_NOT_SET)
open MovementFormal.Std.Acl           (MvAcl)
open MovementFormal.Std.Cmp           (compareU64 compareBool compareU8 compareU16 compareU32 compareU128 compareU256 compareAddress isEq isNe isLt isLe isGt isGe)

-- ── Helpers ──────────────────────────────────────────────────────────────────

private def boolListToArray (vs : List MoveValue) : Option (Array Bool) :=
  vs.foldlM (fun acc v => match v with | .bool b => some (acc.push b) | _ => none) #[]

private def boolArrayToList (bs : Array Bool) : List MoveValue :=
  bs.toList.map .bool

/-- VM wire for `std::bit_vector::BitVector` (shared with `Refinement.Std.BitVectorCatalog`). -/
def mvBitVectorToMoveValue (bv : MvBitVector) : MoveValue :=
  .struct_ [.u64 bv.length, .vector .bool (boolArrayToList bv.bit_field)]

private def moveValueToMvBitVector : MoveValue → Option MvBitVector
  | .struct_ [.u64 len, .vector .bool bits] =>
    match boolListToArray bits with
    | some arr =>
      if h : arr.size = len.toNat then some ⟨len, arr, h⟩
      else none
    | none => none
  | _ => none

/-- `FixedPoint32` wire shape: `struct { value: u64 }`. -/
def fp32ToMoveValue (fp : FixedPoint32) : MoveValue :=
  .struct_ [.u64 fp.value]

/-- Recognize `FixedPoint32` wire value (`struct { value: u64 }`). -/
def moveValueToFp32 : MoveValue → Option FixedPoint32
  | .struct_ [.u64 v] => some ⟨v⟩
  | _ => none

-- MoveOption as a struct wrapping a vector (matching Move runtime layout)
/-- Recognize `Option<T>` wire (`struct { vec: vector<T> }`, length ≤ 1). -/
def moveOptionToMvOption (_ : MoveType) : MoveValue → Option (MoveOption MoveValue)
  | .struct_ [.vector _t elems] =>
    if h : elems.length ≤ 1 then some ⟨elems, h⟩
    else none
  | _ => none

private def mvOptionToMoveValue (t : MoveType) (opt : MoveOption MoveValue) : MoveValue :=
  .struct_ [.vector t opt.vec]

/-- Move wire format for `std::option::Option<T>` (`struct { vec: vector<T> }`), exposed for
link-env natives that pair `option::*` helpers with typed payloads. Same as `mvOptionToMoveValue`. -/
def optionStructValue (t : MoveType) (opt : MoveOption MoveValue) : MoveValue :=
  .struct_ [.vector t opt.vec]

/-- Materialize `Option<u64>` wire for VM↔Lean oracle (`is_some` + `inner` scratch). -/
def optionU64Wire (isSome : Bool) (inner : UInt64) : MoveValue :=
  optionStructValue .u64 (if isSome then some' (.u64 inner) else none')

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
    match MovementFormal.Std.FixedPoint32.create_from_rational num den with
    | .ok fp => some [fp32ToMoveValue fp]
    | .error _ => none  -- aborts in Move; native returns none here
  | _ => none

/-- `fixed_point32::create_from_u64(val): FixedPoint32` -/
def fp32CreateFromU64 : List MoveValue → Option (List MoveValue)
  | [.u64 val] =>
    match MovementFormal.Std.FixedPoint32.create_from_u64 val with
    | .ok fp => some [fp32ToMoveValue fp]
    | .error _ => none
  | _ => none

/-- `fixed_point32::create_from_raw_value(value): FixedPoint32` -/
def fp32CreateFromRaw : List MoveValue → Option (List MoveValue)
  | [.u64 v] => some [fp32ToMoveValue (MovementFormal.Std.FixedPoint32.create_from_raw_value v)]
  | _ => none

/-- `fixed_point32::multiply_u64(val, mult): u64` -/
def fp32MultiplyU64 : List MoveValue → Option (List MoveValue)
  | [.u64 val, fp_mv] =>
    match moveValueToFp32 fp_mv with
    | some fp =>
      match MovementFormal.Std.FixedPoint32.multiply_u64 val fp with
      | .ok result => some [.u64 result]
      | .error _ => none
    | none => none
  | _ => none

/-- `fixed_point32::divide_u64(val, divisor): u64` -/
def fp32DivideU64 : List MoveValue → Option (List MoveValue)
  | [.u64 val, fp_mv] =>
    match moveValueToFp32 fp_mv with
    | some fp =>
      match MovementFormal.Std.FixedPoint32.divide_u64 val fp with
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
    | some fp => some [.bool (MovementFormal.Std.FixedPoint32.is_zero fp)]
    | none => none
  | _ => none

/-- `fixed_point32::floor(fp): u64` -/
def fp32Floor : List MoveValue → Option (List MoveValue)
  | [fp_mv] =>
    match moveValueToFp32 fp_mv with
    | some fp => some [.u64 (MovementFormal.Std.FixedPoint32.floor fp)]
    | none => none
  | _ => none

/-- `fixed_point32::ceil(fp): u64` -/
def fp32Ceil : List MoveValue → Option (List MoveValue)
  | [fp_mv] =>
    match moveValueToFp32 fp_mv with
    | some fp => some [.u64 (MovementFormal.Std.FixedPoint32.ceil fp)]
    | none => none
  | _ => none

/-- `fixed_point32::round(fp): u64` -/
def fp32Round : List MoveValue → Option (List MoveValue)
  | [fp_mv] =>
    match moveValueToFp32 fp_mv with
    | some fp => some [.u64 (MovementFormal.Std.FixedPoint32.round fp)]
    | none => none
  | _ => none

/-- `fixed_point32::min(x, y): FixedPoint32` -/
def fp32Min : List MoveValue → Option (List MoveValue)
  | [x_mv, y_mv] =>
    match moveValueToFp32 x_mv, moveValueToFp32 y_mv with
    | some x, some y => some [fp32ToMoveValue (MovementFormal.Std.FixedPoint32.min x y)]
    | _, _ => none
  | _ => none

/-- `fixed_point32::max(x, y): FixedPoint32` -/
def fp32Max : List MoveValue → Option (List MoveValue)
  | [x_mv, y_mv] =>
    match moveValueToFp32 x_mv, moveValueToFp32 y_mv with
    | some x, some y => some [fp32ToMoveValue (MovementFormal.Std.FixedPoint32.max x y)]
    | _, _ => none
  | _ => none

/-! ### Difftest oracle wrappers (`0x1::difftest_fixed_point32`)

Move wrappers take **raw** `u64` scalars (and return `u64` / `bool`) matching JSON `TypedValue`; they
compose `create_from_raw_value` where the stdlib API takes `FixedPoint32`. -/

def fp32OracleCreateFromRational : List MoveValue → Option (List MoveValue)
  | [.u64 n, .u64 d] =>
    match MovementFormal.Std.FixedPoint32.create_from_rational n d with
    | .ok fp => some [.u64 fp.value]
    | .error _ => none
  | _ => none

def fp32OracleCreateFromU64 : List MoveValue → Option (List MoveValue)
  | [.u64 v] =>
    match MovementFormal.Std.FixedPoint32.create_from_u64 v with
    | .ok fp => some [.u64 fp.value]
    | .error _ => none
  | _ => none

def fp32OracleCreateFromRawValue : List MoveValue → Option (List MoveValue)
  | [.u64 v] => some [.u64 v]
  | _ => none

def fp32OracleMultiplyU64 : List MoveValue → Option (List MoveValue)
  | [.u64 val, .u64 mult_raw] =>
    let mult := MovementFormal.Std.FixedPoint32.create_from_raw_value mult_raw
    match MovementFormal.Std.FixedPoint32.multiply_u64 val mult with
    | .ok r => some [.u64 r]
    | .error _ => none
  | _ => none

def fp32OracleDivideU64 : List MoveValue → Option (List MoveValue)
  | [.u64 val, .u64 div_raw] =>
    let d := MovementFormal.Std.FixedPoint32.create_from_raw_value div_raw
    match MovementFormal.Std.FixedPoint32.divide_u64 val d with
    | .ok r => some [.u64 r]
    | .error _ => none
  | _ => none

def fp32OracleGetRawValue : List MoveValue → Option (List MoveValue)
  | [.u64 v] => some [.u64 v]
  | _ => none

def fp32OracleIsZero : List MoveValue → Option (List MoveValue)
  | [.u64 v] =>
    let fp := MovementFormal.Std.FixedPoint32.create_from_raw_value v
    some [.bool (MovementFormal.Std.FixedPoint32.is_zero fp)]
  | _ => none

def fp32OracleFloor : List MoveValue → Option (List MoveValue)
  | [.u64 v] =>
    let fp := MovementFormal.Std.FixedPoint32.create_from_raw_value v
    some [.u64 (MovementFormal.Std.FixedPoint32.floor fp)]
  | _ => none

def fp32OracleCeil : List MoveValue → Option (List MoveValue)
  | [.u64 v] =>
    let fp := MovementFormal.Std.FixedPoint32.create_from_raw_value v
    some [.u64 (MovementFormal.Std.FixedPoint32.ceil fp)]
  | _ => none

def fp32OracleRound : List MoveValue → Option (List MoveValue)
  | [.u64 v] =>
    let fp := MovementFormal.Std.FixedPoint32.create_from_raw_value v
    some [.u64 (MovementFormal.Std.FixedPoint32.round fp)]
  | _ => none

def fp32OracleMin : List MoveValue → Option (List MoveValue)
  | [.u64 a, .u64 b] =>
    let xa := MovementFormal.Std.FixedPoint32.create_from_raw_value a
    let xb := MovementFormal.Std.FixedPoint32.create_from_raw_value b
    some [.u64 (MovementFormal.Std.FixedPoint32.min xa xb).value]
  | _ => none

def fp32OracleMax : List MoveValue → Option (List MoveValue)
  | [.u64 a, .u64 b] =>
    let xa := MovementFormal.Std.FixedPoint32.create_from_raw_value a
    let xb := MovementFormal.Std.FixedPoint32.create_from_raw_value b
    some [.u64 (MovementFormal.Std.FixedPoint32.max xa xb).value]
  | _ => none

-- ── std::bit_vector ───────────────────────────────────────────────────────────

/-- `bit_vector::new(length: u64): BitVector` -/
def bitVectorNew : List MoveValue → Option (List MoveValue)
  | [.u64 len] =>
    match MovementFormal.Std.BitVector.new len with
    | .ok bv => some [mvBitVectorToMoveValue bv]
    | .error _ => none
  | _ => none

/-- `bit_vector::set(bv: &mut BitVector, i: u64)` — returns updated struct -/
def bitVectorSet : List MoveValue → Option (List MoveValue)
  | [bv_mv, .u64 i] =>
    match moveValueToMvBitVector bv_mv with
    | some bv =>
      match MovementFormal.Std.BitVector.set bv i with
      | .ok bv' => some [mvBitVectorToMoveValue bv']
      | .error _ => none
    | none => none
  | _ => none

/-- `bit_vector::unset(bv: &mut BitVector, i: u64)` — returns updated struct -/
def bitVectorUnset : List MoveValue → Option (List MoveValue)
  | [bv_mv, .u64 i] =>
    match moveValueToMvBitVector bv_mv with
    | some bv =>
      match MovementFormal.Std.BitVector.unset bv i with
      | .ok bv' => some [mvBitVectorToMoveValue bv']
      | .error _ => none
    | none => none
  | _ => none

/-- `bit_vector::is_index_set(bv: &BitVector, i: u64): bool` -/
def bitVectorIsIndexSet : List MoveValue → Option (List MoveValue)
  | [bv_mv, .u64 i] =>
    match moveValueToMvBitVector bv_mv with
    | some bv =>
      match MovementFormal.Std.BitVector.is_index_set bv i with
      | .ok b => some [.bool b]
      | .error _ => none
    | none => none
  | _ => none

/-- `bit_vector::shift_left(bv: &mut BitVector, amount: u64)` -/
def bitVectorShiftLeft : List MoveValue → Option (List MoveValue)
  | [bv_mv, .u64 amt] =>
    match moveValueToMvBitVector bv_mv with
    | some bv => some [mvBitVectorToMoveValue (MovementFormal.Std.BitVector.shift_left bv amt)]
    | none => none
  | _ => none

-- ── std::string (UTF-8 natives; `StringCatalog` / `Refinement/Std/StringCatalog`) ─

/-- `string::internal_check_utf8(v: &vector<u8>): bool` -/
def stringOracleInternalCheckUtf8 : List MoveValue → Option (List MoveValue)
  | [.vector .u8 elems] =>
    match Native.u8ElemsToByteArray elems with
    | some ba => some [.bool (MovementFormal.Std.String.utf8_bytes_well_formed ba.toList)]
    | none => none
  | _ => none

/-- `string::internal_sub_string(v, i, j)` — byte slice; `none` if indices are inconsistent with VM
    preconditions (Lean difftest rows use only in-range `i ≤ j`). -/
def stringOracleInternalSubString : List MoveValue → Option (List MoveValue)
  | [.vector .u8 elems, .u64 i, .u64 j] =>
    match Native.u8ElemsToByteArray elems with
    | some ba =>
      let bs := ba.toList
      let iN := i.toNat
      let jN := j.toNat
      if jN < iN ∨ jN > bs.length ∨ iN > bs.length then none
      else
        let out := MovementFormal.Std.String.internalSubStringBytes bs iN jN
        some [Native.bytesToMoveVec (ByteArray.mk (List.toArray out))]
    | none => none
  | _ => none

/-- `string::internal_index_of(hay, needle): u64` (Rust `str::find` byte offset or full length). -/
def stringOracleInternalIndexOf : List MoveValue → Option (List MoveValue)
  | [.vector .u8 hayE, .vector .u8 needE] =>
    match Native.u8ElemsToByteArray hayE, Native.u8ElemsToByteArray needE with
    | some hay, some need =>
      some [.u64 (UInt64.ofNat (MovementFormal.Std.String.byteIndexOf hay.toList need.toList))]
    | _, _ => none
  | _ => none

/-- `string::internal_is_char_boundary(v, i): bool` — Rust `str::is_char_boundary` on an unchecked UTF-8 view
(`MovementFormal.Std.String.utf8CharBoundaryAt`). -/
def stringOracleInternalIsCharBoundary : List MoveValue → Option (List MoveValue)
  | [.vector .u8 elems, .u64 i] =>
    match Native.u8ElemsToByteArray elems with
    | some ba =>
      some [.bool (MovementFormal.Std.String.utf8CharBoundaryAt ba.toList i.toNat)]
    | none => none
  | _ => none

-- ── std::cmp (`u64` / `bool` / `u8` / `u16` / `u32` / `u128` / `u256` / `address`; `CmpCatalog`)

/-- `cmp::is_eq(&cmp::compare(&a,&b))` for `u64` — matches VM native `compare`. -/
def cmpOracleIsEq : List MoveValue → Option (List MoveValue)
  | [.u64 a, .u64 b] => some [.bool (isEq (compareU64 a b))]
  | _ => none

def cmpOracleIsNe : List MoveValue → Option (List MoveValue)
  | [.u64 a, .u64 b] => some [.bool (isNe (compareU64 a b))]
  | _ => none

def cmpOracleIsLt : List MoveValue → Option (List MoveValue)
  | [.u64 a, .u64 b] => some [.bool (isLt (compareU64 a b))]
  | _ => none

def cmpOracleIsLe : List MoveValue → Option (List MoveValue)
  | [.u64 a, .u64 b] => some [.bool (isLe (compareU64 a b))]
  | _ => none

def cmpOracleIsGt : List MoveValue → Option (List MoveValue)
  | [.u64 a, .u64 b] => some [.bool (isGt (compareU64 a b))]
  | _ => none

def cmpOracleIsGe : List MoveValue → Option (List MoveValue)
  | [.u64 a, .u64 b] => some [.bool (isGe (compareU64 a b))]
  | _ => none

def cmpOracleBoolIsEq : List MoveValue → Option (List MoveValue)
  | [.bool a, .bool b] => some [.bool (isEq (compareBool a b))]
  | _ => none

def cmpOracleBoolIsNe : List MoveValue → Option (List MoveValue)
  | [.bool a, .bool b] => some [.bool (isNe (compareBool a b))]
  | _ => none

def cmpOracleBoolIsLt : List MoveValue → Option (List MoveValue)
  | [.bool a, .bool b] => some [.bool (isLt (compareBool a b))]
  | _ => none

def cmpOracleBoolIsLe : List MoveValue → Option (List MoveValue)
  | [.bool a, .bool b] => some [.bool (isLe (compareBool a b))]
  | _ => none

def cmpOracleBoolIsGt : List MoveValue → Option (List MoveValue)
  | [.bool a, .bool b] => some [.bool (isGt (compareBool a b))]
  | _ => none

def cmpOracleBoolIsGe : List MoveValue → Option (List MoveValue)
  | [.bool a, .bool b] => some [.bool (isGe (compareBool a b))]
  | _ => none

def cmpOracleU8IsEq : List MoveValue → Option (List MoveValue)
  | [.u8 a, .u8 b] => some [.bool (isEq (compareU8 a b))]
  | _ => none

def cmpOracleU8IsNe : List MoveValue → Option (List MoveValue)
  | [.u8 a, .u8 b] => some [.bool (isNe (compareU8 a b))]
  | _ => none

def cmpOracleU8IsLt : List MoveValue → Option (List MoveValue)
  | [.u8 a, .u8 b] => some [.bool (isLt (compareU8 a b))]
  | _ => none

def cmpOracleU8IsLe : List MoveValue → Option (List MoveValue)
  | [.u8 a, .u8 b] => some [.bool (isLe (compareU8 a b))]
  | _ => none

def cmpOracleU8IsGt : List MoveValue → Option (List MoveValue)
  | [.u8 a, .u8 b] => some [.bool (isGt (compareU8 a b))]
  | _ => none

def cmpOracleU8IsGe : List MoveValue → Option (List MoveValue)
  | [.u8 a, .u8 b] => some [.bool (isGe (compareU8 a b))]
  | _ => none

def cmpOracleAddressIsEq : List MoveValue → Option (List MoveValue)
  | [.address a, .address b] => some [.bool (isEq (compareAddress a b))]
  | _ => none

def cmpOracleAddressIsNe : List MoveValue → Option (List MoveValue)
  | [.address a, .address b] => some [.bool (isNe (compareAddress a b))]
  | _ => none

def cmpOracleAddressIsLt : List MoveValue → Option (List MoveValue)
  | [.address a, .address b] => some [.bool (isLt (compareAddress a b))]
  | _ => none

def cmpOracleAddressIsLe : List MoveValue → Option (List MoveValue)
  | [.address a, .address b] => some [.bool (isLe (compareAddress a b))]
  | _ => none

def cmpOracleAddressIsGt : List MoveValue → Option (List MoveValue)
  | [.address a, .address b] => some [.bool (isGt (compareAddress a b))]
  | _ => none

def cmpOracleAddressIsGe : List MoveValue → Option (List MoveValue)
  | [.address a, .address b] => some [.bool (isGe (compareAddress a b))]
  | _ => none

def cmpOracleU128IsEq : List MoveValue → Option (List MoveValue)
  | [.u128 a, .u128 b] => some [.bool (isEq (compareU128 a b))]
  | _ => none

def cmpOracleU128IsNe : List MoveValue → Option (List MoveValue)
  | [.u128 a, .u128 b] => some [.bool (isNe (compareU128 a b))]
  | _ => none

def cmpOracleU128IsLt : List MoveValue → Option (List MoveValue)
  | [.u128 a, .u128 b] => some [.bool (isLt (compareU128 a b))]
  | _ => none

def cmpOracleU128IsLe : List MoveValue → Option (List MoveValue)
  | [.u128 a, .u128 b] => some [.bool (isLe (compareU128 a b))]
  | _ => none

def cmpOracleU128IsGt : List MoveValue → Option (List MoveValue)
  | [.u128 a, .u128 b] => some [.bool (isGt (compareU128 a b))]
  | _ => none

def cmpOracleU128IsGe : List MoveValue → Option (List MoveValue)
  | [.u128 a, .u128 b] => some [.bool (isGe (compareU128 a b))]
  | _ => none

def cmpOracleU16IsEq : List MoveValue → Option (List MoveValue)
  | [.u16 a, .u16 b] => some [.bool (isEq (compareU16 a b))]
  | _ => none

def cmpOracleU16IsNe : List MoveValue → Option (List MoveValue)
  | [.u16 a, .u16 b] => some [.bool (isNe (compareU16 a b))]
  | _ => none

def cmpOracleU16IsLt : List MoveValue → Option (List MoveValue)
  | [.u16 a, .u16 b] => some [.bool (isLt (compareU16 a b))]
  | _ => none

def cmpOracleU16IsLe : List MoveValue → Option (List MoveValue)
  | [.u16 a, .u16 b] => some [.bool (isLe (compareU16 a b))]
  | _ => none

def cmpOracleU16IsGt : List MoveValue → Option (List MoveValue)
  | [.u16 a, .u16 b] => some [.bool (isGt (compareU16 a b))]
  | _ => none

def cmpOracleU16IsGe : List MoveValue → Option (List MoveValue)
  | [.u16 a, .u16 b] => some [.bool (isGe (compareU16 a b))]
  | _ => none

def cmpOracleU32IsEq : List MoveValue → Option (List MoveValue)
  | [.u32 a, .u32 b] => some [.bool (isEq (compareU32 a b))]
  | _ => none

def cmpOracleU32IsNe : List MoveValue → Option (List MoveValue)
  | [.u32 a, .u32 b] => some [.bool (isNe (compareU32 a b))]
  | _ => none

def cmpOracleU32IsLt : List MoveValue → Option (List MoveValue)
  | [.u32 a, .u32 b] => some [.bool (isLt (compareU32 a b))]
  | _ => none

def cmpOracleU32IsLe : List MoveValue → Option (List MoveValue)
  | [.u32 a, .u32 b] => some [.bool (isLe (compareU32 a b))]
  | _ => none

def cmpOracleU32IsGt : List MoveValue → Option (List MoveValue)
  | [.u32 a, .u32 b] => some [.bool (isGt (compareU32 a b))]
  | _ => none

def cmpOracleU32IsGe : List MoveValue → Option (List MoveValue)
  | [.u32 a, .u32 b] => some [.bool (isGe (compareU32 a b))]
  | _ => none

def cmpOracleU256IsEq : List MoveValue → Option (List MoveValue)
  | [.u256 a, .u256 b] => some [.bool (isEq (compareU256 a b))]
  | _ => none

def cmpOracleU256IsNe : List MoveValue → Option (List MoveValue)
  | [.u256 a, .u256 b] => some [.bool (isNe (compareU256 a b))]
  | _ => none

def cmpOracleU256IsLt : List MoveValue → Option (List MoveValue)
  | [.u256 a, .u256 b] => some [.bool (isLt (compareU256 a b))]
  | _ => none

def cmpOracleU256IsLe : List MoveValue → Option (List MoveValue)
  | [.u256 a, .u256 b] => some [.bool (isLe (compareU256 a b))]
  | _ => none

def cmpOracleU256IsGt : List MoveValue → Option (List MoveValue)
  | [.u256 a, .u256 b] => some [.bool (isGt (compareU256 a b))]
  | _ => none

def cmpOracleU256IsGe : List MoveValue → Option (List MoveValue)
  | [.u256 a, .u256 b] => some [.bool (isGe (compareU256 a b))]
  | _ => none

-- ── std::acl (`ACL { list: vector<address> }`) ───────────────────────────────

/-- Recognize ACL wire (`struct` with a single `vector<address>` field). -/
def moveValueToMvAcl : MoveValue → Option MvAcl
  | .struct_ [.vector .address elems] =>
      elems.mapM fun v => match v with | .address bs => some bs | _ => none
  | _ => none

/-- ACL wire from an address list (insertion order). -/
def aclWireOf (a : MvAcl) : MoveValue :=
  .struct_ [.vector .address (a.map MoveValue.address)]

def aclOracleEmpty : List MoveValue → Option (List MoveValue)
  | [] => some [aclWireOf MovementFormal.Std.Acl.empty]
  | _ => none

def aclOracleContains : List MoveValue → Option (List MoveValue)
  | [mv, .address addr] =>
    match moveValueToMvAcl mv with
    | some l => some [.bool (MovementFormal.Std.Acl.contains l addr)]
    | none => none
  | _ => none

def aclOracleAdd : List MoveValue → Option (List MoveValue)
  | [mv, .address addr] =>
    match moveValueToMvAcl mv with
    | some l =>
      match MovementFormal.Std.Acl.add l addr with
      | .ok a' => some [aclWireOf a']
      | .error _ => none
    | none => none
  | _ => none

def aclOracleRemove : List MoveValue → Option (List MoveValue)
  | [mv, .address addr] =>
    match moveValueToMvAcl mv with
    | some l =>
      match MovementFormal.Std.Acl.remove l addr with
      | .ok a' => some [aclWireOf a']
      | .error _ => none
    | none => none
  | _ => none

/-- `assert_contains` — void return on success. -/
def aclOracleAssertContains : List MoveValue → Option (List MoveValue)
  | [mv, .address addr] =>
    match moveValueToMvAcl mv with
    | some l =>
      match MovementFormal.Std.Acl.assertContains l addr with
      | .ok () => some []
      | .error _ => none
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
  fun args => withOpt t args (fun opt => some [.bool (MovementFormal.Std.Option.isNone opt)])

/-- `option::is_some(t: &Option<T>): bool` -/
def optionIsSome (t : MoveType) : List MoveValue → Option (List MoveValue) :=
  fun args => withOpt t args (fun opt => some [.bool (MovementFormal.Std.Option.isSome opt)])

/-- `option::contains(t: &Option<T>, e: &T): bool` -/
def optionContains (t : MoveType) : List MoveValue → Option (List MoveValue)
  | [mv, e] =>
    match moveOptionToMvOption t mv with
    | some opt => some [.bool (MovementFormal.Std.Option.contains' opt e)]
    | none => none
  | _ => none

/-- `option::borrow(t: &Option<T>): &T` — returns the inner value (value semantics) -/
def optionBorrow (t : MoveType) : List MoveValue → Option (List MoveValue) :=
  fun args => withOpt t args (fun opt =>
    match MovementFormal.Std.Option.borrow' opt with
    | some v => some [v]
    | none   => none)

/-- `option::fill(t: &mut Option<T>, e: T)` — fills none; aborts on some -/
def optionFill (t : MoveType) : List MoveValue → Option (List MoveValue)
  | [mv, e] =>
    match moveOptionToMvOption t mv with
    | some opt =>
      match MovementFormal.Std.Option.fill' opt e with
      | .ok opt' => some [mvOptionToMoveValue t opt']
      | .error _ => none
    | none => none
  | _ => none

/-- `option::extract(t: &mut Option<T>): T` -/
def optionExtract (t : MoveType) : List MoveValue → Option (List MoveValue) :=
  fun args => withOpt t args (fun opt =>
    match MovementFormal.Std.Option.extract' opt with
    | .ok (v, opt') => some [v, mvOptionToMoveValue t opt']
    | .error _      => none)

/-- `option::swap(t: &mut Option<T>, e: T): T` -/
def optionSwap (t : MoveType) : List MoveValue → Option (List MoveValue)
  | [mv, e] =>
    match moveOptionToMvOption t mv with
    | some opt =>
      match MovementFormal.Std.Option.swap' opt e with
      | .ok (old, opt') => some [old, mvOptionToMoveValue t opt']
      | .error _        => none
    | none => none
  | _ => none

/-- `option::swap_or_fill(t: &mut Option<T>, e: T): Option<T>` -/
def optionSwapOrFill (t : MoveType) : List MoveValue → Option (List MoveValue)
  | [mv, e] =>
    match moveOptionToMvOption t mv with
    | some opt =>
      let (displaced, updated) := MovementFormal.Std.Option.swapOrFill opt e
      some [mvOptionToMoveValue t displaced, mvOptionToMoveValue t updated]
    | none => none
  | _ => none

/-- `option::destroy_none(t: Option<T>)` — aborts if some -/
def optionDestroyNone (t : MoveType) : List MoveValue → Option (List MoveValue) :=
  fun args => withOpt t args (fun opt =>
    match MovementFormal.Std.Option.destroyNone opt with
    | .ok () => some []
    | .error _ => none)

/-- `option::destroy_some(t: Option<T>): T` -/
def optionDestroySome (t : MoveType) : List MoveValue → Option (List MoveValue) :=
  fun args => withOpt t args (fun opt =>
    match MovementFormal.Std.Option.destroySome opt with
    | .ok v    => some [v]
    | .error _ => none)

/-! ### `Option<u64>` VM↔Lean oracle (`(is_some, inner, …)` scratch args)

Materializes `MovementFormal.Std.Option.MoveOption` from booleans + u64s the same way as
`0x1::difftest_option` in Rust; compares against `option::` on the VM. -/

def optionOracleU64IsNone : List MoveValue → Option (List MoveValue)
  | [.bool b, .u64 x] =>
    let opt : MoveOption MoveValue := if b then some' (.u64 x) else none'
    some [.bool (isNone opt)]
  | _ => none

def optionOracleU64IsSome : List MoveValue → Option (List MoveValue)
  | [.bool b, .u64 x] =>
    let opt : MoveOption MoveValue := if b then some' (.u64 x) else none'
    some [.bool (isSome opt)]
  | _ => none

def optionOracleU64Contains : List MoveValue → Option (List MoveValue)
  | [.bool b, .u64 inner, .u64 e] =>
    let opt : MoveOption MoveValue := if b then some' (.u64 inner) else none'
    some [.bool (MovementFormal.Std.Option.contains' opt (.u64 e))]
  | _ => none

def optionOracleU64GetWithDefault : List MoveValue → Option (List MoveValue)
  | [.bool b, .u64 inner, .u64 dflt] =>
    let opt : MoveOption MoveValue := if b then some' (.u64 inner) else none'
    some [borrowWithDefault opt (.u64 dflt)]
  | _ => none

/-- `borrow_with_default` — same scratch semantics as `get_with_default` for `Option<u64>`. -/
def optionOracleU64BorrowWithDefault : List MoveValue → Option (List MoveValue) :=
  optionOracleU64GetWithDefault

/-- `destroy_with_default` — same result value as `get_with_default` for `Option<u64>`. -/
def optionOracleU64DestroyWithDefault : List MoveValue → Option (List MoveValue) :=
  optionOracleU64GetWithDefault

/-- `to_vec` — underlying list is `opt.vec` (empty or one `u64`). -/
def optionOracleU64ToVec : List MoveValue → Option (List MoveValue)
  | [.bool b, .u64 x] =>
    let opt : MoveOption MoveValue := if b then some' (.u64 x) else none'
    some [.vector .u64 (toVec opt)]
  | _ => none

/-- `from_vec` — `ok` on length ≤ 1; `abort` with `EOPTION_VEC_TOO_LONG` otherwise (VM `assert!`). -/
def optionOracleU64FromVec : List MoveValue → Option (Except UInt64 (List MoveValue))
  | [.vector .u64 xs] =>
    match fromVec xs with
    | .ok opt => some (.ok [optionStructValue .u64 opt])
    | .error c => some (.error c)
  | _ => none

/-- `option::none<u64>()` — empty option wire. -/
def optionOracleU64StdNone : List MoveValue → Option (List MoveValue)
  | [] => some [optionStructValue .u64 none']
  | _ => none

/-- `option::some(x)` for `u64`. -/
def optionOracleU64StdSome : List MoveValue → Option (List MoveValue)
  | [.u64 x] => some [optionStructValue .u64 (some' (.u64 x))]
  | _ => none

def optionOracleU64Borrow : List MoveValue → Option (Except UInt64 (List MoveValue))
  | [.bool true, .u64 v] =>
    match borrow' (some' (.u64 v)) with
    | some x => some (.ok [x])
    | none => none
  | [.bool false, _] => some (.error EOPTION_NOT_SET)
  | _ => none

/-- Matches Move `fill`: no return values (mutation only). -/
def optionOracleU64Fill : List MoveValue → Option (Except UInt64 (List MoveValue))
  | [.bool false, _, .u64 e] =>
    match fill' none' (.u64 e) with
    | .ok _ => some (.ok [])
    | .error c => some (.error c)
  | [.bool true, .u64 inner, .u64 e] =>
    match fill' (some' (.u64 inner)) (.u64 e) with
    | .error c => some (.error c)
    | .ok _ => none
  | _ => none

/-- Matches Move `extract`: returns the popped element only. -/
def optionOracleU64Extract : List MoveValue → Option (Except UInt64 (List MoveValue))
  | [.bool true, .u64 v] =>
    match extract' (some' (.u64 v)) with
    | .ok (val, _) => some (.ok [val])
    | .error c => some (.error c)
  | [.bool false, _] => some (.error EOPTION_NOT_SET)
  | _ => none

/-- Matches Move `swap`: returns the old element only. -/
def optionOracleU64Swap : List MoveValue → Option (Except UInt64 (List MoveValue))
  | [.bool true, .u64 v, .u64 e] =>
    match swap' (some' (.u64 v)) (.u64 e) with
    | .ok (old, _) => some (.ok [old])
    | .error c => some (.error c)
  | [.bool false, _, .u64 _e] => some (.error EOPTION_NOT_SET)
  | _ => none

/-- Matches Move `swap_or_fill`: returns displaced `Option` only. -/
def optionOracleU64SwapOrFill : List MoveValue → Option (List MoveValue)
  | [.bool b, .u64 inner, .u64 e] =>
    let opt : MoveOption MoveValue := if b then some' (.u64 inner) else none'
    let p := MovementFormal.Std.Option.swapOrFill opt (.u64 e)
    some [optionStructValue .u64 p.1]
  | _ => none

def optionOracleU64DestroyNone : List MoveValue → Option (Except UInt64 (List MoveValue))
  | [.bool false, _] =>
    match destroyNone none' with
    | .ok () => some (.ok [])
    | .error c => some (.error c)
  | [.bool true, .u64 v] =>
    match destroyNone (some' (.u64 v)) with
    | .error c => some (.error c)
    | .ok () => none
  | _ => none

def optionOracleU64DestroySome : List MoveValue → Option (Except UInt64 (List MoveValue))
  | [.bool true, .u64 v] =>
    match destroySome (some' (.u64 v)) with
    | .ok x => some (.ok [x])
    | .error c => some (.error c)
  | [.bool false, _] => some (.error EOPTION_NOT_SET)
  | _ => none

end MovementFormal.MoveModel.Native.StdPrimitives
