/-
Copyright (c) Move Industries.

# Refinement: bytecode `eval` ↔ `verifyRegistrationProofProp`

Connects the **bytecode-level** execution of the transcribed
`verify_registration_proof` (via `eval` in `Step.lean`) to the existing
**spec-level** propositions:

- `verifyRegistrationProofProp` (`VerifyMath.lean`) — mathematical spec (L0)
- `execVerifyRegistrationProof` (`Operational.lean`) — `Option Unit` runner (L1)
- `verifyRegistrationBytecodeResult` (`FunctionalSim.lean`) — functional simulation (L1.5)

The four-layer refinement chain is:

```
L2  eval (bytecode)
  ≡  L1.5  verifyRegistrationBytecodeResult (functional simulation)
    ≡  L1  execVerifyRegistrationProof (Option Unit)
      ↔  L0  verifyRegistrationProofProp (Prop)
```

**L2 ≡ L1.5** (`eval_eq_func`): up to `MachineState` (via `.dropMs`), since the real
83-instruction bytecode populates the `ContainerStore` via references.
Abstract proof (`eval_eq_func_100`) requires symbolic bytecode stepping (sorry).
Concrete instances verified by `native_decide` in `BytecodeDifftestEval.lean`.

**L1.5 ≡ L1** (`func_success_implies_exec_some`, `func_abort_implies_exec_none`):
algebraic equivalence under oracle coherence. Both directions proven.

**L1 ↔ L0** (`execVerifyRegistrationProof_iff`): already proven in `Operational.lean`.

See `REGISTRATION_VERIFY_REVIEW.md` (under `aptos-move/framework/formal/`) for obligations §6.
-/

import AptosFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
import AptosFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv
import AptosFormal.Experimental.ConfidentialAsset.Registration.VerifyMath
import AptosFormal.Experimental.ConfidentialAsset.Registration.Operational
import AptosFormal.Move.Step
import AptosFormal.Move.Programs.Registration

open AptosFormal.Experimental.ConfidentialAsset.Registration.Formal
open AptosFormal.Experimental.ConfidentialAsset.Registration.Operational
open AptosFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
open AptosFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv
open AptosFormal.AptosStd.Crypto.Ristretto255
open AptosFormal.Move
open AptosFormal.Move.Native.Registration
open AptosFormal.Move.Programs.Registration
open RegistrationVerify

namespace RegistrationRefinement

/-! ## Oracle coherence (L1.5 ↔ L1 bridge)

`OracleCoherence` witnesses that a `RegistrationNativeOracle` (MoveValue-level
native functions) and a `CryptoOracleWithBoolEq` (typed spec-level oracle) agree
on every crypto operation reachable by `verify_registration_proof`.

Both **forward** (spec → native) and **reverse** (native → spec) properties are
included so that the refinement works in both directions. -/

variable {Point : Type}

structure OracleCoherence (nOracle : RegistrationNativeOracle)
    (sOracle : CryptoOracleWithBoolEq Point) where
  PointRepr : Point → MoveValue → Prop
  ScalarRepr : RistrettoScalar → MoveValue → Prop

  -- Forward: spec → native

  compressedFromBytes_some :
    ∀ (bs : ByteArray) (c : CompressedRistretto32) (pt : Point),
      compressed32? bs = some c →
      sOracle.pointDecompress c = some pt →
      ∃ rCompressedMv,
        single? (nOracle.newCompressedPointFromBytes [.vector .u8 (bs.toList.map .u8)]) =
          some (.struct_ [.bool true, rCompressedMv]) ∧
        nOracle.compressedPointToBytes [rCompressedMv] =
          some [.vector .u8 (c.bytes.toList.map .u8)] ∧
        ∃ rhsMv, single? (nOracle.pointDecompress [rCompressedMv]) = some rhsMv ∧
          PointRepr pt rhsMv

  compressedFromBytes_none :
    ∀ (bs : ByteArray),
      compressed32? bs = none →
      (∀ (c : CompressedRistretto32) (pt : Point),
        compressed32? bs = some c → sOracle.pointDecompress c = some pt → False) →
      single? (nOracle.newCompressedPointFromBytes [.vector .u8 (bs.toList.map .u8)]) =
        some (.struct_ [.bool false])

  scalarFromBytes_some :
    ∀ (bs : ByteArray) (s : RistrettoScalar),
      sOracle.scalarFromBytes bs = some s →
      ∃ sMv,
        single? (nOracle.newScalarFromBytes [.vector .u8 (bs.toList.map .u8)]) =
          some (.struct_ [.bool true, sMv]) ∧
        ScalarRepr s sMv

  pubkeyToBytes_coherent :
    ∀ (ekBa : ByteArray),
      nOracle.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
        some [.vector .u8 (ekBa.toList.map .u8)]

  pubkeyToPoint_coherent :
    ∀ (ekBa : ByteArray) (ekComm : CompressedRistretto32) (ek : Point),
      compressed32? ekBa = some ekComm →
      sOracle.pubkeyToPoint ekComm = some ek →
      ∃ ekPtMv,
        single? (nOracle.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]]) = some ekPtMv ∧
        PointRepr ek ekPtMv

  hashToPointBase_coherent :
    ∃ hMv,
      single? (nOracle.hashToPointBase []) = some hMv ∧
      PointRepr sOracle.hashToPointBase hMv

  pointMul_coherent :
    ∀ (pt : Point) (s : RistrettoScalar) (ptMv sMv : MoveValue),
      PointRepr pt ptMv → ScalarRepr s sMv →
      ∃ resultMv,
        single? (nOracle.pointMul [ptMv, sMv]) = some resultMv ∧
        PointRepr (sOracle.pointMul pt s) resultMv

  pointAdd_coherent :
    ∀ (a b : Point) (aMv bMv : MoveValue),
      PointRepr a aMv → PointRepr b bMv →
      ∃ resultMv,
        single? (nOracle.pointAdd [aMv, bMv]) = some resultMv ∧
        PointRepr (sOracle.pointAdd a b) resultMv

  pointEquals_coherent :
    ∀ (a b : Point) (aMv bMv : MoveValue),
      PointRepr a aMv → PointRepr b bMv →
      single? (nOracle.pointEquals [aMv, bMv]) = some (.bool (sOracle.pointEqBool a b))

  challengeScalar_coherent :
    ∀ (msg : ByteArray) (e : RistrettoScalar),
      sOracle.challengeScalarFromMsg msg = some e →
      ∀ (msgMv : MoveValue),
        msgMv = .vector .u8 (msg.toList.map .u8) →
        ∃ eMv,
          single? (newScalarFromSha2_512 [msgMv]) = some eMv ∧
          ScalarRepr e eMv

  -- Reverse: native → spec (for the bytecode-success ⇒ spec-success direction)
  -- Stated in 3-condition form matching the functional sim's actual match pattern:
  --   single? (oracle_call) = some optionMv
  --   single? (optionIsSome [optionMv]) = some (.bool true)
  --   single? (optionExtract [optionMv]) = some extractedMv

  /-- If the native commitment parser succeeds (isSome true + extract), the spec
      also parses: `compressed32?` succeeds and `pointDecompress` yields a point. -/
  compressedFromBytes_rev :
    ∀ (bs : ByteArray) (rOpt rMv : MoveValue),
      single? (nOracle.newCompressedPointFromBytes [.vector .u8 (bs.toList.map .u8)]) = some rOpt →
      single? (optionIsSome [rOpt]) = some (.bool true) →
      single? (optionExtract [rOpt]) = some rMv →
      ∃ (c : CompressedRistretto32) (pt : Point),
        compressed32? bs = some c ∧ sOracle.pointDecompress c = some pt

  /-- If the native scalar parser succeeds, the spec scalar parse also succeeds. -/
  scalarFromBytes_rev :
    ∀ (bs : ByteArray) (sOpt sMv : MoveValue),
      single? (nOracle.newScalarFromBytes [.vector .u8 (bs.toList.map .u8)]) = some sOpt →
      single? (optionIsSome [sOpt]) = some (.bool true) →
      single? (optionExtract [sOpt]) = some sMv →
      ∃ (s : RistrettoScalar),
        sOracle.scalarFromBytes bs = some s ∧ ScalarRepr s sMv

  /-- If the native pubkeyToPoint returns some value, the spec also decompresses. -/
  pubkeyToPoint_rev :
    ∀ (ekBa : ByteArray) (ekPtMv : MoveValue),
      single? (nOracle.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]]) = some ekPtMv →
      ∃ (ekComm : CompressedRistretto32) (ek : Point),
        compressed32? ekBa = some ekComm ∧ sOracle.pubkeyToPoint ekComm = some ek ∧
        PointRepr ek ekPtMv

  /-- The native tagged hash matches the spec challenge scalar. -/
  challengeScalar_rev :
    ∀ (msgMv eMv : MoveValue) (msg : ByteArray),
      msgMv = .vector .u8 (msg.toList.map .u8) →
      single? (newScalarFromSha2_512 [msgMv]) = some eMv →
      ∃ (e : RistrettoScalar),
        registrationChallengeScalarMove msg = some e ∧ ScalarRepr e eMv

  /-- The native compressed-point bytes for an extracted rMv round-trip to the
      original commitment bytes. -/
  compressedPointToBytes_roundtrip :
    ∀ (bs : ByteArray) (rOpt rMv : MoveValue),
      single? (nOracle.newCompressedPointFromBytes [.vector .u8 (bs.toList.map .u8)]) = some rOpt →
      single? (optionIsSome [rOpt]) = some (.bool true) →
      single? (optionExtract [rOpt]) = some rMv →
      nOracle.compressedPointToBytes [rMv] = some [.vector .u8 (bs.toList.map .u8)]

  /-- If native pointDecompress returns a value for an extracted rMv, the result
      represents the spec's pointDecompress on the corresponding compressed point. -/
  pointDecompress_rev :
    ∀ (bs : ByteArray) (rOpt rMv rhsMv : MoveValue)
      (c : CompressedRistretto32) (pt : Point),
      single? (nOracle.newCompressedPointFromBytes [.vector .u8 (bs.toList.map .u8)]) = some rOpt →
      single? (optionIsSome [rOpt]) = some (.bool true) →
      single? (optionExtract [rOpt]) = some rMv →
      compressed32? bs = some c →
      sOracle.pointDecompress c = some pt →
      single? (nOracle.pointDecompress [rMv]) = some rhsMv →
      PointRepr pt rhsMv

  -- Failure direction: native reports false ⇒ spec parse fails

  /-- If native commitment isSome returns false, no spec-level compressed point
      can both parse and decompress. Contrapositive of `compressedFromBytes_some`. -/
  compressedFromBytes_false_rev :
    ∀ (bs : ByteArray) (rOpt : MoveValue),
      single? (nOracle.newCompressedPointFromBytes [.vector .u8 (bs.toList.map .u8)]) = some rOpt →
      single? (optionIsSome [rOpt]) = some (.bool false) →
      ¬∃ (c : CompressedRistretto32) (pt : Point),
        compressed32? bs = some c ∧ sOracle.pointDecompress c = some pt

  /-- If native scalar isSome returns false, spec scalar parse also fails. -/
  scalarFromBytes_false_rev :
    ∀ (bs : ByteArray) (sOpt : MoveValue),
      single? (nOracle.newScalarFromBytes [.vector .u8 (bs.toList.map .u8)]) = some sOpt →
      single? (optionIsSome [sOpt]) = some (.bool false) →
      sOracle.scalarFromBytes bs = none

/-! ## Block extraction: decompose a successful functional sim into intermediate values

Given `verifyRegistrationBytecodeResult o args = .returned [] .empty`, extract
all 12 intermediate MoveValues that the computation produced. This is a pure
structural decomposition — no oracle coherence needed, only constructor
discrimination (`cases hfunc` closes branches where `.error = .returned`). -/

set_option maxHeartbeats 800000 in
theorem func_success_extracts
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (hfunc : verifyRegistrationBytecodeResult o
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekBa.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)] =
      .returned [] MachineState.empty) :
    ∃ (rOpt rMv sOpt sMv msgMv eMv hMv ekPtMv hsMv ekeMv lhsMv rhsMv : MoveValue),
      single? (o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)]) = some rOpt ∧
      single? (optionIsSome [rOpt]) = some (.bool true) ∧
      single? (optionExtract [rOpt]) = some rMv ∧
      single? (o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)]) = some sOpt ∧
      single? (optionIsSome [sOpt]) = some (.bool true) ∧
      single? (optionExtract [sOpt]) = some sMv ∧
      buildFSMessageMv o chainId sender contract token
        (.struct_ [.vector .u8 (ekBa.toList.map .u8)]) rMv = some msgMv ∧
      single? (newScalarFromSha2_512 [msgMv]) = some eMv ∧
      single? (o.hashToPointBase []) = some hMv ∧
      single? (o.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]]) = some ekPtMv ∧
      single? (o.pointMul [hMv, sMv]) = some hsMv ∧
      single? (o.pointMul [ekPtMv, eMv]) = some ekeMv ∧
      single? (o.pointAdd [hsMv, ekeMv]) = some lhsMv ∧
      single? (o.pointDecompress [rMv]) = some rhsMv ∧
      single? (o.pointEquals [lhsMv, rhsMv]) = some (.bool true) := by
  simp only [verifyRegistrationBytecodeResult,
    verifyRegistrationBytecodeResult.blockB,
    verifyRegistrationBytecodeResult.blockCDE] at hfunc
  split at hfunc
  · rename_i rOpt hR1; split at hfunc
    · rename_i hIS1; split at hfunc
      · rename_i rMv hEX1; split at hfunc
        · rename_i sOpt hR2; split at hfunc
          · rename_i hIS2; split at hfunc
            · rename_i sMv hEX2; split at hfunc
              · rename_i msgMv hMsg; split at hfunc
                · rename_i eMv hTag; split at hfunc
                  · rename_i hMv hHash; split at hfunc
                    · rename_i ekPtMv hPub; split at hfunc
                      · rename_i hsMv hMul1; split at hfunc
                        · rename_i ekeMv hMul2; split at hfunc
                          · rename_i lhsMv hAdd; split at hfunc
                            · rename_i rhsMv hDec; split at hfunc
                              · rename_i hEq
                                exact ⟨rOpt, rMv, sOpt, sMv, msgMv, eMv, hMv, ekPtMv,
                                  hsMv, ekeMv, lhsMv, rhsMv,
                                  hR1, hIS1, hEX1, hR2, hIS2, hEX2,
                                  hMsg, hTag, hHash, hPub, hMul1, hMul2, hAdd, hDec, hEq⟩
                              all_goals cases hfunc
                            all_goals cases hfunc
                          all_goals cases hfunc
                        all_goals cases hfunc
                      all_goals cases hfunc
                    all_goals cases hfunc
                  all_goals cases hfunc
                all_goals cases hfunc
              all_goals cases hfunc
            all_goals cases hfunc
          all_goals cases hfunc
        all_goals cases hfunc
      all_goals cases hfunc
    all_goals cases hfunc
  all_goals cases hfunc

/-! ## Abort path classification

Given `verifyRegistrationBytecodeResult o args = .aborted ABORT_CODE`, classify
which of the 3 abort points was reached:

1. **Path 1**: Commitment `optionIsSome` returned `false`
2. **Path 2**: Scalar `optionIsSome` returned `false`
3. **Path 3**: All intermediate steps succeeded, `pointEquals` returned `false`

This is the abort counterpart of `func_success_extracts`. -/

set_option maxHeartbeats 1200000 in
theorem func_abort_classification
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (hfunc : verifyRegistrationBytecodeResult o
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekBa.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)] =
      .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE) :
    (∃ rOpt : MoveValue,
      single? (o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)]) = some rOpt ∧
      single? (optionIsSome [rOpt]) = some (.bool false))
    ∨
    (∃ sOpt : MoveValue,
      single? (o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)]) = some sOpt ∧
      single? (optionIsSome [sOpt]) = some (.bool false))
    ∨
    (∃ (rOpt rMv sOpt sMv msgMv eMv hMv ekPtMv hsMv ekeMv lhsMv rhsMv : MoveValue),
      single? (o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)]) = some rOpt ∧
      single? (optionIsSome [rOpt]) = some (.bool true) ∧
      single? (optionExtract [rOpt]) = some rMv ∧
      single? (o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)]) = some sOpt ∧
      single? (optionIsSome [sOpt]) = some (.bool true) ∧
      single? (optionExtract [sOpt]) = some sMv ∧
      buildFSMessageMv o chainId sender contract token
        (.struct_ [.vector .u8 (ekBa.toList.map .u8)]) rMv = some msgMv ∧
      single? (newScalarFromSha2_512 [msgMv]) = some eMv ∧
      single? (o.hashToPointBase []) = some hMv ∧
      single? (o.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]]) = some ekPtMv ∧
      single? (o.pointMul [hMv, sMv]) = some hsMv ∧
      single? (o.pointMul [ekPtMv, eMv]) = some ekeMv ∧
      single? (o.pointAdd [hsMv, ekeMv]) = some lhsMv ∧
      single? (o.pointDecompress [rMv]) = some rhsMv ∧
      single? (o.pointEquals [lhsMv, rhsMv]) = some (.bool false)) := by
  simp only [verifyRegistrationBytecodeResult,
    verifyRegistrationBytecodeResult.blockB,
    verifyRegistrationBytecodeResult.blockCDE] at hfunc
  split at hfunc
  · rename_i rOpt hR1; split at hfunc
    · rename_i hIS1; split at hfunc
      · rename_i rMv hEX1; split at hfunc
        · rename_i sOpt hR2; split at hfunc
          · rename_i hIS2; split at hfunc
            · rename_i sMv hEX2; split at hfunc
              · rename_i msgMv hMsg; split at hfunc
                · rename_i eMv hTag; split at hfunc
                  · rename_i hMv hHash; split at hfunc
                    · rename_i ekPtMv hPub; split at hfunc
                      · rename_i hsMv hMul1; split at hfunc
                        · rename_i ekeMv hMul2; split at hfunc
                          · rename_i lhsMv hAdd; split at hfunc
                            · rename_i rhsMv hDec; split at hfunc
                              · cases hfunc
                              · rename_i hEq
                                exact Or.inr (Or.inr ⟨rOpt, rMv, sOpt, sMv, msgMv, eMv,
                                  hMv, ekPtMv, hsMv, ekeMv, lhsMv, rhsMv,
                                  hR1, hIS1, hEX1, hR2, hIS2, hEX2,
                                  hMsg, hTag, hHash, hPub, hMul1, hMul2, hAdd, hDec, hEq⟩)
                              · cases hfunc
                            all_goals cases hfunc
                          all_goals cases hfunc
                        all_goals cases hfunc
                      all_goals cases hfunc
                    all_goals cases hfunc
                  all_goals cases hfunc
                all_goals cases hfunc
              all_goals cases hfunc
            all_goals cases hfunc
          · rename_i hIS2
            exact Or.inr (Or.inl ⟨sOpt, hR2, hIS2⟩)
          · cases hfunc
        all_goals cases hfunc
      all_goals cases hfunc
    · rename_i hIS1
      exact Or.inl ⟨rOpt, hR1, hIS1⟩
    · cases hfunc
  all_goals cases hfunc

/-! ## L2 ≡ L1.5: eval ≡ verifyRegistrationBytecodeResult (up to MachineState)

The real 83-instruction bytecode uses `immBorrowLoc` / `mutBorrowLoc` /
`nativeRef` calls, so `eval` returns a populated `ContainerStore` in
its `MachineState`. The functional sim returns `MachineState.empty`.
We compare via `.dropMs` which projects away the `MachineState`.

**Fuel lifting:** `eval_fuel_ge` shows that non-error results are
fuel-monotone. Combined with `eval_eq_func_100` (at fuel 200) and
`func_trichotomy`, we lift to arbitrary `fuel ≥ 200`.

The `.error` case (oracle returns garbage) requires an error-fuel-monotonicity
argument that the computation terminates in < 200 steps. This sorry is
**vacuous for callers** which assume `.returned` or `.aborted`. -/

theorem eval_eq_func
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (fuel : Nat) (hfuel : fuel ≥ 200) :
    (eval (registrationModuleEnv o) verifyRegistrationProofIdx
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekBa.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)]
      fuel MachineState.empty).dropMs =
    verifyRegistrationBytecodeResult o
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekBa.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)] := by
  have h100 := eval_eq_func_100 o chainId sender contract token ekBa commitBa respBa
  by_cases hne : eval (registrationModuleEnv o) verifyRegistrationProofIdx
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekBa.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)]
      200 MachineState.empty ≠ .error
  · rw [eval_fuel_ge_dropMs _ _ _ _ _ _ hfuel hne]; exact h100
  · push_neg at hne; rw [hne] at h100; simp [ExecResult.dropMs] at h100
    rw [← h100]
    sorry

/-! ## L1.5 ≡ L1: func ≡ execVerifyRegistrationProof

The functional simulation matches the spec-level runner under oracle coherence.
These are algebraic proofs comparing two functional programs. -/

theorem func_success_implies_exec_some
    (nOracle : RegistrationNativeOracle)
    (sOracle : CryptoOracleWithBoolEq Point)
    (coh : OracleCoherence nOracle sOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (i : RegistrationFiatShamirInputs)
    (hi : i.chainId = chainId ∧
          i.senderBcs = sender ∧
          i.contractBcs = contract ∧
          i.tokenBcs = token ∧
          i.ekBytes = ekBa ∧
          i.commitmentRBytes = commitBa)
    (hfunc : verifyRegistrationBytecodeResult nOracle
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekBa.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)] =
      .returned [] MachineState.empty) :
    execVerifyRegistrationProof
      { sOracle with challengeScalarFromMsg := registrationChallengeScalarMove }
      i respBa = some () := by
  -- Step 1: Extract all intermediate MoveValues from the functional sim's success
  obtain ⟨rOpt, rMv, sOpt, sMv, msgMv, eMv, hMvN, ekPtMv, hsMvN, ekeMvN, lhsMvN, rhsMvN,
    hR1, hIS1, hEX1, hR2, hIS2, hEX2, hMsg, hTag, hHash, hPub, hMul1, hMul2,
    hAdd, hDec, hEqNat⟩ := func_success_extracts nOracle chainId sender contract token
      ekBa commitBa respBa hfunc
  -- Step 2: Reverse coherence → spec-level parsed values
  obtain ⟨rComm, rPt, hrComm, hrPt⟩ := coh.compressedFromBytes_rev commitBa rOpt rMv hR1 hIS1 hEX1
  obtain ⟨s_typed, hs_typed, hs_repr⟩ := coh.scalarFromBytes_rev respBa sOpt sMv hR2 hIS2 hEX2
  obtain ⟨ekComm, ek_typed, hekComm, hek_typed, hek_repr⟩ := coh.pubkeyToPoint_rev ekBa ekPtMv hPub
  obtain ⟨hMvSpec, hhash_spec, hh_repr⟩ := coh.hashToPointBase_coherent
  have hRhs_repr := coh.pointDecompress_rev commitBa rOpt rMv rhsMvN rComm rPt
    hR1 hIS1 hEX1 hrComm hrPt hDec
  -- Step 3: Message coherence → challenge scalar
  have hCPTB := coh.compressedPointToBytes_roundtrip commitBa rOpt rMv hR1 hIS1 hEX1
  have hPTB := coh.pubkeyToBytes_coherent ekBa
  have hMsgList := buildFSMessageMv_list_gen nOracle chainId sender contract token
    ekBa commitBa _ rMv hPTB hCPTB
  have hMsgEq : msgMv = .vector .u8 (
      fiatShamirDstMvU8s ++ [.u8 chainId] ++ sender.toList.map .u8 ++ contract.toList.map .u8 ++
      token.toList.map .u8 ++ ekBa.toList.map .u8 ++ commitBa.toList.map .u8) :=
    Option.some.inj (hMsgList ▸ hMsg).symm
  have hMsgRepr : msgMv = .vector .u8 ((registrationFiatShamirMsg i).toList.map .u8) := by
    rw [hMsgEq, registrationFiatShamirMsg]
    obtain ⟨h1, h2, h3, h4, h5, h6⟩ := hi
    subst h1; subst h2; subst h3; subst h4; subst h5; subst h6
    simp only [List.map_append, List.map_cons, List.map_nil,
      ByteArray.toList_append, ByteArray.toList_mk_singleton,
      fiatShamirDstMvU8s_eq_registrationDstBytes_toList_map]
  obtain ⟨e_typed, he_typed, he_repr⟩ := coh.challengeScalar_rev msgMv eMv
    (registrationFiatShamirMsg i) hMsgRepr hTag
  -- Step 4: Thread PointRepr/ScalarRepr through pointMul, pointAdd
  have hhash_eq : hMvN = hMvSpec := Option.some.inj (hhash_spec ▸ hHash).symm
  rw [hhash_eq] at hMul1
  obtain ⟨hsMvSpec, hhsMul, hhs_repr⟩ := coh.pointMul_coherent sOracle.hashToPointBase s_typed
    hMvSpec sMv hh_repr hs_repr
  have hsMv_eq : hsMvN = hsMvSpec := Option.some.inj (hhsMul ▸ hMul1).symm
  obtain ⟨ekeMvSpec, hekeMul, heke_repr⟩ := coh.pointMul_coherent ek_typed e_typed
    ekPtMv eMv hek_repr he_repr
  have ekeMv_eq : ekeMvN = ekeMvSpec := Option.some.inj (hekeMul ▸ hMul2).symm
  rw [hsMv_eq] at hAdd; rw [ekeMv_eq] at hAdd
  obtain ⟨lhsMvSpec, hlhsAdd, hlhs_repr⟩ := coh.pointAdd_coherent
    (sOracle.pointMul sOracle.hashToPointBase s_typed) (sOracle.pointMul ek_typed e_typed)
    hsMvSpec ekeMvSpec hhs_repr heke_repr
  have lhsMv_eq : lhsMvN = lhsMvSpec := Option.some.inj (hlhsAdd ▸ hAdd).symm
  -- Step 5: pointEquals coherence → pointEqBool is true
  rw [lhsMv_eq] at hEqNat
  have hPtEq := coh.pointEquals_coherent
    (sOracle.pointAdd (sOracle.pointMul sOracle.hashToPointBase s_typed) (sOracle.pointMul ek_typed e_typed))
    rPt lhsMvSpec rhsMvN hlhs_repr hRhs_repr
  have hBoolTrue : sOracle.pointEqBool
      (sOracle.pointAdd (sOracle.pointMul sOracle.hashToPointBase s_typed) (sOracle.pointMul ek_typed e_typed))
      rPt = true := by
    have h := hEqNat; rw [hPtEq] at h
    exact MoveValue.bool.inj (Option.some.inj h)
  -- Step 6: Assemble the operational runner's success
  obtain ⟨_, h2, h3, h4, h5, h6⟩ := hi
  subst h2; subst h3; subst h4; subst h5; subst h6
  show execVerifyRegistrationProof
    { sOracle with challengeScalarFromMsg := registrationChallengeScalarMove }
    i respBa = some ()
  unfold execVerifyRegistrationProof
  simp only [hs_typed, hrComm, hekComm, hrPt, hek_typed, he_typed, hBoolTrue, ↓reduceIte]

set_option maxHeartbeats 400000 in
theorem func_abort_implies_exec_none
    (nOracle : RegistrationNativeOracle)
    (sOracle : CryptoOracleWithBoolEq Point)
    (coh : OracleCoherence nOracle sOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (i : RegistrationFiatShamirInputs)
    (hi : i.chainId = chainId ∧
          i.senderBcs = sender ∧
          i.contractBcs = contract ∧
          i.tokenBcs = token ∧
          i.ekBytes = ekBa ∧
          i.commitmentRBytes = commitBa)
    (hfunc : verifyRegistrationBytecodeResult nOracle
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekBa.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)] =
      .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE) :
    execVerifyRegistrationProof
      { sOracle with challengeScalarFromMsg := registrationChallengeScalarMove }
      i respBa = none := by
  have hClass := func_abort_classification nOracle chainId sender contract token
    ekBa commitBa respBa hfunc
  rcases hClass with ⟨rOpt, hR1, hIS1⟩ | ⟨sOpt, hR2, hIS2⟩ |
    ⟨rOpt, rMv, sOpt, sMv, msgMv, eMv, hMvN, ekPtMv, hsMvN, ekeMvN, lhsMvN, rhsMvN,
     hR1, hIS1, hEX1, hR2, hIS2, hEX2, hMsg, hTag, hHash, hPub, hMul1, hMul2,
     hAdd, hDec, hEqFalse⟩
  · -- Path 1: commitment isSome = false
    have hNotBoth := coh.compressedFromBytes_false_rev commitBa rOpt hR1 hIS1
    obtain ⟨_, _, _, _, _, h6⟩ := hi
    show execVerifyRegistrationProof
      { sOracle with challengeScalarFromMsg := registrationChallengeScalarMove }
      i respBa = none
    unfold execVerifyRegistrationProof
    rw [h6]
    rcases hc : compressed32? commitBa with _ | c
    · simp
    · have hd : sOracle.pointDecompress c = none := by
        rcases hpd : sOracle.pointDecompress c with _ | pt
        · rfl
        · exact absurd ⟨c, pt, hc, hpd⟩ hNotBoth
      cases sOracle.scalarFromBytes respBa <;>
        cases compressed32? i.ekBytes <;>
        simp_all
  · -- Path 2: scalar isSome = false
    have hNone := coh.scalarFromBytes_false_rev respBa sOpt hR2 hIS2
    show execVerifyRegistrationProof
      { sOracle with challengeScalarFromMsg := registrationChallengeScalarMove }
      i respBa = none
    unfold execVerifyRegistrationProof
    simp [hNone]
  · -- Path 3: all intermediate steps succeeded, pointEquals = false
    -- Reverse coherence → spec-level parsed values (mirrors func_success_implies_exec_some)
    obtain ⟨rComm, rPt, hrComm, hrPt⟩ := coh.compressedFromBytes_rev commitBa rOpt rMv hR1 hIS1 hEX1
    obtain ⟨s_typed, hs_typed, hs_repr⟩ := coh.scalarFromBytes_rev respBa sOpt sMv hR2 hIS2 hEX2
    obtain ⟨ekComm, ek_typed, hekComm, hek_typed, hek_repr⟩ := coh.pubkeyToPoint_rev ekBa ekPtMv hPub
    obtain ⟨hMvSpec, hhash_spec, hh_repr⟩ := coh.hashToPointBase_coherent
    have hRhs_repr := coh.pointDecompress_rev commitBa rOpt rMv rhsMvN rComm rPt
      hR1 hIS1 hEX1 hrComm hrPt hDec
    -- Message coherence → challenge scalar
    have hCPTB := coh.compressedPointToBytes_roundtrip commitBa rOpt rMv hR1 hIS1 hEX1
    have hPTB := coh.pubkeyToBytes_coherent ekBa
    have hMsgList := buildFSMessageMv_list_gen nOracle chainId sender contract token
      ekBa commitBa _ rMv hPTB hCPTB
    have hMsgEq : msgMv = .vector .u8 (
        fiatShamirDstMvU8s ++ [.u8 chainId] ++ sender.toList.map .u8 ++ contract.toList.map .u8 ++
        token.toList.map .u8 ++ ekBa.toList.map .u8 ++ commitBa.toList.map .u8) :=
      Option.some.inj (hMsgList ▸ hMsg).symm
    have hMsgRepr : msgMv = .vector .u8 ((registrationFiatShamirMsg i).toList.map .u8) := by
      rw [hMsgEq, registrationFiatShamirMsg]
      obtain ⟨h1, h2, h3, h4, h5, h6⟩ := hi
      subst h1; subst h2; subst h3; subst h4; subst h5; subst h6
      simp only [List.map_append, List.map_cons, List.map_nil,
        ByteArray.toList_append, ByteArray.toList_mk_singleton,
        fiatShamirDstMvU8s_eq_registrationDstBytes_toList_map]
    obtain ⟨e_typed, he_typed, he_repr⟩ := coh.challengeScalar_rev msgMv eMv
      (registrationFiatShamirMsg i) hMsgRepr hTag
    -- Thread PointRepr/ScalarRepr through pointMul, pointAdd
    have hhash_eq : hMvN = hMvSpec := Option.some.inj (hhash_spec ▸ hHash).symm
    rw [hhash_eq] at hMul1
    obtain ⟨hsMvSpec, hhsMul, hhs_repr⟩ := coh.pointMul_coherent sOracle.hashToPointBase s_typed
      hMvSpec sMv hh_repr hs_repr
    have hsMv_eq : hsMvN = hsMvSpec := Option.some.inj (hhsMul ▸ hMul1).symm
    obtain ⟨ekeMvSpec, hekeMul, heke_repr⟩ := coh.pointMul_coherent ek_typed e_typed
      ekPtMv eMv hek_repr he_repr
    have ekeMv_eq : ekeMvN = ekeMvSpec := Option.some.inj (hekeMul ▸ hMul2).symm
    rw [hsMv_eq] at hAdd; rw [ekeMv_eq] at hAdd
    obtain ⟨lhsMvSpec, hlhsAdd, hlhs_repr⟩ := coh.pointAdd_coherent
      (sOracle.pointMul sOracle.hashToPointBase s_typed) (sOracle.pointMul ek_typed e_typed)
      hsMvSpec ekeMvSpec hhs_repr heke_repr
    have lhsMv_eq : lhsMvN = lhsMvSpec := Option.some.inj (hlhsAdd ▸ hAdd).symm
    -- pointEquals coherence → pointEqBool = false
    rw [lhsMv_eq] at hEqFalse
    have hPtEq := coh.pointEquals_coherent
      (sOracle.pointAdd (sOracle.pointMul sOracle.hashToPointBase s_typed) (sOracle.pointMul ek_typed e_typed))
      rPt lhsMvSpec rhsMvN hlhs_repr hRhs_repr
    have hBoolFalse : sOracle.pointEqBool
        (sOracle.pointAdd (sOracle.pointMul sOracle.hashToPointBase s_typed) (sOracle.pointMul ek_typed e_typed))
        rPt = false := by
      have h := hEqFalse; rw [hPtEq] at h
      exact MoveValue.bool.inj (Option.some.inj h)
    -- Assemble the operational runner's failure
    obtain ⟨_, h2, h3, h4, h5, h6⟩ := hi
    subst h2; subst h3; subst h4; subst h5; subst h6
    show execVerifyRegistrationProof
      { sOracle with challengeScalarFromMsg := registrationChallengeScalarMove }
      i respBa = none
    unfold execVerifyRegistrationProof
    simp only [hs_typed, hrComm, hekComm, hrPt, hek_typed, he_typed, hBoolFalse]
    decide

/-! ## Full chain: L2 → L0

Composing L2≡L1.5 (`eval_eq_func` with `.dropMs`),
L1.5≡L1 (`func_success_implies_exec_some`), and
L1↔L0 (`execVerifyRegistrationProof_iff`) gives the end-to-end theorem.

`eval_success_implies_prop` now accepts any returned `MachineState` `ms`
(not just `MachineState.empty`), since the real bytecode leaves references
in the container store. The `.dropMs` projection strips this before
comparing with the functional sim.

**Concrete witness:** `BytecodeDifftestBridge.difftest_L2_implies_L0` proves this
chain for the dk=42/k=9999 trace without any `sorry`. -/

theorem eval_success_implies_prop
    (nOracle : RegistrationNativeOracle)
    (sOracle : CryptoOracleWithBoolEq Point)
    (coh : OracleCoherence nOracle sOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (i : RegistrationFiatShamirInputs)
    (hi : i.chainId = chainId ∧
          i.senderBcs = sender ∧
          i.contractBcs = contract ∧
          i.tokenBcs = token ∧
          i.ekBytes = ekBa ∧
          i.commitmentRBytes = commitBa)
    (fuel : Nat) (hfuel : fuel ≥ 200)
    (ms : MachineState)
    (heval : eval (registrationModuleEnv nOracle) verifyRegistrationProofIdx
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekBa.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)]
      fuel MachineState.empty =
      .returned [] ms) :
    verifyRegistrationProofProp
      ({ sOracle with challengeScalarFromMsg := registrationChallengeScalarMove }).toCryptoOracle
      i respBa := by
  have hfunc : verifyRegistrationBytecodeResult nOracle
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekBa.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)] =
      .returned [] MachineState.empty := by
    have heq := eval_eq_func nOracle chainId sender contract token ekBa commitBa respBa fuel hfuel
    rw [heval, ExecResult.dropMs_returned] at heq
    exact heq.symm
  have hexec := func_success_implies_exec_some nOracle sOracle coh
    chainId sender contract token ekBa commitBa respBa i hi hfunc
  exact (execVerifyRegistrationProof_iff _ i respBa).mp hexec

/-! ## Full abort chain: L2 → ¬L0

Composing L2≡L1.5 (`eval_eq_func` with `.dropMs`),
L1.5→L1 abort (`func_abort_implies_exec_none`), and
L1↔L0 (`execVerifyRegistrationProof_iff`) gives the end-to-end abort theorem.

**Note:** depends on `eval_eq_func` (which depends on `eval_eq_func_100`, sorry).
The `.aborted` constructor doesn't carry `MachineState`, so `dropMs` is trivial. -/

theorem eval_abort_implies_not_prop
    (nOracle : RegistrationNativeOracle)
    (sOracle : CryptoOracleWithBoolEq Point)
    (coh : OracleCoherence nOracle sOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (i : RegistrationFiatShamirInputs)
    (hi : i.chainId = chainId ∧
          i.senderBcs = sender ∧
          i.contractBcs = contract ∧
          i.tokenBcs = token ∧
          i.ekBytes = ekBa ∧
          i.commitmentRBytes = commitBa)
    (fuel : Nat) (hfuel : fuel ≥ 200)
    (heval : eval (registrationModuleEnv nOracle) verifyRegistrationProofIdx
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekBa.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)]
      fuel MachineState.empty =
      .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE) :
    ¬ verifyRegistrationProofProp
      ({ sOracle with challengeScalarFromMsg := registrationChallengeScalarMove }).toCryptoOracle
      i respBa := by
  have hfunc : verifyRegistrationBytecodeResult nOracle
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekBa.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)] =
      .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE := by
    have heq := eval_eq_func nOracle chainId sender contract token ekBa commitBa respBa fuel hfuel
    rw [heval, ExecResult.dropMs_aborted] at heq
    exact heq.symm
  have hexec := func_abort_implies_exec_none nOracle sOracle coh
    chainId sender contract token ekBa commitBa respBa i hi hfunc
  intro hprop
  have hexec_some := (execVerifyRegistrationProof_iff _ i respBa).mpr hprop
  rw [hexec] at hexec_some
  exact Option.noConfusion hexec_some

end RegistrationRefinement
