//! VM oracles for `aptos_experimental::confidential_proof` (Phase 3) plus deterministic
//! registration Schnorr (`difftest_registration_helpers`), SHA3-512 of the Bulletproofs DST, and a
//! **`test_registration_fs_message_framework_matches_helpers_golden`** (FS `msg` bytes) and
//! **`test_registration_proof_framework_deterministic_verify_roundtrip`** (production
//! **`prove_registration_deterministic_for_difftest`** + **`verify_registration_proof_for_difftest`** on the
//! **`registration_roundtrip_vm`** fixture — Lean column matches **`test_registration_helpers_roundtrip`**).
//! Short-sigma `deserialize_*` `None` rows reuse Lean indices **16–19** (same `ldTrue` stub as other bool smoke).
//! Layout-only `Some` rows (`test_deserialize_*_layout_ok_is_some`) use VM-built sigma bytes + empty ZKRP vectors;
//! Lean column: **indices 110–113** — same real **`Step`** as **128–130** (`ldConst` corpus sigma + `vecLen` + `eq` on **1152** / **1216** / **1792**); necessary fixed-layout **length** (not `Option::is_some` / `deserialize_*` replay in `eval`). **Hex corpora** (same bytes):
//! `corpora/confidential_assets/deserialize_sigma_18_scalars_18_points.hex` (shared withdrawal+normalization),
//! `deserialize_sigma_19_scalars_19_points.hex`, `deserialize_sigma_transfer_26_scalars_30_points.hex`,
//! `deserialize_sigma_transfer_26_scalars_30_points_plus_one_auditor_quad.hex` (**1920** B = base + **4×A_POINT**),
//! `…_plus_two_auditor_quads.hex` (**2048** B = base + **8×A_POINT**),
//! `…_plus_three_auditor_quads.hex` (**2176** B = base + **12×A_POINT**),
//! `…_plus_four_auditor_quads.hex` (**2304** B = base + **16×A_POINT**),
//! `…_plus_five_auditor_quads.hex` (**2432** B = base + **20×A_POINT**),
//! `…_plus_six_auditor_quads.hex` (**2560** B = base + **24×A_POINT**),
//! `…_plus_seven_auditor_quads.hex` (**2688** B = base + **28×A_POINT**),
//! `…_plus_eight_auditor_quads.hex` (**2816** B = base + **32×A_POINT**),
//! `…_plus_nine_auditor_quads.hex` (**2944** B = base + **36×A_POINT**),
//! `…_plus_ten_auditor_quads.hex` (**3072** B = base + **40×A_POINT**),
//! `…_plus_eleven_auditor_quads.hex` (**3200** B = base + **44×A_POINT**),
//! `…_plus_twelve_auditor_quads.hex` (**3328** B = base + **48×A_POINT**),
//! `…_plus_thirteen_auditor_quads.hex` (**3456** B = base + **52×A_POINT**),
//! `…_plus_fourteen_auditor_quads.hex` (**3584** B = base + **56×A_POINT**),
//! `…_plus_fifteen_auditor_quads.hex` (**3712** B = base + **60×A_POINT**),
//! `…_plus_sixteen_auditor_quads.hex` (**3840** B = base + **64×A_POINT**),
//! `…_plus_seventeen_auditor_quads.hex` (**3968** B = base + **68×A_POINT**),
//! `…_plus_eighteen_auditor_quads.hex` (**4096** B = base + **72×A_POINT**),
//! `…_plus_nineteen_auditor_quads.hex` (**4224** B = base + **76×A_POINT**)
//! — checked by `move-lean-difftest verify-corpora` vs Lean `deserializeSigma*Bytes_length`.
//! **Sigma wire length** rows compare VM `vector::length` to **1152** / **1216** / **1792** / **1920** / **2048** / **2176** / **2304** / **2432** / **2560** / **2688** / **2816** / **2944** / **3072** / **3200** / **3328** / **3456** / **3584** / **3712** / **3840** / **3968** / **4096** / **4224** (extended transfer);
//! Lean **128–130** / **131** / **133** / **135** / **137** / **139** / **141** / **143** / **145** / **147** / **149** / **151** / **153** / **155** / **157** / **159** / **161** / **163** / **165** / **167**: real `Step` (`ldConst` corpora-matching bytes + `vecLen` + `eq`); **132** / **134** / **136** / **138** / **140** / **142** / **144** / **146** / **148** / **150** / **152** / **154** / **156** / **158** / **160** / **162** / **164** / **166** / **168** match VM extended-transfer `Some` with the same bytecode as **131** / **133** / **135** / **137** / **139** / **141** / **143** / **145** / **147** / **149** / **151** / **153** / **155** / **157** / **159** / **161** / **163** / **165** / **167**.
//! Registration FS challenges now use `ristretto255::new_scalar_from_sha2_512(DST || msg)` (no tagged hash).

use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;
use std::path::Path;

use crate::compiler::compile_with_aptos_head_bundle_extras;
use crate::schema::TestCase;
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_confidential_proof";

const EXTRA_MOVE: &[&str] = &[concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/move/difftest_registration_helpers.move"
)];

const TEST_SOURCE: &str = r#"
module 0x1::difftest_confidential_proof {
    use 0x1::difftest_registration_helpers;
    use aptos_experimental::confidential_proof;
    use aptos_experimental::confidential_balance;
    use aptos_experimental::ristretto255_twisted_elgamal as twisted_elgamal;
    use aptos_std::aptos_hash;
    use aptos_std::ristretto255;
    use std::error;
    use std::option;
    use std::vector;

    /// Calls the real `#[view]` getter on `confidential_proof` (not a duplicated literal).
    public fun test_bulletproofs_dst(): vector<u8> {
        confidential_proof::get_bulletproofs_dst()
    }

    public fun test_bulletproofs_num_bits(): u64 {
        confidential_proof::get_bulletproofs_num_bits()
    }

    public fun test_fiat_shamir_withdrawal_sigma_dst(): vector<u8> {
        confidential_proof::get_fiat_shamir_withdrawal_sigma_dst()
    }

    public fun test_fiat_shamir_transfer_sigma_dst(): vector<u8> {
        confidential_proof::get_fiat_shamir_transfer_sigma_dst()
    }

    public fun test_fiat_shamir_normalization_sigma_dst(): vector<u8> {
        confidential_proof::get_fiat_shamir_normalization_sigma_dst()
    }

    public fun test_fiat_shamir_rotation_sigma_dst(): vector<u8> {
        confidential_proof::get_fiat_shamir_rotation_sigma_dst()
    }

    public fun test_fiat_shamir_registration_sigma_dst(): vector<u8> {
        confidential_proof::get_fiat_shamir_registration_sigma_dst()
    }

    /// SHA3-512 of the Bulletproofs DST — same primitive used inside range-proof verification.
    public fun test_bulletproofs_dst_sha3_512(): vector<u8> {
        aptos_hash::sha3_512(b"AptosConfidentialAsset/BulletproofRangeProof")
    }

    public fun test_deserialize_withdrawal_empty_none(): bool {
        std::option::is_none(&confidential_proof::deserialize_withdrawal_proof(x"", x""))
    }

    public fun test_deserialize_transfer_empty_none(): bool {
        std::option::is_none(&confidential_proof::deserialize_transfer_proof(x"", x"", x""))
    }

    public fun test_deserialize_normalization_empty_none(): bool {
        std::option::is_none(&confidential_proof::deserialize_normalization_proof(x"", x""))
    }

    public fun test_deserialize_rotation_empty_none(): bool {
        std::option::is_none(&confidential_proof::deserialize_rotation_proof(x"", x""))
    }

    /// Sigma byte length below the fixed layout ⇒ `deserialize_*_sigma_proof` returns `None` first.
    public fun test_deserialize_withdrawal_short_sigma_is_none(): bool {
        let b = std::vector::range(0, 1).map(|_| 0u8);
        std::option::is_none(&confidential_proof::deserialize_withdrawal_proof(b, x""))
    }

    public fun test_deserialize_transfer_short_sigma_is_none(): bool {
        let b = std::vector::range(0, 1).map(|_| 0u8);
        std::option::is_none(
            &confidential_proof::deserialize_transfer_proof(b, x"", x""),
        )
    }

    public fun test_deserialize_normalization_short_sigma_is_none(): bool {
        let b = std::vector::range(0, 1).map(|_| 0u8);
        std::option::is_none(&confidential_proof::deserialize_normalization_proof(b, x""))
    }

    public fun test_deserialize_rotation_short_sigma_is_none(): bool {
        let b = std::vector::range(0, 1).map(|_| 0u8);
        std::option::is_none(&confidential_proof::deserialize_rotation_proof(b, x""))
    }

    /// Canonical **zero** scalar + fixed valid compressed point (`aptos_std::ristretto255::A_POINT`), repeated to
    /// match withdrawal/normalization sigma layout (`18` scalars + `18` points = **1152** bytes). Empty ZKRP bytes
    /// are accepted by `range_proof_from_bytes`. **Layout-only** `Some` — not a soundness claim for `verify_*`.
    fun layout_sigma_18_scalars_18_points(): vector<u8> {
        let sigma = vector[];
        std::vector::range(0, 18).for_each(|_| {
            sigma.append(x"0000000000000000000000000000000000000000000000000000000000000000");
        });
        std::vector::range(0, 18).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    /// Same encoding pattern as `layout_sigma_18_scalars_18_points` but **19** + **19** chunks (rotation sigma).
    fun layout_sigma_19_scalars_19_points(): vector<u8> {
        let sigma = vector[];
        std::vector::range(0, 19).for_each(|_| {
            sigma.append(x"0000000000000000000000000000000000000000000000000000000000000000");
        });
        std::vector::range(0, 19).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    /// Transfer sigma fixed layout before auditor extension: **26** scalars + **30** points = **1792** bytes.
    fun layout_sigma_transfer_base_layout(): vector<u8> {
        let sigma = vector[];
        std::vector::range(0, 26).for_each(|_| {
            sigma.append(x"0000000000000000000000000000000000000000000000000000000000000000");
        });
        std::vector::range(0, 30).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_deserialize_withdrawal_layout_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_withdrawal_proof(layout_sigma_18_scalars_18_points(), x""),
        )
    }

    public fun test_deserialize_normalization_layout_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_normalization_proof(layout_sigma_18_scalars_18_points(), x""),
        )
    }

    public fun test_deserialize_rotation_layout_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_rotation_proof(layout_sigma_19_scalars_19_points(), x""),
        )
    }

    public fun test_deserialize_transfer_layout_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_base_layout(),
                x"",
                x"",
            ),
        )
    }

    /// VM-built **18**+**18** sigma wire byte length — **1152** (matches `deserialize_sigma_18_scalars_18_points.hex`).
    public fun test_layout_sigma_18_scalars_18_points_byte_length_is_1152(): bool {
        layout_sigma_18_scalars_18_points().length() == 1152
    }

    /// VM-built **19**+**19** sigma wire — **1216** bytes (`deserialize_sigma_19_scalars_19_points.hex`).
    public fun test_layout_sigma_19_scalars_19_points_byte_length_is_1216(): bool {
        layout_sigma_19_scalars_19_points().length() == 1216
    }

    /// VM-built transfer-base sigma (**26**+**30**) — **1792** bytes (`deserialize_sigma_transfer_26_scalars_30_points.hex`).
    public fun test_layout_sigma_transfer_base_layout_byte_length_is_1792(): bool {
        layout_sigma_transfer_base_layout().length() == 1792
    }

    /// Base transfer sigma plus **four** trailing **A_POINT** encodings (**128** B) — one **`auditor_xs`** block in
    /// `deserialize_transfer_sigma_proof` (`auditor_xs % 128 == 0`). **1920** bytes (`…_plus_one_auditor_quad.hex`).
    fun layout_sigma_transfer_one_auditor_quad_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 4).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_one_auditor_quad_extension_byte_length_is_1920(): bool {
        layout_sigma_transfer_one_auditor_quad_extension().length() == 1920
    }

    public fun test_deserialize_transfer_layout_extended_one_auditor_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_one_auditor_quad_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **eight** trailing **A_POINT** encodings (**256** B) — two **`auditor_xs`** blocks.
    /// **2048** bytes (`…_plus_two_auditor_quads.hex`).
    fun layout_sigma_transfer_two_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 8).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_two_auditor_quads_extension_byte_length_is_2048(): bool {
        layout_sigma_transfer_two_auditor_quads_extension().length() == 2048
    }

    public fun test_deserialize_transfer_layout_extended_two_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_two_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **twelve** trailing **A_POINT** encodings (**384** B) — three **`auditor_xs`** blocks.
    /// **2176** bytes (`…_plus_three_auditor_quads.hex`).
    fun layout_sigma_transfer_three_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 12).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_three_auditor_quads_extension_byte_length_is_2176(): bool {
        layout_sigma_transfer_three_auditor_quads_extension().length() == 2176
    }

    public fun test_deserialize_transfer_layout_extended_three_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_three_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **sixteen** trailing **A_POINT** encodings (**512** B) — four **`auditor_xs`** blocks.
    /// **2304** bytes (`…_plus_four_auditor_quads.hex`).
    fun layout_sigma_transfer_four_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 16).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_four_auditor_quads_extension_byte_length_is_2304(): bool {
        layout_sigma_transfer_four_auditor_quads_extension().length() == 2304
    }

    public fun test_deserialize_transfer_layout_extended_four_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_four_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **twenty** trailing **A_POINT** encodings (**640** B) — five **`auditor_xs`** blocks.
    /// **2432** bytes (`…_plus_five_auditor_quads.hex`).
    fun layout_sigma_transfer_five_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 20).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_five_auditor_quads_extension_byte_length_is_2432(): bool {
        layout_sigma_transfer_five_auditor_quads_extension().length() == 2432
    }

    public fun test_deserialize_transfer_layout_extended_five_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_five_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **twenty-four** trailing **A_POINT** encodings (**768** B) — six **`auditor_xs`** blocks.
    /// **2560** bytes (`…_plus_six_auditor_quads.hex`).
    fun layout_sigma_transfer_six_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 24).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_six_auditor_quads_extension_byte_length_is_2560(): bool {
        layout_sigma_transfer_six_auditor_quads_extension().length() == 2560
    }

    public fun test_deserialize_transfer_layout_extended_six_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_six_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **twenty-eight** trailing **A_POINT** encodings (**896** B) — seven **`auditor_xs`** blocks.
    /// **2688** bytes (`…_plus_seven_auditor_quads.hex`).
    fun layout_sigma_transfer_seven_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 28).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_seven_auditor_quads_extension_byte_length_is_2688(): bool {
        layout_sigma_transfer_seven_auditor_quads_extension().length() == 2688
    }

    public fun test_deserialize_transfer_layout_extended_seven_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_seven_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **thirty-two** trailing **A_POINT** encodings (**1024** B) — eight **`auditor_xs`** blocks.
    /// **2816** bytes (`…_plus_eight_auditor_quads.hex`).
    fun layout_sigma_transfer_eight_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 32).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_eight_auditor_quads_extension_byte_length_is_2816(): bool {
        layout_sigma_transfer_eight_auditor_quads_extension().length() == 2816
    }

    public fun test_deserialize_transfer_layout_extended_eight_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_eight_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **thirty-six** trailing **A_POINT** encodings (**1152** B) — nine **`auditor_xs`** blocks.
    /// **2944** bytes (`…_plus_nine_auditor_quads.hex`).
    fun layout_sigma_transfer_nine_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 36).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_nine_auditor_quads_extension_byte_length_is_2944(): bool {
        layout_sigma_transfer_nine_auditor_quads_extension().length() == 2944
    }

    public fun test_deserialize_transfer_layout_extended_nine_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_nine_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **forty** trailing **A_POINT** encodings (**1280** B) — ten **`auditor_xs`** blocks.
    /// **3072** bytes (`…_plus_ten_auditor_quads.hex`).
    fun layout_sigma_transfer_ten_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 40).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_ten_auditor_quads_extension_byte_length_is_3072(): bool {
        layout_sigma_transfer_ten_auditor_quads_extension().length() == 3072
    }

    public fun test_deserialize_transfer_layout_extended_ten_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_ten_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **forty-four** trailing **A_POINT** encodings (**1408** B) — eleven **`auditor_xs`** blocks.
    /// **3200** bytes (`…_plus_eleven_auditor_quads.hex`).
    fun layout_sigma_transfer_eleven_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 44).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_eleven_auditor_quads_extension_byte_length_is_3200(): bool {
        layout_sigma_transfer_eleven_auditor_quads_extension().length() == 3200
    }

    public fun test_deserialize_transfer_layout_extended_eleven_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_eleven_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **forty-eight** trailing **A_POINT** encodings (**1536** B) — twelve **`auditor_xs`** blocks.
    /// **3328** bytes (`…_plus_twelve_auditor_quads.hex`).
    fun layout_sigma_transfer_twelve_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 48).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_twelve_auditor_quads_extension_byte_length_is_3328(): bool {
        layout_sigma_transfer_twelve_auditor_quads_extension().length() == 3328
    }

    public fun test_deserialize_transfer_layout_extended_twelve_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_twelve_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **fifty-two** trailing **A_POINT** encodings (**1664** B) — thirteen **`auditor_xs`** blocks.
    /// **3456** bytes (`…_plus_thirteen_auditor_quads.hex`).
    fun layout_sigma_transfer_thirteen_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 52).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_thirteen_auditor_quads_extension_byte_length_is_3456(): bool {
        layout_sigma_transfer_thirteen_auditor_quads_extension().length() == 3456
    }

    public fun test_deserialize_transfer_layout_extended_thirteen_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_thirteen_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **fifty-six** trailing **A_POINT** encodings (**1792** B) — fourteen **`auditor_xs`** blocks.
    /// **3584** bytes (`…_plus_fourteen_auditor_quads.hex`).
    fun layout_sigma_transfer_fourteen_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 56).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_fourteen_auditor_quads_extension_byte_length_is_3584(): bool {
        layout_sigma_transfer_fourteen_auditor_quads_extension().length() == 3584
    }

    public fun test_deserialize_transfer_layout_extended_fourteen_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_fourteen_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **sixty** trailing **A_POINT** encodings (**1920** B) — fifteen **`auditor_xs`** blocks.
    /// **3712** bytes (`…_plus_fifteen_auditor_quads.hex`).
    fun layout_sigma_transfer_fifteen_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 60).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_fifteen_auditor_quads_extension_byte_length_is_3712(): bool {
        layout_sigma_transfer_fifteen_auditor_quads_extension().length() == 3712
    }

    public fun test_deserialize_transfer_layout_extended_fifteen_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_fifteen_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **sixty-four** trailing **A_POINT** encodings (**2048** B) — sixteen **`auditor_xs`** blocks.
    /// **3840** bytes (`…_plus_sixteen_auditor_quads.hex`).
    fun layout_sigma_transfer_sixteen_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 64).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_sixteen_auditor_quads_extension_byte_length_is_3840(): bool {
        layout_sigma_transfer_sixteen_auditor_quads_extension().length() == 3840
    }

    public fun test_deserialize_transfer_layout_extended_sixteen_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_sixteen_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **sixty-eight** trailing **A_POINT** encodings (**2176** B) — seventeen **`auditor_xs`** blocks.
    /// **3968** bytes (`…_plus_seventeen_auditor_quads.hex`).
    fun layout_sigma_transfer_seventeen_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 68).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_seventeen_auditor_quads_extension_byte_length_is_3968(): bool {
        layout_sigma_transfer_seventeen_auditor_quads_extension().length() == 3968
    }

    public fun test_deserialize_transfer_layout_extended_seventeen_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_seventeen_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **seventy-two** trailing **A_POINT** encodings (**2304** B) — eighteen **`auditor_xs`** blocks.
    /// **4096** bytes (`…_plus_eighteen_auditor_quads.hex`).
    fun layout_sigma_transfer_eighteen_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 72).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_eighteen_auditor_quads_extension_byte_length_is_4096(): bool {
        layout_sigma_transfer_eighteen_auditor_quads_extension().length() == 4096
    }

    public fun test_deserialize_transfer_layout_extended_eighteen_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_eighteen_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    /// Base transfer sigma plus **seventy-six** trailing **A_POINT** encodings (**2432** B) — nineteen **`auditor_xs`** blocks.
    /// **4224** bytes (`…_plus_nineteen_auditor_quads.hex`).
    fun layout_sigma_transfer_nineteen_auditor_quads_extension(): vector<u8> {
        let sigma = layout_sigma_transfer_base_layout();
        std::vector::range(0, 76).for_each(|_| {
            sigma.append(x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
        });
        sigma
    }

    public fun test_layout_sigma_transfer_nineteen_auditor_quads_extension_byte_length_is_4224(): bool {
        layout_sigma_transfer_nineteen_auditor_quads_extension().length() == 4224
    }

    public fun test_deserialize_transfer_layout_extended_nineteen_auditors_ok_is_some(): bool {
        std::option::is_some(
            &confidential_proof::deserialize_transfer_proof(
                layout_sigma_transfer_nineteen_auditor_quads_extension(),
                x"",
                x"",
            ),
        )
    }

    public fun test_registration_helpers_roundtrip(): bool {
        difftest_registration_helpers::registration_roundtrip_vm()
    }

    /// `confidential_proof::registration_fs_message_for_test` on the formal golden inputs must match
    /// `difftest_registration_helpers::registration_fs_message_golden_move` byte-for-byte.
    public fun test_registration_fs_message_framework_matches_helpers_golden(): bool {
        let expected = difftest_registration_helpers::registration_fs_message_golden_move();
        let bp = ristretto255::basepoint_compressed();
        let ek_bytes = ristretto255::compressed_point_to_bytes(bp);
        let ek_opt = twisted_elgamal::new_pubkey_from_bytes(ek_bytes);
        assert!(std::option::is_some(&ek_opt), error::invalid_argument(1));
        let ek = std::option::destroy_some(ek_opt);
        let actual = confidential_proof::registration_fs_message_for_test(
            9,
            @0x1,
            @0x2,
            @0x3,
            &ek,
            ek_bytes,
        );
        actual == expected
    }

    /// Production `prove_registration_deterministic_for_difftest` then `verify_registration_proof_for_difftest`
    /// on the same fixture as `difftest_registration_helpers::registration_roundtrip_vm` (dk=42, k=9999).
    public fun test_registration_proof_framework_deterministic_verify_roundtrip(): bool {
        let chain_id = 9u8;
        let sender = @0x1;
        let contract_address = @0x2;
        let token_address = @0x3;
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (commitment, response) = confidential_proof::prove_registration_deterministic_for_difftest(
            chain_id,
            sender,
            contract_address,
            &dk,
            &ek,
            token_address,
            &k,
        );
        confidential_proof::verify_registration_proof_for_difftest(
            chain_id,
            sender,
            contract_address,
            &ek,
            token_address,
            commitment,
            response,
        );
        true
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Phase H — registration-proof NEGATIVE pins.
    //
    // For each public input of `verify_registration_proof_for_difftest` that is
    // fed into the Fiat–Shamir transcript (chain_id, sender, contract_address,
    // ek, token_address, commitment_bytes) and each output of the prover that
    // must be byte-bound to the verifier's recomputed challenge
    // (response_bytes, commitment_bytes), we produce a valid proof and then
    // mutate exactly one argument on the verifier side. The verifier MUST
    // abort with `error::invalid_argument(ESIGMA_PROTOCOL_VERIFY_FAILED)` =
    // 65537. If it does not — e.g. a regression drops one of those fields
    // from the FS transcript or from the equality check — the Move VM returns
    // `bool(true)` and mismatches Lean `caSigmaVerifyFailedAbortDesc` (funcIdx
    // := 195). That mismatch is the bug alarm.
    //
    // These pins catch a whole family of bugs that positive roundtrip tests
    // cannot catch: the positive test runs prove and verify with identical
    // inputs, so a silent drop of e.g. `chain_id` from the transcript would
    // still produce a valid roundtrip (both sides drop it identically) but
    // would let an adversary replay a proof across chains in production.

    /// Registration verify MUST reject when `sender` on verify differs from prove.
    public fun test_verify_registration_rejects_sender_mutation(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract_address = @0xB;
        let token_address = @0xC;
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (commitment, response) = confidential_proof::prove_registration_deterministic_for_difftest(
            chain_id, sender, contract_address, &dk, &ek, token_address, &k);
        confidential_proof::verify_registration_proof_for_difftest(
            chain_id, @0xDEAD, contract_address, &ek, token_address, commitment, response);
        true
    }

    /// Registration verify MUST reject when `contract_address` on verify differs from prove.
    public fun test_verify_registration_rejects_contract_mutation(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract_address = @0xB;
        let token_address = @0xC;
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (commitment, response) = confidential_proof::prove_registration_deterministic_for_difftest(
            chain_id, sender, contract_address, &dk, &ek, token_address, &k);
        confidential_proof::verify_registration_proof_for_difftest(
            chain_id, sender, @0xDEAD, &ek, token_address, commitment, response);
        true
    }

    /// Registration verify MUST reject when `token_address` on verify differs from prove.
    public fun test_verify_registration_rejects_token_mutation(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract_address = @0xB;
        let token_address = @0xC;
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (commitment, response) = confidential_proof::prove_registration_deterministic_for_difftest(
            chain_id, sender, contract_address, &dk, &ek, token_address, &k);
        confidential_proof::verify_registration_proof_for_difftest(
            chain_id, sender, contract_address, &ek, @0xDEAD, commitment, response);
        true
    }

    /// Registration verify MUST reject when `chain_id` on verify differs from prove.
    /// Critical: without this pin, a bug dropping `chain_id` from the transcript
    /// would still pass positive roundtrip tests but would enable cross-chain replay.
    public fun test_verify_registration_rejects_chain_id_mutation(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract_address = @0xB;
        let token_address = @0xC;
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (commitment, response) = confidential_proof::prove_registration_deterministic_for_difftest(
            chain_id, sender, contract_address, &dk, &ek, token_address, &k);
        confidential_proof::verify_registration_proof_for_difftest(
            10u8, sender, contract_address, &ek, token_address, commitment, response);
        true
    }

    /// Registration verify MUST reject when `ek` on verify differs from prove.
    /// A regression that drops `ek` from the transcript would let an attacker
    /// bind a single proof to multiple encryption keys — severe production bug.
    public fun test_verify_registration_rejects_ek_mutation(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract_address = @0xB;
        let token_address = @0xC;
        let dk = ristretto255::new_scalar_from_u64(42);
        let dk_other = ristretto255::new_scalar_from_u64(43);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let ek_other = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk_other);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (commitment, response) = confidential_proof::prove_registration_deterministic_for_difftest(
            chain_id, sender, contract_address, &dk, &ek, token_address, &k);
        confidential_proof::verify_registration_proof_for_difftest(
            chain_id, sender, contract_address, &ek_other, token_address, commitment, response);
        true
    }

    /// Registration verify MUST reject when `commitment_bytes` are bit-flipped (last byte XOR 0x01).
    /// Binds the commitment to the FS challenge: without this check, a malleable
    /// commitment could be accepted.
    public fun test_verify_registration_rejects_commitment_mutation(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract_address = @0xB;
        let token_address = @0xC;
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (commitment, response) = confidential_proof::prove_registration_deterministic_for_difftest(
            chain_id, sender, contract_address, &dk, &ek, token_address, &k);
        // XOR the last byte to produce either an invalid encoding (aborts on decompress)
        // or a different-but-valid point (aborts on equality check). Both paths abort 65537.
        let last_idx = commitment.length() - 1;
        let last = *commitment.borrow(last_idx);
        *commitment.borrow_mut(last_idx) = last ^ 0x01;
        confidential_proof::verify_registration_proof_for_difftest(
            chain_id, sender, contract_address, &ek, token_address, commitment, response);
        true
    }

    /// Registration verify MUST reject when `response_bytes` are bit-flipped.
    /// Binds the response scalar to the FS challenge via `s * H + e * ek == R`.
    public fun test_verify_registration_rejects_response_mutation(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract_address = @0xB;
        let token_address = @0xC;
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (commitment, response) = confidential_proof::prove_registration_deterministic_for_difftest(
            chain_id, sender, contract_address, &dk, &ek, token_address, &k);
        // Flip the lowest bit of the response scalar's canonical encoding. If the result
        // is a valid scalar (almost always), the MSM equation fails. If invalid, the
        // `new_scalar_from_bytes` check aborts with the same code.
        *response.borrow_mut(0) = *response.borrow(0) ^ 0x01;
        confidential_proof::verify_registration_proof_for_difftest(
            chain_id, sender, contract_address, &ek, token_address, commitment, response);
        true
    }

    /// 161-byte FS `msg` for the formal golden transcript (Lean: `TranscriptAlignment`).
    public fun test_registration_fs_message_golden_move(): vector<u8> {
        difftest_registration_helpers::registration_fs_message_golden_move()
    }

    /// **161**-byte FS `msg` for the second formal golden (`chain_id=42`, `@0x10`/`@0x20`/`@0x30`).
    public fun test_registration_fs_message_golden_move_second(): vector<u8> {
        difftest_registration_helpers::registration_fs_message_golden_move_second_scenario()
    }

    // ─────────── Domain-separation inequality pins ───────────
    // Each `get_fiat_shamir_*_sigma_dst` returns a distinct literal:
    //   withdrawal    = b"MovementConfidentialAsset/Withdrawal"    (36 B)
    //   transfer      = b"MovementConfidentialAsset/Transfer"      (34 B)
    //   rotation      = b"MovementConfidentialAsset/Rotation"      (34 B)  ← same length
    //   normalization = b"MovementConfidentialAsset/Normalization" (39 B)
    //   registration  = b"MovementConfidentialAsset/Registration"  (38 B)
    // A same-length copy-paste swap (e.g. a future edit makes
    // `get_fiat_shamir_transfer_sigma_dst` return the `Rotation` literal) would
    // NOT be caught by any length-only pin (both are 34 B) but WILL be caught
    // by the pairwise-inequality rows below. Each one returns `bool(true)`
    // when the DSTs differ; a regression makes the row flip to `bool(false)`
    // and mismatch Lean `ldTrue`.

    public fun test_fs_dst_transfer_not_equal_rotation(): bool {
        confidential_proof::get_fiat_shamir_transfer_sigma_dst()
            != confidential_proof::get_fiat_shamir_rotation_sigma_dst()
    }

    public fun test_fs_dst_withdrawal_not_equal_normalization(): bool {
        confidential_proof::get_fiat_shamir_withdrawal_sigma_dst()
            != confidential_proof::get_fiat_shamir_normalization_sigma_dst()
    }

    public fun test_fs_dst_registration_not_equal_normalization(): bool {
        confidential_proof::get_fiat_shamir_registration_sigma_dst()
            != confidential_proof::get_fiat_shamir_normalization_sigma_dst()
    }

    public fun test_fs_dst_withdrawal_not_equal_transfer(): bool {
        confidential_proof::get_fiat_shamir_withdrawal_sigma_dst()
            != confidential_proof::get_fiat_shamir_transfer_sigma_dst()
    }

    public fun test_fs_dst_withdrawal_not_equal_rotation(): bool {
        confidential_proof::get_fiat_shamir_withdrawal_sigma_dst()
            != confidential_proof::get_fiat_shamir_rotation_sigma_dst()
    }

    public fun test_fs_dst_withdrawal_not_equal_registration(): bool {
        confidential_proof::get_fiat_shamir_withdrawal_sigma_dst()
            != confidential_proof::get_fiat_shamir_registration_sigma_dst()
    }

    public fun test_fs_dst_transfer_not_equal_normalization(): bool {
        confidential_proof::get_fiat_shamir_transfer_sigma_dst()
            != confidential_proof::get_fiat_shamir_normalization_sigma_dst()
    }

    public fun test_fs_dst_transfer_not_equal_registration(): bool {
        confidential_proof::get_fiat_shamir_transfer_sigma_dst()
            != confidential_proof::get_fiat_shamir_registration_sigma_dst()
    }

    public fun test_fs_dst_rotation_not_equal_normalization(): bool {
        confidential_proof::get_fiat_shamir_rotation_sigma_dst()
            != confidential_proof::get_fiat_shamir_normalization_sigma_dst()
    }

    public fun test_fs_dst_rotation_not_equal_registration(): bool {
        confidential_proof::get_fiat_shamir_rotation_sigma_dst()
            != confidential_proof::get_fiat_shamir_registration_sigma_dst()
    }

    /// Also pin: `get_bulletproofs_dst` must differ from every sigma DST.
    /// Catches a sigma helper that accidentally returns the bulletproofs DST.
    public fun test_fs_dst_bulletproofs_not_equal_any_sigma_dst(): bool {
        let bp = confidential_proof::get_bulletproofs_dst();
        bp != confidential_proof::get_fiat_shamir_withdrawal_sigma_dst()
            && bp != confidential_proof::get_fiat_shamir_transfer_sigma_dst()
            && bp != confidential_proof::get_fiat_shamir_rotation_sigma_dst()
            && bp != confidential_proof::get_fiat_shamir_normalization_sigma_dst()
            && bp != confidential_proof::get_fiat_shamir_registration_sigma_dst()
    }

    /// Exact-byte pins (stronger than length-only): each getter must return
    /// the exact literal the production framework documents. A getter that
    /// returns the **right** length but the **wrong** literal would pass all
    /// length-only rows but fail this one. These pin the production
    /// invariant "DST bytes are stable across releases".
    public fun test_fs_dst_transfer_bytes_exact(): bool {
        confidential_proof::get_fiat_shamir_transfer_sigma_dst() == b"MovementConfidentialAsset/Transfer"
    }

    public fun test_fs_dst_rotation_bytes_exact(): bool {
        confidential_proof::get_fiat_shamir_rotation_sigma_dst() == b"MovementConfidentialAsset/Rotation"
    }

    public fun test_fs_dst_withdrawal_bytes_exact(): bool {
        confidential_proof::get_fiat_shamir_withdrawal_sigma_dst() == b"MovementConfidentialAsset/Withdrawal"
    }

    public fun test_fs_dst_normalization_bytes_exact(): bool {
        confidential_proof::get_fiat_shamir_normalization_sigma_dst() == b"MovementConfidentialAsset/Normalization"
    }

    public fun test_fs_dst_registration_bytes_exact(): bool {
        confidential_proof::get_fiat_shamir_registration_sigma_dst() == b"MovementConfidentialAsset/Registration"
    }

    public fun test_fs_dst_bulletproofs_bytes_exact(): bool {
        confidential_proof::get_bulletproofs_dst() == b"AptosConfidentialAsset/BulletproofRangeProof"
    }

    /// `get_bulletproofs_num_bits` must equal `16`. Pinned as bool to keep
    /// Lean column uniform (`ldTrue`).
    public fun test_bulletproofs_num_bits_is_16(): bool {
        confidential_proof::get_bulletproofs_num_bits() == 16
    }

    /// `registration_fs_message_for_test` on the second golden inputs **==** helpers golden bytes.
    public fun test_registration_fs_message_framework_second_scenario_matches_helpers_golden(): bool {
        let expected = difftest_registration_helpers::registration_fs_message_golden_move_second_scenario();
        let bp = ristretto255::basepoint_compressed();
        let ek_bytes = ristretto255::compressed_point_to_bytes(bp);
        let ek_opt = twisted_elgamal::new_pubkey_from_bytes(ek_bytes);
        assert!(std::option::is_some(&ek_opt), error::invalid_argument(1));
        let ek = std::option::destroy_some(ek_opt);
        let actual = confidential_proof::registration_fs_message_for_test(
            42,
            @0x10,
            @0x20,
            @0x30,
            &ek,
            ek_bytes,
        );
        actual == expected
    }

    // ───────────────────────────────────────────────────────────────────────
    // Phase C: deserializer reject-pin rows (VM-only prover is #[test_only]
    // in `ristretto255_bulletproofs`, so full prove→verify happy path is
    // not callable from a non-test harness module; see inventory matrix).
    //
    // These rows pin the `Option::is_none` reject paths of
    // `deserialize_{withdrawal,transfer,normalization,rotation}_proof` by
    // feeding either **length-rejected** sigma bytes (so
    // `deserialize_*_sigma_proof` returns `none` before touching the
    // bulletproofs decoder) or a mismatched sigma / bulletproofs pair.
    //
    // A regression that makes any deserializer accept arbitrary-length
    // sigma bytes (e.g. "truncate, treat remainder as zero") would flip
    // the `is_none` pin to `is_some`, mismatching Lean `ldTrue`.

    /// Withdrawal sigma proof is 64 * 18 = 1152 bytes (16 scalars + 2
    /// points + 8 points + 8 points = 18*32 ... actually 18 is the count
    /// of 32-byte fields: 8 a1s + a2 + a3 + 8 a4s = 18 scalars; then 1 x1
    /// + 1 x2 + 8 x3s + 8 x4s = 18 points; total 36*32 = 1152 bytes).
    /// Regardless of the exact expected length, a short sigma blob must
    /// be rejected.
    public fun test_deserialize_withdrawal_proof_short_sigma_is_none(): bool {
        let short_sigma = vector[0u8, 1u8, 2u8];
        let zkrp = vector[]; // empty bulletproofs bytes
        let opt = confidential_proof::deserialize_withdrawal_proof(short_sigma, zkrp);
        option::is_none(&opt)
    }

    public fun test_deserialize_normalization_proof_short_sigma_is_none(): bool {
        let short_sigma = vector[0u8, 1u8, 2u8];
        let zkrp = vector[];
        let opt = confidential_proof::deserialize_normalization_proof(short_sigma, zkrp);
        option::is_none(&opt)
    }

    public fun test_deserialize_rotation_proof_short_sigma_is_none(): bool {
        let short_sigma = vector[];
        let zkrp = vector[];
        let opt = confidential_proof::deserialize_rotation_proof(short_sigma, zkrp);
        option::is_none(&opt)
    }

    public fun test_deserialize_transfer_proof_short_sigma_is_none(): bool {
        let short_sigma = vector[0u8];
        let zkrp_new = vector[];
        let zkrp_amt = vector[];
        let opt = confidential_proof::deserialize_transfer_proof(
            short_sigma, zkrp_new, zkrp_amt,
        );
        option::is_none(&opt)
    }

    /// One byte short of any conceivable correct sigma length (-1 byte means
    /// scalar/point decoders hit a partial 32-byte chunk). Feed 1151 bytes
    /// (assuming full withdrawal sigma is a multiple of 32) to pin rejection.
    public fun test_deserialize_withdrawal_proof_one_byte_short_is_none(): bool {
        let n = 1151; // odd length — never a valid witness
        let bad_sigma = vector::empty<u8>();
        let i = 0;
        while (i < n) {
            bad_sigma.push_back(0u8);
            i = i + 1;
        };
        let zkrp = vector[];
        let opt = confidential_proof::deserialize_withdrawal_proof(bad_sigma, zkrp);
        option::is_none(&opt)
    }

    public fun test_deserialize_normalization_proof_one_byte_short_is_none(): bool {
        let n = 1151;
        let bad_sigma = vector::empty<u8>();
        let i = 0;
        while (i < n) {
            bad_sigma.push_back(0u8);
            i = i + 1;
        };
        let zkrp = vector[];
        let opt = confidential_proof::deserialize_normalization_proof(bad_sigma, zkrp);
        option::is_none(&opt)
    }

    public fun test_deserialize_rotation_proof_one_byte_short_is_none(): bool {
        let n = 1215; // rotation sigma is 19 scalars + 19 points = 38*32 = 1216 bytes; -1 byte
        let bad_sigma = vector::empty<u8>();
        let i = 0;
        while (i < n) {
            bad_sigma.push_back(0u8);
            i = i + 1;
        };
        let zkrp = vector[];
        let opt = confidential_proof::deserialize_rotation_proof(bad_sigma, zkrp);
        option::is_none(&opt)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Phase J — deserializer length-check REGRESSION pins.
    //
    // Existing `one_byte_short → None` pins catch length-check regressions
    // where `!=` is weakened to `<=` or `<` (accepting some short lengths).
    // They do NOT catch the symmetric regression: `!=` weakened to `<`
    // (accepting longer-than-expected sigma bytes). A regression from
    //     if (len != EXPECTED) return none()
    // to
    //     if (len < EXPECTED) return none()
    // would silently accept longer sigma bytes. The deserializer slices only
    // `EXPECTED` bytes via `proof_bytes.slice(i*32, (i+1)*32)` for i < expected
    // count, so the EXTRA bytes are ignored. The proof deserializes as if it
    // were length EXPECTED, which is wrong.
    //
    // Pin: feed EXPECTED+1 bytes and require `None`. Catches any length-check
    // regression that stops rejecting longer-than-expected inputs.
    //
    // Note: for TRANSFER the check has a different shape — `< base OR
    // auditor_xs % 128 != 0`. The "one byte too long" case (len = base + 1)
    // is already rejected by `auditor_xs % 128 != 0`. But a regression that
    // drops the modulo check would let misaligned inputs slip through. Pin
    // several misaligned lengths explicitly below.

    /// Withdrawal sigma is exactly 1152 bytes (18 alphas + 18 Xs × 32 B).
    /// Feeding 1153 bytes must return `None`; otherwise a `!=` → `<`
    /// regression on the length check would let longer proof bytes through.
    public fun test_deserialize_withdrawal_proof_one_byte_too_long_is_none(): bool {
        let n = 1153;
        let bad_sigma = vector::empty<u8>();
        let i = 0;
        while (i < n) {
            bad_sigma.push_back(0u8);
            i = i + 1;
        };
        let zkrp = vector[];
        let opt = confidential_proof::deserialize_withdrawal_proof(bad_sigma, zkrp);
        option::is_none(&opt)
    }

    /// Normalization sigma is exactly 1152 bytes. Symmetric to withdrawal.
    public fun test_deserialize_normalization_proof_one_byte_too_long_is_none(): bool {
        let n = 1153;
        let bad_sigma = vector::empty<u8>();
        let i = 0;
        while (i < n) {
            bad_sigma.push_back(0u8);
            i = i + 1;
        };
        let zkrp = vector[];
        let opt = confidential_proof::deserialize_normalization_proof(bad_sigma, zkrp);
        option::is_none(&opt)
    }

    /// Rotation sigma is exactly 1216 bytes (19 alphas + 19 Xs × 32 B).
    public fun test_deserialize_rotation_proof_one_byte_too_long_is_none(): bool {
        let n = 1217;
        let bad_sigma = vector::empty<u8>();
        let i = 0;
        while (i < n) {
            bad_sigma.push_back(0u8);
            i = i + 1;
        };
        let zkrp = vector[];
        let opt = confidential_proof::deserialize_rotation_proof(bad_sigma, zkrp);
        option::is_none(&opt)
    }

    /// Transfer has variable length: base 1792 B + 128 B per auditor.
    /// Feeding `base + 32` (misaligned, not a multiple of 128) must return
    /// `None`. Catches a regression that drops `auditor_xs % 128 != 0`.
    public fun test_deserialize_transfer_proof_base_plus_32_is_none(): bool {
        let n = 1824; // 1792 + 32; auditor_xs = 32, 32 % 128 != 0
        let bad_sigma = vector::empty<u8>();
        let i = 0;
        while (i < n) {
            bad_sigma.push_back(0u8);
            i = i + 1;
        };
        let zkrp_new = vector[];
        let zkrp_amt = vector[];
        let opt = confidential_proof::deserialize_transfer_proof(
            bad_sigma, zkrp_new, zkrp_amt,
        );
        option::is_none(&opt)
    }

    /// Transfer: `base + 64` (misaligned). Same class of regression as above.
    public fun test_deserialize_transfer_proof_base_plus_64_is_none(): bool {
        let n = 1856;
        let bad_sigma = vector::empty<u8>();
        let i = 0;
        while (i < n) {
            bad_sigma.push_back(0u8);
            i = i + 1;
        };
        let zkrp_new = vector[];
        let zkrp_amt = vector[];
        let opt = confidential_proof::deserialize_transfer_proof(
            bad_sigma, zkrp_new, zkrp_amt,
        );
        option::is_none(&opt)
    }

    /// Transfer: `base + 96` (misaligned).
    public fun test_deserialize_transfer_proof_base_plus_96_is_none(): bool {
        let n = 1888;
        let bad_sigma = vector::empty<u8>();
        let i = 0;
        while (i < n) {
            bad_sigma.push_back(0u8);
            i = i + 1;
        };
        let zkrp_new = vector[];
        let zkrp_amt = vector[];
        let opt = confidential_proof::deserialize_transfer_proof(
            bad_sigma, zkrp_new, zkrp_amt,
        );
        option::is_none(&opt)
    }

    /// Transfer: `base + 1` (odd length). Catches regressions that drop
    /// either the base-length check or the modulo check.
    public fun test_deserialize_transfer_proof_base_plus_1_is_none(): bool {
        let n = 1793;
        let bad_sigma = vector::empty<u8>();
        let i = 0;
        while (i < n) {
            bad_sigma.push_back(0u8);
            i = i + 1;
        };
        let zkrp_new = vector[];
        let zkrp_amt = vector[];
        let opt = confidential_proof::deserialize_transfer_proof(
            bad_sigma, zkrp_new, zkrp_amt,
        );
        option::is_none(&opt)
    }

    /// Transfer: `base - 1` (one byte short). Catches regressions that
    /// weaken the base-length check from `<` to something that accepts
    /// strictly less-than-base.
    public fun test_deserialize_transfer_proof_base_minus_1_is_none(): bool {
        let n = 1791;
        let bad_sigma = vector::empty<u8>();
        let i = 0;
        while (i < n) {
            bad_sigma.push_back(0u8);
            i = i + 1;
        };
        let zkrp_new = vector[];
        let zkrp_amt = vector[];
        let opt = confidential_proof::deserialize_transfer_proof(
            bad_sigma, zkrp_new, zkrp_amt,
        );
        option::is_none(&opt)
    }

    /// An all-zero sigma of the correct length is a **structurally valid
    /// deserialization target** (all scalars / points become the identity /
    /// zero-scalar), so `deserialize_*_sigma_proof` returns `some`. Pin
    /// this — any change that tightens the decoder to reject zero-points
    /// must update this row.
    public fun test_deserialize_normalization_proof_all_zero_sigma_is_some(): bool {
        // 8 a1s + a2 + a3 + 8 a4s = 18 scalars; 1 x1 + 1 x2 + 8 x3s + 8 x4s
        // = 18 points. Total 36*32 = 1152 bytes.
        let n = 1152;
        let zero_sigma = vector::empty<u8>();
        let i = 0;
        while (i < n) {
            zero_sigma.push_back(0u8);
            i = i + 1;
        };
        // Bulletproofs decoder usually accepts any bytes (wraps them in
        // `RangeProof { bytes }` without validation).
        let zkrp = vector[];
        let opt = confidential_proof::deserialize_normalization_proof(zero_sigma, zkrp);
        option::is_some(&opt)
    }

    /// Shared helper: build a length-`n` `vector<u8>` of zeros. Used by the
    /// Phase D reject-verify rows to construct structurally-valid sigma
    /// proofs whose algebra is trivially wrong.
    fun make_zero_bytes(n: u64): vector<u8> {
        let v = vector::empty<u8>();
        let i = 0;
        while (i < n) {
            v.push_back(0u8);
            i = i + 1;
        };
        v
    }

    /// Phase K helper: build a length-`n` `vector<u8>` of zeros with the
    /// 32-byte window `[off, off+32)` overwritten with `0xff`. The all-0xff
    /// pattern is canonical-rejection for BOTH a ristretto255 `Scalar`
    /// (`0xff * 32 = 2^256 - 1 > L`) and a `CompressedRistretto` point (high
    /// bit set violates ristretto255 canonicity). This lets the same helper
    /// drive both "non-canonical scalar" and "non-canonical point" pins on
    /// the same sigma-proof byte stream by varying only `off`.
    fun make_zero_bytes_with_ff_at(n: u64, off: u64): vector<u8> {
        let v = make_zero_bytes(n);
        let i = 0;
        while (i < 32) {
            *v.borrow_mut(off + i) = 0xffu8;
            i = i + 1;
        };
        v
    }

    //
    // Phase K — non-canonical scalar / point rejection pins for every sigma
    // proof deserializer.
    //
    // Invariant under test: `deserialize_*_sigma_proof` must return `None`
    // when ANY 32-byte slot that is supposed to parse as a `Scalar` or a
    // `CompressedRistretto` fails its canonicality check. The Phase J rows
    // already pin length regressions; these rows pin the OTHER failure
    // surface (byte-level canonicality of each slot).
    //
    // Target regressions:
    //   1. An engineer relaxes `new_scalar_from_bytes` to `Scalar { data }`
    //      (skipping `scalar_is_canonical_internal`) → non-canonical scalars
    //      would silently parse. This class of bug is dangerous because
    //      downstream MSM / challenge derivation can produce attacker-
    //      chosen outputs once non-canonical scalars are accepted.
    //   2. Same as (1) but for `new_compressed_point_from_bytes` (dropping
    //      `point_is_canonical_internal`). Non-canonical ristretto encodings
    //      can map to valid internal points, breaking the 1-1 encoding
    //      contract that the protocol's soundness rests on.
    //   3. The deserializer stops short of the last slot (e.g. loops from
    //      0..N-1 instead of 0..N). A bad byte in the LAST slot would be
    //      missed. The *_last_* tests pin this.
    //

    /// Withdrawal sigma: 18 scalars at [0, 576). First scalar non-canonical
    /// ⇒ deserializer must return `None`.
    public fun test_deserialize_withdrawal_sigma_bad_first_scalar_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1152, 0);
        let opt = confidential_proof::deserialize_withdrawal_proof(sigma, vector[]);
        option::is_none(&opt)
    }

    /// Withdrawal sigma: last scalar slot at [544, 576). Non-canonical ⇒
    /// `None`. Catches a loop-bound off-by-one in the scalar-parse loop.
    public fun test_deserialize_withdrawal_sigma_bad_last_scalar_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1152, 544);
        let opt = confidential_proof::deserialize_withdrawal_proof(sigma, vector[]);
        option::is_none(&opt)
    }

    /// Withdrawal sigma: first point slot at [576, 608). Non-canonical ⇒
    /// `None`. Catches dropping `point_is_canonical_internal`.
    public fun test_deserialize_withdrawal_sigma_bad_first_point_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1152, 576);
        let opt = confidential_proof::deserialize_withdrawal_proof(sigma, vector[]);
        option::is_none(&opt)
    }

    /// Withdrawal sigma: last point slot at [1120, 1152). Non-canonical ⇒
    /// `None`. Catches a loop-bound off-by-one in the point-parse loop.
    public fun test_deserialize_withdrawal_sigma_bad_last_point_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1152, 1120);
        let opt = confidential_proof::deserialize_withdrawal_proof(sigma, vector[]);
        option::is_none(&opt)
    }

    /// Normalization sigma: 18 scalars at [0, 576). Same layout as
    /// withdrawal; `None` on non-canonical first scalar.
    public fun test_deserialize_normalization_sigma_bad_first_scalar_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1152, 0);
        let opt = confidential_proof::deserialize_normalization_proof(sigma, vector[]);
        option::is_none(&opt)
    }

    /// Normalization sigma: last scalar at [544, 576).
    public fun test_deserialize_normalization_sigma_bad_last_scalar_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1152, 544);
        let opt = confidential_proof::deserialize_normalization_proof(sigma, vector[]);
        option::is_none(&opt)
    }

    /// Normalization sigma: first point at [576, 608).
    public fun test_deserialize_normalization_sigma_bad_first_point_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1152, 576);
        let opt = confidential_proof::deserialize_normalization_proof(sigma, vector[]);
        option::is_none(&opt)
    }

    /// Normalization sigma: last point at [1120, 1152).
    public fun test_deserialize_normalization_sigma_bad_last_point_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1152, 1120);
        let opt = confidential_proof::deserialize_normalization_proof(sigma, vector[]);
        option::is_none(&opt)
    }

    /// Rotation sigma: 19 scalars at [0, 608). First scalar non-canonical
    /// ⇒ `None`.
    public fun test_deserialize_rotation_sigma_bad_first_scalar_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1216, 0);
        let opt = confidential_proof::deserialize_rotation_proof(sigma, vector[]);
        option::is_none(&opt)
    }

    /// Rotation sigma: last scalar at [576, 608).
    public fun test_deserialize_rotation_sigma_bad_last_scalar_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1216, 576);
        let opt = confidential_proof::deserialize_rotation_proof(sigma, vector[]);
        option::is_none(&opt)
    }

    /// Rotation sigma: first point at [608, 640).
    public fun test_deserialize_rotation_sigma_bad_first_point_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1216, 608);
        let opt = confidential_proof::deserialize_rotation_proof(sigma, vector[]);
        option::is_none(&opt)
    }

    /// Rotation sigma: last point at [1184, 1216).
    public fun test_deserialize_rotation_sigma_bad_last_point_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1216, 1184);
        let opt = confidential_proof::deserialize_rotation_proof(sigma, vector[]);
        option::is_none(&opt)
    }

    /// Transfer sigma base: 26 scalars at [0, 832). First scalar non-
    /// canonical ⇒ `None`. Base-layout only (no auditors).
    public fun test_deserialize_transfer_sigma_bad_first_scalar_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1792, 0);
        let opt = confidential_proof::deserialize_transfer_proof(sigma, vector[], vector[]);
        option::is_none(&opt)
    }

    /// Transfer sigma base: last scalar at [800, 832).
    public fun test_deserialize_transfer_sigma_bad_last_scalar_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1792, 800);
        let opt = confidential_proof::deserialize_transfer_proof(sigma, vector[], vector[]);
        option::is_none(&opt)
    }

    /// Transfer sigma base: first point at [832, 864).
    public fun test_deserialize_transfer_sigma_bad_first_point_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1792, 832);
        let opt = confidential_proof::deserialize_transfer_proof(sigma, vector[], vector[]);
        option::is_none(&opt)
    }

    /// Transfer sigma base: last point at [1760, 1792).
    public fun test_deserialize_transfer_sigma_bad_last_point_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1792, 1760);
        let opt = confidential_proof::deserialize_transfer_proof(sigma, vector[], vector[]);
        option::is_none(&opt)
    }

    /// Transfer sigma with one auditor (128 extra bytes = 4 points):
    /// last auditor-point at [1792 + 96, 1792 + 128). Base 1792 + 128 =
    /// 1920. Catches a regression where the per-auditor point loop skips
    /// its last slot.
    public fun test_deserialize_transfer_sigma_bad_last_auditor_point_is_none(): bool {
        let sigma = make_zero_bytes_with_ff_at(1920, 1888);
        let opt = confidential_proof::deserialize_transfer_proof(sigma, vector[], vector[]);
        option::is_none(&opt)
    }

    /// Phase D.1 — direct negative coverage for `verify_withdrawal_proof`.
    ///
    /// Feeds a well-formed-length, all-zero sigma proof (1152 B = 18 scalars
    /// + 18 points, all becoming zero-scalar / identity-point) and empty
    /// ZKRP bytes. `verify_withdrawal_sigma_proof` runs first, so the
    /// Fiat-Shamir challenge `rho` is computed over the commitments (all
    /// identity), and the final `multi_scalar_mul` equality check fails,
    /// aborting with `error::invalid_argument(ESIGMA_PROTOCOL_VERIFY_FAILED)`
    /// = 65537. This pins the FULL verifier code path (FS transcript,
    /// `msm_withdrawal_gammas`, `multi_scalar_mul`, `point_equals`).
    public fun test_verify_withdrawal_proof_zero_sigma_aborts(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract_address = @0xB;
        let dk = ristretto255::new_scalar_from_u64(77);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let amount = 42u64;
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let zero_sigma = make_zero_bytes(1152);
        let proof_opt = confidential_proof::deserialize_withdrawal_proof(zero_sigma, vector[]);
        assert!(option::is_some(&proof_opt), error::invalid_argument(1));
        let proof = option::destroy_some(proof_opt);
        confidential_proof::verify_withdrawal_proof(
            chain_id, sender, contract_address, &ek, amount,
            &current_balance, &new_balance, &proof,
        );
        true
    }

    /// Phase D.1 — direct negative coverage for `verify_normalization_proof`.
    /// See `test_verify_withdrawal_proof_zero_sigma_aborts`; identical shape
    /// but for the normalization sigma protocol. Sigma MSM mismatch aborts
    /// with 65537.
    public fun test_verify_normalization_proof_zero_sigma_aborts(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract_address = @0xB;
        let dk = ristretto255::new_scalar_from_u64(77);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let zero_sigma = make_zero_bytes(1152);
        let proof_opt = confidential_proof::deserialize_normalization_proof(zero_sigma, vector[]);
        assert!(option::is_some(&proof_opt), error::invalid_argument(1));
        let proof = option::destroy_some(proof_opt);
        confidential_proof::verify_normalization_proof(
            chain_id, sender, contract_address, &ek,
            &current_balance, &new_balance, &proof,
        );
        true
    }

    /// Phase D.1 — direct negative coverage for `verify_rotation_proof`.
    /// 19 scalars + 19 points = 1216 B sigma, two distinct pubkeys
    /// (current_ek, new_ek). Sigma MSM mismatch aborts with 65537.
    public fun test_verify_rotation_proof_zero_sigma_aborts(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract_address = @0xB;
        let dk_cur = ristretto255::new_scalar_from_u64(77);
        let dk_new = ristretto255::new_scalar_from_u64(88);
        let current_ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk_cur);
        let new_ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk_new);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let zero_sigma = make_zero_bytes(1216);
        let proof_opt = confidential_proof::deserialize_rotation_proof(zero_sigma, vector[]);
        assert!(option::is_some(&proof_opt), error::invalid_argument(1));
        let proof = option::destroy_some(proof_opt);
        confidential_proof::verify_rotation_proof(
            chain_id, sender, contract_address,
            &current_ek, &new_ek,
            &current_balance, &new_balance, &proof,
        );
        true
    }

    /// Phase D.1 — direct negative coverage for `verify_transfer_proof`.
    /// 26 scalars + 30 points = 1792 B sigma (base layout, no auditors).
    /// Exercises the transfer sigma protocol which is the heaviest
    /// (sender + recipient ek + 4 balances + auditor hint). Sigma MSM
    /// mismatch aborts with 65537.
    public fun test_verify_transfer_proof_zero_sigma_aborts(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract_address = @0xB;
        let dk_sender = ristretto255::new_scalar_from_u64(77);
        let dk_recipient = ristretto255::new_scalar_from_u64(88);
        let sender_ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk_sender);
        let recipient_ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk_recipient);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let sender_auditor_hint = vector::empty<u8>();
        let zero_sigma = make_zero_bytes(1792);
        let proof_opt = confidential_proof::deserialize_transfer_proof(zero_sigma, vector[], vector[]);
        assert!(option::is_some(&proof_opt), error::invalid_argument(1));
        let proof = option::destroy_some(proof_opt);
        confidential_proof::verify_transfer_proof(
            chain_id, sender, contract_address,
            &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts, &sender_auditor_hint,
            &proof,
        );
        true
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Phase G — Fiat-Shamir transcript PREFIX pins for the 4 sigma protocols.
    //
    // Production's `fiat_shamir_*_sigma_proof_challenge` functions build a byte
    // buffer:
    //
    //     msg = DST || chain_id || sender || contract || G || H || <pubkeys> ||
    //           <balances/chunks> || <proof commitment points X_*> || [tag]
    //
    // The `*_fs_prefix_for_test` helpers (added in the same commit that
    // introduced these tests) return the prefix UP TO the proof commitment
    // points — no drift risk, since the challenge fn now calls the same
    // private `*_prefix` helper internally.
    //
    // These rows pin the transcript layout byte-for-byte vs Lean `ldTrue`:
    //   1. Prefix starts with the correct protocol DST literal.
    //   2. Same inputs → same bytes (determinism).
    //   3. Different `chain_id` / `sender` / `contract_address` → different bytes.
    //   4. Cross-protocol distinctness for structurally-shared inputs.
    //
    // A regression that (e.g.) swaps the order of `sender` and `contract` in
    // `prepend_domain_context`, drops the G/H point prepend, or reuses the
    // wrong DST for one of the sigma protocols, would flip one of these rows
    // to `false` / mismatch and fail the run.

    /// Small helper: makes an `elg::CompressedPubkey` for tests from the basepoint `G`.
    fun basepoint_ek_for_fs_tests(): twisted_elgamal::CompressedPubkey {
        let bp = ristretto255::basepoint_compressed();
        let ek_bytes = ristretto255::compressed_point_to_bytes(bp);
        let ek_opt = twisted_elgamal::new_pubkey_from_bytes(ek_bytes);
        assert!(option::is_some(&ek_opt), error::invalid_argument(1));
        option::destroy_some(ek_opt)
    }

    /// Second distinct `elg::CompressedPubkey` for swap-matters tests — uses `H = hash_to_point_base()`.
    /// `G != H` by construction (different DSTs + distinct points), so the two eks produce distinct
    /// `pubkey_to_bytes` — necessary for "swapping sender_ek and recipient_ek changes the transcript".
    fun hash_base_ek_for_fs_tests(): twisted_elgamal::CompressedPubkey {
        let h = ristretto255::hash_to_point_base();
        let h_compressed = ristretto255::point_compress(&h);
        let ek_bytes = ristretto255::compressed_point_to_bytes(h_compressed);
        let ek_opt = twisted_elgamal::new_pubkey_from_bytes(ek_bytes);
        assert!(option::is_some(&ek_opt), error::invalid_argument(1));
        option::destroy_some(ek_opt)
    }

    /// Confirms `basepoint_ek_for_fs_tests()` and `hash_base_ek_for_fs_tests()` actually produce
    /// distinct pubkey bytes — foundation for every swap-matters pin below.
    public fun test_fs_prefix_two_test_eks_are_distinct(): bool {
        let ek_g = basepoint_ek_for_fs_tests();
        let ek_h = hash_base_ek_for_fs_tests();
        twisted_elgamal::pubkey_to_bytes(&ek_g) != twisted_elgamal::pubkey_to_bytes(&ek_h)
    }

    /// Builds a vector of 4 zero scalars for withdrawal `amount_chunks`.
    fun withdrawal_zero_chunks(): vector<ristretto255::Scalar> {
        let v = vector::empty<ristretto255::Scalar>();
        let i = 0;
        while (i < 4) {
            v.push_back(ristretto255::scalar_zero());
            i = i + 1;
        };
        v
    }

    /// Returns true iff `prefix` begins with every byte of `dst` in order.
    fun bytes_start_with(prefix: &vector<u8>, dst: &vector<u8>): bool {
        if (vector::length(prefix) < vector::length(dst)) return false;
        let i = 0;
        while (i < vector::length(dst)) {
            if (*vector::borrow(prefix, i) != *vector::borrow(dst, i)) return false;
            i = i + 1;
        };
        true
    }

    // Withdrawal prefix pins
    public fun test_fs_prefix_wd_starts_with_dst(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let chunks = withdrawal_zero_chunks();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let msg = confidential_proof::withdrawal_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &chunks, &bal);
        let dst = confidential_proof::get_fiat_shamir_withdrawal_sigma_dst();
        bytes_start_with(&msg, &dst)
    }

    public fun test_fs_prefix_wd_deterministic(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let chunks = withdrawal_zero_chunks();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::withdrawal_fs_prefix_for_test(
            7u8, @0xA, @0xB, &ek, &chunks, &bal);
        let b = confidential_proof::withdrawal_fs_prefix_for_test(
            7u8, @0xA, @0xB, &ek, &chunks, &bal);
        a == b
    }

    public fun test_fs_prefix_wd_chain_id_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let chunks = withdrawal_zero_chunks();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::withdrawal_fs_prefix_for_test(
            1u8, @0xA, @0xB, &ek, &chunks, &bal);
        let b = confidential_proof::withdrawal_fs_prefix_for_test(
            2u8, @0xA, @0xB, &ek, &chunks, &bal);
        a != b
    }

    public fun test_fs_prefix_wd_sender_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let chunks = withdrawal_zero_chunks();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::withdrawal_fs_prefix_for_test(
            7u8, @0xA, @0xC, &ek, &chunks, &bal);
        let b = confidential_proof::withdrawal_fs_prefix_for_test(
            7u8, @0xB, @0xC, &ek, &chunks, &bal);
        a != b
    }

    public fun test_fs_prefix_wd_contract_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let chunks = withdrawal_zero_chunks();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::withdrawal_fs_prefix_for_test(
            7u8, @0xA, @0xB, &ek, &chunks, &bal);
        let b = confidential_proof::withdrawal_fs_prefix_for_test(
            7u8, @0xA, @0xC, &ek, &chunks, &bal);
        a != b
    }

    /// Normalization shares the same `(chain_id, sender, contract, ek, bal, bal)` shape at
    /// the `current_balance = new_balance` corner, but the DST differs — the two prefixes
    /// MUST be byte-distinct (catches DST copy-paste bugs).
    public fun test_fs_prefix_wd_vs_norm_distinct(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let chunks = withdrawal_zero_chunks();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let wd = confidential_proof::withdrawal_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &chunks, &bal);
        let norm = confidential_proof::normalization_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &bal, &bal);
        wd != norm
    }

    // Normalization prefix pins
    public fun test_fs_prefix_norm_starts_with_dst(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let msg = confidential_proof::normalization_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &bal, &bal);
        let dst = confidential_proof::get_fiat_shamir_normalization_sigma_dst();
        bytes_start_with(&msg, &dst)
    }

    public fun test_fs_prefix_norm_deterministic(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::normalization_fs_prefix_for_test(
            3u8, @0xA, @0xB, &ek, &bal, &bal);
        let b = confidential_proof::normalization_fs_prefix_for_test(
            3u8, @0xA, @0xB, &ek, &bal, &bal);
        a == b
    }

    public fun test_fs_prefix_norm_chain_id_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::normalization_fs_prefix_for_test(
            1u8, @0xA, @0xB, &ek, &bal, &bal);
        let b = confidential_proof::normalization_fs_prefix_for_test(
            2u8, @0xA, @0xB, &ek, &bal, &bal);
        a != b
    }

    public fun test_fs_prefix_norm_sender_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::normalization_fs_prefix_for_test(
            1u8, @0xA, @0xB, &ek, &bal, &bal);
        let b = confidential_proof::normalization_fs_prefix_for_test(
            1u8, @0xC, @0xB, &ek, &bal, &bal);
        a != b
    }

    public fun test_fs_prefix_norm_contract_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::normalization_fs_prefix_for_test(
            1u8, @0xA, @0xB, &ek, &bal, &bal);
        let b = confidential_proof::normalization_fs_prefix_for_test(
            1u8, @0xA, @0xD, &ek, &bal, &bal);
        a != b
    }

    // Rotation prefix pins
    public fun test_fs_prefix_rot_starts_with_dst(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let msg = confidential_proof::rotation_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &bal, &bal);
        let dst = confidential_proof::get_fiat_shamir_rotation_sigma_dst();
        bytes_start_with(&msg, &dst)
    }

    public fun test_fs_prefix_rot_deterministic(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::rotation_fs_prefix_for_test(
            5u8, @0xA, @0xB, &ek, &ek, &bal, &bal);
        let b = confidential_proof::rotation_fs_prefix_for_test(
            5u8, @0xA, @0xB, &ek, &ek, &bal, &bal);
        a == b
    }

    public fun test_fs_prefix_rot_chain_id_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::rotation_fs_prefix_for_test(
            1u8, @0xA, @0xB, &ek, &ek, &bal, &bal);
        let b = confidential_proof::rotation_fs_prefix_for_test(
            9u8, @0xA, @0xB, &ek, &ek, &bal, &bal);
        a != b
    }

    public fun test_fs_prefix_rot_sender_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::rotation_fs_prefix_for_test(
            1u8, @0xA, @0xB, &ek, &ek, &bal, &bal);
        let b = confidential_proof::rotation_fs_prefix_for_test(
            1u8, @0xE, @0xB, &ek, &ek, &bal, &bal);
        a != b
    }

    public fun test_fs_prefix_rot_contract_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::rotation_fs_prefix_for_test(
            1u8, @0xA, @0xB, &ek, &ek, &bal, &bal);
        let b = confidential_proof::rotation_fs_prefix_for_test(
            1u8, @0xA, @0xF, &ek, &ek, &bal, &bal);
        a != b
    }

    /// Rotation and normalization both take `(ek, bal, bal)` in the same slot-position,
    /// but rotation has an extra `ek` field and a different DST. Distinct-prefix pin.
    public fun test_fs_prefix_rot_vs_norm_distinct(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let rot = confidential_proof::rotation_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &bal, &bal);
        let norm = confidential_proof::normalization_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &bal, &bal);
        rot != norm
    }

    // Transfer prefix pins
    public fun test_fs_prefix_tr_starts_with_dst(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let msg = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        let dst = confidential_proof::get_fiat_shamir_transfer_sigma_dst();
        bytes_start_with(&msg, &dst)
    }

    public fun test_fs_prefix_tr_deterministic(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = confidential_proof::transfer_fs_prefix_for_test(
            3u8, @0xA, @0xB, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            3u8, @0xA, @0xB, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        a == b
    }

    public fun test_fs_prefix_tr_chain_id_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = confidential_proof::transfer_fs_prefix_for_test(
            1u8, @0xA, @0xB, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            2u8, @0xA, @0xB, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        a != b
    }

    public fun test_fs_prefix_tr_sender_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = confidential_proof::transfer_fs_prefix_for_test(
            1u8, @0xA, @0xB, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            1u8, @0xE, @0xB, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        a != b
    }

    public fun test_fs_prefix_tr_contract_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = confidential_proof::transfer_fs_prefix_for_test(
            1u8, @0xA, @0xB, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            1u8, @0xA, @0xF, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        a != b
    }

    /// Auditor ek list length changes must flow into the transcript bytes.
    /// Catches a future refactor that forgets to iterate auditor_eks.
    public fun test_fs_prefix_tr_auditor_count_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let empty_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let empty_amts = vector::empty<confidential_balance::ConfidentialBalance>();
        let one_ek = vector::empty<twisted_elgamal::CompressedPubkey>();
        one_ek.push_back(ek);
        let one_amt = vector::empty<confidential_balance::ConfidentialBalance>();
        one_amt.push_back(confidential_balance::new_pending_balance_no_randomness());
        let a = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &empty_eks, &empty_amts);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &one_ek, &one_amt);
        a != b
    }

    /// Transfer vs withdrawal prefix: same domain context, same ek — must differ by DST.
    public fun test_fs_prefix_tr_vs_wd_distinct(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let chunks = withdrawal_zero_chunks();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let tr = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        let wd = confidential_proof::withdrawal_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &chunks, &act);
        tr != wd
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Phase G.2 — position-SWAP pins.
    //
    // These pins specifically target a class of bug that the positive
    // prove/verify roundtrip tests in `0x7::confidential_proof_tests` cannot
    // catch: a refactor that SWAPS two adjacent arguments in a transcript
    // construction (e.g. sender_ek ↔ recipient_ek, current_balance ↔
    // new_balance, sender ↔ contract_address in `prepend_domain_context`).
    //
    // Why positive roundtrip tests miss this: in `success_transfer`, the
    // prover and verifier both run inside the same Move unit test and both
    // see the SAME swap. They compute the same (wrong) challenge on both
    // sides, the sigma equation is still satisfied algebraically (swapping
    // doesn't break the structural MSM), and the test passes. But in
    // production, an off-chain prover (which won't have the swap bug) and
    // the on-chain verifier (which has the bug) would compute different
    // challenges and verification would fail for every user. A bug that
    // bricks the entire protocol in production but passes every test.
    //
    // Each row here uses two DISTINCT inputs at symmetric positions and
    // asserts the transcripts differ. All map to Lean `funcIdx := 40`
    // (`ldTrue`). A regression that removes the position-dependency flips
    // the row to `bool(false)` and mismatches Lean.

    /// Swapping `sender` and `contract_address` in the domain context MUST change
    /// the transcript. Catches a refactor like
    /// `prepend_domain_context(bytes, chain_id, contract_address, sender)`
    /// (args transposed at the call site).
    public fun test_fs_prefix_wd_sender_vs_contract_swap_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let chunks = withdrawal_zero_chunks();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::withdrawal_fs_prefix_for_test(
            0u8, @0xA, @0xB, &ek, &chunks, &bal);
        let b = confidential_proof::withdrawal_fs_prefix_for_test(
            0u8, @0xB, @0xA, &ek, &chunks, &bal);
        a != b
    }

    /// Withdrawal transcript: changing any single `amount_chunks[i]` must change the bytes.
    /// Catches a decoder/encoder that silently drops the `amount_chunks` vector in favor of
    /// a hard-coded zero.
    public fun test_fs_prefix_wd_amount_chunks_matter(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let chunks_zero = withdrawal_zero_chunks();
        let chunks_one = vector::empty<ristretto255::Scalar>();
        chunks_one.push_back(ristretto255::scalar_one());
        chunks_one.push_back(ristretto255::scalar_zero());
        chunks_one.push_back(ristretto255::scalar_zero());
        chunks_one.push_back(ristretto255::scalar_zero());
        let a = confidential_proof::withdrawal_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &chunks_zero, &bal);
        let b = confidential_proof::withdrawal_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &chunks_one, &bal);
        a != b
    }

    /// Normalization: swapping `current_balance` and `new_balance` must change the transcript.
    /// This matters even when both have equal chunk counts (8 actual chunks) because their
    /// values are distinct — silent swap would brick normalize for every user.
    public fun test_fs_prefix_norm_cur_vs_new_balance_swap_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let zero = confidential_balance::new_actual_balance_no_randomness();
        // Craft a non-zero balance via a one-filled byte slot at chunk 0.
        // 512 bytes: 32 B of `01` at position 0 (C of chunk 0) — rest all zero.
        // That makes C[0] = identity + 1*G = G (valid Ristretto point — basepoint), D[0] = identity.
        let nonzero_bytes = vector::empty<u8>();
        // First 32 bytes = basepoint_compressed() = nonzero; rest = zero.
        let bp_bytes = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        let i = 0;
        while (i < 32) {
            nonzero_bytes.push_back(*vector::borrow(&bp_bytes, i));
            i = i + 1;
        };
        while (i < 512) {
            nonzero_bytes.push_back(0u8);
            i = i + 1;
        };
        let nonzero_opt = confidential_balance::new_actual_balance_from_bytes(nonzero_bytes);
        assert!(option::is_some(&nonzero_opt), error::invalid_argument(1));
        let nonzero = option::destroy_some(nonzero_opt);

        let a = confidential_proof::normalization_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &zero, &nonzero);
        let b = confidential_proof::normalization_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &nonzero, &zero);
        a != b
    }

    /// Rotation: swapping `current_ek` and `new_ek` must change the transcript. Uses two
    /// distinct eks (G and H). Catches a refactor that accidentally transposes the two
    /// arguments at the `fiat_shamir_rotation_sigma_proof_prefix` call site.
    public fun test_fs_prefix_rot_cur_vs_new_ek_swap_matters(): bool {
        let ek_g = basepoint_ek_for_fs_tests();
        let ek_h = hash_base_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::rotation_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_g, &ek_h, &bal, &bal);
        let b = confidential_proof::rotation_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_h, &ek_g, &bal, &bal);
        a != b
    }

    /// Rotation: swapping `current_balance` and `new_balance` must change the transcript.
    public fun test_fs_prefix_rot_cur_vs_new_balance_swap_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let zero = confidential_balance::new_actual_balance_no_randomness();
        // Same non-zero construction as norm swap test.
        let nonzero_bytes = vector::empty<u8>();
        let bp_bytes = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        let i = 0;
        while (i < 32) {
            nonzero_bytes.push_back(*vector::borrow(&bp_bytes, i));
            i = i + 1;
        };
        while (i < 512) {
            nonzero_bytes.push_back(0u8);
            i = i + 1;
        };
        let nonzero = option::destroy_some(
            confidential_balance::new_actual_balance_from_bytes(nonzero_bytes));
        let a = confidential_proof::rotation_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &zero, &nonzero);
        let b = confidential_proof::rotation_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &nonzero, &zero);
        a != b
    }

    /// Transfer: swapping `sender_ek` and `recipient_ek` must change the transcript. This is
    /// one of the highest-severity silent-swap bugs — a role swap would route audit
    /// traffic through the wrong party and still pass every in-process roundtrip test.
    public fun test_fs_prefix_tr_sender_vs_recipient_ek_swap_matters(): bool {
        let ek_g = basepoint_ek_for_fs_tests();
        let ek_h = hash_base_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_g, &ek_h, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_h, &ek_g, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        a != b
    }

    /// Transfer: swapping `current_balance` (sender's current actual) and `new_balance`
    /// (sender's actual after transfer) must change the transcript. Catches a role swap
    /// in the verify signature.
    public fun test_fs_prefix_tr_current_vs_new_balance_swap_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        // Build distinct actual balances: zero vs "C[0] = basepoint".
        let zero = confidential_balance::new_actual_balance_no_randomness();
        let nonzero_bytes = vector::empty<u8>();
        let bp_bytes = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        let i = 0;
        while (i < 32) {
            nonzero_bytes.push_back(*vector::borrow(&bp_bytes, i));
            i = i + 1;
        };
        while (i < 512) {
            nonzero_bytes.push_back(0u8);
            i = i + 1;
        };
        let nonzero = option::destroy_some(
            confidential_balance::new_actual_balance_from_bytes(nonzero_bytes));
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &zero, &nonzero, &pend, &pend, &auditor_eks, &auditor_amounts);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &nonzero, &zero, &pend, &pend, &auditor_eks, &auditor_amounts);
        a != b
    }

    /// Transfer: swapping `sender_amount` and `recipient_amount` (both pending balances)
    /// must change the transcript. Note: only the D components of these are hashed per
    /// production. To produce two pending balances with distinct D components we craft them
    /// via `new_pending_balance_from_bytes` with different point encodings in D positions.
    public fun test_fs_prefix_tr_sender_vs_recipient_amount_swap_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        // Build two distinct pending balances that differ in their D components.
        // Pending is 4 chunks × 64 B = 256 B. Each chunk is 32 B C || 32 B D.
        // Zero pending: all 256 zeros.
        // Nonzero_d pending: C = 0 for all chunks, D[0] = basepoint, D[1..3] = 0.
        // That way balance_to_points_d → [G, 0, 0, 0], distinct from zero's [0,0,0,0].
        let bp_bytes = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        let sender_amt_bytes = vector::empty<u8>();
        // Chunk 0: C = 32 zeros, D = basepoint.
        let j = 0;
        while (j < 32) {
            sender_amt_bytes.push_back(0u8);
            j = j + 1;
        };
        j = 0;
        while (j < 32) {
            sender_amt_bytes.push_back(*vector::borrow(&bp_bytes, j));
            j = j + 1;
        };
        // Chunks 1..3: all zeros (64 B each).
        j = 0;
        while (j < 192) {
            sender_amt_bytes.push_back(0u8);
            j = j + 1;
        };
        let sender_amt = option::destroy_some(
            confidential_balance::new_pending_balance_from_bytes(sender_amt_bytes));

        // recipient_amt: zero pending (all 256 zeros → D = [0, 0, 0, 0]).
        let recipient_amt = confidential_balance::new_pending_balance_no_randomness();

        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &sender_amt, &recipient_amt, &auditor_eks, &auditor_amounts);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &recipient_amt, &sender_amt, &auditor_eks, &auditor_amounts);
        a != b
    }

    /// Transfer: swapping the ORDER of two distinct auditor eks must change the transcript.
    /// Extends the existing `test_fs_prefix_tr_auditor_count_matters` (which only shows that
    /// a non-empty list differs from an empty list) to catch a bug that e.g. sorts or
    /// reverses the auditor ek vector before hashing.
    public fun test_fs_prefix_tr_auditor_eks_order_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let ek_g = basepoint_ek_for_fs_tests();
        let ek_h = hash_base_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let eks_gh = vector::empty<twisted_elgamal::CompressedPubkey>();
        eks_gh.push_back(ek_g);
        eks_gh.push_back(ek_h);
        let ek_g2 = basepoint_ek_for_fs_tests();
        let ek_h2 = hash_base_ek_for_fs_tests();
        let eks_hg = vector::empty<twisted_elgamal::CompressedPubkey>();
        eks_hg.push_back(ek_h2);
        eks_hg.push_back(ek_g2);
        let zero_p1 = confidential_balance::new_pending_balance_no_randomness();
        let zero_p2 = confidential_balance::new_pending_balance_no_randomness();
        let auditor_amounts_1 = vector::empty<confidential_balance::ConfidentialBalance>();
        auditor_amounts_1.push_back(zero_p1);
        auditor_amounts_1.push_back(zero_p2);
        let zero_p3 = confidential_balance::new_pending_balance_no_randomness();
        let zero_p4 = confidential_balance::new_pending_balance_no_randomness();
        let auditor_amounts_2 = vector::empty<confidential_balance::ConfidentialBalance>();
        auditor_amounts_2.push_back(zero_p3);
        auditor_amounts_2.push_back(zero_p4);
        let a = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &eks_gh, &auditor_amounts_1);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &eks_hg, &auditor_amounts_2);
        a != b
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Phase N — individual-field coverage for FS prefixes.
    //
    // The existing Phase G pins cover:
    //   * chain_id / sender / contract `_matters` for all four protocols.
    //   * Position swaps (sender↔contract, sender_ek↔recipient_ek,
    //     current↔new balance, current↔new ek, auditor order).
    //   * `amount_chunks_matters` for withdrawal.
    //
    // A position-swap pin can catch "one of the two swapped slots was
    // dropped" but NOT "both slots were dropped" or "only one slot is
    // hashed". To catch that stronger class of bug we pin every remaining
    // field individually — change ONLY field X (keep everything else fixed)
    // and require the prefix bytes change. That way a transcript that
    // silently drops field X (e.g. a refactor that removes an
    // `append(pubkey_to_bytes(ek))` call) flips the row to `false`.
    //
    // This completes the matrix for every input to every FS prefix helper:
    //   * Withdrawal:        ek, current_balance  (amount_chunks already pinned).
    //   * Normalization:     ek, current_balance, new_balance.
    //   * Rotation:          current_ek, new_ek, current_balance, new_balance.
    //   * Transfer:          sender_ek, recipient_ek, current_balance,
    //                        new_balance, sender_amount, recipient_amount,
    //                        auditor-ek-contents, auditor-amount-contents.
    //
    // Uses the same two distinct EKs (G and H) and the same "basepoint at
    // chunk-0 C slot" non-zero balance construction already exercised by
    // Phase G.2 (guarded by `test_fs_prefix_two_test_eks_are_distinct` at
    // row zero of the matrix).

    /// Builds an actual (8-chunk) balance whose chunk-0 C component equals
    /// `basepoint` (rest zero). Distinct from `new_actual_balance_no_randomness`.
    fun nonzero_actual_bal_for_fs_tests(): confidential_balance::ConfidentialBalance {
        let nonzero_bytes = vector::empty<u8>();
        let bp_bytes = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        let i = 0;
        while (i < 32) {
            nonzero_bytes.push_back(*vector::borrow(&bp_bytes, i));
            i = i + 1;
        };
        while (i < 512) {
            nonzero_bytes.push_back(0u8);
            i = i + 1;
        };
        let opt = confidential_balance::new_actual_balance_from_bytes(nonzero_bytes);
        assert!(option::is_some(&opt), error::invalid_argument(1));
        option::destroy_some(opt)
    }

    /// Builds a pending (4-chunk) balance whose chunk-0 D component equals
    /// `basepoint` (rest zero). The production transfer transcript hashes
    /// only the D points of sender_amount/recipient_amount, so we make the
    /// nonzero signal visible at a D slot. Distinct from
    /// `new_pending_balance_no_randomness` in `balance_to_points_d`.
    fun nonzero_pending_bal_d_for_fs_tests(): confidential_balance::ConfidentialBalance {
        let bp_bytes = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        let bytes = vector::empty<u8>();
        let j = 0;
        while (j < 32) { bytes.push_back(0u8); j = j + 1; };
        j = 0;
        while (j < 32) {
            bytes.push_back(*vector::borrow(&bp_bytes, j));
            j = j + 1;
        };
        j = 0;
        while (j < 192) { bytes.push_back(0u8); j = j + 1; };
        let opt = confidential_balance::new_pending_balance_from_bytes(bytes);
        assert!(option::is_some(&opt), error::invalid_argument(1));
        option::destroy_some(opt)
    }

    // ── Withdrawal field-coverage ──

    /// Catches: `withdrawal` transcript that silently drops `ek`.
    public fun test_fs_prefix_wd_ek_matters(): bool {
        let ek_g = basepoint_ek_for_fs_tests();
        let ek_h = hash_base_ek_for_fs_tests();
        let chunks = withdrawal_zero_chunks();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::withdrawal_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_g, &chunks, &bal);
        let b = confidential_proof::withdrawal_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_h, &chunks, &bal);
        a != b
    }

    /// Catches: `withdrawal` transcript that silently drops `current_balance`.
    public fun test_fs_prefix_wd_current_balance_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let chunks = withdrawal_zero_chunks();
        let zero = confidential_balance::new_actual_balance_no_randomness();
        let nonzero = nonzero_actual_bal_for_fs_tests();
        let a = confidential_proof::withdrawal_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &chunks, &zero);
        let b = confidential_proof::withdrawal_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &chunks, &nonzero);
        a != b
    }

    // ── Normalization field-coverage ──

    /// Catches: `normalization` transcript that silently drops `ek`.
    public fun test_fs_prefix_norm_ek_matters(): bool {
        let ek_g = basepoint_ek_for_fs_tests();
        let ek_h = hash_base_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::normalization_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_g, &bal, &bal);
        let b = confidential_proof::normalization_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_h, &bal, &bal);
        a != b
    }

    /// Catches: `normalization` transcript that silently drops `current_balance`.
    /// Stronger than the existing `cur_vs_new_balance_swap_matters` row — that
    /// row still passes if only ONE of the two balance slots is hashed.
    public fun test_fs_prefix_norm_current_balance_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let zero = confidential_balance::new_actual_balance_no_randomness();
        let nonzero = nonzero_actual_bal_for_fs_tests();
        let a = confidential_proof::normalization_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &zero, &zero);
        let b = confidential_proof::normalization_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &nonzero, &zero);
        a != b
    }

    /// Dual of the above — catches `normalization` dropping `new_balance`.
    public fun test_fs_prefix_norm_new_balance_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let zero = confidential_balance::new_actual_balance_no_randomness();
        let nonzero = nonzero_actual_bal_for_fs_tests();
        let a = confidential_proof::normalization_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &zero, &zero);
        let b = confidential_proof::normalization_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &zero, &nonzero);
        a != b
    }

    // ── Rotation field-coverage ──

    /// Catches: `rotation` transcript that silently drops `current_ek`.
    public fun test_fs_prefix_rot_current_ek_matters(): bool {
        let ek_g = basepoint_ek_for_fs_tests();
        let ek_h = hash_base_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::rotation_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_g, &ek_g, &bal, &bal);
        let b = confidential_proof::rotation_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_h, &ek_g, &bal, &bal);
        a != b
    }

    /// Catches: `rotation` transcript that silently drops `new_ek`.
    public fun test_fs_prefix_rot_new_ek_matters(): bool {
        let ek_g = basepoint_ek_for_fs_tests();
        let ek_h = hash_base_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = confidential_proof::rotation_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_g, &ek_g, &bal, &bal);
        let b = confidential_proof::rotation_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_g, &ek_h, &bal, &bal);
        a != b
    }

    /// Catches: `rotation` transcript that silently drops `current_balance`.
    public fun test_fs_prefix_rot_current_balance_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let zero = confidential_balance::new_actual_balance_no_randomness();
        let nonzero = nonzero_actual_bal_for_fs_tests();
        let a = confidential_proof::rotation_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &zero, &zero);
        let b = confidential_proof::rotation_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &nonzero, &zero);
        a != b
    }

    /// Catches: `rotation` transcript that silently drops `new_balance`.
    public fun test_fs_prefix_rot_new_balance_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let zero = confidential_balance::new_actual_balance_no_randomness();
        let nonzero = nonzero_actual_bal_for_fs_tests();
        let a = confidential_proof::rotation_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &zero, &zero);
        let b = confidential_proof::rotation_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &zero, &nonzero);
        a != b
    }

    // ── Transfer field-coverage ──

    /// Catches: `transfer` transcript that silently drops `sender_ek`.
    public fun test_fs_prefix_tr_sender_ek_matters(): bool {
        let ek_g = basepoint_ek_for_fs_tests();
        let ek_h = hash_base_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let aeks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let aams = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_g, &ek_g, &act, &act, &pend, &pend, &aeks, &aams);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_h, &ek_g, &act, &act, &pend, &pend, &aeks, &aams);
        a != b
    }

    /// Catches: `transfer` transcript that silently drops `recipient_ek`.
    public fun test_fs_prefix_tr_recipient_ek_matters(): bool {
        let ek_g = basepoint_ek_for_fs_tests();
        let ek_h = hash_base_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let aeks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let aams = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_g, &ek_g, &act, &act, &pend, &pend, &aeks, &aams);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek_g, &ek_h, &act, &act, &pend, &pend, &aeks, &aams);
        a != b
    }

    /// Catches: `transfer` transcript that silently drops `current_balance`.
    public fun test_fs_prefix_tr_current_balance_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let zero = confidential_balance::new_actual_balance_no_randomness();
        let nonzero = nonzero_actual_bal_for_fs_tests();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let aeks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let aams = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &zero, &zero, &pend, &pend, &aeks, &aams);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &nonzero, &zero, &pend, &pend, &aeks, &aams);
        a != b
    }

    /// Catches: `transfer` transcript that silently drops `new_balance`.
    public fun test_fs_prefix_tr_new_balance_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let zero = confidential_balance::new_actual_balance_no_randomness();
        let nonzero = nonzero_actual_bal_for_fs_tests();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let aeks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let aams = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &zero, &zero, &pend, &pend, &aeks, &aams);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &zero, &nonzero, &pend, &pend, &aeks, &aams);
        a != b
    }

    /// Catches: `transfer` transcript that silently drops `sender_amount` (D points).
    public fun test_fs_prefix_tr_sender_amount_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let zero_p = confidential_balance::new_pending_balance_no_randomness();
        let nonzero_p = nonzero_pending_bal_d_for_fs_tests();
        let aeks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let aams = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &zero_p, &zero_p, &aeks, &aams);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &nonzero_p, &zero_p, &aeks, &aams);
        a != b
    }

    /// Catches: `transfer` transcript that silently drops `recipient_amount` (D points).
    public fun test_fs_prefix_tr_recipient_amount_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let zero_p = confidential_balance::new_pending_balance_no_randomness();
        let nonzero_p = nonzero_pending_bal_d_for_fs_tests();
        let aeks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let aams = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &zero_p, &zero_p, &aeks, &aams);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &zero_p, &nonzero_p, &aeks, &aams);
        a != b
    }

    /// Catches: `transfer` transcript that hashes auditor-ek COUNT but not
    /// auditor-ek CONTENTS (e.g. serializes only `len(auditor_eks)` instead
    /// of each ek's bytes). The existing `auditor_count_matters` row passes
    /// in that buggy regime because it compares empty vs one-element counts;
    /// this row pins contents-at-fixed-count-of-1.
    public fun test_fs_prefix_tr_auditor_ek_content_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let ek_g = basepoint_ek_for_fs_tests();
        let ek_h = hash_base_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let aeks_g = vector::empty<twisted_elgamal::CompressedPubkey>();
        aeks_g.push_back(ek_g);
        let aeks_h = vector::empty<twisted_elgamal::CompressedPubkey>();
        aeks_h.push_back(ek_h);
        let aams = vector::empty<confidential_balance::ConfidentialBalance>();
        aams.push_back(confidential_balance::new_pending_balance_no_randomness());
        let aams2 = vector::empty<confidential_balance::ConfidentialBalance>();
        aams2.push_back(confidential_balance::new_pending_balance_no_randomness());
        let a = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &aeks_g, &aams);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &aeks_h, &aams2);
        a != b
    }

    /// Dual of above — catches `transfer` hashing auditor-amount COUNT but
    /// not auditor-amount D-points. Same count (1), different D.
    public fun test_fs_prefix_tr_auditor_amount_content_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let ek_aud = basepoint_ek_for_fs_tests();
        let ek_aud2 = basepoint_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let aeks_1 = vector::empty<twisted_elgamal::CompressedPubkey>();
        aeks_1.push_back(ek_aud);
        let aeks_2 = vector::empty<twisted_elgamal::CompressedPubkey>();
        aeks_2.push_back(ek_aud2);
        let zero_p = confidential_balance::new_pending_balance_no_randomness();
        let nonzero_p = nonzero_pending_bal_d_for_fs_tests();
        let aams_zero = vector::empty<confidential_balance::ConfidentialBalance>();
        aams_zero.push_back(zero_p);
        let aams_nonzero = vector::empty<confidential_balance::ConfidentialBalance>();
        aams_nonzero.push_back(nonzero_p);
        let a = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &aeks_1, &aams_zero);
        let b = confidential_proof::transfer_fs_prefix_for_test(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &aeks_2, &aams_nonzero);
        a != b
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Phase O — prover-side field-coverage pins for
    // `prove_registration_deterministic_for_difftest`.
    //
    // Phases G / G.2 / N pin the FS *prefix* construction, and Phase H pins
    // the *verifier* rejection logic when a single argument is mutated on
    // the verify side. Neither of those covers the PROVER side: a
    // regression that mutates the prover's transcript (e.g. silently drops
    // `chain_id` from the FS challenge INSIDE the prover but not the
    // verifier) would break cross-process prove/verify — the Phase G
    // rows would still pass (they pin the verifier's public `_fs_prefix_
    // for_test` helper, which is built from the same private helper the
    // verifier uses, not the prover's copy), and the Phase H rows would
    // still pass (they round-trip prove→verify in the same process, so
    // both sides drop `chain_id` identically).
    //
    // The prover algebra is:
    //   commitment = point_compress(k * H)      ← depends ONLY on k
    //   response   = k − e(·) · dk⁻¹            ← depends on everything
    //                                              in the FS transcript
    //                                              (chain_id, sender,
    //                                              contract, token, ek,
    //                                              commitment) AND on dk
    //
    // So the two orthogonal bug-catching invariants are:
    //   (I) Commitment INVARIANCE under every non-k input: chain_id,
    //       sender, contract, token, ek, dk MUST NOT affect commitment.
    //       Catches: prover that accidentally mixes a non-k field into
    //       the commitment (e.g. `commitment = k * H + ek`, or a
    //       refactor that passes `k + chain_id as Scalar` to `point_mul`).
    //   (II) Commitment MATTERS under k change.
    //   (III) Response MATTERS under every FS-transcript input AND under
    //         dk. Catches: prover that silently drops a field from its
    //         own transcript or from its inversion of `dk`.
    //
    // All rows return `bool` and land at Lean `funcIdx := 40` (`ldTrue`).
    // 13 rows total.

    /// Compact alias: build the fixture ek for `dk = <scalar>`.
    fun reg_ek_for_scalar_u64(v: u64): twisted_elgamal::CompressedPubkey {
        let s = ristretto255::new_scalar_from_u64(v);
        difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&s)
    }

    // ── Length + determinism pins ──

    // ─────────────────────────────────────────────────────────────────────────
    // Phase Q — golden-vector byte pins for `prove_registration_deterministic_for_difftest`.
    //
    // Phase O pinned algebraic (IN)EQUALITY relationships between different
    // prover inputs (e.g. commitment must be invariant under `chain_id`,
    // response must vary under `dk`). Every such pin returns `bool(true)`
    // via a *structural* comparison of two prover outputs — it fires only
    // if the SIGN of the (in)equality flips. A subtle algebraic drift that
    // shifts both outputs symmetrically (e.g. a bug in
    // `new_scalar_from_sha2_512` that compresses bytes differently, or a
    // refactor of `point_compress` that swaps bit-order) could leave every
    // Phase O row intact while still silently changing the bytes.
    //
    // A golden-vector pin — "on this exact fixture, the prover MUST emit
    // THESE exact bytes" — is strictly stronger: it binds the full algebraic
    // transitive closure under the prover to a stable bit-for-bit output.
    // A single-bit change in any transitively-called primitive (`scalar_mul`,
    // `scalar_sub`, `scalar_invert`, `new_scalar_from_sha2_512`,
    // `basepoint_mul`, `point_mul`, `point_compress`, any byte-packing
    // helper) flips these bytes and fails the row.
    //
    // The fixture is `(chain_id=9, sender=@0xA, contract=@0xB, token=@0xC,
    // dk=scalar(42), ek=pk_from_scalar(42), k=scalar(9999))` — identical to
    // every Phase O row. Golden values were extracted from the Move VM
    // oracle (§ `./aptos-move/framework/formal/difftest.sh
    // --suite confidential_proof`) on **2026-04-17** and MUST be updated
    // in lockstep with any deliberate production-algebra change; doing so
    // is the *desired* regression workflow per § 1 of
    // `inventory/confidential_assets.md`.

    // ─────────────────────────────────────────────────────────────────────────
    // Phase R — golden-vector byte pins for the four sigma FS prefix helpers.
    //
    // Phase G pinned "starts with DST", "deterministic under identical inputs",
    // "changes when chain_id/sender/contract matters", and cross-protocol
    // pairwise distinctness. Phase G.2 pinned argument-position swaps. Phase N
    // pinned individual-field `_matters`. These cover every single-field
    // regression class but — like Phase O vs Phase Q for the prover — they are
    // all STRUCTURAL comparisons of two prefix outputs: they only fire if the
    // SIGN of some (in)equality flips. A subtle byte-layout drift that shifts
    // EVERY prefix output symmetrically — e.g. a bug in `compressed_point_to_bytes`
    // that changes endian, a refactor of `prepend_domain_context` that swaps
    // `chain_id`/`sender`/`contract` in a way that still happens to produce a
    // distinct byte under every Phase G swap pin, a subtle change in
    // `balance_to_bytes` order-of-chunks — could leave Phase G / G.2 / N
    // intact while silently changing every prefix's byte layout.
    //
    // A golden-vector pin — "on this exact fixture, the prefix helper MUST
    // emit THESE exact bytes" — is strictly stronger: it binds the full
    // algebraic + byte-packing transitive closure under `*_fs_prefix_for_test`
    // to a stable bit-for-bit output. A single-bit change in any transitively
    // called primitive (`basepoint_compressed`, `compressed_point_to_bytes`,
    // `hash_to_point_base`, `point_compress`, `pubkey_to_bytes`,
    // `scalar_to_bytes`, `balance_to_bytes`, `prepend_domain_context`,
    // `bcs::to_bytes`, or the underlying DST / chain_id / sender / contract
    // byte layout) flips these bytes and fails the row.
    //
    // Fixtures:
    //   chain_id = 9, sender = @0xA, contract = @0xB
    //   ek_g = basepoint_ek_for_fs_tests()   (basepoint as pubkey)
    //   ek_h = hash_base_ek_for_fs_tests()   (hash_to_point_base as pubkey)
    //   zero-balance pending/actual, no randomness (all ciphertexts = (id, id))
    //   withdrawal amount = 42 (split into [42, 0, 0, 0])
    //   transfer auditor lists empty
    //
    // Golden values were extracted from the Move VM oracle
    // (`./aptos-move/framework/formal/difftest.sh --suite confidential_proof`)
    // on 2026-04-17 and MUST be updated in lockstep with any deliberate
    // production-algebra change, per § 1 of `inventory/confidential_assets.md`.

    /// Phase U — withdrawal FS prefix golden with DISTINCT per-chunk amounts
    /// (837 B). Both Phase R (amount=42, chunks=[42,0,0,0]) and Phase T
    /// (amount=u64::MAX, chunks=[0xffff,0xffff,0xffff,0xffff]) leave every
    /// chunk-pair SWAP invisible: Phase R only exercises chunk 0 (so any
    /// swap involving only zero chunks is a no-op), and Phase T makes every
    /// chunk identical. This fixture uses `amount = 0x0004_0003_0002_0001`
    /// ⇒ chunks = [1, 2, 3, 4] — four pairwise-distinct 16-bit values. Any
    /// pairwise swap in the amount-chunk iteration loop flips exactly two
    /// of the four 32-byte scalar blobs in the prefix and fails this pin.
    public fun test_fs_prefix_wd_distinct_chunks_matches_golden(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(1125912791875585u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let got = confidential_proof::withdrawal_fs_prefix_for_test(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        got == x"4d6f76656d656e74436f6e666964656e7469616c41737365742f5769746864726177616c09000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000be2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d7601000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    }

    /// Phase U — rotation FS prefix golden with NON-ZERO current + NON-ZERO
    /// new, pairwise-distinct (1251 B). Phase R uses zero balances on both
    /// sides (every `balance_to_bytes` call returns 512 all-zero bytes, so
    /// current↔new swap is a no-op at the byte level). Phase T's norm_nonzero
    /// makes current non-zero but new zero — catches "either side is dropped"
    /// but since the asymmetry is visible, a reorder/swap between current
    /// and new is already observable. This fixture uses two DISTINCT
    /// non-zero balances: current = C[0]=basepoint (nonzero_actual_bal) and
    /// new = D[0]=basepoint (nonzero_actual_bal_d). A bug that (i) swaps
    /// `balance_to_bytes(current)` ↔ `balance_to_bytes(new)` call order,
    /// (ii) concatenates them in reversed order, or (iii) serializes both
    /// from the same source (dropping one) — all flip the pinned bytes.
    public fun test_fs_prefix_rot_nonzero_both_matches_golden(): bool {
        let current_ek = basepoint_ek_for_fs_tests();
        let new_ek = hash_base_ek_for_fs_tests();
        let current_balance = nonzero_actual_bal_for_fs_tests();
        let new_balance = nonzero_actual_bal_d_for_fs_tests();
        let got = confidential_proof::rotation_fs_prefix_for_test(
            9u8, @0xA, @0xB, &current_ek, &new_ek,
            &current_balance, &new_balance);
        got == x"4d6f76656d656e74436f6e666964656e7469616c41737365742f526f746174696f6e09000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000be2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d7600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    }

    /// Builds an actual (8-chunk) balance whose chunk-0 D component equals
    /// `basepoint` (rest zero, including C[0]). Distinct from both
    /// `nonzero_actual_bal_for_fs_tests` (C[0] = basepoint) and from
    /// `new_actual_balance_no_randomness` (all zero), so it's a third
    /// pairwise-distinct actual-balance value.
    fun nonzero_actual_bal_d_for_fs_tests(): confidential_balance::ConfidentialBalance {
        let bp_bytes = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        let bytes = vector::empty<u8>();
        let j = 0;
        while (j < 32) { bytes.push_back(0u8); j = j + 1; };
        j = 0;
        while (j < 32) {
            bytes.push_back(*vector::borrow(&bp_bytes, j));
            j = j + 1;
        };
        j = 0;
        while (j < 448) { bytes.push_back(0u8); j = j + 1; };
        let opt = confidential_balance::new_actual_balance_from_bytes(bytes);
        assert!(option::is_some(&opt), error::invalid_argument(1));
        option::destroy_some(opt)
    }

    /// Phase T — withdrawal FS prefix golden with `amount = u64::MAX` (837 B).
    /// Phase R's withdrawal golden uses `amount=42` which fills ONLY chunk 0;
    /// `u64::MAX` fills ALL 4 chunks with `0xffff`. A bug in `split_into_
    /// chunks_u64` that mis-shifts high chunks, a regression in
    /// `scalar_to_bytes` that produces wrong bytes for non-trivial values,
    /// or an off-by-one in the amount-chunk iteration loop
    /// (`amount_chunks.for_each_ref(|chunk| bytes.append(scalar_to_bytes
    /// (chunk)))`) that only manifests past chunk 0 — none of these would
    /// fail Phase R's amount=42 row because chunks 1-3 are zero there, but
    /// all would flip these bytes.
    public fun test_fs_prefix_wd_u64max_matches_golden(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(18446744073709551615u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let got = confidential_proof::withdrawal_fs_prefix_for_test(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        got == x"4d6f76656d656e74436f6e666964656e7469616c41737365742f5769746864726177616c09000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000be2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d76ffff000000000000000000000000000000000000000000000000000000000000ffff000000000000000000000000000000000000000000000000000000000000ffff000000000000000000000000000000000000000000000000000000000000ffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    }

    /// Phase T — transfer FS prefix golden with 2 auditors (1955 B). Phase S
    /// pins 1 auditor (the loop BODY). A bug that hashes only `auditor_eks[0]`
    /// (forgets to advance the index), that concats `auditor_eks[0]` twice,
    /// or that truncates at `auditor_eks.len() - 1` would pass Phase S's
    /// 1-auditor row but fail this 2-auditor row. Two DISTINCT auditor eks
    /// (hash_base + basepoint) + two distinct amounts (zero + chunk-0-D =
    /// basepoint) force the iteration to walk both slots' bytes.
    public fun test_fs_prefix_tr_2aud_matches_golden(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector[
            hash_base_ek_for_fs_tests(),
            basepoint_ek_for_fs_tests()
        ];
        let auditor_amounts = vector[
            confidential_balance::new_pending_balance_no_randomness(),
            nonzero_pending_bal_d_for_fs_tests()
        ];
        let got = confidential_proof::transfer_fs_prefix_for_test(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        got == x"4d6f76656d656e74436f6e666964656e7469616c41737365742f5472616e7366657209000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000be2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f340488711348c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d7600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    }

    /// Phase T — normalization FS prefix golden with NON-ZERO current balance
    /// (1224 B). Phase R's normalization golden uses zero balances, so every
    /// `balance_to_bytes` call produces 512 all-zero bytes — a bug in the
    /// per-chunk D-point extraction OR a chunk-concat bug (e.g. serializing
    /// chunks in reverse, or swapping C-point and D-point per chunk) would
    /// NOT manifest because all chunks are identical (zero). A non-zero
    /// current balance with chunk-0 C = basepoint catches these
    /// order-sensitive / component-swap bugs byte-for-byte.
    public fun test_fs_prefix_norm_nonzero_matches_golden(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let current_balance = nonzero_actual_bal_for_fs_tests();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let got = confidential_proof::normalization_fs_prefix_for_test(
            9u8, @0xA, @0xB, &ek, &current_balance, &new_balance);
        got == x"4d6f76656d656e74436f6e666964656e7469616c41737365742f4e6f726d616c697a6174696f6e09000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000be2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d76e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    }

    /// Phase S — second transfer FS prefix golden with 1 auditor (1795 B).
    /// Phase R's transfer golden uses 0 auditors, so the `auditor_eks.for_each_ref(|ek| ...)`
    /// and `auditor_amounts.for_each_ref(|bal| ...)` loops NEVER execute a body
    /// and are only pinned at "length 0" — a regression that silently skips the
    /// auditor loop (e.g. a refactor that uses `.for_each` but returns early
    /// on len==0, or an off-by-one that hashes only `auditor_eks[0..len-1]`)
    /// would still pass every Phase R / G / G.2 / N row. This golden, on a
    /// fixture with exactly 1 auditor ek (= hash_to_point_base) + 1 auditor
    /// amount (= zero pending balance, 128 B), pins the auditor-iteration
    /// path byte-for-byte: output must be 1795 B = 1635 (base) + 32 (ek) +
    /// 128 (pending balance).
    public fun test_fs_prefix_tr_1aud_matches_golden(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector[ hash_base_ek_for_fs_tests() ];
        let auditor_amounts = vector[
            confidential_balance::new_pending_balance_no_randomness()
        ];
        let got = confidential_proof::transfer_fs_prefix_for_test(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        got == x"4d6f76656d656e74436f6e666964656e7469616c41737365742f5472616e7366657209000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000be2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f340488711348c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    }

    /// Registration FS message golden (199 B). Pre-Phase R.1, the existing row
    /// `test_registration_fs_message_framework_matches_helpers_golden` pinned
    /// the production helper against the Move *helper*
    /// `difftest_registration_helpers::registration_fs_message_golden_move` —
    /// but that helper LIVE-RECONSTRUCTS the message from the same primitives
    /// (`FIAT_SHAMIR_REGISTRATION_SIGMA_DST`, `bcs::to_bytes`, `pubkey_to_bytes`,
    /// `compressed_point_to_bytes`) that the production code uses. A symmetric
    /// byte-layout drift in any of those primitives would shift BOTH sides
    /// equally and the row would still pass. A hex golden — extracted from the
    /// Move VM oracle on 2026-04-17 at fixture (chain_id=9, sender=@0x1,
    /// contract=@0x2, token=@0x3, ek=basepoint) — is strictly stronger: any
    /// single-bit drift in DST bytes, `bcs::to_bytes`, `pubkey_to_bytes`, or
    /// `compressed_point_to_bytes` flips the message and fails the row.
    public fun test_fs_reg_msg_matches_golden(): bool {
        let bp = ristretto255::basepoint_compressed();
        let ek_bytes = ristretto255::compressed_point_to_bytes(bp);
        let ek_opt = twisted_elgamal::new_pubkey_from_bytes(ek_bytes);
        let ek = std::option::destroy_some(ek_opt);
        let got = confidential_proof::registration_fs_message_for_test(
            9, @0x1, @0x2, @0x3, &ek, ek_bytes);
        got == x"4d6f76656d656e74436f6e666964656e7469616c41737365742f526567697374726174696f6e09000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d76e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d76"
    }

    /// Withdrawal FS prefix golden (837 B).
    public fun test_fs_prefix_wd_matches_golden(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(42u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let got = confidential_proof::withdrawal_fs_prefix_for_test(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        got == x"4d6f76656d656e74436f6e666964656e7469616c41737365742f5769746864726177616c09000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000be2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d762a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    }

    /// Normalization FS prefix golden (1224 B).
    public fun test_fs_prefix_norm_matches_golden(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let got = confidential_proof::normalization_fs_prefix_for_test(
            9u8, @0xA, @0xB, &ek, &current_balance, &new_balance);
        got == x"4d6f76656d656e74436f6e666964656e7469616c41737365742f4e6f726d616c697a6174696f6e09000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000be2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d7600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    }

    /// Rotation FS prefix golden (1251 B).
    public fun test_fs_prefix_rot_matches_golden(): bool {
        let current_ek = basepoint_ek_for_fs_tests();
        let new_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let got = confidential_proof::rotation_fs_prefix_for_test(
            9u8, @0xA, @0xB, &current_ek, &new_ek, &current_balance, &new_balance);
        got == x"4d6f76656d656e74436f6e666964656e7469616c41737365742f526f746174696f6e09000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000be2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f3404887113400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    }

    /// Transfer FS prefix golden (1635 B, 0 auditors).
    public fun test_fs_prefix_tr_matches_golden(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let got = confidential_proof::transfer_fs_prefix_for_test(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        got == x"4d6f76656d656e74436f6e666964656e7469616c41737365742f5472616e7366657209000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000be2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f3404887113400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    }

    /// Golden commitment bytes for the Phase Q fixture. If this row fails,
    /// EITHER the prover's algebra drifted (investigate!) OR a deliberate
    /// production fix landed (regenerate the golden and log it).
    public fun test_prove_reg_det_commitment_matches_golden(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (commitment, _response) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        commitment == x"b268253d22a9668268094e11b365efe05314b3bf55e8f681d0a76124c52b1774"
    }

    /// Golden response bytes for the Phase Q fixture.
    public fun test_prove_reg_det_response_matches_golden(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (_commitment, response) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        response == x"8c6d7437c7e2f158cdd0da5d9202a7ecfbf15efcfa3176c50c925306b00a480d"
    }

    /// `commitment_bytes` MUST be exactly 32 bytes — a Ristretto255 compressed point.
    public fun test_prove_reg_det_commitment_length_is_32(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (commitment, _response) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        commitment.length() == 32
    }

    /// `response_bytes` MUST be exactly 32 bytes — a Ristretto255 scalar.
    public fun test_prove_reg_det_response_length_is_32(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (_commitment, response) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        response.length() == 32
    }

    /// Determinism: same inputs → same (commitment, response). Catches: any
    /// internal randomness leak or stateful prover.
    public fun test_prove_reg_det_deterministic_same_inputs(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (c1, r1) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        let (c2, r2) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        c1 == c2 && r1 == r2
    }

    // ── Invariant (I): commitment depends ONLY on `k` ──

    /// `commitment` MUST NOT depend on `chain_id`. Catches: refactor that
    /// threads `chain_id` into the `k * H` computation.
    public fun test_prove_reg_det_commitment_invariant_under_chain_id(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (c1, _) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        let (c2, _) = confidential_proof::prove_registration_deterministic_for_difftest(
            10u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        c1 == c2
    }

    /// `commitment` MUST NOT depend on `sender`.
    public fun test_prove_reg_det_commitment_invariant_under_sender(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (c1, _) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        let (c2, _) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xDEAD, @0xB, &dk, &ek, @0xC, &k);
        c1 == c2
    }

    /// `commitment` MUST NOT depend on `contract_address`.
    public fun test_prove_reg_det_commitment_invariant_under_contract(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (c1, _) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        let (c2, _) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xDEAD, &dk, &ek, @0xC, &k);
        c1 == c2
    }

    /// `commitment` MUST NOT depend on `token_address`.
    public fun test_prove_reg_det_commitment_invariant_under_token(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (c1, _) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        let (c2, _) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xDEAD, &k);
        c1 == c2
    }

    /// `commitment` MUST NOT depend on `ek`. Catches: prover folding the
    /// encryption key into the commitment (would leak the binding to a
    /// specific ek into the commitment, breaking proof malleability
    /// protections in unexpected ways).
    public fun test_prove_reg_det_commitment_invariant_under_ek(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek_1 = reg_ek_for_scalar_u64(42);
        let ek_2 = reg_ek_for_scalar_u64(43);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (c1, _) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek_1, @0xC, &k);
        let (c2, _) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek_2, @0xC, &k);
        c1 == c2
    }

    /// `commitment` MUST NOT depend on `dk`. Catches: prover accidentally
    /// using `dk` in the commitment computation (e.g. `commitment = k * dk`
    /// — would leak `dk` bits into a public value).
    public fun test_prove_reg_det_commitment_invariant_under_dk(): bool {
        let dk_1 = ristretto255::new_scalar_from_u64(42);
        let dk_2 = ristretto255::new_scalar_from_u64(43);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (c1, _) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk_1, &ek, @0xC, &k);
        let (c2, _) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk_2, &ek, @0xC, &k);
        c1 == c2
    }

    // ── Invariant (II): commitment varies with `k` ──

    /// `commitment` MUST change when `k` changes. Catches: prover that
    /// computes a constant commitment (e.g. hard-coded `point_identity()`).
    public fun test_prove_reg_det_commitment_changes_with_k(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k1 = ristretto255::new_scalar_from_u64(9999);
        let k2 = ristretto255::new_scalar_from_u64(10000);
        let (c1, _) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k1);
        let (c2, _) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k2);
        c1 != c2
    }

    // ── Invariant (III): response varies with every transcript input + dk ──

    /// `response` MUST change when `chain_id` changes (via FS challenge `e`).
    /// Catches: prover that drops `chain_id` from its own transcript.
    public fun test_prove_reg_det_response_changes_with_chain_id(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (_, r1) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        let (_, r2) = confidential_proof::prove_registration_deterministic_for_difftest(
            10u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        r1 != r2
    }

    /// `response` MUST change when `sender` changes.
    public fun test_prove_reg_det_response_changes_with_sender(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (_, r1) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        let (_, r2) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xDEAD, @0xB, &dk, &ek, @0xC, &k);
        r1 != r2
    }

    /// `response` MUST change when `contract_address` changes.
    public fun test_prove_reg_det_response_changes_with_contract(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (_, r1) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        let (_, r2) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xDEAD, &dk, &ek, @0xC, &k);
        r1 != r2
    }

    /// `response` MUST change when `token_address` changes.
    public fun test_prove_reg_det_response_changes_with_token(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (_, r1) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k);
        let (_, r2) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xDEAD, &k);
        r1 != r2
    }

    /// `response` MUST change when `ek` changes (bytes feed into FS `e`).
    /// Catches: prover that drops `ek` from its transcript — a variant would
    /// bind the proof to a "wildcard" ek, critical security hole.
    public fun test_prove_reg_det_response_changes_with_ek(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek_1 = reg_ek_for_scalar_u64(42);
        let ek_2 = reg_ek_for_scalar_u64(43);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (_, r1) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek_1, @0xC, &k);
        let (_, r2) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek_2, @0xC, &k);
        r1 != r2
    }

    /// `response` MUST change when `dk` changes (via `dk_inv` multiplied
    /// into `response = k - e * dk_inv`). Catches: prover that zeroes out
    /// `dk` (e.g. an off-by-one that reads uninitialized local as dk) —
    /// would produce a "signed-with-identity" proof that any `dk` can
    /// verify, trivially breaking soundness.
    public fun test_prove_reg_det_response_changes_with_dk(): bool {
        let dk_1 = ristretto255::new_scalar_from_u64(42);
        let dk_2 = ristretto255::new_scalar_from_u64(43);
        let ek = reg_ek_for_scalar_u64(42);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (_, r1) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk_1, &ek, @0xC, &k);
        let (_, r2) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk_2, &ek, @0xC, &k);
        r1 != r2
    }

    /// `response` MUST change when `k` changes (directly appears in
    /// `response = k − e·dk_inv`, and also through `r = k*H` in `e`).
    public fun test_prove_reg_det_response_changes_with_k(): bool {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = reg_ek_for_scalar_u64(42);
        let k1 = ristretto255::new_scalar_from_u64(9999);
        let k2 = ristretto255::new_scalar_from_u64(10000);
        let (_, r1) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k1);
        let (_, r2) = confidential_proof::prove_registration_deterministic_for_difftest(
            9u8, @0xA, @0xB, &dk, &ek, @0xC, &k2);
        r1 != r2
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Phase P — `verify_registration_proof_for_difftest` input-byte rejection
    // pins: non-canonical + wrong-length `commitment_bytes` / `response_bytes`.
    //
    // Phase H pins the verifier against SEMANTIC mutation (e.g. flip the
    // last byte of `commitment_bytes` → still a valid 32-byte encoding, so
    // we land on the `point_equals` check). These Phase P pins exercise
    // the FIRST verifier gate: the parsing / canonicality check at
    // `verify_registration_proof`:
    //
    //   let r_point = ristretto255::new_compressed_point_from_bytes(
    //       commitment_bytes);
    //   assert!(option::is_some(&r_point),
    //       error::invalid_argument(ESIGMA_PROTOCOL_VERIFY_FAILED));
    //
    //   let s = ristretto255::new_scalar_from_bytes(response_bytes);
    //   assert!(option::is_some(&s),
    //       error::invalid_argument(ESIGMA_PROTOCOL_VERIFY_FAILED));
    //
    // A regression that drops either `assert!` (or replaces the
    // `new_*_from_bytes` factories with raw wrappers that skip the
    // canonicality checks) would silently accept:
    //   - commitment bytes of wrong length → panic downstream, corrupting
    //     the VM;
    //   - a non-canonical commitment encoding → violates ristretto255's
    //     1-1 encoding contract, a precondition for every soundness
    //     proof in this module;
    //   - a non-canonical response scalar (`>= L`) → an attacker could
    //     submit infinitely many "different" scalars that reduce to the
    //     same point, breaking the proof's binding to a unique witness.
    //
    // Each row returns `()` after aborting with
    // `error::invalid_argument(ESIGMA_PROTOCOL_VERIFY_FAILED)` = 65537.
    // Lean descriptor: `funcIdx := 195` (`caSigmaVerifyFailedAbortDesc`).
    //
    // 6 rows total.

    /// Registration verify MUST reject a 31-byte `commitment_bytes` (too short).
    public fun test_verify_registration_rejects_commitment_len_31(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract = @0xB;
        let token = @0xC;
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (_commitment, response) = confidential_proof::prove_registration_deterministic_for_difftest(
            chain_id, sender, contract, &dk, &ek, token, &k);
        let short_commit = make_zero_bytes(31);
        confidential_proof::verify_registration_proof_for_difftest(
            chain_id, sender, contract, &ek, token, short_commit, response);
        true
    }

    /// Registration verify MUST reject a 33-byte `commitment_bytes` (too long).
    public fun test_verify_registration_rejects_commitment_len_33(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract = @0xB;
        let token = @0xC;
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (_commitment, response) = confidential_proof::prove_registration_deterministic_for_difftest(
            chain_id, sender, contract, &dk, &ek, token, &k);
        let long_commit = make_zero_bytes(33);
        confidential_proof::verify_registration_proof_for_difftest(
            chain_id, sender, contract, &ek, token, long_commit, response);
        true
    }

    /// Registration verify MUST reject a non-canonical `commitment_bytes`
    /// (`0xff * 32` has the high bit set and violates ristretto255 canonicity).
    public fun test_verify_registration_rejects_commitment_noncanonical_ff32(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract = @0xB;
        let token = @0xC;
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (_commitment, response) = confidential_proof::prove_registration_deterministic_for_difftest(
            chain_id, sender, contract, &dk, &ek, token, &k);
        let bad_commit = make_zero_bytes_with_ff_at(32, 0);
        confidential_proof::verify_registration_proof_for_difftest(
            chain_id, sender, contract, &ek, token, bad_commit, response);
        true
    }

    /// Registration verify MUST reject a 31-byte `response_bytes`.
    public fun test_verify_registration_rejects_response_len_31(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract = @0xB;
        let token = @0xC;
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (commitment, _response) = confidential_proof::prove_registration_deterministic_for_difftest(
            chain_id, sender, contract, &dk, &ek, token, &k);
        let short_resp = make_zero_bytes(31);
        confidential_proof::verify_registration_proof_for_difftest(
            chain_id, sender, contract, &ek, token, commitment, short_resp);
        true
    }

    /// Registration verify MUST reject a 33-byte `response_bytes`.
    public fun test_verify_registration_rejects_response_len_33(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract = @0xB;
        let token = @0xC;
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (commitment, _response) = confidential_proof::prove_registration_deterministic_for_difftest(
            chain_id, sender, contract, &dk, &ek, token, &k);
        let long_resp = make_zero_bytes(33);
        confidential_proof::verify_registration_proof_for_difftest(
            chain_id, sender, contract, &ek, token, commitment, long_resp);
        true
    }

    /// Registration verify MUST reject a non-canonical `response_bytes`
    /// (`0xff * 32` = `2^256 − 1 > L`; violates scalar canonicity). A
    /// regression that drops `scalar_is_canonical_internal` would let an
    /// attacker forge infinitely many distinct-but-equivalent responses,
    /// directly breaking binding.
    public fun test_verify_registration_rejects_response_noncanonical_ff32(): bool {
        let chain_id = 9u8;
        let sender = @0xA;
        let contract = @0xB;
        let token = @0xC;
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = difftest_registration_helpers::registration_fixture_pubkey_from_secret_scalar(&dk);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (commitment, _response) = confidential_proof::prove_registration_deterministic_for_difftest(
            chain_id, sender, contract, &dk, &ek, token, &k);
        let bad_resp = make_zero_bytes_with_ff_at(32, 0);
        confidential_proof::verify_registration_proof_for_difftest(
            chain_id, sender, contract, &ek, token, commitment, bad_resp);
        true
    }
}
"#;

pub struct ConfidentialProofSuite;

impl DiffTestSuite for ConfidentialProofSuite {
    fn id(&self) -> &'static str {
        "confidential_proof"
    }

    fn name(&self) -> &str {
        "0x1::difftest_confidential_proof (+ registration helpers)"
    }

    fn load_module(&self, storage: &mut InMemoryStorage) -> Result<()> {
        let paths: Vec<&Path> = EXTRA_MOVE.iter().map(Path::new).collect();
        let modules = compile_with_aptos_head_bundle_extras(TEST_SOURCE, &paths)?;
        for module in &modules {
            let blob = module_blob(module)?;
            storage.add_module_bytes(module.self_addr(), module.self_name(), blob.into());
        }
        Ok(())
    }

    fn generate_test_cases(&self, storage: &mut InMemoryStorage) -> Result<Vec<TestCase>> {
        let mut cases = Vec::new();
        for (function, label) in [
            ("test_bulletproofs_dst", "dst"),
            ("test_bulletproofs_num_bits", "bits"),
            ("test_bulletproofs_dst_sha3_512", "bp_dst_sha512"),
            ("test_fiat_shamir_withdrawal_sigma_dst", "fs_wd"),
            ("test_fiat_shamir_transfer_sigma_dst", "fs_tr"),
            ("test_fiat_shamir_normalization_sigma_dst", "fs_norm"),
            ("test_fiat_shamir_rotation_sigma_dst", "fs_rot"),
            ("test_fiat_shamir_registration_sigma_dst", "fs_reg"),
            ("test_deserialize_withdrawal_empty_none", "withdrawal"),
            ("test_deserialize_transfer_empty_none", "transfer"),
            ("test_deserialize_normalization_empty_none", "norm"),
            ("test_deserialize_rotation_empty_none", "rotation"),
            (
                "test_deserialize_withdrawal_short_sigma_is_none",
                "wd_short_sig",
            ),
            (
                "test_deserialize_transfer_short_sigma_is_none",
                "tr_short_sig",
            ),
            (
                "test_deserialize_normalization_short_sigma_is_none",
                "norm_short_sig",
            ),
            (
                "test_deserialize_rotation_short_sigma_is_none",
                "rot_short_sig",
            ),
            (
                "test_deserialize_withdrawal_layout_ok_is_some",
                "wd_layout_some",
            ),
            (
                "test_deserialize_normalization_layout_ok_is_some",
                "norm_layout_some",
            ),
            (
                "test_deserialize_rotation_layout_ok_is_some",
                "rot_layout_some",
            ),
            (
                "test_deserialize_transfer_layout_ok_is_some",
                "tr_layout_some",
            ),
            (
                "test_layout_sigma_18_scalars_18_points_byte_length_is_1152",
                "sigma18_len",
            ),
            (
                "test_layout_sigma_19_scalars_19_points_byte_length_is_1216",
                "sigma19_len",
            ),
            (
                "test_layout_sigma_transfer_base_layout_byte_length_is_1792",
                "sigma_tr_len",
            ),
            (
                "test_layout_sigma_transfer_one_auditor_quad_extension_byte_length_is_1920",
                "sigma_tr_ext1920_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_one_auditor_ok_is_some",
                "tr_ext_layout_some",
            ),
            (
                "test_layout_sigma_transfer_two_auditor_quads_extension_byte_length_is_2048",
                "sigma_tr_ext2048_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_two_auditors_ok_is_some",
                "tr_ext2_layout_some",
            ),
            (
                "test_layout_sigma_transfer_three_auditor_quads_extension_byte_length_is_2176",
                "sigma_tr_ext2176_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_three_auditors_ok_is_some",
                "tr_ext3_layout_some",
            ),
            (
                "test_layout_sigma_transfer_four_auditor_quads_extension_byte_length_is_2304",
                "sigma_tr_ext2304_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_four_auditors_ok_is_some",
                "tr_ext4_layout_some",
            ),
            (
                "test_layout_sigma_transfer_five_auditor_quads_extension_byte_length_is_2432",
                "sigma_tr_ext2432_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_five_auditors_ok_is_some",
                "tr_ext5_layout_some",
            ),
            (
                "test_layout_sigma_transfer_six_auditor_quads_extension_byte_length_is_2560",
                "sigma_tr_ext2560_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_six_auditors_ok_is_some",
                "tr_ext6_layout_some",
            ),
            (
                "test_layout_sigma_transfer_seven_auditor_quads_extension_byte_length_is_2688",
                "sigma_tr_ext2688_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_seven_auditors_ok_is_some",
                "tr_ext7_layout_some",
            ),
            (
                "test_layout_sigma_transfer_eight_auditor_quads_extension_byte_length_is_2816",
                "sigma_tr_ext2816_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_eight_auditors_ok_is_some",
                "tr_ext8_layout_some",
            ),
            (
                "test_layout_sigma_transfer_nine_auditor_quads_extension_byte_length_is_2944",
                "sigma_tr_ext2944_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_nine_auditors_ok_is_some",
                "tr_ext9_layout_some",
            ),
            (
                "test_layout_sigma_transfer_ten_auditor_quads_extension_byte_length_is_3072",
                "sigma_tr_ext3072_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_ten_auditors_ok_is_some",
                "tr_ext10_layout_some",
            ),
            (
                "test_layout_sigma_transfer_eleven_auditor_quads_extension_byte_length_is_3200",
                "sigma_tr_ext3200_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_eleven_auditors_ok_is_some",
                "tr_ext11_layout_some",
            ),
            (
                "test_layout_sigma_transfer_twelve_auditor_quads_extension_byte_length_is_3328",
                "sigma_tr_ext3328_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_twelve_auditors_ok_is_some",
                "tr_ext12_layout_some",
            ),
            (
                "test_layout_sigma_transfer_thirteen_auditor_quads_extension_byte_length_is_3456",
                "sigma_tr_ext3456_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_thirteen_auditors_ok_is_some",
                "tr_ext13_layout_some",
            ),
            (
                "test_layout_sigma_transfer_fourteen_auditor_quads_extension_byte_length_is_3584",
                "sigma_tr_ext3584_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_fourteen_auditors_ok_is_some",
                "tr_ext14_layout_some",
            ),
            (
                "test_layout_sigma_transfer_fifteen_auditor_quads_extension_byte_length_is_3712",
                "sigma_tr_ext3712_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_fifteen_auditors_ok_is_some",
                "tr_ext15_layout_some",
            ),
            (
                "test_layout_sigma_transfer_sixteen_auditor_quads_extension_byte_length_is_3840",
                "sigma_tr_ext3840_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_sixteen_auditors_ok_is_some",
                "tr_ext16_layout_some",
            ),
            (
                "test_layout_sigma_transfer_seventeen_auditor_quads_extension_byte_length_is_3968",
                "sigma_tr_ext3968_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_seventeen_auditors_ok_is_some",
                "tr_ext17_layout_some",
            ),
            (
                "test_layout_sigma_transfer_eighteen_auditor_quads_extension_byte_length_is_4096",
                "sigma_tr_ext4096_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_eighteen_auditors_ok_is_some",
                "tr_ext18_layout_some",
            ),
            (
                "test_layout_sigma_transfer_nineteen_auditor_quads_extension_byte_length_is_4224",
                "sigma_tr_ext4224_len",
            ),
            (
                "test_deserialize_transfer_layout_extended_nineteen_auditors_ok_is_some",
                "tr_ext19_layout_some",
            ),
            ("test_registration_helpers_roundtrip", "schnorr_helpers"),
            (
                "test_registration_fs_message_framework_matches_helpers_golden",
                "reg_fs_fw_eq_helpers",
            ),
            (
                "test_registration_proof_framework_deterministic_verify_roundtrip",
                "reg_proof_fw_rt",
            ),
            ("test_registration_fs_message_golden_move", "reg_fs_golden"),
            ("test_registration_fs_message_golden_move_second", "reg_fs_golden_2"),
            (
                "test_registration_fs_message_framework_second_scenario_matches_helpers_golden",
                "reg_fs_fw_eq_helpers_2",
            ),
            ("test_fs_dst_transfer_not_equal_rotation", "fs_dst_tr_ne_rot"),
            (
                "test_fs_dst_withdrawal_not_equal_normalization",
                "fs_dst_wd_ne_norm",
            ),
            (
                "test_fs_dst_registration_not_equal_normalization",
                "fs_dst_reg_ne_norm",
            ),
            (
                "test_fs_dst_withdrawal_not_equal_transfer",
                "fs_dst_wd_ne_tr",
            ),
            (
                "test_fs_dst_withdrawal_not_equal_rotation",
                "fs_dst_wd_ne_rot",
            ),
            (
                "test_fs_dst_withdrawal_not_equal_registration",
                "fs_dst_wd_ne_reg",
            ),
            (
                "test_fs_dst_transfer_not_equal_normalization",
                "fs_dst_tr_ne_norm",
            ),
            (
                "test_fs_dst_transfer_not_equal_registration",
                "fs_dst_tr_ne_reg",
            ),
            (
                "test_fs_dst_rotation_not_equal_normalization",
                "fs_dst_rot_ne_norm",
            ),
            (
                "test_fs_dst_rotation_not_equal_registration",
                "fs_dst_rot_ne_reg",
            ),
            (
                "test_fs_dst_bulletproofs_not_equal_any_sigma_dst",
                "fs_dst_bp_ne_any",
            ),
            ("test_fs_dst_transfer_bytes_exact", "fs_dst_tr_exact"),
            ("test_fs_dst_rotation_bytes_exact", "fs_dst_rot_exact"),
            ("test_fs_dst_withdrawal_bytes_exact", "fs_dst_wd_exact"),
            (
                "test_fs_dst_normalization_bytes_exact",
                "fs_dst_norm_exact",
            ),
            (
                "test_fs_dst_registration_bytes_exact",
                "fs_dst_reg_exact",
            ),
            (
                "test_fs_dst_bulletproofs_bytes_exact",
                "fs_dst_bp_exact",
            ),
            ("test_bulletproofs_num_bits_is_16", "bp_num_bits_16"),
            (
                "test_deserialize_withdrawal_proof_short_sigma_is_none",
                "des_wd_short_none",
            ),
            (
                "test_deserialize_normalization_proof_short_sigma_is_none",
                "des_norm_short_none",
            ),
            (
                "test_deserialize_rotation_proof_short_sigma_is_none",
                "des_rot_empty_none",
            ),
            (
                "test_deserialize_transfer_proof_short_sigma_is_none",
                "des_tr_short_none",
            ),
            (
                "test_deserialize_withdrawal_proof_one_byte_short_is_none",
                "des_wd_1b_short_none",
            ),
            (
                "test_deserialize_normalization_proof_one_byte_short_is_none",
                "des_norm_1b_short_none",
            ),
            (
                "test_deserialize_rotation_proof_one_byte_short_is_none",
                "des_rot_1b_short_none",
            ),
            (
                "test_deserialize_normalization_proof_all_zero_sigma_is_some",
                "des_norm_zero_some",
            ),
            // Phase J — deserializer length-check regression pins.
            (
                "test_deserialize_withdrawal_proof_one_byte_too_long_is_none",
                "des_wd_1b_long_none",
            ),
            (
                "test_deserialize_normalization_proof_one_byte_too_long_is_none",
                "des_norm_1b_long_none",
            ),
            (
                "test_deserialize_rotation_proof_one_byte_too_long_is_none",
                "des_rot_1b_long_none",
            ),
            (
                "test_deserialize_transfer_proof_base_plus_32_is_none",
                "des_tr_p32_none",
            ),
            (
                "test_deserialize_transfer_proof_base_plus_64_is_none",
                "des_tr_p64_none",
            ),
            (
                "test_deserialize_transfer_proof_base_plus_96_is_none",
                "des_tr_p96_none",
            ),
            (
                "test_deserialize_transfer_proof_base_plus_1_is_none",
                "des_tr_p1_none",
            ),
            (
                "test_deserialize_transfer_proof_base_minus_1_is_none",
                "des_tr_m1_none",
            ),
            // Phase K — non-canonical scalar / point rejection pins.
            (
                "test_deserialize_withdrawal_sigma_bad_first_scalar_is_none",
                "des_wd_bad_s0_none",
            ),
            (
                "test_deserialize_withdrawal_sigma_bad_last_scalar_is_none",
                "des_wd_bad_sN_none",
            ),
            (
                "test_deserialize_withdrawal_sigma_bad_first_point_is_none",
                "des_wd_bad_p0_none",
            ),
            (
                "test_deserialize_withdrawal_sigma_bad_last_point_is_none",
                "des_wd_bad_pN_none",
            ),
            (
                "test_deserialize_normalization_sigma_bad_first_scalar_is_none",
                "des_norm_bad_s0_none",
            ),
            (
                "test_deserialize_normalization_sigma_bad_last_scalar_is_none",
                "des_norm_bad_sN_none",
            ),
            (
                "test_deserialize_normalization_sigma_bad_first_point_is_none",
                "des_norm_bad_p0_none",
            ),
            (
                "test_deserialize_normalization_sigma_bad_last_point_is_none",
                "des_norm_bad_pN_none",
            ),
            (
                "test_deserialize_rotation_sigma_bad_first_scalar_is_none",
                "des_rot_bad_s0_none",
            ),
            (
                "test_deserialize_rotation_sigma_bad_last_scalar_is_none",
                "des_rot_bad_sN_none",
            ),
            (
                "test_deserialize_rotation_sigma_bad_first_point_is_none",
                "des_rot_bad_p0_none",
            ),
            (
                "test_deserialize_rotation_sigma_bad_last_point_is_none",
                "des_rot_bad_pN_none",
            ),
            (
                "test_deserialize_transfer_sigma_bad_first_scalar_is_none",
                "des_tr_bad_s0_none",
            ),
            (
                "test_deserialize_transfer_sigma_bad_last_scalar_is_none",
                "des_tr_bad_sN_none",
            ),
            (
                "test_deserialize_transfer_sigma_bad_first_point_is_none",
                "des_tr_bad_p0_none",
            ),
            (
                "test_deserialize_transfer_sigma_bad_last_point_is_none",
                "des_tr_bad_pN_none",
            ),
            (
                "test_deserialize_transfer_sigma_bad_last_auditor_point_is_none",
                "des_tr_bad_aud_pN_none",
            ),
            (
                "test_verify_withdrawal_proof_zero_sigma_aborts",
                "verify_wd_zero_abort",
            ),
            (
                "test_verify_normalization_proof_zero_sigma_aborts",
                "verify_norm_zero_abort",
            ),
            (
                "test_verify_rotation_proof_zero_sigma_aborts",
                "verify_rot_zero_abort",
            ),
            (
                "test_verify_transfer_proof_zero_sigma_aborts",
                "verify_tr_zero_abort",
            ),
            // Phase H — registration-proof negative (all abort 65537).
            (
                "test_verify_registration_rejects_sender_mutation",
                "verify_reg_snd_mut_abort",
            ),
            (
                "test_verify_registration_rejects_contract_mutation",
                "verify_reg_ct_mut_abort",
            ),
            (
                "test_verify_registration_rejects_token_mutation",
                "verify_reg_tok_mut_abort",
            ),
            (
                "test_verify_registration_rejects_chain_id_mutation",
                "verify_reg_cid_mut_abort",
            ),
            (
                "test_verify_registration_rejects_ek_mutation",
                "verify_reg_ek_mut_abort",
            ),
            (
                "test_verify_registration_rejects_commitment_mutation",
                "verify_reg_comm_mut_abort",
            ),
            (
                "test_verify_registration_rejects_response_mutation",
                "verify_reg_resp_mut_abort",
            ),
            // Phase G — Fiat-Shamir transcript prefix pins.
            ("test_fs_prefix_wd_starts_with_dst", "fs_pfx_wd_dst"),
            ("test_fs_prefix_wd_deterministic", "fs_pfx_wd_det"),
            ("test_fs_prefix_wd_chain_id_matters", "fs_pfx_wd_cid"),
            ("test_fs_prefix_wd_sender_matters", "fs_pfx_wd_sender"),
            ("test_fs_prefix_wd_contract_matters", "fs_pfx_wd_contract"),
            ("test_fs_prefix_wd_vs_norm_distinct", "fs_pfx_wd_ne_norm"),
            ("test_fs_prefix_norm_starts_with_dst", "fs_pfx_norm_dst"),
            ("test_fs_prefix_norm_deterministic", "fs_pfx_norm_det"),
            ("test_fs_prefix_norm_chain_id_matters", "fs_pfx_norm_cid"),
            ("test_fs_prefix_norm_sender_matters", "fs_pfx_norm_sender"),
            ("test_fs_prefix_norm_contract_matters", "fs_pfx_norm_contract"),
            ("test_fs_prefix_rot_starts_with_dst", "fs_pfx_rot_dst"),
            ("test_fs_prefix_rot_deterministic", "fs_pfx_rot_det"),
            ("test_fs_prefix_rot_chain_id_matters", "fs_pfx_rot_cid"),
            ("test_fs_prefix_rot_sender_matters", "fs_pfx_rot_sender"),
            ("test_fs_prefix_rot_contract_matters", "fs_pfx_rot_contract"),
            ("test_fs_prefix_rot_vs_norm_distinct", "fs_pfx_rot_ne_norm"),
            ("test_fs_prefix_tr_starts_with_dst", "fs_pfx_tr_dst"),
            ("test_fs_prefix_tr_deterministic", "fs_pfx_tr_det"),
            ("test_fs_prefix_tr_chain_id_matters", "fs_pfx_tr_cid"),
            ("test_fs_prefix_tr_sender_matters", "fs_pfx_tr_sender"),
            ("test_fs_prefix_tr_contract_matters", "fs_pfx_tr_contract"),
            ("test_fs_prefix_tr_auditor_count_matters", "fs_pfx_tr_aud_cnt"),
            ("test_fs_prefix_tr_vs_wd_distinct", "fs_pfx_tr_ne_wd"),
            // Phase G.2 — position-swap pins.
            ("test_fs_prefix_two_test_eks_are_distinct", "fs_pfx_two_eks_ne"),
            ("test_fs_prefix_wd_sender_vs_contract_swap_matters", "fs_pfx_wd_snd_ct_swap"),
            ("test_fs_prefix_wd_amount_chunks_matter", "fs_pfx_wd_chunks_matter"),
            ("test_fs_prefix_norm_cur_vs_new_balance_swap_matters", "fs_pfx_norm_bal_swap"),
            ("test_fs_prefix_rot_cur_vs_new_ek_swap_matters", "fs_pfx_rot_ek_swap"),
            ("test_fs_prefix_rot_cur_vs_new_balance_swap_matters", "fs_pfx_rot_bal_swap"),
            ("test_fs_prefix_tr_sender_vs_recipient_ek_swap_matters", "fs_pfx_tr_ek_swap"),
            ("test_fs_prefix_tr_current_vs_new_balance_swap_matters", "fs_pfx_tr_bal_swap"),
            ("test_fs_prefix_tr_sender_vs_recipient_amount_swap_matters", "fs_pfx_tr_amt_swap"),
            ("test_fs_prefix_tr_auditor_eks_order_matters", "fs_pfx_tr_aud_ord"),
            // Phase N — individual-field coverage for FS prefixes (every
            // remaining field of every prefix helper pinned as `_matters`).
            ("test_fs_prefix_wd_ek_matters", "fs_pfx_wd_ek"),
            ("test_fs_prefix_wd_current_balance_matters", "fs_pfx_wd_cbal"),
            ("test_fs_prefix_norm_ek_matters", "fs_pfx_norm_ek"),
            ("test_fs_prefix_norm_current_balance_matters", "fs_pfx_norm_cbal"),
            ("test_fs_prefix_norm_new_balance_matters", "fs_pfx_norm_nbal"),
            ("test_fs_prefix_rot_current_ek_matters", "fs_pfx_rot_cek"),
            ("test_fs_prefix_rot_new_ek_matters", "fs_pfx_rot_nek"),
            ("test_fs_prefix_rot_current_balance_matters", "fs_pfx_rot_cbal"),
            ("test_fs_prefix_rot_new_balance_matters", "fs_pfx_rot_nbal"),
            ("test_fs_prefix_tr_sender_ek_matters", "fs_pfx_tr_sek"),
            ("test_fs_prefix_tr_recipient_ek_matters", "fs_pfx_tr_rek"),
            ("test_fs_prefix_tr_current_balance_matters", "fs_pfx_tr_cbal"),
            ("test_fs_prefix_tr_new_balance_matters", "fs_pfx_tr_nbal"),
            ("test_fs_prefix_tr_sender_amount_matters", "fs_pfx_tr_samt"),
            ("test_fs_prefix_tr_recipient_amount_matters", "fs_pfx_tr_ramt"),
            ("test_fs_prefix_tr_auditor_ek_content_matters", "fs_pfx_tr_aek_ct"),
            ("test_fs_prefix_tr_auditor_amount_content_matters", "fs_pfx_tr_aam_ct"),
            // Phase O — prover-side field-coverage pins for
            // `prove_registration_deterministic_for_difftest`.
            // Phase Q — golden-vector byte pins for the deterministic
            // registration prover (bit-for-bit stability under transitive
            // algebra). See detailed comment above the test bodies.
            ("test_prove_reg_det_commitment_matches_golden", "prove_reg_c_golden"),
            ("test_prove_reg_det_response_matches_golden", "prove_reg_r_golden"),
            // Phase R.1 — golden-vector byte pin for the registration FS
            // message helper.
            ("test_fs_reg_msg_matches_golden", "fs_reg_msg_golden"),
            // Phase S — transfer FS prefix golden WITH 1 auditor (exercises
            // the auditor-iteration path skipped by Phase R's 0-auditor row).
            ("test_fs_prefix_tr_1aud_matches_golden", "fs_prefix_tr_1aud_golden"),
            // Phase T — boundary / multi-auditor / non-zero-balance
            // fixture goldens that exercise code paths Phase R and S don't
            // hit (high amount chunks, 2nd auditor-loop iteration,
            // non-zero chunk-0 balance).
            ("test_fs_prefix_wd_u64max_matches_golden", "fs_prefix_wd_u64max_golden"),
            ("test_fs_prefix_tr_2aud_matches_golden", "fs_prefix_tr_2aud_golden"),
            ("test_fs_prefix_norm_nonzero_matches_golden", "fs_prefix_norm_nonzero_golden"),
            // Phase U — distinct-chunk withdrawal prefix + non-zero rotation
            // current+new prefix: catch pairwise-swap / reorder bugs that
            // Phase R/T cannot observe because their fixtures are symmetric
            // (Phase R only chunk 0, Phase T all chunks equal; Phase R
            // zero-zero, Phase T current-zero with zero-new asymmetry).
            ("test_fs_prefix_wd_distinct_chunks_matches_golden", "fs_prefix_wd_distinct_chunks_golden"),
            ("test_fs_prefix_rot_nonzero_both_matches_golden", "fs_prefix_rot_nonzero_both_golden"),
            // Phase R — golden-vector byte pins for the four sigma FS prefix
            // helpers (withdrawal, normalization, rotation, transfer). See
            // detailed comment above the test bodies.
            ("test_fs_prefix_wd_matches_golden", "fs_prefix_wd_golden"),
            ("test_fs_prefix_norm_matches_golden", "fs_prefix_norm_golden"),
            ("test_fs_prefix_rot_matches_golden", "fs_prefix_rot_golden"),
            ("test_fs_prefix_tr_matches_golden", "fs_prefix_tr_golden"),
            ("test_prove_reg_det_commitment_length_is_32", "prove_reg_c_len32"),
            ("test_prove_reg_det_response_length_is_32", "prove_reg_r_len32"),
            ("test_prove_reg_det_deterministic_same_inputs", "prove_reg_det_same"),
            ("test_prove_reg_det_commitment_invariant_under_chain_id", "prove_reg_c_inv_cid"),
            ("test_prove_reg_det_commitment_invariant_under_sender", "prove_reg_c_inv_snd"),
            ("test_prove_reg_det_commitment_invariant_under_contract", "prove_reg_c_inv_ct"),
            ("test_prove_reg_det_commitment_invariant_under_token", "prove_reg_c_inv_tk"),
            ("test_prove_reg_det_commitment_invariant_under_ek", "prove_reg_c_inv_ek"),
            ("test_prove_reg_det_commitment_invariant_under_dk", "prove_reg_c_inv_dk"),
            ("test_prove_reg_det_commitment_changes_with_k", "prove_reg_c_k"),
            ("test_prove_reg_det_response_changes_with_chain_id", "prove_reg_r_cid"),
            ("test_prove_reg_det_response_changes_with_sender", "prove_reg_r_snd"),
            ("test_prove_reg_det_response_changes_with_contract", "prove_reg_r_ct"),
            ("test_prove_reg_det_response_changes_with_token", "prove_reg_r_tk"),
            ("test_prove_reg_det_response_changes_with_ek", "prove_reg_r_ek"),
            ("test_prove_reg_det_response_changes_with_dk", "prove_reg_r_dk"),
            ("test_prove_reg_det_response_changes_with_k", "prove_reg_r_k"),
            // Phase P — `verify_registration_proof_for_difftest` non-canonical
            // / wrong-length commitment/response rejection pins. Each test
            // aborts with `ESIGMA_PROTOCOL_VERIFY_FAILED` (65537); mapped to
            // Lean `caSigmaVerifyFailedAbortDesc` (funcIdx := 195).
            ("test_verify_registration_rejects_commitment_len_31", "reg_rej_c_len31"),
            ("test_verify_registration_rejects_commitment_len_33", "reg_rej_c_len33"),
            ("test_verify_registration_rejects_commitment_noncanonical_ff32", "reg_rej_c_ff32"),
            ("test_verify_registration_rejects_response_len_31", "reg_rej_r_len31"),
            ("test_verify_registration_rejects_response_len_33", "reg_rej_r_len33"),
            ("test_verify_registration_rejects_response_noncanonical_ff32", "reg_rej_r_ff32"),
        ] {
            let result = run_test_case(storage, STD_ADDR, MODULE_NAME, function, &[])?;
            cases.push(TestCase {
                function: format!("{} [{}]", function, label),
                type_args: None,
                args: vec![],
                result,
                skip_lean: false,
            });
        }
        Ok(cases)
    }
}
