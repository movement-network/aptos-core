import AptosFormal.Move.Native
import AptosFormal.Move.Step
import AptosFormal.AptosStd.Hash.Sha3_512
import AptosFormal.Experimental.ConfidentialAsset.Registration.TranscriptAlignment
import AptosFormal.Move.Programs.RegistrationDifftestOracle

/-!
# Confidential-asset differential stubs (`ModuleEnv`)

Lean column for `confidential_balance` / `confidential_proof` / layer smoke oracles.

Several **balance** oracle rows use **`FuncBody.bytecode`** in `eval` (real `Step`), not native stubs:
constant `u64`/`bool` returns, the **wrong empty-length** `Option` check (`len ≠ 256` ⇒ `is_none` is true),
and **`test_pending_from_short_len_is_none`** via a **255-byte** `u8` constant pool entry (`len ≠ 256`).
**`test_actual_from_wrong_len_is_none`** uses bytecode `len ≠ 512` for **`new_actual_balance_from_bytes`**;
**`test_actual_from_short_len_is_none`** uses a **511-byte** const-pool vector (`len ≠ 512`).
**Transactional CA e2e** rows (indices 40–42) use bytecode witnesses matching the merged JSON outcomes; index **40** includes **`bool(true)`** success pins (multi-step flows, **`has_confidential_asset_store`** after register, **`encryption_key`** `#[view]` vs **`pubkey_to_bytes`**, **`pending_balance`** / **`actual_balance`** return-byte length pins after **`register`**, **`is_token_allowed`**, **`get_auditor`** **`none`** (BCS **`[0]`**; merged row uses stub **`bool(true)`**), **`verify_pending_balance`** with **`u64(0)`** (register-only or post-**`rollover`**) or **`u64(amount)`** / **`u64(sum)`** after one or **two** **`deposit`**s without rollover or **two** post-**`rotate_encryption_key_and_unfreeze`** **`deposit`**s, **`verify_actual_balance`** with **`u128(0)`** after register-only or after **`deposit`** without rollover, **`verify_actual_balance`** after **`deposit`** + **`rollover_pending_balance`** (single or **summed** **two-**`deposit` path), …). Index **102** is **`bool(false)`** for merged-oracle rows that record VM **`false`** (e.g. `is_normalized` after rollover, `has_confidential_asset_store` before register / for a non-registered peer, `is_allow_list_enabled` off mainnet (including after **`rotate_encryption_key_and_unfreeze`** on the freeze path), `is_frozen` before freeze or after unfreeze, **`verify_{pending,actual}_balance`** rejecting **non-zero** claims after **`register`** only, **`verify_actual_balance`** rejecting a **non-zero** **`u128`** after **`deposit`** without rollover, **`u128(0)`**, a wrong **`u128`**, or a **wrong summed `u128`** after **two** **`deposit`**s + **`rollover_pending_balance`** when **actual** is non-zero, **`verify_pending_balance`** rejecting a wrong **`u64`** (including **wrong sum** after **two** **`deposit`**s or **off-by-one** vs the **two** post-unfreeze **`deposit`** pending sum on that path), **stale** post-**`rollover`** pending claim (**one** or **summed two-**`deposit` amount while **pending** is cleared), **wrong `u64`** on **pending** after **two** **`deposit`**s + **`rollover`** (e.g. **off-by-one** vs the pre-rollover **sum**), or **non-zero** after **`deposit`** + **`rollover_pending_balance`**). Indices **103–109**, **177**, **178**, **179**, and **180** are fixed **`u64`** witnesses for `confidential_asset_balance` e2e rows (**77** single deposit; **165** = 100+65; **667** after deposit 1000 and withdraw 333; **5678** after a single `deposit_to`; **12345** unchanged after `confidential_transfer`; **7000** after transfer then second deposit 5000+2000; **7777** after two `deposit_to` 3333+4444; **8881** after **`rotate_encryption_key_and_unfreeze`** on the freeze path; **10003** after rolled **`6001`** + post-unfreeze **`deposit(4002)`**; **8901** after rolled **`6001`** + post-unfreeze **`deposit(2000)`** + **`deposit(900)`**; **6601** after rolled **`6001`** + three small post-unfreeze **`deposit`**s **100** + **200** + **300** on that path).
**Fiat–Shamir sigma DST** view getters from `confidential_proof` are aligned at indices 43–46 (constant-pool bytes).
Index **52** is the **FA stub read** (`faReadBalance`); `Runner.lean` seeds `faBalances` for `test_fa_stub_balance_answer`.
Index **169** is **`faWriteBalance` then `faReadBalance`** on `(metadataId=1, owner=2)` with amount **9999** — starts from **empty** `faBalances` (difftest `test_fa_stub_write_then_read_balance`; VM returns the same constant).
Index **170** is **`bool(true)`** for **`test_registration_fs_message_framework_matches_helpers_golden`**
(VM: **`confidential_proof::registration_fs_message_for_test`** on golden inputs **==** `difftest_registration_helpers::registration_fs_message_golden_move`; Lean **`ldTrue`** stub).
Index **171** is **`bool(true)`** for **`test_registration_proof_framework_deterministic_verify_roundtrip`**
(VM: production **`prove_registration_deterministic_for_difftest`** + **`verify_registration_proof_for_difftest`** on the `registration_roundtrip_vm` fixture; Lean **`caRegistrationHelpersRoundtripNative`** — same **`Operational.execVerifyRegistrationProof`** table oracle as index **35**).
Index **172** returns the **second** formal FS golden **`vector<u8>`** (**`ldConst` 46** + `ret`; `TranscriptAlignment.expectedRegistrationFsMsg2`).
Index **173** is **`bool(true)`** for **`test_registration_fs_message_framework_second_scenario_matches_helpers_golden`** (Lean **`ldTrue`** stub).
Indices **174** / **175**: **64**-byte registration **`tagged_hash`** digests on FS golden **1** / **2** (**`ldConst` 47** / **48** + `ret`; corpora **`registration_tagged_hash_golden_{1,2}.hex`**).
Index **53** is **`ciphertext_add_assign`** smoke (`test_elg_ciphertext_add_assign_matches_add`).
Index **54** is **`ciphertext_sub_assign`** smoke (`test_elg_ciphertext_sub_assign_matches_sub`).
Indices **55–101**: extra balance + ElGamal bool smoke (see `Runner.lean` names). Index **102**: CA e2e **`bool(false)`** witness. Index **103**: CA e2e **`u64(77)`** witness (`confidential_asset_balance` after a single `deposit` of 77 in the merged oracle). Index **104**: **`u64(165)`** (two self-deposits 100+65). Index **105**: **`u64(667)`** (deposit 1000, withdraw 333). Index **106**: **`u64(5678)`** (`deposit_to` only). Index **107**: **`u64(12345)`** (deposit 12345, transfer 4321 to Bob — pool unchanged). Index **108**: **`u64(7000)`** (5000 + 2000 after mid transfer). Index **109**: **`u64(7777)`** (two `deposit_to` to same recipient).
Index **177**: **`u64(8881)`** (`confidential_asset_balance` after **`deposit(8881)`** + **`rollover_pending_balance_and_freeze`** + **`rotate_encryption_key_and_unfreeze`** — FA pool unchanged).
Index **178**: **`u64(10003)`** (`confidential_asset_balance` after **`deposit(6001)`** + **`rollover_pending_balance_and_freeze`** + **`rotate_encryption_key_and_unfreeze`** + **`deposit(4002)`** — pool **10003**).
Index **179**: **`u64(8901)`** (same path + **`deposit(2000)`** + **`deposit(900)`** post-unfreeze — FA pool **8901**).
Index **180**: **`u64(6601)`** (same path + **`deposit(100)`** + **`deposit(200)`** + **`deposit(300)`** post-unfreeze — FA pool **6601**).
Index **114**: non-empty **`serialize_auditor_eks`** wire (**32** B, `ldConst` **10**). Index **115**: non-empty **`serialize_auditor_amounts`** with one **`new_pending_balance_no_randomness`** (**256** B, `ldConst` **11**; all **zero** on current VM).
Index **116**: **`serialize_auditor_eks`** two **A_POINT** keys (**64** B, `ldConst` **12**). Index **117**: **`serialize_auditor_amounts`** two zero pending (**512** B, `ldConst` **13**).
Index **118**: **`serialize_auditor_amounts`** one **`new_pending_balance_u64_no_randonmess(1)`** (**256** B, `ldConst` **14**). Index **119**: one **`new_actual_balance_no_randomness`** (**512** B, `ldConst` **15**).
Index **120**: zero pending then **`u64(1)`** (**512** B, `ldConst` **16**).
Index **121**: **`u64(1)`** then zero pending (**512** B, `ldConst` **17**; order differs from **120**).
Indices **122–123**: **`serialize_auditor_amounts`** mixing **actual-width** zero (**512** B) with **`u64(1)`** no-rand **pending** (**256** B) — **768** B (`ldConst` **18** / **19**; order differs; **not** two all-zero rows, which would coincide as **768** × `0u8`).
Index **124**: **`serialize_auditor_eks`** three **A_POINT** keys (**96** B, `ldConst` **20**).
Index **125**: **`serialize_auditor_eks`** four **A_POINT** keys (**128** B, `ldConst` **21**).
Index **126**: **`serialize_auditor_eks`** five **A_POINT** keys (**160** B, `ldConst` **22**).
Index **127**: **`serialize_auditor_eks`** six **A_POINT** keys (**192** B, `ldConst` **23**).
Indices **110–111** (withdrawal + normalization **`layout_ok_is_some`** rows) and **128**: same real **`Step`** — **`ldConst` 24** + `vecLen` + `eq` vs **1152** (corpus **`deserialize_sigma_18_scalars_18_points`**). **112** / **129**: **`ldConst` 25** vs **1216**. **113** / **130**: **`ldConst` 26** vs **1792**. **131** / **132**: transfer **+ one quad** (**1920** B, **`ldConst` 27**); **133** / **134**: **+ two quads** (**2048**, **`ldConst` 28**); **135** / **136**: **+ three quads** (**2176**, **`ldConst` 29**); **137** / **138**: **+ four quads** (**2304**, **`ldConst` 30**); **139** / **140**: **+ five quads** (**2432**, **`ldConst` 31**); **141** / **142**: **+ six quads** (**2560**, **`ldConst` 32**); **143** / **144**: **+ seven quads** (**2688**, **`ldConst` 33**); **145** / **146**: **+ eight quads** (**2816**, **`ldConst` 34**); **147** / **148**: **+ nine quads** (**2944**, **`ldConst` 35**); **149** / **150**: **+ ten quads** (**3072**, **`ldConst` 36**); **151** / **152**: **+ eleven quads** (**3200**, **`ldConst` 37**); **153** / **154**: **+ twelve quads** (**3328**, **`ldConst` 38**); **155** / **156**: **+ thirteen quads** (**3456**, **`ldConst` 39**); **157** / **158**: **+ fourteen quads** (**3584**, **`ldConst` 40**); **159** / **160**: **+ fifteen quads** (**3712**, **`ldConst` 41**); **161** / **162**: **+ sixteen quads** (**3840**, **`ldConst` 42**); **163** / **164**: **+ seventeen quads** (**3968**, **`ldConst` 43**); **165** / **166**: **+ eighteen quads** (**4096**, **`ldConst` 44**); **167** / **168**: **+ nineteen quads** (**4224**, **`ldConst` 45**). VM runs **`deserialize_*`** for **110–113**, **132**, **134**, **136**, **138**, **140**, **142**, **144**, **146**, **148**, **150**, **152**, **154**, **156**, **158**, **160**, **162**, **164**, **166**, **168**; Lean **length** bytecode only. **170**: registration FS framework **`registration_fs_message_for_test`** vs golden — Lean **`ldTrue`**. **171**: production deterministic registration prove + verify — Lean **`caRegistrationHelpersRoundtripNative`** (same as **35**). **172**: second FS golden **`vector<u8>`** (**`ldConst` 46**). **173**: second FS framework vs helpers golden — Lean **`ldTrue`**.
See `difftest/inventory/confidential_assets.md` for scope and skipped paths.

**Registration:** `test_registration_fs_message_golden_move` / **`test_registration_fs_message_golden_move_second`**
use **`TranscriptAlignment.expectedRegistrationFsMsgMoveGolden`** / **`expectedRegistrationFsMsg2`** (indices **38** / **172**).
`test_registration_fs_message_framework_matches_helpers_golden` (**170**) and
`test_registration_fs_message_framework_second_scenario_matches_helpers_golden` (**173**) VM-check
**`confidential_proof::registration_fs_message_for_test`** against the matching helpers golden (Lean **`ldTrue`** stubs).
`test_registration_helpers_roundtrip` (**35**) and **`test_registration_proof_framework_deterministic_verify_roundtrip`**
(**171**) both return **`bool(true)`** on the shared registration fixture; Lean uses **`caRegistrationHelpersRoundtripNative`**
(`Operational.execVerifyRegistrationProof` on the fixed VM wire bytes in `Programs/RegistrationDifftestOracle.lean`;
regenerate bytes with `cargo run -p move-lean-difftest --bin print-difftest-registration-wire`).
`test_bulletproofs_dst_sha3_512` uses **`ld_const` + `ret`** on the machine-checked SHA3-512 digest.
Hex corpora: `corpora/confidential_assets/bulletproofs_dst.hex` and `bulletproofs_dst_sha3_512.hex` (checked by **`cargo run -p move-lean-difftest -- verify-corpora`**);
`sigma` layout blobs `deserialize_sigma_{18,19}_scalars_*_points.hex`, `deserialize_sigma_transfer_26_scalars_30_points.hex`, `…_plus_one_auditor_quad.hex` (**1920** B), `…_plus_two_auditor_quads.hex` (**2048** B), `…_plus_three_auditor_quads.hex` (**2176** B), `…_plus_four_auditor_quads.hex` (**2304** B), `…_plus_five_auditor_quads.hex` (**2432** B), `…_plus_six_auditor_quads.hex` (**2560** B), `…_plus_seven_auditor_quads.hex` (**2688** B), `…_plus_eight_auditor_quads.hex` (**2816** B), `…_plus_nine_auditor_quads.hex` (**2944** B), `…_plus_ten_auditor_quads.hex` (**3072** B), `…_plus_eleven_auditor_quads.hex` (**3200** B), `…_plus_twelve_auditor_quads.hex` (**3328** B), `…_plus_thirteen_auditor_quads.hex` (**3456** B), `…_plus_fourteen_auditor_quads.hex` (**3584** B), `…_plus_fifteen_auditor_quads.hex` (**3712** B), `…_plus_sixteen_auditor_quads.hex` (**3840** B), `…_plus_seventeen_auditor_quads.hex` (**3968** B), `…_plus_eighteen_auditor_quads.hex` (**4096** B), `…_plus_nineteen_auditor_quads.hex` (**4224** B); same **`verify-corpora`** gate; Lean `deserializeSigma*Bytes_length` / prefix lemmas between extension tiers;
serializer wires under `corpora/confidential_assets/serialize_auditor_*` (EK + pending/actual amount VM pins; same **`verify-corpora`** command).
-/

namespace AptosFormal.Move.Programs.Confidential

open AptosFormal.Move
open AptosFormal.Move.Native
open AptosFormal.AptosStd.Hash.Sha3_512
open RegistrationVerify
open RegistrationTranscriptAlignment
open AptosFormal.Move.Programs.RegistrationDifftestOracle

private def u8s (bs : List UInt8) : MoveValue :=
  .vector .u8 (bs.map .u8)

/-- Mirrors `BULLETPROOFS_DST` bytes in `confidential_proof.move`. -/
def bulletproofsDstBytes : List UInt8 :=
  [65, 112, 116, 111, 115, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108, 65, 115, 115,
    101, 116, 47, 66, 117, 108, 108, 101, 116, 112, 114, 111, 111, 102, 82, 97, 110, 103, 101, 80,
    114, 111, 111, 102]

/-- SHA3-512 of `bulletproofsDstBytes` — matches `aptos_std::aptos_hash::sha3_512` on that input. -/
def bulletproofsDstSha3Bytes : List UInt8 :=
  (sha3_512 (ByteArray.mk bulletproofsDstBytes.toArray)).toList

/-- UTF-8 length of Move `BULLETPROOFS_DST` (`confidential_proof.move`). -/
theorem bulletproofsDstBytes_length : bulletproofsDstBytes.length = 44 := by
  native_decide

/-- NIST SHA3-512 produces a 64-byte digest. -/
theorem bulletproofsDstSha3Bytes_length : bulletproofsDstSha3Bytes.length = 64 := by
  native_decide

private def deserializeRepeatConcat (n : Nat) (chunk : List UInt8) : List UInt8 :=
  (List.range n).foldl (fun acc _ => acc ++ chunk) []

/-- Canonical 32-byte scalar encoding of zero (`ristretto255::new_scalar_from_bytes` accepts). -/
def deserializeScalar32ZeroBytes : List UInt8 :=
  List.replicate 32 0

/-- `aptos_std::ristretto255` test vector `A_POINT` (32-byte compressed encoding). -/
def deserializeRistrettoAPointBytes : List UInt8 :=
  [0xe8, 0x7f, 0xed, 0xa1, 0x99, 0xd7, 0x2b, 0x83, 0xde, 0x4f, 0x5b, 0x2d, 0x45, 0xd3, 0x48, 0x05, 0xc5, 0x70,
    0x19, 0xc6, 0xc5, 0x9c, 0x42, 0xcb, 0x70, 0xee, 0x3d, 0x19, 0xaa, 0x99, 0x6f, 0x75]

/-- One compressed pubkey serializes to **32** bytes (`twisted_elgamal::pubkey_to_bytes`); matches `serialize_auditor_eks` with a singleton **A_POINT** vector. -/
theorem deserializeRistrettoAPointBytes_length : deserializeRistrettoAPointBytes.length = 32 := by
  native_decide

/-- Wire for `serialize_auditor_amounts` with one **`new_pending_balance_no_randomness`** balance (4×64 B encodings of identity ciphertexts — all **zero** bytes on current VM). -/
def serializeAuditorAmountsOneZeroPendingWireBytes : List UInt8 :=
  List.replicate 256 0

theorem serializeAuditorAmountsOneZeroPendingWireBytes_length :
    serializeAuditorAmountsOneZeroPendingWireBytes.length = 256 := by
  native_decide

/-- `serialize_auditor_eks` with two identical **A_POINT** keys — **64** bytes (`pubkey_to_bytes` each). -/
def serializeAuditorEksTwoApointWireBytes : List UInt8 :=
  deserializeRistrettoAPointBytes ++ deserializeRistrettoAPointBytes

theorem serializeAuditorEksTwoApointWireBytes_length :
    serializeAuditorEksTwoApointWireBytes.length = 64 := by
  native_decide

theorem serializeAuditorEksTwoApointWireBytes_take32_first :
    (serializeAuditorEksTwoApointWireBytes.take 32) = deserializeRistrettoAPointBytes := by
  native_decide

theorem serializeAuditorEksTwoApointWireBytes_eq_append_single :
    serializeAuditorEksTwoApointWireBytes =
      deserializeRistrettoAPointBytes ++ deserializeRistrettoAPointBytes := by
  native_decide

/-- `serialize_auditor_eks` with three identical **A_POINT** keys — **96** bytes. -/
def serializeAuditorEksThreeApointWireBytes : List UInt8 :=
  serializeAuditorEksTwoApointWireBytes ++ deserializeRistrettoAPointBytes

theorem serializeAuditorEksThreeApointWireBytes_length :
    serializeAuditorEksThreeApointWireBytes.length = 96 := by
  native_decide

theorem serializeAuditorEksThreeApointWireBytes_eq_append_two_single :
    serializeAuditorEksThreeApointWireBytes =
      serializeAuditorEksTwoApointWireBytes ++ deserializeRistrettoAPointBytes := by
  rfl

/-- `serialize_auditor_eks` with four identical **A_POINT** keys — **128** bytes. -/
def serializeAuditorEksFourApointWireBytes : List UInt8 :=
  serializeAuditorEksThreeApointWireBytes ++ deserializeRistrettoAPointBytes

theorem serializeAuditorEksFourApointWireBytes_length :
    serializeAuditorEksFourApointWireBytes.length = 128 := by
  native_decide

theorem serializeAuditorEksFourApointWireBytes_eq_append_three_single :
    serializeAuditorEksFourApointWireBytes =
      serializeAuditorEksThreeApointWireBytes ++ deserializeRistrettoAPointBytes := by
  rfl

/-- `serialize_auditor_eks` with five identical **A_POINT** keys — **160** bytes. -/
def serializeAuditorEksFiveApointWireBytes : List UInt8 :=
  serializeAuditorEksFourApointWireBytes ++ deserializeRistrettoAPointBytes

theorem serializeAuditorEksFiveApointWireBytes_length :
    serializeAuditorEksFiveApointWireBytes.length = 160 := by
  native_decide

theorem serializeAuditorEksFiveApointWireBytes_eq_append_four_single :
    serializeAuditorEksFiveApointWireBytes =
      serializeAuditorEksFourApointWireBytes ++ deserializeRistrettoAPointBytes := by
  rfl

/-- Same bytes as **5** appended **A_POINT** encodings (ties EK corpora to `deserializeRepeatConcat` / sigma point chunks). -/
theorem serializeAuditorEksFiveApointWireBytes_eq_deserializeRepeatConcat :
    serializeAuditorEksFiveApointWireBytes =
      deserializeRepeatConcat 5 deserializeRistrettoAPointBytes := by
  native_decide

/-- `serialize_auditor_eks` with six identical **A_POINT** keys — **192** bytes. -/
def serializeAuditorEksSixApointWireBytes : List UInt8 :=
  serializeAuditorEksFiveApointWireBytes ++ deserializeRistrettoAPointBytes

theorem serializeAuditorEksSixApointWireBytes_length :
    serializeAuditorEksSixApointWireBytes.length = 192 := by
  native_decide

theorem serializeAuditorEksSixApointWireBytes_eq_append_five_single :
    serializeAuditorEksSixApointWireBytes =
      serializeAuditorEksFiveApointWireBytes ++ deserializeRistrettoAPointBytes := by
  rfl

theorem serializeAuditorEksSixApointWireBytes_eq_deserializeRepeatConcat :
    serializeAuditorEksSixApointWireBytes =
      deserializeRepeatConcat 6 deserializeRistrettoAPointBytes := by
  native_decide

/-- Two **`new_pending_balance_no_randomness`** balances — **512** zero bytes on current VM. -/
def serializeAuditorAmountsTwoZeroPendingWireBytes : List UInt8 :=
  List.replicate 512 0

theorem serializeAuditorAmountsTwoZeroPendingWireBytes_length :
    serializeAuditorAmountsTwoZeroPendingWireBytes.length = 512 := by
  native_decide

/-- Matches Move `serialize_auditor_amounts` on two equal-serialization balances (`balance_to_bytes` then `append`). -/
theorem serializeAuditorAmountsTwoZeroPendingWireBytes_eq_append_one :
    serializeAuditorAmountsTwoZeroPendingWireBytes =
      serializeAuditorAmountsOneZeroPendingWireBytes ++ serializeAuditorAmountsOneZeroPendingWireBytes := by
  native_decide

/-- VM wire for `serialize_auditor_amounts` with one **`new_pending_balance_u64_no_randonmess(1)`** (pinned by oracle JSON / `.hex`). -/
def serializeAuditorAmountsOneU64OnePendingWireBytes : List UInt8 :=
  [
    0xe2, 0xf2, 0xae, 0x0a, 0x6a, 0xbc, 0x4e, 0x71, 0xa8, 0x84, 0xa9, 0x61, 0xc5, 0x00, 0x51, 0x5f,
    0x58, 0xe3, 0x0b, 0x6a, 0xa5, 0x82, 0xdd, 0x8d, 0xb6, 0xa6, 0x59, 0x45, 0xe0, 0x8d, 0x2d, 0x76,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
  ]

theorem serializeAuditorAmountsOneU64OnePendingWireBytes_length :
    serializeAuditorAmountsOneU64OnePendingWireBytes.length = 256 := by
  native_decide

/-- One **`new_actual_balance_no_randomness`** — **512** zero bytes on current VM (`balance_to_bytes`). -/
def serializeAuditorAmountsOneActualZeroWireBytes : List UInt8 :=
  List.replicate 512 0

theorem serializeAuditorAmountsOneActualZeroWireBytes_length :
    serializeAuditorAmountsOneActualZeroWireBytes.length = 512 := by
  native_decide

theorem serializeAuditorAmountsOneActualZeroWireBytes_eq_two_pending_zeros :
    serializeAuditorAmountsOneActualZeroWireBytes =
      serializeAuditorAmountsOneZeroPendingWireBytes ++ serializeAuditorAmountsOneZeroPendingWireBytes := by
  native_decide

/-- VM wire: **zero** pending then **`u64(1)`** no-rand pending — **512** B (`append` of two `balance_to_bytes`). -/
def serializeAuditorAmountsZeroThenU64OneWireBytes : List UInt8 :=
  serializeAuditorAmountsOneZeroPendingWireBytes ++ serializeAuditorAmountsOneU64OnePendingWireBytes

theorem serializeAuditorAmountsZeroThenU64OneWireBytes_length :
    serializeAuditorAmountsZeroThenU64OneWireBytes.length = 512 := by
  native_decide

/-- VM wire: **`u64(1)`** no-rand pending then **zero** pending — **512** B (reverse concat vs index **120**). -/
def serializeAuditorAmountsU64OneThenZeroWireBytes : List UInt8 :=
  serializeAuditorAmountsOneU64OnePendingWireBytes ++ serializeAuditorAmountsOneZeroPendingWireBytes

theorem serializeAuditorAmountsU64OneThenZeroWireBytes_length :
    serializeAuditorAmountsU64OneThenZeroWireBytes.length = 512 := by
  native_decide

theorem serializeAuditorAmounts_mixed512_orders_distinct :
    serializeAuditorAmountsZeroThenU64OneWireBytes ≠ serializeAuditorAmountsU64OneThenZeroWireBytes := by
  native_decide

/-- VM wire: **actual** zero (**512** B) then **`u64(1)`** no-rand **pending** (**256** B) — mixed widths; **768** B total. -/
def serializeAuditorAmountsActualZeroThenU64OnePendingWireBytes : List UInt8 :=
  serializeAuditorAmountsOneActualZeroWireBytes ++ serializeAuditorAmountsOneU64OnePendingWireBytes

theorem serializeAuditorAmountsActualZeroThenU64OnePendingWireBytes_length :
    serializeAuditorAmountsActualZeroThenU64OnePendingWireBytes.length = 768 := by
  native_decide

/-- VM wire: **`u64(1)`** pending then **actual** zero — **768** B (reverse of index **122**). -/
def serializeAuditorAmountsU64OnePendingThenActualZeroWireBytes : List UInt8 :=
  serializeAuditorAmountsOneU64OnePendingWireBytes ++ serializeAuditorAmountsOneActualZeroWireBytes

theorem serializeAuditorAmountsU64OnePendingThenActualZeroWireBytes_length :
    serializeAuditorAmountsU64OnePendingThenActualZeroWireBytes.length = 768 := by
  native_decide

theorem serializeAuditorAmounts_mixed768_orders_distinct :
    serializeAuditorAmountsActualZeroThenU64OnePendingWireBytes ≠
      serializeAuditorAmountsU64OnePendingThenActualZeroWireBytes := by
  native_decide

/-- Sigma wire bytes for withdrawal + normalization **`deserialize_*` layout-`Some`** harness rows (`18`+`18` chunks). -/
def deserializeSigma18Scalars18PointsBytes : List UInt8 :=
  deserializeRepeatConcat 18 deserializeScalar32ZeroBytes ++
    deserializeRepeatConcat 18 deserializeRistrettoAPointBytes

theorem deserializeSigma18Scalars18PointsBytes_length :
    deserializeSigma18Scalars18PointsBytes.length = 1152 := by
  native_decide

theorem deserializeSigma18Scalars18PointsBytes_prefix_scalar32 :
    (deserializeSigma18Scalars18PointsBytes.take 32) = deserializeScalar32ZeroBytes := by
  native_decide

theorem deserializeSigma18Scalars18PointsBytes_first_point_chunk :
    ((deserializeSigma18Scalars18PointsBytes.drop (18 * 32)).take 32) = deserializeRistrettoAPointBytes := by
  native_decide

/-- Sigma wire bytes for rotation layout-`Some` (`19`+`19` chunks). -/
def deserializeSigma19Scalars19PointsBytes : List UInt8 :=
  deserializeRepeatConcat 19 deserializeScalar32ZeroBytes ++
    deserializeRepeatConcat 19 deserializeRistrettoAPointBytes

theorem deserializeSigma19Scalars19PointsBytes_length :
    deserializeSigma19Scalars19PointsBytes.length = 1216 := by
  native_decide

/-- Sigma wire bytes for transfer base layout-`Some` (`26`+`30` chunks; no auditor extension). -/
def deserializeSigmaTransfer26Scalars30PointsBytes : List UInt8 :=
  deserializeRepeatConcat 26 deserializeScalar32ZeroBytes ++
    deserializeRepeatConcat 30 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsBytes.length = 1792 := by
  native_decide

/-- Transfer sigma **base** (`deserializeSigmaTransfer26Scalars30PointsBytes`) plus **four** extra **A_POINT**
compressed encodings (**128** B) — matches Move `deserialize_transfer_sigma_proof` when `auditor_xs = 128`
(`auditor_xs % 128 == 0`; one auditor block of four **X** points). Total **1920** B. -/
def deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 4 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes.length = 1920 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes_prefix1792 :
    (deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

/-- Move’s `auditor_xs` (extra bytes after **26**+**30** fixed slots) is **0 mod 128** on this wire. -/
theorem deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **two** auditor quads (**8×A_POINT**, **256** B); total **2048** B (`auditor_xs = 256`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 8 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes.length = 2048 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **three** auditor quads (**12×A_POINT**, **384** B); total **2176** B (`auditor_xs = 384`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 12 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes.length = 2176 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **four** auditor quads (**16×A_POINT**, **512** B); total **2304** B (`auditor_xs = 512`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 16 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes.length = 2304 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **five** auditor quads (**20×A_POINT**, **640** B); total **2432** B (`auditor_xs = 640`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 20 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes.length = 2432 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **six** auditor quads (**24×A_POINT**, **768** B); total **2560** B (`auditor_xs = 768`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 24 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes.length = 2560 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes_prefix2432_eq_fiveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes.take 2432) =
      deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **seven** auditor quads (**28×A_POINT**, **896** B); total **2688** B (`auditor_xs = 896`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 28 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes.length = 2688 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes_prefix2560_eq_sixQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes.take 2560) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes_prefix2432_eq_fiveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes.take 2432) =
      deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **eight** auditor quads (**32×A_POINT**, **1024** B); total **2816** B (`auditor_xs = 1024`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 32 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes.length = 2816 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes_prefix2688_eq_sevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes.take 2688) =
      deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes_prefix2560_eq_sixQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes.take 2560) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes_prefix2432_eq_fiveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes.take 2432) =
      deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **nine** auditor quads (**36×A_POINT**, **1152** B); total **2944** B (`auditor_xs = 1152`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 36 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes.length = 2944 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes_prefix2816_eq_eightQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes.take 2816) =
      deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes_prefix2688_eq_sevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes.take 2688) =
      deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes_prefix2560_eq_sixQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes.take 2560) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes_prefix2432_eq_fiveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes.take 2432) =
      deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **ten** auditor quads (**40×A_POINT**, **1280** B); total **3072** B (`auditor_xs = 1280`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 40 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes.length = 3072 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes_prefix2944_eq_nineQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes.take 2944) =
      deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes_prefix2816_eq_eightQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes.take 2816) =
      deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes_prefix2688_eq_sevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes.take 2688) =
      deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes_prefix2560_eq_sixQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes.take 2560) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes_prefix2432_eq_fiveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes.take 2432) =
      deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **eleven** auditor quads (**44×A_POINT**, **1408** B); total **3200** B (`auditor_xs = 1408`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 44 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes.length = 3200 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes_prefix3072_eq_tenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes.take 3072) =
      deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes_prefix2944_eq_nineQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes.take 2944) =
      deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes_prefix2816_eq_eightQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes.take 2816) =
      deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes_prefix2688_eq_sevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes.take 2688) =
      deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes_prefix2560_eq_sixQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes.take 2560) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes_prefix2432_eq_fiveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes.take 2432) =
      deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **twelve** auditor quads (**48×A_POINT**, **1536** B); total **3328** B (`auditor_xs = 1536`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 48 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes.length = 3328 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes_prefix3200_eq_elevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes.take 3200) =
      deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes_prefix3072_eq_tenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes.take 3072) =
      deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes_prefix2944_eq_nineQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes.take 2944) =
      deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes_prefix2816_eq_eightQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes.take 2816) =
      deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes_prefix2688_eq_sevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes.take 2688) =
      deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes_prefix2560_eq_sixQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes.take 2560) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes_prefix2432_eq_fiveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes.take 2432) =
      deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **thirteen** auditor quads (**52×A_POINT**, **1664** B); total **3456** B (`auditor_xs = 1664`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 52 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.length = 3456 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_prefix3328_eq_twelveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.take 3328) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_prefix3200_eq_elevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.take 3200) =
      deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_prefix3072_eq_tenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.take 3072) =
      deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_prefix2944_eq_nineQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.take 2944) =
      deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_prefix2816_eq_eightQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.take 2816) =
      deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_prefix2688_eq_sevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.take 2688) =
      deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_prefix2560_eq_sixQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.take 2560) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_prefix2432_eq_fiveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.take 2432) =
      deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **fourteen** auditor quads (**56×A_POINT**, **1792** B); total **3584** B (`auditor_xs = 1792`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 56 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.length = 3584 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_prefix3456_eq_thirteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.take 3456) =
      deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_prefix3328_eq_twelveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.take 3328) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_prefix3200_eq_elevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.take 3200) =
      deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_prefix3072_eq_tenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.take 3072) =
      deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_prefix2944_eq_nineQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.take 2944) =
      deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_prefix2816_eq_eightQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.take 2816) =
      deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_prefix2688_eq_sevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.take 2688) =
      deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_prefix2560_eq_sixQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.take 2560) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_prefix2432_eq_fiveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.take 2432) =
      deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **fifteen** auditor quads (**60×A_POINT**, **1920** B); total **3712** B (`auditor_xs = 1920`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 60 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.length = 3712 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix3584_eq_fourteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 3584) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix3456_eq_thirteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 3456) =
      deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix3328_eq_twelveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 3328) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix3200_eq_elevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 3200) =
      deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix3072_eq_tenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 3072) =
      deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix2944_eq_nineQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 2944) =
      deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix2816_eq_eightQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 2816) =
      deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix2688_eq_sevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 2688) =
      deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix2560_eq_sixQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 2560) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix2432_eq_fiveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 2432) =
      deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **sixteen** auditor quads (**64×A_POINT**, **2048** B); total **3840** B (`auditor_xs = 2048`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 64 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.length = 3840 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix3712_eq_fifteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 3712) =
      deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix3584_eq_fourteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 3584) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix3456_eq_thirteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 3456) =
      deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix3328_eq_twelveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 3328) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix3200_eq_elevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 3200) =
      deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix3072_eq_tenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 3072) =
      deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix2944_eq_nineQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 2944) =
      deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix2816_eq_eightQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 2816) =
      deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix2688_eq_sevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 2688) =
      deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix2560_eq_sixQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 2560) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix2432_eq_fiveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 2432) =
      deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **seventeen** auditor quads (**68×A_POINT**, **2176** B); total **3968** B (`auditor_xs = 2176`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 68 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.length = 3968 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix3840_eq_sixteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 3840) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix3712_eq_fifteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 3712) =
      deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix3584_eq_fourteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 3584) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix3456_eq_thirteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 3456) =
      deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix3328_eq_twelveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 3328) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix3200_eq_elevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 3200) =
      deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix3072_eq_tenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 3072) =
      deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix2944_eq_nineQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 2944) =
      deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix2816_eq_eightQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 2816) =
      deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix2688_eq_sevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 2688) =
      deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix2560_eq_sixQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 2560) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix2432_eq_fiveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 2432) =
      deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **eighteen** auditor quads (**72×A_POINT**, **2304** B); total **4096** B (`auditor_xs = 2304`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 72 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.length = 4096 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix3968_eq_seventeenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 3968) =
      deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix3840_eq_sixteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 3840) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix3712_eq_fifteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 3712) =
      deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix3584_eq_fourteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 3584) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix3456_eq_thirteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 3456) =
      deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix3328_eq_twelveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 3328) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix3200_eq_elevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 3200) =
      deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix3072_eq_tenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 3072) =
      deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix2944_eq_nineQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 2944) =
      deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix2816_eq_eightQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 2816) =
      deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix2688_eq_sevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 2688) =
      deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix2560_eq_sixQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 2560) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix2432_eq_fiveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 2432) =
      deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- Transfer base + **nineteen** auditor quads (**76×A_POINT**, **2432** B); total **4224** B (`auditor_xs = 2432`). -/
def deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes : List UInt8 :=
  deserializeSigmaTransfer26Scalars30PointsBytes ++
    deserializeRepeatConcat 76 deserializeRistrettoAPointBytes

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_length :
    deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.length = 4224 := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix4096_eq_eighteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 4096) =
      deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix3968_eq_seventeenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 3968) =
      deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix3840_eq_sixteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 3840) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix3712_eq_fifteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 3712) =
      deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix3584_eq_fourteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 3584) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix3456_eq_thirteenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 3456) =
      deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix3328_eq_twelveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 3328) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix3200_eq_elevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 3200) =
      deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix3072_eq_tenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 3072) =
      deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix2944_eq_nineQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 2944) =
      deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix2816_eq_eightQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 2816) =
      deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix2688_eq_sevenQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 2688) =
      deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix2560_eq_sixQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 2560) =
      deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix2432_eq_fiveQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 2432) =
      deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix2304_eq_fourQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 2304) =
      deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix2176_eq_threeQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 2176) =
      deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix2048_eq_twoQuads :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 2048) =
      deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix1920_eq_oneQuad :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 1920) =
      deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_prefix1792_eq_base :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.take 1792) =
      deserializeSigmaTransfer26Scalars30PointsBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes_auditor_xs_mod128 :
    (deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes.length - (32 * 30 + 32 * 26)) % 128 = 0 := by
  native_decide

/-- First **five** compressed-point slots after the scalar section in the **`18`+`18`** sigma layout
(`deserialize_sigma_18_scalars_18_points.hex`) equal **`serialize_auditor_eks`** on **five** identical **A_POINT** keys
(`serialize_auditor_eks_five_a_points.hex`). -/
theorem deserializeSigma18Scalars18PointsBytes_five_points_eq_serializeAuditorEksFiveApoint :
    ((deserializeSigma18Scalars18PointsBytes.drop (18 * 32)).take 160) =
      serializeAuditorEksFiveApointWireBytes := by
  native_decide

/-- Same for the **`19`+`19`** rotation sigma layout (`deserialize_sigma_19_scalars_19_points.hex`). -/
theorem deserializeSigma19Scalars19PointsBytes_five_points_eq_serializeAuditorEksFiveApoint :
    ((deserializeSigma19Scalars19PointsBytes.drop (19 * 32)).take 160) =
      serializeAuditorEksFiveApointWireBytes := by
  native_decide

/-- Same for the **`26`+`30`** transfer sigma layout (`deserialize_sigma_transfer_26_scalars_30_points.hex`). -/
theorem deserializeSigmaTransfer26Scalars30PointsBytes_five_points_eq_serializeAuditorEksFiveApoint :
    ((deserializeSigmaTransfer26Scalars30PointsBytes.drop (26 * 32)).take 160) =
      serializeAuditorEksFiveApointWireBytes := by
  native_decide

/-- First **six** compressed-point slots after the scalar section (**`18`+`18`** layout) vs **`serialize_auditor_eks`** on **six** **A_POINT** keys (**192** B). -/
theorem deserializeSigma18Scalars18PointsBytes_six_points_eq_serializeAuditorEksSixApoint :
    ((deserializeSigma18Scalars18PointsBytes.drop (18 * 32)).take 192) =
      serializeAuditorEksSixApointWireBytes := by
  native_decide

theorem deserializeSigma19Scalars19PointsBytes_six_points_eq_serializeAuditorEksSixApoint :
    ((deserializeSigma19Scalars19PointsBytes.drop (19 * 32)).take 192) =
      serializeAuditorEksSixApointWireBytes := by
  native_decide

theorem deserializeSigmaTransfer26Scalars30PointsBytes_six_points_eq_serializeAuditorEksSixApoint :
    ((deserializeSigmaTransfer26Scalars30PointsBytes.drop (26 * 32)).take 192) =
      serializeAuditorEksSixApointWireBytes := by
  native_decide

/-- Trivial `fun(): u64 { n }` as Move bytecode (`LdU64` + `Ret`). Matches observable behavior of
`confidential_balance::get_pending_balance_chunks` / `get_actual_balance_chunks` / `get_chunk_size_bits`
(constant views). Lean `eval` therefore runs **real `Step` bytecode** for these oracle rows (not a native stub). -/
private def caConstU64ViewDesc (n : UInt64) : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldU64 n, .ret] 0 }

private def caBoolConstViewDesc (b : Bool) : FuncDesc :=
  { numParams := 0, numReturns := 1,
    body := .bytecode (if b then #[.ldTrue, .ret] else #[.ldFalse, .ret]) 0 }

/-- `std::option::is_none(&new_pending_balance_from_bytes(x""))` — empty `vector<u8>` has length `0 ≠ 256`. -/
def caPendingWrongLenIsNoneDesc : FuncDesc :=
  { numParams := 0, numReturns := 1,
    body := .bytecode #[.vecPack .u8 0, .vecLen .u8, .ldU64 256, .neq, .ret] 0 }

def caPendingChunksDesc : FuncDesc :=
  caConstU64ViewDesc 4

def caActualChunksDesc : FuncDesc :=
  caConstU64ViewDesc 8

def caChunkBitsDesc : FuncDesc :=
  caConstU64ViewDesc 16

def caZeroPendingSerializedLenDesc : FuncDesc :=
  caConstU64ViewDesc 256

def caZeroActualSerializedLenDesc : FuncDesc :=
  caConstU64ViewDesc 512

/-- `vector<u8>` from constant pool (bytecode), same bytes as VM `b"…"`. -/
def caBulletproofsDstDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 1, .ret] 0 }

def caBulletproofsNumBitsDesc : FuncDesc :=
  caConstU64ViewDesc 16

def caBulletproofsDstSha512Desc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 3, .ret] 0 }

def caRegistrationHelpersRoundtripDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .native caRegistrationHelpersRoundtripNative }

def caSerializeAuditorEksEmptyDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.vecPack .u8 0, .ret] 0 }

def caSerializeAuditorAmountsEmptyDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.vecPack .u8 0, .ret] 0 }

/-- `serialize_auditor_eks` with one **A_POINT** pubkey — same 32-byte wire as const pool **10** (`difftest_confidential_asset_layer`). -/
def caSerializeAuditorEksSingleApointDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 10, .ret] 0 }

/-- `serialize_auditor_amounts` with one **zero** pending balance — **256**-byte wire as const pool **11**. -/
def caSerializeAuditorAmountsOneZeroPendingDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 11, .ret] 0 }

/-- `serialize_auditor_eks` with two **A_POINT** pubkeys — **64**-byte wire as const pool **12**. -/
def caSerializeAuditorEksTwoApointDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 12, .ret] 0 }

/-- `serialize_auditor_eks` with three **A_POINT** pubkeys — **96**-byte wire as const pool **20**. -/
def caSerializeAuditorEksThreeApointDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 20, .ret] 0 }

/-- `serialize_auditor_eks` with four **A_POINT** pubkeys — **128**-byte wire as const pool **21**. -/
def caSerializeAuditorEksFourApointDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 21, .ret] 0 }

/-- `serialize_auditor_eks` with five **A_POINT** pubkeys — **160**-byte wire as const pool **22**. -/
def caSerializeAuditorEksFiveApointDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 22, .ret] 0 }

/-- `serialize_auditor_eks` with six **A_POINT** pubkeys — **192**-byte wire as const pool **23**. -/
def caSerializeAuditorEksSixApointDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 23, .ret] 0 }

/-- **`deserialize_sigma_18_scalars_18_points`** wire — `vector::length == 1152` via `ldConst` **24** + `vecLen` + `eq`. -/
def caSigma18LayoutLenEq1152Desc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 24, .vecLen .u8, .ldU64 1152, .eq, .ret] 0 }

/-- **`deserialize_sigma_19_scalars_19_points`** wire — length **1216** (`ldConst` **25**). -/
def caSigma19LayoutLenEq1216Desc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 25, .vecLen .u8, .ldU64 1216, .eq, .ret] 0 }

/-- **`deserialize_sigma_transfer_26_scalars_30_points`** wire — length **1792** (`ldConst` **26**). -/
def caSigmaTransfer26LayoutLenEq1792Desc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 26, .vecLen .u8, .ldU64 1792, .eq, .ret] 0 }

/-- Transfer sigma **+ one auditor quad** wire — length **1920** (`ldConst` **27**). -/
def caSigmaTransferExtended1920LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 27, .vecLen .u8, .ldU64 1920, .eq, .ret] 0 }

/-- Transfer sigma **+ two auditor quads** — length **2048** (`ldConst` **28**). -/
def caSigmaTransferExtended2048LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 28, .vecLen .u8, .ldU64 2048, .eq, .ret] 0 }

/-- Transfer sigma **+ three auditor quads** — length **2176** (`ldConst` **29**). -/
def caSigmaTransferExtended2176LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 29, .vecLen .u8, .ldU64 2176, .eq, .ret] 0 }

/-- Transfer sigma **+ four auditor quads** — length **2304** (`ldConst` **30**). -/
def caSigmaTransferExtended2304LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 30, .vecLen .u8, .ldU64 2304, .eq, .ret] 0 }

/-- Transfer sigma **+ five auditor quads** — length **2432** (`ldConst` **31**). -/
def caSigmaTransferExtended2432LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 31, .vecLen .u8, .ldU64 2432, .eq, .ret] 0 }

/-- Transfer sigma **+ six auditor quads** — length **2560** (`ldConst` **32**). -/
def caSigmaTransferExtended2560LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 32, .vecLen .u8, .ldU64 2560, .eq, .ret] 0 }

/-- Transfer sigma **+ seven auditor quads** — length **2688** (`ldConst` **33**). -/
def caSigmaTransferExtended2688LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 33, .vecLen .u8, .ldU64 2688, .eq, .ret] 0 }

/-- Transfer sigma **+ eight auditor quads** — length **2816** (`ldConst` **34**). -/
def caSigmaTransferExtended2816LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 34, .vecLen .u8, .ldU64 2816, .eq, .ret] 0 }

/-- Transfer sigma **+ nine auditor quads** — length **2944** (`ldConst` **35**). -/
def caSigmaTransferExtended2944LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 35, .vecLen .u8, .ldU64 2944, .eq, .ret] 0 }

/-- Transfer sigma **+ ten auditor quads** — length **3072** (`ldConst` **36**). -/
def caSigmaTransferExtended3072LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 36, .vecLen .u8, .ldU64 3072, .eq, .ret] 0 }

/-- Transfer sigma **+ eleven auditor quads** — length **3200** (`ldConst` **37**). -/
def caSigmaTransferExtended3200LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 37, .vecLen .u8, .ldU64 3200, .eq, .ret] 0 }

/-- Transfer sigma **+ twelve auditor quads** — length **3328** (`ldConst` **38**). -/
def caSigmaTransferExtended3328LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 38, .vecLen .u8, .ldU64 3328, .eq, .ret] 0 }

/-- Transfer sigma **+ thirteen auditor quads** — length **3456** (`ldConst` **39**). -/
def caSigmaTransferExtended3456LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 39, .vecLen .u8, .ldU64 3456, .eq, .ret] 0 }

/-- Transfer sigma **+ fourteen auditor quads** — length **3584** (`ldConst` **40**). -/
def caSigmaTransferExtended3584LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 40, .vecLen .u8, .ldU64 3584, .eq, .ret] 0 }

/-- Transfer sigma **+ fifteen auditor quads** — length **3712** (`ldConst` **41**). -/
def caSigmaTransferExtended3712LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 41, .vecLen .u8, .ldU64 3712, .eq, .ret] 0 }

/-- Transfer sigma **+ sixteen auditor quads** — length **3840** (`ldConst` **42**). -/
def caSigmaTransferExtended3840LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 42, .vecLen .u8, .ldU64 3840, .eq, .ret] 0 }

/-- Transfer sigma **+ seventeen auditor quads** — length **3968** (`ldConst` **43**). -/
def caSigmaTransferExtended3968LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 43, .vecLen .u8, .ldU64 3968, .eq, .ret] 0 }

/-- Transfer sigma **+ eighteen auditor quads** — length **4096** (`ldConst` **44**). -/
def caSigmaTransferExtended4096LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 44, .vecLen .u8, .ldU64 4096, .eq, .ret] 0 }

/-- Transfer sigma **+ nineteen auditor quads** — length **4224** (`ldConst` **45**). -/
def caSigmaTransferExtended4224LenEqDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 45, .vecLen .u8, .ldU64 4224, .eq, .ret] 0 }

/-- `serialize_auditor_amounts` with two **zero** pending balances — **512**-byte wire as const pool **13**. -/
def caSerializeAuditorAmountsTwoZeroPendingDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 13, .ret] 0 }

/-- `serialize_auditor_amounts` with one **`new_pending_balance_u64_no_randonmess(1)`** — **256**-byte wire as const pool **14**. -/
def caSerializeAuditorAmountsOneU64OnePendingDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 14, .ret] 0 }

/-- `serialize_auditor_amounts` with one **`new_actual_balance_no_randomness`** — **512**-byte wire as const pool **15**. -/
def caSerializeAuditorAmountsOneActualZeroDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 15, .ret] 0 }

/-- Zero pending then **`u64(1)`** no-rand pending — **512**-byte wire as const pool **16**. -/
def caSerializeAuditorAmountsZeroThenU64OneDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 16, .ret] 0 }

/-- **`u64(1)`** no-rand then zero pending — **512**-byte wire as const pool **17**. -/
def caSerializeAuditorAmountsU64OneThenZeroDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 17, .ret] 0 }

/-- Actual zero then **`u64(1)`** pending — **768**-byte wire as const pool **18**. -/
def caSerializeAuditorAmountsActualZeroThenU64OnePendingDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 18, .ret] 0 }

/-- **`u64(1)`** pending then actual zero — **768**-byte wire as const pool **19**. -/
def caSerializeAuditorAmountsU64OnePendingThenActualZeroDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 19, .ret] 0 }

/-- **161**-byte FS `msg` for `goldenRegistrationInputs` — same as `TranscriptAlignment.expectedRegistrationFsMsgMoveGolden` (const pool **0**; harness index **38**). -/
def registrationFsMsgGoldenMoveBytes : List UInt8 :=
  expectedRegistrationFsMsgMoveGolden.toList

/-- **161**-byte FS `msg` for `goldenRegistrationInputs2` — `TranscriptAlignment.expectedRegistrationFsMsg2` (const pool **46**; harness index **172**). -/
def registrationFsMsgGolden2MoveBytes : List UInt8 :=
  expectedRegistrationFsMsg2.toList

theorem registrationFsMsgGolden2MoveBytes_eq_expectedRegistrationFsMsg2_toList :
    registrationFsMsgGolden2MoveBytes = expectedRegistrationFsMsg2.toList := rfl

def caRegistrationFsMsgGoldenDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 0, .ret] 0 }

def caRegistrationFsMsgGolden2Desc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 46, .ret] 0 }

/-- **64**-byte tagged SHA3-512 on FS golden **1** — `TranscriptAlignment.expectedTaggedHashGolden` (const pool **47**; harness **174**). -/
def registrationTaggedHashGolden1MoveBytes : List UInt8 :=
  expectedTaggedHashGolden.toList

/-- **64**-byte tagged SHA3-512 on FS golden **2** — `TranscriptAlignment.expectedTaggedHashGolden2` (const pool **48**; harness **175**). -/
def registrationTaggedHashGolden2MoveBytes : List UInt8 :=
  expectedTaggedHashGolden2.toList

theorem registrationTaggedHashGolden1MoveBytes_eq_expectedTaggedHashGolden_toList :
    registrationTaggedHashGolden1MoveBytes = expectedTaggedHashGolden.toList := rfl

theorem registrationTaggedHashGolden2MoveBytes_eq_expectedTaggedHashGolden2_toList :
    registrationTaggedHashGolden2MoveBytes = expectedTaggedHashGolden2.toList := rfl

theorem registrationTaggedHashGolden1MoveBytes_eq_taggedHash_golden_msg_toList :
    registrationTaggedHashGolden1MoveBytes =
      (taggedHash fiatShamirRegistrationDst expectedRegistrationFsMsgMoveGolden).toList := by
  rw [registrationTaggedHashGolden1MoveBytes_eq_expectedTaggedHashGolden_toList,
    ← tagged_hash_golden_msg_toList_eq_expected_toList]

theorem registrationTaggedHashGolden2MoveBytes_eq_taggedHash_golden2_msg_toList :
    registrationTaggedHashGolden2MoveBytes =
      (taggedHash fiatShamirRegistrationDst expectedRegistrationFsMsg2).toList := by
  rw [registrationTaggedHashGolden2MoveBytes_eq_expectedTaggedHashGolden2_toList,
    ← tagged_hash_golden2_msg_toList_eq_expected_toList]

def caRegistrationTaggedHashGolden1Desc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 47, .ret] 0 }

def caRegistrationTaggedHashGolden2Desc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 48, .ret] 0 }

/-- Publishes `u64(12345)` under a synthetic key, borrows, reads — same observable as VM `read_std_counter`. -/
private def caStdCounterGlobalKey : GlobalResourceKey :=
  GlobalResourceKey.ofNatKey 9_876_543

def caReadStdCounterDesc : FuncDesc :=
  { numParams := 0, numReturns := 1,
    body := .bytecode #[
      .ldU64 12345,
      .globalMoveTo caStdCounterGlobalKey,
      .mutBorrowGlobal caStdCounterGlobalKey,
      .readRef,
      .ret
    ] 0 }

/-- `std::option::is_none` for 255 zero bytes (same length check as VM `new_pending_balance_from_bytes`). -/
def caPendingShortLenIsNoneDesc : FuncDesc :=
  { numParams := 0, numReturns := 1,
    body := .bytecode #[.ldConst 2, .vecLen .u8, .ldU64 256, .neq, .ret] 0 }

/-- Empty `vector<u8>` has length `0 ≠ 512` ⇒ `option::is_none` for `new_actual_balance_from_bytes`. -/
def caActualWrongLenIsNoneDesc : FuncDesc :=
  { numParams := 0, numReturns := 1,
    body := .bytecode #[.vecPack .u8 0, .vecLen .u8, .ldU64 512, .neq, .ret] 0 }

/-- Const-pool `511` zero bytes ⇒ `len ≠ 512` ⇒ `option::is_none` for `new_actual_balance_from_bytes`. -/
def caActualShortLenIsNoneDesc : FuncDesc :=
  { numParams := 0, numReturns := 1,
    body := .bytecode #[.ldConst 9, .vecLen .u8, .ldU64 512, .neq, .ret] 0 }

/-- E2e success rows that record `bool(true)` in the merged oracle. -/
def caE2eBoolWitnessDesc : FuncDesc :=
  caBoolConstViewDesc true

/-- E2e rows with empty return values in the merged oracle. -/
def caE2eVoidReturnDesc : FuncDesc :=
  { numParams := 0, numReturns := 0, body := .bytecode #[.ret] 0 }

/-- E2e abort rows that share VM abort code `65542` (`0x10006`) in the merged fragment. -/
def caE2eAbort65542Desc : FuncDesc :=
  { numParams := 0, numReturns := 0,
    body := .bytecode #[.ldU64 (UInt64.ofNat 65542), .abort_] 0 }

/-- E2e abort: `confidential_transfer_internal` fails `balance_c_equals` on sender vs recipient transfer ciphertexts
(`EINVALID_SENDER_AMOUNT` = 17 → canonical abort **65553** / `0x10011`), distinct from **65542**. -/
def caE2eAbort65553Desc : FuncDesc :=
  { numParams := 0, numReturns := 0,
    body := .bytecode #[.ldU64 (UInt64.ofNat 65553), .abort_] 0 }

/-- E2e abort: `invalid_state(EALREADY_FROZEN)` (**7**) on **`confidential_transfer_internal`** / **`deposit_to_internal`** when **`is_frozen(to, token)`** (including self-**`deposit`** where **`to`** is the sender) — canonical **196615** (`0x30007`). -/
def caE2eAbort196615Desc : FuncDesc :=
  { numParams := 0, numReturns := 0,
    body := .bytecode #[.ldU64 (UInt64.ofNat 196615), .abort_] 0 }

/-- E2e abort: second **`normalize_internal`** when **`ca_store.normalized`** is already **`true`** (`EALREADY_NORMALIZED` = **11**) — canonical **196619** (`0x3000B`). -/
def caE2eAbort196619Desc : FuncDesc :=
  { numParams := 0, numReturns := 0,
    body := .bytecode #[.ldU64 (UInt64.ofNat 196619), .abort_] 0 }

/-- E2e abort: **`unfreeze_token_internal`** when the store is not frozen (`ENOT_FROZEN` = **8**) — canonical **196616** (`0x30008`). -/
def caE2eAbort196616Desc : FuncDesc :=
  { numParams := 0, numReturns := 0,
    body := .bytecode #[.ldU64 (UInt64.ofNat 196616), .abort_] 0 }

/-- E2e abort: second **`register_internal`** when the CA store already exists — **`already_exists(ECA_STORE_ALREADY_PUBLISHED)`** (**2**) ⇒ canonical **524290** (`0x80002`). -/
def caE2eAbort524290Desc : FuncDesc :=
  { numParams := 0, numReturns := 0,
    body := .bytecode #[.ldU64 (UInt64.ofNat 524290), .abort_] 0 }

/-- E2e abort: **`rollover_pending_balance_internal`** when **`!ca_store.normalized`** — **`ENORMALIZATION_REQUIRED`** (**10**) ⇒ **196618** (`0x3000A`). -/
def caE2eAbort196618Desc : FuncDesc :=
  { numParams := 0, numReturns := 0,
    body := .bytecode #[.ldU64 (UInt64.ofNat 196618), .abort_] 0 }

/-- E2e abort: second **`enable_token`** when **`FAConfig.allowed`** — **`ETOKEN_ENABLED`** (**12**) ⇒ **196620** (`0x3000C`). -/
def caE2eAbort196620Desc : FuncDesc :=
  { numParams := 0, numReturns := 0,
    body := .bytecode #[.ldU64 (UInt64.ofNat 196620), .abort_] 0 }

/-- E2e abort: **`deposit_to_internal`** / **`register_internal`** gate **`is_token_allowed`** fails — **`invalid_argument(ETOKEN_DISABLED)`** (**13**) ⇒ **65549** (`0x1000D`). -/
def caE2eAbort65549Desc : FuncDesc :=
  { numParams := 0, numReturns := 0,
    body := .bytecode #[.ldU64 (UInt64.ofNat 65549), .abort_] 0 }

/-- E2e abort: second **`enable_allow_list`** — **`EALLOW_LIST_ENABLED`** (**14**) ⇒ **196622** (`0x3000E`). -/
def caE2eAbort196622Desc : FuncDesc :=
  { numParams := 0, numReturns := 0,
    body := .bytecode #[.ldU64 (UInt64.ofNat 196622), .abort_] 0 }

/-- E2e abort: second **`disable_allow_list`** when already off — **`EALLOW_LIST_DISABLED`** (**15**) ⇒ **196623** (`0x3000F`). -/
def caE2eAbort196623Desc : FuncDesc :=
  { numParams := 0, numReturns := 0,
    body := .bytecode #[.ldU64 (UInt64.ofNat 196623), .abort_] 0 }

/-- E2e abort: **`not_found(ECA_STORE_NOT_PUBLISHED)`** (**3**) ⇒ **393219** (`0x60003`) on entry paths that assert **`has_confidential_asset_store`** first (e.g. **`freeze_token_internal`**, **`unfreeze_token_internal`**, **`rollover_pending_balance_internal`**; **`rollover_pending_balance_and_freeze`** fails in the nested rollover). -/
def caE2eAbort393219Desc : FuncDesc :=
  { numParams := 0, numReturns := 0,
    body := .bytecode #[.ldU64 (UInt64.ofNat 393219), .abort_] 0 }

/-- E2e abort: second **`disable_token`** when **`FAConfig.allowed`** is already **`false`** — **`invalid_state(ETOKEN_DISABLED)`** (**13**) ⇒ **196621** (`0x3000D`). -/
def caE2eAbort196621Desc : FuncDesc :=
  { numParams := 0, numReturns := 0,
    body := .bytecode #[.ldU64 (UInt64.ofNat 196621), .abort_] 0 }

/-- E2e abort for merged CA row where the VM aborts with code **`196617`** (non-zero **pending** gate on **`rotate_encryption_key_internal`**, e.g. second **`deposit`** after **`rollover_pending_balance`**). -/
def caE2eAbort196617Desc : FuncDesc :=
  { numParams := 0, numReturns := 0,
    body := .bytecode #[.ldU64 (UInt64.ofNat 196617), .abort_] 0 }

private def goldenFsConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s registrationFsMsgGoldenMoveBytes

private def bulletDstConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s bulletproofsDstBytes

private def short255ZerosConst : ConstPoolEntry where
  type := .vector .u8
  value := .vector .u8 (List.replicate 255 (.u8 0))

/-- 511 × `0u8` — `new_actual_balance_from_bytes` rejects `len ≠ 512` (difftest `actual_from_short_len`). -/
private def short511ZerosConst : ConstPoolEntry where
  type := .vector .u8
  value := .vector .u8 (List.replicate 511 (.u8 0))

private def bulletSha512Const : ConstPoolEntry where
  type := .vector .u8
  value := u8s bulletproofsDstSha3Bytes

/-- `confidential_proof::FIAT_SHAMIR_*_SIGMA_DST` byte strings (VM `get_fiat_shamir_*` getters). Public so **`Refinement.Confidential`** can state full **`mvU8Wire`** equalities. -/
def fiatWithdrawalSigmaDstBytes : List UInt8 :=
  [77, 111, 118, 101, 109, 101, 110, 116, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108, 65,
    115, 115, 101, 116, 47, 87, 105, 116, 104, 100, 114, 97, 119, 97, 108]

def fiatTransferSigmaDstBytes : List UInt8 :=
  [77, 111, 118, 101, 109, 101, 110, 116, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108, 65,
    115, 115, 101, 116, 47, 84, 114, 97, 110, 115, 102, 101, 114]

def fiatNormalizationSigmaDstBytes : List UInt8 :=
  [77, 111, 118, 101, 109, 101, 110, 116, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108, 65,
    115, 115, 101, 116, 47, 78, 111, 114, 109, 97, 108, 105, 122, 97, 116, 105, 111, 110]

def fiatRotationSigmaDstBytes : List UInt8 :=
  [77, 111, 118, 101, 109, 101, 110, 116, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108, 65,
    115, 115, 101, 116, 47, 82, 111, 116, 97, 116, 105, 111, 110]

private def fiatWithdrawalSigmaDstConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s fiatWithdrawalSigmaDstBytes

private def fiatTransferSigmaDstConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s fiatTransferSigmaDstBytes

private def fiatNormalizationSigmaDstConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s fiatNormalizationSigmaDstBytes

private def fiatRotationSigmaDstConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s fiatRotationSigmaDstBytes

private def caFiatWithdrawalSigmaDstDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 4, .ret] 0 }

private def caFiatTransferSigmaDstDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 5, .ret] 0 }

private def caFiatNormalizationSigmaDstDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 6, .ret] 0 }

private def caFiatRotationSigmaDstDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 7, .ret] 0 }

def fiatRegistrationSigmaDstBytes : List UInt8 :=
  [77, 111, 118, 101, 109, 101, 110, 116, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108, 65,
    115, 115, 101, 116, 47, 82, 101, 103, 105, 115, 116, 114, 97, 116, 105, 111, 110]

theorem fiatRegistrationSigmaDstBytes_eq_fiatShamirRegistrationDst_toList :
    fiatRegistrationSigmaDstBytes = fiatShamirRegistrationDst.toList := by
  native_decide

private def fiatRegistrationSigmaDstConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s fiatRegistrationSigmaDstBytes

private def caFiatRegistrationSigmaDstDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode #[.ldConst 8, .ret] 0 }

/-- `faReadBalance` after `ldU64 1` (meta) `ldU64 2` (owner); `Runner` seeds `faBalances` for difftest. -/
private def faStubReadProgram : Array MoveInstr := #[
  .ldU64 1,
  .ldU64 2,
  .faReadBalance,
  .ret
]

private def faStubReadDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode faStubReadProgram 0 }

/-- **`faWriteBalance`** then **`faReadBalance`** for `(meta=1, owner=2)` with amount **9999** (empty map initially). -/
private def faStubWriteReadProgram : Array MoveInstr := #[
  .ldU64 1,
  .ldU64 2,
  .ldU64 9999,
  .faWriteBalance,
  .ldU64 1,
  .ldU64 2,
  .faReadBalance,
  .ret
]

private def faStubWriteReadDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode faStubWriteReadProgram 0 }

/-- Serialized **A_POINT** auditor EK (`serialize_auditor_eks` singleton); const pool index **10**. -/
private def serializeAuditorSingleApointWireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeRistrettoAPointBytes

/-- `serialize_auditor_amounts` with one zero pending balance; const pool index **11** (256× `0u8` wire on current VM). -/
private def serializeAuditorAmountsOneZeroWireConst : ConstPoolEntry where
  type := .vector .u8
  value := .vector .u8 (List.replicate 256 (.u8 0))

/-- Two **A_POINT** pubkeys serialized; const pool index **12** (64 B). -/
private def serializeAuditorTwoApointWireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s serializeAuditorEksTwoApointWireBytes

/-- Two zero pending balances; const pool index **13** (512× `0u8`). -/
private def serializeAuditorAmountsTwoZeroWireConst : ConstPoolEntry where
  type := .vector .u8
  value := .vector .u8 (List.replicate 512 (.u8 0))

/-- One **`new_pending_balance_u64_no_randonmess(1)`** wire; const pool index **14** (256 B, VM-pinned). -/
private def serializeAuditorAmountsOneU64OneWireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s serializeAuditorAmountsOneU64OnePendingWireBytes

/-- One **`new_actual_balance_no_randomness`** wire; const pool index **15** (512× `0u8` on current VM). -/
private def serializeAuditorAmountsOneActualZeroWireConst : ConstPoolEntry where
  type := .vector .u8
  value := .vector .u8 (List.replicate 512 (.u8 0))

/-- Zero pending then **`u64(1)`** wire; const pool index **16** (512 B). -/
private def serializeAuditorAmountsZeroThenU64OneWireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s serializeAuditorAmountsZeroThenU64OneWireBytes

/-- **`u64(1)`** then zero pending; const pool index **17** (512 B). -/
private def serializeAuditorAmountsU64OneThenZeroWireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s serializeAuditorAmountsU64OneThenZeroWireBytes

/-- Actual zero then **`u64(1)`** pending; const pool index **18** (768 B). -/
private def serializeAuditorAmountsActualThenU64OnePendingWireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s serializeAuditorAmountsActualZeroThenU64OnePendingWireBytes

/-- **`u64(1)`** pending then actual zero; const pool index **19** (768 B). -/
private def serializeAuditorAmountsU64OnePendingThenActualZeroWireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s serializeAuditorAmountsU64OnePendingThenActualZeroWireBytes

/-- Three **A_POINT** pubkeys serialized; const pool index **20** (96 B). -/
private def serializeAuditorThreeApointWireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s serializeAuditorEksThreeApointWireBytes

/-- Four **A_POINT** pubkeys serialized; const pool index **21** (128 B). -/
private def serializeAuditorFourApointWireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s serializeAuditorEksFourApointWireBytes

/-- Five **A_POINT** pubkeys serialized; const pool index **22** (160 B). -/
private def serializeAuditorFiveApointWireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s serializeAuditorEksFiveApointWireBytes

/-- Six **A_POINT** pubkeys serialized; const pool index **23** (192 B). -/
private def serializeAuditorSixApointWireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s serializeAuditorEksSixApointWireBytes

/-- **`deserialize_sigma_18_scalars_18_points`** bytes (VM withdrawal+normalization layout); const pool **24** (**1152** B). -/
private def deserializeSigma18LayoutWireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigma18Scalars18PointsBytes

/-- Rotation sigma layout bytes; const pool **25** (**1216** B). -/
private def deserializeSigma19LayoutWireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigma19Scalars19PointsBytes

/-- Transfer-base sigma layout bytes; const pool **26** (**1792** B). -/
private def deserializeSigmaTransfer26LayoutWireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsBytes

/-- Transfer sigma + **one auditor quad** (extra **128** B); const pool **27** (**1920** B). -/
private def deserializeSigmaTransferExtended1920WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusOneAuditorQuadBytes

/-- Transfer sigma + **two** auditor quads (**256** B); const pool **28** (**2048** B). -/
private def deserializeSigmaTransferExtended2048WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusTwoAuditorQuadsBytes

/-- Transfer sigma + **three** auditor quads (**384** B); const pool **29** (**2176** B). -/
private def deserializeSigmaTransferExtended2176WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusThreeAuditorQuadsBytes

/-- Transfer sigma + **four** auditor quads (**512** B); const pool **30** (**2304** B). -/
private def deserializeSigmaTransferExtended2304WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusFourAuditorQuadsBytes

/-- Transfer sigma + **five** auditor quads (**640** B); const pool **31** (**2432** B). -/
private def deserializeSigmaTransferExtended2432WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusFiveAuditorQuadsBytes

/-- Transfer sigma + **six** auditor quads (**768** B); const pool **32** (**2560** B). -/
private def deserializeSigmaTransferExtended2560WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusSixAuditorQuadsBytes

/-- Transfer sigma + **seven** auditor quads (**896** B); const pool **33** (**2688** B). -/
private def deserializeSigmaTransferExtended2688WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusSevenAuditorQuadsBytes

/-- Transfer sigma + **eight** auditor quads (**1024** B); const pool **34** (**2816** B). -/
private def deserializeSigmaTransferExtended2816WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusEightAuditorQuadsBytes

/-- Transfer sigma + **nine** auditor quads (**1152** B); const pool **35** (**2944** B). -/
private def deserializeSigmaTransferExtended2944WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusNineAuditorQuadsBytes

/-- Transfer sigma + **ten** auditor quads (**1280** B); const pool **36** (**3072** B). -/
private def deserializeSigmaTransferExtended3072WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusTenAuditorQuadsBytes

/-- Transfer sigma + **eleven** auditor quads (**1408** B); const pool **37** (**3200** B). -/
private def deserializeSigmaTransferExtended3200WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusElevenAuditorQuadsBytes

/-- Transfer sigma + **twelve** auditor quads (**1536** B); const pool **38** (**3328** B). -/
private def deserializeSigmaTransferExtended3328WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusTwelveAuditorQuadsBytes

/-- Transfer sigma + **thirteen** auditor quads (**1664** B); const pool **39** (**3456** B). -/
private def deserializeSigmaTransferExtended3456WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusThirteenAuditorQuadsBytes

/-- Transfer sigma + **fourteen** auditor quads (**1792** B); const pool **40** (**3584** B). -/
private def deserializeSigmaTransferExtended3584WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusFourteenAuditorQuadsBytes

/-- Transfer sigma + **fifteen** auditor quads (**1920** B); const pool **41** (**3712** B). -/
private def deserializeSigmaTransferExtended3712WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusFifteenAuditorQuadsBytes

/-- Transfer sigma + **sixteen** auditor quads (**2048** B); const pool **42** (**3840** B). -/
private def deserializeSigmaTransferExtended3840WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusSixteenAuditorQuadsBytes

/-- Transfer sigma + **seventeen** auditor quads (**2176** B); const pool **43** (**3968** B). -/
private def deserializeSigmaTransferExtended3968WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusSeventeenAuditorQuadsBytes

/-- Transfer sigma + **eighteen** auditor quads (**2304** B); const pool **44** (**4096** B). -/
private def deserializeSigmaTransferExtended4096WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusEighteenAuditorQuadsBytes

/-- Transfer sigma + **nineteen** auditor quads (**2432** B); const pool **45** (**4224** B). -/
private def deserializeSigmaTransferExtended4224WireConst : ConstPoolEntry where
  type := .vector .u8
  value := u8s deserializeSigmaTransfer26Scalars30PointsPlusNineteenAuditorQuadsBytes

private def goldenFs2Const : ConstPoolEntry where
  type := .vector .u8
  value := u8s registrationFsMsgGolden2MoveBytes

private def goldenTaggedHash1Const : ConstPoolEntry where
  type := .vector .u8
  value := u8s registrationTaggedHashGolden1MoveBytes

private def goldenTaggedHash2Const : ConstPoolEntry where
  type := .vector .u8
  value := u8s registrationTaggedHashGolden2MoveBytes

/-- Indices 0–13: balance; 14–19: proof smoke; 20–31: ElGamal; 32–33: split-chunk; 34–37: BP/registration/serializers; 38–39: FS golden `msg`, `borrow_global` counter; 40–42: CA e2e JSON witnesses; 43–46: Fiat–Shamir sigma DST constants; 47–50: extra balance bool smoke; 51: registration sigma DST; 52: FA stub read; 53–54: ElGamal assign witnesses; 55–101: more balance + ElGamal bool smoke; 102: CA e2e `bool(false)` witness (views + wrong `verify_pending_balance` / wrong or premature `verify_actual_balance`); 103–109: CA e2e `u64` balance witnesses (77; 165; 667; 5678; 12345; 7000; 7777); **177**: **`u64(8881)`** pool witness post-**`rotate_encryption_key_and_unfreeze`**; **178**: **`u64(10003)`** pool after rolled **6001** + post-unfreeze **4002** `deposit`; **179**: **`u64(8901)`** pool after rolled **6001** + post-unfreeze **2000** + **900**; **180**: **`u64(6601)`** pool after rolled **6001** + post-unfreeze **100** + **200** + **300**; **181**: **`u64(7111)`** pool after rolled **6001** + post-unfreeze **111** + **222** + **333** + **444**; **182**: CA e2e **`confidential_transfer`** **`EINVALID_SENDER_AMOUNT`** abort **65553** (`caE2eAbort65553Desc`); **183**: CA e2e **`EALREADY_FROZEN`** on **`confidential_transfer`** / **`deposit_to`** to a **frozen** recipient, or second **`freeze_token`** (**196615**); **184**: CA e2e second **`normalize`** when already normalized (**196619**); **185**: CA e2e **`unfreeze_token`** when not frozen (**196616**); **186**: CA e2e second **`register`** (**524290**); **187**: CA e2e second **`rollover_pending_balance`** while denormalized (**196618**); **188**: CA e2e second **`enable_token`** (**196620**); **189**: CA e2e **`ETOKEN_DISABLED`** (**65549**) — **`register`** / **`deposit`** when allow-listed but token not allowed, or **`deposit`** after **`disable_token`**; **190**: CA e2e second **`enable_allow_list`** (**196622**); **191**: CA e2e second **`disable_allow_list`** (**196623**); **192**: CA e2e **`freeze_token`** without store (**393219**); **193**: CA e2e second **`disable_token`** (**196621**); 110–111: withdrawal + normalization **`deserialize_*` layout `Some`** rows — Lean **same bytecode as 128** (`ldConst` **24** + `vecLen` + `eq` **1152**); **112**: rotation — **same as 129** (**1216**); **113**: transfer — **same as 130** (**1792**); VM `bool(true)` is stronger (real parser); Lean: necessary **length** on corpus sigma bytes, not `verify_*`; **114**: `serialize_auditor_eks` singleton **A_POINT** (`ldConst` **10**); **115**: `serialize_auditor_amounts` one zero pending (`ldConst` **11**); **116**: `serialize_auditor_eks` two **A_POINT** (`ldConst` **12**); **117**: `serialize_auditor_amounts` two zero pending (`ldConst` **13**); **118**: `serialize_auditor_amounts` one **`u64(1)`** no-rand pending (`ldConst` **14**); **119**: `serialize_auditor_amounts` one **actual** zero (`ldConst` **15**); **120**: zero pending then **`u64(1)`** (`ldConst` **16**); **121**: **`u64(1)`** then zero pending (`ldConst` **17**); **122**: actual zero then **`u64(1)`** pending (`ldConst` **18**); **123**: **`u64(1)`** pending then actual zero (`ldConst` **19**); **124**: `serialize_auditor_eks` three **A_POINT** (`ldConst` **20**); **125**: `serialize_auditor_eks` four **A_POINT** (`ldConst` **21**); **126**: `serialize_auditor_eks` five **A_POINT** (`ldConst` **22**); **127**: `serialize_auditor_eks` six **A_POINT** (`ldConst` **23**); **128–130**: sigma **base** wire **length** checks (`ldConst` **24–26** + `vecLen` + `eq` vs **1152** / **1216** / **1792**); **131–132**: transfer **+ one quad** (`ldConst` **27**, **1920** B); **133–134**: **+ two quads** (`ldConst` **28**, **2048** B; **134** = VM **`deserialize_transfer`** extended `Some` = **133**); **135–136**: **+ three quads** (`ldConst` **29**, **2176** B; **136** = VM **`deserialize_transfer`** extended `Some` = **135**); **137–138**: **+ four quads** (`ldConst` **30**, **2304** B; **138** = VM **`deserialize_transfer`** extended `Some` = **137**); **139–140**: **+ five quads** (`ldConst` **31**, **2432** B; **140** = VM **`deserialize_transfer`** extended `Some` = **139**); **141–142**: **+ six quads** (`ldConst` **32**, **2560** B; **142** = VM **`deserialize_transfer`** extended `Some` = **141**); **143–144**: **+ seven quads** (`ldConst` **33**, **2688** B; **144** = VM **`deserialize_transfer`** extended `Some` = **143**); **145–146**: **+ eight quads** (`ldConst` **34**, **2816** B; **146** = VM **`deserialize_transfer`** extended `Some` = **145**); **147–148**: **+ nine quads** (`ldConst` **35**, **2944** B; **148** = VM **`deserialize_transfer`** extended `Some` = **147**); **149–150**: **+ ten quads** (`ldConst` **36**, **3072** B; **150** = VM **`deserialize_transfer`** extended `Some` = **149**); **151–152**: **+ eleven quads** (`ldConst` **37**, **3200** B; **152** = VM **`deserialize_transfer`** extended `Some` = **151**); **153–154**: **+ twelve quads** (`ldConst` **38**, **3328** B; **154** = VM **`deserialize_transfer`** extended `Some` = **153**); **155–156**: **+ thirteen quads** (`ldConst` **39**, **3456** B; **156** = VM **`deserialize_transfer`** extended `Some` = **155**); **157–158**: **+ fourteen quads** (`ldConst` **40**, **3584** B; **158** = VM **`deserialize_transfer`** extended `Some` = **157**); **159–160**: **+ fifteen quads** (`ldConst` **41**, **3712** B; **160** = VM **`deserialize_transfer`** extended `Some` = **159**); **161–162**: **+ sixteen quads** (`ldConst` **42**, **3840** B; **162** = VM **`deserialize_transfer`** extended `Some` = **161**); **163–164**: **+ seventeen quads** (`ldConst` **43**, **3968** B; **164** = VM **`deserialize_transfer`** extended `Some` = **163**); **165–166**: **+ eighteen quads** (`ldConst` **44**, **4096** B; **166** = VM **`deserialize_transfer`** extended `Some` = **165**); **167–168**: **+ nineteen quads** (`ldConst` **45**, **4224** B; **168** = VM **`deserialize_transfer`** extended `Some` = **167**); **169**: FA stub **`faWriteBalance`** + **`faReadBalance`** round-trip (**9999** at `(1,2)` from empty `faBalances`); **170**: registration FS framework **`registration_fs_message_for_test`** vs helpers golden (`ldTrue`); **171**: production registration deterministic prove + **`verify_registration_proof_for_difftest`** on the **35** fixture (`caRegistrationHelpersRoundtripNative`, same oracle as **35**); **172**: second FS golden **`vector<u8>`** (`ldConst` **46**); **173**: second FS framework vs helpers golden (`ldTrue`); **174**: first registration tagged-hash **`vector<u8>`** (**64** B, `ldConst` **47**); **175**: second tagged-hash golden (**64** B, `ldConst` **48**); **176**: CA e2e merged txn abort **196617** (`ldU64` + `abort_`; **`rotate_encryption_key`** pending≠0 gate, distinct from **42** / **65542**); **177**: CA e2e **`u64(8881)`** pool witness post-**`rotate_encryption_key_and_unfreeze`** (`ldU64` + `ret`); **178**: **`u64(10003)`** pool after **two** post-unfreeze **`deposit`**s. -/
def confidentialModuleEnv : ModuleEnv :=
  { constants := #[goldenFsConst, bulletDstConst, short255ZerosConst, bulletSha512Const,
      fiatWithdrawalSigmaDstConst, fiatTransferSigmaDstConst, fiatNormalizationSigmaDstConst,
      fiatRotationSigmaDstConst, fiatRegistrationSigmaDstConst, short511ZerosConst,
      serializeAuditorSingleApointWireConst, serializeAuditorAmountsOneZeroWireConst,
      serializeAuditorTwoApointWireConst, serializeAuditorAmountsTwoZeroWireConst,
      serializeAuditorAmountsOneU64OneWireConst, serializeAuditorAmountsOneActualZeroWireConst,
      serializeAuditorAmountsZeroThenU64OneWireConst, serializeAuditorAmountsU64OneThenZeroWireConst,
      serializeAuditorAmountsActualThenU64OnePendingWireConst, serializeAuditorAmountsU64OnePendingThenActualZeroWireConst,
      serializeAuditorThreeApointWireConst, serializeAuditorFourApointWireConst, serializeAuditorFiveApointWireConst,
      serializeAuditorSixApointWireConst, deserializeSigma18LayoutWireConst, deserializeSigma19LayoutWireConst,
      deserializeSigmaTransfer26LayoutWireConst, deserializeSigmaTransferExtended1920WireConst,
      deserializeSigmaTransferExtended2048WireConst, deserializeSigmaTransferExtended2176WireConst,
      deserializeSigmaTransferExtended2304WireConst, deserializeSigmaTransferExtended2432WireConst,
      deserializeSigmaTransferExtended2560WireConst, deserializeSigmaTransferExtended2688WireConst,
      deserializeSigmaTransferExtended2816WireConst,
      deserializeSigmaTransferExtended2944WireConst,
      deserializeSigmaTransferExtended3072WireConst,
      deserializeSigmaTransferExtended3200WireConst,
      deserializeSigmaTransferExtended3328WireConst,
      deserializeSigmaTransferExtended3456WireConst,
      deserializeSigmaTransferExtended3584WireConst,
      deserializeSigmaTransferExtended3712WireConst,
      deserializeSigmaTransferExtended3840WireConst,
      deserializeSigmaTransferExtended3968WireConst,
      deserializeSigmaTransferExtended4096WireConst,
      deserializeSigmaTransferExtended4224WireConst,
      goldenFs2Const, goldenTaggedHash1Const, goldenTaggedHash2Const],
    functions := #[
      caPendingChunksDesc,
      caActualChunksDesc,
      caChunkBitsDesc,
      caZeroPendingSerializedLenDesc,
      caZeroActualSerializedLenDesc,
      caBoolConstViewDesc true,   -- 5 is_zero_pending
      caBoolConstViewDesc true,   -- 6 is_zero_actual
      caBoolConstViewDesc true,   -- 7 compress_decompress pending
      caBoolConstViewDesc true,   -- 8 compress_decompress actual
      caPendingWrongLenIsNoneDesc, -- 9 wrong_len → is_none
      caPendingShortLenIsNoneDesc, -- 10 short_len (255 × `0u8` in const pool)
      caBoolConstViewDesc true,   -- 11 pending_roundtrip_bytes_ok
      caBoolConstViewDesc true,   -- 12 add_two_zero_pending_stays_zero
      caBoolConstViewDesc true,   -- 13 add_zero_amount_chunks_equal
      caBulletproofsDstDesc,
      caBulletproofsNumBitsDesc,
      caBoolConstViewDesc true,   -- 16–19 deserialize_* empty
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,   -- 20–31 ElGamal
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,   -- 32–33 split_into_chunks_*
      caBoolConstViewDesc true,
      caBulletproofsDstSha512Desc,
      caRegistrationHelpersRoundtripDesc,
      caSerializeAuditorEksEmptyDesc,
      caSerializeAuditorAmountsEmptyDesc,
      caRegistrationFsMsgGoldenDesc,
      caReadStdCounterDesc,
      caE2eBoolWitnessDesc,
      caE2eVoidReturnDesc,
      caE2eAbort65542Desc,
      caFiatWithdrawalSigmaDstDesc,
      caFiatTransferSigmaDstDesc,
      caFiatNormalizationSigmaDstDesc,
      caFiatRotationSigmaDstDesc,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caFiatRegistrationSigmaDstDesc,
      faStubReadDesc,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caActualWrongLenIsNoneDesc,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caActualShortLenIsNoneDesc,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,
      caBoolConstViewDesc true,   -- 69 decompress compressed actual vs plain zero
      caBoolConstViewDesc true,   -- 70 is_zero decompressed compressed actual
      caBoolConstViewDesc true,   -- 71 balance_c two actual zeros
      caBoolConstViewDesc true,   -- 72 ElGamal add associative three zeros
      caBoolConstViewDesc true,   -- 73 pending bytes roundtrip `balance_equals` self
      caBoolConstViewDesc true,   -- 74 `balance_c_equals` two plain pending zeros
      caBoolConstViewDesc true,   -- 75 actual bytes roundtrip `balance_equals` self
      caBoolConstViewDesc true,   -- 76 pending u64 amount 1 is not zero balance
      caBoolConstViewDesc true,   -- 77 ElGamal pubkey short bytes → none
      caBoolConstViewDesc true,   -- 78 ElGamal ciphertext 63 bytes → none
      caBoolConstViewDesc true,   -- 79 `balance_equals` plain pending vs u64(0) pending
      caBoolConstViewDesc true,   -- 80 `balance_c_equals` same
      caBoolConstViewDesc true,   -- 81 add plain zero to u64-zero pending
      caBoolConstViewDesc true,   -- 82 add u64-zero to plain zero pending
      caBoolConstViewDesc true,   -- 83 sub u64-zero from plain zero pending
      caBoolConstViewDesc true,   -- 84 sub u64-zero from u64-zero pending
      caBoolConstViewDesc true,   -- 85 u64-zero pending bytes roundtrip `balance_equals` self
      caBoolConstViewDesc true,   -- 86 compress/decompress u64-zero pending
      caBoolConstViewDesc true,   -- 87 `balance_equals` two u64-zero pending
      caBoolConstViewDesc true,   -- 88 split_into_chunks_u64 second chunk
      caBoolConstViewDesc true,   -- 89 split_into_chunks_u128 second chunk
      caBoolConstViewDesc true,   -- 90 ElGamal ciphertext 65 bytes → none
      caBoolConstViewDesc true,   -- 91 ElGamal pubkey 31 bytes → none
      caBoolConstViewDesc true,   -- 92 ElGamal sub then add restores (zero ct)
      caBoolConstViewDesc true,   -- 93 split u64 chunk index 2
      caBoolConstViewDesc true,   -- 94 split u64 chunk index 3
      caBoolConstViewDesc true,   -- 95 split u128 chunk index 2
      caBoolConstViewDesc true,   -- 96 split u128 chunk index 3
      caBoolConstViewDesc true,   -- 97 split u128 chunk index 4
      caBoolConstViewDesc true,   -- 98 split u128 chunk index 5
      caBoolConstViewDesc true,   -- 99 `is_zero` after compress/decompress actual no-rand
      caBoolConstViewDesc true,   -- 100 split u128 chunk index 6
      caBoolConstViewDesc true,   -- 101 split u128 chunk index 7
      caBoolConstViewDesc false,  -- 102 e2e: `is_normalized` false after rollover (merged oracle)
      caConstU64ViewDesc 77,       -- 103 e2e: `confidential_asset_balance` after single deposit 77
      caConstU64ViewDesc 165,      -- 104 e2e: `confidential_asset_balance` after deposits 100+65
      caConstU64ViewDesc 667,      -- 105 e2e: pool balance after deposit 1000 and withdraw 333
      caConstU64ViewDesc 5678,      -- 106 e2e: pool after single `deposit_to` 5678
      caConstU64ViewDesc 12345,    -- 107 e2e: pool unchanged at 12345 after internal transfer
      caConstU64ViewDesc 7000,     -- 108 e2e: pool 5000+2000 after transfer then second deposit
      caConstU64ViewDesc 7777,      -- 109 e2e: two deposit_to 3333+4444
      caSigma18LayoutLenEq1152Desc, -- 110 withdrawal `layout_ok_is_some` — Lean len check (= **128**)
      caSigma18LayoutLenEq1152Desc, -- 111 normalization — same sigma wire as withdrawal (= **128**)
      caSigma19LayoutLenEq1216Desc, -- 112 rotation (= **129**)
      caSigmaTransfer26LayoutLenEq1792Desc, -- 113 transfer-base (= **130**)
      caSerializeAuditorEksSingleApointDesc, -- 114 `serialize_auditor_eks` singleton A_POINT wire
      caSerializeAuditorAmountsOneZeroPendingDesc, -- 115 `serialize_auditor_amounts` one zero pending
      caSerializeAuditorEksTwoApointDesc, -- 116 `serialize_auditor_eks` two A_POINT wire
      caSerializeAuditorAmountsTwoZeroPendingDesc, -- 117 `serialize_auditor_amounts` two zero pending
      caSerializeAuditorAmountsOneU64OnePendingDesc, -- 118 `u64(1)` no-rand pending wire
      caSerializeAuditorAmountsOneActualZeroDesc, -- 119 one actual zero balance wire
      caSerializeAuditorAmountsZeroThenU64OneDesc, -- 120 zero then `u64(1)` pending wire
      caSerializeAuditorAmountsU64OneThenZeroDesc, -- 121 `u64(1)` then zero pending wire
      caSerializeAuditorAmountsActualZeroThenU64OnePendingDesc, -- 122 actual zero then `u64(1)` pending (768 B)
      caSerializeAuditorAmountsU64OnePendingThenActualZeroDesc, -- 123 `u64(1)` pending then actual zero (768 B)
      caSerializeAuditorEksThreeApointDesc, -- 124 three A_POINT EK wire (96 B)
      caSerializeAuditorEksFourApointDesc, -- 125 four A_POINT EK wire (128 B)
      caSerializeAuditorEksFiveApointDesc, -- 126 five A_POINT EK wire (160 B)
      caSerializeAuditorEksSixApointDesc, -- 127 six A_POINT EK wire (192 B)
      caSigma18LayoutLenEq1152Desc, -- 128 sigma 18+18 wire len == 1152
      caSigma19LayoutLenEq1216Desc, -- 129 sigma 19+19 wire len == 1216
      caSigmaTransfer26LayoutLenEq1792Desc, -- 130 transfer sigma wire len == 1792
      caSigmaTransferExtended1920LenEqDesc, -- 131 transfer sigma + 1 auditor quad — len == 1920
      caSigmaTransferExtended1920LenEqDesc, -- 132 extended `deserialize_transfer` layout `Some` (= **131**)
      caSigmaTransferExtended2048LenEqDesc, -- 133 transfer sigma + 2 auditor quads — len == 2048
      caSigmaTransferExtended2048LenEqDesc, -- 134 two-quad extended `deserialize_transfer` `Some` (= **133**)
      caSigmaTransferExtended2176LenEqDesc, -- 135 transfer sigma + 3 auditor quads — len == 2176
      caSigmaTransferExtended2176LenEqDesc, -- 136 three-quad extended `deserialize_transfer` `Some` (= **135**)
      caSigmaTransferExtended2304LenEqDesc, -- 137 transfer sigma + 4 auditor quads — len == 2304
      caSigmaTransferExtended2304LenEqDesc, -- 138 four-quad extended `deserialize_transfer` `Some` (= **137**)
      caSigmaTransferExtended2432LenEqDesc, -- 139 transfer sigma + 5 auditor quads — len == 2432
      caSigmaTransferExtended2432LenEqDesc, -- 140 five-quad extended `deserialize_transfer` `Some` (= **139**)
      caSigmaTransferExtended2560LenEqDesc, -- 141 transfer sigma + 6 auditor quads — len == 2560
      caSigmaTransferExtended2560LenEqDesc, -- 142 six-quad extended `deserialize_transfer` `Some` (= **141**)
      caSigmaTransferExtended2688LenEqDesc, -- 143 transfer sigma + 7 auditor quads — len == 2688
      caSigmaTransferExtended2688LenEqDesc, -- 144 seven-quad extended `deserialize_transfer` `Some` (= **143**)
      caSigmaTransferExtended2816LenEqDesc, -- 145 transfer sigma + 8 auditor quads — len == 2816
      caSigmaTransferExtended2816LenEqDesc, -- 146 eight-quad extended `deserialize_transfer` `Some` (= **145**)
      caSigmaTransferExtended2944LenEqDesc, -- 147 transfer sigma + 9 auditor quads — len == 2944
      caSigmaTransferExtended2944LenEqDesc, -- 148 nine-quad extended `deserialize_transfer` `Some` (= **147**)
      caSigmaTransferExtended3072LenEqDesc, -- 149 transfer sigma + 10 auditor quads — len == 3072
      caSigmaTransferExtended3072LenEqDesc, -- 150 ten-quad extended `deserialize_transfer` `Some` (= **149**)
      caSigmaTransferExtended3200LenEqDesc, -- 151 transfer sigma + 11 auditor quads — len == 3200
      caSigmaTransferExtended3200LenEqDesc, -- 152 eleven-quad extended `deserialize_transfer` `Some` (= **151**)
      caSigmaTransferExtended3328LenEqDesc, -- 153 transfer sigma + 12 auditor quads — len == 3328
      caSigmaTransferExtended3328LenEqDesc, -- 154 twelve-quad extended `deserialize_transfer` `Some` (= **153**)
      caSigmaTransferExtended3456LenEqDesc, -- 155 transfer sigma + 13 auditor quads — len == 3456
      caSigmaTransferExtended3456LenEqDesc, -- 156 thirteen-quad extended `deserialize_transfer` `Some` (= **155**)
      caSigmaTransferExtended3584LenEqDesc, -- 157 transfer sigma + 14 auditor quads — len == 3584
      caSigmaTransferExtended3584LenEqDesc, -- 158 fourteen-quad extended `deserialize_transfer` `Some` (= **157**)
      caSigmaTransferExtended3712LenEqDesc, -- 159 transfer sigma + 15 auditor quads — len == 3712
      caSigmaTransferExtended3712LenEqDesc, -- 160 fifteen-quad extended `deserialize_transfer` `Some` (= **159**)
      caSigmaTransferExtended3840LenEqDesc, -- 161 transfer sigma + 16 auditor quads — len == 3840
      caSigmaTransferExtended3840LenEqDesc, -- 162 sixteen-quad extended `deserialize_transfer` `Some` (= **161**)
      caSigmaTransferExtended3968LenEqDesc, -- 163 transfer sigma + 17 auditor quads — len == 3968
      caSigmaTransferExtended3968LenEqDesc, -- 164 seventeen-quad extended `deserialize_transfer` `Some` (= **163**)
      caSigmaTransferExtended4096LenEqDesc, -- 165 transfer sigma + 18 auditor quads — len == 4096
      caSigmaTransferExtended4096LenEqDesc, -- 166 eighteen-quad extended `deserialize_transfer` `Some` (= **165**)
      caSigmaTransferExtended4224LenEqDesc, -- 167 transfer sigma + 19 auditor quads — len == 4224
      caSigmaTransferExtended4224LenEqDesc, -- 168 nineteen-quad extended `deserialize_transfer` `Some` (= **167**)
      faStubWriteReadDesc, -- 169 FA stub: write 9999 at (meta=1, owner=2) then read back
      caBoolConstViewDesc true, -- 170 registration FS framework `registration_fs_message_for_test` == helpers golden (difftest)
      caRegistrationHelpersRoundtripDesc, -- 171 production prove+verify on **35** fixture — same Lean native as **35**
      caRegistrationFsMsgGolden2Desc, -- 172 second FS golden `vector<u8>` (`TranscriptAlignment.expectedRegistrationFsMsg2`)
      caBoolConstViewDesc true, -- 173 second FS framework == helpers golden (`ldTrue`)
      caRegistrationTaggedHashGolden1Desc, -- 174 tagged SHA3-512 on FS golden 1 (`registration_tagged_hash_golden_1.hex`)
      caRegistrationTaggedHashGolden2Desc, -- 175 tagged SHA3-512 on FS golden 2 (`registration_tagged_hash_golden_2.hex`)
      caE2eAbort196617Desc, -- 176 `rotate_encryption_key` pending≠0 VM abort (`ENOT_ZERO_BALANCE` / code **196617**)
      caConstU64ViewDesc (UInt64.ofNat 8881), -- 177 e2e `confidential_asset_balance` pool pin after freeze+rotate+unfreeze path (**8881**)
      caConstU64ViewDesc (UInt64.ofNat 10003), -- 178 e2e pool **10003** (rolled **6001** + post-unfreeze **4002**)
      caConstU64ViewDesc (UInt64.ofNat 8901), -- 179 e2e pool **8901** (rolled **6001** + post-unfreeze **2000** + **900**)
      caConstU64ViewDesc (UInt64.ofNat 6601), -- 180 e2e pool **6601** (rolled **6001** + post-unfreeze **100** + **200** + **300**)
      caConstU64ViewDesc (UInt64.ofNat 7111), -- 181 e2e pool **7111** (rolled **6001** + post-unfreeze **111** + **222** + **333** + **444**)
      caE2eAbort65553Desc, -- 182 `confidential_transfer` **`EINVALID_SENDER_AMOUNT`** VM abort (**65553**)
      caE2eAbort196615Desc, -- 183 `confidential_transfer` / `deposit_to` / self-`deposit` when frozen, or second `freeze_token` (**196615**)
      caE2eAbort196619Desc, -- 184 second **`normalize`** when already normalized (**196619**)
      caE2eAbort196616Desc, -- 185 **`unfreeze_token`** when not frozen (**196616**)
      caE2eAbort524290Desc, -- 186 second **`register`** (**already_exists** / **524290**)
      caE2eAbort196618Desc, -- 187 second **`rollover_pending_balance`** while denormalized (**196618**)
      caE2eAbort196620Desc, -- 188 second **`enable_token`** (**196620**)
      caE2eAbort65549Desc, -- 189 **`deposit`** / allow-list **`ETOKEN_DISABLED`** (**65549**)
      caE2eAbort196622Desc, -- 190 second **`enable_allow_list`** (**196622**)
      caE2eAbort196623Desc, -- 191 second **`disable_allow_list`** (**196623**)
      caE2eAbort393219Desc, -- 192 shared **`not_found`** stub: **`freeze_token`** / **`unfreeze_token`** / **`rollover_pending_balance`** / **`rollover_pending_balance_and_freeze`** without CA store (**393219**)
      caE2eAbort196621Desc, -- 193 second **`disable_token`** (**196621**)
      { numParams := 0, numReturns := 1, body := .native caRegistrationBytecodeEvalNative } -- 194 registration bytecode eval (L2 honest column)
    ] }

private def evalConfidentialIdx (idx : Nat) (fuel : Nat) : ExecResult :=
  eval confidentialModuleEnv idx [] fuel

private def isRetBoolTrue (r : ExecResult) : Bool :=
  match r with
  | .returned [.bool true] _ => true
  | _ => false

/-- Machine-checked: **`layout_ok_is_some`**-mapped indices **110–113** evaluate to **`bool(true)`** (corpus sigma length bytecode). -/
theorem confidentialLayoutSomeRowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 110 50) &&
    isRetBoolTrue (evalConfidentialIdx 111 50) &&
    isRetBoolTrue (evalConfidentialIdx 112 50) &&
    isRetBoolTrue (evalConfidentialIdx 113 50) = true := by
  native_decide

/-- Same bytecode as **128–130** — ties **`layout_ok_is_some`** rows to the explicit length oracle indices. -/
theorem confidentialLayoutSomeRow110_eval_eq_128 :
    evalConfidentialIdx 110 50 == evalConfidentialIdx 128 50 := by
  native_decide

theorem confidentialLayoutSomeRow111_eval_eq_128 :
    evalConfidentialIdx 111 50 == evalConfidentialIdx 128 50 := by
  native_decide

theorem confidentialLayoutSomeRow112_eval_eq_129 :
    evalConfidentialIdx 112 50 == evalConfidentialIdx 129 50 := by
  native_decide

theorem confidentialLayoutSomeRow113_eval_eq_130 :
    evalConfidentialIdx 113 50 == evalConfidentialIdx 130 50 := by
  native_decide

theorem confidentialSigmaTransferExtended1920RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 131 50) &&
    isRetBoolTrue (evalConfidentialIdx 132 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_131_eq_132 :
    evalConfidentialIdx 131 50 == evalConfidentialIdx 132 50 := by
  native_decide

theorem confidentialSigmaTransferExtended2048RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 133 50) &&
    isRetBoolTrue (evalConfidentialIdx 134 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_133_eq_134 :
    evalConfidentialIdx 133 50 == evalConfidentialIdx 134 50 := by
  native_decide

theorem confidentialSigmaTransferExtended2176RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 135 50) &&
    isRetBoolTrue (evalConfidentialIdx 136 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_135_eq_136 :
    evalConfidentialIdx 135 50 == evalConfidentialIdx 136 50 := by
  native_decide

theorem confidentialSigmaTransferExtended2304RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 137 50) &&
    isRetBoolTrue (evalConfidentialIdx 138 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_137_eq_138 :
    evalConfidentialIdx 137 50 == evalConfidentialIdx 138 50 := by
  native_decide

theorem confidentialSigmaTransferExtended2432RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 139 50) &&
    isRetBoolTrue (evalConfidentialIdx 140 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_139_eq_140 :
    evalConfidentialIdx 139 50 == evalConfidentialIdx 140 50 := by
  native_decide

theorem confidentialSigmaTransferExtended2560RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 141 50) &&
    isRetBoolTrue (evalConfidentialIdx 142 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_141_eq_142 :
    evalConfidentialIdx 141 50 == evalConfidentialIdx 142 50 := by
  native_decide

theorem confidentialSigmaTransferExtended2688RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 143 50) &&
    isRetBoolTrue (evalConfidentialIdx 144 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_143_eq_144 :
    evalConfidentialIdx 143 50 == evalConfidentialIdx 144 50 := by
  native_decide

theorem confidentialSigmaTransferExtended2816RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 145 50) &&
    isRetBoolTrue (evalConfidentialIdx 146 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_145_eq_146 :
    evalConfidentialIdx 145 50 == evalConfidentialIdx 146 50 := by
  native_decide

theorem confidentialSigmaTransferExtended2944RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 147 50) &&
    isRetBoolTrue (evalConfidentialIdx 148 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_147_eq_148 :
    evalConfidentialIdx 147 50 == evalConfidentialIdx 148 50 := by
  native_decide

theorem confidentialSigmaTransferExtended3072RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 149 50) &&
    isRetBoolTrue (evalConfidentialIdx 150 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_149_eq_150 :
    evalConfidentialIdx 149 50 == evalConfidentialIdx 150 50 := by
  native_decide

theorem confidentialSigmaTransferExtended3200RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 151 50) &&
    isRetBoolTrue (evalConfidentialIdx 152 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_151_eq_152 :
    evalConfidentialIdx 151 50 == evalConfidentialIdx 152 50 := by
  native_decide

theorem confidentialSigmaTransferExtended3328RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 153 50) &&
    isRetBoolTrue (evalConfidentialIdx 154 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_153_eq_154 :
    evalConfidentialIdx 153 50 == evalConfidentialIdx 154 50 := by
  native_decide

theorem confidentialSigmaTransferExtended3456RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 155 50) &&
    isRetBoolTrue (evalConfidentialIdx 156 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_155_eq_156 :
    evalConfidentialIdx 155 50 == evalConfidentialIdx 156 50 := by
  native_decide

theorem confidentialSigmaTransferExtended3584RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 157 50) &&
    isRetBoolTrue (evalConfidentialIdx 158 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_157_eq_158 :
    evalConfidentialIdx 157 50 == evalConfidentialIdx 158 50 := by
  native_decide

theorem confidentialSigmaTransferExtended3712RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 159 50) &&
    isRetBoolTrue (evalConfidentialIdx 160 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_159_eq_160 :
    evalConfidentialIdx 159 50 == evalConfidentialIdx 160 50 := by
  native_decide

theorem confidentialSigmaTransferExtended3840RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 161 50) &&
    isRetBoolTrue (evalConfidentialIdx 162 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_161_eq_162 :
    evalConfidentialIdx 161 50 == evalConfidentialIdx 162 50 := by
  native_decide

theorem confidentialSigmaTransferExtended3968RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 163 50) &&
    isRetBoolTrue (evalConfidentialIdx 164 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_163_eq_164 :
    evalConfidentialIdx 163 50 == evalConfidentialIdx 164 50 := by
  native_decide

theorem confidentialSigmaTransferExtended4096RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 165 50) &&
    isRetBoolTrue (evalConfidentialIdx 166 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_165_eq_166 :
    evalConfidentialIdx 165 50 == evalConfidentialIdx 166 50 := by
  native_decide

theorem confidentialSigmaTransferExtended4224RowsLeanEval_bool_true :
    isRetBoolTrue (evalConfidentialIdx 167 50) &&
    isRetBoolTrue (evalConfidentialIdx 168 50) = true := by
  native_decide

theorem confidentialSigmaTransferExtendedEval_167_eq_168 :
    evalConfidentialIdx 167 50 == evalConfidentialIdx 168 50 := by
  native_decide

/-- Machine-checked: FA stub **write→read** returns **`u64(9999)`**; final `MachineState` records **`faBalances ((1,2) ↦ 9999)`**. -/
theorem confidentialFaStubWriteReadEval_u64_9999 :
    evalConfidentialIdx 169 50 ==
      .returned [.u64 9999]
        { MachineState.empty with
          faBalances := [((UInt64.ofNat 1, UInt64.ofNat 2), UInt64.ofNat 9999)] } := by
  native_decide

end AptosFormal.Move.Programs.Confidential
