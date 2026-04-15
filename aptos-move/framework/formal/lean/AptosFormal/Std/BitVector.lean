import AptosFormal.Move.Value
import Mathlib.Tactic.Omega

/-!
# Lean specification for `std::bit_vector`

`BitVector { length: u64, bit_field: vector<bool> }` with invariant
`bit_field.length == length`.
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

def new (length : UInt64) : Except UInt64 MvBitVector :=
  if length = 0 then .error ELENGTH
  else if length ≥ MAX_SIZE then .error ELENGTH
  else .ok ⟨length, Array.mkArray length.toNat false, Array.size_mkArray _ _⟩

def set (bv : MvBitVector) (i : UInt64) : Except UInt64 MvBitVector :=
  if i ≥ bv.length then .error EINDEX
  else
    let arr' := bv.bit_field.set ⟨i.toNat, by have := bv.inv; omega⟩ true
    .ok ⟨bv.length, arr', by simp [arr_, bv.inv]⟩

def unset (bv : MvBitVector) (i : UInt64) : Except UInt64 MvBitVector :=
  if i ≥ bv.length then .error EINDEX
  else
    let arr' := bv.bit_field.set ⟨i.toNat, by have := bv.inv; omega⟩ false
    .ok ⟨bv.length, arr', by simp [arr_, bv.inv]⟩

def is_index_set (bv : MvBitVector) (i : UInt64) : Except UInt64 Bool :=
  if i ≥ bv.length then .error EINDEX
  else .ok (bv.bit_field.get ⟨i.toNat, by have := bv.inv; omega⟩)

def shift_left (bv : MvBitVector) (amount : UInt64) : MvBitVector :=
  if amount ≥ bv.length then
    ⟨bv.length, Array.mkArray bv.length.toNat false, Array.size_mkArray _ _⟩
  else
    let n := bv.length.toNat
    let k := amount.toNat
    let newField := Array.ofFn (n := n) fun i =>
      if i.val + k < n then bv.bit_field.get ⟨i.val + k, by omega⟩ else false
    ⟨bv.length, newField, by simp [newField, Array.size_ofFn]⟩

theorem new_length (len : UInt64) (h0 : len ≠ 0) (hmax : len < MAX_SIZE)
    (bv : MvBitVector) (hnew : new len = .ok bv) : bv.length = len := by
  simp [new, h0, hmax] at hnew; subst hnew; rfl

theorem new_all_false (len : UInt64) (h0 : len ≠ 0) (hmax : len < MAX_SIZE)
    (bv : MvBitVector) (hnew : new len = .ok bv) (i : Nat) (hi : i < len.toNat) :
    bv.bit_field[i]? = some false := by
  simp [new, h0, hmax] at hnew; subst hnew; simp [Array.getElem?_mkArray, hi]

theorem shift_left_copies_front (bv : MvBitVector) (amount : UInt64) (hamt : amount < bv.length)
    (i : Nat) (hi : i + amount.toNat < bv.length.toNat) :
    (shift_left bv amount).bit_field.get ⟨i, by simp [shift_left, (by exact UInt64.not_le.mpr (by exact UInt64.lt_iff_toNat_lt.mp hamt)), Array.size_ofFn]; omega⟩ =
      bv.bit_field.get ⟨i + amount.toNat, by have := bv.inv; omega⟩ := by
  simp [shift_left, UInt64.not_le.mpr (by exact UInt64.lt_iff_toNat_lt.mp hamt), Array.get_ofFn, hi]

end AptosFormal.Std.BitVector
