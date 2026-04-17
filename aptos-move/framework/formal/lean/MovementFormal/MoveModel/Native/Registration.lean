import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native
import MovementFormal.AptosStd.Crypto.Ristretto255
import MovementFormal.AptosStd.Hash.Sha2_512

/-!
# Native function bindings for `verify_registration_proof`

**Source:** `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`; crypto / hash anchors `aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.move`, `aptos-move/framework/aptos-stdlib/sources/hash.move`.

Extends the standard native table with the **minimal** set of Ristretto255,
SHA2-512, and BCS operations needed to `eval` a transcribed
`verify_registration_proof` bytecode body.

**Crypto operations** (point arithmetic, decompression, equality) are
inherently abstract — we parameterize them via `RegistrationNativeOracle`,
which aligns with `CryptoOracleWithBoolEq` from `Operational.lean`.

**Hash operations** use the executable Lean SHA2-512 from `MovementFormal.AptosStd.Hash.Sha2_512`.
-/

namespace MovementFormal.MoveModel.Native.Registration

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native
open MovementFormal.AptosStd.Crypto.Ristretto255
open MovementFormal.AptosStd.Hash.Sha2_512

/-! ## Oracle for abstract point operations

`RegistrationNativeOracle` provides the curve operations as Lean functions
on `MoveValue`. Points are represented as opaque `MoveValue.vector .u8`
(compressed 32-byte or internal representation); scalars likewise.
Oracle functions operate on **values** (not references); reference-to-value
bridging is handled by `nativeRef` wrappers below. -/

structure RegistrationNativeOracle where
  /-- `ristretto255::new_compressed_point_from_bytes(bytes) → Option<CompressedRistretto>` -/
  newCompressedPointFromBytes : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::new_scalar_from_bytes(bytes) → Option<Scalar>` -/
  newScalarFromBytes : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::compressed_point_to_bytes(p) → vector<u8>` -/
  compressedPointToBytes : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::hash_to_point_base() → RistrettoPoint` -/
  hashToPointBase : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::point_decompress(compressed) → RistrettoPoint` -/
  pointDecompress : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::point_mul(point, scalar) → RistrettoPoint` -/
  pointMul : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::point_add(a, b) → RistrettoPoint` -/
  pointAdd : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::point_equals(a, b) → bool` -/
  pointEquals : List MoveValue → Option (List MoveValue)
  /-- `twisted_elgamal::pubkey_to_bytes(ek) → vector<u8>` -/
  pubkeyToBytes : List MoveValue → Option (List MoveValue)
  /-- `twisted_elgamal::pubkey_to_point(ek) → RistrettoPoint` -/
  pubkeyToPoint : List MoveValue → Option (List MoveValue)

/-! ## Reference helpers

Move's compiled bytecode passes many arguments by reference (`&T`, `&mut T`).
These helpers dereference `MoveValue.immRef`/`.mutRef` from the `ContainerStore`
so that existing value-level oracle and native functions can be reused. -/

private def derefImm (cs : ContainerStore) : MoveValue → Option MoveValue
  | .immRef id => cs.read id
  | v => some v

/-! ## Ref-aware native functions (for real bytecode semantics)

These use `FuncBody.nativeRef` — they receive the `ContainerStore` plus raw
stack args (which may include `.immRef`/`.mutRef` values), and return results
plus an updated `ContainerStore`. -/

/-- `option::is_some<T>(&Option<T>) → bool` — dereferences immRef arg. -/
def optionIsSomeRef : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)
  | cs, [.immRef id] =>
    match cs.read id with
    | some (.struct_ (.bool tag :: _)) => some ([.bool tag], cs)
    | _ => none
  | _, _ => none

/-- `option::extract<T>(&mut Option<T>) → T` — reads through mutRef, writes None back. -/
def optionExtractRef : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)
  | cs, [.mutRef id] =>
    match cs.read id with
    | some (.struct_ (.bool true :: val :: _)) =>
      match cs.write id (.struct_ [.bool false]) with
      | some cs' => some ([val], cs')
      | none => none
    | _ => none
  | _, _ => none

/-- `vector::append<u8>(&mut vector<u8>, vector<u8>)` — mutates through ref, returns void. -/
def vectorAppendU8Ref : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)
  | cs, [.mutRef id, .vector .u8 appended] =>
    match cs.read id with
    | some (.vector .u8 existing) =>
      match cs.write id (.vector .u8 (existing ++ appended)) with
      | some cs' => some ([], cs')
      | none => none
    | _ => none
  | _, _ => none

/-- `bcs::to_bytes<address>(&address) → vector<u8>` — dereferences immRef. -/
def bcsToBytesAddressRef : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)
  | cs, [.immRef id] =>
    match cs.read id with
    | some (.address bs) => some ([.vector .u8 (bs.toList.map .u8)], cs)
    | _ => none
  | _, _ => none

/-- Wrap a 1-arg value-level oracle to accept an immRef argument. -/
def wrapOracleImmRef1 (oracle : List MoveValue → Option (List MoveValue))
    : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)
  | cs, [arg] => do
    let v ← derefImm cs arg
    let results ← oracle [v]
    return (results, cs)
  | _, _ => none

/-- Wrap a 2-arg value-level oracle to accept immRef arguments. -/
def wrapOracleImmRef2 (oracle : List MoveValue → Option (List MoveValue))
    : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)
  | cs, [arg1, arg2] => do
    let v1 ← derefImm cs arg1
    let v2 ← derefImm cs arg2
    let results ← oracle [v1, v2]
    return (results, cs)
  | _, _ => none

/-! ## Executable natives (non-oracle) -/

private def u8ElemsToByteArray (elems : List MoveValue) : Option ByteArray :=
  let rec go (acc : Array UInt8) : List MoveValue → Option ByteArray
    | [] => some (ByteArray.mk acc)
    | .u8 b :: rest => go (acc.push b) rest
    | _ :: _ => none
  go #[] elems

private def bytesToMoveVec (bs : ByteArray) : MoveValue :=
  .vector .u8 (bs.toList.map .u8)

/-- `ristretto255::new_scalar_from_sha2_512(input)`: SHA2-512 → scalar.
    Takes one `vector<u8>` argument, returns a `Scalar` struct.
    The 64-byte digest is reduced mod ℓ (the curve order). -/
def newScalarFromSha2_512 : List MoveValue → Option (List MoveValue)
  | [.vector .u8 elems] =>
    match u8ElemsToByteArray elems with
    | some ba =>
      let digest := sha2_512 ba
      let scalarBytes := digest.toList.map MoveValue.u8
      some [.struct_ [.vector .u8 scalarBytes]]
    | none => none
  | _ => none

/-- `option::is_some<T>(opt) → bool` on struct-encoded Option (field 0 = bool tag). -/
def optionIsSome : List MoveValue → Option (List MoveValue)
  | [.struct_ (.bool tag :: _)] => some [.bool tag]
  | _ => none

/-- `option::extract<T>(opt) → T` on struct-encoded Option. Aborts (returns none) if tag is false. -/
def optionExtract : List MoveValue → Option (List MoveValue)
  | [.struct_ (.bool true :: val :: _)] => some [val]
  | _ => none

/-- `vector::singleton<u8>(byte)` -/
def vectorSingletonU8 : List MoveValue → Option (List MoveValue)
  | [.u8 b] => some [.vector .u8 [.u8 b]]
  | _ => none

/-- `vector::push_back<u8>(&mut vector<u8>, u8)` — appends single byte through ref. -/
def vectorPushBackU8Ref : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)
  | cs, [.mutRef id, .u8 b] =>
    match cs.read id with
    | some (.vector .u8 existing) =>
      match cs.write id (.vector .u8 (existing ++ [.u8 b])) with
      | some cs' => some ([], cs')
      | none => none
    | _ => none
  | _, _ => none

/-- `vector::append<u8>(v1, v2)` — consumes both, returns concatenated vector. -/
def vectorAppendU8 : List MoveValue → Option (List MoveValue)
  | [.vector .u8 a, .vector .u8 b] => some [.vector .u8 (a ++ b)]
  | _ => none

/-- `bcs::to_bytes<address>(addr)` — address is 32-byte `MoveValue.address`; BCS = identity. -/
def bcsToBytes_address : List MoveValue → Option (List MoveValue)
  | [.address bs] => some [.vector .u8 (bs.toList.map .u8)]
  | _ => none

/-! ## error::invalid_argument

`error::invalid_argument(reason)` computes `(1 << 16) + reason`.
Source: `aptos-move/framework/move-stdlib/sources/error.move`. -/

def errorInvalidArgument : List MoveValue → Option (List MoveValue)
  | [.u64 reason] => some [.u64 (65536 + reason)]
  | _ => none

/-! ## Function descriptors (value-semantics, kept for backward compat) -/

def newScalarFromSha2_512Desc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .native newScalarFromSha2_512 }

def optionIsSomeDesc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .native optionIsSome }

def optionExtractDesc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .native optionExtract }

def vectorSingletonU8Desc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .native vectorSingletonU8 }

def vectorAppendU8Desc : FuncDesc :=
  { numParams := 2, numReturns := 1, body := .native vectorAppendU8 }

def bcsToBytes_addressDesc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .native bcsToBytes_address }

/-! ## Ref-aware function descriptors (for real bytecode)

These match the calling conventions of the `movement` v7.4 compiled bytecode,
where many stdlib functions take `&T` or `&mut T` arguments. -/

def optionIsSomeRefDesc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .nativeRef optionIsSomeRef }

def optionExtractRefDesc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .nativeRef optionExtractRef }

def vectorAppendU8RefDesc : FuncDesc :=
  { numParams := 2, numReturns := 0, body := .nativeRef vectorAppendU8Ref }

def vectorPushBackU8RefDesc : FuncDesc :=
  { numParams := 2, numReturns := 0, body := .nativeRef vectorPushBackU8Ref }

def bcsToBytesAddressRefDesc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .nativeRef bcsToBytesAddressRef }

def errorInvalidArgumentDesc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .native errorInvalidArgument }

/-- Build oracle-dependent function descriptors from a `RegistrationNativeOracle`. -/
def oracleDescs (o : RegistrationNativeOracle) : Array FuncDesc := #[
  { numParams := 1, numReturns := 1, body := .native o.newCompressedPointFromBytes },  -- 0
  { numParams := 1, numReturns := 1, body := .native o.newScalarFromBytes },            -- 1
  { numParams := 1, numReturns := 1, body := .native o.compressedPointToBytes },         -- 2
  { numParams := 0, numReturns := 1, body := .native o.hashToPointBase },                -- 3
  { numParams := 1, numReturns := 1, body := .native o.pointDecompress },                -- 4
  { numParams := 2, numReturns := 1, body := .native o.pointMul },                       -- 5
  { numParams := 2, numReturns := 1, body := .native o.pointAdd },                       -- 6
  { numParams := 2, numReturns := 1, body := .native o.pointEquals },                    -- 7
  { numParams := 1, numReturns := 1, body := .native o.pubkeyToBytes },                  -- 8
  { numParams := 1, numReturns := 1, body := .native o.pubkeyToPoint }                   -- 9
]

/-! ## Real bytecode module environment (movement v7.4 compiler output)

Function index table for the **actual** 83-instruction bytecode:

| Index | Function | Body kind |
|-------|----------|-----------|
| 0     | `ristretto255::new_compressed_point_from_bytes(vector<u8>)` | native (oracle) |
| 1     | `option::is_some<T>(&Option<T>)` | nativeRef |
| 2     | `option::extract<T>(&mut Option<T>)` | nativeRef |
| 3     | `ristretto255::new_scalar_from_bytes(vector<u8>)` | native (oracle) |
| 4     | `vector::push_back<u8>(&mut vector<u8>, u8)` | nativeRef |
| 5     | `bcs::to_bytes<address>(&address)` | nativeRef |
| 6     | `vector::append<u8>(&mut vector<u8>, vector<u8>)` | nativeRef |
| 7     | `pubkey_to_bytes(&CompressedPubkey)` | nativeRef (oracle) |
| 8     | `compressed_point_to_bytes(CompressedRistretto)` | native (oracle) |
| 9     | `ristretto255::new_scalar_from_sha2_512(vector<u8>)` | native |
| 10    | `hash_to_point_base()` | native (oracle) |
| 11    | `pubkey_to_point(&CompressedPubkey)` | nativeRef (oracle) |
| 12    | `point_mul(&RistrettoPoint, &Scalar)` | nativeRef (oracle) |
| 13    | `point_add(&RistrettoPoint, &RistrettoPoint)` | nativeRef (oracle) |
| 14    | `point_decompress(&CompressedRistretto)` | nativeRef (oracle) |
| 15    | `point_equals(&RistrettoPoint, &RistrettoPoint)` | nativeRef (oracle) |
| 16    | `error::invalid_argument(u64)` | native |
| 17    | `verify_registration_proof` (bytecode) | bytecode (84 instrs, 19 locals) |
-/

/-- `error::invalid_argument(ESIGMA_PROTOCOL_VERIFY_FAILED)` = `(1 << 16) | 1` = `0x10001` = `65537`. -/
def ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE : UInt64 := 65537

end MovementFormal.MoveModel.Native.Registration
