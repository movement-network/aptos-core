import AptosFormal.Move.Step
import AptosFormal.Move.Programs.Registration
import AptosFormal.Experimental.ConfidentialAsset.Registration.VerifyMath
import AptosFormal.Experimental.ConfidentialAsset.Registration.TranscriptAlignment

/-!
# Eval smoke tests for the **real** `verify_registration_proof` bytecode

Runs `eval` on the 83-instruction bytecode transcribed from the `movement` v7.4
compiler output, using a concrete `RegistrationNativeOracle` with symbolic
integer-tagged `MoveValue.u64` values for points/scalars.

Because the real bytecode passes `ek` as `&CompressedPubkey` (an immutable
reference), the initial `MachineState` must have the ek value pre-allocated
in the `ContainerStore` and the arg list must contain `.immRef ekRefId`.

Tests:
1. **Valid proof**: `eval` returns `ExecResult.returned []` (success, void return)
2. **Invalid proof**: `eval` returns `ExecResult.aborted 65537`
-/

namespace AptosFormal.Experimental.ConfidentialAsset.Registration.BytecodeSmoke

open AptosFormal.Move
open AptosFormal.Move.Native.Registration
open AptosFormal.Move.Programs.Registration
open RegistrationTranscriptAlignment

/-! ## Golden constants -/

private def basepointBytes : List MoveValue :=
  [0xe2, 0xf2, 0xae, 0x0a, 0x6a, 0xbc, 0x4e, 0x71, 0xa8, 0x84, 0xa9, 0x61, 0xc5, 0x00, 0x51, 0x5f,
   0x58, 0xe3, 0x0b, 0x6a, 0xa5, 0x82, 0xdd, 0x8d, 0xb6, 0xa6, 0x59, 0x45, 0xe0, 0x8d, 0x2d, 0x76
  ].map MoveValue.u8

private def basepointVec : MoveValue := .vector .u8 basepointBytes

private def ekStruct : MoveValue := .struct_ [basepointVec]

private def someCompressed : MoveValue :=
  .struct_ [.bool true, .struct_ [basepointVec]]

private def noneCompressed : MoveValue :=
  .struct_ [.bool false]

private def validResponseBytes : List MoveValue :=
  (List.replicate 32 (0x01 : UInt8)).map MoveValue.u8

private def validResponseVec : MoveValue := .vector .u8 validResponseBytes

private def validScalarStruct : MoveValue :=
  .struct_ [.vector .u8 validResponseBytes]

private def someScalar : MoveValue :=
  .struct_ [.bool true, validScalarStruct]

private def addr0x1 : ByteArray := bcsAddress0x1
private def addr0x2 : ByteArray := bcsAddress0x2
private def addr0x3 : ByteArray := bcsAddress0x3

/-! ## Symbolic point IDs -/

private def pointH : MoveValue := .u64 1000
private def pointEk : MoveValue := .u64 1001
private def pointRhs : MoveValue := .u64 1002
private def pointHs : MoveValue := .u64 1003
private def pointEkE : MoveValue := .u64 1004
private def pointLhs : MoveValue := .u64 1005

/-! ## Golden oracle for valid-proof scenario

Oracle functions operate on **values** (not references). The `nativeRef`
wrappers in the module environment dereference args from the `ContainerStore`
before calling these. -/

private def goldenOracle (validProof : Bool) : RegistrationNativeOracle where
  newCompressedPointFromBytes := fun args =>
    match args with
    | [.vector .u8 bs] =>
      if bs == basepointBytes then some [someCompressed]
      else some [noneCompressed]
    | _ => none

  newScalarFromBytes := fun args =>
    match args with
    | [.vector .u8 bs] =>
      if bs == validResponseBytes then some [someScalar]
      else some [.struct_ [.bool false]]
    | _ => none

  compressedPointToBytes := fun args =>
    match args with
    | [.struct_ [.vector .u8 bs]] => some [.vector .u8 bs]
    | _ => none

  hashToPointBase := fun args =>
    match args with
    | [] => some [pointH]
    | _ => none

  pointDecompress := fun args =>
    match args with
    | [.struct_ [.vector .u8 _]] => some [pointRhs]
    | _ => none

  pointMul := fun args =>
    match args with
    | [pt, _sc] =>
      if pt == pointH then some [pointHs]
      else if pt == pointEk then some [pointEkE]
      else none
    | _ => none

  pointAdd := fun args =>
    match args with
    | [a, b] =>
      if a == pointHs && b == pointEkE then some [pointLhs]
      else none
    | _ => none

  pointEquals := fun args =>
    match args with
    | [a, b] =>
      if a == pointLhs && b == pointRhs then
        some [.bool validProof]
      else none
    | _ => none

  pubkeyToBytes := fun args =>
    match args with
    | [.struct_ [.vector .u8 bs]] => some [.vector .u8 bs]
    | _ => none

  pubkeyToPoint := fun args =>
    match args with
    | [.struct_ [.vector .u8 _]] => some [pointEk]
    | _ => none

/-! ## Initial state: ek pre-allocated in ContainerStore

In the real bytecode, `ek` is `&CompressedPubkey` — an immutable reference
passed by the caller. We model this by pre-allocating the ek value in the
ContainerStore and passing `.immRef 0` as the argument. -/

private def initMs : MachineState :=
  let (cs, _) := ContainerStore.empty.alloc ekStruct
  MachineState.ofContainers cs

private def goldenArgs : List MoveValue := [
  .u8 9,                               -- chain_id
  .address addr0x1,                    -- sender
  .address addr0x2,                    -- contract_address
  .immRef 0,                           -- ek: &CompressedPubkey (ref to CS cell 0)
  .address addr0x3,                    -- token_address
  basepointVec,                        -- commitment_bytes (R)
  validResponseVec                     -- response_bytes
]

/-! ## Result predicates -/

private def isReturnedEmpty : ExecResult → Bool
  | .returned [] _ => true
  | _ => false

private def isAbortedWith (code : UInt64) : ExecResult → Bool
  | .aborted c => c == code
  | _ => false

/-! ## Eval smoke: valid proof → success (void return) -/

private def validEnv : ModuleEnv := registrationModuleEnv (goldenOracle true)

/-- Eval the real 83-instruction `verify_registration_proof` bytecode on golden
    inputs with a valid-proof oracle. Expects `returned []` (success, void). -/
theorem eval_verify_registration_proof_valid :
    isReturnedEmpty (eval validEnv verifyRegistrationProofIdx goldenArgs 200 initMs) = true := by
  native_decide

/-! ## Eval smoke: invalid proof → abort 65537 -/

private def invalidEnv : ModuleEnv := registrationModuleEnv (goldenOracle false)

/-- Eval the real bytecode with an invalid-proof oracle.
    Expects `aborted 65537` (`ESIGMA_PROTOCOL_VERIFY_FAILED`). -/
theorem eval_verify_registration_proof_invalid :
    isAbortedWith ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE
      (eval invalidEnv verifyRegistrationProofIdx goldenArgs 200 initMs) = true := by
  native_decide

end AptosFormal.Experimental.ConfidentialAsset.Registration.BytecodeSmoke
