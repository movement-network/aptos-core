import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.Programs.Registration
import MovementFormal.Experimental.ConfidentialAsset.Registration.TranscriptAlignment
import MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv

/-!
# Bytecode eval on real VM wire data (native_decide proofs)

**Source:** `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`; VM wire / JSON `aptos-move/framework/formal/difftest/`.

Isolated file with minimal imports so `native_decide` can build
the `Decidable` instance without interference from heavy imports
(Operational/RegistrationDifftestOracle bring in Mathlib ZMod).

Contains three `native_decide` proofs:
1. `eval` of the bytecode returns successfully on difftest wire data
2. `verifyRegistrationBytecodeResult` (functional simulation) agrees with `eval`
3. The functional simulation produces the correct result independently
-/

set_option maxRecDepth 131072

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeDifftestEval

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.MoveModel.Programs.Registration
open RegistrationTranscriptAlignment

/-! ## Wire bytes as MoveValue lists (dk=42, k=9999 roundtrip trace) -/

def difftestEkMoveBytes : List MoveValue :=
  [166, 105, 246, 130, 61, 48, 217, 70, 117, 78, 136, 118, 239, 145, 118, 242,
   104, 118, 83, 176, 52, 109, 234, 2, 109, 19, 71, 241, 151, 86, 172, 77
  ].map MoveValue.u8

def difftestCommitmentMoveBytes : List MoveValue :=
  [178, 104, 37, 61, 34, 169, 102, 130, 104, 9, 78, 17, 179, 101, 239, 224,
   83, 20, 179, 191, 85, 232, 246, 129, 208, 167, 97, 36, 197, 43, 23, 116
  ].map MoveValue.u8

def difftestResponseMoveBytes : List MoveValue :=
  [34, 212, 81, 110, 48, 73, 236, 104, 246, 40, 69, 83, 11, 209, 226, 161,
   218, 0, 212, 201, 196, 232, 2, 22, 166, 106, 81, 152, 241, 191, 129, 10
  ].map MoveValue.u8

/-! ## Symbolic point IDs -/

private def dtPtH   : MoveValue := .u64 3000
private def dtPtEk  : MoveValue := .u64 3001
private def dtPtHs  : MoveValue := .u64 3002
private def dtPtEkE : MoveValue := .u64 3003
private def dtPtLhs : MoveValue := .u64 3004
private def dtPtRhs : MoveValue := .u64 3005

/-! ## Concrete oracle (trace replay) -/

def difftestNativeOracle : RegistrationNativeOracle where
  newCompressedPointFromBytes := fun args =>
    match args with
    | [.vector .u8 bs] =>
      if bs == difftestCommitmentMoveBytes then
        some [.struct_ [.bool true, .struct_ [.vector .u8 bs]]]
      else some [.struct_ [.bool false]]
    | _ => none

  newScalarFromBytes := fun args =>
    match args with
    | [.vector .u8 bs] =>
      if bs == difftestResponseMoveBytes then
        some [.struct_ [.bool true, .struct_ [.vector .u8 bs]]]
      else some [.struct_ [.bool false]]
    | _ => none

  compressedPointToBytes := fun args =>
    match args with
    | [.struct_ [.vector .u8 bs]] => some [.vector .u8 bs]
    | _ => none

  hashToPointBase := fun args =>
    match args with
    | [] => some [dtPtH]
    | _ => none

  pointDecompress := fun args =>
    match args with
    | [.struct_ [.vector .u8 _]] => some [dtPtRhs]
    | _ => none

  pointMul := fun args =>
    match args with
    | [pt, _sc] =>
      if pt == dtPtH then some [dtPtHs]
      else if pt == dtPtEk then some [dtPtEkE]
      else none
    | _ => none

  pointAdd := fun args =>
    match args with
    | [a, b] =>
      if a == dtPtHs && b == dtPtEkE then some [dtPtLhs]
      else none
    | _ => none

  pointEquals := fun args =>
    match args with
    | [a, b] =>
      if a == dtPtLhs && b == dtPtRhs then some [.bool true]
      else none
    | _ => none

  pubkeyToBytes := fun args =>
    match args with
    | [.struct_ [.vector .u8 bs]] => some [.vector .u8 bs]
    | _ => none

  pubkeyToPoint := fun args =>
    match args with
    | [.struct_ [.vector .u8 _]] => some [dtPtEk]
    | _ => none

private def difftestEkStruct : MoveValue := .struct_ [.vector .u8 difftestEkMoveBytes]

def difftestInitMs : MachineState :=
  let (cs, _) := ContainerStore.empty.alloc difftestEkStruct
  MachineState.ofContainers cs

def difftestArgs : List MoveValue := [
  .u8 9,
  .address bcsAddress0x1,
  .address bcsAddress0x2,
  .immRef 0,                           -- ek: &CompressedPubkey (ref to CS cell 0)
  .address bcsAddress0x3,
  .vector .u8 difftestCommitmentMoveBytes,
  .vector .u8 difftestResponseMoveBytes
]

def difftestEnv : ModuleEnv := registrationModuleEnv difftestNativeOracle

def isReturnedEmpty : ExecResult → Bool
  | .returned [] _ => true
  | _ => false

def isAbortedWith (code : UInt64) : ExecResult → Bool
  | .aborted c => c == code
  | _ => false

/-! ## L2: eval returns successfully -/

theorem eval_difftest_registration_roundtrip :
    isReturnedEmpty (eval difftestEnv verifyRegistrationProofIdx difftestArgs 200 difftestInitMs) = true := by
  native_decide

/-! ## L1.5: Functional simulation (value args)

The functional sim uses value semantics — it passes ek as a struct value,
not a reference. For the `func ≡ eval` comparison, we use **value args**
(struct for ek, no initMs) plus `.dropMs` to strip the container store
populated by the bytecode's reference operations. -/

def difftestValArgs : List MoveValue := [
  .u8 9,
  .address bcsAddress0x1,
  .address bcsAddress0x2,
  difftestEkStruct,                    -- ek: CompressedPubkey value (not ref)
  .address bcsAddress0x3,
  .vector .u8 difftestCommitmentMoveBytes,
  .vector .u8 difftestResponseMoveBytes
]

open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim in
open MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv in
theorem func_eq_eval_difftest_val :
    verifyRegistrationBytecodeResult difftestNativeOracle difftestValArgs ==
      (eval difftestEnv verifyRegistrationProofIdx difftestValArgs 200 MachineState.empty).dropMs := by
  native_decide

open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim in
theorem func_difftest_returns :
    verifyRegistrationBytecodeResult difftestNativeOracle difftestValArgs ==
      .returned [] MachineState.empty := by
  native_decide

/-! -----------------------------------------------------------------------
## Trace 2: golden2 scenario (chain_id=42, @0x10/@0x20/@0x30, basepoint ek/R)

Different addresses, chain ID, and key material from trace 1. The oracle
uses distinct symbolic point IDs (4000-series) to avoid any accidental
collision with trace 1. This exercises a completely different tagged-hash
computation path.
----------------------------------------------------------------------- -/

private def basepointMoveBytes : List MoveValue :=
  [0xe2, 0xf2, 0xae, 0x0a, 0x6a, 0xbc, 0x4e, 0x71, 0xa8, 0x84, 0xa9, 0x61,
   0xc5, 0x00, 0x51, 0x5f, 0x58, 0xe3, 0x0b, 0x6a, 0xa5, 0x82, 0xdd, 0x8d,
   0xb6, 0xa6, 0x59, 0x45, 0xe0, 0x8d, 0x2d, 0x76
  ].map MoveValue.u8

private def trace2ResponseMoveBytes : List MoveValue :=
  [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c,
   0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
   0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x01
  ].map MoveValue.u8

private def t2PtH   : MoveValue := .u64 4000
private def t2PtEk  : MoveValue := .u64 4001
private def t2PtHs  : MoveValue := .u64 4002
private def t2PtEkE : MoveValue := .u64 4003
private def t2PtLhs : MoveValue := .u64 4004
private def t2PtRhs : MoveValue := .u64 4005

def trace2NativeOracle : RegistrationNativeOracle where
  newCompressedPointFromBytes := fun args =>
    match args with
    | [.vector .u8 bs] =>
      if bs == basepointMoveBytes then
        some [.struct_ [.bool true, .struct_ [.vector .u8 bs]]]
      else some [.struct_ [.bool false]]
    | _ => none

  newScalarFromBytes := fun args =>
    match args with
    | [.vector .u8 bs] =>
      if bs == trace2ResponseMoveBytes then
        some [.struct_ [.bool true, .struct_ [.vector .u8 bs]]]
      else some [.struct_ [.bool false]]
    | _ => none

  compressedPointToBytes := fun args =>
    match args with
    | [.struct_ [.vector .u8 bs]] => some [.vector .u8 bs]
    | _ => none

  hashToPointBase := fun args =>
    match args with
    | [] => some [t2PtH]
    | _ => none

  pointDecompress := fun args =>
    match args with
    | [.struct_ [.vector .u8 _]] => some [t2PtRhs]
    | _ => none

  pointMul := fun args =>
    match args with
    | [pt, _sc] =>
      if pt == t2PtH then some [t2PtHs]
      else if pt == t2PtEk then some [t2PtEkE]
      else none
    | _ => none

  pointAdd := fun args =>
    match args with
    | [a, b] =>
      if a == t2PtHs && b == t2PtEkE then some [t2PtLhs]
      else none
    | _ => none

  pointEquals := fun args =>
    match args with
    | [a, b] =>
      if a == t2PtLhs && b == t2PtRhs then some [.bool true]
      else none
    | _ => none

  pubkeyToBytes := fun args =>
    match args with
    | [.struct_ [.vector .u8 bs]] => some [.vector .u8 bs]
    | _ => none

  pubkeyToPoint := fun args =>
    match args with
    | [.struct_ [.vector .u8 _]] => some [t2PtEk]
    | _ => none

private def trace2EkStruct : MoveValue := .struct_ [.vector .u8 basepointMoveBytes]

private def trace2InitMs : MachineState :=
  let (cs, _) := ContainerStore.empty.alloc trace2EkStruct
  MachineState.ofContainers cs

def trace2Args : List MoveValue := [
  .u8 42,
  .address bcsAddress0x10,
  .address bcsAddress0x20,
  .immRef 0,                           -- ek: &CompressedPubkey
  .address bcsAddress0x30,
  .vector .u8 basepointMoveBytes,
  .vector .u8 trace2ResponseMoveBytes
]

def trace2Env : ModuleEnv := registrationModuleEnv trace2NativeOracle

/-! ## Trace 2: L2 eval -/

theorem eval_trace2_registration_roundtrip :
    isReturnedEmpty (eval trace2Env verifyRegistrationProofIdx trace2Args 200 trace2InitMs) = true := by
  native_decide

/-! ## Trace 2: L1.5 functional sim (value args) -/

def trace2ValArgs : List MoveValue := [
  .u8 42,
  .address bcsAddress0x10,
  .address bcsAddress0x20,
  trace2EkStruct,                      -- ek: CompressedPubkey value (not ref)
  .address bcsAddress0x30,
  .vector .u8 basepointMoveBytes,
  .vector .u8 trace2ResponseMoveBytes
]

open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim in
open MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv in
theorem func_eq_eval_trace2_val :
    verifyRegistrationBytecodeResult trace2NativeOracle trace2ValArgs ==
      (eval trace2Env verifyRegistrationProofIdx trace2ValArgs 200 MachineState.empty).dropMs := by
  native_decide

open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim in
theorem func_trace2_returns :
    verifyRegistrationBytecodeResult trace2NativeOracle trace2ValArgs ==
      .returned [] MachineState.empty := by
  native_decide

/-! ## Trace 2: abort case (bad commitment bytes)

Exercises the `.aborted` path: same oracle but with wrong commitment bytes.
The oracle's `newCompressedPointFromBytes` returns `(false)`, causing abort. -/

def trace2AbortArgs : List MoveValue := [
  .u8 42,
  .address bcsAddress0x10,
  .address bcsAddress0x20,
  .immRef 0,                           -- ek: &CompressedPubkey
  .address bcsAddress0x30,
  .vector .u8 ([0xff, 0xff].map MoveValue.u8),
  .vector .u8 trace2ResponseMoveBytes
]

theorem eval_trace2_abort :
    isAbortedWith ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE
      (eval trace2Env verifyRegistrationProofIdx trace2AbortArgs 200 trace2InitMs) = true := by
  native_decide

def trace2AbortValArgs : List MoveValue := [
  .u8 42,
  .address bcsAddress0x10,
  .address bcsAddress0x20,
  trace2EkStruct,                      -- ek: CompressedPubkey value (not ref)
  .address bcsAddress0x30,
  .vector .u8 ([0xff, 0xff].map MoveValue.u8),
  .vector .u8 trace2ResponseMoveBytes
]

open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim in
theorem func_trace2_aborts :
    verifyRegistrationBytecodeResult trace2NativeOracle trace2AbortValArgs ==
      .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE := by
  native_decide

/-! ## Trace 2: scalar-stage abort (bad response bytes)

Valid commitment bytes (basepoint) but bad scalar bytes — oracle's
`newScalarFromBytes` returns `(false)`, exercising abort **path 2**. -/

def trace2ScalarAbortArgs : List MoveValue := [
  .u8 42,
  .address bcsAddress0x10,
  .address bcsAddress0x20,
  .immRef 0,                           -- ek: &CompressedPubkey
  .address bcsAddress0x30,
  .vector .u8 basepointMoveBytes,
  .vector .u8 ([0xaa, 0xbb].map MoveValue.u8)
]

theorem eval_trace2_scalar_abort :
    isAbortedWith ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE
      (eval trace2Env verifyRegistrationProofIdx trace2ScalarAbortArgs 200 trace2InitMs) = true := by
  native_decide

def trace2ScalarAbortValArgs : List MoveValue := [
  .u8 42,
  .address bcsAddress0x10,
  .address bcsAddress0x20,
  trace2EkStruct,                      -- ek: CompressedPubkey value (not ref)
  .address bcsAddress0x30,
  .vector .u8 basepointMoveBytes,
  .vector .u8 ([0xaa, 0xbb].map MoveValue.u8)
]

open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim in
theorem func_trace2_scalar_aborts :
    verifyRegistrationBytecodeResult trace2NativeOracle trace2ScalarAbortValArgs ==
      .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE := by
  native_decide

/-! ## Trace 2: pointEquals-false abort (valid parse, bad proof)

Valid commitment (basepoint), valid scalar (trace2Response), but oracle
returns `pointEquals = false`, exercising abort **path 3**. -/

private def t2PtFalseH   : MoveValue := .u64 5000
private def t2PtFalseEk  : MoveValue := .u64 5001
private def t2PtFalseHs  : MoveValue := .u64 5002
private def t2PtFalseEkE : MoveValue := .u64 5003
private def t2PtFalseLhs : MoveValue := .u64 5004
private def t2PtFalseRhs : MoveValue := .u64 5005

def trace2PointEqFalseOracle : RegistrationNativeOracle where
  newCompressedPointFromBytes := fun args =>
    match args with
    | [.vector .u8 bs] =>
      if bs == basepointMoveBytes then
        some [.struct_ [.bool true, .struct_ [.vector .u8 bs]]]
      else some [.struct_ [.bool false]]
    | _ => none

  newScalarFromBytes := fun args =>
    match args with
    | [.vector .u8 bs] =>
      if bs == trace2ResponseMoveBytes then
        some [.struct_ [.bool true, .struct_ [.vector .u8 bs]]]
      else some [.struct_ [.bool false]]
    | _ => none

  compressedPointToBytes := fun args =>
    match args with
    | [.struct_ [.vector .u8 bs]] => some [.vector .u8 bs]
    | _ => none

  hashToPointBase := fun args =>
    match args with
    | [] => some [t2PtFalseH]
    | _ => none

  pointDecompress := fun args =>
    match args with
    | [.struct_ [.vector .u8 _]] => some [t2PtFalseRhs]
    | _ => none

  pointMul := fun args =>
    match args with
    | [pt, _sc] =>
      if pt == t2PtFalseH then some [t2PtFalseHs]
      else if pt == t2PtFalseEk then some [t2PtFalseEkE]
      else none
    | _ => none

  pointAdd := fun args =>
    match args with
    | [a, b] =>
      if a == t2PtFalseHs && b == t2PtFalseEkE then some [t2PtFalseLhs]
      else none
    | _ => none

  pointEquals := fun args =>
    match args with
    | [a, b] =>
      if a == t2PtFalseLhs && b == t2PtFalseRhs then some [.bool false]
      else none
    | _ => none

  pubkeyToBytes := fun args =>
    match args with
    | [.struct_ [.vector .u8 bs]] => some [.vector .u8 bs]
    | _ => none

  pubkeyToPoint := fun args =>
    match args with
    | [.struct_ [.vector .u8 _]] => some [t2PtFalseEk]
    | _ => none

def trace2PointEqFalseEnv : ModuleEnv := registrationModuleEnv trace2PointEqFalseOracle

def trace2PointEqFalseArgs : List MoveValue := [
  .u8 42,
  .address bcsAddress0x10,
  .address bcsAddress0x20,
  .immRef 0,                           -- ek: &CompressedPubkey
  .address bcsAddress0x30,
  .vector .u8 basepointMoveBytes,
  .vector .u8 trace2ResponseMoveBytes
]

theorem eval_trace2_pointeq_false_abort :
    isAbortedWith ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE
      (eval trace2PointEqFalseEnv verifyRegistrationProofIdx trace2PointEqFalseArgs 200 trace2InitMs) = true := by
  native_decide

def trace2PointEqFalseValArgs : List MoveValue := [
  .u8 42,
  .address bcsAddress0x10,
  .address bcsAddress0x20,
  trace2EkStruct,                      -- ek: CompressedPubkey value (not ref)
  .address bcsAddress0x30,
  .vector .u8 basepointMoveBytes,
  .vector .u8 trace2ResponseMoveBytes
]

open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim in
theorem func_trace2_pointeq_false_aborts :
    verifyRegistrationBytecodeResult trace2PointEqFalseOracle trace2PointEqFalseValArgs ==
      .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE := by
  native_decide

end MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeDifftestEval
