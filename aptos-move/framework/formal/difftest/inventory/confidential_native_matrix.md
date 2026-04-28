# CA native & crypto dependency matrix (living)

**Purpose:** Track what the **Move VM** executes on confidential-asset paths vs what **`MovementFormal.MoveModel` / difftest** model today. Feeds **[`CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md`](../../CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md)** Workstream **A** (native specs) and **[`STUB_POLICY.md`](../STUB_POLICY.md)**.

**Legend**

| Status | Meaning |
|--------|---------|
| **Oracle** | VM↔Lean agree on harness / merged JSON rows (may be constant witness, not full native). |
| **Lean spec** | Pure Lean (`MovementFormal.AptosStd.*`, `MovementFormal.Std.*`) used in proofs or `native_decide` checks. |
| **Open** | No Lean executable spec on CA paths; difftest witness or VM-only. |

---

## 1. `aptos_std::aptos_hash`

| Surface | Move | Lean / difftest | Status |
|---------|------|-----------------|--------|
| SHA3-512 | `sha3_512_internal` → `sha3_512` | `MovementFormal.AptosStd.Hash.Sha3_512` | **Lean spec** + **Oracle** (BP DST digest, …) |
| SHA2-512 (Fiat-Shamir) | `ristretto255::new_scalar_from_sha2_512` | `MovementFormal.AptosStd.Hash.Sha2_512` | **Lean spec** + **Oracle** (registration FS challenge, …) |

---

## 2. `aptos_std::ristretto255` (internal natives; public wrappers)

Move: `aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.move` — **point / scalar** handles with `*_internal` natives (decompress, mul, add, `multi_scalar_mul`, `scalar_uniform_from_64_bytes`, …).

| Used heavily from | Notes | Lean / difftest |
|--------------------|-------|-----------------|
| `confidential_proof` | Registration Schnorr, sigma layouts, BP driver | **Oracle** + **L0** transcript (`TranscriptAlignment`); **corpora** `deserialize_sigma_*.hex` (+ **`verify-corpora`**) for VM layout-`Some` sigma wires; full curve **`Open`** in `eval` for entrypoints. |
| `confidential_balance` | Compress/decompress balances | **Oracle** (`confidential_balance` suite); partial **Lean spec** on narrow rows. |
| `ristretto255_twisted_elgamal` | ElGamal ops (no own natives) | **`confidential_elgamal`** suite. |

---

## 3. `aptos_std::ristretto255_bulletproofs`

Move: `ristretto255_bulletproofs.move` — `verify_range_proof_internal`, `verify_batch_range_proof_internal`, `prove_range_internal`, …

| Surface | Lean / difftest | Status |
|---------|-----------------|--------|
| Range proof verify / prove | DST string + SHA3-512 digest in oracle (BP-specific; FS challenges use SHA2-512); **not** full BP verify in Lean `eval` | **Oracle** + **Open** for bit-for-bit BP in Lean |

**Corpus (checked by `cargo run -p move-lean-difftest -- verify-corpora`):**

- [`../corpora/confidential_assets/bulletproofs_dst.hex`](../corpora/confidential_assets/bulletproofs_dst.hex) — UTF-8 DST (44 B).
- [`../corpora/confidential_assets/bulletproofs_dst_sha3_512.hex`](../corpora/confidential_assets/bulletproofs_dst_sha3_512.hex) — `sha3_512(DST)` (64 B).

**Lean length facts:** `MovementFormal.MoveModel.Programs.Confidential.bulletproofsDstBytes_length` / `bulletproofsDstSha3Bytes_length`.

---

## 4. `aptos_experimental::confidential_*` (application Move)

| Module | Declares `native fun`? | Notes |
|--------|-------------------------|--------|
| `confidential_asset` | **No** | FA + framework calls; e2e VM depth + merged JSON **witness** rows in Lean. |
| `confidential_proof` | **No** | Calls stdlib crypto natives. |
| `confidential_balance` | **No** | Calls stdlib crypto / structure. |
| `ristretto255_twisted_elgamal` | **No** | Wrapper over `ristretto255`. |

---

## 5. Registration DST (corpus + proof)

- **Bytes:** `difftest/corpora/confidential_assets/fiat_shamir_registration_dst.hex`
- **Lean:** `…VerifyMath.RegistrationVerify.fiatShamirRegistrationDst_byte_length` (**38** bytes).

---

## 6. `move-lean-difftest` ↔ Lean `Programs.Confidential` (indices)

| Index band (approx.) | Role |
|----------------------|------|
| 0–39 | `confidential_balance` / proof smoke / ElGamal / FS golden `msg` / `borrow_global` smoke |
| 40–42 | Merged CA e2e **witness** (`bool`, void, fixed abort) — not entrypoint bytecode |
| 43–51 | Fiat–Shamir sigma DST constants + registration sigma DST |
| 52–101 | FA stub read, ElGamal assign smoke, extra balance rows |
| 102 | CA e2e `bool(false)` witness |
| 103–109 | CA e2e `u64` pool-balance witnesses (see `Runner.lean` + module header comments) |
| 110–113 | `deserialize_*` **layout-only** `Some` — VM runs real parsers; Lean **`ldConst` 24–26** + `vecLen` + `eq` (same **`Step`** as **128–130**; necessary layout **length**, not parser replay) |
| **114** | `serialize_auditor_eks` one **A_POINT** — VM full wire; Lean **`ldConst` 10** + `ret` (**Oracle**; corpora [`serialize_auditor_eks_single_a_point.hex`](../corpora/confidential_assets/serialize_auditor_eks_single_a_point.hex)) |
| **115** | `serialize_auditor_amounts` one **`new_pending_balance_no_randomness`** — VM **256** B (all **zero** on current VM); Lean **`ldConst` 11** + `ret` (**Oracle**; corpora [`serialize_auditor_amounts_one_zero_pending.hex`](../corpora/confidential_assets/serialize_auditor_amounts_one_zero_pending.hex)) |
| **116** | `serialize_auditor_eks` two **A_POINT** — **64** B; Lean **`ldConst` 12** + `ret` (**Oracle**; [`serialize_auditor_eks_two_a_points.hex`](../corpora/confidential_assets/serialize_auditor_eks_two_a_points.hex)) |
| **117** | `serialize_auditor_amounts` two zero pending — **512** B; Lean **`ldConst` 13** + `ret` (**Oracle**; [`serialize_auditor_amounts_two_zero_pending.hex`](../corpora/confidential_assets/serialize_auditor_amounts_two_zero_pending.hex)) |
| **118** | `serialize_auditor_amounts` **`u64(1)`** no-rand pending — **256** B VM pin; Lean **`ldConst` 14** + `ret` (**Oracle**; [`serialize_auditor_amounts_one_u64_one_pending.hex`](../corpora/confidential_assets/serialize_auditor_amounts_one_u64_one_pending.hex); **literal** in Lean) |
| **119** | `serialize_auditor_amounts` one **actual** zero — **512** B; Lean **`ldConst` 15** + `ret` (**Oracle**; [`serialize_auditor_amounts_one_actual_zero.hex`](../corpora/confidential_assets/serialize_auditor_amounts_one_actual_zero.hex)) |
| **120** | `serialize_auditor_amounts` zero pending then **`u64(1)`** no-rand — **512** B; Lean **`ldConst` 16** + `ret` (**Oracle**; [`serialize_auditor_amounts_zero_then_u64_one_pending.hex`](../corpora/confidential_assets/serialize_auditor_amounts_zero_then_u64_one_pending.hex); concat of **115** + **118** wires) |
| **121** | `serialize_auditor_amounts` **`u64(1)`** no-rand then zero pending — **512** B; Lean **`ldConst` 17** + `ret` (**Oracle**; [`serialize_auditor_amounts_u64_one_then_zero_pending.hex`](../corpora/confidential_assets/serialize_auditor_amounts_u64_one_then_zero_pending.hex); **118** ‖ **115**) |
| **122** | `serialize_auditor_amounts` actual zero then **`u64(1)`** pending — **768** B; Lean **`ldConst` 18** + `ret` (**Oracle**; [`serialize_auditor_amounts_actual_zero_then_u64_one_pending.hex`](../corpora/confidential_assets/serialize_auditor_amounts_actual_zero_then_u64_one_pending.hex)) |
| **123** | `serialize_auditor_amounts` **`u64(1)`** pending then actual zero — **768** B; Lean **`ldConst` 19** + `ret` (**Oracle**; [`serialize_auditor_amounts_u64_one_pending_then_actual_zero.hex`](../corpora/confidential_assets/serialize_auditor_amounts_u64_one_pending_then_actual_zero.hex)) |
| **124** | `serialize_auditor_eks` three **A_POINT** — **96** B; Lean **`ldConst` 20** + `ret` (**Oracle**; [`serialize_auditor_eks_three_a_points.hex`](../corpora/confidential_assets/serialize_auditor_eks_three_a_points.hex)) |
| **125** | `serialize_auditor_eks` four **A_POINT** — **128** B; Lean **`ldConst` 21** + `ret` (**Oracle**; [`serialize_auditor_eks_four_a_points.hex`](../corpora/confidential_assets/serialize_auditor_eks_four_a_points.hex)) |
| **126** | `serialize_auditor_eks` five **A_POINT** — **160** B; Lean **`ldConst` 22** + `ret` (**Oracle**; [`serialize_auditor_eks_five_a_points.hex`](../corpora/confidential_assets/serialize_auditor_eks_five_a_points.hex)) |
| **127** | `serialize_auditor_eks` six **A_POINT** — **192** B; Lean **`ldConst` 23** + `ret` (**Oracle**; [`serialize_auditor_eks_six_a_points.hex`](../corpora/confidential_assets/serialize_auditor_eks_six_a_points.hex)) |
| **128** | Sigma **18+18** layout wire length **1152** — Lean **`ldConst` 24** + `vecLen` + `eq` (**real `Step`**; bytes = [`deserialize_sigma_18_scalars_18_points.hex`](../corpora/confidential_assets/deserialize_sigma_18_scalars_18_points.hex)) |
| **129** | Sigma **19+19** wire length **1216** — Lean **`ldConst` 25** + `vecLen` + `eq` (**Oracle**; [`deserialize_sigma_19_scalars_19_points.hex`](../corpora/confidential_assets/deserialize_sigma_19_scalars_19_points.hex)) |
| **130** | Transfer sigma **26+30** wire length **1792** — Lean **`ldConst` 26** + `vecLen` + `eq` (**Oracle**; [`deserialize_sigma_transfer_26_scalars_30_points.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points.hex)) |
| **131** | Transfer sigma **+ one auditor quad** wire length **1920** — Lean **`ldConst` 27** + `vecLen` + `eq` (**Oracle**; [`deserialize_sigma_transfer_26_scalars_30_points_plus_one_auditor_quad.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_one_auditor_quad.hex)) |
| **132** | VM **`deserialize_transfer`** extended layout-`Some` — Lean **same bytecode as 131** (necessary **length**; not full parser in `eval`) |
| **133** | Transfer sigma **+ two auditor quads** wire length **2048** — Lean **`ldConst` 28** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_two_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_two_auditor_quads.hex)) |
| **134** | VM **`deserialize_transfer`** two-quad extended `Some` — Lean **same bytecode as 133** |
| **135** | Transfer sigma **+ three auditor quads** wire length **2176** — Lean **`ldConst` 29** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_three_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_three_auditor_quads.hex)) |
| **136** | VM **`deserialize_transfer`** three-quad extended `Some` — Lean **same bytecode as 135** |
| **137** | Transfer sigma **+ four auditor quads** wire length **2304** — Lean **`ldConst` 30** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_four_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_four_auditor_quads.hex)) |
| **138** | VM **`deserialize_transfer`** four-quad extended `Some` — Lean **same bytecode as 137** |
| **139** | Transfer sigma **+ five auditor quads** wire length **2432** — Lean **`ldConst` 31** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_five_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_five_auditor_quads.hex)) |
| **140** | VM **`deserialize_transfer`** five-quad extended `Some` — Lean **same bytecode as 139** |
| **141** | Transfer sigma **+ six auditor quads** wire length **2560** — Lean **`ldConst` 32** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_six_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_six_auditor_quads.hex)) |
| **142** | VM **`deserialize_transfer`** six-quad extended `Some` — Lean **same bytecode as 141** |
| **143** | Transfer sigma **+ seven auditor quads** wire length **2688** — Lean **`ldConst` 33** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_seven_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_seven_auditor_quads.hex)) |
| **144** | VM **`deserialize_transfer`** seven-quad extended `Some` — Lean **same bytecode as 143** |
| **145** | Transfer sigma **+ eight auditor quads** wire length **2816** — Lean **`ldConst` 34** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_eight_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_eight_auditor_quads.hex)) |
| **146** | VM **`deserialize_transfer`** eight-quad extended `Some` — Lean **same bytecode as 145** |
| **147** | Transfer sigma **+ nine auditor quads** wire length **2944** — Lean **`ldConst` 35** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_nine_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_nine_auditor_quads.hex)) |
| **148** | VM **`deserialize_transfer`** nine-quad extended `Some` — Lean **same bytecode as 147** |
| **149** | Transfer sigma **+ ten auditor quads** wire length **3072** — Lean **`ldConst` 36** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_ten_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_ten_auditor_quads.hex)) |
| **150** | VM **`deserialize_transfer`** ten-quad extended `Some` — Lean **same bytecode as 149** |
| **151** | Transfer sigma **+ eleven auditor quads** wire length **3200** — Lean **`ldConst` 37** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_eleven_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_eleven_auditor_quads.hex)) |
| **152** | VM **`deserialize_transfer`** eleven-quad extended `Some` — Lean **same bytecode as 151** |
| **153** | Transfer sigma **+ twelve auditor quads** wire length **3328** — Lean **`ldConst` 38** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_twelve_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_twelve_auditor_quads.hex)) |
| **154** | VM **`deserialize_transfer`** twelve-quad extended `Some` — Lean **same bytecode as 153** |
| **155** | Transfer sigma **+ thirteen auditor quads** wire length **3456** — Lean **`ldConst` 39** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_thirteen_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_thirteen_auditor_quads.hex)) |
| **156** | VM **`deserialize_transfer`** thirteen-quad extended `Some` — Lean **same bytecode as 155** |
| **157** | Transfer sigma **+ fourteen auditor quads** wire length **3584** — Lean **`ldConst` 40** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_fourteen_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_fourteen_auditor_quads.hex)) |
| **158** | VM **`deserialize_transfer`** fourteen-quad extended `Some` — Lean **same bytecode as 157** |
| **159** | Transfer sigma **+ fifteen auditor quads** wire length **3712** — Lean **`ldConst` 41** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_fifteen_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_fifteen_auditor_quads.hex)) |
| **160** | VM **`deserialize_transfer`** fifteen-quad extended `Some` — Lean **same bytecode as 159** |
| **161** | Transfer sigma **+ sixteen auditor quads** wire length **3840** — Lean **`ldConst` 42** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_sixteen_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_sixteen_auditor_quads.hex)) |
| **162** | VM **`deserialize_transfer`** sixteen-quad extended `Some` — Lean **same bytecode as 161** |
| **163** | Transfer sigma **+ seventeen auditor quads** wire length **3968** — Lean **`ldConst` 43** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_seventeen_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_seventeen_auditor_quads.hex)) |
| **164** | VM **`deserialize_transfer`** seventeen-quad extended `Some` — Lean **same bytecode as 163** |
| **165** | Transfer sigma **+ eighteen auditor quads** wire length **4096** — Lean **`ldConst` 44** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_eighteen_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_eighteen_auditor_quads.hex)) |
| **166** | VM **`deserialize_transfer`** eighteen-quad extended `Some` — Lean **same bytecode as 165** |
| **167** | Transfer sigma **+ nineteen auditor quads** wire length **4224** — Lean **`ldConst` 45** + `vecLen` + `eq` ([`deserialize_sigma_transfer_26_scalars_30_points_plus_nineteen_auditor_quads.hex`](../corpora/confidential_assets/deserialize_sigma_transfer_26_scalars_30_points_plus_nineteen_auditor_quads.hex)) |
| **168** | VM **`deserialize_transfer`** nineteen-quad extended `Some` — Lean **same bytecode as 167** |
| **169** | FA stub **`faWriteBalance`** + **`faReadBalance`** — **`u64(9999)`** at `(meta=1, owner=2)` from empty map (`test_fa_stub_write_then_read_balance`) |
| **170** | **`confidential_proof::registration_fs_message_for_test`** on golden inputs **==** **`registration_fs_message_golden_move`** (`test_registration_fs_message_framework_matches_helpers_golden`); Lean **`ldTrue`** stub |
| **171** | **`prove_registration_deterministic_for_difftest`** + **`verify_registration_proof_for_difftest`** on the **35** fixture (`test_registration_proof_framework_deterministic_verify_roundtrip`); Lean **`caRegistrationHelpersRoundtripNative`** (same **`Operational.execVerifyRegistrationProof`** oracle as **35**) |
| **172** | Second formal FS golden **`vector<u8>`** (`test_registration_fs_message_golden_move_second`); Lean **`ldConst` 46** + `ret` vs **`TranscriptAlignment.expectedRegistrationFsMsg2`** |
| **173** | Second scenario **`registration_fs_message_for_test`** **==** **`registration_fs_message_golden_move_second_scenario`** (`test_registration_fs_message_framework_second_scenario_matches_helpers_golden`); Lean **`ldTrue`** stub |

Details: [`STUB_POLICY.md`](../STUB_POLICY.md), [`Programs/Confidential.lean`](../../lean/MovementFormal/MoveModel/Programs/Confidential.lean), [`DiffTest/Runner.lean`](../../lean/MovementFormal/DiffTest/Runner.lean), [`DiffTest/RunnerFuncMappingAux.lean`](../../lean/MovementFormal/DiffTest/RunnerFuncMappingAux.lean).

---

## 7. Next actions (suggested)

1. Expand this table **per public `fun`** on hot paths (owner + target L-level from FV plan).
2. For each **`ristretto255::*`** used from `confidential_proof::verify_*`, map to **Lean spec or axiom** row (Workstream A exit: “native → status” table).
3. Decide **BP strategy**: oracle-only vs bounded lemma vs external reference harness.
