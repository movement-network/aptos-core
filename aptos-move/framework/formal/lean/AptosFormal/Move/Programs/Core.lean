import AptosFormal.Move.Native

/-!
# Core bytecode programs

Hand-written bytecode programs for basic operations: arithmetic, branching,
BCS serialization, and reference read/write. These exercise the fundamental
instruction set without loops or inter-function calls.
-/

namespace AptosFormal.Move.Programs.Core

open AptosFormal.Move
open AptosFormal.Move.Native

/-! ## add_u64

```move
fun add_u64(a: u64, b: u64): u64 { a + b }
```
-/

def addU64Code : Array MoveInstr := #[
  .copyLoc 0,
  .copyLoc 1,
  .add,
  .ret
]

def addU64Desc : FuncDesc :=
  { numParams := 2, numReturns := 1, body := .bytecode addU64Code 2 }

/-! ## max_u64

```move
fun max_u64(a: u64, b: u64): u64 {
    if (a >= b) { a } else { b }
}
```
-/

def maxU64Code : Array MoveInstr := #[
  .copyLoc 0,   -- 0
  .copyLoc 1,   -- 1
  .ge,          -- 2
  .brFalse 6,   -- 3: jump to pc 6 if a < b
  .moveLoc 0,   -- 4
  .ret,         -- 5
  .moveLoc 1,   -- 6
  .ret          -- 7
]

def maxU64Desc : FuncDesc :=
  { numParams := 2, numReturns := 1, body := .bytecode maxU64Code 2 }

/-! ## is_zero_u64

```move
fun is_zero(n: u64): bool { n == 0 }
```
-/

def isZeroU64Code : Array MoveInstr := #[
  .copyLoc 0,
  .ldU64 0,
  .eq,
  .ret
]

def isZeroU64Desc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .bytecode isZeroU64Code 1 }

/-! ## abs_diff_u64

```move
fun abs_diff(a: u64, b: u64): u64 {
    if (a >= b) { a - b } else { b - a }
}
```
-/

def absDiffU64Code : Array MoveInstr := #[
  .copyLoc 0,   -- 0
  .copyLoc 1,   -- 1
  .ge,          -- 2
  .brFalse 8,   -- 3: jump to pc 8 if a < b
  .copyLoc 0,   -- 4
  .copyLoc 1,   -- 5
  .sub,         -- 6
  .ret,         -- 7
  .copyLoc 1,   -- 8
  .copyLoc 0,   -- 9
  .sub,         -- 10
  .ret          -- 11
]

def absDiffU64Desc : FuncDesc :=
  { numParams := 2, numReturns := 1, body := .bytecode absDiffU64Code 2 }

/-! ## sum_to_n

```move
fun sum_to_n(n: u64): u64 {
    let acc: u64 = 0;
    let i: u64 = 0;
    while (i < n) {
        i = i + 1;
        acc = acc + i;
    };
    acc
}
```

Locals: 0=n (param), 1=acc, 2=i
-/

def sumToNProgram : Array MoveInstr := #[
  .ldU64 0,     -- 0
  .stLoc 1,     -- 1: acc = 0
  .ldU64 0,     -- 2
  .stLoc 2,     -- 3: i = 0
  .copyLoc 2,   -- 4: loop header
  .copyLoc 0,   -- 5
  .lt,          -- 6: i < n?
  .brFalse 17,  -- 7: exit → pc 17
  .copyLoc 2,   -- 8
  .ldU64 1,     -- 9
  .add,         -- 10: i + 1
  .stLoc 2,     -- 11: i = i + 1
  .copyLoc 1,   -- 12
  .copyLoc 2,   -- 13
  .add,         -- 14: acc + i
  .stLoc 1,     -- 15: acc = acc + i
  .branch 4,    -- 16: loop back
  .copyLoc 1,   -- 17: push acc
  .ret          -- 18
]

def sumToNDesc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .bytecode sumToNProgram 3 }

/-! ## bcs_to_bytes_u64 (calls native)

```move
fun bcs_to_bytes_u64(v: u64): vector<u8> { bcs::to_bytes(&v) }
```
-/

def bcsU64Code : Array MoveInstr := #[
  .copyLoc 0,   -- 0: push v
  .call 1,      -- 1: call bcs::to_bytes<u64> (native index 1)
  .ret          -- 2
]

def bcsU64Desc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .bytecode bcsU64Code 1 }

/-! ## read_via_ref (immutable borrow + ReadRef)

```move
fun read_via_ref(n: u64): u64 { let r = &n; *r }
```
-/

def readViaRefCode : Array MoveInstr := #[
  .immBorrowLoc 0,  -- 0: containers[0]=n, push immRef(0)
  .readRef,         -- 1: read containers[0], push n
  .ret              -- 2
]

def readViaRefDesc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .bytecode readViaRefCode 1 }

/-! ## inc_via_ref (mutable borrow + WriteRef + ReadRef)

```move
fun inc_via_ref(n: u64): u64 {
    let r = &mut n;
    *r = *r + 1;
    *r
}
```
-/

def incViaRefCode : Array MoveInstr := #[
  .mutBorrowLoc 0,  -- 0:  containers[0]=n, locals[0]=none, push mutRef(0)
  .stLoc 1,         -- 1:  locals[1]=mutRef(0)
  .copyLoc 1,       -- 2:  push mutRef(0)
  .readRef,         -- 3:  read containers[0]=n, push n
  .ldU64 1,         -- 4:  push 1
  .add,             -- 5:  push n+1
  .copyLoc 1,       -- 6:  push mutRef(0) on top
  .writeRef,        -- 7:  containers[0]=n+1
  .copyLoc 1,       -- 8:  push mutRef(0)
  .readRef,         -- 9:  read containers[0]=n+1
  .ret              -- 10
]

def incViaRefDesc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .bytecode incViaRefCode 2 }

/-! ## vec_push_and_len (MutBorrowLoc + VecPushBackRef + VecLenRef)

```move
fun vec_push_and_len(v: vector<u64>, val: u64): u64 {
    let r = &mut v;
    vector::push_back(r, val);
    vector::length(r)
}
```
-/

def vecPushAndLenCode : Array MoveInstr := #[
  .mutBorrowLoc 0,        -- 0: containers[0]=v, locals[0]=none, push mutRef(0)
  .stLoc 2,               -- 1: locals[2]=mutRef(0)
  .copyLoc 2,             -- 2: push mutRef(0)
  .copyLoc 1,             -- 3: push val
  .vecPushBackRef .u64,   -- 4: containers[0]=v++[val]
  .copyLoc 2,             -- 5: push mutRef(0)
  .vecLenRef .u64,        -- 6: push length
  .ret                    -- 7
]

def vecPushAndLenDesc : FuncDesc :=
  { numParams := 2, numReturns := 1, body := .bytecode vecPushAndLenCode 3 }

end AptosFormal.Move.Programs.Core
