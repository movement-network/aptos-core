/-
Copyright (c) Move Industries.

# Registration Fiat–Shamir `msg` — Move vs Lean byte alignment

**Source:** `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`; goldens `aptos-move/framework/aptos-experimental/tests/confidential_asset/formal_goldens_registration.move`.

Machine-checked equality between:

- `registrationFiatShamirMsg` (`Formal.lean`), with `AptosAddress32` standing in for BCS `address`, and
- the **same** byte layout as `aptos_experimental::confidential_proof::verify_registration_proof`
  (`registration_fs_message_for_test` + `formal_goldens_registration.move`).

Move anchor: `aptos-move/framework/aptos-experimental/tests/confidential_asset/formal_goldens_registration.move`.

**Address BCS.** For `@0xN` with `N < 256`, the Movement VM encodes `address` as 32 bytes: 31 zero bytes then `N` in the
last byte (matches `std::bcs::to_bytes` / `bcs_tests`-style layout).

This does **not** yet prove Ristretto group arithmetic, `new_scalar_from_bytes`, or `point_equals` match Move;
those remain oracle obligations in `REGISTRATION_VERIFY_REVIEW.md`.
-/

import MovementFormal.Experimental.ConfidentialAsset.Registration.Formal
import MovementFormal.Experimental.ConfidentialAsset.Registration.VerifyMath
import MovementFormal.AptosStd.Hash.Sha2_512
import MovementFormal.AptosStd.Crypto.Ristretto255

open MovementFormal.Experimental.ConfidentialAsset.Registration.Formal
open MovementFormal.AptosStd.Hash.Sha2_512
open MovementFormal.AptosStd.Crypto.Ristretto255
open RegistrationVerify

namespace RegistrationTranscriptAlignment

/-- Ristretto255 basepoint compressed (`ristretto255::BASE_POINT` in Move). -/
def ristrettoBasepointCompressedBytes : ByteArray :=
  ByteArray.mk #[
    0xe2, 0xf2, 0xae, 0x0a, 0x6a, 0xbc, 0x4e, 0x71, 0xa8, 0x84, 0xa9, 0x61, 0xc5, 0x00, 0x51, 0x5f,
    0x58, 0xe3, 0x0b, 0x6a, 0xa5, 0x82, 0xdd, 0x8d, 0xb6, 0xa6, 0x59, 0x45, 0xe0, 0x8d, 0x2d, 0x76
  ]

/-- BCS `address` for `@0x1` (31 zero bytes, `0x01` last) — matches Move `formal_goldens_registration`. -/
def bcsAddress0x1 : ByteArray :=
  ByteArray.mk #[
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
  ]

def bcsAddress0x2 : ByteArray :=
  ByteArray.mk #[
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2
  ]

def bcsAddress0x3 : ByteArray :=
  ByteArray.mk #[
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3
  ]

/-- Same public inputs as `formal_goldens_registration.move`. -/
def goldenRegistrationInputs : RegistrationFiatShamirInputs where
  chainId := 9
  senderBcs := bcsAddress0x1
  contractBcs := bcsAddress0x2
  tokenBcs := bcsAddress0x3
  ekBytes := ristrettoBasepointCompressedBytes
  commitmentRBytes := ristrettoBasepointCompressedBytes

/-- 199 bytes: `hex` from `formal_goldens_registration.move` (must stay in lockstep). DST || chain_id || sender || contract || token || ek || R. -/
def expectedRegistrationFsMsgMoveGolden : ByteArray :=
  ByteArray.mk #[
    0x4d, 0x6f, 0x76, 0x65, 0x6d, 0x65, 0x6e, 0x74, 0x43, 0x6f, 0x6e, 0x66, 0x69, 0x64, 0x65, 0x6e,
    0x74, 0x69, 0x61, 0x6c, 0x41, 0x73, 0x73, 0x65, 0x74, 0x2f, 0x52, 0x65, 0x67, 0x69, 0x73, 0x74,
    0x72, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0xe2, 0xf2, 0xae, 0x0a, 0x6a, 0xbc, 0x4e, 0x71, 0xa8,
    0x84, 0xa9, 0x61, 0xc5, 0x00, 0x51, 0x5f, 0x58, 0xe3, 0x0b, 0x6a, 0xa5, 0x82, 0xdd, 0x8d, 0xb6,
    0xa6, 0x59, 0x45, 0xe0, 0x8d, 0x2d, 0x76, 0xe2, 0xf2, 0xae, 0x0a, 0x6a, 0xbc, 0x4e, 0x71, 0xa8,
    0x84, 0xa9, 0x61, 0xc5, 0x00, 0x51, 0x5f, 0x58, 0xe3, 0x0b, 0x6a, 0xa5, 0x82, 0xdd, 0x8d, 0xb6,
    0xa6, 0x59, 0x45, 0xe0, 0x8d, 0x2d, 0x76
  ]

theorem registration_fiat_shamir_msg_matches_move_golden :
    registrationFiatShamirMsg goldenRegistrationInputs = expectedRegistrationFsMsgMoveGolden := by
  native_decide

/-! ## SHA2-512 digest of the golden FS message -/

def expectedTaggedHashGolden : ByteArray :=
  ByteArray.mk #[
    0x9a, 0x9a, 0x63, 0x79, 0x07, 0x4e, 0xee, 0x0f, 0x92, 0x20, 0xe3, 0xdd, 0xe6, 0xeb, 0x4b, 0x54,
    0x56, 0xcd, 0xb3, 0x53, 0xc5, 0x57, 0x78, 0x5f, 0xab, 0x5a, 0xae, 0x1b, 0xca, 0x51, 0xd1, 0xa9,
    0x5a, 0x89, 0x83, 0xf1, 0xaf, 0x5b, 0x90, 0x4e, 0x7e, 0xcd, 0x11, 0x28, 0x0e, 0x76, 0xb2, 0x75,
    0xd7, 0xdd, 0x58, 0x3c, 0x9f, 0xa2, 0xd6, 0xe5, 0xf5, 0x9e, 0x91, 0xf4, 0xab, 0xa5, 0x0a, 0x67
  ]

theorem tagged_hash_golden_msg_matches :
    sha2_512 expectedRegistrationFsMsgMoveGolden
      = expectedTaggedHashGolden := by
  native_decide

theorem tagged_hash_golden_msg_toList_eq_expected_toList :
    (sha2_512 expectedRegistrationFsMsgMoveGolden).toList
      = expectedTaggedHashGolden.toList := by
  rw [tagged_hash_golden_msg_matches]

theorem tagged_hash_golden_msg_toList_length_eq_64 :
    (sha2_512 expectedRegistrationFsMsgMoveGolden).toList.length = 64 := by
  native_decide

theorem tagged_hash_golden_msg_toList_length_eq_expectedTaggedHashGolden_toList_length :
    (sha2_512 expectedRegistrationFsMsgMoveGolden).toList.length =
      expectedTaggedHashGolden.toList.length := by
  rw [tagged_hash_golden_msg_toList_eq_expected_toList]

theorem expectedTaggedHashGolden_byte_length :
    expectedTaggedHashGolden.size = 64 := by
  native_decide

theorem expectedTaggedHashGolden_toList_length_eq_64 :
    expectedTaggedHashGolden.toList.length = 64 := by
  native_decide

theorem tagged_hash_golden_msg_byte_length :
    (sha2_512 expectedRegistrationFsMsgMoveGolden).size = 64 := by
  rw [tagged_hash_golden_msg_matches, expectedTaggedHashGolden_byte_length]

/-! ## Full challenge scalar derivation (SHA2-512 → `scalarUniformFrom64Bytes` → ℤ/ℓℤ) -/

theorem registration_challenge_scalar_is_some :
    registrationChallengeScalarMove expectedRegistrationFsMsgMoveGolden ≠ none := by
  simp [registrationChallengeScalarMove, MovementFormal.AptosStd.Crypto.Ristretto255.scalarUniformFrom64Bytes]
  native_decide

/-- The Move challenge pipeline on golden **1** FS `msg` is **`scalarUniformFrom64Bytes`** on the **64**-byte SHA2-512 digest (`registration_sha2_512_golden_1.hex`). -/
theorem registrationChallengeScalarMove_golden1_msg_eq_uniform_expectedTaggedHashGolden :
    registrationChallengeScalarMove expectedRegistrationFsMsgMoveGolden =
      scalarUniformFrom64Bytes expectedTaggedHashGolden := by
  rw [registrationChallengeScalarMove_eq_uniform_tagged expectedRegistrationFsMsgMoveGolden]
  simp_rw [tagged_hash_golden_msg_matches]

/-! ## Second golden scenario (chain_id=42, @0x10/@0x20/@0x30, basepoint ek/R) -/

def bcsAddress0x10 : ByteArray :=
  ByteArray.mk #[
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x10
  ]

def bcsAddress0x20 : ByteArray :=
  ByteArray.mk #[
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x20
  ]

def bcsAddress0x30 : ByteArray :=
  ByteArray.mk #[
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x30
  ]

/-- Second golden: `chain_id=42`, `@0x10`/`@0x20`/`@0x30`, basepoint `ek`/`R`. -/
def goldenRegistrationInputs2 : RegistrationFiatShamirInputs where
  chainId := 42
  senderBcs := bcsAddress0x10
  contractBcs := bcsAddress0x20
  tokenBcs := bcsAddress0x30
  ekBytes := ristrettoBasepointCompressedBytes
  commitmentRBytes := ristrettoBasepointCompressedBytes

/-- 199 bytes: expected FS message for the second golden scenario. DST || chain_id || sender || contract || token || ek || R. -/
def expectedRegistrationFsMsg2 : ByteArray :=
  ByteArray.mk #[
    0x4d, 0x6f, 0x76, 0x65, 0x6d, 0x65, 0x6e, 0x74, 0x43, 0x6f, 0x6e, 0x66, 0x69, 0x64, 0x65, 0x6e,
    0x74, 0x69, 0x61, 0x6c, 0x41, 0x73, 0x73, 0x65, 0x74, 0x2f, 0x52, 0x65, 0x67, 0x69, 0x73, 0x74,
    0x72, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x2a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0xe2, 0xf2, 0xae, 0x0a, 0x6a, 0xbc, 0x4e, 0x71, 0xa8,
    0x84, 0xa9, 0x61, 0xc5, 0x00, 0x51, 0x5f, 0x58, 0xe3, 0x0b, 0x6a, 0xa5, 0x82, 0xdd, 0x8d, 0xb6,
    0xa6, 0x59, 0x45, 0xe0, 0x8d, 0x2d, 0x76, 0xe2, 0xf2, 0xae, 0x0a, 0x6a, 0xbc, 0x4e, 0x71, 0xa8,
    0x84, 0xa9, 0x61, 0xc5, 0x00, 0x51, 0x5f, 0x58, 0xe3, 0x0b, 0x6a, 0xa5, 0x82, 0xdd, 0x8d, 0xb6,
    0xa6, 0x59, 0x45, 0xe0, 0x8d, 0x2d, 0x76
  ]

theorem registration_fiat_shamir_msg_matches_golden_2 :
    registrationFiatShamirMsg goldenRegistrationInputs2 = expectedRegistrationFsMsg2 := by
  native_decide

/-! ## SHA2-512 digest of the second golden FS message -/

def expectedTaggedHashGolden2 : ByteArray :=
  ByteArray.mk #[
    0x37, 0xb6, 0x6d, 0xcf, 0x98, 0x94, 0x74, 0xc1, 0x97, 0xa6, 0x59, 0x70, 0xa9, 0x3c, 0xdd, 0xe9,
    0x1c, 0x38, 0xba, 0xe0, 0x39, 0x6b, 0x01, 0xa4, 0x80, 0x97, 0x22, 0xfe, 0x62, 0x85, 0x4e, 0x36,
    0xa5, 0x7a, 0x65, 0x03, 0xd6, 0x9e, 0xe1, 0xac, 0x49, 0x41, 0xcd, 0xca, 0x94, 0x29, 0x93, 0xf3,
    0x38, 0xee, 0x02, 0x5a, 0x0b, 0xbb, 0x53, 0x92, 0x53, 0x49, 0x60, 0x32, 0xd8, 0xb2, 0x0e, 0xee
  ]

theorem tagged_hash_golden2_msg_matches :
    sha2_512 expectedRegistrationFsMsg2 =
      expectedTaggedHashGolden2 := by
  native_decide

theorem tagged_hash_golden2_msg_toList_eq_expected_toList :
    (sha2_512 expectedRegistrationFsMsg2).toList
      = expectedTaggedHashGolden2.toList := by
  rw [tagged_hash_golden2_msg_matches]

theorem tagged_hash_golden2_msg_toList_length_eq_64 :
    (sha2_512 expectedRegistrationFsMsg2).toList.length = 64 := by
  native_decide

theorem tagged_hash_golden2_msg_toList_length_eq_expectedTaggedHashGolden2_toList_length :
    (sha2_512 expectedRegistrationFsMsg2).toList.length =
      expectedTaggedHashGolden2.toList.length := by
  rw [tagged_hash_golden2_msg_toList_eq_expected_toList]

theorem expectedTaggedHashGolden2_byte_length :
    expectedTaggedHashGolden2.size = 64 := by
  native_decide

theorem expectedTaggedHashGolden2_toList_length_eq_64 :
    expectedTaggedHashGolden2.toList.length = 64 := by
  native_decide

theorem tagged_hash_golden2_msg_byte_length :
    (sha2_512 expectedRegistrationFsMsg2).size = 64 := by
  rw [tagged_hash_golden2_msg_matches, expectedTaggedHashGolden2_byte_length]

/-- Both Move FS `msg` goldens yield **64**-byte SHA2-512 digests (corpus / `verify-corpora` hygiene). -/
theorem tagged_hash_golden_msgs_tagged_digest_byte_length_bundle :
    (sha2_512 expectedRegistrationFsMsgMoveGolden).size = 64 ∧
    (sha2_512 expectedRegistrationFsMsg2).size = 64 :=
  And.intro tagged_hash_golden_msg_byte_length tagged_hash_golden2_msg_byte_length

theorem registration_challenge_scalar_is_some_2 :
    registrationChallengeScalarMove expectedRegistrationFsMsg2 ≠ none := by
  simp [registrationChallengeScalarMove, MovementFormal.AptosStd.Crypto.Ristretto255.scalarUniformFrom64Bytes]
  native_decide

/-- Both formal FS `msg` goldens yield a defined challenge scalar (no `none` from `scalarUniformFrom64Bytes`). -/
theorem registration_challenge_scalar_is_some_both_move_golden_msgs :
    registrationChallengeScalarMove expectedRegistrationFsMsgMoveGolden ≠ none ∧
    registrationChallengeScalarMove expectedRegistrationFsMsg2 ≠ none :=
  And.intro registration_challenge_scalar_is_some registration_challenge_scalar_is_some_2

/-- Same for golden **2** FS `msg` and **`registration_sha2_512_golden_2.hex`**. -/
theorem registrationChallengeScalarMove_golden2_msg_eq_uniform_expectedTaggedHashGolden2 :
    registrationChallengeScalarMove expectedRegistrationFsMsg2 =
      scalarUniformFrom64Bytes expectedTaggedHashGolden2 := by
  rw [registrationChallengeScalarMove_eq_uniform_tagged expectedRegistrationFsMsg2]
  simp_rw [tagged_hash_golden2_msg_matches]

/-- `registrationChallengeScalarMove` depends only on FS `msg` bytes; golden **1** inputs use the Move golden `msg`. -/
theorem registrationChallengeScalarMove_eq_on_golden1_inputs :
    registrationChallengeScalarMove (registrationFiatShamirMsg goldenRegistrationInputs) =
      registrationChallengeScalarMove expectedRegistrationFsMsgMoveGolden := by
  rw [registration_fiat_shamir_msg_matches_move_golden]

/-- Same for golden **2** (`expectedRegistrationFsMsg2`). -/
theorem registrationChallengeScalarMove_eq_on_golden2_inputs :
    registrationChallengeScalarMove (registrationFiatShamirMsg goldenRegistrationInputs2) =
      registrationChallengeScalarMove expectedRegistrationFsMsg2 := by
  rw [registration_fiat_shamir_msg_matches_golden_2]

/-! ## Byte lengths (corpus + review hygiene)

Machine-checked lengths for the checked-in hex corpora under
`difftest/corpora/confidential_assets/registration_fs_msg_move_golden_*.hex`.
-/

theorem expectedRegistrationFsMsgMoveGolden_byte_length :
    expectedRegistrationFsMsgMoveGolden.size = 199 := by
  native_decide

theorem expectedRegistrationFsMsg2_byte_length :
    expectedRegistrationFsMsg2.size = 199 := by
  native_decide

theorem registrationFiatShamirMsg_golden1_byte_length :
    (registrationFiatShamirMsg goldenRegistrationInputs).size = 199 := by
  rw [registration_fiat_shamir_msg_matches_move_golden, expectedRegistrationFsMsgMoveGolden_byte_length]

theorem registrationFiatShamirMsg_golden2_byte_length :
    (registrationFiatShamirMsg goldenRegistrationInputs2).size = 199 := by
  rw [registration_fiat_shamir_msg_matches_golden_2, expectedRegistrationFsMsg2_byte_length]

/-- Both golden **`registrationFiatShamirMsg`** wires are **199** B (inputs **1** and **2**). -/
theorem registrationFiatShamirMsg_golden_inputs_byte_length_bundle :
    (registrationFiatShamirMsg goldenRegistrationInputs).size = 199 ∧
    (registrationFiatShamirMsg goldenRegistrationInputs2).size = 199 :=
  And.intro registrationFiatShamirMsg_golden1_byte_length registrationFiatShamirMsg_golden2_byte_length

/-- Both Move FS `msg` golden byte arrays are **199** B (`registration_fs_msg_move_golden_*.hex`). -/
theorem expectedRegistrationFsMsgMoveGolden_and_golden2_byte_length_bundle :
    expectedRegistrationFsMsgMoveGolden.size = 199 ∧ expectedRegistrationFsMsg2.size = 199 :=
  And.intro expectedRegistrationFsMsgMoveGolden_byte_length expectedRegistrationFsMsg2_byte_length

/-- Golden FS **`msg`** wires (**199** B) and their SHA2-512 digests (**64** B), both scenarios. -/
theorem registration_golden_fs_msgs_and_tagged_digests_length_bundle :
    (registrationFiatShamirMsg goldenRegistrationInputs).size = 199 ∧
    (registrationFiatShamirMsg goldenRegistrationInputs2).size = 199 ∧
    (sha2_512 expectedRegistrationFsMsgMoveGolden).size = 64 ∧
    (sha2_512 expectedRegistrationFsMsg2).size = 64 :=
  And.intro registrationFiatShamirMsg_golden1_byte_length
    (And.intro registrationFiatShamirMsg_golden2_byte_length
      (And.intro tagged_hash_golden_msg_byte_length tagged_hash_golden2_msg_byte_length))

/-- Both goldens yield a defined challenge scalar **and** **64**-byte SHA2-512 digests. -/
theorem registration_golden_challenge_defined_and_digest_length_bundle :
    registrationChallengeScalarMove expectedRegistrationFsMsgMoveGolden ≠ none ∧
    registrationChallengeScalarMove expectedRegistrationFsMsg2 ≠ none ∧
    (sha2_512 expectedRegistrationFsMsgMoveGolden).size = 64 ∧
    (sha2_512 expectedRegistrationFsMsg2).size = 64 :=
  And.intro registration_challenge_scalar_is_some
    (And.intro registration_challenge_scalar_is_some_2
      (And.intro tagged_hash_golden_msg_byte_length tagged_hash_golden2_msg_byte_length))

/--
**Golden registration transcript hygiene** in one statement: both FS **`msg`** wires are **199** B,
SHA2-512 digests are **64** B, and the Move-modeled challenge scalars are defined (**`≠ none`**)
on both golden FS byte arrays.
-/
theorem registration_golden_fs_digest_and_challenge_bundle :
    (registrationFiatShamirMsg goldenRegistrationInputs).size = 199 ∧
    (registrationFiatShamirMsg goldenRegistrationInputs2).size = 199 ∧
    (sha2_512 expectedRegistrationFsMsgMoveGolden).size = 64 ∧
    (sha2_512 expectedRegistrationFsMsg2).size = 64 ∧
    registrationChallengeScalarMove expectedRegistrationFsMsgMoveGolden ≠ none ∧
    registrationChallengeScalarMove expectedRegistrationFsMsg2 ≠ none :=
  And.intro registrationFiatShamirMsg_golden1_byte_length
    (And.intro registrationFiatShamirMsg_golden2_byte_length
      (And.intro tagged_hash_golden_msg_byte_length
        (And.intro tagged_hash_golden2_msg_byte_length
          (And.intro registration_challenge_scalar_is_some registration_challenge_scalar_is_some_2))))

end RegistrationTranscriptAlignment
