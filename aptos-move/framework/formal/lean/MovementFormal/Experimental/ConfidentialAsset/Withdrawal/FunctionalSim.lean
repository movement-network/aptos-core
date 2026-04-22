import MovementFormal.MoveModel.Step

/-!
# Functional simulation of `verify_withdrawal_proof` bytecode — Phase 4 scaffold

**Source:** `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move` — `public fun verify_withdrawal_proof(...)`.

Phase 4 scaffold per [`CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`](../../../../../CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md) §6. This file lands:

1. **`WithdrawalNativeOracle`** — the analog of `RegistrationNativeOracle` exposing the curve
   operations the withdrawal verifier needs (point arithmetic, scalar ops, hash-to-point,
   pubkey-to-point, plus `verify_batch_range_proof` for the Bulletproofs range-proof part).
2. **`verifyWithdrawalBytecodeResult`** — a **stub** functional sim that returns `.error` for
   every input. The real sim will be a readable Lean function mirroring the bytecode's
   decompose-check-MSM pipeline; filling it in is a Phase 4 task that depends on transcribing
   the withdrawal bytecode (`MovementFormal.MoveModel.Programs.Withdrawal`, does not exist yet).

The scaffold is intentionally self-contained so it can land and build without blocking on
upstream transcription work. Callers get a real oracle structure to write tests and `pragma
opaque` boundaries against.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Withdrawal.FunctionalSim

open MovementFormal.MoveModel

/-! ## Oracle structure

Wraps the Ristretto255 / Bulletproofs natives the withdrawal verifier dispatches to. Scalars
are `.struct_ [.vector .u8 <32 bytes>]`; points are `.vector .u8 <32 bytes>` (compressed) or
`.struct_ [...]` (decompressed); the exact shapes follow Registration's convention.
-/

structure WithdrawalNativeOracle where
  /-- `ristretto255::new_scalar_from_bytes(bytes) → Option<Scalar>`. -/
  newScalarFromBytes : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::new_compressed_point_from_bytes(bytes) → Option<CompressedRistretto>`. -/
  newCompressedPointFromBytes : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::new_scalar_from_sha2_512(msg) → Scalar` (Fiat-Shamir challenge). -/
  newScalarFromSha2_512 : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::compressed_point_to_bytes(p) → vector<u8>`. -/
  compressedPointToBytes : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::hash_to_point_base() → RistrettoPoint`. -/
  hashToPointBase : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::point_decompress(compressed) → RistrettoPoint`. -/
  pointDecompress : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::point_mul(point, scalar) → RistrettoPoint`. -/
  pointMul : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::point_add(a, b) → RistrettoPoint`. -/
  pointAdd : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::point_sub(a, b) → RistrettoPoint`. -/
  pointSub : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::point_equals(a, b) → bool`. -/
  pointEquals : List MoveValue → Option (List MoveValue)
  /-- `ristretto255::multi_scalar_mul(points, scalars) → RistrettoPoint`. -/
  multiScalarMul : List MoveValue → Option (List MoveValue)
  /-- `twisted_elgamal::pubkey_to_bytes(ek) → vector<u8>`. -/
  pubkeyToBytes : List MoveValue → Option (List MoveValue)
  /-- `twisted_elgamal::pubkey_to_point(ek) → RistrettoPoint`. -/
  pubkeyToPoint : List MoveValue → Option (List MoveValue)
  /-- `ristretto255_bulletproofs::verify_batch_range_proof(values, gens, proof, dst) → bool`.

    Aborts with `EVALUES_NOT_VALID_SCALARS` (1 → 65537) if values aren't canonical scalars;
    otherwise returns `bool` indicating whether the proof verifies. -/
  verifyBatchRangeProof : List MoveValue → Option (List MoveValue)

/-! ## Functional-sim stub

Returns `.error` unconditionally for now. The real sim's shape (from the Move source) is:

```
verify_withdrawal_proof(cid, from, contract, sender_ek, amount, current_balance, new_balance, proof):
    Bulletproofs: verify range proof on new_balance chunks (range proof binding)
    Sigma:
      build FS challenge scalar `e`
      Case A (sender): verify `s_v · G + s_r · P = C_v + e · (C_curr - C_new - amount·G)`
      Case B (recipient): verify `s_r · G = D_new + e · (D_curr - D_new)`
    Accept iff both checks pass; otherwise abort with ESIGMA_PROTOCOL_VERIFY_FAILED (= 65537).
```

Filling this in is Phase 4 proper; this stub is scaffolding. -/

def verifyWithdrawalBytecodeResult (_o : WithdrawalNativeOracle) (_args : List MoveValue)
    : ExecResult :=
  .error

/-- Trivial property: the stub returns `.error`. Delete this when the real sim lands. -/
@[simp] theorem verifyWithdrawalBytecodeResult_stub_is_error
    (o : WithdrawalNativeOracle) (args : List MoveValue) :
    verifyWithdrawalBytecodeResult o args = .error := rfl

end MovementFormal.Experimental.ConfidentialAsset.Withdrawal.FunctionalSim
