/-!
# Move runtime values and types

Lean model of Move's bytecode-level value and type representation.

**Source:**
- `third_party/move/move-vm/types/src/values/values_impl.rs` — `ValueImpl`, `Container`
- `third_party/move/move-binary-format/src/file_format.rs` — `SignatureToken`
-/

namespace AptosFormal.Move

/-! ## Runtime type tags

`MoveType` mirrors `SignatureToken` restricted to runtime (non-reference,
non-generic) types.  It serves as the discriminant for vector element types
and struct field layouts. -/

inductive MoveType where
  | bool
  | u8
  | u16
  | u32
  | u64
  | u128
  | u256
  | address
  | signer
  | vector (elem : MoveType)
  | struct_ (id : Nat) (fields : List MoveType)
  deriving Repr

mutual
def MoveType.list_beq : List MoveType → List MoveType → Bool
  | [], [] => true
  | a :: as, b :: bs => MoveType.beq a b && list_beq as bs
  | _, _ => false

def MoveType.beq : MoveType → MoveType → Bool
  | .bool, .bool => true
  | .u8, .u8 => true
  | .u16, .u16 => true
  | .u32, .u32 => true
  | .u64, .u64 => true
  | .u128, .u128 => true
  | .u256, .u256 => true
  | .address, .address => true
  | .signer, .signer => true
  | .vector e1, .vector e2 => MoveType.beq e1 e2
  | .struct_ i1 f1, .struct_ i2 f2 => (i1 == i2) && MoveType.list_beq f1 f2
  | _, _ => false
end

instance : BEq MoveType := ⟨MoveType.beq⟩

/-! ## Runtime values

`MoveValue` is the pure functional counterpart of the VM's `ValueImpl`.
References are modeled as `mutRef`/`immRef` carrying a `RefId` index into
the `ContainerStore` (see `State.lean`).  We omit delayed/aggregator values
and closures.

Integer widths: u8..u64 use the built-in `UInt` types; u128 and u256 use
`Nat` bounded by `isValid` predicates (matching Move's overflow semantics). -/

structure U128 where
  val : Nat
  isValid : val < 2 ^ 128 := by omega
  deriving Repr

structure U256 where
  val : Nat
  isValid : val < 2 ^ 256 := by omega
  deriving Repr

instance : BEq U128 where beq a b := a.val == b.val
instance : BEq U256 where beq a b := a.val == b.val

def U128.zero : U128 := ⟨0, by omega⟩
def U256.zero : U256 := ⟨0, by omega⟩

abbrev RefId := Nat

inductive MoveValue where
  | bool (b : Bool)
  | u8 (n : UInt8)
  | u16 (n : UInt16)
  | u32 (n : UInt32)
  | u64 (n : UInt64)
  | u128 (n : U128)
  | u256 (n : U256)
  | address (bytes : ByteArray)
  | signer (bytes : ByteArray)
  | vector (elemType : MoveType) (elems : List MoveValue)
  | struct_ (fields : List MoveValue)
  | mutRef (id : RefId)
  | immRef (id : RefId)

mutual
def MoveValue.list_beq : List MoveValue → List MoveValue → Bool
  | [], [] => true
  | a :: as, b :: bs => MoveValue.beq a b && list_beq as bs
  | _, _ => false

def MoveValue.beq : MoveValue → MoveValue → Bool
  | .bool a, .bool b => a == b
  | .u8 a, .u8 b => a == b
  | .u16 a, .u16 b => a == b
  | .u32 a, .u32 b => a == b
  | .u64 a, .u64 b => a == b
  | .u128 a, .u128 b => a == b
  | .u256 a, .u256 b => a == b
  | .address a, .address b => a == b
  | .signer a, .signer b => a == b
  | .vector t1 e1, .vector t2 e2 => MoveType.beq t1 t2 && MoveValue.list_beq e1 e2
  | .struct_ f1, .struct_ f2 => MoveValue.list_beq f1 f2
  | .mutRef i, .mutRef j => i == j
  | .immRef i, .immRef j => i == j
  | _, _ => false
end

instance : BEq MoveValue := ⟨MoveValue.beq⟩

@[simp] theorem MoveValue.beq_u64 (a b : UInt64) : MoveValue.beq (.u64 a) (.u64 b) = (a == b) :=
  rfl

instance : Repr MoveValue where
  reprPrec v _ := match v with
    | .bool b => f!"MoveValue.bool {repr b}"
    | .u8 n => f!"MoveValue.u8 {repr n}"
    | .u16 n => f!"MoveValue.u16 {repr n}"
    | .u32 n => f!"MoveValue.u32 {repr n}"
    | .u64 n => f!"MoveValue.u64 {repr n}"
    | .u128 n => f!"MoveValue.u128 ⟨{n.val}⟩"
    | .u256 n => f!"MoveValue.u256 ⟨{n.val}⟩"
    | .address _ => "MoveValue.address ⟨…⟩"
    | .signer _ => "MoveValue.signer ⟨…⟩"
    | .vector t es => f!"MoveValue.vector {repr t} ({es.length} elems)"
    | .struct_ fs => f!"MoveValue.struct_ ({fs.length} fields)"
    | .mutRef i => f!"MoveValue.mutRef {repr i}"
    | .immRef i => f!"MoveValue.immRef {repr i}"

/-! ## Type-checking predicate

`hasType v t` holds when the value `v` is well-formed at type `t`.
This mirrors the bytecode verifier's type-safety invariant for values
on the stack and in locals. -/

mutual
def MoveValue.hasType : MoveValue → MoveType → Prop
  | .bool _,    .bool    => True
  | .u8 _,      .u8      => True
  | .u16 _,     .u16     => True
  | .u32 _,     .u32     => True
  | .u64 _,     .u64     => True
  | .u128 _,    .u128    => True
  | .u256 _,    .u256    => True
  | .address _, .address => True
  | .signer _,  .signer  => True
  | .vector et elems, .vector et' =>
      et == et' ∧ MoveValue.allHaveType elems et'
  | .struct_ fields, .struct_ _ fieldTypes =>
      MoveValue.pairwiseHasType fields fieldTypes
  | _, _ => False

def MoveValue.allHaveType : List MoveValue → MoveType → Prop
  | [],     _  => True
  | v :: vs, t => v.hasType t ∧ allHaveType vs t

def MoveValue.pairwiseHasType : List MoveValue → List MoveType → Prop
  | [],     []      => True
  | v :: vs, t :: ts => v.hasType t ∧ pairwiseHasType vs ts
  | _,      _       => False
end

/-! ## Integer helpers

Arithmetic that matches Move's abort-on-overflow semantics: operations
return `Option` so the evaluator can map `none` to an abort. -/

namespace U128

def ofNat? (n : Nat) : Option U128 :=
  if h : n < 2 ^ 128 then some ⟨n, h⟩ else none

def add (a b : U128) : Option U128 := ofNat? (a.val + b.val)
def sub (a b : U128) : Option U128 :=
  if h : b.val ≤ a.val then
    some ⟨a.val - b.val, by have := a.isValid; omega⟩
  else none
def mul (a b : U128) : Option U128 := ofNat? (a.val * b.val)
def div (a b : U128) : Option U128 :=
  if b.val = 0 then none else ofNat? (a.val / b.val)
def mod_ (a b : U128) : Option U128 :=
  if b.val = 0 then none else ofNat? (a.val % b.val)

end U128

namespace U256

def ofNat? (n : Nat) : Option U256 :=
  if h : n < 2 ^ 256 then some ⟨n, h⟩ else none

def add (a b : U256) : Option U256 := ofNat? (a.val + b.val)
def sub (a b : U256) : Option U256 :=
  if h : b.val ≤ a.val then
    some ⟨a.val - b.val, by have := a.isValid; omega⟩
  else none
def mul (a b : U256) : Option U256 := ofNat? (a.val * b.val)
def div (a b : U256) : Option U256 :=
  if b.val = 0 then none else ofNat? (a.val / b.val)
def mod_ (a b : U256) : Option U256 :=
  if b.val = 0 then none else ofNat? (a.val % b.val)

end U256

/-! ## Default values

Move locals are initialized to "invalid", but after bytecode verification
every local is guaranteed to be assigned before use. For modeling purposes
we provide a `defaultValue` that returns the zero/empty value for each type. -/

def MoveType.defaultValue : MoveType → MoveValue
  | .bool    => .bool false
  | .u8      => .u8 0
  | .u16     => .u16 0
  | .u32     => .u32 0
  | .u64     => .u64 0
  | .u128    => .u128 U128.zero
  | .u256    => .u256 U256.zero
  | .address => .address (ByteArray.mk #[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                                          0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])
  | .signer  => .signer (ByteArray.mk #[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                                         0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])
  | .vector _ => .vector .u8 []
  | .struct_ _ fts => .struct_ (fts.map MoveType.defaultValue)

end AptosFormal.Move
