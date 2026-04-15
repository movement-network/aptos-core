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
  else .ok ⟨length, Array.replicate length.toNat false, by simp⟩

-- ── private helper ────────────────────────────────────────────────────────────

private theorem idx_lt_size (bv : MvBitVector) {i : UInt64} (h : ¬ i ≥ bv.length) :
    i.toNat < bv.bit_field.size := by
  rw [bv.inv, UInt64.lt_iff_toNat_lt]
  -- h : ¬ (bv.length ≤ i) → i.toNat < bv.length.toNat via Nat
  have : i.toNat < bv.length.toNat := by
    have hle : ¬ bv.length.toNat ≤ i.toNat := by
      intro hle
      apply h
      rw [ge_iff_le, UInt64.le_iff_toNat_le]
      exact hle
    omega
  exact this

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
    .ok (bv.bit_field.get (Fin.mk i.toNat hi))

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
         bv.bit_field.get (Fin.mk j (bv.inv ▸ hj))
       else false,
     by simp [Array.size_ofFn]⟩

-- ── Theorems ──────────────────────────────────────────────────────────────────

@[simp] theorem new_ok_length {len : UInt64} (h0 : len ≠ 0) (hmax : len < MAX_SIZE)
    {bv : MvBitVector} (hnew : new len = .ok bv) : bv.length = len := by
  simp only [new, h0, ↓reduceIte, ge_iff_le] at hnew
  split_ifs at hnew with hge
  · simp at hnew
  · have heq := Except.ok.inj hnew
    exact congrArg MvBitVector.length heq

@[simp] theorem new_ok_all_false {len : UInt64} (h0 : len ≠ 0) (hmax : len < MAX_SIZE)
    {bv : MvBitVector} (hnew : new len = .ok bv)
    {i : Nat} (hi : i < len.toNat) : bv.bit_field[i]? = some false := by
  simp only [new, h0, ↓reduceIte, ge_iff_le] at hnew
  split_ifs at hnew with hge
  · simp at hnew
  · have heq : bv = ⟨len, Array.replicate len.toNat false, by simp⟩ :=
      Except.ok.inj hnew
    simp [heq, Array.getElem?_replicate, hi]

theorem set_ok_length {bv bv' : MvBitVector} {i : UInt64}
    (hs : set bv i = .ok bv') : bv'.length = bv.length := by
  simp only [set] at hs
  split_ifs at hs with h
  · simp at hs
  · exact congrArg MvBitVector.length (Except.ok.inj hs)

theorem unset_ok_length {bv bv' : MvBitVector} {i : UInt64}
    (hs : unset bv i = .ok bv') : bv'.length = bv.length := by
  simp only [unset] at hs
  split_ifs at hs with h
  · simp at hs
  · exact congrArg MvBitVector.length (Except.ok.inj hs)

@[simp] theorem shift_left_length (bv : MvBitVector) (amt : UInt64) :
    (shift_left bv amt).length = bv.length := by
  unfold shift_left
  split_ifs <;> rfl

theorem shift_left_zero (bv : MvBitVector) : shift_left bv 0 = bv := by
  unfold shift_left
  simp only [ge_iff_le, UInt64.le_zero_iff, UInt64.toNat_zero]
  by_cases h : bv.length = 0
  · -- amount = 0 ≥ bv.length = 0, so takes the replicate branch
    have hge : (0 : UInt64) ≥ bv.length := by rw [h]; rfl
    simp only [hge, ↓reduceIte]
    ext1
    · simp [h]
    · have hsz : bv.bit_field.size = 0 := by rw [bv.inv, h]; rfl
      simp [h, Array.size_eq_zero_iff.mp hsz]
    · simp [h]
  · -- amount = 0 < bv.length, so takes the ofFn branch
    have hlt : ¬ (0 : UInt64) ≥ bv.length := by
      simp only [ge_iff_le, UInt64.le_zero_iff]; exact h
    simp only [hlt, ↓reduceIte]
    ext1
    · rfl
    · apply Array.ext
      · simp [Array.size_ofFn, bv.inv]
      · intro j hj _
        simp only [Array.getElem_ofFn, UInt64.toNat_zero, Nat.add_zero]
        have hjlt : j < bv.length.toNat := bv.inv ▸ hj
        simp [hjlt]
    · rfl

end AptosFormal.Std.BitVector
