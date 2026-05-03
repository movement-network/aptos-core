import MovementFormal.MoveModel.Value

/-!
# Lean specification for `std::cmp::Ordering` (predicate API)

`std::cmp::compare<T>` is **native** for general `T`. We model scalar orders used in VM↔Lean
difftest: **`u64`**, **`bool`** (Rust `bool::cmp`: `false < true`), **`u8`**, **`u16`**, **`u32`**,
**`u128`** (order on `U128.val`), **`u256`** (order on `U256.val`), and **`address`**
(lexicographic order on the underlying byte sequence — same as Rust `Ord` for `AccountAddress`).

Predicate helpers (`is_eq`, `is_ne`, …) match `aptos-move/framework/move-stdlib/sources/cmp.move`:
they are pure pattern tests on `Ordering`.

**Source:** `aptos-move/framework/move-stdlib/sources/cmp.move`
-/

namespace MovementFormal.Std.Cmp

/-- Mirrors `std::cmp::Ordering` (three variants). -/
inductive MvOrdering where
  | less
  | equal
  | greater
  deriving DecidableEq, Repr

/-- Total order for `u64`, aligned with Move `cmp::compare` on `u64` (same as Rust `u64::cmp`). -/
def compareU64 (a b : UInt64) : MvOrdering :=
  if a < b then .less
  else if a = b then .equal
  else .greater

/-- `bool::cmp` in Rust / Move VM: `false` is **less** than `true`. -/
def compareBool (a b : Bool) : MvOrdering :=
  match a, b with
  | false, false => .equal
  | false, true => .less
  | true, false => .greater
  | true, true => .equal

/-- Total order for `u8` (same as Rust `u8::cmp`). -/
def compareU8 (a b : UInt8) : MvOrdering :=
  if a < b then .less
  else if a = b then .equal
  else .greater

/-- Total order for `u16` (same as Rust `u16::cmp`). -/
def compareU16 (a b : UInt16) : MvOrdering :=
  if a < b then .less
  else if a = b then .equal
  else .greater

/-- Total order for `u32` (same as Rust `u32::cmp`). -/
def compareU32 (a b : UInt32) : MvOrdering :=
  if a < b then .less
  else if a = b then .equal
  else .greater

/-- Total order for `u128` (same as Rust `u128::cmp` on the underlying natural). -/
def compareU128 (a b : MovementFormal.MoveModel.U128) : MvOrdering :=
  let av := MovementFormal.MoveModel.U128.val a
  let bv := MovementFormal.MoveModel.U128.val b
  if av < bv then .less
  else if av = bv then .equal
  else .greater

/-- Total order for `u256` (same as Rust `U256` / lexicographic `Nat` order on `U256.val`). -/
def compareU256 (a b : MovementFormal.MoveModel.U256) : MvOrdering :=
  let av := MovementFormal.MoveModel.U256.val a
  let bv := MovementFormal.MoveModel.U256.val b
  if av < bv then .less
  else if av = bv then .equal
  else .greater

/-- Lexicographic order on byte lists (Rust `[u8]::cmp` / `Vec<u8>` order). -/
def compareBytesLex : List UInt8 → List UInt8 → MvOrdering
  | [], [] => .equal
  | [], _ :: _ => .less
  | _ :: _, [] => .greater
  | ha :: ta, hb :: tb =>
    if ha < hb then .less
    else if hb < ha then .greater
    else compareBytesLex ta tb
termination_by a b => a.length + b.length

/-- Lexicographic order on `address` / `ByteArray` (Move `address` compare). -/
def compareAddress (a b : ByteArray) : MvOrdering :=
  compareBytesLex a.toList b.toList

def isEq (o : MvOrdering) : Bool :=
  match o with | .equal => true | _ => false

def isNe (o : MvOrdering) : Bool :=
  match o with | .equal => false | _ => true

def isLt (o : MvOrdering) : Bool :=
  match o with | .less => true | _ => false

def isLe (o : MvOrdering) : Bool :=
  match o with | .greater => false | _ => true

def isGt (o : MvOrdering) : Bool :=
  match o with | .greater => true | _ => false

def isGe (o : MvOrdering) : Bool :=
  match o with | .less => false | _ => true

@[simp] theorem isEq_equal : isEq .equal = true := rfl
@[simp] theorem isEq_less : isEq .less = false := rfl
@[simp] theorem isEq_greater : isEq .greater = false := rfl

@[simp] theorem isNe_equal : isNe .equal = false := rfl
@[simp] theorem isNe_less : isNe .less = true := rfl

@[simp] theorem isLe_less : isLe .less = true := rfl
@[simp] theorem isLe_equal : isLe .equal = true := rfl
@[simp] theorem isLe_greater : isLe .greater = false := rfl

@[simp] theorem isGe_greater : isGe .greater = true := rfl
@[simp] theorem isGe_equal : isGe .equal = true := rfl
@[simp] theorem isGe_less : isGe .less = false := rfl

end MovementFormal.Std.Cmp
