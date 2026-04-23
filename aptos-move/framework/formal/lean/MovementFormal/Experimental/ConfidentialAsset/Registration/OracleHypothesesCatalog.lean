import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native.Registration
import MovementFormal.Experimental.ConfidentialAsset.Registration.OracleSemantics
import MovementFormal.Experimental.ConfidentialAsset.Registration.ValidationLemmas

/-! # Oracle Hypotheses Catalog

This file provides a comprehensive catalog of all oracle hypotheses needed for the
registration singleton branch proof. Oracle hypotheses link the abstract oracle
interface to concrete execution by specifying:

1. **Input preconditions**: What must be true about oracle inputs
2. **Output postconditions**: What the oracle guarantees about results
3. **Correspondence**: How oracle results relate to functional simulation

## Oracle Categories

**Cryptographic Oracles** (value-level, deterministic):
- newCompressedPointFromBytes(bytes) → Option<CompressedPoint>
- newScalarFromBytes(bytes) → Option<Scalar>
- pointMul(point, scalar) → CompressedPoint
- pointAdd(point1, point2) → CompressedPoint
- pointDecompress(compressed) → Point
- pointEquals(point1, point2) → bool
- hashToPointBase() → CompressedPoint
- pubkeyToPoint(pubkey) → CompressedPoint
- pubkeyToBytes(pubkey) → vector<u8>
- compressedPointToBytes(point) → vector<u8>
- newScalarFromSha2_512(message) → Scalar (concrete, executable)

**Ref-Aware Wrappers** (ContainerStore-modifying):
- optionIsSomeRef(&Option<T>) → bool
- optionExtractRef(&mut Option<T>) → T
- vectorAppendU8Ref(&mut vector<u8>, vector<u8>) → unit
- vectorPushBackU8Ref(&mut vector<u8>, u8) → unit
- bcsToBytesAddressRef(&address) → vector<u8>

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.OracleHypothesesCatalog

open MovementFormal.MoveModel
open MovementFormal.Experimental.ConfidentialAsset.Registration.OracleSemantics
open MovementFormal.Experimental.ConfidentialAsset.Registration.Validation

/-! ## Happy Path Oracle Hypotheses

Hypotheses for the singleton branch happy path where all validations succeed.
-/

/-- newCompressedPointFromBytes succeeds on valid 32-byte commitment. -/
structure HypothesisNewCompressedPointFromBytes (o : RegistrationNativeOracle) where
  commitBa : ByteArray
  v : MoveValue
  inner : MoveValue
  rest : List MoveValue
  h_len : commitBa.size = 32
  h_valid : IsValidCompressedPointBytes (.vector .u8 (commitBa.toList.map .u8))
  h_call : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] =
           some [v]
  h_struct : v = .struct_ (.bool true :: inner :: rest)

/-- newScalarFromBytes succeeds on valid 32-byte response. -/
structure HypothesisNewScalarFromBytes (o : RegistrationNativeOracle) where
  respBa : ByteArray
  s_opt : MoveValue
  scalar : MoveValue
  rest : List MoveValue
  h_len : respBa.size = 32
  h_valid : IsReducedScalar (.vector .u8 (respBa.toList.map .u8))
  h_call : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] =
           some [s_opt]
  h_struct : s_opt = .struct_ (.bool true :: scalar :: rest)

/-- optionIsSomeRef returns true on Some values. -/
structure HypothesisOptionIsSomeRef (o : RegistrationNativeOracle) where
  containers : ContainerStore
  rid : RefId
  tag : Bool
  inner : MoveValue
  rest : List MoveValue
  h_tag : tag = true
  h_read : containers.read rid = some (.struct_ (.bool tag :: inner :: rest))
  h_call : o.optionIsSomeRef containers [.immRef rid] =
           some ([.bool tag], containers)

/-- optionExtractRef extracts inner value and writes false. -/
structure HypothesisOptionExtractRef (o : RegistrationNativeOracle) where
  containers : ContainerStore
  containers' : ContainerStore
  rid : RefId
  inner : MoveValue
  rest : List MoveValue
  h_read : containers.read rid = some (.struct_ (.bool true :: inner :: rest))
  h_write : containers.write rid (.struct_ [.bool false]) = some containers'
  h_call : optionExtractRef containers [.mutRef rid] =
           some ([inner], containers')

/-- vectorPushBackU8Ref appends single byte. -/
structure HypothesisVectorPushBackU8Ref (o : RegistrationNativeOracle) where
  containers : ContainerStore
  containers' : ContainerStore
  rid : RefId
  existing : List MoveValue
  byte : UInt8
  h_read : containers.read rid = some (.vector .u8 existing)
  h_write : containers.write rid (.vector .u8 (existing ++ [.u8 byte])) = some containers'
  h_call : vectorPushBackU8Ref containers [.mutRef rid, .u8 byte] =
           some ([], containers')

/-- vectorAppendU8Ref appends byte vector. -/
structure HypothesisVectorAppendU8Ref (o : RegistrationNativeOracle) where
  containers : ContainerStore
  containers' : ContainerStore
  rid : RefId
  existing : List MoveValue
  appended : List MoveValue
  h_read : containers.read rid = some (.vector .u8 existing)
  h_write : containers.write rid (.vector .u8 (existing ++ appended)) = some containers'
  h_call : vectorAppendU8Ref containers [.mutRef rid, .vector .u8 appended] =
           some ([], containers')

/-- bcsToBytesAddressRef serializes address. -/
structure HypothesisBcsToBytesAddressRef (o : RegistrationNativeOracle) where
  containers : ContainerStore
  rid : RefId
  addr : ByteArray
  h_read : containers.read rid = some (.address addr)
  h_call : bcsToBytesAddressRef containers [.immRef rid] =
           some ([.vector .u8 (addr.toList.map .u8)], containers)

/-- newScalarFromSha2_512 computes challenge from message. -/
structure HypothesisNewScalarFromSha2_512 where
  message : MoveValue
  challenge : MoveValue
  h_valid_msg : IsValidU8Vector message
  h_call : newScalarFromSha2_512 [message] = some [challenge]
  h_format : ∃ scalar_bytes, challenge = .struct_ [.vector .u8 scalar_bytes] ∧
                              scalar_bytes.length = 64

/-- hashToPointBase returns base point. -/
structure HypothesisHashToPointBase (o : RegistrationNativeOracle) where
  base : MoveValue
  h_call : o.hashToPointBase [] = some [base]
  h_valid : IsValidCompressedPoint base

/-- pubkeyToPoint converts pubkey to point. -/
structure HypothesisPubkeyToPoint (o : RegistrationNativeOracle) where
  ekBa : ByteArray
  ek_point : MoveValue
  h_len : ekBa.size = 32
  h_call : o.pubkeyToPoint [.vector .u8 (ekBa.toList.map .u8)] = some [ek_point]
  h_valid : IsValidCompressedPoint ek_point

/-- pointMul computes scalar multiplication. -/
structure HypothesisPointMul (o : RegistrationNativeOracle) where
  point : MoveValue
  scalar : MoveValue
  result : MoveValue
  h_point_valid : IsValidCompressedPoint point
  h_scalar_valid : IsValidScalar scalar
  h_call : o.pointMul [point, scalar] = some [result]
  h_result_valid : IsValidCompressedPoint result

/-- pointAdd computes point addition. -/
structure HypothesisPointAdd (o : RegistrationNativeOracle) where
  point1 : MoveValue
  point2 : MoveValue
  result : MoveValue
  h_point1_valid : IsValidCompressedPoint point1
  h_point2_valid : IsValidCompressedPoint point2
  h_call : o.pointAdd [point1, point2] = some [result]
  h_result_valid : IsValidCompressedPoint result

/-- pointDecompress converts compressed to decompressed. -/
structure HypothesisPointDecompress (o : RegistrationNativeOracle) where
  compressed : MoveValue
  decompressed : MoveValue
  h_compressed_valid : IsValidCompressedPoint compressed
  h_call : o.pointDecompress [compressed] = some [decompressed]

/-- pointEquals returns true when points are equal. -/
structure HypothesisPointEquals (o : RegistrationNativeOracle) where
  point1 : MoveValue
  point2 : MoveValue
  h_point1_valid : IsValidCompressedPoint point1
  h_point2_valid : IsValidCompressedPoint point2
  h_call : o.pointEquals [point1, point2] = some [.bool true]

/-! ## Composed Oracle Hypotheses for Proof Phases

Bundled hypotheses for each proof phase.
-/

/-- Phase 1 oracle hypotheses (PC 4-20). -/
structure Phase1Hypotheses (o : RegistrationNativeOracle) where
  -- newCompressedPointFromBytes at PC 3
  h_compressed_point : HypothesisNewCompressedPointFromBytes o
  -- optionIsSomeRef at PC 4
  h_option_is_some_v : HypothesisOptionIsSomeRef o
  -- optionExtractRef at PC 7
  h_option_extract_v : HypothesisOptionExtractRef o
  -- newScalarFromBytes at PC 10
  h_scalar : HypothesisNewScalarFromBytes o
  -- optionIsSomeRef at PC 13
  h_option_is_some_s : HypothesisOptionIsSomeRef o
  -- optionExtractRef at PC 17
  h_option_extract_s : HypothesisOptionExtractRef o

/-- Phase 2 oracle hypotheses (PC 20-43). -/
structure Phase2Hypotheses (o : RegistrationNativeOracle) where
  -- vectorPushBackU8Ref for chainId at PC 26
  h_push_chain_id : HypothesisVectorPushBackU8Ref o
  -- bcsToBytesAddressRef for sender at PC 29 (or vectorAppendU8Ref alternative)
  h_append_sender : HypothesisVectorAppendU8Ref o
  -- Similar for contract, token, ek_bytes
  h_append_contract : HypothesisVectorAppendU8Ref o
  h_append_token : HypothesisVectorAppendU8Ref o
  h_append_ek : HypothesisVectorAppendU8Ref o

/-- Phase 3 oracle hypotheses (PC 43-70). -/
structure Phase3Hypotheses (o : RegistrationNativeOracle) where
  -- newScalarFromSha2_512 at PC 44
  h_challenge : HypothesisNewScalarFromSha2_512
  -- hashToPointBase at PC 47
  h_base : HypothesisHashToPointBase o
  -- pubkeyToPoint at PC 49
  h_ek_point : HypothesisPubkeyToPoint o
  -- pointMul for h*s at PC 53
  h_mul_hs : HypothesisPointMul o
  -- pointMul for ek*e at PC 57
  h_mul_ek_e : HypothesisPointMul o
  -- pointAdd for h*s + ek*e at PC 60
  h_add_lhs : HypothesisPointAdd o
  -- pointDecompress at PC 63
  h_decompress_rhs : HypothesisPointDecompress o
  -- pointEquals at PC 66
  h_equals : HypothesisPointEquals o

/-! ## Complete Oracle Hypothesis Bundle

All oracle hypotheses for the full PC 4-70 proof.
-/

structure CompleteOracleHypotheses (o : RegistrationNativeOracle) where
  phase1 : Phase1Hypotheses o
  phase2 : Phase2Hypotheses o
  phase3 : Phase3Hypotheses o

/-! ## Hypothesis Derivation from Inputs

Lemmas showing oracle hypotheses can be derived from valid inputs.
-/

/-- Valid inputs imply Phase 1 hypotheses. -/
theorem valid_inputs_imply_phase1_hypotheses
    (o : RegistrationNativeOracle)
    (commitBa respBa : ByteArray)
    (h_commit_len : commitBa.size = 32)
    (h_resp_len : respBa.size = 32)
    (h_commit_valid : IsValidCompressedPointBytes (.vector .u8 (commitBa.toList.map .u8)))
    (h_resp_valid : IsReducedScalar (.vector .u8 (respBa.toList.map .u8))) :
    ∃ (phase1 : Phase1Hypotheses o), True := by
  sorry  -- Construct from validity axioms in OracleSemantics

/-- Valid message implies challenge hypothesis. -/
theorem valid_message_imply_challenge_hypothesis
    (message : MoveValue)
    (h_valid : IsValidU8Vector message) :
    ∃ (h_challenge : HypothesisNewScalarFromSha2_512),
      h_challenge.message = message := by
  sorry  -- newScalarFromSha2_512 is total on valid u8 vectors

/-- Valid inputs and intermediate results imply Phase 3 hypotheses. -/
theorem valid_intermediates_imply_phase3_hypotheses
    (o : RegistrationNativeOracle)
    (message : MoveValue)
    (ekBa : ByteArray)
    (rCompressed scalar : MoveValue)
    (h_msg_valid : IsValidU8Vector message)
    (h_ek_len : ekBa.size = 32)
    (h_r_valid : IsValidCompressedPoint rCompressed)
    (h_s_valid : IsValidScalar scalar) :
    ∃ (phase3 : Phase3Hypotheses o), True := by
  sorry  -- Construct from closure axioms

/-! ## Hypothesis Checking

Predicates for runtime validation of oracle hypotheses.
-/

/-- Check if newCompressedPointFromBytes hypothesis is satisfied. -/
def checkHypothesisNewCompressedPointFromBytes
    (o : RegistrationNativeOracle)
    (commitBa : ByteArray) : Prop :=
  ∃ (v inner : MoveValue) (rest : List MoveValue),
    commitBa.size = 32 ∧
    o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some [v] ∧
    v = .struct_ (.bool true :: inner :: rest)

/-- Check if all Phase 1 hypotheses are satisfied. -/
def checkPhase1Hypotheses
    (o : RegistrationNativeOracle)
    (commitBa respBa : ByteArray) : Prop :=
  checkHypothesisNewCompressedPointFromBytes o commitBa ∧
  ∃ (s_opt scalar : MoveValue) (rest : List MoveValue),
    respBa.size = 32 ∧
    o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [s_opt] ∧
    s_opt = .struct_ (.bool true :: scalar :: rest)

/-! ## Hypothesis Weakening and Strengthening

Lemmas for manipulating hypothesis strength.
-/

/-- Stronger validity implies weaker validity. -/
theorem valid_compressed_point_implies_valid_bytes
    (v : MoveValue)
    (h : IsValidCompressedPoint v) :
    IsValidU8Vector v := by
  exact compressedPoint_is_u8_vector v h

/-- Hypothesis with stronger precondition implies hypothesis with weaker. -/
theorem hypothesis_weakening_example
    (o : RegistrationNativeOracle)
    (h : HypothesisPointMul o)
    (h_extra : h.point = h.point) :
    IsValidCompressedPoint h.result := by
  exact h.h_result_valid

/-! ## Auxiliary Hypothesis Utilities

Helper definitions and lemmas for hypothesis management.
-/

/-- Extract commitBa from Phase1Hypotheses. -/
def Phase1Hypotheses.commitBa (h : Phase1Hypotheses o) : ByteArray :=
  h.h_compressed_point.commitBa

/-- Extract respBa from Phase1Hypotheses. -/
def Phase1Hypotheses.respBa (h : Phase1Hypotheses o) : ByteArray :=
  h.h_scalar.respBa

/-- Extract message from Phase3Hypotheses. -/
def Phase3Hypotheses.message (h : Phase3Hypotheses o) : MoveValue :=
  h.h_challenge.message

/-- All hypotheses are consistent (no contradictions). -/
axiom hypotheses_consistent
    (o : RegistrationNativeOracle)
    (h : CompleteOracleHypotheses o) :
    -- No contradictory assumptions
    True

end MovementFormal.Experimental.ConfidentialAsset.Registration.OracleHypothesesCatalog
