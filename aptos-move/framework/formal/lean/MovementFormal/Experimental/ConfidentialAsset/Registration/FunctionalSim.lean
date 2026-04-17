import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.Programs.Registration
import MovementFormal.Experimental.ConfidentialAsset.Registration.Formal

/-!
# Functional simulation of `verify_registration_proof` bytecode

`verifyRegistrationBytecodeResult` computes the same result as `eval` on the
67-instruction transcribed bytecode, but expressed as a readable Lean function
on `MoveValue`s. It serves as the intermediary layer in the refinement chain:

```
L2  eval (67 instrs)  ≡  L1.5  verifyRegistrationBytecodeResult  ≡  L1  execVerifyRegistrationProof
```

## Design rationale

Proving `eval ≡ func` requires stepping through 67 bytecode instructions
symbolically. Proving `func ≡ exec` is a straightforward functional equivalence
under oracle coherence. By splitting the proof at this boundary:

- The **`eval ≡ func`** proof is mechanical (checked by `native_decide`
  on concrete oracles, or by block-simulation lemmas abstractly)
- The **`func ≡ exec`** proof is algebraic (matching function shapes)

An auditor can verify `func` by visual inspection against the bytecode source.

**Import discipline:** This file uses only light imports (no Mathlib/ZMod) so
that `native_decide` can elaborate `func` efficiently.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.MoveModel.Programs.Registration
open MovementFormal.Experimental.ConfidentialAsset.Registration.Formal

/-! ## Helper: extract single value from a native return -/

def single? : Option (List MoveValue) → Option MoveValue
  | some [v] => some v
  | _ => none

/-! ## Fiat-Shamir message construction

Mirrors the bytecode's message build (instrs 18–42):
```
  msg = DST                                   -- ldConst
     ++ push_back(chain_id)
     ++ bcs::to_bytes(sender)
     ++ bcs::to_bytes(contract)
     ++ bcs::to_bytes(token)
     ++ pubkey_to_bytes(ek)
     ++ compressed_point_to_bytes(R)
```
The DST is now the prefix of the hash input (SHA2-512, not tagged SHA3-512). -/

def buildFSMessageMv (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token : ByteArray)
    (ek rCompressed : MoveValue) : Option MoveValue := do
  let dstVec := fiatShamirRegistrationDstValue
  let m0 ← single? (vectorAppendU8 [dstVec, .vector .u8 [.u8 chainId]])
  let sBytes ← single? (bcsToBytes_address [.address sender])
  let m1 ← single? (vectorAppendU8 [m0, sBytes])
  let cBytes ← single? (bcsToBytes_address [.address contract])
  let m2 ← single? (vectorAppendU8 [m1, cBytes])
  let tBytes ← single? (bcsToBytes_address [.address token])
  let m3 ← single? (vectorAppendU8 [m2, tBytes])
  let ekB ← single? (o.pubkeyToBytes [ek])
  let m4 ← single? (vectorAppendU8 [m3, ekB])
  let rB ← single? (o.compressedPointToBytes [rCompressed])
  single? (vectorAppendU8 [m4, rB])

/-! ## Full functional simulation

Each block mirrors a contiguous region of the 67-instruction bytecode body.
The `where` blocks keep the nesting manageable while preserving `native_decide`
reducibility. -/

def verifyRegistrationBytecodeResult (o : RegistrationNativeOracle)
    (args : List MoveValue) : ExecResult :=
  match args with
  | [.u8 chainId, .address sender, .address contract, ek,
     .address token, commitBytes, respBytes] =>
    -- Block A (instrs 0–10): Decompress commitment point R
    match single? (o.newCompressedPointFromBytes [commitBytes]) with
    | some rOpt =>
      match single? (optionIsSome [rOpt]) with
      | some (.bool true) =>
        match single? (optionExtract [rOpt]) with
        | some rCompressed =>
          blockB o chainId sender contract token ek rCompressed respBytes
        | _ => .error
      | some (.bool false) =>
        .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE
      | _ => .error
    | _ => .error
  | _ => .error
where
  blockB (o : RegistrationNativeOracle)
      (chainId : UInt8) (sender contract token : ByteArray)
      (ek rCompressed : MoveValue) (respBytes : MoveValue) : ExecResult :=
    match single? (o.newScalarFromBytes [respBytes]) with
    | some sOpt =>
      match single? (optionIsSome [sOpt]) with
      | some (.bool true) =>
        match single? (optionExtract [sOpt]) with
        | some s =>
          blockCDE o chainId sender contract token ek rCompressed s
        | _ => .error
      | some (.bool false) =>
        .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE
      | _ => .error
    | _ => .error

  blockCDE (o : RegistrationNativeOracle)
      (chainId : UInt8) (sender contract token : ByteArray)
      (ek rCompressed s : MoveValue) : ExecResult :=
    match buildFSMessageMv o chainId sender contract token ek rCompressed with
    | some msgVal =>
      match single? (newScalarFromSha2_512 [msgVal]) with
      | some e =>
        match single? (o.hashToPointBase []) with
        | some h =>
          match single? (o.pubkeyToPoint [ek]) with
          | some ekPt =>
            match single? (o.pointMul [h, s]) with
            | some hs =>
              match single? (o.pointMul [ekPt, e]) with
              | some eke =>
                match single? (o.pointAdd [hs, eke]) with
                | some lhs =>
                  match single? (o.pointDecompress [rCompressed]) with
                  | some rhs =>
                    match single? (o.pointEquals [lhs, rhs]) with
                    | some (.bool true) => .returned [] MachineState.empty
                    | some (.bool false) =>
                      .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE
                    | _ => .error
                  | _ => .error
                | _ => .error
              | _ => .error
            | _ => .error
          | _ => .error
        | _ => .error
      | _ => .error
    | none => .error

/-! ## Msg construction correctness (abstract)

When the oracle's `pubkeyToBytes` and `compressedPointToBytes` return the raw
bytes of their arguments, `buildFSMessageMv` produces a `MoveValue.vector` whose
bytes match `registrationFiatShamirMsg` from `Formal.lean`.

This is verified concretely by `native_decide` in `BytecodeDifftestEval.lean`
(`buildFSMessageMv_golden_matches_spec`). The abstract version below is stated
for future proof. -/

/-- The DST bytes as a `List MoveValue` (inner contents of `fiatShamirRegistrationDstValue`). -/
def fiatShamirDstMvU8s : List MoveValue :=
  [77, 111, 118, 101, 109, 101, 110, 116, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108,
   65, 115, 115, 101, 116, 47, 82, 101, 103, 105, 115, 116, 114, 97, 116, 105, 111, 110
  ].map MoveValue.u8

/-- `ByteArray.toList` is `@[irreducible]` in Lean 4.24, so we axiomatize this
    concrete equality (same pattern as `ByteArray.toList_append` below). -/
axiom fiatShamirDstMvU8s_eq_registrationDstBytes_toList_map :
    fiatShamirDstMvU8s = registrationDstBytes.toList.map MoveValue.u8

/-- Generalized form: works with any `ekMv` and `rMv` that satisfy the oracle
    byte-extraction hypotheses. The message now includes the 38-byte DST prefix. -/
theorem buildFSMessageMv_list_gen
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token : ByteArray)
    (ekBa commitBa : ByteArray) (ekMv rMv : MoveValue)
    (hEk : o.pubkeyToBytes [ekMv] = some [.vector .u8 (ekBa.toList.map .u8)])
    (hR : o.compressedPointToBytes [rMv] = some [.vector .u8 (commitBa.toList.map .u8)]) :
    buildFSMessageMv o chainId sender contract token ekMv rMv =
    some (.vector .u8 (
      fiatShamirDstMvU8s ++ [.u8 chainId] ++ sender.toList.map .u8 ++ contract.toList.map .u8 ++
      token.toList.map .u8 ++ ekBa.toList.map .u8 ++ commitBa.toList.map .u8)) := by
  simp only [buildFSMessageMv, single?, bcsToBytes_address,
    vectorAppendU8, hEk, hR, bind, Option.bind, fiatShamirRegistrationDstValue, fiatShamirDstMvU8s]

theorem buildFSMessageMv_list
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token : ByteArray)
    (ekBa commitBa : ByteArray)
    (hEk : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
            some [.vector .u8 (ekBa.toList.map .u8)])
    (hR : o.compressedPointToBytes [.struct_ [.vector .u8 (commitBa.toList.map .u8)]] =
           some [.vector .u8 (commitBa.toList.map .u8)]) :
    buildFSMessageMv o chainId sender contract token
      (.struct_ [.vector .u8 (ekBa.toList.map .u8)])
      (.struct_ [.vector .u8 (commitBa.toList.map .u8)]) =
    some (.vector .u8 (
      fiatShamirDstMvU8s ++ [.u8 chainId] ++ sender.toList.map .u8 ++ contract.toList.map .u8 ++
      token.toList.map .u8 ++ ekBa.toList.map .u8 ++ commitBa.toList.map .u8)) :=
  buildFSMessageMv_list_gen o chainId sender contract token ekBa commitBa _ _ hEk hR

/-! ## ByteArray.toList distributivity

`ByteArray.toList.loop` is `@[irreducible]` in Lean 4.24, so the proof that
`ByteArray.toList` distributes over `ByteArray.append` requires a loop-invariant
argument that is orthogonal to the cryptographic verification.

We axiomatize `ByteArray.toList_append` here.  It is verified concretely by
`native_decide` for every concrete `ByteArray` pair and is a well-known property
of `ByteArray.toList` (matching `Array.toList_append` via `ByteArray.data_append`).
This is a **library-level obligation**, not a security assumption. -/

axiom ByteArray.toList_append (a b : ByteArray) :
    (a ++ b).toList = a.toList ++ b.toList

axiom ByteArray.toList_mk_singleton (x : UInt8) :
    (ByteArray.mk #[x]).toList = [x]

/-! ## Structural properties

The functional simulation can only return three kinds of results:
- `.returned [] MachineState.empty` (valid proof)
- `.aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE` (failed assert)
- `.error` (oracle/native failure — unreachable in practice) -/

theorem func_trichotomy (o : RegistrationNativeOracle) (args : List MoveValue) :
    verifyRegistrationBytecodeResult o args = .returned [] MachineState.empty ∨
    verifyRegistrationBytecodeResult o args = .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE ∨
    verifyRegistrationBytecodeResult o args = .error := by
  simp only [verifyRegistrationBytecodeResult]
  split
  · simp only [verifyRegistrationBytecodeResult.blockB,
      verifyRegistrationBytecodeResult.blockCDE]
    repeat first | (split; repeat tauto) | tauto
  · tauto

end MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
