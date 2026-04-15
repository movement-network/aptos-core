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
  else .ok ⟨length, Array.replicate length.toNat false, Array.size_replicate _ _⟩

-- ── helpers for index bounds ──────────────────────────────────────────────────

private theorem idx_lt_size (bv : MvBitVector) (i : UInt64) (hi : i < bv.length) :
    i.toNat < bv.bit_field.size := by
  rw [bv.inv]; exact UInt64.toNat_lt_toNat.mpr hi

-- ── Mutation ─────────────────────────────────────────────────────────────────

def set (bv : MvBitVector) (i : UInt64) : Except UInt64 MvBitVector :=
  if h : i ≥ bv.length then .error EINDEX
  else
    have hi : i.toNat < bv.bit_field.size := idx_lt_size bv i (UInt64.lt_of_not_le h)
    let arr' := bv.bit_field.set ⟨i.toNat, hi⟩ true
    .ok ⟨bv.length, arr', by simp [arr', Array.size_set, bv.inv]⟩

def unset (bv : MvBitVector) (i : UInt64) : Except UInt64 MvBitVector :=
  if h : i ≥ bv.length then .error EINDEX
  else
    have hi : i.toNat < bv.bit_field.size := idx_lt_size bv i (UInt64.lt_of_not_le h)
    let arr' := bv.bit_field.set ⟨i.toNat, hi⟩ false
    .ok ⟨bv.length, arr', by simp [arr', Array.size_set, bv.inv]⟩

-- ── Queries ───────────────────────────────────────────────────────────────────

def is_index_set (bv : MvBitVector) (i : UInt64) : Except UInt64 Bool :=
  if h : i ≥ bv.length then .error EINDEX
  else
    have hi : i.toNat < bv.bit_field.size := idx_lt_size bv i (UInt64.lt_of_not_le h)
    .ok bv.bit_field[i.toNat]'hi

def bvLength (bv : MvBitVector) : UInt64 := bv.length

-- ── Shift ─────────────────────────────────────────────────────────────────────

def shift_left (bv : MvBitVector) (amount : UInt64) : MvBitVector :=
  if amount ≥ bv.length then
    ⟨bv.length, Array.replicate bv.length.toNat false, Array.size_replicate _ _⟩
  else
    let n := bv.length.toNat
    let k := amount.toNat
    let newField : Array Bool := Array.ofFn (n := n) fun i =>
      if h : i.val + k < n then
        have hlt : i.val + k < bv.bit_field.size := bv.inv ▸ h
        bv.bit_field[i.val + k]'hlt
      else false
    ⟨bv.length, newField, by simp [newField, Array.size_ofFn]⟩

-- ── Theorems ──────────────────────────────────────────────────────────────────

/-- `new` succeeds iff 0 < len < MAX_SIZE, and the result has the right length. -/
@[simp] theorem new_ok_length {len : UInt64} (h0 : len ≠ 0) (hmax : len < MAX_SIZE)
    {bv : MvBitVector} (hnew : new len = .ok bv) : bv.length = len := by
  simp only [new, h0, ↓reduceIte, ge_iff_le, not_le] at hnew
  simp only [hmax, ↓reduceIte] at hnew
  simp only [Except.ok.injEq] at hnew
  rw [← hnew]

@[simp] theorem new_ok_all_false {len : UInt64} (h0 : len ≠ 0) (hmax : len < MAX_SIZE)
    {bv : MvBitVector} (hnew : new len = .ok bv)
    {i : Nat} (hi : i < len.toNat) : bv.bit_field[i]? = some false := by
  simp only [new, h0, ↓reduceIte, ge_iff_le, not_le, hmax, Except.ok.injEq] at hnew
  rw [← hnew]
  simp [Array.getElem?_replicate, hi]

theorem set_ok_length {bv bv' : MvBitVector} {i : UInt64}
    (hs : set bv i = .ok bv') : bv'.length = bv.length := by
  simp only [set] at hs
  split_ifs at hs with h
  · simp at hs
  · simp only [Except.ok.injEq] at hs; rw [← hs]

theorem unset_ok_length {bv bv' : MvBitVector} {i : UInt64}
    (hs : unset bv i = .ok bv') : bv'.length = bv.length := by
  simp only [unset] at hs
  split_ifs at hs with h
  · simp at hs
  · simp only [Except.ok.injEq] at hs; rw [← hs]

theorem set_ok_index {bv bv' : MvBitVector} {i : UInt64}
    (hs : set bv i = .ok bv') : is_index_set bv' i = .ok true := by
  simp only [set] at hs
  split_ifs at hs with h
  · simp at hs
  · simp only [Except.ok.injEq] at hs
    simp only [is_index_set, ← hs, ge_iff_le, not_le]
    have hlt := UInt64.lt_of_not_le h
    simp only [hlt, not_true, ge_iff_le, not_le, dif_neg (not_le.mpr hlt)]
    simp [Array.getElem_set_eq]

theorem unset_ok_index {bv bv' : MvBitVector} {i : UInt64}
    (hs : unset bv i = .ok bv') : is_index_set bv' i = .ok false := by
  simp only [unset] at hs
  split_ifs at hs with h
  · simp at hs
  · simp only [Except.ok.injEq] at hs
    simp only [is_index_set, ← hs, ge_iff_le, not_le]
    have hlt := UInt64.lt_of_not_le h
    simp only [dif_neg (not_le.mpr hlt)]
    simp [Array.getElem_set_eq]

@[simp] theorem shift_left_length (bv : MvBitVector) (amt : UInt64) :
    (shift_left bv amt).length = bv.length := by
  simp [shift_left]; split_ifs <;> rfl

/-- Shifting by zero is identity. -/
theorem shift_left_zero (bv : MvBitVector) : shift_left bv 0 = bv := by
  simp only [shift_left, ge_iff_le, UInt64.le_zero_iff, ↓reduceIte]
  -- Only reaches here when 0 < bv.length (i.e. amount = 0, not ≥ bv.length)
  -- The if-condition is `0 ≥ bv.length` which is `bv.length = 0`.
  -- Case split: if bv.length = 0 the replicate branch gives same struct; else the ofFn branch.
  by_cases h : (0 : UInt64) ≥ bv.length
  · -- bv.length = 0, so both branches produce identical zero-length bitvectors
    simp only [h, ↓reduceIte]
    ext1
    · simp [UInt64.le_antisymm h (UInt64.zero_le _)]
    · have : bv.length = 0 := UInt64.le_antisymm h (UInt64.zero_le _)
      simp [this, bv.inv]
    · simp [UInt64.le_antisymm h (UInt64.zero_le _), bv.inv]
  · simp only [h, ↓reduceIte, UInt64.toNat_zero, Nat.add_zero]
    ext1
    · rfl
    · apply Array.ext
      · simp [Array.size_ofFn, bv.inv]
      · intro i hi₁ _
        simp only [Array.getElem_ofFn]
        have hlt : i < bv.bit_field.size := bv.inv ▸ hi₁
        simp [Nat.add_zero, hlt]
    · rfl

end AptosFormal.Std.BitVector
