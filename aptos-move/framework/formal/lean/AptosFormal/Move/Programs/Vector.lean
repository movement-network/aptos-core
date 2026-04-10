import AptosFormal.Move.Native

/-!
# Vector bytecode programs

Both hand-written and real compiler-output bytecode for `std::vector` functions.

## Hand-written programs

Manually composed bytecode that inlines the logic of `vector::reverse`,
`vector::contains`, and `vector::index_of`. These were the initial model
validation targets.

## Real compiler output

Bytecode transcribed directly from `movement move disassemble` on the
compiled `move-stdlib` package. Each program matches the compiler's output
instruction-for-instruction, including branch targets, `MoveLoc`/`Pop`
cleanup patterns, and calling conventions.

**Source:** `movement move compile --package-dir aptos-move/framework/move-stdlib`
then `movement move disassemble --bytecode-path .../bytecode_modules/vector.mv`
-/

namespace AptosFormal.Move.Programs.Vector

open AptosFormal.Move
open AptosFormal.Move.Native

/-! -------------------------------------------------------------------
## Hand-written programs
--------------------------------------------------------------------- -/

/-! ### vector_reverse (hand-written, self-contained)

Inlines `vector::reverse` + `reverse_slice`. Locals: 0=v, 1=ref, 2=left, 3=right.

**Source:** `vector::reverse_slice` in
`aptos-move/framework/move-stdlib/sources/vector.move` -/

def vectorReverseCode : Array MoveInstr := #[
  .mutBorrowLoc 0,       -- 0:  containers[0]=v, push mutRef(0)
  .stLoc 1,              -- 1:  locals[1]=mutRef(0)
  .copyLoc 1,            -- 2:  push mutRef(0)
  .vecLenRef .u64,       -- 3:  push length
  .stLoc 3,              -- 4:  right = length
  .ldU64 0,              -- 5
  .stLoc 2,              -- 6:  left = 0
  .copyLoc 2,            -- 7
  .copyLoc 3,            -- 8
  .eq,                   -- 9:  left == right?
  .brTrue 32,            -- 10: if empty/single, skip to ReadRef (pc 32)
  .copyLoc 3,            -- 11
  .ldU64 1,              -- 12
  .sub,                  -- 13
  .stLoc 3,              -- 14: right -= 1
  .copyLoc 2,            -- 15: LOOP HEADER
  .copyLoc 3,            -- 16
  .lt,                   -- 17: left < right?
  .brFalse 32,           -- 18: exit loop → ReadRef (pc 32)
  .copyLoc 1,            -- 19: push ref
  .copyLoc 2,            -- 20: push left
  .copyLoc 3,            -- 21: push right
  .vecSwapRef .u64,      -- 22: swap(ref, left, right)
  .copyLoc 2,            -- 23
  .ldU64 1,              -- 24
  .add,                  -- 25
  .stLoc 2,              -- 26: left += 1
  .copyLoc 3,            -- 27
  .ldU64 1,              -- 28
  .sub,                  -- 29
  .stLoc 3,              -- 30: right -= 1
  .branch 15,            -- 31: loop back
  .copyLoc 1,            -- 32: push ref     (branch target)
  .readRef,              -- 33: read vector from container store
  .ret                   -- 34
]

def vectorReverseDesc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .bytecode vectorReverseCode 4 }

/-! ### vector_contains (hand-written, self-contained)

Locals: 0=v, 1=e, 2=ref, 3=i, 4=len.

**Source:** `vector::contains` in
`aptos-move/framework/move-stdlib/sources/vector.move` -/

def vectorContainsCode : Array MoveInstr := #[
  .immBorrowLoc 0,       -- 0:  containers[0]=v, push immRef(0)
  .stLoc 2,              -- 1:  locals[2]=immRef(0)
  .ldU64 0,              -- 2
  .stLoc 3,              -- 3:  i = 0
  .copyLoc 2,            -- 4:  push ref
  .vecLenRef .u64,       -- 5:  push length
  .stLoc 4,              -- 6:  len = length
  .copyLoc 3,            -- 7:  LOOP HEADER: push i
  .copyLoc 4,            -- 8:  push len
  .lt,                   -- 9:  i < len?
  .brFalse 25,           -- 10: exit loop → NOT FOUND (pc 25)
  .copyLoc 2,            -- 11: push ref
  .copyLoc 3,            -- 12: push i
  .vecImmBorrow .u64,    -- 13: push immRef(elem_id) — borrow elems[i]
  .readRef,              -- 14: read element value
  .copyLoc 1,            -- 15: push e
  .eq,                   -- 16: elem == e?
  .brTrue 23,            -- 17: found → FOUND (pc 23)
  .copyLoc 3,            -- 18
  .ldU64 1,              -- 19
  .add,                  -- 20
  .stLoc 3,              -- 21: i += 1
  .branch 7,             -- 22: loop back
  .ldTrue,               -- 23: FOUND
  .ret,                  -- 24
  .ldFalse,              -- 25: NOT FOUND
  .ret                   -- 26
]

/-- For `step` reduction: concrete size of the hand-written `vector_contains` bytecode. -/
@[simp] theorem vectorContains_code_size : vectorContainsCode.size = 27 := by native_decide

private theorem vectorContains_ix_lt {i : Nat} (hi : i < 27) : i < vectorContainsCode.size := by
  rw [vectorContains_code_size]
  exact hi

@[simp] theorem vectorContains_instr_9 :
    vectorContainsCode[9]'(vectorContains_ix_lt (by decide)) = MoveInstr.lt := rfl

@[simp] theorem vectorContains_instr_13 :
    vectorContainsCode[13]'(vectorContains_ix_lt (by decide)) = MoveInstr.vecImmBorrow .u64 := rfl

@[simp] theorem vectorContains_instr_14 :
    vectorContainsCode[14]'(vectorContains_ix_lt (by decide)) = MoveInstr.readRef := rfl

@[simp] theorem vectorContains_instr_16 :
    vectorContainsCode[16]'(vectorContains_ix_lt (by decide)) = MoveInstr.eq := rfl

@[simp] theorem vectorContains_instr_22 :
    vectorContainsCode[22]'(vectorContains_ix_lt (by decide)) = MoveInstr.branch 7 := rfl

def vectorContainsDesc : FuncDesc :=
  { numParams := 2, numReturns := 1, body := .bytecode vectorContainsCode 5 }

/-! ### vector_index_of (hand-written, self-contained)

Locals: 0=v, 1=e, 2=ref, 3=i, 4=len.

**Source:** `vector::index_of` in
`aptos-move/framework/move-stdlib/sources/vector.move` -/

def vectorIndexOfCode : Array MoveInstr := #[
  .immBorrowLoc 0,       -- 0:  containers[0]=v, push immRef(0)
  .stLoc 2,              -- 1:  locals[2]=immRef(0)
  .ldU64 0,              -- 2
  .stLoc 3,              -- 3:  i = 0
  .copyLoc 2,            -- 4:  push ref
  .vecLenRef .u64,       -- 5:  push length
  .stLoc 4,              -- 6:  len = length
  .copyLoc 3,            -- 7:  LOOP HEADER: push i
  .copyLoc 4,            -- 8:  push len
  .lt,                   -- 9:  i < len?
  .brFalse 26,           -- 10: exit loop → NOT FOUND (pc 26)
  .copyLoc 2,            -- 11: push ref
  .copyLoc 3,            -- 12: push i
  .vecImmBorrow .u64,    -- 13: borrow elems[i]
  .readRef,              -- 14: read element
  .copyLoc 1,            -- 15: push e
  .eq,                   -- 16: elem == e?
  .brTrue 23,            -- 17: found → FOUND (pc 23)
  .copyLoc 3,            -- 18
  .ldU64 1,              -- 19
  .add,                  -- 20
  .stLoc 3,              -- 21: i += 1
  .branch 7,             -- 22: loop back
  .copyLoc 3,            -- 23: FOUND: push i
  .ldTrue,               -- 24: push true
  .ret,                  -- 25: return [true, i]
  .ldU64 0,              -- 26: NOT FOUND: push 0
  .ldFalse,              -- 27: push false
  .ret                   -- 28: return [false, 0]
]

def vectorIndexOfDesc : FuncDesc :=
  { numParams := 2, numReturns := 2, body := .bytecode vectorIndexOfCode 5 }

/-! -------------------------------------------------------------------
## Real compiler output

Transcribed from `movement move disassemble` on `vector.mv`.
--------------------------------------------------------------------- -/

/-! ### reverse_slice (def_idx 21)

```
reverse_slice<Element>(self: &mut vector<Element>, left: u64, right: u64)
```

Params: 3 (`self`, `left`, `right`), no extra locals. -/

def realReverseSliceCode : Array MoveInstr := #[
  .copyLoc 1,      -- 0:  push left
  .copyLoc 2,      -- 1:  push right
  .le,             -- 2:  left <= right?
  .brFalse 35,     -- 3:  invalid range → abort
  .copyLoc 1,      -- 4:  push left
  .copyLoc 2,      -- 5:  push right
  .eq,             -- 6:  left == right?
  .brFalse 11,     -- 7:  not equal → proceed
  .moveLoc 0,      -- 8:  cleanup self
  .pop,            -- 9
  .ret,            -- 10: return (single element or empty)
  .moveLoc 2,      -- 11: push right
  .ldU64 1,        -- 12
  .sub,            -- 13: right - 1
  .stLoc 2,        -- 14: right = right - 1
  .copyLoc 1,      -- 15: push left    (LOOP HEADER)
  .copyLoc 2,      -- 16: push right
  .lt,             -- 17: left < right?
  .brFalse 32,     -- 18: exit loop → cleanup
  .copyLoc 0,      -- 19: push self
  .copyLoc 1,      -- 20: push left
  .copyLoc 2,      -- 21: push right
  .vecSwapRef .u64, -- 22: swap(self, left, right)
  .moveLoc 1,      -- 23: push left
  .ldU64 1,        -- 24
  .add,            -- 25: left + 1
  .stLoc 1,        -- 26: left = left + 1
  .moveLoc 2,      -- 27: push right
  .ldU64 1,        -- 28
  .sub,            -- 29: right - 1
  .stLoc 2,        -- 30: right = right - 1
  .branch 15,      -- 31: loop back
  .moveLoc 0,      -- 32: cleanup self
  .pop,            -- 33
  .ret,            -- 34: return
  .moveLoc 0,      -- 35: error path — EINVALID_RANGE
  .pop,            -- 36
  .ldU64 131073,   -- 37: 0x20001
  .abort_          -- 38
]

def realReverseSliceDesc : FuncDesc :=
  { numParams := 3, numReturns := 0, body := .bytecode realReverseSliceCode 3 }

/-! ### reverse (def_idx 19)

```
reverse<Element>(self: &mut vector<Element>)
```

Delegates to `reverse_slice(self, 0, len)`. The `call` index is resolved
relative to the module environment — see `Move/Programs.lean` for the
index table. -/

def realReverseCode (reverseSliceIdx : FuncIndex) : Array MoveInstr := #[
  .copyLoc 0,              -- 0: push self (&mut vec)
  .freezeRef,              -- 1: &mut → &
  .vecLenRef .u64,         -- 2: push length
  .stLoc 1,                -- 3: len = length
  .moveLoc 0,              -- 4: push self (move out of local 0)
  .ldU64 0,                -- 5: push 0 (left)
  .moveLoc 1,              -- 6: push len (right)
  .call reverseSliceIdx,   -- 7: call reverse_slice(self, 0, len)
  .ret                     -- 8
]

def realReverseDesc (reverseSliceIdx : FuncIndex) : FuncDesc :=
  { numParams := 1, numReturns := 0,
    body := .bytecode (realReverseCode reverseSliceIdx) 2 }

/-! ### contains (def_idx 0)

```
contains<Element>(self: &vector<Element>, e: &Element): bool
```

Params: 2 (both references), 2 extra locals (`i`, `len`). -/

def realContainsCode : Array MoveInstr := #[
  .ldU64 0,           -- 0
  .stLoc 2,           -- 1:  i = 0
  .copyLoc 0,         -- 2:  push self (&vector)
  .vecLenRef .u64,    -- 3:  push length
  .stLoc 3,           -- 4:  len = length
  .copyLoc 2,         -- 5:  push i          (LOOP HEADER)
  .copyLoc 3,         -- 6:  push len
  .lt,                -- 7:  i < len?
  .brFalse 26,        -- 8:  exit → not found
  .copyLoc 0,         -- 9:  push self
  .copyLoc 2,         -- 10: push i
  .vecImmBorrow .u64, -- 11: push &elems[i]
  .copyLoc 1,         -- 12: push e (&Element)
  .eq,                -- 13: compare by value (deref both refs)
  .brFalse 21,        -- 14: not equal → increment
  .moveLoc 0,         -- 15: cleanup self
  .pop,               -- 16
  .moveLoc 1,         -- 17: cleanup e
  .pop,               -- 18
  .ldTrue,            -- 19
  .ret,               -- 20: return true
  .moveLoc 2,         -- 21: push i
  .ldU64 1,           -- 22
  .add,               -- 23: i + 1
  .stLoc 2,           -- 24: i = i + 1
  .branch 5,          -- 25: loop back
  .moveLoc 0,         -- 26: cleanup self
  .pop,               -- 27
  .moveLoc 1,         -- 28: cleanup e
  .pop,               -- 29
  .ldFalse,           -- 30
  .ret                -- 31: return false
]

def realContainsDesc : FuncDesc :=
  { numParams := 2, numReturns := 1, body := .bytecode realContainsCode 4 }

/-! ### index_of (def_idx 1)

```
index_of<Element>(self: &vector<Element>, e: &Element): bool * u64
```

Params: 2 (both references), 2 extra locals (`i`, `len`). -/

def realIndexOfCode : Array MoveInstr := #[
  .ldU64 0,           -- 0
  .stLoc 2,           -- 1:  i = 0
  .copyLoc 0,         -- 2:  push self
  .vecLenRef .u64,    -- 3:  push length
  .stLoc 3,           -- 4:  len = length
  .copyLoc 2,         -- 5:  push i          (LOOP HEADER)
  .copyLoc 3,         -- 6:  push len
  .lt,                -- 7:  i < len?
  .brFalse 27,        -- 8:  exit → not found
  .copyLoc 0,         -- 9:  push self
  .copyLoc 2,         -- 10: push i
  .vecImmBorrow .u64, -- 11: push &elems[i]
  .copyLoc 1,         -- 12: push e
  .eq,                -- 13: compare by value
  .brFalse 22,        -- 14: not equal → increment
  .moveLoc 0,         -- 15: cleanup self
  .pop,               -- 16
  .moveLoc 1,         -- 17: cleanup e
  .pop,               -- 18
  .ldTrue,            -- 19
  .moveLoc 2,         -- 20: push i
  .ret,               -- 21: return (true, i)
  .moveLoc 2,         -- 22: push i
  .ldU64 1,           -- 23
  .add,               -- 24: i + 1
  .stLoc 2,           -- 25: i = i + 1
  .branch 5,          -- 26: loop back
  .moveLoc 0,         -- 27: cleanup self
  .pop,               -- 28
  .moveLoc 1,         -- 29: cleanup e
  .pop,               -- 30
  .ldFalse,           -- 31
  .ldU64 0,           -- 32
  .ret                -- 33: return (false, 0)
]

def realIndexOfDesc : FuncDesc :=
  { numParams := 2, numReturns := 2, body := .bytecode realIndexOfCode 4 }

/-! ### Test wrappers

These take value-typed arguments, create references, and call the real
compiler-output functions. They bridge between our `eval` entry point
(which passes values) and the real functions (which expect references).

The `call` indices are resolved by the module environment — see
`Move/Programs.lean` for the index table. -/

/-- `test_contains(v: vector<u64>, e: u64): bool` -/
def testRealContainsCode (containsIdx : FuncIndex) : Array MoveInstr := #[
  .immBorrowLoc 0,     -- 0: alloc containers[0]=v, push immRef(0)
  .immBorrowLoc 1,     -- 1: alloc containers[1]=e, push immRef(1)
  .call containsIdx,   -- 2: call realContains(immRef(0), immRef(1))
  .ret                 -- 3: return bool
]

def testRealContainsDesc (containsIdx : FuncIndex) : FuncDesc :=
  { numParams := 2, numReturns := 1,
    body := .bytecode (testRealContainsCode containsIdx) 2 }

/-- `test_index_of(v: vector<u64>, e: u64): (bool, u64)` -/
def testRealIndexOfCode (indexOfIdx : FuncIndex) : Array MoveInstr := #[
  .immBorrowLoc 0,     -- 0: alloc containers[0]=v, push immRef(0)
  .immBorrowLoc 1,     -- 1: alloc containers[1]=e, push immRef(1)
  .call indexOfIdx,    -- 2: call realIndexOf(immRef(0), immRef(1))
  .ret                 -- 3: return (bool, u64)
]

def testRealIndexOfDesc (indexOfIdx : FuncIndex) : FuncDesc :=
  { numParams := 2, numReturns := 2,
    body := .bytecode (testRealIndexOfCode indexOfIdx) 2 }

/-- `test_reverse(v: vector<u64>): vector<u64>` -/
def testRealReverseCode (reverseIdx : FuncIndex) : Array MoveInstr := #[
  .mutBorrowLoc 0,     -- 0: alloc containers[0]=v, push mutRef(0)
  .stLoc 1,            -- 1: locals[1] = mutRef(0)
  .copyLoc 1,          -- 2: push mutRef(0)
  .call reverseIdx,    -- 3: call realReverse(mutRef(0)) — mutates container 0
  .copyLoc 1,          -- 4: push mutRef(0)
  .readRef,            -- 5: read reversed vector from container 0
  .ret                 -- 6: return vector
]

def testRealReverseDesc (reverseIdx : FuncIndex) : FuncDesc :=
  { numParams := 1, numReturns := 1,
    body := .bytecode (testRealReverseCode reverseIdx) 2 }

end AptosFormal.Move.Programs.Vector
