import AptosFormal.Move.Native
import AptosFormal.Move.Native.StdPrimitives
import AptosFormal.Std.Error
import AptosFormal.Std.BitVector

/-!
# Bytecode programs for move-stdlib primitives

Hand-written bytecode for `std::error` (canonical + 13 wrappers) and
`std::bit_vector::length`.

## Key instruction notes (verified from Step.lean)
- `.bitOr` — bitwise OR on integers (u8/u16/u32/u64); uses `intBitOr`
- `.or`    — boolean OR only (`Bool || Bool`); NOT for integers
- `.shl`   — TOS must be `.u8` shift amount; operand any int type
- `.unpack N N` — pops struct, pushes fields[0..N-1]; TOS = fields[N-1]

## What is bytecode here
- `std::error::canonical` + all 13 category wrappers (pure u64 arithmetic)
- `std::bit_vector::length` (unpack + pop)

## What is native (Move/Native/StdPrimitives.lean)
- `std::signer::*`, `std::fixed_point32::*` — u128 / Move native semantics
- `std::bit_vector::new/set/unset/is_index_set/shift_left` — mut-ref semantics
- `std::option::*` — vector mutation semantics

**Source:** `aptos-move/framework/move-stdlib/sources/error.move`, `bit_vector.move`
-/

namespace AptosFormal.Move.Programs.StdPrimitives

open AptosFormal.Move
open AptosFormal.Move.Native

/-! ## `std::error::canonical(category: u64, reason: u64): u64`

Move source: `(category << 16) | reason`

Stack trace (locals: 0=category, 1=reason):
  copyLoc 0  → [cat]
  ldU8 16    → [cat, 16u8]   -- shl shift amount must be u8
  shl        → [cat<<16]
  copyLoc 1  → [cat<<16, reason]
  bitOr      → [(cat<<16)|reason]   -- .bitOr for integers, NOT .or (boolean only)
  ret
-/

def errorCanonicalCode : Array MoveInstr := #[
  .copyLoc 0,   -- 0: push category (u64)
  .ldU8 16,     -- 1: push 16 as u8
  .shl,         -- 2: category << 16
  .copyLoc 1,   -- 3: push reason (u64)
  .bitOr,       -- 4: (category << 16) | reason
  .ret          -- 5
]

def errorCanonicalDesc : FuncDesc :=
  { numParams := 2, numReturns := 1, body := .bytecode errorCanonicalCode 2 }

@[simp] theorem errorCanonical_code_size : errorCanonicalCode.size = 6 := by native_decide

/-! ## std::error category wrappers

Each inlines `canonical` with a literal category constant.
Stack trace (local 0=reason):
  ldU64 CAT  → [cat_const]
  ldU8 16    → [cat_const, 16u8]
  shl        → [cat_const<<16]
  copyLoc 0  → [cat_const<<16, reason]
  bitOr      → [(cat_const<<16)|reason]
  ret
-/

private def mkErrCode (cat : UInt64) : Array MoveInstr := #[
  .ldU64 cat,   -- 0: push category literal
  .ldU8 16,     -- 1: shift amount
  .shl,         -- 2: cat << 16
  .copyLoc 0,   -- 3: push reason
  .bitOr,       -- 4: (cat << 16) | reason  (.bitOr = integer bitwise OR)
  .ret          -- 5
]

private def mkErrDesc (cat : UInt64) : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .bytecode (mkErrCode cat) 1 }

def errorInvalidArgumentDesc   := mkErrDesc 0x1
def errorOutOfRangeDesc        := mkErrDesc 0x2
def errorInvalidStateDesc      := mkErrDesc 0x3
def errorUnauthenticatedDesc   := mkErrDesc 0x4
def errorPermissionDeniedDesc  := mkErrDesc 0x5
def errorNotFoundDesc          := mkErrDesc 0x6
def errorAbortedDesc           := mkErrDesc 0x7
def errorAlreadyExistsDesc     := mkErrDesc 0x8
def errorResourceExhaustedDesc := mkErrDesc 0x9
def errorCancelledDesc         := mkErrDesc 0xA
def errorInternalDesc          := mkErrDesc 0xB
def errorNotImplementedDesc    := mkErrDesc 0xC
def errorUnavailableDesc       := mkErrDesc 0xD

@[simp] theorem errorCategory_code_size (cat : UInt64) :
    (mkErrCode cat).size = 6 := by native_decide

/-! ## `std::bit_vector::length(bv: BitVector): u64`

`BitVector { length: u64, bit_field: vector<bool> }` — two fields.
`unpack 2 2` pushes fields in declaration order; TOS = bit_field, below = length.

Stack trace (local 0=bv):
  moveLoc 0   → [bv_struct]
  unpack 2 2  → [length, bit_field]   (TOS = bit_field)
  pop         → [length]
  ret
-/

def bitVectorLengthCode : Array MoveInstr := #[
  .moveLoc 0,     -- 0: consume bv struct
  .unpack 2 2,    -- 1: push 2 fields; TOS = bit_field, below = length
  .pop,           -- 2: discard bit_field
  .ret            -- 3: return length
]

def bitVectorLengthDesc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .bytecode bitVectorLengthCode 1 }

@[simp] theorem bitVectorLength_code_size : bitVectorLengthCode.size = 4 := by native_decide

end AptosFormal.Move.Programs.StdPrimitives
