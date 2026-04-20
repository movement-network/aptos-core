/-
Copyright (c) Move Industries.

# Confidential-asset sigma-proof verifiers (withdrawal / normalization / rotation)

**Source:** `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move` —
functions `verify_withdrawal_sigma_proof`, `verify_normalization_sigma_proof`,
`verify_rotation_sigma_proof`, plus their Fiat–Shamir challenge functions
`fiat_shamir_{withdrawal,normalization,rotation}_sigma_proof_challenge`.

Tier 3 Layer 7: mirrors each verifier as a pure Lean predicate over
abstract curve points (`Point`) and `RistrettoScalar`. Each verifier has
the same high-level shape:

1. Decompress every `CompressedRistretto` in `proof.xs` (returns `Option`).
2. Derive the Fiat–Shamir challenge `ρ = H(DST ‖ chain_id ‖ sender ‖ contract ‖ G ‖ H ‖ P ‖ public_inputs ‖ proof.xs)`.
3. Compute the `γ` scalars: `γᵢ = H(ρ ‖ i)` (or with two indices for vector-γ).
4. Assemble `scalars_lhs`, `scalars_rhs`, `points_lhs`, `points_rhs` via
   the sigma-specific formulas in the Move module.
5. Accept iff `Σ (scalars_lhs[i] · points_lhs[i]) = Σ (scalars_rhs[i] · points_rhs[i])`.

## Design

- We mirror Move's data layout exactly (`*SigmaProofXs`, `*SigmaProofAlphas`,
  `*SigmaProofGammas`, `*SigmaProof`) for direct byte-for-byte correspondence
  with oracle JSON.
- FS challenge derivation is **concrete**: `sha2_512` is already formalized
  in `MovementFormal.AptosStd.Hash.Sha2_512`; `scalarUniformFrom64Bytes` is in
  `Ristretto255.lean`. A Lean-side regression that altered byte packing
  would produce a different scalar and break this verifier.
- MSM equation uses an abstract `multiScalarMul` function on `Point` +
  `RistrettoScalar`, which delegates to `CryptoOracle.pointAdd` and the
  module action.
- The verifier is a `Prop`; acceptance (the "accept" semantics of
  `verify_*_sigma_proof`) is `True`; rejection (Move aborts with
  `ESIGMA_PROTOCOL_VERIFY_FAILED = 65537`) corresponds to `False`.

## Out of scope here

- Ristretto encoding/decoding internals (`point_decompress`, `point_compress`):
  those come from `RistrettoEncoding` as opaque functions pinned by roundtrip axioms.
- Completeness/soundness proofs of the sigma protocols: research-level.
- Bulletproofs range-proof verifier — Layer 9.
-/

import MovementFormal.AptosStd.Crypto.EdwardsCurve25519
import MovementFormal.AptosStd.Crypto.EdwardsOracle
import MovementFormal.AptosStd.Crypto.Ristretto255
import MovementFormal.AptosStd.Crypto.RistrettoEncoding
import MovementFormal.AptosStd.Hash.Sha2_512

open MovementFormal.AptosStd.Crypto.EdwardsCurve25519
open MovementFormal.AptosStd.Crypto.EdwardsCurve25519.EdwardsPoint
open MovementFormal.AptosStd.Crypto.Ristretto255
open MovementFormal.AptosStd.Crypto.RistrettoEncoding
open MovementFormal.AptosStd.Hash.Sha2_512

namespace MovementFormal.Experimental.ConfidentialAsset.SigmaVerifiers

/-! ## Domain-separation tags (exact match to
`aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`). -/

/-- `FIAT_SHAMIR_WITHDRAWAL_SIGMA_DST = b"MovementConfidentialAsset/Withdrawal"`. -/
def withdrawalDst : ByteArray :=
  ByteArray.mk #[
    0x4d, 0x6f, 0x76, 0x65, 0x6d, 0x65, 0x6e, 0x74, 0x43, 0x6f, 0x6e, 0x66,
    0x69, 0x64, 0x65, 0x6e, 0x74, 0x69, 0x61, 0x6c, 0x41, 0x73, 0x73, 0x65,
    0x74, 0x2f, 0x57, 0x69, 0x74, 0x68, 0x64, 0x72, 0x61, 0x77, 0x61, 0x6c
  ]

theorem withdrawalDst_size : withdrawalDst.size = 36 := by native_decide

/-- `FIAT_SHAMIR_TRANSFER_SIGMA_DST = b"MovementConfidentialAsset/Transfer"`. -/
def transferDst : ByteArray :=
  ByteArray.mk #[
    0x4d, 0x6f, 0x76, 0x65, 0x6d, 0x65, 0x6e, 0x74, 0x43, 0x6f, 0x6e, 0x66,
    0x69, 0x64, 0x65, 0x6e, 0x74, 0x69, 0x61, 0x6c, 0x41, 0x73, 0x73, 0x65,
    0x74, 0x2f, 0x54, 0x72, 0x61, 0x6e, 0x73, 0x66, 0x65, 0x72
  ]

theorem transferDst_size : transferDst.size = 34 := by native_decide

/-- `FIAT_SHAMIR_ROTATION_SIGMA_DST = b"MovementConfidentialAsset/Rotation"`. -/
def rotationDst : ByteArray :=
  ByteArray.mk #[
    0x4d, 0x6f, 0x76, 0x65, 0x6d, 0x65, 0x6e, 0x74, 0x43, 0x6f, 0x6e, 0x66,
    0x69, 0x64, 0x65, 0x6e, 0x74, 0x69, 0x61, 0x6c, 0x41, 0x73, 0x73, 0x65,
    0x74, 0x2f, 0x52, 0x6f, 0x74, 0x61, 0x74, 0x69, 0x6f, 0x6e
  ]

theorem rotationDst_size : rotationDst.size = 34 := by native_decide

/-- `FIAT_SHAMIR_NORMALIZATION_SIGMA_DST = b"MovementConfidentialAsset/Normalization"`. -/
def normalizationDst : ByteArray :=
  ByteArray.mk #[
    0x4d, 0x6f, 0x76, 0x65, 0x6d, 0x65, 0x6e, 0x74, 0x43, 0x6f, 0x6e, 0x66,
    0x69, 0x64, 0x65, 0x6e, 0x74, 0x69, 0x61, 0x6c, 0x41, 0x73, 0x73, 0x65,
    0x74, 0x2f, 0x4e, 0x6f, 0x72, 0x6d, 0x61, 0x6c, 0x69, 0x7a, 0x61, 0x74,
    0x69, 0x6f, 0x6e
  ]

theorem normalizationDst_size : normalizationDst.size = 39 := by native_decide

/-! ## Shared scalar helpers mirroring `confidential_proof.move` lines 1658–1683. -/

/-- `scalar_mul_3(s1, s2, s3) = s1 * s2 * s3`. -/
def scalarMul3 (s1 s2 s3 : RistrettoScalar) : RistrettoScalar :=
  s1 * s2 * s3

/-- `scalar_linear_combination(lhs, rhs) = Σ lhs[i] * rhs[i]`. Vectors
zipped by the shorter length (matches Move's `zip_ref`). -/
def scalarLinearCombination (lhs rhs : List RistrettoScalar) : RistrettoScalar :=
  (List.zip lhs rhs).foldl (fun acc (p : RistrettoScalar × RistrettoScalar) => acc + p.1 * p.2) 0

/-- `new_scalar_from_pow2(exp) = 2^exp (mod ℓ)`. -/
def newScalarFromPow2 (exp : ℕ) : RistrettoScalar :=
  ((2 ^ exp : ℕ) : RistrettoScalar)

/-! ### `scalarToBytes` — concrete 32-LE encoding of a scalar

Mirrors Move `ristretto255::scalar_to_bytes`. We implement it by
extracting the canonical `val` of the `ZMod ℓ` scalar and emitting its
32 little-endian bytes.
-/

/-- Emit the `i`-th LE byte of a natural number `n`. -/
def natLeByte (n i : ℕ) : UInt8 :=
  UInt8.ofNat ((n / 256 ^ i) % 256)

/-- 32-LE byte encoding of a `RistrettoScalar`. -/
def scalarToBytes (s : RistrettoScalar) : ByteArray :=
  ByteArray.mk ((List.range 32).map (fun i => natLeByte s.val i)).toArray

theorem scalarToBytes_size (s : RistrettoScalar) : (scalarToBytes s).size = 32 := by
  simp [scalarToBytes, ByteArray.size]

/-! ## Fiat–Shamir γ helpers mirroring `msm_gamma_1` / `msm_gamma_2`. -/

/-- `msm_gamma_1(ρ, i) = scalar_to_bytes(ρ) ++ [i]`. -/
def msmGamma1Bytes (rho : RistrettoScalar) (i : UInt8) : ByteArray :=
  scalarToBytes rho |>.push i

/-- `msm_gamma_2(ρ, i, j) = scalar_to_bytes(ρ) ++ [i, j]`. -/
def msmGamma2Bytes (rho : RistrettoScalar) (i j : UInt8) : ByteArray :=
  (scalarToBytes rho |>.push i).push j

/-- `γ₁ᵢ = new_scalar_from_sha2_512(msm_gamma_1(ρ, i))`. -/
noncomputable def msmGamma1 (rho : RistrettoScalar) (i : UInt8) : Option RistrettoScalar :=
  scalarUniformFrom64Bytes (sha2_512 (msmGamma1Bytes rho i))

/-- `γ₂ᵢⱼ = new_scalar_from_sha2_512(msm_gamma_2(ρ, i, j))`. -/
noncomputable def msmGamma2 (rho : RistrettoScalar) (i j : UInt8) : Option RistrettoScalar :=
  scalarUniformFrom64Bytes (sha2_512 (msmGamma2Bytes rho i j))

/-! ## `prepend_domain_context`

Mirrors `confidential_proof.move:1365-1376`:
```move
context = [chain_id] ++ bcs::to_bytes(&sender) ++ bcs::to_bytes(&contract_address) ++ (old bytes)
```

`bcs::to_bytes(address)` in Aptos emits 32 little-endian bytes (a Move
`address` is 32 bytes). We carry the sender/contract as `ByteArray` pinned
to 32 bytes for direct roundtrip.
-/

/-- Aptos `address` as 32 bytes (BCS little-endian). -/
structure Address32 where
  bytes : ByteArray
  size_eq : bytes.size = 32

/-- `prepend_domain_context(bytes, chain_id, sender, contract)`. -/
def prependDomainContext (chainId : UInt8) (sender contract : Address32)
    (bytes : ByteArray) : ByteArray :=
  (((ByteArray.mk #[chainId]) ++ sender.bytes) ++ contract.bytes) ++ bytes

/-! ## Withdrawal sigma proof — data layout -/

structure WithdrawalSigmaProofXs where
  x1 : CompressedRistretto32
  x2 : CompressedRistretto32
  x3s : List CompressedRistretto32
  x4s : List CompressedRistretto32

structure WithdrawalSigmaProofAlphas where
  a1s : List RistrettoScalar
  a2 : RistrettoScalar
  a3 : RistrettoScalar
  a4s : List RistrettoScalar

structure WithdrawalSigmaProofGammas where
  g1 : RistrettoScalar
  g2 : RistrettoScalar
  g3s : List RistrettoScalar
  g4s : List RistrettoScalar

structure WithdrawalSigmaProof where
  alphas : WithdrawalSigmaProofAlphas
  xs : WithdrawalSigmaProofXs

/-- `msm_withdrawal_gammas(ρ)` — returns `none` if any γ derivation fails. -/
noncomputable def msmWithdrawalGammas (rho : RistrettoScalar) :
    Option WithdrawalSigmaProofGammas := do
  let g1 ← msmGamma1 rho 1
  let g2 ← msmGamma1 rho 2
  let g3s ← (List.range 8).mapM (fun i => msmGamma2 rho 3 (UInt8.ofNat i))
  let g4s ← (List.range 8).mapM (fun i => msmGamma2 rho 4 (UInt8.ofNat i))
  return { g1, g2, g3s, g4s }

/-! ## Normalization sigma proof -/

structure NormalizationSigmaProofXs where
  x1 : CompressedRistretto32
  x2 : CompressedRistretto32
  x3s : List CompressedRistretto32
  x4s : List CompressedRistretto32

structure NormalizationSigmaProofAlphas where
  a1s : List RistrettoScalar
  a2 : RistrettoScalar
  a3 : RistrettoScalar
  a4s : List RistrettoScalar

structure NormalizationSigmaProofGammas where
  g1 : RistrettoScalar
  g2 : RistrettoScalar
  g3s : List RistrettoScalar
  g4s : List RistrettoScalar

structure NormalizationSigmaProof where
  alphas : NormalizationSigmaProofAlphas
  xs : NormalizationSigmaProofXs

noncomputable def msmNormalizationGammas (rho : RistrettoScalar) :
    Option NormalizationSigmaProofGammas := do
  let g1 ← msmGamma1 rho 1
  let g2 ← msmGamma1 rho 2
  let g3s ← (List.range 8).mapM (fun i => msmGamma2 rho 3 (UInt8.ofNat i))
  let g4s ← (List.range 8).mapM (fun i => msmGamma2 rho 4 (UInt8.ofNat i))
  return { g1, g2, g3s, g4s }

/-! ## Rotation sigma proof -/

structure RotationSigmaProofXs where
  x1 : CompressedRistretto32
  x2 : CompressedRistretto32
  x3 : CompressedRistretto32
  x4s : List CompressedRistretto32
  x5s : List CompressedRistretto32

structure RotationSigmaProofAlphas where
  a1s : List RistrettoScalar
  a2 : RistrettoScalar
  a3 : RistrettoScalar
  a4 : RistrettoScalar
  a5s : List RistrettoScalar

structure RotationSigmaProofGammas where
  g1 : RistrettoScalar
  g2 : RistrettoScalar
  g3 : RistrettoScalar
  g4s : List RistrettoScalar
  g5s : List RistrettoScalar

structure RotationSigmaProof where
  alphas : RotationSigmaProofAlphas
  xs : RotationSigmaProofXs

noncomputable def msmRotationGammas (rho : RistrettoScalar) :
    Option RotationSigmaProofGammas := do
  let g1 ← msmGamma1 rho 1
  let g2 ← msmGamma1 rho 2
  let g3 ← msmGamma1 rho 3
  let g4s ← (List.range 8).mapM (fun i => msmGamma2 rho 4 (UInt8.ofNat i))
  let g5s ← (List.range 8).mapM (fun i => msmGamma2 rho 5 (UInt8.ofNat i))
  return { g1, g2, g3, g4s, g5s }

/-! ## Confidential balance as points (matches `confidential_balance.move`) -/

/-- A compressed confidential balance: sequence of per-chunk twisted-ElGamal
ciphertexts `(C, D)`. Full balances use 8 chunks, u64 amounts use 4. -/
structure CompressedConfidentialBalance where
  cChunks : List CompressedRistretto32
  dChunks : List CompressedRistretto32

/-- `balance_to_bytes(balance) = concat of compress(C_i) ++ compress(D_i) for each chunk`. -/
def balanceToBytes (b : CompressedConfidentialBalance) : ByteArray :=
  (b.cChunks.foldl (fun acc c => acc ++ c.bytes) ByteArray.empty) ++
    (b.dChunks.foldl (fun acc d => acc ++ d.bytes) ByteArray.empty)

/-! ## Fiat–Shamir challenge construction — withdrawal -/

/-- FS message bytes before DST prepend + prepend_domain_context. -/
noncomputable def withdrawalFsBodyBytes
    (ek : CompressedRistretto32)
    (amountChunks : List RistrettoScalar)
    (currentBalance : CompressedConfidentialBalance)
    (xs : WithdrawalSigmaProofXs) : ByteArray :=
  let basepointBytes := ristrettoBasepointBytes
  let hBytes := confidentialAssetHashBaseBytes
  let ekBytes := ek.bytes
  let amtBytes := amountChunks.foldl (fun acc s => acc ++ scalarToBytes s) ByteArray.empty
  let balBytes := balanceToBytes currentBalance
  let x1b := xs.x1.bytes
  let x2b := xs.x2.bytes
  let x3b := xs.x3s.foldl (fun acc c => acc ++ c.bytes) ByteArray.empty
  let x4b := xs.x4s.foldl (fun acc c => acc ++ c.bytes) ByteArray.empty
  basepointBytes ++ hBytes ++ ekBytes ++ amtBytes ++ balBytes ++ x1b ++ x2b ++ x3b ++ x4b

/-- Complete FS challenge for the withdrawal sigma proof. -/
noncomputable def fiatShamirWithdrawal
    (chainId : UInt8) (sender contract : Address32)
    (ek : CompressedRistretto32)
    (amountChunks : List RistrettoScalar)
    (currentBalance : CompressedConfidentialBalance)
    (xs : WithdrawalSigmaProofXs) : Option RistrettoScalar :=
  let body := withdrawalFsBodyBytes ek amountChunks currentBalance xs
  let prefixBytes := prependDomainContext chainId sender contract body
  scalarUniformFrom64Bytes (sha2_512 (withdrawalDst ++ prefixBytes))

/-! ## Fiat–Shamir challenge construction — normalization -/

noncomputable def normalizationFsBodyBytes
    (ek : CompressedRistretto32)
    (currentBalance newBalance : CompressedConfidentialBalance)
    (xs : NormalizationSigmaProofXs) : ByteArray :=
  let basepointBytes := ristrettoBasepointBytes
  let hBytes := confidentialAssetHashBaseBytes
  let ekBytes := ek.bytes
  let curBytes := balanceToBytes currentBalance
  let newBytes := balanceToBytes newBalance
  let x1b := xs.x1.bytes
  let x2b := xs.x2.bytes
  let x3b := xs.x3s.foldl (fun acc c => acc ++ c.bytes) ByteArray.empty
  let x4b := xs.x4s.foldl (fun acc c => acc ++ c.bytes) ByteArray.empty
  basepointBytes ++ hBytes ++ ekBytes ++ curBytes ++ newBytes ++ x1b ++ x2b ++ x3b ++ x4b

noncomputable def fiatShamirNormalization
    (chainId : UInt8) (sender contract : Address32)
    (ek : CompressedRistretto32)
    (currentBalance newBalance : CompressedConfidentialBalance)
    (xs : NormalizationSigmaProofXs) : Option RistrettoScalar :=
  let body := normalizationFsBodyBytes ek currentBalance newBalance xs
  let prefixBytes := prependDomainContext chainId sender contract body
  scalarUniformFrom64Bytes (sha2_512 (normalizationDst ++ prefixBytes))

/-! ## Fiat–Shamir challenge construction — rotation -/

noncomputable def rotationFsBodyBytes
    (currentEk newEk : CompressedRistretto32)
    (currentBalance newBalance : CompressedConfidentialBalance)
    (xs : RotationSigmaProofXs) : ByteArray :=
  let basepointBytes := ristrettoBasepointBytes
  let hBytes := confidentialAssetHashBaseBytes
  let curEkBytes := currentEk.bytes
  let newEkBytes := newEk.bytes
  let curBalBytes := balanceToBytes currentBalance
  let newBalBytes := balanceToBytes newBalance
  let x1b := xs.x1.bytes
  let x2b := xs.x2.bytes
  let x3b := xs.x3.bytes
  let x4b := xs.x4s.foldl (fun acc c => acc ++ c.bytes) ByteArray.empty
  let x5b := xs.x5s.foldl (fun acc c => acc ++ c.bytes) ByteArray.empty
  basepointBytes ++ hBytes ++ curEkBytes ++ newEkBytes ++ curBalBytes ++ newBalBytes ++ x1b ++ x2b ++ x3b ++ x4b ++ x5b

noncomputable def fiatShamirRotation
    (chainId : UInt8) (sender contract : Address32)
    (currentEk newEk : CompressedRistretto32)
    (currentBalance newBalance : CompressedConfidentialBalance)
    (xs : RotationSigmaProofXs) : Option RistrettoScalar :=
  let body := rotationFsBodyBytes currentEk newEk currentBalance newBalance xs
  let prefixBytes := prependDomainContext chainId sender contract body
  scalarUniformFrom64Bytes (sha2_512 (rotationDst ++ prefixBytes))

/-! ## Abstract MSM and decompressed confidential balance -/

/-- Decompressed confidential balance. -/
structure ConfidentialBalancePoints (Point : Type) where
  cChunks : List Point
  dChunks : List Point

/-- Multi-scalar multiplication of paired vectors. -/
noncomputable def multiScalarMul {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]
    (scalars : List RistrettoScalar) (points : List Point) : Point :=
  (List.zip scalars points).foldl (fun acc (p : RistrettoScalar × Point) => acc + p.1 • p.2) 0

/-! ## Withdrawal verifier predicate

Shape of `verify_withdrawal_sigma_proof` (lines 477-574 of `confidential_proof.move`):

```
ρ  := fiat_shamir_withdrawal(chain_id, sender, contract, ek, amount_chunks, current_balance, proof.xs)
γ  := msm_withdrawal_gammas(ρ)
LHS := Σᵢ γ_lhs_i · decompress(proof.xs.i)      -- 18 points
RHS := scalar_g · G + scalar_h · H + scalar_ek · P
       + Σᵢ (scalar_cur_d_i · cur.D_i + scalar_new_d_i · new.D_i
            + scalar_cur_c_i · cur.C_i + scalar_new_c_i · new.C_i)
accept iff LHS = RHS.
```

We extract the scalar formulas directly from the Move source.
-/

namespace WithdrawalRHS

/-- `scalar_g` (line 513-522 of `confidential_proof.move`). Represents the
multiplier of `G` in the verification MSM. -/
def scalarG (γ : WithdrawalSigmaProofGammas) (α : WithdrawalSigmaProofAlphas)
    (ρ : RistrettoScalar) (amount : RistrettoScalar) : RistrettoScalar :=
  let powers := (List.range 8).map (fun i => newScalarFromPow2 (i * 16))
  let lhs1 := scalarLinearCombination α.a1s powers * γ.g1
  let lhs2 := scalarLinearCombination γ.g3s α.a1s
  let sub := scalarMul3 γ.g1 ρ amount
  lhs1 + lhs2 - sub

/-- `scalar_h` (line 524-528). Multiplier of `H`. -/
def scalarH (γ : WithdrawalSigmaProofGammas) (α : WithdrawalSigmaProofAlphas) :
    RistrettoScalar :=
  γ.g2 * α.a3 + scalarLinearCombination γ.g3s α.a4s

/-- `scalar_ek` (line 530-534). Multiplier of the sender's public key. -/
def scalarEk (γ : WithdrawalSigmaProofGammas) (α : WithdrawalSigmaProofAlphas)
    (ρ : RistrettoScalar) : RistrettoScalar :=
  γ.g2 * ρ + scalarLinearCombination γ.g4s α.a4s

/-- `scalars_current_balance_d` (line 536-538). 8 scalars; i-th is
`γ.g1 * α.a2 * 2^(16i)`. -/
def scalarsCurDs (γ : WithdrawalSigmaProofGammas) (α : WithdrawalSigmaProofAlphas) :
    List RistrettoScalar :=
  (List.range 8).map (fun i => scalarMul3 γ.g1 α.a2 (newScalarFromPow2 (i * 16)))

/-- `scalars_new_balance_d` (line 540-542). 8 scalars; i-th is `γ.g4s[i] * ρ`. -/
def scalarsNewDs (γ : WithdrawalSigmaProofGammas) (ρ : RistrettoScalar) :
    List RistrettoScalar :=
  γ.g4s.map (fun g => g * ρ)

/-- `scalars_current_balance_c` (line 544-546). i-th is `γ.g1 * ρ * 2^(16i)`. -/
def scalarsCurCs (γ : WithdrawalSigmaProofGammas) (ρ : RistrettoScalar) :
    List RistrettoScalar :=
  (List.range 8).map (fun i => scalarMul3 γ.g1 ρ (newScalarFromPow2 (i * 16)))

/-- `scalars_new_balance_c` (line 548-550). i-th is `γ.g3s[i] * ρ`. -/
def scalarsNewCs (γ : WithdrawalSigmaProofGammas) (ρ : RistrettoScalar) :
    List RistrettoScalar :=
  γ.g3s.map (fun g => g * ρ)

end WithdrawalRHS

/-- Full withdrawal verifier predicate, parameterized over an abstract
`Point` type and a concrete `CryptoOracle`-style decoder. -/
noncomputable def verifyWithdrawalSigmaProof
    {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]
    (basepointG : Point) (hashBaseH : Point)
    (decode : CompressedRistretto32 → Option Point)
    (pubkeyToPoint : CompressedRistretto32 → Option Point)
    (balanceToPoints : CompressedConfidentialBalance → ConfidentialBalancePoints Point)
    (chainId : UInt8) (sender contract : Address32)
    (ek : CompressedRistretto32)
    (amount : RistrettoScalar) (amountChunks : List RistrettoScalar)
    (currentBalance newBalance : CompressedConfidentialBalance)
    (proof : WithdrawalSigmaProof) : Prop :=
  match fiatShamirWithdrawal chainId sender contract ek amountChunks currentBalance proof.xs,
        decode proof.xs.x1, decode proof.xs.x2,
        proof.xs.x3s.mapM decode, proof.xs.x4s.mapM decode,
        pubkeyToPoint ek with
  | some ρ, some X1, some X2, some X3s, some X4s, some P =>
      match msmWithdrawalGammas ρ with
      | some γ =>
          let curPoints := balanceToPoints currentBalance
          let newPoints := balanceToPoints newBalance
          let scalarsLhs := [γ.g1, γ.g2] ++ γ.g3s ++ γ.g4s
          let pointsLhs := [X1, X2] ++ X3s ++ X4s
          let sG := WithdrawalRHS.scalarG γ proof.alphas ρ amount
          let sH := WithdrawalRHS.scalarH γ proof.alphas
          let sEk := WithdrawalRHS.scalarEk γ proof.alphas ρ
          let sCurDs := WithdrawalRHS.scalarsCurDs γ proof.alphas
          let sNewDs := WithdrawalRHS.scalarsNewDs γ ρ
          let sCurCs := WithdrawalRHS.scalarsCurCs γ ρ
          let sNewCs := WithdrawalRHS.scalarsNewCs γ ρ
          let scalarsRhs := [sG, sH, sEk] ++ sCurDs ++ sNewDs ++ sCurCs ++ sNewCs
          let pointsRhs := [basepointG, hashBaseH, P]
            ++ curPoints.dChunks ++ newPoints.dChunks
            ++ curPoints.cChunks ++ newPoints.cChunks
          multiScalarMul scalarsLhs pointsLhs = multiScalarMul scalarsRhs pointsRhs
      | none => False
  | _, _, _, _, _, _ => False

/-! ## Normalization verifier predicate -/

namespace NormalizationRHS

def scalarG (γ : NormalizationSigmaProofGammas) (α : NormalizationSigmaProofAlphas) :
    RistrettoScalar :=
  let powers := (List.range 8).map (fun i => newScalarFromPow2 (i * 16))
  let lhs1 := scalarLinearCombination α.a1s powers * γ.g1
  let lhs2 := scalarLinearCombination γ.g3s α.a1s
  lhs1 + lhs2

def scalarH (γ : NormalizationSigmaProofGammas) (α : NormalizationSigmaProofAlphas) :
    RistrettoScalar :=
  γ.g2 * α.a3 + scalarLinearCombination γ.g3s α.a4s

def scalarEk (γ : NormalizationSigmaProofGammas) (α : NormalizationSigmaProofAlphas)
    (ρ : RistrettoScalar) : RistrettoScalar :=
  γ.g2 * ρ + scalarLinearCombination γ.g4s α.a4s

def scalarsCurDs (γ : NormalizationSigmaProofGammas) (α : NormalizationSigmaProofAlphas) :
    List RistrettoScalar :=
  (List.range 8).map (fun i => scalarMul3 γ.g1 α.a2 (newScalarFromPow2 (i * 16)))

def scalarsNewDs (γ : NormalizationSigmaProofGammas) (ρ : RistrettoScalar) :
    List RistrettoScalar :=
  γ.g4s.map (fun g => g * ρ)

def scalarsCurCs (γ : NormalizationSigmaProofGammas) (ρ : RistrettoScalar) :
    List RistrettoScalar :=
  (List.range 8).map (fun i => scalarMul3 γ.g1 ρ (newScalarFromPow2 (i * 16)))

def scalarsNewCs (γ : NormalizationSigmaProofGammas) (ρ : RistrettoScalar) :
    List RistrettoScalar :=
  γ.g3s.map (fun g => g * ρ)

end NormalizationRHS

noncomputable def verifyNormalizationSigmaProof
    {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]
    (basepointG hashBaseH : Point)
    (decode : CompressedRistretto32 → Option Point)
    (pubkeyToPoint : CompressedRistretto32 → Option Point)
    (balanceToPoints : CompressedConfidentialBalance → ConfidentialBalancePoints Point)
    (chainId : UInt8) (sender contract : Address32)
    (ek : CompressedRistretto32)
    (currentBalance newBalance : CompressedConfidentialBalance)
    (proof : NormalizationSigmaProof) : Prop :=
  match fiatShamirNormalization chainId sender contract ek currentBalance newBalance proof.xs,
        decode proof.xs.x1, decode proof.xs.x2,
        proof.xs.x3s.mapM decode, proof.xs.x4s.mapM decode,
        pubkeyToPoint ek with
  | some ρ, some X1, some X2, some X3s, some X4s, some P =>
      match msmNormalizationGammas ρ with
      | some γ =>
          let curPoints := balanceToPoints currentBalance
          let newPoints := balanceToPoints newBalance
          let scalarsLhs := [γ.g1, γ.g2] ++ γ.g3s ++ γ.g4s
          let pointsLhs := [X1, X2] ++ X3s ++ X4s
          let sG := NormalizationRHS.scalarG γ proof.alphas
          let sH := NormalizationRHS.scalarH γ proof.alphas
          let sEk := NormalizationRHS.scalarEk γ proof.alphas ρ
          let sCurDs := NormalizationRHS.scalarsCurDs γ proof.alphas
          let sNewDs := NormalizationRHS.scalarsNewDs γ ρ
          let sCurCs := NormalizationRHS.scalarsCurCs γ ρ
          let sNewCs := NormalizationRHS.scalarsNewCs γ ρ
          let scalarsRhs := [sG, sH, sEk] ++ sCurDs ++ sNewDs ++ sCurCs ++ sNewCs
          let pointsRhs := [basepointG, hashBaseH, P]
            ++ curPoints.dChunks ++ newPoints.dChunks
            ++ curPoints.cChunks ++ newPoints.cChunks
          multiScalarMul scalarsLhs pointsLhs = multiScalarMul scalarsRhs pointsRhs
      | none => False
  | _, _, _, _, _, _ => False

/-! ## Rotation verifier predicate

Rotation proves that a `ConfidentialBalance` encrypted under
`current_ek` is re-encrypted under `new_ek` to the same plaintext.
Uses 3 distinct `x*` field commitments (x1, x2, x3) plus x4s/x5s for
per-chunk witnesses.
-/

namespace RotationRHS

def scalarG (γ : RotationSigmaProofGammas) (α : RotationSigmaProofAlphas) :
    RistrettoScalar :=
  let powers := (List.range 8).map (fun i => newScalarFromPow2 (i * 16))
  let lhs1 := scalarLinearCombination α.a1s powers * γ.g1
  let lhs2 := scalarLinearCombination γ.g4s α.a1s
  lhs1 + lhs2

def scalarH (γ : RotationSigmaProofGammas) (α : RotationSigmaProofAlphas) :
    RistrettoScalar :=
  γ.g2 * α.a3 + γ.g3 * α.a4 + scalarLinearCombination γ.g4s α.a5s

/-- `scalar_ek_cur = γ.g2 * ρ`. Mirrors `verify_rotation_sigma_proof` line 924. -/
def scalarCurEk (γ : RotationSigmaProofGammas) (ρ : RistrettoScalar) : RistrettoScalar :=
  γ.g2 * ρ

/-- `scalar_ek_new = γ.g3 * ρ + Σ γ.g5s[i] * α.a5s[i]`. Mirrors lines 926-930. -/
def scalarNewEk (γ : RotationSigmaProofGammas) (α : RotationSigmaProofAlphas)
    (ρ : RistrettoScalar) : RistrettoScalar :=
  γ.g3 * ρ + scalarLinearCombination γ.g5s α.a5s

def scalarsCurDs (γ : RotationSigmaProofGammas) (α : RotationSigmaProofAlphas) :
    List RistrettoScalar :=
  (List.range 8).map (fun i => scalarMul3 γ.g1 α.a2 (newScalarFromPow2 (i * 16)))

/-- `scalars_new_balance_d[i] = γ.g5s[i] * ρ`. Mirrors line 937. -/
def scalarsNewDs (γ : RotationSigmaProofGammas) (ρ : RistrettoScalar) :
    List RistrettoScalar :=
  γ.g5s.map (fun g => g * ρ)

def scalarsCurCs (γ : RotationSigmaProofGammas) (ρ : RistrettoScalar) :
    List RistrettoScalar :=
  (List.range 8).map (fun i => scalarMul3 γ.g1 ρ (newScalarFromPow2 (i * 16)))

/-- `scalars_new_balance_c[i] = γ.g4s[i] * ρ`. Mirrors line 945. -/
def scalarsNewCs (γ : RotationSigmaProofGammas) (ρ : RistrettoScalar) :
    List RistrettoScalar :=
  γ.g4s.map (fun g => g * ρ)

end RotationRHS

noncomputable def verifyRotationSigmaProof
    {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]
    (basepointG hashBaseH : Point)
    (decode : CompressedRistretto32 → Option Point)
    (pubkeyToPoint : CompressedRistretto32 → Option Point)
    (balanceToPoints : CompressedConfidentialBalance → ConfidentialBalancePoints Point)
    (chainId : UInt8) (sender contract : Address32)
    (currentEk newEk : CompressedRistretto32)
    (currentBalance newBalance : CompressedConfidentialBalance)
    (proof : RotationSigmaProof) : Prop :=
  match fiatShamirRotation chainId sender contract currentEk newEk currentBalance newBalance proof.xs,
        decode proof.xs.x1, decode proof.xs.x2, decode proof.xs.x3,
        proof.xs.x4s.mapM decode, proof.xs.x5s.mapM decode,
        pubkeyToPoint currentEk, pubkeyToPoint newEk with
  | some ρ, some X1, some X2, some X3, some X4s, some X5s, some PCur, some PNew =>
      match msmRotationGammas ρ with
      | some γ =>
          let curPoints := balanceToPoints currentBalance
          let newPoints := balanceToPoints newBalance
          let scalarsLhs := [γ.g1, γ.g2, γ.g3] ++ γ.g4s ++ γ.g5s
          let pointsLhs := [X1, X2, X3] ++ X4s ++ X5s
          let sG := RotationRHS.scalarG γ proof.alphas
          let sH := RotationRHS.scalarH γ proof.alphas
          let sCurEk := RotationRHS.scalarCurEk γ ρ
          let sNewEk := RotationRHS.scalarNewEk γ proof.alphas ρ
          let sCurDs := RotationRHS.scalarsCurDs γ proof.alphas
          let sNewDs := RotationRHS.scalarsNewDs γ ρ
          let sCurCs := RotationRHS.scalarsCurCs γ ρ
          let sNewCs := RotationRHS.scalarsNewCs γ ρ
          let scalarsRhs := [sG, sH, sCurEk, sNewEk] ++ sCurDs ++ sNewDs ++ sCurCs ++ sNewCs
          let pointsRhs := [basepointG, hashBaseH, PCur, PNew]
            ++ curPoints.dChunks ++ newPoints.dChunks
            ++ curPoints.cChunks ++ newPoints.cChunks
          multiScalarMul scalarsLhs pointsLhs = multiScalarMul scalarsRhs pointsRhs
      | none => False
  | _, _, _, _, _, _, _, _ => False

/-! ## Transfer sigma proof — data layout

Matches `confidential_proof.move` lines 105-139. Auditors are indexed
dynamically; the proof carries a `vector<vector<CompressedRistretto>>`
for per-auditor amount witnesses.
-/

structure TransferSigmaProofXs where
  x1 : CompressedRistretto32
  x2s : List CompressedRistretto32
  x3s : List CompressedRistretto32
  x4s : List CompressedRistretto32
  x5 : CompressedRistretto32
  x6s : List CompressedRistretto32
  x7s : List (List CompressedRistretto32)
  x8s : List CompressedRistretto32

structure TransferSigmaProofAlphas where
  a1s : List RistrettoScalar
  a2 : RistrettoScalar
  a3s : List RistrettoScalar
  a4s : List RistrettoScalar
  a5 : RistrettoScalar
  a6s : List RistrettoScalar

structure TransferSigmaProofGammas where
  g1 : RistrettoScalar
  g2s : List RistrettoScalar
  g3s : List RistrettoScalar
  g4s : List RistrettoScalar
  g5 : RistrettoScalar
  g6s : List RistrettoScalar
  g7s : List (List RistrettoScalar)
  g8s : List RistrettoScalar

structure TransferSigmaProof where
  alphas : TransferSigmaProofAlphas
  xs : TransferSigmaProofXs

/-- `msm_transfer_gammas(ρ, auditors_count)` — lines 1584-1611. -/
noncomputable def msmTransferGammas (rho : RistrettoScalar) (auditorsCount : ℕ) :
    Option TransferSigmaProofGammas := do
  let g1 ← msmGamma1 rho 1
  let g2s ← (List.range 8).mapM (fun i => msmGamma2 rho 2 (UInt8.ofNat i))
  let g3s ← (List.range 4).mapM (fun i => msmGamma2 rho 3 (UInt8.ofNat i))
  let g4s ← (List.range 4).mapM (fun i => msmGamma2 rho 4 (UInt8.ofNat i))
  let g5 ← msmGamma1 rho 5
  let g6s ← (List.range 8).mapM (fun i => msmGamma2 rho 6 (UInt8.ofNat i))
  let g7s ← (List.range auditorsCount).mapM (fun i =>
    (List.range 4).mapM (fun j =>
      msmGamma2 rho (UInt8.ofNat (i + 7)) (UInt8.ofNat j)))
  let g8s ← (List.range 4).mapM (fun i =>
    msmGamma2 rho (UInt8.ofNat (auditorsCount + 7)) (UInt8.ofNat i))
  return { g1, g2s, g3s, g4s, g5, g6s, g7s, g8s }

/-! ## Fiat–Shamir challenge for transfer -/

/-- FS body (before DST + domain context).

Mirrors `fiat_shamir_transfer_sigma_proof_challenge` lines 1422-1492. -/
noncomputable def transferFsBodyBytes
    (senderEk recipientEk : CompressedRistretto32)
    (auditorEks : List CompressedRistretto32)
    (currentBalance recipientAmount : CompressedConfidentialBalance)
    (auditorAmounts : List CompressedConfidentialBalance)
    (senderAmount : CompressedConfidentialBalance)
    (newBalance : CompressedConfidentialBalance)
    (senderAuditorHint : ByteArray)
    (xs : TransferSigmaProofXs) : ByteArray :=
  let basepointBytes := ristrettoBasepointBytes
  let hBytes := confidentialAssetHashBaseBytes
  let sEk := senderEk.bytes
  let rEk := recipientEk.bytes
  let audEks := auditorEks.foldl (fun acc e => acc ++ e.bytes) ByteArray.empty
  let curBal := balanceToBytes currentBalance
  let recAmt := balanceToBytes recipientAmount
  let audAmtsD := auditorAmounts.foldl (fun acc bal =>
    bal.dChunks.foldl (fun a c => a ++ c.bytes) acc) ByteArray.empty
  let sendAmtD := senderAmount.dChunks.foldl (fun acc c => acc ++ c.bytes) ByteArray.empty
  let newBal := balanceToBytes newBalance
  let x1b := xs.x1.bytes
  let x2b := xs.x2s.foldl (fun a c => a ++ c.bytes) ByteArray.empty
  let x3b := xs.x3s.foldl (fun a c => a ++ c.bytes) ByteArray.empty
  let x4b := xs.x4s.foldl (fun a c => a ++ c.bytes) ByteArray.empty
  let x5b := xs.x5.bytes
  let x6b := xs.x6s.foldl (fun a c => a ++ c.bytes) ByteArray.empty
  let x7b := xs.x7s.foldl (fun a xss => xss.foldl (fun a2 c => a2 ++ c.bytes) a) ByteArray.empty
  let x8b := xs.x8s.foldl (fun a c => a ++ c.bytes) ByteArray.empty
  basepointBytes ++ hBytes ++ sEk ++ rEk ++ audEks
    ++ curBal ++ recAmt ++ audAmtsD ++ sendAmtD ++ newBal
    ++ x1b ++ x2b ++ x3b ++ x4b ++ x5b ++ x6b ++ x7b ++ x8b
    ++ senderAuditorHint

noncomputable def fiatShamirTransfer
    (chainId : UInt8) (sender contract : Address32)
    (senderEk recipientEk : CompressedRistretto32)
    (auditorEks : List CompressedRistretto32)
    (currentBalance recipientAmount : CompressedConfidentialBalance)
    (auditorAmounts : List CompressedConfidentialBalance)
    (senderAmount : CompressedConfidentialBalance)
    (newBalance : CompressedConfidentialBalance)
    (senderAuditorHint : ByteArray)
    (xs : TransferSigmaProofXs) : Option RistrettoScalar :=
  let body := transferFsBodyBytes senderEk recipientEk auditorEks
    currentBalance recipientAmount auditorAmounts senderAmount newBalance
    senderAuditorHint xs
  let prefixBytes := prependDomainContext chainId sender contract body
  scalarUniformFrom64Bytes (sha2_512 (transferDst ++ prefixBytes))

/-! ## Transfer verifier RHS formulas -/

namespace TransferRHS

/-- `scalar_g` lines 633-647. -/
def scalarG (γ : TransferSigmaProofGammas) (α : TransferSigmaProofAlphas) :
    RistrettoScalar :=
  let powers := (List.range 8).map (fun i => newScalarFromPow2 (i * 16))
  let lhs1 := scalarLinearCombination α.a1s powers * γ.g1
  let lhs2 := scalarLinearCombination γ.g4s α.a4s
  let lhs3 := scalarLinearCombination γ.g6s α.a1s
  lhs1 + lhs2 + lhs3

/-- `scalar_h` lines 649-669. -/
def scalarH (γ : TransferSigmaProofGammas) (α : TransferSigmaProofAlphas) :
    RistrettoScalar :=
  let base := γ.g5 * α.a5
  let addPos := (List.range 8).foldl
    (fun acc i => acc + scalarMul3 γ.g1 α.a6s[i]! (newScalarFromPow2 (i * 16))) 0
  let subNeg := (List.range 4).foldl
    (fun acc i => acc + scalarMul3 γ.g1 α.a3s[i]! (newScalarFromPow2 (i * 16))) 0
  let addG4 := scalarLinearCombination γ.g4s α.a3s
  let addG6 := scalarLinearCombination γ.g6s α.a6s
  base + addPos - subNeg + addG4 + addG6

/-- `scalar_sender_ek` lines 671-676. -/
def scalarSenderEk (γ : TransferSigmaProofGammas) (α : TransferSigmaProofAlphas)
    (ρ : RistrettoScalar) : RistrettoScalar :=
  scalarLinearCombination γ.g2s α.a6s + γ.g5 * ρ + scalarLinearCombination γ.g8s α.a3s

/-- `scalar_recipient_ek` lines 678-684. -/
def scalarRecipientEk (γ : TransferSigmaProofGammas) (α : TransferSigmaProofAlphas) :
    RistrettoScalar :=
  (List.range 4).foldl (fun acc i => acc + γ.g3s[i]! * α.a3s[i]!) 0

/-- One scalar per auditor: `Σᵢ γ.g7s[k][i] * α.a3s[i]` (lines 686-695). -/
def scalarEkAuditors (γ : TransferSigmaProofGammas) (α : TransferSigmaProofAlphas) :
    List RistrettoScalar :=
  γ.g7s.map (fun gamma =>
    (List.range 4).foldl (fun acc i => acc + gamma[i]! * α.a3s[i]!) 0)

/-- `scalars_new_balance_d` lines 697-704: 8 scalars. -/
def scalarsNewDs (γ : TransferSigmaProofGammas) (α : TransferSigmaProofAlphas)
    (ρ : RistrettoScalar) : List RistrettoScalar :=
  (List.range 8).map (fun i =>
    γ.g2s[i]! * ρ - scalarMul3 γ.g1 α.a2 (newScalarFromPow2 (i * 16)))

/-- `scalars_recipient_amount_d` lines 706-708: 4 scalars. -/
def scalarsRecipientDs (γ : TransferSigmaProofGammas) (ρ : RistrettoScalar) :
    List RistrettoScalar :=
  γ.g3s.map (fun g => g * ρ)

/-- `scalars_current_balance_d` lines 710-712: 8 scalars. -/
def scalarsCurDs (γ : TransferSigmaProofGammas) (α : TransferSigmaProofAlphas) :
    List RistrettoScalar :=
  (List.range 8).map (fun i => scalarMul3 γ.g1 α.a2 (newScalarFromPow2 (i * 16)))

/-- `scalars_auditor_amount_d` lines 714-716. Auditor×4 scalars. -/
def scalarsAuditorDs (γ : TransferSigmaProofGammas) (ρ : RistrettoScalar) :
    List (List RistrettoScalar) :=
  γ.g7s.map (fun gamma => gamma.map (fun g => g * ρ))

/-- `scalars_sender_amount_d` lines 718-720: 4 scalars. -/
def scalarsSenderDs (γ : TransferSigmaProofGammas) (ρ : RistrettoScalar) :
    List RistrettoScalar :=
  γ.g8s.map (fun g => g * ρ)

/-- `scalars_current_balance_c` lines 722-724: 8 scalars. -/
def scalarsCurCs (γ : TransferSigmaProofGammas) (ρ : RistrettoScalar) :
    List RistrettoScalar :=
  (List.range 8).map (fun i => scalarMul3 γ.g1 ρ (newScalarFromPow2 (i * 16)))

/-- `scalars_transfer_amount_c` lines 726-733: 4 scalars. -/
def scalarsTransferAmountCs (γ : TransferSigmaProofGammas) (ρ : RistrettoScalar) :
    List RistrettoScalar :=
  (List.range 4).map (fun i =>
    γ.g4s[i]! * ρ - scalarMul3 γ.g1 ρ (newScalarFromPow2 (i * 16)))

/-- `scalars_new_balance_c` lines 735-737: 8 scalars. -/
def scalarsNewCs (γ : TransferSigmaProofGammas) (ρ : RistrettoScalar) :
    List RistrettoScalar :=
  γ.g6s.map (fun g => g * ρ)

end TransferRHS

/-- Full transfer verifier predicate. -/
noncomputable def verifyTransferSigmaProof
    {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]
    (basepointG hashBaseH : Point)
    (decode : CompressedRistretto32 → Option Point)
    (pubkeyToPoint : CompressedRistretto32 → Option Point)
    (balanceToPoints : CompressedConfidentialBalance → ConfidentialBalancePoints Point)
    (chainId : UInt8) (sender contract : Address32)
    (senderEk recipientEk : CompressedRistretto32)
    (auditorEks : List CompressedRistretto32)
    (currentBalance recipientAmount : CompressedConfidentialBalance)
    (auditorAmounts : List CompressedConfidentialBalance)
    (senderAmount newBalance : CompressedConfidentialBalance)
    (senderAuditorHint : ByteArray)
    (proof : TransferSigmaProof) : Prop :=
  match fiatShamirTransfer chainId sender contract senderEk recipientEk auditorEks
          currentBalance recipientAmount auditorAmounts senderAmount newBalance
          senderAuditorHint proof.xs,
        decode proof.xs.x1,
        proof.xs.x2s.mapM decode, proof.xs.x3s.mapM decode, proof.xs.x4s.mapM decode,
        decode proof.xs.x5,
        proof.xs.x6s.mapM decode,
        proof.xs.x7s.mapM (fun xs => xs.mapM decode),
        proof.xs.x8s.mapM decode,
        pubkeyToPoint senderEk, pubkeyToPoint recipientEk,
        auditorEks.mapM pubkeyToPoint with
  | some ρ, some X1, some X2s, some X3s, some X4s, some X5, some X6s, some X7s, some X8s,
    some PS, some PR, some auditorPks =>
      match msmTransferGammas ρ proof.xs.x7s.length with
      | some γ =>
          let curPoints := balanceToPoints currentBalance
          let recPoints := balanceToPoints recipientAmount
          let newPoints := balanceToPoints newBalance
          let sendPoints := balanceToPoints senderAmount
          let audPoints := auditorAmounts.map balanceToPoints
          let scalarsLhs := [γ.g1] ++ γ.g2s ++ γ.g3s ++ γ.g4s ++ [γ.g5] ++ γ.g6s
            ++ γ.g7s.flatten ++ γ.g8s
          let pointsLhs := [X1] ++ X2s ++ X3s ++ X4s ++ [X5] ++ X6s ++ X7s.flatten ++ X8s
          let sG := TransferRHS.scalarG γ proof.alphas
          let sH := TransferRHS.scalarH γ proof.alphas
          let sSendEk := TransferRHS.scalarSenderEk γ proof.alphas ρ
          let sRecEk := TransferRHS.scalarRecipientEk γ proof.alphas
          let sAudEks := TransferRHS.scalarEkAuditors γ proof.alphas
          let sNewDs := TransferRHS.scalarsNewDs γ proof.alphas ρ
          let sRecDs := TransferRHS.scalarsRecipientDs γ ρ
          let sCurDs := TransferRHS.scalarsCurDs γ proof.alphas
          let sAudDs := TransferRHS.scalarsAuditorDs γ ρ
          let sSendDs := TransferRHS.scalarsSenderDs γ ρ
          let sCurCs := TransferRHS.scalarsCurCs γ ρ
          let sXferCs := TransferRHS.scalarsTransferAmountCs γ ρ
          let sNewCs := TransferRHS.scalarsNewCs γ ρ
          let scalarsRhs := [sG, sH, sSendEk, sRecEk] ++ sAudEks
            ++ sNewDs ++ sRecDs ++ sCurDs ++ sAudDs.flatten ++ sSendDs
            ++ sCurCs ++ sXferCs ++ sNewCs
          let pointsRhs := [basepointG, hashBaseH, PS, PR] ++ auditorPks
            ++ newPoints.dChunks ++ recPoints.dChunks ++ curPoints.dChunks
            ++ (audPoints.map (fun p => p.dChunks)).flatten ++ sendPoints.dChunks
            ++ curPoints.cChunks ++ recPoints.cChunks ++ newPoints.cChunks
          multiScalarMul scalarsLhs pointsLhs = multiScalarMul scalarsRhs pointsRhs
      | none => False
  | _, _, _, _, _, _, _, _, _, _, _, _ => False

end MovementFormal.Experimental.ConfidentialAsset.SigmaVerifiers
