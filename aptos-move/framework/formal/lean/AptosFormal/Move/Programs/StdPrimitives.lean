import AptosFormal.Move.Native
import AptosFormal.Std.Error
import AptosFormal.Std.BitVector
import AptosFormal.Std.Option

/-!
# Bytecode programs for move-stdlib primitives

Hand-written bytecode for `std::error` (all 14 entry points) and
`std::bit_vector::length` (pure struct accessor).

## Calling convention
- Locals `0..numParams-1`: parameters in declaration order.
- `shl` / `shr`: shift amount must be of type `.u8` on TOS; operand is any int type.
- `or` / `and` / `xor`: bitwise; both operands must be same type.
- `unpack N fIdx`: pops struct, pushes fields[0]..fields[N-1]; TOS = fields[N-1].

## What is bytecode here
- `std::error::canonical` + all 13 category wrappers (pure arithmetic)
- `std::bit_vector::length` (unpack + pop)

## What is native (see Move/Native/StdPrimitives.lean)
- `std::signer::*` — Move natives
- `std::fixed_point32::*` — u128 intermediate arithmetic
- `std::bit_vector::new`, `set`, `unset`, `is_index_set`, `shift_left` — mut-ref semantics
- `std::option::*` — vec mutation semantics

**Source:** `aptos-move/framework/move-stdlib/sources/error.move`
-/

namespace AptosFormal.Move.Programs.StdPrimitives

open AptosFormal.Move
open AptosFormal.Move.Native

/-! ─────────────────────────────────────────────────────────────────────────
## `std::error::canonical(category: u64, reason: u64): u64`

Move source:
```move
fun canonical(category: u64, reason: u64): u64 {
    (category << 16) | reason
}
```

Stack trace (locals: 0=category, 1=reason):
  0: copyLoc 0  →  [cat]
  1: ldU8 16    →  [cat, 16u8]   -- shift amount MUST be u8
  2: shl        →  [cat<<16]
  3: copyLoc 1  →  [cat<<16, reason]
  4: or         →  [(cat<<16)|reason]
  5: ret
────────────────────────────────────────────────────────────────────────── -/

def errorCanonicalCode : Array MoveInstr := #[
  .copyLoc 0,   -- 0: push category (u64)
  .ldU8 16,     -- 1: push 16 as u8 (shl shift-amount type)
  .shl,         -- 2: category << 16  → u64
  .copyLoc 1,   -- 3: push reason (u64)
  .or,          -- 4: (category << 16) | reason → u64
  .ret          -- 5
]

def errorCanonicalDesc : FuncDesc :=
  { numParams := 2, numReturns := 1, body := .bytecode errorCanonicalCode 2 }

@[simp] theorem errorCanonical_code_size : errorCanonicalCode.size = 6 := by native_decide

/-! ### std::error category wrapper template

Each of the 13 public functions is:
```move
public fun invalid_argument(r: u64): u64 { canonical(INVALID_ARGUMENT, r) }
```
i.e. inline canonical with a literal category constant.

Stack trace (local 0=reason):
  0: ldU64 CAT  →  [cat_const]
  1: ldU8 16    →  [cat_const, 16u8]
  2: shl        →  [cat_const<<16]
  3: copyLoc 0  →  [cat_const<<16, reason]
  4: or         →  [(cat_const<<16)|reason]
  5: ret
-/

private def mkErrCode (cat : UInt64) : Array MoveInstr := #[
  .ldU64 cat,   -- 0: push category literal
  .ldU8 16,     -- 1: shift amount
  .shl,         -- 2: cat << 16
  .copyLoc 0,   -- 3: push reason
  .or,          -- 4: (cat << 16) | reason
  .ret          -- 5
]

private def mkErrDesc (cat : UInt64) : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .bytecode (mkErrCode cat) 1 }

-- ── The 13 category functions ─────────────────────────────────────────────

def errorInvalidArgumentCode   := mkErrCode 0x1
def errorOutOfRangeCode        := mkErrCode 0x2
def errorInvalidStateCode      := mkErrCode 0x3
def errorUnauthenticatedCode   := mkErrCode 0x4
def errorPermissionDeniedCode  := mkErrCode 0x5
def errorNotFoundCode          := mkErrCode 0x6
def errorAbortedCode           := mkErrCode 0x7
def errorAlreadyExistsCode     := mkErrCode 0x8
def errorResourceExhaustedCode := mkErrCode 0x9
def errorCancelledCode         := mkErrCode 0xA
def errorInternalCode          := mkErrCode 0xB
def errorNotImplementedCode    := mkErrCode 0xC
def errorUnavailableCode       := mkErrCode 0xD

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

-- ── Size lemmas ────────────────────────────────────────────────────────────

@[simp] theorem errorCategory_code_size (cat : UInt64) : (mkErrCode cat).size = 6 := by
  native_decide

/-! ─────────────────────────────────────────────────────────────────────────
## `std::bit_vector::length(bv: BitVector): u64`

`BitVector { length: u64, bit_field: vector<bool> }` — two fields.
After `unpack 2 2`: pushes fields in declaration order, so TOS = bit_field, next = length.

Stack trace (local 0=bv):
  0: moveLoc 0  →  [bv_struct]
  1: unpack 2 2 →  [length, bit_field]   TOS=bit_field
  2: pop        →  [length]
  3: ret
────────────────────────────────────────────────────────────────────────── -/

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
