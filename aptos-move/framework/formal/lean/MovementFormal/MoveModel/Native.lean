import MovementFormal.MoveModel.State
import MovementFormal.Std.Bcs.Primitives
import MovementFormal.Std.Hash.Sha2_256
import MovementFormal.Std.Hash.Sha3_256

/-!
# Native function bindings

Connects Move native functions to their Lean specifications from `Std.*`.
Each native wraps a `List MoveValue → Option (List MoveValue)` that the
evaluator calls when it encounters `FuncBody.native`. **`FuncBody.nativeAbort`**
uses `Option (Except UInt64 (List MoveValue))` so natives can model **`abort`** with a
fixed code (see `Step.handleNativeAbortResult`).

**Source:**
- `aptos-move/framework/move-stdlib/sources/bcs.move` — `native fun to_bytes`
- `aptos-move/framework/move-stdlib/sources/hash.move` — `native fun sha2_256`, `sha3_256`
- `aptos-move/framework/move-stdlib/sources/vector.move` — `native fun length`, etc.
-/

namespace MovementFormal.MoveModel.Native

open MovementFormal.Std.Bcs
open MovementFormal.Std.Hash.Sha2_256
open MovementFormal.Std.Hash.Sha3_256
open MovementFormal.MoveModel

/-! ## BCS natives

`bcs::to_bytes` is a generic native. We provide monomorphic wrappers
for the types we need: `u8`, `u64`, `u128`, `u16`, `u32`, `u256`, `bool`. Each converts a
`MoveValue` to BCS bytes via the spec in `Std.Bcs.Primitives`, then
wraps the result as `MoveValue.vector .u8`. -/

/-- Wrap raw BCS bytes as `vector<u8>` for `MoveValue` results. -/
def bytesToMoveVec (bs : ByteArray) : MoveValue :=
  .vector .u8 (bs.toList.map .u8)

def bcsToBytes_u8 : List MoveValue → Option (List MoveValue)
  | [.u8 x] => some [bytesToMoveVec (u8Bytes x)]
  | _ => none

def bcsToBytes_u64 : List MoveValue → Option (List MoveValue)
  | [.u64 x] => some [bytesToMoveVec (u64Le x)]
  | _ => none

def bcsToBytes_u128 : List MoveValue → Option (List MoveValue)
  | [.u128 x] => some [bytesToMoveVec (u128LeNat x.val)]
  | _ => none

def bcsToBytes_u16 : List MoveValue → Option (List MoveValue)
  | [.u16 x] => some [bytesToMoveVec (u16Le x)]
  | _ => none

def bcsToBytes_u32 : List MoveValue → Option (List MoveValue)
  | [.u32 x] => some [bytesToMoveVec (u32Le x)]
  | _ => none

def bcsToBytes_u256 : List MoveValue → Option (List MoveValue)
  | [.u256 x] => some [bytesToMoveVec (u256LeNat x.val)]
  | _ => none

def bcsToBytes_bool : List MoveValue → Option (List MoveValue)
  | [.bool b] => some [bytesToMoveVec (boolBytes b)]
  | _ => none

/-! ## Hash natives

`std::hash::sha2_256` / `sha3_256` — input `vector<u8>`, output `vector<u8>` (32 bytes). -/

partial def u8ElemsToByteArrayAux (acc : Array UInt8) : List MoveValue → Option ByteArray
  | [] => some (ByteArray.mk acc)
  | .u8 b :: rest => u8ElemsToByteArrayAux (acc.push b) rest
  | _ :: _ => none

/-- Extract `vector<u8>` element list as `ByteArray` (shared by hash / BCS-style paths). -/
def u8ElemsToByteArray (elems : List MoveValue) : Option ByteArray :=
  u8ElemsToByteArrayAux #[] elems

def sha2_256_native : List MoveValue → Option (List MoveValue)
  | [.vector .u8 elems] =>
    match u8ElemsToByteArray elems with
    | some ba => some [bytesToMoveVec (sha2_256 ba)]
    | none => none
  | _ => none

def sha3_256_native : List MoveValue → Option (List MoveValue)
  | [.vector .u8 elems] =>
    match u8ElemsToByteArray elems with
    | some ba => some [bytesToMoveVec (sha3_256 ba)]
    | none => none
  | _ => none

/-! ## Vector natives

These model the bytecode-instruction-level vector operations that are
native in Move but are already handled by our `MoveInstr.vec*` instructions.
They're provided here for completeness when modeling functions that
call them through the `Call` instruction rather than the direct bytecode
instructions. -/

def vectorLength : List MoveValue → Option (List MoveValue)
  | [.vector _ elems] => some [.u64 elems.length.toUInt64]
  | _ => none

def vectorIsEmpty : List MoveValue → Option (List MoveValue)
  | [.vector _ elems] => some [.bool elems.isEmpty]
  | _ => none

def vectorPushBack : List MoveValue → Option (List MoveValue)
  | [.vector et elems, val] => some [.vector et (elems ++ [val])]
  | _ => none

def vectorPopBack : List MoveValue → Option (List MoveValue)
  | [.vector et elems] =>
    match elems.reverse with
    | last :: init => some [.vector et init.reverse, last]
    | [] => none
  | _ => none

/-- `vector::remove` on `vector<u64>` — returns `[removed, new_vec]` for `lake exe difftest` stack order (see `Runner.runTestCase`). -/
def vectorRemove : List MoveValue → Option (List MoveValue)
  | [.vector .u64 elems, .u64 i] =>
      let n := elems.length
      let iNat := i.toNat
      if h : iNat < n then
        let removed := elems.get ⟨iNat, h⟩
        let rest := elems.take iNat ++ elems.drop (iNat + 1)
        some [removed, .vector .u64 rest]
      else
        none
  | _ => none

/-- `vector::swap_remove` on `vector<u64>`. -/
def vectorSwapRemove : List MoveValue → Option (List MoveValue)
  | [.vector .u64 elems, .u64 i] =>
      let n := elems.length
      let iNat := i.toNat
      if h : iNat < n then
        let lastIdx := n - 1
        let removed := elems.get ⟨iNat, h⟩
        if hi : iNat = lastIdx then
          some [removed, .vector .u64 (elems.take lastIdx)]
        else
          let lastElem := elems.get ⟨lastIdx, by omega⟩
          let before := elems.take iNat
          let midLen := n - iNat - 2
          let mid := (elems.drop (iNat + 1)).take midLen
          some [removed, .vector .u64 (before ++ [lastElem] ++ mid)]
      else
        none
  | _ => none

/-- `vector::append` on two `vector<u64>` values (consumes both lists). -/
def vectorAppend : List MoveValue → Option (List MoveValue)
  | [.vector .u64 a, .vector .u64 b] => some [.vector .u64 (a ++ b)]
  | _ => none

/-- `vector::singleton` for `u64`. -/
def vectorSingleton : List MoveValue → Option (List MoveValue)
  | [.u64 x] => some [.vector .u64 [.u64 x]]
  | _ => none

/-! ## Standard native table

A pre-built function table with natives at fixed indices for use in
bytecode programs. The index assignments are:

| Index | Function |
|-------|----------|
| 0 | `bcs::to_bytes<u8>` |
| 1 | `bcs::to_bytes<u64>` |
| 2 | `bcs::to_bytes<u128>` |
| 3 | `bcs::to_bytes<bool>` |
| 4 | `vector::length` |
| 5 | `vector::is_empty` |
| 6 | `vector::push_back` |
| 7 | `vector::pop_back` |

Appended after hand-written bytecode in `Programs.lean` (not in this array):

| (see `Programs`) | `hash::sha3_256` (VM↔Lean **`hash` suite** uses `HashCatalog`: `sha2_256`, `sha3_256`) |
-/

def stdNatives : Array FuncDesc := #[
  { numParams := 1, numReturns := 1, body := .native bcsToBytes_u8 },
  { numParams := 1, numReturns := 1, body := .native bcsToBytes_u64 },
  { numParams := 1, numReturns := 1, body := .native bcsToBytes_u128 },
  { numParams := 1, numReturns := 1, body := .native bcsToBytes_bool },
  { numParams := 1, numReturns := 1, body := .native vectorLength },
  { numParams := 1, numReturns := 1, body := .native vectorIsEmpty },
  { numParams := 2, numReturns := 1, body := .native vectorPushBack },
  { numParams := 1, numReturns := 2, body := .native vectorPopBack }
]

end MovementFormal.MoveModel.Native
