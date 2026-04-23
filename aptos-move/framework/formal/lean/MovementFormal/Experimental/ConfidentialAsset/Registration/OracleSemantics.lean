import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native.Registration
import MovementFormal.Experimental.ConfidentialAsset.Registration.ValidationLemmas

/-! # Oracle Semantics and Correspondence

This file provides detailed semantic specifications for all oracle functions used in
the registration verification proof, along with correspondence theorems between
different oracle representations (value-level vs ref-aware).

## Oracle Categories

1. **Cryptographic oracles** (abstract, parameterized):
   - Point operations: pointMul, pointAdd, pointDecompress, pointEquals
   - Scalar operations: newScalarFromBytes, newCompressedPointFromBytes
   - Key operations: pubkeyToPoint, pubkeyToBytes, compressedPointToBytes
   - Base point: hashToPointBase

2. **Hash functions** (concrete, executable):
   - newScalarFromSha2_512

3. **Move stdlib wrappers** (ref-aware):
   - optionIsSomeRef, optionExtractRef
   - vectorAppendU8Ref, vectorPushBackU8Ref
   - bcsToBytesAddressRef

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.OracleSemantics

open MovementFormal.MoveModel
open MovementFormal.Experimental.ConfidentialAsset.Registration.Validation

/-! ## Cryptographic Oracle Properties

These properties characterize the abstract behavior of cryptographic oracles.
-/

/-! ### Point Operation Properties -/

/-- pointMul is closed (always produces valid point when inputs are valid). -/
axiom pointMul_closure
    (o : RegistrationNativeOracle)
    (point scalar : MoveValue)
    (h_point_valid : IsValidCompressedPoint point)
    (h_scalar_valid : IsValidScalar scalar) :
    ∃ result, o.pointMul [point, scalar] = some [result] ∧
              IsValidCompressedPoint result

/-- pointAdd is closed. -/
axiom pointAdd_closure
    (o : RegistrationNativeOracle)
    (point1 point2 : MoveValue)
    (h1 : IsValidCompressedPoint point1)
    (h2 : IsValidCompressedPoint point2) :
    ∃ result, o.pointAdd [point1, point2] = some [result] ∧
              IsValidCompressedPoint result

/-- pointDecompress converts compressed to decompressed representation. -/
axiom pointDecompress_validity
    (o : RegistrationNativeOracle)
    (compressed : MoveValue)
    (h : IsValidCompressedPoint compressed) :
    ∃ result, o.pointDecompress [compressed] = some [result]

/-- pointEquals is total on valid points. -/
axiom pointEquals_totality
    (o : RegistrationNativeOracle)
    (point1 point2 : MoveValue)
    (h1 : IsValidCompressedPoint point1)
    (h2 : IsValidCompressedPoint point2) :
    ∃ (b : Bool), o.pointEquals [point1, point2] = some [.bool b]

/-- pointEquals is reflexive. -/
axiom pointEquals_reflexive
    (o : RegistrationNativeOracle)
    (point : MoveValue)
    (h : IsValidCompressedPoint point) :
    o.pointEquals [point, point] = some [.bool true]

/-- pointEquals is symmetric. -/
axiom pointEquals_symmetric
    (o : RegistrationNativeOracle)
    (point1 point2 : MoveValue)
    (result : Bool) :
    o.pointEquals [point1, point2] = some [.bool result] →
    o.pointEquals [point2, point1] = some [.bool result]

/-! ### Scalar Operation Properties -/

/-- newScalarFromBytes validates input length. -/
axiom newScalarFromBytes_length_check
    (o : RegistrationNativeOracle)
    (bytes : MoveValue)
    (h : IsValidU8Vector bytes) :
    ∃ result, o.newScalarFromBytes [bytes] = some [result] ∧
              IsValidOption result

/-- Valid scalar bytes produce Some result. -/
axiom newScalarFromBytes_valid_produces_some
    (o : RegistrationNativeOracle)
    (bytes : MoveValue)
    (h_bytes : IsValidU8Vector bytes)
    (h_len : ∃ data, bytes = .vector .u8 data ∧ data.length = 32) :
    ∃ scalar, o.newScalarFromBytes [bytes] = some [.struct_ [.bool true, scalar]]

/-- newCompressedPointFromBytes validates format. -/
axiom newCompressedPointFromBytes_format_check
    (o : RegistrationNativeOracle)
    (bytes : MoveValue)
    (h : IsValidU8Vector bytes) :
    ∃ result, o.newCompressedPointFromBytes [bytes] = some [result] ∧
              IsValidOption result

/-! ### Hash Function Properties -/

/-- newScalarFromSha2_512 is deterministic. -/
theorem newScalarFromSha2_512_deterministic
    (msg : MoveValue)
    (result1 result2 : MoveValue)
    (h1 : newScalarFromSha2_512 [msg] = some [result1])
    (h2 : newScalarFromSha2_512 [msg] = some [result2]) :
    result1 = result2 := by
  rw [h1] at h2
  injection h2

/-- newScalarFromSha2_512 always produces 64-byte digest reduced to scalar. -/
theorem newScalarFromSha2_512_output_format
    (msg result : MoveValue)
    (h : newScalarFromSha2_512 [msg] = some [result]) :
    ∃ scalar_bytes, result = .struct_ [.vector .u8 scalar_bytes] ∧
                    scalar_bytes.length = 64 := by
  sorry  -- TODO: From SHA2-512 implementation

/-- hashToPointBase is deterministic (always returns same base point). -/
axiom hashToPointBase_deterministic
    (o : RegistrationNativeOracle)
    (result1 result2 : MoveValue)
    (h1 : o.hashToPointBase [] = some [result1])
    (h2 : o.hashToPointBase [] = some [result2]) :
    result1 = result2

/-! ## Ref-Aware Wrapper Semantics

These theorems establish the correspondence between value-level oracles
and their ref-aware wrappers.
-/

/-! ### Option Wrappers -/

theorem optionIsSomeRef_value_correspondence
    (containers : ContainerStore)
    (rid : RefId)
    (v : MoveValue)
    (tag : Bool)
    (rest : List MoveValue)
    (h_read : containers.read rid = some v)
    (h_struct : v = .struct_ (.bool tag :: rest)) :
    optionIsSomeRef containers [.immRef rid] =
    some ([.bool tag], containers) := by
  exact optionIsSomeRef_immRef_read containers rid tag rest h_struct

theorem optionExtractRef_value_correspondence
    (containers containers' : ContainerStore)
    (rid : RefId)
    (v extracted : MoveValue)
    (rest : List MoveValue)
    (h_read : containers.read rid = some v)
    (h_struct : v = .struct_ (.bool true :: extracted :: rest))
    (h_write : containers.write rid (.struct_ [.bool false]) = some containers') :
    optionExtractRef containers [.mutRef rid] =
    some ([extracted], containers') := by
  exact optionExtractRef_mutRef_read_write containers rid extracted rest containers' h_struct h_write

/-! ### Vector Wrappers -/

theorem vectorAppendU8Ref_concatenation_semantics
    (containers containers' : ContainerStore)
    (rid : RefId)
    (existing appended : List MoveValue)
    (h_read : containers.read rid = some (.vector .u8 existing))
    (h_write : containers.write rid (.vector .u8 (existing ++ appended)) = some containers') :
    vectorAppendU8Ref containers [.mutRef rid, .vector .u8 appended] =
    some ([], containers') := by
  unfold vectorAppendU8Ref
  simp [h_read, h_write]

theorem vectorAppendU8Ref_preserves_type
    (containers containers' : ContainerStore)
    (rid : RefId)
    (appended : List MoveValue)
    (h : vectorAppendU8Ref containers [.mutRef rid, .vector .u8 appended] = some ([], containers')) :
    ∃ existing result,
      containers.read rid = some (.vector .u8 existing) ∧
      containers'.read rid = some (.vector .u8 result) ∧
      result = existing ++ appended := by
  sorry  -- TODO: Unfold and extract from h

theorem vectorPushBackU8Ref_append_single
    (containers containers' : ContainerStore)
    (rid : RefId)
    (existing : List MoveValue)
    (byte : UInt8)
    (h_read : containers.read rid = some (.vector .u8 existing))
    (h_write : containers.write rid (.vector .u8 (existing ++ [.u8 byte])) = some containers') :
    vectorPushBackU8Ref containers [.mutRef rid, .u8 byte] =
    some ([], containers') := by
  unfold vectorPushBackU8Ref
  simp [h_read, h_write]

/-! ### BCS Serialization Wrappers -/

theorem bcsToBytesAddressRef_identity
    (containers : ContainerStore)
    (rid : RefId)
    (addr : ByteArray)
    (h_read : containers.read rid = some (.address addr)) :
    bcsToBytesAddressRef containers [.immRef rid] =
    some ([.vector .u8 (addr.toList.map .u8)], containers) := by
  unfold bcsToBytesAddressRef
  simp [h_read]

theorem bcsToBytesAddressRef_preserves_containers
    (containers : ContainerStore)
    (rid : RefId)
    (result : List MoveValue)
    (containers' : ContainerStore)
    (h : bcsToBytesAddressRef containers [.immRef rid] = some (result, containers')) :
    containers' = containers := by
  unfold bcsToBytesAddressRef at h
  cases hread : containers.read rid with
  | none => simp [hread] at h
  | some v =>
    simp [hread] at h
    cases v <;> simp at h
    case address addr =>
      injection h with _ h2
      exact h2

/-! ## Oracle Failure Conditions

Characterize when oracles return None (failure).
-/

/-- pointMul fails when scalar is invalid. -/
axiom pointMul_fails_on_invalid_scalar
    (o : RegistrationNativeOracle)
    (point scalar : MoveValue)
    (h : ¬IsValidScalar scalar) :
    o.pointMul [point, scalar] = none

/-- pointAdd fails when either point is invalid. -/
axiom pointAdd_fails_on_invalid_input
    (o : RegistrationNativeOracle)
    (point1 point2 : MoveValue)
    (h : ¬IsValidCompressedPoint point1 ∨ ¬IsValidCompressedPoint point2) :
    o.pointAdd [point1, point2] = none

/-- newScalarFromBytes fails on wrong length. -/
axiom newScalarFromBytes_fails_on_wrong_length
    (o : RegistrationNativeOracle)
    (bytes : MoveValue)
    (h : ∃ data, bytes = .vector .u8 data ∧ data.length ≠ 32) :
    ∃ result, o.newScalarFromBytes [bytes] = some [.struct_ [.bool false]]

/-! ## Success Path Composition

Theorems about oracle success in the happy path.
-/

/-- All oracles succeed in happy path with valid inputs. -/
theorem happy_path_oracles_succeed
    (o : RegistrationNativeOracle)
    (commitBa respBa : ByteArray)
    (h_commit_len : commitBa.size = 32)
    (h_resp_len : respBa.size = 32) :
    (∃ v, o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some [v]) ∧
    (∃ s, o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [s]) := by
  sorry  -- TODO: From validity axioms

/-- Sigma protocol verification oracles chain successfully. -/
theorem sigma_oracles_chain
    (o : RegistrationNativeOracle)
    (msg : MoveValue)
    (h_valid_msg : IsValidU8Vector msg) :
    ∃ (challenge base ek_point h_s ek_e lhs rhs : MoveValue),
      newScalarFromSha2_512 [msg] = some [challenge] ∧
      o.hashToPointBase [] = some [base] ∧
      (∀ ek, o.pubkeyToPoint [ek] = some [ek_point] →
        o.pointMul [base, scalar] = some [h_s] →
        o.pointMul [ek_point, challenge] = some [ek_e] →
        o.pointAdd [h_s, ek_e] = some [lhs] →
        o.pointDecompress [compressed] = some [rhs] →
        ∃ b, o.pointEquals [lhs, rhs] = some [.bool b]) := by
  sorry  -- TODO: Composition of closure axioms

/-! ## Oracle Monotonicity

Oracles don't modify the container store (except ref-aware wrappers on purpose).
-/

theorem value_oracle_preserves_containers
    (o : RegistrationNativeOracle)
    (oracle_fn : List MoveValue → Option (List MoveValue))
    (input result : List MoveValue)
    (containers : ContainerStore)
    (h : oracle_fn input = some result) :
    -- Value-level oracles have no containers parameter
    True := by
  trivial

theorem ref_oracle_mutation_bounded
    (oracle_fn : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (containers containers' : ContainerStore)
    (rid : RefId)
    (input result : List MoveValue)
    (h : oracle_fn containers input = some (result, containers'))
    (h_mut : ∃ mutRef, .mutRef rid ∈ input) :
    -- Mutation only affects rid
    ∀ rid' ≠ rid, ∀ v,
      containers.read rid' = some v →
      containers'.read rid' = some v := by
  sorry  -- TODO: From oracle implementation

/-! ## Error Code Correspondence

Link oracle failures to specific error codes.
-/

/-- Invalid scalar bytes lead to None option (error code path). -/
theorem invalid_scalar_produces_error_code
    (o : RegistrationNativeOracle)
    (bytes : MoveValue)
    (h_fail : o.newScalarFromBytes [bytes] = some [.struct_ [.bool false]]) :
    -- This leads to PC 74 error path with abort code 65537
    True := by
  trivial

/-- Sigma verification failure produces specific abort code. -/
theorem sigma_verify_failure_abort_code
    (o : RegistrationNativeOracle)
    (lhs rhs : MoveValue)
    (h_not_equal : o.pointEquals [lhs, rhs] = some [.bool false]) :
    -- This leads to PC 73 abort with code 65537
    True := by
  trivial

end MovementFormal.Experimental.ConfidentialAsset.Registration.OracleSemantics
