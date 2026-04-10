import AptosFormal.Move.State

/-!
# Move small-step evaluator

Pure-functional small-step semantics for Move bytecode execution.
Each call to `step` consumes one instruction and produces an `ExecResult`.

**Source:**
- `third_party/move/move-vm/runtime/src/interpreter.rs` — `execute_code_impl`
- `third_party/move/move-vm/runtime/src/frame.rs` — `Frame::execute_code`
-/

namespace AptosFormal.Move

/-! ## Integer arithmetic helpers

Binary operations on same-width integer values. Returns `none` on type
mismatch or arithmetic error (overflow, underflow, division by zero). -/

private def intAdd : MoveValue → MoveValue → Option MoveValue
  | .u8  a, .u8  b => some (.u8  (a + b))
  | .u16 a, .u16 b => some (.u16 (a + b))
  | .u32 a, .u32 b => some (.u32 (a + b))
  | .u64 a, .u64 b => some (.u64 (a + b))
  | .u128 a, .u128 b => (U128.add a b).map .u128
  | .u256 a, .u256 b => (U256.add a b).map .u256
  | _, _ => none

private def intSub : MoveValue → MoveValue → Option MoveValue
  | .u8  a, .u8  b => some (.u8  (a - b))
  | .u16 a, .u16 b => some (.u16 (a - b))
  | .u32 a, .u32 b => some (.u32 (a - b))
  | .u64 a, .u64 b => some (.u64 (a - b))
  | .u128 a, .u128 b => (U128.sub a b).map .u128
  | .u256 a, .u256 b => (U256.sub a b).map .u256
  | _, _ => none

private def intMul : MoveValue → MoveValue → Option MoveValue
  | .u8  a, .u8  b => some (.u8  (a * b))
  | .u16 a, .u16 b => some (.u16 (a * b))
  | .u32 a, .u32 b => some (.u32 (a * b))
  | .u64 a, .u64 b => some (.u64 (a * b))
  | .u128 a, .u128 b => (U128.mul a b).map .u128
  | .u256 a, .u256 b => (U256.mul a b).map .u256
  | _, _ => none

private def intDiv : MoveValue → MoveValue → Option MoveValue
  | .u8  _, .u8  0 => none
  | .u8  a, .u8  b => some (.u8  (a / b))
  | .u16 _, .u16 0 => none
  | .u16 a, .u16 b => some (.u16 (a / b))
  | .u32 _, .u32 0 => none
  | .u32 a, .u32 b => some (.u32 (a / b))
  | .u64 _, .u64 0 => none
  | .u64 a, .u64 b => some (.u64 (a / b))
  | .u128 a, .u128 b => (U128.div a b).map .u128
  | .u256 a, .u256 b => (U256.div a b).map .u256
  | _, _ => none

private def intMod : MoveValue → MoveValue → Option MoveValue
  | .u8  _, .u8  0 => none
  | .u8  a, .u8  b => some (.u8  (a % b))
  | .u16 _, .u16 0 => none
  | .u16 a, .u16 b => some (.u16 (a % b))
  | .u32 _, .u32 0 => none
  | .u32 a, .u32 b => some (.u32 (a % b))
  | .u64 _, .u64 0 => none
  | .u64 a, .u64 b => some (.u64 (a % b))
  | .u128 a, .u128 b => (U128.mod_ a b).map .u128
  | .u256 a, .u256 b => (U256.mod_ a b).map .u256
  | _, _ => none

/-! ## Bitwise helpers -/

private def intBitOr : MoveValue → MoveValue → Option MoveValue
  | .u8  a, .u8  b => some (.u8  (a ||| b))
  | .u16 a, .u16 b => some (.u16 (a ||| b))
  | .u32 a, .u32 b => some (.u32 (a ||| b))
  | .u64 a, .u64 b => some (.u64 (a ||| b))
  | _, _ => none

private def intBitAnd : MoveValue → MoveValue → Option MoveValue
  | .u8  a, .u8  b => some (.u8  (a &&& b))
  | .u16 a, .u16 b => some (.u16 (a &&& b))
  | .u32 a, .u32 b => some (.u32 (a &&& b))
  | .u64 a, .u64 b => some (.u64 (a &&& b))
  | _, _ => none

private def intXor : MoveValue → MoveValue → Option MoveValue
  | .u8  a, .u8  b => some (.u8  (a ^^^ b))
  | .u16 a, .u16 b => some (.u16 (a ^^^ b))
  | .u32 a, .u32 b => some (.u32 (a ^^^ b))
  | .u64 a, .u64 b => some (.u64 (a ^^^ b))
  | _, _ => none

/-! ## Comparison helpers -/

def intLt : MoveValue → MoveValue → Option Bool
  | .u8  a, .u8  b => some (a < b)
  | .u16 a, .u16 b => some (a < b)
  | .u32 a, .u32 b => some (a < b)
  | .u64 a, .u64 b => some (a < b)
  | .u128 a, .u128 b => some (a.val < b.val)
  | .u256 a, .u256 b => some (a.val < b.val)
  | _, _ => none

/-- Exposed for refinement proofs that relate `lt` on the operand stack to `UInt64` ordering. -/
theorem intLt_u64 (a b : UInt64) : intLt (.u64 a) (.u64 b) = some (decide (a < b)) := rfl

private def intGt (a b : MoveValue) : Option Bool := intLt b a

private def intLe (a b : MoveValue) : Option Bool := do
  let r ← intLt b a; return !r

private def intGe (a b : MoveValue) : Option Bool := do
  let r ← intLt a b; return !r

/-! ## Shift helpers -/

private def intShl : MoveValue → UInt8 → Option MoveValue
  | .u8  a, n => if n.toNat ≥ 8   then none else some (.u8  (a <<< n))
  | .u16 a, n => if n.toNat ≥ 16  then none else some (.u16 (a <<< n.toUInt16))
  | .u32 a, n => if n.toNat ≥ 32  then none else some (.u32 (a <<< n.toUInt32))
  | .u64 a, n => if n.toNat ≥ 64  then none else some (.u64 (a <<< n.toUInt64))
  | _, _ => none

private def intShr : MoveValue → UInt8 → Option MoveValue
  | .u8  a, n => if n.toNat ≥ 8   then none else some (.u8  (a >>> n))
  | .u16 a, n => if n.toNat ≥ 16  then none else some (.u16 (a >>> n.toUInt16))
  | .u32 a, n => if n.toNat ≥ 32  then none else some (.u32 (a >>> n.toUInt32))
  | .u64 a, n => if n.toNat ≥ 64  then none else some (.u64 (a >>> n.toUInt64))
  | _, _ => none

/-! ## Casting helpers -/

private def intToNat : MoveValue → Option Nat
  | .u8  n => some n.toNat
  | .u16 n => some n.toNat
  | .u32 n => some n.toNat
  | .u64 n => some n.toNat
  | .u128 n => some n.val
  | .u256 n => some n.val
  | _ => none

private def castToU8 (v : MoveValue) : Option MoveValue := do
  let n ← intToNat v
  if n < 2 ^ 8 then some (.u8 n.toUInt8) else none

private def castToU16 (v : MoveValue) : Option MoveValue := do
  let n ← intToNat v
  if n < 2 ^ 16 then some (.u16 n.toUInt16) else none

private def castToU32 (v : MoveValue) : Option MoveValue := do
  let n ← intToNat v
  if n < 2 ^ 32 then some (.u32 n.toUInt32) else none

private def castToU64 (v : MoveValue) : Option MoveValue := do
  let n ← intToNat v
  if n < 2 ^ 64 then some (.u64 n.toUInt64) else none

private def castToU128 (v : MoveValue) : Option MoveValue := do
  let n ← intToNat v
  U128.ofNat? n |>.map .u128

private def castToU256 (v : MoveValue) : Option MoveValue := do
  let n ← intToNat v
  U256.ofNat? n |>.map .u256

/-! ## List helpers for stack operations -/

private def takeN (stack : List MoveValue) (n : Nat) : Option (List MoveValue × List MoveValue) :=
  if stack.length < n then none
  else some (stack.take n |>.reverse, stack.drop n)

/-! ## Reference helper: extract RefId from a reference value -/

def getRefId : MoveValue → Option RefId
  | .mutRef id => some id
  | .immRef id => some id
  | _ => none

@[simp] theorem getRefId_mut (id : RefId) : getRefId (.mutRef id) = some id := rfl
@[simp] theorem getRefId_imm (id : RefId) : getRefId (.immRef id) = some id := rfl

/-! ## Single-step evaluator

`step env frame callStack stack containers` executes the instruction at
`frame.code[frame.pc]` and produces an `ExecResult`. -/

def step (env : ModuleEnv) (frame : Frame) (callStack : List Frame)
    (stack : List MoveValue) (containers : ContainerStore) : ExecResult :=
  if h : frame.pc < frame.code.size then
    let instr := frame.code[frame.pc]
    let advance (f : Frame) : Frame := { f with pc := f.pc + 1 }
    let ok' (f : Frame) (cs : List Frame) (s : List MoveValue)
        (ct : ContainerStore) :=
      ExecResult.ok (advance f) cs s ct
    match instr with

    -- Stack and locals
    | .pop => match stack with
      | _ :: rest => ok' frame callStack rest containers
      | _ => .error

    | .ldU8 val    => ok' frame callStack (.u8 val :: stack) containers
    | .ldU16 val   => ok' frame callStack (.u16 val :: stack) containers
    | .ldU32 val   => ok' frame callStack (.u32 val :: stack) containers
    | .ldU64 val   => ok' frame callStack (.u64 val :: stack) containers
    | .ldU128 val  => ok' frame callStack (.u128 val :: stack) containers
    | .ldU256 val  => ok' frame callStack (.u256 val :: stack) containers
    | .ldTrue      => ok' frame callStack (.bool true :: stack) containers
    | .ldFalse     => ok' frame callStack (.bool false :: stack) containers

    | .ldConst idx =>
      if h : idx < env.constants.size then
        ok' frame callStack (env.constants[idx].value :: stack) containers
      else .error

    | .copyLoc idx =>
      if h : idx < frame.locals.size then
        match frame.locals[idx] with
        | some v => ok' frame callStack (v :: stack) containers
        | none => .error
      else .error

    | .moveLoc idx =>
      if h : idx < frame.locals.size then
        match frame.locals[idx] with
        | some v =>
          let locals' := frame.locals.set idx none (by omega)
          let frame' := { frame with locals := locals' }
          ok' frame' callStack (v :: stack) containers
        | none => .error
      else .error

    | .stLoc idx =>
      if h : idx < frame.locals.size then
        match stack with
        | v :: rest =>
          let locals' := frame.locals.set idx (some v) (by omega)
          let frame' := { frame with locals := locals' }
          ok' frame' callStack rest containers
        | _ => .error
      else .error

    -- Control flow
    | .ret =>
      match callStack with
      | caller :: restCalls =>
        ExecResult.ok caller restCalls stack containers
      | [] => .returned stack containers

    | .brTrue offset => match stack with
      | .bool true :: rest =>
        .ok { frame with pc := offset } callStack rest containers
      | .bool false :: rest => ok' frame callStack rest containers
      | _ => .error

    | .brFalse offset => match stack with
      | .bool false :: rest =>
        .ok { frame with pc := offset } callStack rest containers
      | .bool true :: rest => ok' frame callStack rest containers
      | _ => .error

    | .branch offset =>
      .ok { frame with pc := offset } callStack stack containers

    | .call funcIdx =>
      if h : funcIdx < env.functions.size then
        let fdesc := env.functions[funcIdx]
        match takeN stack fdesc.numParams with
        | some (args, rest) =>
          match fdesc.body with
          | .native impl =>
            match impl args with
            | some results => ok' frame callStack (results ++ rest) containers
            | none => .error
          | .bytecode code numLocals =>
            let newLocals := args.map some ++
              List.replicate (numLocals - fdesc.numParams) none
            let newFrame : Frame := {
              code := code
              pc := 0
              locals := newLocals.toArray
            }
            let savedFrame := { frame with pc := frame.pc + 1 }
            .ok newFrame (savedFrame :: callStack) rest containers
        | none => .error
      else .error

    | .abort_ => match stack with
      | .u64 code :: _ => .aborted code
      | _ => .error

    | .nop => ok' frame callStack stack containers

    -- Arithmetic
    | .add => match stack with
      | rhs :: lhs :: rest => match intAdd lhs rhs with
        | some v => ok' frame callStack (v :: rest) containers
        | none => .error
      | _ => .error
    | .sub => match stack with
      | rhs :: lhs :: rest => match intSub lhs rhs with
        | some v => ok' frame callStack (v :: rest) containers
        | none => .error
      | _ => .error
    | .mul => match stack with
      | rhs :: lhs :: rest => match intMul lhs rhs with
        | some v => ok' frame callStack (v :: rest) containers
        | none => .error
      | _ => .error
    | .div => match stack with
      | rhs :: lhs :: rest => match intDiv lhs rhs with
        | some v => ok' frame callStack (v :: rest) containers
        | none => .error
      | _ => .error
    | .mod_ => match stack with
      | rhs :: lhs :: rest => match intMod lhs rhs with
        | some v => ok' frame callStack (v :: rest) containers
        | none => .error
      | _ => .error

    -- Bitwise
    | .bitOr => match stack with
      | rhs :: lhs :: rest => match intBitOr lhs rhs with
        | some v => ok' frame callStack (v :: rest) containers
        | none => .error
      | _ => .error
    | .bitAnd => match stack with
      | rhs :: lhs :: rest => match intBitAnd lhs rhs with
        | some v => ok' frame callStack (v :: rest) containers
        | none => .error
      | _ => .error
    | .xor => match stack with
      | rhs :: lhs :: rest => match intXor lhs rhs with
        | some v => ok' frame callStack (v :: rest) containers
        | none => .error
      | _ => .error
    | .shl => match stack with
      | .u8 n :: lhs :: rest => match intShl lhs n with
        | some v => ok' frame callStack (v :: rest) containers
        | none => .error
      | _ => .error
    | .shr => match stack with
      | .u8 n :: lhs :: rest => match intShr lhs n with
        | some v => ok' frame callStack (v :: rest) containers
        | none => .error
      | _ => .error

    -- Boolean
    | .or => match stack with
      | .bool b :: .bool a :: rest =>
        ok' frame callStack (.bool (a || b) :: rest) containers
      | _ => .error
    | .and => match stack with
      | .bool b :: .bool a :: rest =>
        ok' frame callStack (.bool (a && b) :: rest) containers
      | _ => .error
    | .not => match stack with
      | .bool b :: rest =>
        ok' frame callStack (.bool (!b) :: rest) containers
      | _ => .error

    -- Comparison
    -- Move's Eq/Neq dereference references before comparing values.
    -- See `IndexedRef::equals` / `ContainerRef::equals` in values_impl.rs.
    | .eq => match stack with
      | rhs :: lhs :: rest =>
        let lhs' := match lhs with
          | .immRef id | .mutRef id => (containers.read id).getD lhs
          | v => v
        let rhs' := match rhs with
          | .immRef id | .mutRef id => (containers.read id).getD rhs
          | v => v
        ok' frame callStack (.bool (lhs' == rhs') :: rest) containers
      | _ => .error
    | .neq => match stack with
      | rhs :: lhs :: rest =>
        let lhs' := match lhs with
          | .immRef id | .mutRef id => (containers.read id).getD lhs
          | v => v
        let rhs' := match rhs with
          | .immRef id | .mutRef id => (containers.read id).getD rhs
          | v => v
        ok' frame callStack (.bool (!(lhs' == rhs')) :: rest) containers
      | _ => .error
    | .lt => match stack with
      | rhs :: lhs :: rest => match intLt lhs rhs with
        | some b => ok' frame callStack (.bool b :: rest) containers
        | none => .error
      | _ => .error
    | .gt => match stack with
      | rhs :: lhs :: rest => match intGt lhs rhs with
        | some b => ok' frame callStack (.bool b :: rest) containers
        | none => .error
      | _ => .error
    | .le => match stack with
      | rhs :: lhs :: rest => match intLe lhs rhs with
        | some b => ok' frame callStack (.bool b :: rest) containers
        | none => .error
      | _ => .error
    | .ge => match stack with
      | rhs :: lhs :: rest => match intGe lhs rhs with
        | some b => ok' frame callStack (.bool b :: rest) containers
        | none => .error
      | _ => .error

    -- Casting
    | .castU8 => match stack with
      | v :: rest => match castToU8 v with
        | some v' => ok' frame callStack (v' :: rest) containers
        | none => .error
      | _ => .error
    | .castU16 => match stack with
      | v :: rest => match castToU16 v with
        | some v' => ok' frame callStack (v' :: rest) containers
        | none => .error
      | _ => .error
    | .castU32 => match stack with
      | v :: rest => match castToU32 v with
        | some v' => ok' frame callStack (v' :: rest) containers
        | none => .error
      | _ => .error
    | .castU64 => match stack with
      | v :: rest => match castToU64 v with
        | some v' => ok' frame callStack (v' :: rest) containers
        | none => .error
      | _ => .error
    | .castU128 => match stack with
      | v :: rest => match castToU128 v with
        | some v' => ok' frame callStack (v' :: rest) containers
        | none => .error
      | _ => .error
    | .castU256 => match stack with
      | v :: rest => match castToU256 v with
        | some v' => ok' frame callStack (v' :: rest) containers
        | none => .error
      | _ => .error

    -- Struct
    | .pack _structIdx numFields => match takeN stack numFields with
      | some (fields, rest) =>
        ok' frame callStack (.struct_ fields :: rest) containers
      | none => .error
    | .unpack _structIdx numFields => match stack with
      | .struct_ fields :: rest =>
        if fields.length == numFields then
          ok' frame callStack (fields.reverse ++ rest) containers
        else .error
      | _ => .error

    -- Vector (value-level)
    | .vecPack elemType numElems => match takeN stack numElems with
      | some (elems, rest) =>
        ok' frame callStack (.vector elemType elems :: rest) containers
      | none => .error
    | .vecLen _elemType => match stack with
      | .vector _ elems :: rest =>
        ok' frame callStack (.u64 elems.length.toUInt64 :: rest) containers
      | _ => .error
    | .vecPushBack _elemType => match stack with
      | val :: .vector et elems :: rest =>
        ok' frame callStack (.vector et (elems ++ [val]) :: rest) containers
      | _ => .error
    | .vecPopBack _elemType => match stack with
      | .vector et elems :: rest =>
        match elems.reverse with
        | last :: init =>
          ok' frame callStack
            (last :: .vector et init.reverse :: rest) containers
        | [] => .error
      | _ => .error
    | .vecUnpack _elemType numElems => match stack with
      | .vector _ elems :: rest =>
        if elems.length == numElems then
          ok' frame callStack (elems.reverse ++ rest) containers
        else .error
      | _ => .error
    | .vecSwap _elemType => match stack with
      | .u64 j :: .u64 i :: .vector et elems :: rest =>
        let ia := i.toNat
        let ja := j.toNat
        if h1 : ia < elems.length then
          if h2 : ja < elems.length then
            let vi := elems[ia]
            let vj := elems[ja]
            let elems' := (elems.set ia vj).set ja vi
            ok' frame callStack (.vector et elems' :: rest) containers
          else .error
        else .error
      | _ => .error

    -- References
    | .mutBorrowLoc idx =>
      if h : idx < frame.locals.size then
        match frame.locals[idx] with
        | some v =>
          let (containers', refId) := containers.alloc v
          let locals' := frame.locals.set idx none (by omega)
          let frame' := { frame with locals := locals' }
          ok' frame' callStack (.mutRef refId :: stack) containers'
        | none => .error
      else .error

    | .immBorrowLoc idx =>
      if h : idx < frame.locals.size then
        match frame.locals[idx] with
        | some v =>
          let (containers', refId) := containers.alloc v
          ok' frame callStack (.immRef refId :: stack) containers'
        | none => .error
      else .error

    | .readRef => match stack with
      | ref :: rest => match getRefId ref with
        | some id => match containers.read id with
          | some v => ok' frame callStack (v :: rest) containers
          | none => .error
        | none => .error
      | _ => .error

    | .writeRef => match stack with
      | ref :: val :: rest => match ref with
        | .mutRef id => match containers.write id val with
          | some containers' => ok' frame callStack rest containers'
          | none => .error
        | _ => .error
      | _ => .error

    | .freezeRef => match stack with
      | .mutRef id :: rest =>
        ok' frame callStack (.immRef id :: rest) containers
      | _ => .error

    | .immBorrowField fieldIdx => match stack with
      | ref :: rest => match getRefId ref with
        | some id => match containers.read id with
          | some (.struct_ fields) =>
            if h : fieldIdx < fields.length then
              let (containers', fid) := containers.alloc fields[fieldIdx]
              ok' frame callStack (.immRef fid :: rest) containers'
            else .error
          | _ => .error
        | none => .error
      | _ => .error

    | .mutBorrowField fieldIdx => match stack with
      | .mutRef id :: rest => match containers.read id with
        | some (.struct_ fields) =>
          if h : fieldIdx < fields.length then
            let (containers', fid) := containers.alloc fields[fieldIdx]
            ok' frame callStack (.mutRef fid :: rest) containers'
          else .error
        | _ => .error
      | _ => .error

    -- Vector (reference-level, matching real Move bytecode)
    | .vecLenRef _elemType => match stack with
      | ref :: rest => match getRefId ref with
        | some id => match containers.read id with
          | some (.vector _ elems) =>
            ok' frame callStack
              (.u64 elems.length.toUInt64 :: rest) containers
          | _ => .error
        | none => .error
      | _ => .error

    | .vecImmBorrow _elemType => match stack with
      | .u64 i :: ref :: rest => match getRefId ref with
        | some id => match containers.read id with
          | some (.vector _ elems) =>
            let ia := i.toNat
            if h : ia < elems.length then
              let (containers', eid) := containers.alloc elems[ia]
              ok' frame callStack (.immRef eid :: rest) containers'
            else .error
          | _ => .error
        | none => .error
      | _ => .error

    | .vecMutBorrow _elemType => match stack with
      | .u64 i :: .mutRef id :: rest => match containers.read id with
        | some (.vector _ elems) =>
          let ia := i.toNat
          if h : ia < elems.length then
            let (containers', eid) := containers.alloc elems[ia]
            ok' frame callStack (.mutRef eid :: rest) containers'
          else .error
        | _ => .error
      | _ => .error

    | .vecPushBackRef _elemType => match stack with
      | val :: .mutRef id :: rest => match containers.read id with
        | some (.vector et elems) =>
          match containers.write id (.vector et (elems ++ [val])) with
          | some containers' => ok' frame callStack rest containers'
          | none => .error
        | _ => .error
      | _ => .error

    | .vecPopBackRef _elemType => match stack with
      | .mutRef id :: rest => match containers.read id with
        | some (.vector et elems) =>
          match elems.reverse with
          | last :: init =>
            match containers.write id (.vector et init.reverse) with
            | some containers' =>
              ok' frame callStack (last :: rest) containers'
            | none => .error
          | [] => .error
        | _ => .error
      | _ => .error

    | .vecSwapRef _elemType => match stack with
      | .u64 j :: .u64 i :: .mutRef id :: rest =>
        match containers.read id with
        | some (.vector et elems) =>
          let ia := i.toNat
          let ja := j.toNat
          if h1 : ia < elems.length then
            if h2 : ja < elems.length then
              let vi := elems[ia]
              let vj := elems[ja]
              let elems' := (elems.set ia vj).set ja vi
              match containers.write id (.vector et elems') with
              | some containers' =>
                ok' frame callStack rest containers'
              | none => .error
            else .error
          else .error
        | _ => .error
      | _ => .error

  else .error

/-! ## Multi-step evaluation -/

def run (env : ModuleEnv) (frame : Frame) (callStack : List Frame)
    (stack : List MoveValue) (containers : ContainerStore)
    (fuel : Nat) : ExecResult :=
  match fuel with
  | 0 => .error
  | fuel' + 1 =>
    match step env frame callStack stack containers with
    | .ok frame' cs' stack' containers' =>
      run env frame' cs' stack' containers' fuel'
    | result => result

/-! ## Top-level entry point -/

def eval (env : ModuleEnv) (funcIdx : FuncIndex) (args : List MoveValue)
    (fuel : Nat) : ExecResult :=
  if h : funcIdx < env.functions.size then
    let fdesc := env.functions[funcIdx]
    match fdesc.body with
    | .native impl =>
      match impl args with
      | some results => .returned results ContainerStore.empty
      | none => .error
    | .bytecode code numLocals =>
      let initLocals := args.map some ++
        List.replicate (numLocals - fdesc.numParams) none
      let frame : Frame := {
        code := code
        pc := 0
        locals := initLocals.toArray
      }
      run env frame [] [] ContainerStore.empty fuel
  else .error

end AptosFormal.Move
