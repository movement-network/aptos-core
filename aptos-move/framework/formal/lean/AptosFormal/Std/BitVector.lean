import AptosFormal.Move.Value

/-!
# Lean specification for `std::bit_vector`

`BitVector { length: u64, bit_field: vector<bool> }` with invariant
`bit_field.length == length`.

**Source:** `aptos-move/framework/move-stdlib/sources/bit_vector.move`
-/

namespace AptosFormal.Std.BitVector

open AptosFormal.Move

def EINDEX   : UInt64 := 0x20000
def ELENGTH  : UInt64 := 0x20001
def MAX_SIZE : UInt64 := 1024

@[ext]
structure MvBitVector where
  length    : UInt64
  bit_field : Array Bool
  inv       : bit_field.size = length.toNat
deriving Repr

-- ── Constructors ─────────────────────────────────────────────────────────────

def new (length : UInt64) : Except UInt64 MvBitVector :=
  if length = 0 then .error ELENGTH
  else if length ≥ MAX_SIZE then .error ELENGTH
  else
    let arr := Array.replicate length.toNat false
    .ok ⟨length, arr, Array.size_replicate length.toNat false⟩

-- ── Mutation ─────────────────────────────────────────────────────────────────

def set (bv : MvBitVector) (i : UInt64) : Except UInt64 MvBitVector :=
  if h : i ≥ bv.length then .error EINDEX
  else
    have hi : i.toNat < bv.bit_field.size := by
      rw [bv.inv]
      have hlt : i < bv.length := by simp [ge_iff_le, not_le] at h; exact h
      exact UInt64.toNat_lt_toNat.mpr hlt
    .ok ⟨bv.length, bv.bit_field.set ⟨i.toNat, hi⟩ true,
         by simp [Array.size_set, bv.inv]⟩

def unset (bv : MvBitVector) (i : UInt64) : Except UInt64 MvBitVector :=
  if h : i ≥ bv.length then .error EINDEX
  else
    have hi : i.toNat < bv.bit_field.size := by
      rw [bv.inv]
      have hlt : i < bv.length := by simp [ge_iff_le, not_le] at h; exact h
      exact UInt64.toNat_lt_toNat.mpr hlt
    .ok ⟨bv.length, bv.bit_field.set ⟨i.toNat, hi⟩ false,
         by simp [Array.size_set, bv.inv]⟩

-- ── Queries ───────────────────────────────────────────────────────────────────

def is_index_set (bv : MvBitVector) (i : UInt64) : Except UInt64 Bool :=
  if h : i ≥ bv.length then .error EINDEX
  else
    have hi : i.toNat < bv.bit_field.size := by
      rw [bv.inv]
      have hlt : i < bv.length := by simp [ge_iff_le, not_le] at h; exact h
      exact UInt64.toNat_lt_toNat.mpr hlt
    .ok bv.bit_field[i.toNat]'hi

def bvLength (bv : MvBitVector) : UInt64 := bv.length

-- ── Shift ─────────────────────────────────────────────────────────────────────

def shift_left (bv : MvBitVector) (amount : UInt64) : MvBitVector :=
  let n := bv.length.toNat
  let k := amount.toNat
  if amount ≥ bv.length then
    ⟨bv.length, Array.replicate n false, Array.size_replicate n false⟩
  else
    let newField : Array Bool := Array.ofFn (n := n) fun i =>
      if h : i.val + k < n then
        have hlt : i.val + k < bv.bit_field.size := bv.inv ▸ h
        bv.bit_field[i.val + k]'hlt
      else false
    ⟨bv.length, newField, by simp [Array.size_ofFn]⟩

-- ── Theorems ──────────────────────────────────────────────────────────────────

@[simp] theorem new_ok_length {len : UInt64} (h0 : len ≠ 0) (hmax : len < MAX_SIZE)
    {bv : MvBitVector} (hnew : new len = .ok bv) : bv.length = len := by
  simp only [new, h0, ↓reduceIte, ge_iff_le, not_le.mpr hmax] at hnew
  exact congrArg MvBitVector.length (Except.ok.inj hnew)

@[simp] theorem new_ok_all_false {len : UInt64} (h0 : len ≠ 0) (hmax : len < MAX_SIZE)
    {bv : MvBitVector} (hnew : new len = .ok bv)
    {i : Nat} (hi : i < len.toNat) : bv.bit_field[i]? = some false := by
  simp only [new, h0, ↓reduceIte, ge_iff_le, not_le.mpr hmax] at hnew
  have heq : bv = ⟨len, Array.replicate len.toNat false, _⟩ := Except.ok.inj hnew
  simp [heq, Array.getElem?_replicate, hi]

theorem set_ok_length {bv bv' : MvBitVector} {i : UInt64}
    (hs : set bv i = .ok bv') : bv'.length = bv.length := by
  simp only [set] at hs
  split_ifs at hs with h
  · exact absurd hs (by simp)
  · exact congrArg MvBitVector.length (Except.ok.inj hs)

theorem unset_ok_length {bv bv' : MvBitVector} {i : UInt64}
    (hs : unset bv i = .ok bv') : bv'.length = bv.length := by
  simp only [unset] at hs
  split_ifs at hs with h
  · exact absurd hs (by simp)
  · exact congrArg MvBitVector.length (Except.ok.inj hs)

@[simp] theorem shift_left_length (bv : MvBitVector) (amt : UInt64) :
    (shift_left bv amt).length = bv.length := by
  simp only [shift_left]
  split_ifs <;> rfl

/-- Shifting by zero is identity. -/
theorem shift_left_zero (bv : MvBitVector) : shift_left bv 0 = bv := by
  simp only [shift_left, UInt64.toNat_zero, ge_iff_le, UInt64.le_zero_iff]
  split_ifs with h
  · -- amount ≥ bv.length means bv.length = 0
    have hlen0 : bv.length = 0 := UInt64.le_antisymm h (UInt64.zero_le _)
    ext1
    · exact hlen0.symm
    · have : bv.bit_field.size = 0 := by rw [bv.inv, UInt64.toNat_eq_zero.mpr hlen0]
      simp [hlen0, Array.size_eq_zero.mp this, Array.size_replicate]
    · simp [hlen0]
  · -- amount = 0, not ≥ bv.length; ofFn identity
    ext1
    · rfl
    · apply Array.ext
      · simp [Array.size_ofFn, bv.inv]
      · intro j hj _
        simp only [Array.getElem_ofFn]
        have hlt : j < bv.bit_field.size := bv.inv ▸ hj
        simp [Nat.add_zero, hlt]
    · rfl

end AptosFormal.Std.BitVector
