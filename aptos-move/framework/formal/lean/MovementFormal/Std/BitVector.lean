import MovementFormal.MoveModel.Value

/-!
# Lean specification for `std::bit_vector`
-/

namespace MovementFormal.Std.BitVector

open MovementFormal.MoveModel

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
  else .ok ⟨length, Array.replicate length.toNat false, by simp⟩

-- ── private helper ────────────────────────────────────────────────────────────

private theorem idx_lt_size (bv : MvBitVector) {i : UInt64} (h : ¬ i ≥ bv.length) :
    i.toNat < bv.bit_field.size := by
  rw [bv.inv]
  -- goal: i.toNat < bv.length.toNat
  -- h : ¬ i ≥ bv.length, i.e. ¬ bv.length ≤ i
  rw [ge_iff_le, UInt64.le_iff_toNat_le] at h
  -- h : ¬ bv.length.toNat ≤ i.toNat
  omega

-- ── Mutation ─────────────────────────────────────────────────────────────────

def set (bv : MvBitVector) (i : UInt64) : Except UInt64 MvBitVector :=
  if h : i ≥ bv.length then .error EINDEX
  else
    have hi : i.toNat < bv.bit_field.size := idx_lt_size bv h
    .ok ⟨bv.length,
         bv.bit_field.set (Fin.mk i.toNat hi) true,
         by simp [Array.size_set, bv.inv]⟩

def unset (bv : MvBitVector) (i : UInt64) : Except UInt64 MvBitVector :=
  if h : i ≥ bv.length then .error EINDEX
  else
    have hi : i.toNat < bv.bit_field.size := idx_lt_size bv h
    .ok ⟨bv.length,
         bv.bit_field.set (Fin.mk i.toNat hi) false,
         by simp [Array.size_set, bv.inv]⟩

-- ── Queries ───────────────────────────────────────────────────────────────────

def is_index_set (bv : MvBitVector) (i : UInt64) : Except UInt64 Bool :=
  if h : i ≥ bv.length then .error EINDEX
  else
    have hi : i.toNat < bv.bit_field.size := idx_lt_size bv h
    .ok (bv.bit_field[i.toNat]' hi)

def bvLength (bv : MvBitVector) : UInt64 := bv.length

-- ── Shift ─────────────────────────────────────────────────────────────────────

def shift_left (bv : MvBitVector) (amount : UInt64) : MvBitVector :=
  if amount ≥ bv.length then
    ⟨bv.length, Array.replicate bv.length.toNat false, by simp⟩
  else
    ⟨bv.length,
     Array.ofFn (n := bv.length.toNat) fun i =>
       let j := i.val + amount.toNat
       if hj : j < bv.length.toNat then
         bv.bit_field[j]' (bv.inv ▸ hj)
       else false,
     by simp [Array.size_ofFn]⟩

-- ── Theorems ──────────────────────────────────────────────────────────────────

@[simp] theorem new_ok_length {len : UInt64} (h0 : len ≠ 0) (hmax : len < MAX_SIZE)
    {bv : MvBitVector} (hnew : new len = .ok bv) : bv.length = len := by
  simp only [new, h0, ↓reduceIte] at hnew
  -- after h0 branch: hnew : (if MAX_SIZE ≤ len then .error else .ok {...}) = .ok bv
  have hlt : ¬ MAX_SIZE ≤ len := by
    rw [UInt64.le_iff_toNat_le]
    rw [UInt64.lt_iff_toNat_lt] at hmax
    omega
  simp only [if_neg hlt] at hnew
  exact ((Except.ok.inj hnew).symm ▸ rfl)

@[simp] theorem new_ok_all_false {len : UInt64} (h0 : len ≠ 0) (hmax : len < MAX_SIZE)
    {bv : MvBitVector} (hnew : new len = .ok bv)
    {i : Nat} (hi : i < len.toNat) : bv.bit_field[i]? = some false := by
  simp only [new, h0, ↓reduceIte] at hnew
  -- hnew : (if MAX_SIZE ≤ len then .error else .ok {...}) = .ok bv
  have hlt : ¬ MAX_SIZE ≤ len := by
    rw [UInt64.le_iff_toNat_le]
    rw [UInt64.lt_iff_toNat_lt] at hmax
    omega
  simp only [if_neg hlt] at hnew
  have heq : bv = ⟨len, Array.replicate len.toNat false, by simp⟩ :=
    (Except.ok.inj hnew).symm
  simp [heq, hi]

theorem set_ok_length {bv bv' : MvBitVector} {i : UInt64}
    (hs : set bv i = .ok bv') : bv'.length = bv.length := by
  simp only [set] at hs
  by_cases h : i ≥ bv.length
  · simp only [dif_pos h] at hs; simp at hs  -- Except.error ≠ Except.ok → False
  · simp only [dif_neg h] at hs
    exact (Except.ok.inj hs) ▸ rfl

theorem unset_ok_length {bv bv' : MvBitVector} {i : UInt64}
    (hs : unset bv i = .ok bv') : bv'.length = bv.length := by
  simp only [unset] at hs
  by_cases h : i ≥ bv.length
  · simp only [dif_pos h] at hs; simp at hs
  · simp only [dif_neg h] at hs
    exact (Except.ok.inj hs) ▸ rfl

@[simp] theorem shift_left_length (bv : MvBitVector) (amt : UInt64) :
    (shift_left bv amt).length = bv.length := by
  simp only [shift_left]
  by_cases h : amt ≥ bv.length
  · simp only [if_pos h]
  · simp only [if_neg h]

theorem shift_left_zero (bv : MvBitVector) : shift_left bv 0 = bv := by
  -- Proof sketch:
  -- Case bv.length = 0: both sides have empty bit_field (size 0 by inv)
  -- Case bv.length > 0: ofFn with amount=0 recovers original array; each
  --   element i maps to bv.bit_field[i+0] = bv.bit_field[i]
  sorry

end MovementFormal.Std.BitVector
