import Mathlib.Tactic.Omega

/-!
# Lean specification for `std::fixed_point32`

`FixedPoint32` wraps a `u64` with an implicit 2^32 scale factor.
-/

namespace AptosFormal.Std.FixedPoint32

def EDENOMINATOR        : UInt64 := 0x10001
def EDIVISION           : UInt64 := 0x20002
def EMULTIPLICATION     : UInt64 := 0x20003
def EDIVISION_BY_ZERO   : UInt64 := 0x10004
def ERATIO_OUT_OF_RANGE : UInt64 := 0x20005
def MAX_U64             : UInt128 := 18446744073709551615

structure FixedPoint32 where value : UInt64 deriving Repr, DecidableEq

def create_from_raw_value (v : UInt64) : FixedPoint32 := ⟨v⟩
def get_raw_value (fp : FixedPoint32) : UInt64 := fp.value

def create_from_rational (num den : UInt64) : Except UInt64 FixedPoint32 :=
  if den = 0 then .error EDENOMINATOR
  else
    let n128 : UInt128 := (num.toNat : UInt128) <<< 64
    let d128 : UInt128 := (den.toNat : UInt128) <<< 32
    let q := n128 / d128
    if q = 0 && num ≠ 0 then .error ERATIO_OUT_OF_RANGE
    else if q > MAX_U64 then .error ERATIO_OUT_OF_RANGE
    else .ok ⟨q.toUInt64⟩

def create_from_u64 (val : UInt64) : Except UInt64 FixedPoint32 :=
  let scaled : UInt128 := (val.toNat : UInt128) <<< 32
  if scaled > MAX_U64 then .error ERATIO_OUT_OF_RANGE
  else .ok ⟨scaled.toUInt64⟩

def multiply_u64 (val : UInt64) (mult : FixedPoint32) : Except UInt64 UInt64 :=
  let prod : UInt128 := (val.toNat : UInt128) * mult.value.toNat
  let result := prod >>> 32
  if result > MAX_U64 then .error EMULTIPLICATION
  else .ok result.toUInt64

def divide_u64 (val : UInt64) (div : FixedPoint32) : Except UInt64 UInt64 :=
  if div.value = 0 then .error EDIVISION_BY_ZERO
  else
    let scaled : UInt128 := (val.toNat : UInt128) <<< 32
    let q := scaled / div.value.toNat
    if q > MAX_U64 then .error EDIVISION
    else .ok q.toUInt64

def is_zero (fp : FixedPoint32) : Bool := fp.value = 0
def min (a b : FixedPoint32) : FixedPoint32 := if a.value < b.value then a else b
def max (a b : FixedPoint32) : FixedPoint32 := if a.value > b.value then a else b

def floor (fp : FixedPoint32) : UInt64 := fp.value >>> 32
def ceil  (fp : FixedPoint32) : UInt64 :=
  let f := floor fp
  if fp.value.toNat = f.toNat <<< 32 then f else (f.toNat + 1).toUInt64
def round (fp : FixedPoint32) : UInt64 :=
  let f := floor fp
  if fp.value.toNat < f.toNat <<< 32 + (1 <<< 32) / 2 then f else ceil fp

theorem multiply_u64_zero (mult : FixedPoint32) : multiply_u64 0 mult = .ok 0 := by
  simp [multiply_u64, UInt64.toNat, MAX_U64]

theorem divide_u64_zero (div : FixedPoint32) (hd : div.value ≠ 0) :
    divide_u64 0 div = .ok 0 := by simp [divide_u64, hd, UInt64.toNat]

theorem min_comm (a b : FixedPoint32) : min a b = min b a := by
  simp [min]; split_ifs with h1 h2 <;> try rfl
  · exact absurd (UInt64.lt_trans h1 h2) (UInt64.lt_irrefl _)
  · push_neg at h1 h2; exact congrArg _ (UInt64.le_antisymm h1 h2)

theorem max_comm (a b : FixedPoint32) : max a b = max b a := by
  simp [max]; split_ifs with h1 h2 <;> try rfl
  · exact absurd (UInt64.lt_trans h1 h2) (UInt64.lt_irrefl _)
  · push_neg at h1 h2; exact congrArg _ (UInt64.le_antisymm h1 h2)

end AptosFormal.Std.FixedPoint32
