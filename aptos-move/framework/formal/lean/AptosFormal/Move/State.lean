import AptosFormal.Move.Instr

/-!
# Move execution state

Pure-functional model of the Move VM's runtime state: operand stack, call
stack, locals, and program counter.

**Source:**
- `third_party/move/move-vm/runtime/src/interpreter.rs` — `InterpreterImpl`, `Stack`
- `third_party/move/move-vm/runtime/src/frame.rs` — `Frame`
-/

namespace AptosFormal.Move

/-! ## Frame

A `Frame` represents a single function activation.  It holds the function's
bytecode, the program counter, and the local variable slots.  Locals use
`Option MoveValue` — `none` represents the "invalid" state before first
assignment (or while borrowed). -/

structure Frame where
  code : Array MoveInstr
  pc : Nat
  locals : Array (Option MoveValue)
  deriving BEq

/-! ## Container store

`ContainerStore` is the pure-functional model of the VM's `Container`
sharing mechanism (`Rc<RefCell<Vec<ValueImpl>>>`).  Each `RefId` maps to
a live value that can be read or written through `ReadRef` / `WriteRef`.

In the VM, a borrowed local and the reference point to the same
`Rc`-wrapped cell, so mutations are immediately visible in both.
Our model achieves the same semantics with an explicit flat store:
both the reference and the local (after write-back) see the same
`RefId`, so reads after writes are consistent.

**Source:** `Container`, `ContainerRef` in
`third_party/move/move-vm/types/src/values/values_impl.rs` -/

structure ContainerStore where
  store : Array MoveValue
  deriving BEq

namespace ContainerStore

def empty : ContainerStore := { store := #[] }

def alloc (cs : ContainerStore) (v : MoveValue) : ContainerStore × RefId :=
  let id := cs.store.size
  ({ store := cs.store.push v }, id)

def read (cs : ContainerStore) (id : RefId) : Option MoveValue :=
  if hlt : id < cs.store.size then some cs.store[id] else none

def write (cs : ContainerStore) (id : RefId) (v : MoveValue) : Option ContainerStore :=
  if hlt : id < cs.store.size then
    some { store := cs.store.set id v (by omega) }
  else none

end ContainerStore

/-! ## Execution outcome

`ExecResult` captures the four ways a single step can complete:

- `ok s'` — normal transition to a new machine state
- `returned vs` — the top-level function returned values
- `aborted code` — explicit `abort` with an error code
- `error` — runtime error (type mismatch, out of bounds, etc.) -/

inductive ExecResult where
  | ok (frame : Frame) (callStack : List Frame) (stack : List MoveValue)
      (containers : ContainerStore)
  | returned (values : List MoveValue) (containers : ContainerStore)
  | aborted (code : UInt64)
  | error
  deriving BEq

/-! ## Module environment

`ModuleEnv` bundles the constant pool and function table needed by the
evaluator.  Native functions plug in through `FuncBody.native`. -/

structure ModuleEnv where
  constants : Array ConstPoolEntry
  functions : Array FuncDesc

end AptosFormal.Move
