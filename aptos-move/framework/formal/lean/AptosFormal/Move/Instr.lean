import AptosFormal.Move.Value

/-!
# Move bytecode instructions

Lean model of the Move bytecode instruction set.  Covers stack/local
operations, control flow, arithmetic, bitwise, boolean, comparison,
casting, struct pack/unpack, vector operations, references
(`ReadRef`, `WriteRef`, `*BorrowLoc`, `*BorrowField`, `FreezeRef`),
and function calls (including native dispatch).

Omitted for now: global storage (`MoveFrom`, `MoveTo`, `Exists`,
`*BorrowGlobal*`), closures (`PackClosure*`, `CallClosure`), and
variants (`*Variant*`).

**Source:** `Bytecode` enum in
`third_party/move/move-binary-format/src/file_format.rs`
-/

namespace AptosFormal.Move

abbrev LocalIndex := Nat
abbrev CodeOffset := Nat
abbrev ConstPoolIndex := Nat
abbrev FuncIndex := Nat
abbrev StructIndex := Nat

/-! ## Instruction set

The instruction set is partitioned into groups matching the Rust `Bytecode`
enum.  Omitted for now: global storage (`MoveFrom`, `MoveTo`, `Exists`,
`*BorrowGlobal*`), closures (`PackClosure*`, `CallClosure`), and
variants (`*Variant*`). -/

inductive MoveInstr where
  -- Stack and locals
  | pop
  | ldU8    (val : UInt8)
  | ldU16   (val : UInt16)
  | ldU32   (val : UInt32)
  | ldU64   (val : UInt64)
  | ldU128  (val : U128)
  | ldU256  (val : U256)
  | ldTrue
  | ldFalse
  | ldConst (idx : ConstPoolIndex)
  | copyLoc (idx : LocalIndex)
  | moveLoc (idx : LocalIndex)
  | stLoc   (idx : LocalIndex)

  -- Control flow
  | ret
  | brTrue  (offset : CodeOffset)
  | brFalse (offset : CodeOffset)
  | branch  (offset : CodeOffset)
  | call    (func : FuncIndex)
  | abort_
  | nop

  -- Arithmetic (operate on same-width integer pairs)
  | add
  | sub
  | mul
  | div
  | mod_

  -- Bitwise
  | bitOr
  | bitAnd
  | xor
  | shl
  | shr

  -- Boolean
  | or
  | and
  | not

  -- Comparison
  | eq
  | neq
  | lt
  | gt
  | le
  | ge

  -- Casting
  | castU8
  | castU16
  | castU32
  | castU64
  | castU128
  | castU256

  -- Struct
  | pack   (structIdx : StructIndex) (numFields : Nat)
  | unpack (structIdx : StructIndex) (numFields : Nat)

  -- Vector (value-level, for programs that don't use references)
  | vecPack    (elemType : MoveType) (numElems : Nat)
  | vecLen     (elemType : MoveType)
  | vecPushBack (elemType : MoveType)
  | vecPopBack  (elemType : MoveType)
  | vecUnpack   (elemType : MoveType) (numElems : Nat)
  | vecSwap     (elemType : MoveType)

  -- References
  | immBorrowLoc (idx : LocalIndex)
  | mutBorrowLoc (idx : LocalIndex)
  | readRef
  | writeRef
  | freezeRef
  | immBorrowField (fieldIdx : Nat)
  | mutBorrowField (fieldIdx : Nat)

  -- Vector (reference-level, matching real Move bytecode)
  | vecLenRef     (elemType : MoveType)
  | vecImmBorrow  (elemType : MoveType)
  | vecMutBorrow  (elemType : MoveType)
  | vecPushBackRef (elemType : MoveType)
  | vecPopBackRef  (elemType : MoveType)
  | vecSwapRef     (elemType : MoveType)
  deriving Repr, BEq

/-! ## Constant pool

The constant pool holds serialized values loaded by `LdConst`. Each entry
stores the value's type and the value itself. -/

structure ConstPoolEntry where
  type : MoveType
  value : MoveValue
  deriving BEq

/-! ## Function descriptors

A `FuncDesc` describes a callable function — either a Move bytecode body
or a native function modeled as a Lean function on values. -/

inductive FuncBody where
  | bytecode (code : Array MoveInstr) (numLocals : Nat)
  | native (impl : List MoveValue → Option (List MoveValue))

structure FuncDesc where
  numParams : Nat
  numReturns : Nat
  body : FuncBody

end AptosFormal.Move
