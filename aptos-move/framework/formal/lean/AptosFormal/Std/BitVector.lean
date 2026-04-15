import AptosFormal.Move.Value
import Mathlib.Tactic.Omega

/-!
# Lean specification for `std::bit_vector`

`BitVector { length: u64, bit_field: vector<bool> }` with invariant
`bit_field.length == length`.

**Source:** `aptos-move/framework/move-stdlib/sources/bit_vector.move`

## Bug-fix note
PR #1 had a typo: `arr_` instead of `arr'` in the `simp` calls inside
`set` and `unset`, causing a compile error. Fixed below.
-/

namespace AptosFormal.Std.BitVector

open AptosFormal.Move

def EINDEX   : UInt64 := 0x20000
def ELENGTH  : UInt64 := 0x20001
def MAX_SIZE : UInt64 := 1024

structure MvBitVector where
  length    : UInt64
  bit_field : Array Bool
  inv       : bit_field.size = length.toNat
deriving Repr

-- ── Constructors ─────────────────────────────────────────────────────────────

def new (length : UInt64) : Except UInt64 MvBitVector :=
  if length = 0 then .error ELENGTH
  else if length ≥ MAX_SIZE then .error ELENGTH
  else .ok ⟨length, Array.mkArray length.toNat false, Array.size_mkArray _ _⟩

-- ── Mutation (pure, returns new struct) ─────────────────────────────────────

/-- Set bit at index `i` to `true`. -/
def set (bv : MvBitVector) (i : UInt64) : Except UInt64 MvBitVector :=
  if i ≥ bv.length then .error EINDEX
  else
    have hi : i.toNat < bv.bit_field.size := by
      have := bv.inv; simp [UInt64.lt_iff_toNat_lt] at *; omega
    let arr' := bv.bit_field.set ⟨i.toNat, hi⟩ true
    -- FIX: was `arr_` (typo) — must be `arr'`
    .ok ⟨bv.length, arr', by simp [arr', bv.inv]⟩

/-- Set bit at index `i` to `false`. -/
def unset (bv : MvBitVector) (i : UInt64) : Except UInt64 MvBitVector :=
  if i ≥ bv.length then .error EINDEX
  else
    have hi : i.toNat < bv.bit_field.size := by
      have := bv.inv; simp [UInt64.lt_iff_toNat_lt] at *; omega
    let arr' := bv.bit_field.set ⟨i.toNat, hi⟩ false
    -- FIX: was `arr_` (typo) — must be `arr'`
    .ok ⟨bv.length, arr', by simp [arr', bv.inv]⟩

-- ── Queries ──────────────────────────────────────────────────────────────────

def is_index_set (bv : MvBitVector) (i : UInt64) : Except UInt64 Bool :=
  if i ≥ bv.length then .error EINDEX
  else
    have hi : i.toNat < bv.bit_field.size := by
      have := bv.inv; simp [UInt64.lt_iff_toNat_lt] at *; omega
    .ok (bv.bit_field.get ⟨i.toNat, hi⟩)

@[simp] def length (bv : MvBitVector) : UInt64 := bv.length

-- ── Shift ────────────────────────────────────────────────────────────────────

def shift_left (bv : MvBitVector) (amount : UInt64) : MvBitVector :=
  if amount ≥ bv.length then
    ⟨bv.length, Array.mkArray bv.length.toNat false, Array.size_mkArray _ _⟩
  else
    let n := bv.length.toNat
    let k := amount.toNat
    let newField := Array.ofFn (n := n) fun i =>
      if i.val + k < n then
        have : i.val + k < bv.bit_field.size := by have := bv.inv; omega
        bv.bit_field.get ⟨i.val + k, this⟩
      else false
    ⟨bv.length, newField, by simp [newField, Array.size_ofFn]⟩

-- ── Theorems ─────────────────────────────────────────────────────────────────

@[simp] theorem new_ok_length (len : UInt64) (h0 : len ≠ 0) (hmax : len < MAX_SIZE)
    (bv : MvBitVector) (hnew : new len = .ok bv) : bv.length = len := by
  simp [new, h0, hmax] at hnew; subst hnew; rfl

@[simp] theorem new_ok_all_false (len : UInt64) (h0 : len ≠ 0) (hmax : len < MAX_SIZE)
    (bv : MvBitVector) (hnew : new len = .ok bv)
    (i : Nat) (hi : i < len.toNat) : bv.bit_field[i]? = some false := by
  simp [new, h0, hmax] at hnew; subst hnew
  simp [Array.getElem?_mkArray, hi]

theorem set_ok_length (bv bv' : MvBitVector) (i : UInt64)
    (hs : set bv i = .ok bv') : bv'.length = bv.length := by
  simp [set] at hs; split_ifs at hs with h <;> simp_all

theorem unset_ok_length (bv bv' : MvBitVector) (i : UInt64)
    (hs : unset bv i = .ok bv') : bv'.length = bv.length := by
  simp [unset] at hs; split_ifs at hs with h <;> simp_all

theorem set_ok_index (bv bv' : MvBitVector) (i : UInt64)
    (hs : set bv i = .ok bv') :
    is_index_set bv' i = .ok true := by
  simp [set, is_index_set] at *
  split_ifs at hs with h
  · simp_all
  · simp_all [Array.get_set_eq]

theorem unset_ok_index (bv bv' : MvBitVector) (i : UInt64)
    (hs : unset bv i = .ok bv') :
    is_index_set bv' i = .ok false := by
  simp [unset, is_index_set] at *
  split_ifs at hs with h
  · simp_all
  · simp_all [Array.get_set_eq]

@[simp] theorem shift_left_length (bv : MvBitVector) (amt : UInt64) :
    (shift_left bv amt).length = bv.length := rfl

theorem shift_left_zero (bv : MvBitVector) : shift_left bv 0 = bv := by
  simp [shift_left]
  sorry  -- Array.ofFn identity; flagged, requires funext + bv.inv

end AptosFormal.Std.BitVector
