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

const EXTRA_MOVE: &[&str] = &[
    concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/move/difftest_registration_helpers.move"
    ),
    concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/move/difftest_confidential_proof_helpers.move"
    ),
];

const TEST_SOURCE: &str = r#"
module 0x1::difftest_confidential_proof {
    use 0x1::difftest_registration_helpers;
    use 0x1::difftest_confidential_proof_helpers;
    use aptos_experimental::confidential_proof;
    use aptos_experimental::confidential_balance;
    use aptos_experimental::ristretto255_twisted_elgamal as twisted_elgamal;
    use aptos_std::aptos_hash;
    use aptos_std::ristretto255;
    use aptos_std::ristretto255_bulletproofs;
    use aptos_std::ristretto255_pedersen;
    use std::bcs;
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

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 binding rows: VM `ristretto255::basepoint_compressed()` +
    // `hash_to_point_base()` vs the Lean-side pinned constants
    // `RistrettoEncoding.ristrettoBasepointBytes` +
    // `confidentialAssetHashBaseBytes`. Both rows map to `funcIdx := 40`
    // (`ldTrue`); Lean's constants hold the exact 32 bytes below, so any
    // drift in the Move native (e.g. a regenerated `hash_to_point_base`
    // domain separator, a new Ristretto compression policy, or an
    // accidental recompilation of the Curve25519 native from a different
    // source revision) flips the VM-side equality to `false` and
    // mismatches Lean `ldTrue`. Conversely, a Lean-side edit that drifts
    // the pinned bytes fails Lean's `confidentialAssetHashBaseBytes_size`
    // / `ristrettoBasepointBytes_size` goldens or one of the per-byte
    // `native_decide` pins in `SigmaVerifiersGoldens`. Together these
    // give a two-sided byte-exact binding for the CA Pedersen basepoints.

    /// VM-side `G = ristretto255::basepoint_compressed()` serialized to 32
    /// bytes must equal the RFC-9380-§4.1 Ristretto basepoint constant.
    /// Matches Lean `RistrettoEncoding.ristrettoBasepointBytes`.
    public fun test_ristretto_basepoint_bytes_equals_tier3_golden(): bool {
        let g = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        g == x"e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d76"
    }

    /// VM-side `H = point_compress(hash_to_point_base())` serialized to
    /// 32 bytes must equal the Move-VM golden pinned into Lean at
    /// `RistrettoEncoding.confidentialAssetHashBaseBytes`.
    public fun test_hash_to_point_base_bytes_equals_tier3_golden(): bool {
        let h = ristretto255::hash_to_point_base();
        let hc = ristretto255::point_compress(&h);
        let bytes = ristretto255::compressed_point_to_bytes(hc);
        bytes == x"8c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134"
    }

    /// `G != H` — basepoint and hash-to-point base must not coincide
    /// (catastrophic for Pedersen commitment binding / hiding). Matches
    /// Lean `ristrettoBasepointBytes_ne_confidentialAssetHashBaseBytes`.
    public fun test_ristretto_basepoint_ne_hash_base(): bool {
        let g = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        let h_point = ristretto255::hash_to_point_base();
        let hc = ristretto255::point_compress(&h_point);
        let h = ristretto255::compressed_point_to_bytes(hc);
        g != h
    }

    /// `hash_to_point_base()` is deterministic across calls — same 32
    /// bytes on every invocation. Matches Lean (where
    /// `confidentialAssetHashBaseBytes` is a fixed literal).
    public fun test_hash_to_point_base_deterministic(): bool {
        let h1 = ristretto255::hash_to_point_base();
        let hc1 = ristretto255::point_compress(&h1);
        let b1 = ristretto255::compressed_point_to_bytes(hc1);
        let h2 = ristretto255::hash_to_point_base();
        let hc2 = ristretto255::point_compress(&h2);
        let b2 = ristretto255::compressed_point_to_bytes(hc2);
        b1 == b2
    }

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 Phase W.5: end-to-end algebraic binding for the
    // `new_scalar_from_sha2_512` Fiat–Shamir hash pipeline.
    //
    // Unlike the basepoint-byte rows above (which pin VM-side outputs
    // against literal hex constants chosen ONCE from the VM), these
    // rows pin the VM's `scalar_to_bytes(new_scalar_from_sha2_512(msg))`
    // against a hex constant that was computed INDEPENDENTLY on the
    // Lean side via the fully-computable algebra
    // `scalarToBytes ∘ scalarUniformFrom64Bytes ∘ sha2_512` from
    // `MovementFormal/Experimental/ConfidentialAsset/SigmaVerifiers.lean`
    // and `MovementFormal/AptosStd/Hash/Sha2_512.lean`. Both sides
    // compute the bytes from scratch from the same input string and
    // converge on the same 32-byte output — so a drift in EITHER:
    //
    //   1. The Lean SHA-512 (`MovementFormal.AptosStd.Hash.Sha2_512`).
    //   2. Lean's `scalarUniformFrom64Bytes` / `scalarToBytes`
    //      (`Ristretto255.lean`, `SigmaVerifiers.lean`).
    //   3. The Move VM's `new_scalar_from_sha2_512` native (which
    //      transitively uses `aptos_stdlib::aptos_hash::sha2_512`).
    //   4. The Move VM's `scalar_to_bytes` native (LE serialization
    //      of the canonical `s.val mod ℓ`).
    //   5. The Curve25519 subgroup order constant `ℓ` baked into
    //      either `RistrettoScalar = ZMod ristrettoSubgroupOrder` on
    //      the Lean side or the underlying scalar reduction in
    //      `curve25519-dalek` on the Rust side.
    //
    // would flip one of these rows to `false`, mismatching Lean
    // `ldTrue`. This is a TRUE cross-engine algebraic binding, not a
    // self-equality.

    /// Golden bytes computed independently in Lean via:
    ///   `scalarToBytes (scalarUniformFrom64Bytes (sha2_512 "tier3-binding-sha512-to-scalar".toUTF8))`.
    /// Catches any drift in the SHA-512 → ZMod ℓ pipeline on EITHER
    /// engine.
    public fun test_new_scalar_from_sha2_512_tier3_binding(): bool {
        let s = ristretto255::new_scalar_from_sha2_512(b"tier3-binding-sha512-to-scalar");
        let bytes = ristretto255::scalar_to_bytes(&s);
        bytes == x"e9d087190f5404d1973e8096913a230763b252e2b51a329a16873b29c2d1ee05"
    }

    /// Empty-input variant — exercises SHA-512's empty-message edge
    /// case (NIST FIPS 180-4 reference: SHA-512("") padding produces
    /// a fully-distinct input from any non-empty message). A drift
    /// in the empty-padding logic (either side) flips this row.
    public fun test_new_scalar_from_sha2_512_empty_input_tier3_binding(): bool {
        let s = ristretto255::new_scalar_from_sha2_512(b"");
        let bytes = ristretto255::scalar_to_bytes(&s);
        bytes == x"9ef5a0ea93678eb78d69b33367e129543b0d8520122c42e7dfe9d1977f6c3a0c"
    }

    /// Classic NIST `"abc"` (3-byte) test vector input — exercises
    /// the small-message path (single 1024-bit SHA-512 block, partial
    /// padding). A drift in the message-length encoding bytes (the
    /// final 16 bytes of the SHA-512 padding) flips this row.
    public fun test_new_scalar_from_sha2_512_abc_input_tier3_binding(): bool {
        let s = ristretto255::new_scalar_from_sha2_512(b"abc");
        let bytes = ristretto255::scalar_to_bytes(&s);
        bytes == x"d15dbef29abf1ff29f9cf91c4b75ee0bb1012cb031d9605d684e841df034de0b"
    }

    /// Sigma DST as the SHA-512 input — semantically meaningless (the
    /// DST itself is *prepended* to the FS message, not hashed alone)
    /// but provides another byte-distinct pin. A drift in either
    /// engine's SHA-512 absorb-multiple-blocks loop (DST is 36 bytes,
    /// well within a single block, but exercises a different padding
    /// length) flips this row.
    public fun test_new_scalar_from_sha2_512_dst_input_tier3_binding(): bool {
        let s = ristretto255::new_scalar_from_sha2_512(b"MovementConfidentialAsset/Withdrawal");
        let bytes = ristretto255::scalar_to_bytes(&s);
        bytes == x"774cf23329d4d71114b6126b8f225e93117ab52f6353195014ea70d414993500"
    }

    /// Determinism: the same input always produces the same scalar
    /// bytes (catches stateful prover regressions or RNG leakage).
    public fun test_new_scalar_from_sha2_512_deterministic(): bool {
        let s1 = ristretto255::new_scalar_from_sha2_512(b"determinism-check");
        let s2 = ristretto255::new_scalar_from_sha2_512(b"determinism-check");
        ristretto255::scalar_to_bytes(&s1) == ristretto255::scalar_to_bytes(&s2)
    }

    /// Distinct inputs produce distinct scalars (probabilistic; with
    /// 252-bit collision space and the four chosen inputs it would
    /// take ~2^126 unrelated inputs to find one collision). A
    /// regression that returns `0` or a constant scalar from
    /// `new_scalar_from_sha2_512` flips this row immediately.
    public fun test_new_scalar_from_sha2_512_distinct_inputs(): bool {
        let s1 = ristretto255::new_scalar_from_sha2_512(b"input-1");
        let s2 = ristretto255::new_scalar_from_sha2_512(b"input-2");
        ristretto255::scalar_to_bytes(&s1) != ristretto255::scalar_to_bytes(&s2)
    }

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 Phase W.6: cross-engine algebraic binding for Curve25519
    // scalar arithmetic (`scalar_add`, `scalar_sub`, `scalar_mul`,
    // `scalar_neg`, `scalar_invert`, `scalar_to_bytes`). Each row pins
    // the VM's `scalar_to_bytes(op(...))` against a hex constant
    // computed independently in Lean via the fully-computable
    // `RistrettoScalar = ZMod ristrettoSubgroupOrder` algebra
    // (`MovementFormal/AptosStd/Crypto/Ristretto255.lean` +
    // `SigmaVerifiers.lean`). A drift in EITHER:
    //
    //   1. The Lean `RistrettoScalar` instance / `scalarToBytes` /
    //      `natLeByte` / `byteArrayLeNat` (LE byte serialization of
    //      `ZMod ℓ`).
    //   2. The Lean `ristrettoSubgroupOrder` constant (= ℓ; Curve25519
    //      basepoint subgroup order).
    //   3. The Move VM's `scalar_add` / `scalar_sub` / `scalar_mul` /
    //      `scalar_neg` / `scalar_invert` natives (`curve25519-dalek`
    //      `Scalar` arithmetic mod ℓ).
    //   4. The Move VM's `scalar_to_bytes` (canonical LE serialization
    //      of `s.val mod ℓ`).
    //   5. The on-chain ℓ constant baked into `curve25519-dalek`.
    //
    // would flip one of these rows, mismatching Lean `ldTrue`. These
    // rows together pin the entire scalar-arithmetic surface used by
    // every CA sigma proof RHS computation.

    /// `3 + 5 = 8` (mod ℓ). Smallest non-trivial add. Matches Lean
    /// `scalarToBytes ((3 : RistrettoScalar) + (5 : RistrettoScalar))`.
    public fun test_scalar_add_3_5_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(3);
        let b = ristretto255::new_scalar_from_u64(5);
        ristretto255::scalar_to_bytes(&ristretto255::scalar_add(&a, &b))
            == x"0800000000000000000000000000000000000000000000000000000000000000"
    }

    /// `5 - 3 = 2` (mod ℓ). Positive-result subtraction.
    public fun test_scalar_sub_5_3_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(5);
        let b = ristretto255::new_scalar_from_u64(3);
        ristretto255::scalar_to_bytes(&ristretto255::scalar_sub(&a, &b))
            == x"0200000000000000000000000000000000000000000000000000000000000000"
    }

    /// `3 - 5 = ℓ - 2` (mod ℓ). Underflow path. Catches: signed-vs-unsigned
    /// reduction bug, modular-reduction-direction drift. The expected hex
    /// is the LE encoding of ℓ - 2 = `2^252 + 27742317777372353535851937790883648491`.
    public fun test_scalar_sub_3_5_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(3);
        let b = ristretto255::new_scalar_from_u64(5);
        ristretto255::scalar_to_bytes(&ristretto255::scalar_sub(&a, &b))
            == x"ebd3f55c1a631258d69cf7a2def9de1400000000000000000000000000000010"
    }

    /// `7 * 11 = 77 = 0x4d` (mod ℓ). Smallest non-trivial multiplication
    /// with neither operand 0 / 1.
    public fun test_scalar_mul_7_11_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(7);
        let b = ristretto255::new_scalar_from_u64(11);
        ristretto255::scalar_to_bytes(&ristretto255::scalar_mul(&a, &b))
            == x"4d00000000000000000000000000000000000000000000000000000000000000"
    }

    /// `-1 = ℓ - 1` (mod ℓ). Catches: drift in `scalar_neg`'s "subtract
    /// from order" implementation, off-by-one in ℓ, or wrong endianness.
    public fun test_scalar_neg_one_equals_l_minus_one_tier3_binding(): bool {
        let one = ristretto255::new_scalar_from_u64(1);
        ristretto255::scalar_to_bytes(&ristretto255::scalar_neg(&one))
            == x"ecd3f55c1a631258d69cf7a2def9de1400000000000000000000000000000010"
    }

    /// `-0 = 0` (mod ℓ). Edge case: negating zero must yield zero, not ℓ.
    public fun test_scalar_neg_zero_is_zero_tier3_binding(): bool {
        let zero = ristretto255::new_scalar_from_u64(0);
        ristretto255::scalar_to_bytes(&ristretto255::scalar_neg(&zero))
            == x"0000000000000000000000000000000000000000000000000000000000000000"
    }

    /// `7^(-1)` (mod ℓ). The expected hex is the canonical LE encoding
    /// of the modular inverse of 7 mod ℓ, computed by Lean via
    /// `Mathlib.Data.ZMod.Defs` (which uses Fermat's little theorem
    /// internally for prime ℓ).
    public fun test_scalar_invert_7_tier3_binding(): bool {
        let seven = ristretto255::new_scalar_from_u64(7);
        let inv_opt = ristretto255::scalar_invert(&seven);
        assert!(option::is_some(&inv_opt), error::invalid_argument(99));
        let inv = option::destroy_some(inv_opt);
        ristretto255::scalar_to_bytes(&inv)
            == x"22d5909fba32273143cdfe848dda1f4c92244992244992244992244992244902"
    }

    /// `2 * 2^(-1) = 1` (mod ℓ) — the defining property of the inverse.
    /// Catches a `scalar_invert` regression that returns the right
    /// 32-byte canonical encoding but inverts under the wrong
    /// modulus (e.g. `2^255 - 19` instead of ℓ).
    public fun test_scalar_invert_2_times_2_is_one_tier3_binding(): bool {
        let two = ristretto255::new_scalar_from_u64(2);
        let inv_opt = ristretto255::scalar_invert(&two);
        assert!(option::is_some(&inv_opt), error::invalid_argument(99));
        let inv = option::destroy_some(inv_opt);
        ristretto255::scalar_to_bytes(&ristretto255::scalar_mul(&inv, &two))
            == x"0100000000000000000000000000000000000000000000000000000000000000"
    }

    /// `scalar_invert(0)` MUST return `none` — there is no
    /// multiplicative inverse of zero in `ZMod ℓ`. Catches a regression
    /// that silently returns `0` or any other value.
    public fun test_scalar_invert_zero_is_none_tier3_binding(): bool {
        let zero = ristretto255::new_scalar_from_u64(0);
        let inv_opt = ristretto255::scalar_invert(&zero);
        option::is_none(&inv_opt)
    }

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 Phase W.7: cross-engine algebraic binding for the raw
    // SHA-512 hash function (`aptos_hash::sha2_512`) and the
    // `new_scalar_from_u64` LE-encoding pipeline. Each row pins the
    // VM's output bytes against a hex constant computed independently
    // in Lean via:
    //
    //   - SHA-512 rows: `MovementFormal.AptosStd.Hash.Sha2_512.sha2_512`
    //     (pure-Lean FIPS 180-4 reference implementation, 64-byte raw
    //     output; no scalar reduction, unlike Phase W.5).
    //   - `scalar_from_u64` rows: `(n : RistrettoScalar) |> scalarToBytes`
    //     (Lean computes the canonical LE byte representation of `n`
    //     directly via `natLeByte`).
    //
    // The two Lean SHA-512 goldens against `""` and `"abc"` are
    // additionally pinned against the NIST FIPS 180-4 §C reference
    // vectors — so this row simultaneously catches: (i) any drift in
    // Lean's SHA-512 implementation, (ii) any drift in libsodium's
    // SHA-512 (the underlying VM impl), (iii) any drift in the Move
    // `aptos_hash::sha2_512` Move-source wrapper. These are the
    // foundational bindings that Phase W.5's `new_scalar_from_sha2_512`
    // implicitly depends on; W.7 surfaces the dependency directly.

    /// SHA-512("") — NIST FIPS 180-4 §C.2 reference vector.
    public fun test_sha2_512_empty_input_tier3_binding(): bool {
        aptos_hash::sha2_512(b"")
            == x"cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
    }

    /// SHA-512("abc") — NIST FIPS 180-4 §C.1 reference vector.
    public fun test_sha2_512_abc_input_tier3_binding(): bool {
        aptos_hash::sha2_512(b"abc")
            == x"ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
    }

    /// SHA-512("movement") — small custom input.
    public fun test_sha2_512_movement_input_tier3_binding(): bool {
        aptos_hash::sha2_512(b"movement")
            == x"850de3b61448982c85721a1a84787734ff6225fa63fe8287ff30b65a0ca243067f4f664bf74611025b90979a98aa81a0c445f1c40e6cf495df93d6b70f7e213c"
    }

    /// SHA-512 of 112 'a' bytes — exercises the boundary case where
    /// the message length is exactly `(2 * 1024 / 8) - 16 = 112` bytes
    /// (i.e. the padding byte and the 16-byte length field exactly
    /// fill the second SHA-512 block, with no extra zero bytes in
    /// the padding region).
    public fun test_sha2_512_112_a_bytes_tier3_binding(): bool {
        let buf = vector::empty<u8>();
        let i = 0;
        while (i < 112) { buf.push_back(b"a"[0]); i = i + 1; };
        aptos_hash::sha2_512(buf)
            == x"c01d080efd492776a1c43bd23dd99d0a2e626d481e16782e75d54c2503b5dc32bd05f0f1ba33e568b88fd2d970929b719ecbb152f58f130a407c8830604b70ca"
    }

    /// SHA-512 of 128 'b' bytes — exercises the case where the message
    /// length is exactly one full SHA-512 block (1024 bits = 128 bytes),
    /// forcing padding to span an entirely new third block.
    public fun test_sha2_512_128_b_bytes_tier3_binding(): bool {
        let buf = vector::empty<u8>();
        let i = 0;
        while (i < 128) { buf.push_back(b"b"[0]); i = i + 1; };
        aptos_hash::sha2_512(buf)
            == x"fef679bea370b59c774dc497fa4435b9bd0e1d7f54dc24b4d0a55c16190d6e17da48c744ce7475b13565f533aab813430258db6734fb6acabc8549f9c35a7d1a"
    }

    /// SHA-512 output is always 64 bytes regardless of input length.
    public fun test_sha2_512_output_length_is_64(): bool {
        aptos_hash::sha2_512(b"any input").length() == 64
    }

    /// SHA-512 of two distinct inputs MUST differ (avalanche / no-fixed-point).
    public fun test_sha2_512_distinct_inputs_distinct_outputs(): bool {
        aptos_hash::sha2_512(b"input-A") != aptos_hash::sha2_512(b"input-B")
    }

    // ───────────────────────────────────────────────────────────────────────
    // `new_scalar_from_u64` LE-encoding cross-engine binding.

    /// `scalar_to_bytes(new_scalar_from_u64(0)) = [0; 32]`.
    public fun test_scalar_from_u64_0_tier3_binding(): bool {
        let s = ristretto255::new_scalar_from_u64(0);
        ristretto255::scalar_to_bytes(&s)
            == x"0000000000000000000000000000000000000000000000000000000000000000"
    }

    /// `scalar_to_bytes(new_scalar_from_u64(1)) = 01 [0; 31]`.
    public fun test_scalar_from_u64_1_tier3_binding(): bool {
        let s = ristretto255::new_scalar_from_u64(1);
        ristretto255::scalar_to_bytes(&s)
            == x"0100000000000000000000000000000000000000000000000000000000000000"
    }

    /// `scalar_to_bytes(new_scalar_from_u64(42)) = 2a [0; 31]`.
    public fun test_scalar_from_u64_42_tier3_binding(): bool {
        let s = ristretto255::new_scalar_from_u64(42);
        ristretto255::scalar_to_bytes(&s)
            == x"2a00000000000000000000000000000000000000000000000000000000000000"
    }

    /// `scalar_to_bytes(new_scalar_from_u64(2^32 - 1))` — exercises
    /// the LE-byte boundary at offset 4 (where bytes transition from
    /// non-zero to zero).
    public fun test_scalar_from_u64_max_u32_tier3_binding(): bool {
        let s = ristretto255::new_scalar_from_u64(4294967295);
        ristretto255::scalar_to_bytes(&s)
            == x"ffffffff00000000000000000000000000000000000000000000000000000000"
    }

    /// `scalar_to_bytes(new_scalar_from_u64(2^64 - 1))` — exercises
    /// the LE-byte boundary at offset 8 (the upper bound of `u64`
    /// encoding before any modular reduction kicks in; ℓ ≫ 2^64).
    public fun test_scalar_from_u64_max_u64_tier3_binding(): bool {
        let s = ristretto255::new_scalar_from_u64(18446744073709551615);
        ristretto255::scalar_to_bytes(&s)
            == x"ffffffffffffffff000000000000000000000000000000000000000000000000"
    }

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 Phase W.8: `msm_gamma_N` Fiat-Shamir composition
    // cross-engine binding (SHA-512 of `scalar_to_bytes(ρ) ++ [i]` for
    // γ₁, or `scalar_to_bytes(ρ) ++ [i, j]` for γ₂, reduced mod ℓ).
    // This is the EXACT composition used by every CA sigma-proof
    // verifier's Fiat-Shamir challenge computation in
    // `confidential_proof::fiat_shamir_*_sigma_proof_challenge`. Pins
    // the composed pipeline (`ByteArray.push` + `sha2_512` + scalar
    // reduction) across both engines on 3 γ₁ and 2 γ₂ inputs.
    //
    // Plus: scalar algebraic identity rows (additive cancellation,
    // distributivity, multi-step compositions). Each identity LHS
    // and RHS are computed independently and pinned to the same hex
    // literal — catches a `scalar_add` ↔ `scalar_mul` swap or a
    // `scalar_sub` sign error that the W.6 per-op pins would miss.

    /// `γ₁(ρ=42, i=0) = scalar_from_sha2_512(scalar_to_bytes(42) ++ [0])`.
    public fun test_msm_gamma_1_42_0_tier3_binding(): bool {
        let rho = ristretto255::new_scalar_from_u64(42);
        let rho_bytes = ristretto255::scalar_to_bytes(&rho);
        rho_bytes.push_back(0u8);
        let g = ristretto255::new_scalar_from_sha2_512(rho_bytes);
        ristretto255::scalar_to_bytes(&g)
            == x"5280c18753026fb427e071f0173e69d037513dc6ecff8d7cbb9461fb867a3104"
    }

    /// `γ₁(ρ=42, i=1)` — same ρ, different index. Catches a regression
    /// that ignores the index byte (e.g. `sha2_512` called on only
    /// `scalar_to_bytes(ρ)` without the index suffix).
    public fun test_msm_gamma_1_42_1_tier3_binding(): bool {
        let rho = ristretto255::new_scalar_from_u64(42);
        let rho_bytes = ristretto255::scalar_to_bytes(&rho);
        rho_bytes.push_back(1u8);
        let g = ristretto255::new_scalar_from_sha2_512(rho_bytes);
        ristretto255::scalar_to_bytes(&g)
            == x"5b185dabdee1c5f9d3fd82f31131f8fcbaa51cd01a19927dfa967e76009a6c08"
    }

    /// `γ₁(ρ=1, i=3)` — small ρ, non-trivial index.
    public fun test_msm_gamma_1_1_3_tier3_binding(): bool {
        let rho = ristretto255::new_scalar_from_u64(1);
        let rho_bytes = ristretto255::scalar_to_bytes(&rho);
        rho_bytes.push_back(3u8);
        let g = ristretto255::new_scalar_from_sha2_512(rho_bytes);
        ristretto255::scalar_to_bytes(&g)
            == x"c6ab5381473988a744949fbef51fde049efc7002c8ce231a6611f5dfd3c8da02"
    }

    /// `γ₂(ρ=42, i=0, j=5) = scalar_from_sha2_512(scalar_to_bytes(42) ++ [0, 5])`.
    /// Two-index variant used by transfer sigma proofs for auditor/chunk
    /// indexing.
    public fun test_msm_gamma_2_42_0_5_tier3_binding(): bool {
        let rho = ristretto255::new_scalar_from_u64(42);
        let rho_bytes = ristretto255::scalar_to_bytes(&rho);
        rho_bytes.push_back(0u8);
        rho_bytes.push_back(5u8);
        let g = ristretto255::new_scalar_from_sha2_512(rho_bytes);
        ristretto255::scalar_to_bytes(&g)
            == x"e29ce825ec71ad990624e8cfb90cf8567cd4ede979bedb1ba6427ac5fb4f1309"
    }

    /// `γ₂(ρ=100, i=7, j=11)` — distinct ρ / i / j to catch a
    /// regression where byte ordering `[i, j]` vs `[j, i]` would
    /// silently flip γ₂ without failing single-index tests.
    public fun test_msm_gamma_2_100_7_11_tier3_binding(): bool {
        let rho = ristretto255::new_scalar_from_u64(100);
        let rho_bytes = ristretto255::scalar_to_bytes(&rho);
        rho_bytes.push_back(7u8);
        rho_bytes.push_back(11u8);
        let g = ristretto255::new_scalar_from_sha2_512(rho_bytes);
        ristretto255::scalar_to_bytes(&g)
            == x"fc72108cfbb138d265deb1308a336be95276501ae8d34dc2d8883ae557d9a406"
    }

    // ───────────────────────────────────────────────────────────────────────
    // Scalar algebraic identity rows.

    /// `(100 + 200) - 200 = 100 = 0x64`. Additive cancellation.
    public fun test_scalar_add_sub_cancel_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(100);
        let b = ristretto255::new_scalar_from_u64(200);
        let r = ristretto255::scalar_sub(&ristretto255::scalar_add(&a, &b), &b);
        ristretto255::scalar_to_bytes(&r)
            == x"6400000000000000000000000000000000000000000000000000000000000000"
    }

    /// `(3 + 5) * (3 - 5) = 3² - 5² = 9 - 25 = -16 = ℓ - 16`.
    /// Squared-difference identity; catches a sign-flip regression in
    /// `scalar_sub` that the single-step W.6 rows wouldn't catch.
    public fun test_scalar_squared_difference_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(3);
        let b = ristretto255::new_scalar_from_u64(5);
        let sum = ristretto255::scalar_add(&a, &b);
        let diff = ristretto255::scalar_sub(&a, &b);
        let r = ristretto255::scalar_mul(&sum, &diff);
        ristretto255::scalar_to_bytes(&r)
            == x"ddd3f55c1a631258d69cf7a2def9de1400000000000000000000000000000010"
    }

    /// `7 * 11 * 13 = 1001 = 0x3e9`. Associativity / 3-operand
    /// multiplication.
    public fun test_scalar_mul_assoc_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(7);
        let b = ristretto255::new_scalar_from_u64(11);
        let c = ristretto255::new_scalar_from_u64(13);
        let r = ristretto255::scalar_mul(&ristretto255::scalar_mul(&a, &b), &c);
        ristretto255::scalar_to_bytes(&r)
            == x"e903000000000000000000000000000000000000000000000000000000000000"
    }

    /// `(5 + 7) * 13 = 5*13 + 7*13 = 156 = 0x9c`. Left distributivity
    /// sanity check. The LHS bytes are pinned; the companion
    /// `test_scalar_distributivity_rhs_tier3_binding` pins the same
    /// bytes computed via the RHS factored form.
    public fun test_scalar_distributivity_lhs_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(5);
        let b = ristretto255::new_scalar_from_u64(7);
        let c = ristretto255::new_scalar_from_u64(13);
        let r = ristretto255::scalar_mul(&ristretto255::scalar_add(&a, &b), &c);
        ristretto255::scalar_to_bytes(&r)
            == x"9c00000000000000000000000000000000000000000000000000000000000000"
    }

    /// `5*13 + 7*13 = 156 = 0x9c`. RHS factored form. If this row and
    /// `..._lhs` both pass AND produce the same bytes, distributivity
    /// holds byte-for-byte on the VM.
    public fun test_scalar_distributivity_rhs_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(5);
        let b = ristretto255::new_scalar_from_u64(7);
        let c = ristretto255::new_scalar_from_u64(13);
        let r = ristretto255::scalar_add(
            &ristretto255::scalar_mul(&a, &c),
            &ristretto255::scalar_mul(&b, &c),
        );
        ristretto255::scalar_to_bytes(&r)
            == x"9c00000000000000000000000000000000000000000000000000000000000000"
    }

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 Phase W.9: scalar inversion identity rows +
    // `prepend_domain_context` cross-engine binding.
    //
    // Inversion identity rows pin LHS / RHS of group-theoretic laws
    // over `ℤ/ℓℤ^*`:
    //   (a⁻¹)⁻¹ = a  (involutive inverse)
    //   (a·b)⁻¹ = a⁻¹·b⁻¹  (inverse of product)
    //   (-a)⁻¹ = -(a⁻¹)  (inverse commutes with negation)
    //   a³ - b³ = (a-b)(a² + ab + b²)  (cube-difference identity)
    //   a · (-a) = -a²  (neg/mul interaction — pinned at a=3)
    // Each row pins the SAME 32-byte hex on both engines.
    //
    // `prepend_domain_context` rows pin the EXACT byte layout used by
    // every CA sigma-proof FS transcript:
    //   prepend_domain_context(body, chain_id, sender, contract) =
    //       [chain_id] ++ bcs(sender) ++ bcs(contract) ++ body
    // VM: composes via `std::bcs::to_bytes` + `vector::append`.
    // Lean: computes via `SigmaVerifiers.prependDomainContext`
    // directly on `Address32` (which stores the 32-byte BCS form
    // verbatim). A regression that swaps `sender ↔ contract`, forgets
    // the `chain_id` prefix, or mis-orders the concat flips one of
    // these rows.

    /// Helper: `bcs::to_bytes(&sender) ++ bcs::to_bytes(&contract)` +
    /// `chain_id` byte prepended + optional body suffix. Mirrors
    /// `confidential_proof::prepend_domain_context` exactly (private
    /// there; reconstructed here from public `std::bcs` primitives).
    fun pdc_compose(chain_id: u8, sender: address, contract_address: address, body: vector<u8>): vector<u8> {
        let r = vector::singleton(chain_id);
        r.append(std::bcs::to_bytes(&sender));
        r.append(std::bcs::to_bytes(&contract_address));
        r.append(body);
        r
    }

    // ───────────────────────────────────────────────────────────────────────
    // Inversion / multiplicative identities.

    /// `(7⁻¹)⁻¹ = 7`. Double inversion is the identity on `ℤ/ℓℤ^*`.
    public fun test_scalar_double_inverse_7_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(7);
        let ai = option::destroy_some(ristretto255::scalar_invert(&a));
        let aii = option::destroy_some(ristretto255::scalar_invert(&ai));
        ristretto255::scalar_to_bytes(&aii)
            == x"0700000000000000000000000000000000000000000000000000000000000000"
    }

    /// `(42⁻¹)⁻¹ = 42`. Same invariant, different scalar.
    public fun test_scalar_double_inverse_42_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(42);
        let ai = option::destroy_some(ristretto255::scalar_invert(&a));
        let aii = option::destroy_some(ristretto255::scalar_invert(&ai));
        ristretto255::scalar_to_bytes(&aii)
            == x"2a00000000000000000000000000000000000000000000000000000000000000"
    }

    /// `(1001⁻¹)⁻¹ = 1001 = 0x3e9`.
    public fun test_scalar_double_inverse_1001_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(1001);
        let ai = option::destroy_some(ristretto255::scalar_invert(&a));
        let aii = option::destroy_some(ristretto255::scalar_invert(&ai));
        ristretto255::scalar_to_bytes(&aii)
            == x"e903000000000000000000000000000000000000000000000000000000000000"
    }

    /// `(7·11)⁻¹` — LHS of `(ab)⁻¹ = a⁻¹ b⁻¹`.
    public fun test_scalar_inv_of_product_lhs_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(7);
        let b = ristretto255::new_scalar_from_u64(11);
        let ab = ristretto255::scalar_mul(&a, &b);
        let r = option::destroy_some(ristretto255::scalar_invert(&ab));
        ristretto255::scalar_to_bytes(&r)
            == x"10e41ee44dc6c74b92dc291fcc2708fb981ad83ba606f68ea981bd636a60ef08"
    }

    /// `7⁻¹ · 11⁻¹` — RHS of `(ab)⁻¹ = a⁻¹ b⁻¹`. Must match LHS
    /// bytes exactly to pin the identity at the byte level on the VM.
    public fun test_scalar_inv_of_product_rhs_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(7);
        let b = ristretto255::new_scalar_from_u64(11);
        let ai = option::destroy_some(ristretto255::scalar_invert(&a));
        let bi = option::destroy_some(ristretto255::scalar_invert(&b));
        let r = ristretto255::scalar_mul(&ai, &bi);
        ristretto255::scalar_to_bytes(&r)
            == x"10e41ee44dc6c74b92dc291fcc2708fb981ad83ba606f68ea981bd636a60ef08"
    }

    /// `(-7)⁻¹` — LHS of `(-a)⁻¹ = -(a⁻¹)`.
    public fun test_scalar_inv_of_neg_lhs_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(7);
        let neg_a = ristretto255::scalar_neg(&a);
        let r = option::destroy_some(ristretto255::scalar_invert(&neg_a));
        ristretto255::scalar_to_bytes(&r)
            == x"cbfe64bd5f30eb2693cff81d511fbfc86ddbb66ddbb66ddbb66ddbb66ddbb60d"
    }

    /// `-(7⁻¹)` — RHS of `(-a)⁻¹ = -(a⁻¹)`. Must equal LHS bytes.
    public fun test_scalar_inv_of_neg_rhs_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(7);
        let ai = option::destroy_some(ristretto255::scalar_invert(&a));
        let r = ristretto255::scalar_neg(&ai);
        ristretto255::scalar_to_bytes(&r)
            == x"cbfe64bd5f30eb2693cff81d511fbfc86ddbb66ddbb66ddbb66ddbb66ddbb60d"
    }

    /// `3³ - 2³ = 27 - 8 = 19 = 0x13`. Direct cube-difference.
    public fun test_scalar_cube_diff_direct_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(3);
        let b = ristretto255::new_scalar_from_u64(2);
        let a3 = ristretto255::scalar_mul(&ristretto255::scalar_mul(&a, &a), &a);
        let b3 = ristretto255::scalar_mul(&ristretto255::scalar_mul(&b, &b), &b);
        let r = ristretto255::scalar_sub(&a3, &b3);
        ristretto255::scalar_to_bytes(&r)
            == x"1300000000000000000000000000000000000000000000000000000000000000"
    }

    /// `(3 - 2)(3² + 3·2 + 2²) = 1 · 19 = 19 = 0x13`. Factored
    /// cube-difference identity. Must equal the direct form byte-for-byte.
    public fun test_scalar_cube_diff_factored_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(3);
        let b = ristretto255::new_scalar_from_u64(2);
        let a2 = ristretto255::scalar_mul(&a, &a);
        let b2 = ristretto255::scalar_mul(&b, &b);
        let ab = ristretto255::scalar_mul(&a, &b);
        let trinomial = ristretto255::scalar_add(
            &ristretto255::scalar_add(&a2, &ab),
            &b2,
        );
        let diff = ristretto255::scalar_sub(&a, &b);
        let r = ristretto255::scalar_mul(&diff, &trinomial);
        ristretto255::scalar_to_bytes(&r)
            == x"1300000000000000000000000000000000000000000000000000000000000000"
    }

    /// `3 · (-3) = -9 = ℓ - 9`. Pins the `neg / mul` interaction at
    /// the byte level; if `scalar_neg` silently returned `a` instead
    /// of `-a`, this row would fail (would produce `+9` bytes).
    public fun test_scalar_mul_neg_identity_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(3);
        let neg_a = ristretto255::scalar_neg(&a);
        let r = ristretto255::scalar_mul(&a, &neg_a);
        ristretto255::scalar_to_bytes(&r)
            == x"e4d3f55c1a631258d69cf7a2def9de1400000000000000000000000000000010"
    }

    // ───────────────────────────────────────────────────────────────────────
    // `prepend_domain_context` byte-layout cross-engine binding.

    /// `prepend_domain_context(body=[], chain_id=9, sender=@0xA, contract=@0xB)`
    /// = 65 bytes = [0x09] ++ 32-byte sender (31 zero + 0x0a)
    ///              ++ 32-byte contract (31 zero + 0x0b) ++ [].
    public fun test_prepend_domain_context_empty_body_tier3_binding(): bool {
        pdc_compose(9u8, @0xA, @0xB, vector::empty<u8>())
            == x"09000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000b"
    }

    /// Same but with `body = b"suffix"` — pins the suffix-append
    /// ordering (body goes LAST, not between chain_id and sender).
    public fun test_prepend_domain_context_with_suffix_tier3_binding(): bool {
        pdc_compose(9u8, @0xA, @0xB, b"suffix")
            == x"09000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000b737566666978"
    }

    /// `chain_id = 0xff` — pins the full `u8` range of the chain_id
    /// prefix byte. Catches a regression that mis-casts `u8` to an
    /// `i8` equivalent and flips high-bit.
    public fun test_prepend_domain_context_max_chain_id_tier3_binding(): bool {
        pdc_compose(255u8, @0xA, @0xB, vector::empty<u8>())
            == x"ff000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000b"
    }

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 Phase W.10: FULL FS-prefix cross-engine byte equality via
    // SHA-512 digest pin. This is the HOLY GRAIL of Tier 3 —
    // end-to-end cross-engine byte equality of the ENTIRE Fiat–Shamir
    // transcript prefix for ALL four sigma protocols (withdrawal,
    // normalization, rotation, transfer) on a specific fixture.
    //
    // VM side: computes the full FS prefix (837 / 1224 / 1251 / 1635
    // bytes) via `difftest_confidential_proof_helpers::*_fs_prefix`
    // — which composes `G || H || ek || amount || balance … ||
    // prepend_domain_context || DST_prepend` exactly as the
    // production `confidential_proof.move` does, using only public
    // APIs (no Move-source edits). The VM then hashes the prefix
    // with `aptos_hash::sha2_512` and compares to a 64-byte golden.
    //
    // Lean side: constructs the same byte layout purely from the
    // formal model (`SigmaVerifiers.prependDomainContext`, 
    // `scalarToBytes`, `balanceToBytes` fixtures, DSTs, basepoint
    // bytes, H bytes) and hashes with `Sha2_512.sha2_512`, pinning
    // the exact same 64-byte golden.
    //
    // If the two 837/1224/1251/1635-byte byte sequences differ
    // anywhere — a transposed field, a missing domain-context byte,
    // a wrong ek encoding, an off-by-one in scalar bytes, or a
    // different H base — the SHA-512 digests diverge and exactly
    // one engine fails. This closes the FS-prefix binding loop
    // that Phases R + W.4–W.9 built up toward.
    //
    // Fixture (common to all four):
    //   chain_id  = 9
    //   sender    = @0xA   (32-byte BCS: 31 zero || 0x0a)
    //   contract  = @0xB   (32-byte BCS: 31 zero || 0x0b)
    //   ek(_sender) = basepoint_ek      (G-compressed)
    //   recipient_ek / new_ek = hash_base_ek  (H-compressed)
    //   amount (withdrawal) = 42 (chunk 0 = 42, rest zero)
    //   current_balance / new_balance = zero actual balance
    //   sender_amount / recipient_amount = zero pending balance
    //   auditor_eks / auditor_amounts = empty (0 auditors)

    /// Withdrawal FS prefix (837 B) SHA-512 golden. Pins the full
    /// transcript byte-for-byte across engines.
    public fun test_sha2_512_of_wd_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(42u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        aptos_hash::sha2_512(prefix)
            == x"0f7b8e28e41255ff324dac523a6a24fee36dee1b468eab1ef56b04665594248792d1c1cc7fc9381383f55391a7ac6813a47a0bb65ddc1d2b92f498f2d91611c6"
    }

    /// Normalization FS prefix (1224 B) SHA-512 golden.
    public fun test_sha2_512_of_norm_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::normalization_fs_prefix(
            9u8, @0xA, @0xB, &ek, &current_balance, &new_balance);
        aptos_hash::sha2_512(prefix)
            == x"a31bedb9259357f236dbeba439b6d8a335b565050f4b3389db16fc22362cb6c1115080cf41dbda22228fca943d5d7686efb8cc705b38b382bf195223469b4092"
    }

    /// Rotation FS prefix (1251 B) SHA-512 golden.
    public fun test_sha2_512_of_rot_fs_prefix_matches_golden_tier3_binding(): bool {
        let current_ek = basepoint_ek_for_fs_tests();
        let new_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::rotation_fs_prefix(
            9u8, @0xA, @0xB, &current_ek, &new_ek, &current_balance, &new_balance);
        aptos_hash::sha2_512(prefix)
            == x"460a6d70273e373e12f2e4dda9a78314e2204767422643d8c3a9aaeeafc3ed7abc59f1cc6a7f3ec2198ab4d1f782c64d7879b5a2735647229d0b53b111f2f427"
    }

    /// Transfer FS prefix (1635 B, 0 auditors) SHA-512 golden.
    public fun test_sha2_512_of_tr_fs_prefix_matches_golden_tier3_binding(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let prefix = difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        aptos_hash::sha2_512(prefix)
            == x"167b5d2dcb79770b2ade6f9638b5fe6cf6ebc59cba1b715faaa1d1410cd5be58234ee4583db04c8da5db816bf3e9e4d0943a9f2d1bb7a04d096e2a8adb377ffb"
    }

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 Phase W.11 — multi-fixture FS-prefix SHA-512 cross-engine
    // byte equality. W.10 bound ONE reference fixture (chain_id=9,
    // @0xA/@0xB, amount=42, ek=G). A symmetric bug that hard-codes the
    // reference fixture on either engine would slip through — every
    // W.10 row would still pass. W.11 adds fixture VARIANTS, varying
    // each independent input axis:
    //
    //   V2 (withdrawal): chain_id=0xff (max u8), amount=1, ek=G
    //        → exercises high-bit chain_id handling + non-42 amount
    //   V3 (withdrawal): chain_id=1, amount=65535 (u16 max, single chunk),
    //        ek=G → exercises chunk-boundary arithmetic
    //   V4 (normalization): SWAPPED addresses (sender=@0xB, contract=@0xA),
    //        chain_id=9 → exercises sender/contract argument-order bug
    //   V5 (rotation): SWAPPED eks (current_ek=H, new_ek=G), chain_id=0x42
    //        → exercises current_ek/new_ek argument-order bug
    //
    // Each variant reuses `difftest_confidential_proof_helpers::*_fs_prefix`
    // so the VM-side composition logic is identical to W.10; only the
    // inputs change. On the Lean side
    // (`SigmaVerifiersGoldens.withdrawalFsPrefixBytesV{2,3}`,
    // `normalizationFsPrefixBytesV2`, `rotationFsPrefixBytesV2`) the
    // fixtures are independently reconstructed from cross-bound
    // primitives. Both engines pin to the SAME 64-byte SHA-512 golden.

    /// Withdrawal V2: chain_id=0xff, amount=1, ek=G.
    public fun test_sha2_512_of_wd_v2_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(1u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            0xffu8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        aptos_hash::sha2_512(prefix)
            == x"8c2fec701bc30c3b36eb70ec29248518222382d4f6259f07c236d49721ae63267b5264c4a9452f301e907b4e5f256e91137e8d3f8511444d206fbf86fee1fa86"
    }

    /// Withdrawal V3: chain_id=1, amount=65535 (u16 max, single chunk), ek=G.
    public fun test_sha2_512_of_wd_v3_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(65535u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            1u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        aptos_hash::sha2_512(prefix)
            == x"d79165a8db29de586343f4495aab62201551b9d4456576e7c026ac2634caa7545d44bd78f2d01467136918cc27e79a8b03f0975ec458c6fbebdb3c96b035f0af"
    }

    /// Normalization V2: SWAPPED addresses (sender=@0xB, contract=@0xA),
    /// chain_id=9, ek=G.
    public fun test_sha2_512_of_norm_v2_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::normalization_fs_prefix(
            9u8, @0xB, @0xA, &ek, &current_balance, &new_balance);
        aptos_hash::sha2_512(prefix)
            == x"6ed2a396c13cec24a572e53c6052bc3324e09541ecf719c7aa91025925ab2d2d4e6276fb4c53204ad0324c801e9c31347c9b1dc478d67216ea67dfaf5e150342"
    }

    /// Rotation V2: SWAPPED eks (current_ek=H, new_ek=G), chain_id=0x42,
    /// sender=@0xA, contract=@0xB.
    public fun test_sha2_512_of_rot_v2_fs_prefix_matches_golden_tier3_binding(): bool {
        let current_ek = hash_base_ek_for_fs_tests();
        let new_ek = basepoint_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0x42u8, @0xA, @0xB, &current_ek, &new_ek, &current_balance, &new_balance);
        aptos_hash::sha2_512(prefix)
            == x"135a97e8533d150fc58ae1e184d29aa210eb212c0788b2a306778674209d75b32c852952bdfc568956866315080714157d9cfa33b8da938493e7d942d4a8d97b"
    }

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 Phase W.12 — Fiat–Shamir CHALLENGE SCALAR cross-engine binding
    // on top of full FS prefix. Phases W.10 / W.11 bind the byte-level
    // SHA-512 digest of the FS prefix. But the operationally critical
    // value — the scalar consumed by every verifier's MSM equation — is
    // the reduction of that 64-byte digest modulo ℓ (Ristretto subgroup
    // order), serialized as 32 LE bytes. VM pipeline:
    //   `scalar_to_bytes(&new_scalar_from_sha2_512(prefix))`
    // Lean pipeline:
    //   `scalarToBytes ((scalarUniformFrom64Bytes (sha2_512 prefix)).getD 0)`
    //
    // Phase W.5 pinned this pipeline on short raw strings (`""`, `"abc"`,
    // etc.). Phase W.12 pins it on the FULL multi-hundred-byte FS prefix
    // sequences from W.10 / W.11, catching a regression that only
    // manifests on prefix-shaped inputs (e.g., a branch inside
    // `new_scalar_from_sha2_512` that short-circuits under length < 64
    // bytes, or a lazily-evaluated reduction that diverges on boundary-
    // aligned SHA-512 outputs from the specific FS-prefix byte
    // distribution).

    /// W.12: withdrawal reference fixture → FS challenge scalar golden.
    public fun test_fs_challenge_scalar_wd_ref_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(42u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"fc04c635f5450480592689d99b4ad64f1e17e65d298acda4ac9bc02bc5d47d0f"
    }

    /// W.12: normalization reference fixture → FS challenge scalar golden.
    public fun test_fs_challenge_scalar_norm_ref_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::normalization_fs_prefix(
            9u8, @0xA, @0xB, &ek, &current_balance, &new_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"7dd2eb1b1f30781aa6324592344e57033fc8a8e60c3bf0a75f1306f8e861750f"
    }

    /// W.12: rotation reference fixture → FS challenge scalar golden.
    public fun test_fs_challenge_scalar_rot_ref_tier3_binding(): bool {
        let current_ek = basepoint_ek_for_fs_tests();
        let new_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::rotation_fs_prefix(
            9u8, @0xA, @0xB, &current_ek, &new_ek, &current_balance, &new_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"d34f838e9cb121eeef499e4960f9eb4bac7a72f049bd9d58b9248a5b5a325b07"
    }

    /// W.12: transfer (0 auditors) reference fixture → FS challenge scalar golden.
    public fun test_fs_challenge_scalar_tr_ref_tier3_binding(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let prefix = difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"78a5e80928543d11ba9efc4e03b97c15cad0a04888ec83fcf1ce3c634fe40401"
    }

    /// W.12: withdrawal V2 → FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_v2_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(1u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            0xffu8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"5aa404e21fd22d5a768c46e520e46e11994189233dc18f4148e9248807490e0f"
    }

    /// W.12: withdrawal V3 → FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_v3_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(65535u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            1u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"5fec3789e7e3b23a45d1d52ea49ba20071048bd7be27878f1092b407399a7f09"
    }

    /// W.12: normalization V2 (swapped addresses) → FS challenge scalar.
    public fun test_fs_challenge_scalar_norm_v2_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::normalization_fs_prefix(
            9u8, @0xB, @0xA, &ek, &current_balance, &new_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"084cac35fa438d83aeca7714e03ff7b57364b74d30187424813798c5eb9add07"
    }

    /// W.12: rotation V2 (swapped eks) → FS challenge scalar.
    public fun test_fs_challenge_scalar_rot_v2_tier3_binding(): bool {
        let current_ek = hash_base_ek_for_fs_tests();
        let new_ek = basepoint_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0x42u8, @0xA, @0xB, &current_ek, &new_ek, &current_balance, &new_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"f72c5aa123e56baafc310a9ca8112173609ae7154fb0d600e924194f52027e0c"
    }

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 Phase W.13 — TRANSFER AUDITOR-COUNT FS-prefix + challenge-scalar
    // cross-engine binding. Phases W.10 / W.11 / W.12 all use 0 auditors on
    // every transfer row. But the transfer FS prefix's auditor loop (per-
    // auditor ek block BEFORE current_balance + per-auditor amount-D block
    // BEFORE sender_amount D block) is a primary regression-prone surface:
    // off-by-one, reversed order, skipped slots, or eks-placed-in-wrong-
    // block would pass every W.10-W.12 row. W.13 pins the FS prefix SHA-512
    // AND the downstream challenge scalar for 1, 2, 3 auditors and a 2-
    // auditor variant with SWAPPED auditor-ek order.

    fun auditor_eks_vec_1G(): vector<twisted_elgamal::CompressedPubkey> {
        let v = vector::empty<twisted_elgamal::CompressedPubkey>();
        vector::push_back(&mut v, basepoint_ek_for_fs_tests());
        v
    }

    fun auditor_eks_vec_2_GH(): vector<twisted_elgamal::CompressedPubkey> {
        let v = vector::empty<twisted_elgamal::CompressedPubkey>();
        vector::push_back(&mut v, basepoint_ek_for_fs_tests());
        vector::push_back(&mut v, hash_base_ek_for_fs_tests());
        v
    }

    fun auditor_eks_vec_2_HG(): vector<twisted_elgamal::CompressedPubkey> {
        let v = vector::empty<twisted_elgamal::CompressedPubkey>();
        vector::push_back(&mut v, hash_base_ek_for_fs_tests());
        vector::push_back(&mut v, basepoint_ek_for_fs_tests());
        v
    }

    fun auditor_eks_vec_3_GHG(): vector<twisted_elgamal::CompressedPubkey> {
        let v = vector::empty<twisted_elgamal::CompressedPubkey>();
        vector::push_back(&mut v, basepoint_ek_for_fs_tests());
        vector::push_back(&mut v, hash_base_ek_for_fs_tests());
        vector::push_back(&mut v, basepoint_ek_for_fs_tests());
        v
    }

    fun auditor_amounts_zero(n: u64): vector<confidential_balance::ConfidentialBalance> {
        let v = vector::empty<confidential_balance::ConfidentialBalance>();
        let i = 0u64;
        while (i < n) {
            vector::push_back(&mut v, confidential_balance::new_pending_balance_no_randomness());
            i = i + 1;
        };
        v
    }

    /// W.13 (1 auditor, ek=G): SHA-512 of FS prefix.
    public fun test_sha2_512_of_tr_1_auditor_fs_prefix_matches_golden_tier3_binding(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = auditor_eks_vec_1G();
        let auditor_amounts = auditor_amounts_zero(1);
        let prefix = difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        aptos_hash::sha2_512(prefix)
            == x"543657bea89678b4b17cee15b797f54e153a6887530ae7195c125050900d9ee0c4cff20072cc88bcc3a242c092bd88ecb02890f9b451cdea063be528c1a6af49"
    }

    /// W.13 (2 auditors, eks=[G,H]): SHA-512 of FS prefix.
    public fun test_sha2_512_of_tr_2_auditor_fs_prefix_matches_golden_tier3_binding(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = auditor_eks_vec_2_GH();
        let auditor_amounts = auditor_amounts_zero(2);
        let prefix = difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        aptos_hash::sha2_512(prefix)
            == x"f058a3f77fb554eb73e237beca83573467e9444d93de452738f668248b32c6d8a9bbd38af07e6f059d37c28dca4944d02fa2c6bdd828f603b7092929ad8efb32"
    }

    /// W.13 (3 auditors, eks=[G,H,G]): SHA-512 of FS prefix.
    public fun test_sha2_512_of_tr_3_auditor_fs_prefix_matches_golden_tier3_binding(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = auditor_eks_vec_3_GHG();
        let auditor_amounts = auditor_amounts_zero(3);
        let prefix = difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        aptos_hash::sha2_512(prefix)
            == x"8844186fdf7aa4db3497bccb465e1e91c6c1eacda139e98ec77ee3e5aaecccd1cf648c6f117a0a05e7d3502eeddb682a8c56a931d838e7f88197d1506af53892"
    }

    /// W.13 (2 auditors, eks=[H,G] SWAPPED): SHA-512 of FS prefix.
    /// Distinct from 2A [G,H] — directly binds auditor-order semantics.
    public fun test_sha2_512_of_tr_2_auditor_swapped_fs_prefix_matches_golden_tier3_binding(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = auditor_eks_vec_2_HG();
        let auditor_amounts = auditor_amounts_zero(2);
        let prefix = difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        aptos_hash::sha2_512(prefix)
            == x"99eb6376b9f432f70f750981816cd6cadf0e06dacef4f66c745b0962d71fd897d8164e58dac9551d8b563611e9e9e3870ffd5b68e6f70d662b166c7cbf10a9c7"
    }

    /// W.13 (1 auditor): FS challenge scalar golden.
    public fun test_fs_challenge_scalar_tr_1_auditor_tier3_binding(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = auditor_eks_vec_1G();
        let auditor_amounts = auditor_amounts_zero(1);
        let prefix = difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"fa6dfd53973bd9e4e7f58a151dd95025ea569ca88e87803d6eb27d68d87ee507"
    }

    /// W.13 (2 auditors, eks=[G,H]): FS challenge scalar golden.
    public fun test_fs_challenge_scalar_tr_2_auditor_tier3_binding(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = auditor_eks_vec_2_GH();
        let auditor_amounts = auditor_amounts_zero(2);
        let prefix = difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"1cf95cecd9605235caa25a95148b8047f4241214bbd244c267286a29b7913a03"
    }

    /// W.13 (3 auditors): FS challenge scalar golden.
    public fun test_fs_challenge_scalar_tr_3_auditor_tier3_binding(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = auditor_eks_vec_3_GHG();
        let auditor_amounts = auditor_amounts_zero(3);
        let prefix = difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"134994c4afa7b8e35894df001078ab8e51978c3b7a7733bfedeef702d6182e07"
    }

    /// W.13 (2 auditors, SWAPPED eks=[H,G]): FS challenge scalar golden.
    public fun test_fs_challenge_scalar_tr_2_auditor_swapped_tier3_binding(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = auditor_eks_vec_2_HG();
        let auditor_amounts = auditor_amounts_zero(2);
        let prefix = difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"d422b17939b91c76ba20286fc96276ce5708646eab52f293f3192388b9de930a"
    }

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 Phase W.14 — chain_id BOUNDARY axis coverage for all four sigma
    // protocols. W.11 covers chain_id variants for withdrawal only. W.14
    // pins FS prefix SHA-512 + challenge scalar at {0x00, 0xff} boundaries
    // for normalization, rotation, transfer, plus wd_cid0 to complete the
    // withdrawal chain_id axis {0, 1, 9, 0xff}. Catches a regression in
    // chain_id byte processing that only manifests at boundaries — e.g. a
    // signed/unsigned mismatch that sign-extends for chain_id ≥ 0x80, a
    // branch that treats chain_id = 0 as "missing" and omits the byte, or
    // a silent u8→i8 coercion.

    /// W.14 (withdrawal, chain_id=0x00): SHA-512 of FS prefix.
    public fun test_sha2_512_of_wd_cid0_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(42u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            0u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        aptos_hash::sha2_512(prefix)
            == x"25b803e1aced4e052ce7bd6d9e7d3781fd8f1d6e268e530663295aa6840a53073c707c58b325aacffd10f22c08ba2ca2aad957a037d11f2955b1cb9718df8c83"
    }

    /// W.14 (withdrawal, chain_id=0x00): FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_cid0_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(42u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            0u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"3a7b26269bc0d5692eebf2d5b684350cb8a76807eb23a3598fc5993c362a8a0e"
    }

    /// W.14 (normalization, chain_id=0x00): SHA-512 of FS prefix.
    public fun test_sha2_512_of_norm_cid0_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::normalization_fs_prefix(
            0u8, @0xA, @0xB, &ek, &current_balance, &new_balance);
        aptos_hash::sha2_512(prefix)
            == x"b928e787990f86bf06ba28bb1f210fd5fdc237c69798d2b9e820d066abd5b1c76464d602255a41829e1c28fc52e5a60c4472aba8791badd71e50f79fb13ad1fc"
    }

    /// W.14 (normalization, chain_id=0x00): FS challenge scalar.
    public fun test_fs_challenge_scalar_norm_cid0_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::normalization_fs_prefix(
            0u8, @0xA, @0xB, &ek, &current_balance, &new_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"e9a7d3e77baf9a4faabf4723475b0b2d92e8aa40139f1814effe46d533943f00"
    }

    /// W.14 (normalization, chain_id=0xff): SHA-512 of FS prefix.
    public fun test_sha2_512_of_norm_cidff_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::normalization_fs_prefix(
            0xffu8, @0xA, @0xB, &ek, &current_balance, &new_balance);
        aptos_hash::sha2_512(prefix)
            == x"b486fbb6a8759fecf3e0661aab3fa753324c36a58e55af596b292d6c35c6fd20f3f9e844c972d25d124c189d01f93207dbd4ec5880dfc653bff7c90b763dac66"
    }

    /// W.14 (normalization, chain_id=0xff): FS challenge scalar.
    public fun test_fs_challenge_scalar_norm_cidff_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::normalization_fs_prefix(
            0xffu8, @0xA, @0xB, &ek, &current_balance, &new_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"28c584d046c7fa3040150ae85c9c412813703097de6e814729bd476bc275f109"
    }

    /// W.14 (rotation, chain_id=0x00): SHA-512 of FS prefix.
    public fun test_sha2_512_of_rot_cid0_fs_prefix_matches_golden_tier3_binding(): bool {
        let current_ek = basepoint_ek_for_fs_tests();
        let new_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0u8, @0xA, @0xB, &current_ek, &new_ek, &current_balance, &new_balance);
        aptos_hash::sha2_512(prefix)
            == x"70c77f452762a362dd7a3084ebd6912fcf9b54aeb778bb2ab063e180fa82c2aad262f68c02b2851dd4084f17c27021422257f292c25b9b48fb4e3abab2d98c51"
    }

    /// W.14 (rotation, chain_id=0x00): FS challenge scalar.
    public fun test_fs_challenge_scalar_rot_cid0_tier3_binding(): bool {
        let current_ek = basepoint_ek_for_fs_tests();
        let new_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0u8, @0xA, @0xB, &current_ek, &new_ek, &current_balance, &new_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"d118b45261a3e9aa4be02b3de6c69d6dc9129dd7e0bbcf4c1c99be1b8dc79502"
    }

    /// W.14 (rotation, chain_id=0xff): SHA-512 of FS prefix.
    public fun test_sha2_512_of_rot_cidff_fs_prefix_matches_golden_tier3_binding(): bool {
        let current_ek = basepoint_ek_for_fs_tests();
        let new_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0xffu8, @0xA, @0xB, &current_ek, &new_ek, &current_balance, &new_balance);
        aptos_hash::sha2_512(prefix)
            == x"5f4e5832209bd392d946634fb57a684ec383ef32c34e2c155ea54e79b24cb29d03d6b1dab3221db06dc0fafc60d2c651fc5aaa74ac1bf948d1704ab28ee06fee"
    }

    /// W.14 (rotation, chain_id=0xff): FS challenge scalar.
    public fun test_fs_challenge_scalar_rot_cidff_tier3_binding(): bool {
        let current_ek = basepoint_ek_for_fs_tests();
        let new_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0xffu8, @0xA, @0xB, &current_ek, &new_ek, &current_balance, &new_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"031e4c478d837def6045e0f7676c879c5a9cb168e5ef77483c893a4fdbb8e202"
    }

    /// W.14 (transfer 0-aud, chain_id=0x00): SHA-512 of FS prefix.
    public fun test_sha2_512_of_tr_cid0_fs_prefix_matches_golden_tier3_binding(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let prefix = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        aptos_hash::sha2_512(prefix)
            == x"84b8585b6f38ef0fc6172b239797962c4a9666208ccb86eaf94f7edb191f1b812a91ff9c692802a178da708cad5cbee67224965975101d34cdc6bc592d9e5dfd"
    }

    /// W.14 (transfer 0-aud, chain_id=0x00): FS challenge scalar.
    public fun test_fs_challenge_scalar_tr_cid0_tier3_binding(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let prefix = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"84c4545df83b97766ec1f977278e076962f727b23d25424af137ba160224cc05"
    }

    /// W.14 (transfer 0-aud, chain_id=0xff): SHA-512 of FS prefix.
    public fun test_sha2_512_of_tr_cidff_fs_prefix_matches_golden_tier3_binding(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let prefix = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0xffu8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        aptos_hash::sha2_512(prefix)
            == x"6dae7afe07dbe319e4ae4f486d02eebc9920dd6d789625f5f92800d16e4d596ef8ac6e32fe90e06668f8854bd44243d4e9a9f87161d72b3fb5f1f2c88c887beb"
    }

    /// W.14 (transfer 0-aud, chain_id=0xff): FS challenge scalar.
    public fun test_fs_challenge_scalar_tr_cidff_tier3_binding(): bool {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let prefix = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0xffu8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"f7ff2ed8426628f00bcef8a103fd655f968a8df2b8314d124a60bd8066d8b702"
    }

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 Phase W.15 — amount-chunk BOUNDARY axis for withdrawal FS
    // prefix. All W.10-W.14 withdrawal rows use amount=42 → chunks
    // [42,0,0,0]; only chunk-0 is non-zero and no chunk boundary is
    // crossed. W.15 pins FS prefix SHA-512 + challenge scalar for
    // amount ∈ {0, 2^32-1, 2^32, 2^64-1, 0x0123_4567_89ab_cdef} —
    // boundary values that activate each of the four 16-bit chunks in
    // independent patterns. Catches a regression in
    // `split_into_chunks_u64` or in the FS-prefix chunk-ordering /
    // chunk-width logic (big-endian vs little-endian chunk order,
    // chunk-width off-by-one, skipping zero chunks, swapping chunk-0
    // ↔ chunk-3).

    /// W.15 (amount=0): SHA-512 of FS prefix.
    public fun test_sha2_512_of_wd_amt_0_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(0u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        aptos_hash::sha2_512(prefix)
            == x"e69ccd0c56e8150133ecfc0a1ac24afaae24e3496a407891698d552160cf09c136aa48e4305654314730f4c6a4f3ef93effa6b442acd56695a1cfb8e36121baa"
    }

    /// W.15 (amount=0): FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_amt_0_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(0u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"a00c3fb08e00ea09d684419f893207e69dc6c5aaa31750e65ca1aff6b731170c"
    }

    /// W.15 (amount=2^32-1, chunks [0xffff,0xffff,0,0]): SHA-512.
    public fun test_sha2_512_of_wd_amt_u32max_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(0xffffffffu64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        aptos_hash::sha2_512(prefix)
            == x"e8bf37416678b63f4cfec49ba96eaf47a07f6d08fa796e3e8672bc33324c235d368930efad1c02145cd0de7f6efcf3966d3c094e7db02fbebfb8b1be1c872b0f"
    }

    /// W.15 (amount=2^32-1): FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_amt_u32max_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(0xffffffffu64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"69b183f7c38876d9d1edf3fe08b68e9c016fadeed31802af34494f68e3482601"
    }

    /// W.15 (amount=2^32, chunks [0,0,1,0]): SHA-512.
    public fun test_sha2_512_of_wd_amt_2p32_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(0x100000000u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        aptos_hash::sha2_512(prefix)
            == x"e1f03b3395f804b4282a6dc4b3d7fdd2c2ae8aed1f553395af5aa2dba655cb7ad088437bbe79b295de460cd02e7b34a7075b2ae409b98068c7f8ecd173a7b2b5"
    }

    /// W.15 (amount=2^32): FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_amt_2p32_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(0x100000000u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"b7088d2ea9cbe3e60bcc512b7fea5e1ef5216f31498931355c86be4efdfe1b0d"
    }

    /// W.15 (amount=u64::MAX, all chunks 0xffff): SHA-512.
    public fun test_sha2_512_of_wd_amt_u64max_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(0xffffffffffffffffu64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        aptos_hash::sha2_512(prefix)
            == x"c5cf28b3e6bff9bd593566c08a5e59addde00799b9806777d57bdc103296882de8779bc72f3293306b76972ef620a3b787a71c5dd09f4a9f2da9111014509d4d"
    }

    /// W.15 (amount=u64::MAX): FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_amt_u64max_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(0xffffffffffffffffu64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"f4cb54b229d7cee4546643b817ae9e825b9bc3cb036f9045898f6941331ecb0b"
    }

    /// W.15 (amount=0x0123_4567_89ab_cdef, all 4 chunks distinct): SHA-512.
    /// Directly pins chunk-order: chunks = [0xcdef, 0x89ab, 0x4567, 0x0123].
    /// A big-endian-chunk regression would swap these and change the hash.
    public fun test_sha2_512_of_wd_amt_distinct_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(0x0123456789abcdefu64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        aptos_hash::sha2_512(prefix)
            == x"fd35077d6aab18d4a9715b51e9ff889a215d2a303009a81fce553df2878785642ddd930210ef8efff4e4183c85ec7e1a9cb6a03351deede407aae5bf7e180a46"
    }

    /// W.15 (amount=0x0123_4567_89ab_cdef): FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_amt_distinct_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(0x0123456789abcdefu64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"c3a41ed7b8ce06708a4b39589b12b82cef2eea97099b03dafae8b7226b846b0d"
    }

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 Phase W.16 — address-BCS BOUNDARY axis for withdrawal FS
    // prefix. All W.10-W.15 rows use sender=@0xA, recipient=@0xB. W.16
    // pins 4 address-boundary fixtures (swap, zero, max, same) ×
    // 2 bindings (SHA-512 + challenge scalar) = 8 new rows. Catches a
    // regression in BCS address serialization or sender↔recipient
    // assembly swap, all-zero-address leading-zero elision, max-address
    // overflow, or a self-withdrawal (sender == recipient) short-circuit.

    /// W.16 (addr swap: sender=@0xB, recipient=@0xA): SHA-512 of FS prefix.
    public fun test_sha2_512_of_wd_addr_swap_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(42u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xB, @0xA, &ek, &amount_chunks, &current_balance);
        aptos_hash::sha2_512(prefix)
            == x"6639158ac4efaa01a5c78de7bd6667d1d1f750ebc51ec70a1a41f646878ebd8949ecda68e951884d5c690562415e380a0e64c79693f737b381a450a1be4c4bc3"
    }

    /// W.16 (addr swap): FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_addr_swap_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(42u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xB, @0xA, &ek, &amount_chunks, &current_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"d2f3c7d9afc1775f69adcf64b243efee00794886525fdf9ee4ed409775c2c30c"
    }

    /// W.16 (addr zero: sender=@0x0, recipient=@0x1): SHA-512.
    public fun test_sha2_512_of_wd_addr_zero_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(42u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0x0, @0x1, &ek, &amount_chunks, &current_balance);
        aptos_hash::sha2_512(prefix)
            == x"1ffdbb1eec75c3427676830407023c8808d333917fc4759ae932723ddb106f3b3e9f3f29b9b7265f1ffaf1f8253c4fc02c8e0506af9ad2fddf3f6961e37eb13d"
    }

    /// W.16 (addr zero): FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_addr_zero_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(42u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0x0, @0x1, &ek, &amount_chunks, &current_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"81992c28ea8d1c9ac022e3fd080c8c9b243a57a7394c2b70b5b5aef2310be306"
    }

    /// W.16 (addr max: sender=@0xff..ff, recipient=@0xff..fe): SHA-512.
    public fun test_sha2_512_of_wd_addr_max_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(42u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8,
            @0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            @0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            &ek, &amount_chunks, &current_balance);
        aptos_hash::sha2_512(prefix)
            == x"bb570576c1c3cdb55f1c2da93dce000193c1bb2ccf8b0f665b64c51eafffeed35739d3f999bcb7f24ee11afe750d1afeaae214b4293a6a599d2f154bfb06ed52"
    }

    /// W.16 (addr max): FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_addr_max_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(42u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8,
            @0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            @0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            &ek, &amount_chunks, &current_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"0eeedc6b138041af0f3aa0d4ccd0ac48cfbaee494dd37720e75bd08205640c0e"
    }

    /// W.16 (addr same: sender=recipient=@0xA, self-withdrawal): SHA-512.
    public fun test_sha2_512_of_wd_addr_same_fs_prefix_matches_golden_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(42u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xA, &ek, &amount_chunks, &current_balance);
        aptos_hash::sha2_512(prefix)
            == x"a85ee5b72c676fbc760c67f6ec9a57dc8d342625341c1929602808cb06ff8e7f1c39e561b8245e07044b4836cc65d99e2c8c613d1ce18195cebdb8a0865406c2"
    }

    /// W.16 (addr same): FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_addr_same_tier3_binding(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(42u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let prefix = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xA, &ek, &amount_chunks, &current_balance);
        let s = ristretto255::new_scalar_from_sha2_512(prefix);
        ristretto255::scalar_to_bytes(&s)
            == x"da50cae71a398f6df7587e1b4d62d280a4494439e7bf0c8abec08558af684708"
    }

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 Phase W.17 — full FS-MESSAGE axis (prefix || X-point bytes).
    // All W.10-W.16 bindings stop at the FS PREFIX. The actual sigma
    // challenge is new_scalar_from_sha2_512(prefix || compress(X_0) || ...
    // || compress(X_n)). W.17 circumvents the open canonicalEncode
    // noncomputability problem by using ALREADY-PINNED compressed
    // Ristretto byte arrays (G and H) as synthetic X-point bytes,
    // binding the FULL FS-message byte concatenation + SHA-512 + scalar
    // reduction for 4 fixtures (1, 2, 2-swapped, and 6 X-points).

    /// Reference withdrawal FS prefix for W.17.
    fun wd_fs_prefix_w17(): vector<u8> {
        let ek = basepoint_ek_for_fs_tests();
        let amount_chunks = confidential_balance::split_into_chunks_u64(42u64);
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance)
    }

    /// G bytes (basepoint compressed).
    fun g_bytes(): vector<u8> {
        ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed())
    }

    /// H bytes (confidential-asset hash base compressed).
    fun h_bytes(): vector<u8> {
        let h = ristretto255::hash_to_point_base();
        ristretto255::point_to_bytes(&ristretto255::point_compress(&h))
    }

    /// W.17 msg A (1 X = G): SHA-512.
    public fun test_sha2_512_of_wd_msg_a_tier3_binding(): bool {
        let msg = wd_fs_prefix_w17();
        msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"6cb4e3e405aa2b529e3b74a19deaac15dc7724c8bdf311d86f4a6053cd2fa1a64ad8e3905f539cc3fe3852ab48f7dd5ff587f9e76b9ff1a3dd3eeec2e9d498a2"
    }

    /// W.17 msg A: FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_msg_a_tier3_binding(): bool {
        let msg = wd_fs_prefix_w17();
        msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"a12712db315c6a7f09185bbd679c990fc6d6f32bff5d4a044b5e31291e5f1509"
    }

    /// W.17 msg B (X = [G, H]): SHA-512.
    public fun test_sha2_512_of_wd_msg_b_tier3_binding(): bool {
        let msg = wd_fs_prefix_w17();
        msg.append(g_bytes());
        msg.append(h_bytes());
        aptos_hash::sha2_512(msg)
            == x"7de231d2ff9fa1e8dd9ba927fccd6b984721e9f01dc67031506329020ff250662fd395011d15ddabc5f0e4e965462bdc6e51361ca8126b1f7b95ca150562f39b"
    }

    /// W.17 msg B: FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_msg_b_tier3_binding(): bool {
        let msg = wd_fs_prefix_w17();
        msg.append(g_bytes());
        msg.append(h_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"f4a81ddf974e875af5a173aa773fa564393b8d9feb7d45121ad22b5e5330200c"
    }

    /// W.17 msg C (X = [H, G] — SWAPPED): SHA-512. Directly pins
    /// X-point ordering in the FS-message assembly.
    public fun test_sha2_512_of_wd_msg_c_tier3_binding(): bool {
        let msg = wd_fs_prefix_w17();
        msg.append(h_bytes());
        msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"ff99f12eea7c6b10223d0677e4f5c7d5beaca0c240510b38dac73f8cd1ffef4ddd08f23159564f142b088bcd9898e8718e0b93932af098cb95e053ff4f2b7831"
    }

    /// W.17 msg C: FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_msg_c_tier3_binding(): bool {
        let msg = wd_fs_prefix_w17();
        msg.append(h_bytes());
        msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"0831ee86f3f4aee60cc4d25b2d68103866e3e641fbda563a8df20c875e880f02"
    }

    /// W.17 msg D (X = [G, G, G, H, H, H] — 6 X-points): SHA-512.
    public fun test_sha2_512_of_wd_msg_d_tier3_binding(): bool {
        let msg = wd_fs_prefix_w17();
        msg.append(g_bytes());
        msg.append(g_bytes());
        msg.append(g_bytes());
        msg.append(h_bytes());
        msg.append(h_bytes());
        msg.append(h_bytes());
        aptos_hash::sha2_512(msg)
            == x"b5f870cd18c3fe74f4c3805e624d938b27a0f60455dfa77138bb42e66a3b09bf26ec6c96ccded243128a1401eef325655432f4ef4b9e90afdf2df9a9d169ecc4"
    }

    /// W.17 msg D: FS challenge scalar.
    public fun test_fs_challenge_scalar_wd_msg_d_tier3_binding(): bool {
        let msg = wd_fs_prefix_w17();
        msg.append(g_bytes());
        msg.append(g_bytes());
        msg.append(g_bytes());
        msg.append(h_bytes());
        msg.append(h_bytes());
        msg.append(h_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"64fc857fd15955766d5c471a59da30cce7b78d29eeb4b2cb4ec13c6fc875880a"
    }

    // ───────────────────────────────────────────────────────────────────────
    // Tier 3 Phase W.18 — full FS-MESSAGE axis for normalization /
    // rotation / transfer. Extends W.17 (withdrawal) to the remaining
    // 3 sigma protocols. 3 protocols × 2 shapes (G only, [H,G]
    // swapped) × 2 bindings (SHA-512 + challenge scalar) = 12 new
    // rows. Per-protocol X-order distinctness is pinned in Lean.

    fun norm_fs_prefix_w18(): vector<u8> {
        let ek = basepoint_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        difftest_confidential_proof_helpers::normalization_fs_prefix(
            9u8, @0xA, @0xB, &ek, &current_balance, &new_balance)
    }

    fun rot_fs_prefix_w18(): vector<u8> {
        let current_ek = basepoint_ek_for_fs_tests();
        let new_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        difftest_confidential_proof_helpers::rotation_fs_prefix(
            9u8, @0xA, @0xB, &current_ek, &new_ek, &current_balance, &new_balance)
    }

    fun tr_fs_prefix_w18(): vector<u8> {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts)
    }

    /// W.18 norm msg A (prefix || G): SHA-512.
    public fun test_sha2_512_of_norm_msg_a_tier3_binding(): bool {
        let msg = norm_fs_prefix_w18(); msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"84bbf94633c0e26ed207364dcee74c482368ee6c94a747fc74d779190175173a973dcba8feb2afca81b37841ee1137b8c7d477c2a7c125eeecc2cc2fd6768abf"
    }

    /// W.18 norm msg A: FS challenge scalar.
    public fun test_fs_challenge_scalar_norm_msg_a_tier3_binding(): bool {
        let msg = norm_fs_prefix_w18(); msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"49c6fc2fe50bc304ba550fa02ab7da8afd0f21c0c51817421d04133c6e6dbb00"
    }

    /// W.18 norm msg B (prefix || H || G — SWAPPED X-order): SHA-512.
    public fun test_sha2_512_of_norm_msg_b_tier3_binding(): bool {
        let msg = norm_fs_prefix_w18(); msg.append(h_bytes()); msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"4bcfc3cfdd82f4ebc5535411f3be5bb1093ab055c680e58bbd2d292b3e48f1fc9fbd0b98965f8514f21b27db71a5723d7b86f067b447aa82ab563c98429412fc"
    }

    /// W.18 norm msg B: FS challenge scalar.
    public fun test_fs_challenge_scalar_norm_msg_b_tier3_binding(): bool {
        let msg = norm_fs_prefix_w18(); msg.append(h_bytes()); msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"ed6a3b12ec77271428566401ea47d3f0197b5554ab56b662b73d2f0a15238403"
    }

    /// W.18 rot msg A: SHA-512.
    public fun test_sha2_512_of_rot_msg_a_tier3_binding(): bool {
        let msg = rot_fs_prefix_w18(); msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"1e729e783f7c83198cff1ec65ce824baf3f886d183f9128f071e30764335f86b0a2d23fbd6188eb3160df4ac388dd870a8049ee4fc3d26a13f67d14c72982da9"
    }

    /// W.18 rot msg A: FS challenge scalar.
    public fun test_fs_challenge_scalar_rot_msg_a_tier3_binding(): bool {
        let msg = rot_fs_prefix_w18(); msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"eb1f7c92f39001b3c78e4e01dbcb58e6f56fb9d65a9ed7e95ae2f43d59a3480f"
    }

    /// W.18 rot msg B: SHA-512.
    public fun test_sha2_512_of_rot_msg_b_tier3_binding(): bool {
        let msg = rot_fs_prefix_w18(); msg.append(h_bytes()); msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"b9a9aff1e2c6ea174b2bc2cdc966c1f9e3675b4f2369eabd1ae9720d799bf7a7afb82f7ee2a9eac75f4dde8b3eec7a055ef8129c028f2c94429bf2347c38d12f"
    }

    /// W.18 rot msg B: FS challenge scalar.
    public fun test_fs_challenge_scalar_rot_msg_b_tier3_binding(): bool {
        let msg = rot_fs_prefix_w18(); msg.append(h_bytes()); msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"973a634ac14e3325c8c981ec5b9d2c0f4218e6cbc3d6678a70b104cd58a48907"
    }

    /// W.18 tr msg A: SHA-512.
    public fun test_sha2_512_of_tr_msg_a_tier3_binding(): bool {
        let msg = tr_fs_prefix_w18(); msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"343f9e95247215c210506ded2e9d7a6ae2cc6e769b37c42c007644929876a86e906f61f3ae1b0ccde6e509ec1ae95393cb1fc8826087b666fe372f5c45883af9"
    }

    /// W.18 tr msg A: FS challenge scalar.
    public fun test_fs_challenge_scalar_tr_msg_a_tier3_binding(): bool {
        let msg = tr_fs_prefix_w18(); msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"55bc1186c330a80553fac9a06e8426bf641f4d7996d21144810458363e129804"
    }

    /// W.18 tr msg B: SHA-512.
    public fun test_sha2_512_of_tr_msg_b_tier3_binding(): bool {
        let msg = tr_fs_prefix_w18(); msg.append(h_bytes()); msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"402d4a7533703485886e4daa2d4c9c2ae782c7f49fa2a9006b086b3c29b4889b5ea037a35c3cdaaa9d2788ee4c0f6476074bab6edd19001018a425238403c8b0"
    }

    /// W.18 tr msg B: FS challenge scalar.
    public fun test_fs_challenge_scalar_tr_msg_b_tier3_binding(): bool {
        let msg = tr_fs_prefix_w18(); msg.append(h_bytes()); msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"1071e010294373ae90d232a60fa22715d52c8977ce5b749bb4a55589506bf601"
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.19 — extend full FS-MESSAGE axis for norm / rot / tr
    // to match W.17's 4-shape coverage density for withdrawal.
    //
    //   MsgC = prefix || G || H        (2 X, NON-swapped; paired
    //                                   with MsgB which is [H,G] so
    //                                   any X-order serializer drift
    //                                   flips both the B/C direct
    //                                   pin and the independent
    //                                   golden pin)
    //   MsgD = prefix || 3×G || 3×H   (6 X, matches wdMsgD in W.17)
    //
    // 3 protocols × 2 shapes × 2 bindings = 12 new rows.
    // ───────────────────────────────────────────────────────────────

    /// W.19 norm msg C: SHA-512 over prefix || G || H.
    public fun test_sha2_512_of_norm_msg_c_tier3_binding(): bool {
        let msg = norm_fs_prefix_w18(); msg.append(g_bytes()); msg.append(h_bytes());
        aptos_hash::sha2_512(msg)
            == x"95a1e1b24dd55fd9318843c61f6990d6af97b2825f01b5b70d74972de788a4ff5da8ba41267ec9ebd03034b1cccad40848f5cb7881cfb4ac666fe84ec32bbbb3"
    }

    /// W.19 norm msg C: FS challenge scalar.
    public fun test_fs_challenge_scalar_norm_msg_c_tier3_binding(): bool {
        let msg = norm_fs_prefix_w18(); msg.append(g_bytes()); msg.append(h_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"076a9fb2a9dd1a72aad32fc6c045849172b769a77fc9ec78021448daebfe280a"
    }

    /// W.19 norm msg D: SHA-512 over prefix || 3×G || 3×H.
    public fun test_sha2_512_of_norm_msg_d_tier3_binding(): bool {
        let msg = norm_fs_prefix_w18();
        msg.append(g_bytes()); msg.append(g_bytes()); msg.append(g_bytes());
        msg.append(h_bytes()); msg.append(h_bytes()); msg.append(h_bytes());
        aptos_hash::sha2_512(msg)
            == x"3d7059bb6483336806c6aca045afa1e5910e733c75cab8c8675dcc4b574f8fb4fbfcb26766566dbff7adea7a1c79eb121c3a17da15b2c550bd006bb59c3cf968"
    }

    /// W.19 norm msg D: FS challenge scalar.
    public fun test_fs_challenge_scalar_norm_msg_d_tier3_binding(): bool {
        let msg = norm_fs_prefix_w18();
        msg.append(g_bytes()); msg.append(g_bytes()); msg.append(g_bytes());
        msg.append(h_bytes()); msg.append(h_bytes()); msg.append(h_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"6cf4bb2ad5f2f94e745087c9437b6311077e8dc713424ba638fc0a43244fcc0f"
    }

    /// W.19 rot msg C: SHA-512.
    public fun test_sha2_512_of_rot_msg_c_tier3_binding(): bool {
        let msg = rot_fs_prefix_w18(); msg.append(g_bytes()); msg.append(h_bytes());
        aptos_hash::sha2_512(msg)
            == x"e97faf928e8b3354327acf35125c4419200f0926fa5803dc8ea5f1007dc5ec2dd58cb26a9cc619c9791f77ffa2be61a7e85e921434c3fcb8b5a7731d7ac69281"
    }

    /// W.19 rot msg C: FS challenge scalar.
    public fun test_fs_challenge_scalar_rot_msg_c_tier3_binding(): bool {
        let msg = rot_fs_prefix_w18(); msg.append(g_bytes()); msg.append(h_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"9d632bada068a508cda2347cc39fc72e035a5dd87161c670b978f7d2dad2b402"
    }

    /// W.19 rot msg D: SHA-512.
    public fun test_sha2_512_of_rot_msg_d_tier3_binding(): bool {
        let msg = rot_fs_prefix_w18();
        msg.append(g_bytes()); msg.append(g_bytes()); msg.append(g_bytes());
        msg.append(h_bytes()); msg.append(h_bytes()); msg.append(h_bytes());
        aptos_hash::sha2_512(msg)
            == x"ccfeb70b5251551ba0f2db0605623275fb55692efb53438352d8a3fffbea94ddec16b46425d3df7cb4b929fcdd0ba15b7d6b4ab3dc76ee06d4b3b0d9927e8d54"
    }

    /// W.19 rot msg D: FS challenge scalar.
    public fun test_fs_challenge_scalar_rot_msg_d_tier3_binding(): bool {
        let msg = rot_fs_prefix_w18();
        msg.append(g_bytes()); msg.append(g_bytes()); msg.append(g_bytes());
        msg.append(h_bytes()); msg.append(h_bytes()); msg.append(h_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"add8ba931d42f593619292b20831f1b9805a7a4fe98400d55e50d54417b8850d"
    }

    /// W.19 tr msg C: SHA-512.
    public fun test_sha2_512_of_tr_msg_c_tier3_binding(): bool {
        let msg = tr_fs_prefix_w18(); msg.append(g_bytes()); msg.append(h_bytes());
        aptos_hash::sha2_512(msg)
            == x"cfab03a7f0b628f39624c049ae67eecb04f12642b0ce63faac5e31b7960f4c02f4a6d4e07b9440769d7587ecc63ddfa611938e17be04240c0303949c98e92933"
    }

    /// W.19 tr msg C: FS challenge scalar.
    public fun test_fs_challenge_scalar_tr_msg_c_tier3_binding(): bool {
        let msg = tr_fs_prefix_w18(); msg.append(g_bytes()); msg.append(h_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"92723e625c47d905ece99eee973a3b40b436ec115ae17fe481d88fdaee45e40f"
    }

    /// W.19 tr msg D: SHA-512.
    public fun test_sha2_512_of_tr_msg_d_tier3_binding(): bool {
        let msg = tr_fs_prefix_w18();
        msg.append(g_bytes()); msg.append(g_bytes()); msg.append(g_bytes());
        msg.append(h_bytes()); msg.append(h_bytes()); msg.append(h_bytes());
        aptos_hash::sha2_512(msg)
            == x"f54810c9409f0c11812018610da8432a217590d06fe4af2be90ac902e68757a92a1b01e3ace7e16f19a36eba4398c1c5c85d87d8895368c23081b35f96d4d52e"
    }

    /// W.19 tr msg D: FS challenge scalar.
    public fun test_fs_challenge_scalar_tr_msg_d_tier3_binding(): bool {
        let msg = tr_fs_prefix_w18();
        msg.append(g_bytes()); msg.append(g_bytes()); msg.append(g_bytes());
        msg.append(h_bytes()); msg.append(h_bytes()); msg.append(h_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"7c0bfc6d14c40c381c5482e1f2399e8fe29a45ccb5cd59e1a583e36c03fc4805"
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.20 — transfer auditor-count × full FS-MESSAGE axis.
    //
    // W.13 pinned the transfer FS PREFIX for {1, 2, 3, 2-swapped}
    // auditor variants. W.18 / W.19 pinned the full FS-MESSAGE only
    // for transfer with 0 auditors. Combining both axes here binds
    // per-auditor-variant X-point concatenation into the full message
    // hash + scalar reduction path.
    //
    // 4 auditor variants × 2 X-shapes × 2 bindings = 16 new rows.
    // ───────────────────────────────────────────────────────────────

    fun tr1a_fs_prefix_w20(): vector<u8> {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = auditor_eks_vec_1G();
        let auditor_amounts = auditor_amounts_zero(1);
        difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts)
    }

    fun tr2a_fs_prefix_w20(): vector<u8> {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = auditor_eks_vec_2_GH();
        let auditor_amounts = auditor_amounts_zero(2);
        difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts)
    }

    fun tr3a_fs_prefix_w20(): vector<u8> {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = auditor_eks_vec_3_GHG();
        let auditor_amounts = auditor_amounts_zero(3);
        difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts)
    }

    fun tr2aswap_fs_prefix_w20(): vector<u8> {
        let sender_ek = basepoint_ek_for_fs_tests();
        let recipient_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let sender_amount = confidential_balance::new_pending_balance_no_randomness();
        let recipient_amount = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = auditor_eks_vec_2_HG();
        let auditor_amounts = auditor_amounts_zero(2);
        difftest_confidential_proof_helpers::transfer_fs_prefix(
            9u8, @0xA, @0xB, &sender_ek, &recipient_ek,
            &current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts)
    }

    /// W.20 1a-auditor msg A: SHA-512.
    public fun test_sha2_512_of_tr_1a_msg_a_tier3_binding(): bool {
        let msg = tr1a_fs_prefix_w20(); msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"30db7b48dbd7d4b92ecaa6d5702520181fb0de603e26d0e61743bd936dfd8c48eb9584dbed0444db316617bcbd03188298d2c063a4420deb4121966c81fa9461"
    }

    public fun test_fs_challenge_scalar_tr_1a_msg_a_tier3_binding(): bool {
        let msg = tr1a_fs_prefix_w20(); msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"1b400b80f3402733528ba5d753ddbd69f114666a90cf3dddb1d0838a05011403"
    }

    public fun test_sha2_512_of_tr_1a_msg_b_tier3_binding(): bool {
        let msg = tr1a_fs_prefix_w20(); msg.append(h_bytes()); msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"2b8765ecef436d27a2eee87b6b9f3663ce3aee9fa1bc2c67d049d41c4cc1e8d1eeb7332a7e096b621ada060921d6910aab2916d45090dbed573e01b7340943ed"
    }

    public fun test_fs_challenge_scalar_tr_1a_msg_b_tier3_binding(): bool {
        let msg = tr1a_fs_prefix_w20(); msg.append(h_bytes()); msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"4e80109a2468534da2ad49a524f0f36fa790a7947c398b68fe1b50f5747a940b"
    }

    public fun test_sha2_512_of_tr_2a_msg_a_tier3_binding(): bool {
        let msg = tr2a_fs_prefix_w20(); msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"23b75eece045190fc461f344ceb8432d4226df2969d3d130da9a12fcc612d14894912083cb83ba6dc1a9322c6147c58dbeedf82fe07d8b1ba158b6cd48e378bd"
    }

    public fun test_fs_challenge_scalar_tr_2a_msg_a_tier3_binding(): bool {
        let msg = tr2a_fs_prefix_w20(); msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"f8245ec4080f06ff31f29e729d1c6fee0ef66e51c63d1f2ab454a374f8629e0d"
    }

    public fun test_sha2_512_of_tr_2a_msg_b_tier3_binding(): bool {
        let msg = tr2a_fs_prefix_w20(); msg.append(h_bytes()); msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"4678386b545fac496bed6d11e7c9518c46da6053f329e0ad786fd676776b27d9691412c6d86cd36324591ea99a42f0ea4ec9caaaeec1429e13ac68e4be18b3f1"
    }

    public fun test_fs_challenge_scalar_tr_2a_msg_b_tier3_binding(): bool {
        let msg = tr2a_fs_prefix_w20(); msg.append(h_bytes()); msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"6f21cc4af90264116cd66c0f7e275f7d0eebe0687819bf44eb668809f9d4e908"
    }

    public fun test_sha2_512_of_tr_3a_msg_a_tier3_binding(): bool {
        let msg = tr3a_fs_prefix_w20(); msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"0425c29027dc12c4b5b5faefd4f45511efe7220cf1c4030aa29476641c6339daed48556d1c2e0961324c8feb6019dd2016f117de4070d20e35a7f681dbb2841f"
    }

    public fun test_fs_challenge_scalar_tr_3a_msg_a_tier3_binding(): bool {
        let msg = tr3a_fs_prefix_w20(); msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"7674e2ffa1c1f5d59a699098f173efee7f4e0d9d0f7edc2d6344cffc0d9c110f"
    }

    public fun test_sha2_512_of_tr_3a_msg_b_tier3_binding(): bool {
        let msg = tr3a_fs_prefix_w20(); msg.append(h_bytes()); msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"a0aaf4c3eb08e1beea229a9cc62efe7085093481b96db6ffdd2eb395731bca981efdd88fb89ed2a9f2e407ba3ab793e4fae0ce861162cf4e785ebe2b4e7983f3"
    }

    public fun test_fs_challenge_scalar_tr_3a_msg_b_tier3_binding(): bool {
        let msg = tr3a_fs_prefix_w20(); msg.append(h_bytes()); msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"d1081d357b9dfec4a1ee1b68c32b9acfea60f2abc09b21d48f0d0f16e35fcc0c"
    }

    public fun test_sha2_512_of_tr_2aswap_msg_a_tier3_binding(): bool {
        let msg = tr2aswap_fs_prefix_w20(); msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"d46393d780b4f5dea3b6709246f26f157f88fda093fa33fd52ef789fc4f505f3bf8e6f8d4c835195079dab81d674049550a5912c2d06189f03b912abd410b823"
    }

    public fun test_fs_challenge_scalar_tr_2aswap_msg_a_tier3_binding(): bool {
        let msg = tr2aswap_fs_prefix_w20(); msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"d135fa6a817251bf0fd16b2cfd0cf596301971366cf838396d0085ef791edb00"
    }

    public fun test_sha2_512_of_tr_2aswap_msg_b_tier3_binding(): bool {
        let msg = tr2aswap_fs_prefix_w20(); msg.append(h_bytes()); msg.append(g_bytes());
        aptos_hash::sha2_512(msg)
            == x"e5911a017fa772a49ba4df2c6d0825b1426ec72eac423cbfe80454b95c5010f28a16042ab7fcd74c0cfa5f97edbf1f5b984390e739343a2ea1d64555fcf2b64f"
    }

    public fun test_fs_challenge_scalar_tr_2aswap_msg_b_tier3_binding(): bool {
        let msg = tr2aswap_fs_prefix_w20(); msg.append(h_bytes()); msg.append(g_bytes());
        let s = ristretto255::new_scalar_from_sha2_512(msg);
        ristretto255::scalar_to_bytes(&s)
            == x"c89b290aedf2aa5207f22d87477b09a81e9f1bf96f464b36cd1f038e42098408"
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.21 — Ristretto255 point-arithmetic algebraic identity
    // binding. Prior phases pin byte-level hashes / FS messages. W.21
    // closes a coverage gap for the *core Ristretto natives* that
    // underpin every sigma verifier: `point_identity`, `basepoint_mul`,
    // `point_mul`, `point_add`, `multi_scalar_mul`, `basepoint_
    // double_mul`. Each identity is expressed as a byte-for-byte
    // equality between two Move-VM-derived computations of the same
    // algebraic expression — e.g. `basepoint_mul(1) ==_bytes
    // basepoint_compressed()`. Any regression in the natives that
    // breaks algebraic correctness on concrete operands flips the
    // corresponding row.
    //
    // 12 new rows × `funcIdx := 40` (VM-executed boolean asserted
    // `true` by the Move body; Lean mirror side returns `ldTrue`).
    // ───────────────────────────────────────────────────────────────

    /// W.21.01: `point_identity_compressed()` is 32 zero bytes.
    public fun test_ristretto_identity_is_zero_bytes_tier3_binding(): bool {
        let id = ristretto255::point_identity_compressed();
        ristretto255::compressed_point_to_bytes(id)
            == x"0000000000000000000000000000000000000000000000000000000000000000"
    }

    /// W.21.02: `basepoint_mul(1) == basepoint_compressed()`.
    public fun test_ristretto_basepoint_mul_by_one_tier3_binding(): bool {
        let one = ristretto255::scalar_one();
        let p = ristretto255::basepoint_mul(&one);
        let pc = ristretto255::point_compress(&p);
        let bp = ristretto255::basepoint_compressed();
        ristretto255::compressed_point_to_bytes(pc)
            == ristretto255::compressed_point_to_bytes(bp)
    }

    /// W.21.03: `basepoint_mul(0) == point_identity`.
    public fun test_ristretto_basepoint_mul_by_zero_tier3_binding(): bool {
        let zero = ristretto255::scalar_zero();
        let p = ristretto255::basepoint_mul(&zero);
        let pc = ristretto255::point_compress(&p);
        let id = ristretto255::point_identity_compressed();
        ristretto255::compressed_point_to_bytes(pc)
            == ristretto255::compressed_point_to_bytes(id)
    }

    /// W.21.04: `point_add(identity, basepoint) == basepoint`.
    public fun test_ristretto_point_add_zero_left_tier3_binding(): bool {
        let id = ristretto255::point_identity();
        let bp = ristretto255::basepoint();
        let sum = ristretto255::point_add(&id, &bp);
        let sum_c = ristretto255::point_compress(&sum);
        let bp_c = ristretto255::basepoint_compressed();
        ristretto255::compressed_point_to_bytes(sum_c)
            == ristretto255::compressed_point_to_bytes(bp_c)
    }

    /// W.21.05: `point_add(basepoint, identity) == basepoint`.
    public fun test_ristretto_point_add_zero_right_tier3_binding(): bool {
        let bp = ristretto255::basepoint();
        let id = ristretto255::point_identity();
        let sum = ristretto255::point_add(&bp, &id);
        let sum_c = ristretto255::point_compress(&sum);
        let bp_c = ristretto255::basepoint_compressed();
        ristretto255::compressed_point_to_bytes(sum_c)
            == ristretto255::compressed_point_to_bytes(bp_c)
    }

    /// W.21.06: `multi_scalar_mul([G], [1]) == G`.
    public fun test_ristretto_msm_single_element_tier3_binding(): bool {
        let points = vector::empty<ristretto255::RistrettoPoint>();
        vector::push_back(&mut points, ristretto255::basepoint());
        let scalars = vector::empty<ristretto255::Scalar>();
        vector::push_back(&mut scalars, ristretto255::scalar_one());
        let r = ristretto255::multi_scalar_mul(&points, &scalars);
        let r_c = ristretto255::point_compress(&r);
        let bp_c = ristretto255::basepoint_compressed();
        ristretto255::compressed_point_to_bytes(r_c)
            == ristretto255::compressed_point_to_bytes(bp_c)
    }

    /// W.21.07: `multi_scalar_mul([G, G], [0, 0]) == identity`.
    public fun test_ristretto_msm_zero_scalars_tier3_binding(): bool {
        let points = vector::empty<ristretto255::RistrettoPoint>();
        vector::push_back(&mut points, ristretto255::basepoint());
        vector::push_back(&mut points, ristretto255::basepoint());
        let scalars = vector::empty<ristretto255::Scalar>();
        vector::push_back(&mut scalars, ristretto255::scalar_zero());
        vector::push_back(&mut scalars, ristretto255::scalar_zero());
        let r = ristretto255::multi_scalar_mul(&points, &scalars);
        let r_c = ristretto255::point_compress(&r);
        let id = ristretto255::point_identity_compressed();
        ristretto255::compressed_point_to_bytes(r_c)
            == ristretto255::compressed_point_to_bytes(id)
    }

    /// W.21.08: `point_mul(G, s) == basepoint_mul(s)` for s = 3.
    public fun test_ristretto_point_mul_vs_basepoint_mul_tier3_binding(): bool {
        let s = ristretto255::new_scalar_from_u64(3);
        let a = ristretto255::point_mul(&ristretto255::basepoint(), &s);
        let b = ristretto255::basepoint_mul(&s);
        let a_c = ristretto255::point_compress(&a);
        let b_c = ristretto255::point_compress(&b);
        ristretto255::compressed_point_to_bytes(a_c)
            == ristretto255::compressed_point_to_bytes(b_c)
    }

    /// W.21.09: scalar distributivity.
    /// `basepoint_mul(a + b) == point_add(basepoint_mul(a), basepoint_mul(b))`
    /// for a = 2, b = 3.
    public fun test_ristretto_scalar_distributivity_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(2);
        let b = ristretto255::new_scalar_from_u64(3);
        let ab = ristretto255::scalar_add(&a, &b);
        let lhs = ristretto255::basepoint_mul(&ab);
        let pa = ristretto255::basepoint_mul(&a);
        let pb = ristretto255::basepoint_mul(&b);
        let rhs = ristretto255::point_add(&pa, &pb);
        let l_c = ristretto255::point_compress(&lhs);
        let r_c = ristretto255::point_compress(&rhs);
        ristretto255::compressed_point_to_bytes(l_c)
            == ristretto255::compressed_point_to_bytes(r_c)
    }

    /// W.21.10: `multi_scalar_mul([G, G], [a, b]) == basepoint_mul(a + b)`
    /// for a = 3, b = 5. Binds MSM internal-sum correctness against
    /// basepoint_mul.
    public fun test_ristretto_msm_distributive_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(3);
        let b = ristretto255::new_scalar_from_u64(5);
        let points = vector::empty<ristretto255::RistrettoPoint>();
        vector::push_back(&mut points, ristretto255::basepoint());
        vector::push_back(&mut points, ristretto255::basepoint());
        let scalars = vector::empty<ristretto255::Scalar>();
        vector::push_back(&mut scalars, a);
        vector::push_back(&mut scalars, b);
        let lhs = ristretto255::multi_scalar_mul(&points, &scalars);
        let ab = ristretto255::scalar_add(&a, &b);
        let rhs = ristretto255::basepoint_mul(&ab);
        let l_c = ristretto255::point_compress(&lhs);
        let r_c = ristretto255::point_compress(&rhs);
        ristretto255::compressed_point_to_bytes(l_c)
            == ristretto255::compressed_point_to_bytes(r_c)
    }

    /// W.21.11: `basepoint_double_mul(a, G, b) ==
    /// point_add(basepoint_mul(a), point_mul(G, b))` for a = 7, b = 11.
    public fun test_ristretto_basepoint_double_mul_equivalence_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(7);
        let b = ristretto255::new_scalar_from_u64(11);
        let g = ristretto255::basepoint();
        let lhs = ristretto255::basepoint_double_mul(&a, &g, &b);
        let pa = ristretto255::basepoint_mul(&a);
        let pb = ristretto255::point_mul(&g, &b);
        let rhs = ristretto255::point_add(&pa, &pb);
        let l_c = ristretto255::point_compress(&lhs);
        let r_c = ristretto255::point_compress(&rhs);
        ristretto255::compressed_point_to_bytes(l_c)
            == ristretto255::compressed_point_to_bytes(r_c)
    }

    /// W.21.12: `point_add(G, 2G) == point_add(2G, G)` (commutativity).
    public fun test_ristretto_point_add_commutes_tier3_binding(): bool {
        let two = ristretto255::new_scalar_from_u64(2);
        let g = ristretto255::basepoint();
        let g2 = ristretto255::basepoint_mul(&two);
        let ab = ristretto255::point_add(&g, &g2);
        let ba = ristretto255::point_add(&g2, &g);
        let a_c = ristretto255::point_compress(&ab);
        let b_c = ristretto255::point_compress(&ba);
        ristretto255::compressed_point_to_bytes(a_c)
            == ristretto255::compressed_point_to_bytes(b_c)
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.22 — advanced Ristretto/scalar algebraic identities.
    // W.21 covers the "identity-element + distributivity + commutativity"
    // foundations using only the basepoint G. W.22 extends coverage to:
    //   (i) non-basepoint operands (the hash-to-point base H, the
    //       curve's independent generator used in Pedersen commitments);
    //   (ii) mixed-basis MSM (MSM over {G, H} rather than only {G, G});
    //   (iii) additive inverse + scalar-algebra identities at the
    //       scalar-field level (neg, double-neg, absorption, assoc,
    //       comm) — these would previously go untested.
    //
    // A regression that special-cases on the basepoint (e.g. only
    // `basepoint_mul` is correct; `point_mul H s` produces garbage),
    // or that corrupts the scalar-field additive-inverse / negation
    // arithmetic (breaking every sigma-protocol response check), slips
    // silently past W.21. Phase W.22 closes both seams.
    //
    // 13 new rows × `funcIdx := 40`.
    // ───────────────────────────────────────────────────────────────

    /// W.22.01: `point_mul(H, 1) == H` — identity multiplier on non-basepoint.
    public fun test_ristretto_h_mul_by_one_tier3_binding(): bool {
        let one = ristretto255::scalar_one();
        let h = ristretto255::hash_to_point_base();
        let r = ristretto255::point_mul(&h, &one);
        let r_c = ristretto255::point_compress(&r);
        let h_c = ristretto255::point_compress(&h);
        ristretto255::compressed_point_to_bytes(r_c)
            == ristretto255::compressed_point_to_bytes(h_c)
    }

    /// W.22.02: `point_mul(H, 0) == identity`.
    public fun test_ristretto_h_mul_by_zero_tier3_binding(): bool {
        let zero = ristretto255::scalar_zero();
        let h = ristretto255::hash_to_point_base();
        let r = ristretto255::point_mul(&h, &zero);
        let r_c = ristretto255::point_compress(&r);
        let id = ristretto255::point_identity_compressed();
        ristretto255::compressed_point_to_bytes(r_c)
            == ristretto255::compressed_point_to_bytes(id)
    }

    /// W.22.03: `point_add(H, H) == point_mul(H, 2)` — doubling on H.
    public fun test_ristretto_h_doubling_tier3_binding(): bool {
        let h = ristretto255::hash_to_point_base();
        let lhs = ristretto255::point_add(&h, &h);
        let two = ristretto255::new_scalar_from_u64(2);
        let rhs = ristretto255::point_mul(&h, &two);
        let l_c = ristretto255::point_compress(&lhs);
        let r_c = ristretto255::point_compress(&rhs);
        ristretto255::compressed_point_to_bytes(l_c)
            == ristretto255::compressed_point_to_bytes(r_c)
    }

    /// W.22.04: mixed-basis MSM.
    /// `MSM([G, H], [a, b]) == point_add(basepoint_mul a, point_mul H b)`
    /// for a = 2, b = 7. Binds MSM across a MIXED-basis {G, H} vector
    /// (every prior W.21 MSM row uses only G — a regression that
    /// special-cases `*_mul` for basepoint alone passes W.21).
    public fun test_ristretto_msm_mixed_basis_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(2);
        let b = ristretto255::new_scalar_from_u64(7);
        let points = vector::empty<ristretto255::RistrettoPoint>();
        vector::push_back(&mut points, ristretto255::basepoint());
        vector::push_back(&mut points, ristretto255::hash_to_point_base());
        let scalars = vector::empty<ristretto255::Scalar>();
        vector::push_back(&mut scalars, a);
        vector::push_back(&mut scalars, b);
        let lhs = ristretto255::multi_scalar_mul(&points, &scalars);
        let pa = ristretto255::basepoint_mul(&a);
        let pb = ristretto255::point_mul(&ristretto255::hash_to_point_base(), &b);
        let rhs = ristretto255::point_add(&pa, &pb);
        let l_c = ristretto255::point_compress(&lhs);
        let r_c = ristretto255::point_compress(&rhs);
        ristretto255::compressed_point_to_bytes(l_c)
            == ristretto255::compressed_point_to_bytes(r_c)
    }

    /// W.22.05: additive inverse at the point level.
    /// `MSM([G, G], [a, -a]) == identity`. Binds `scalar_neg` + MSM.
    public fun test_ristretto_msm_additive_inverse_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(42);
        let na = ristretto255::scalar_neg(&a);
        let points = vector::empty<ristretto255::RistrettoPoint>();
        vector::push_back(&mut points, ristretto255::basepoint());
        vector::push_back(&mut points, ristretto255::basepoint());
        let scalars = vector::empty<ristretto255::Scalar>();
        vector::push_back(&mut scalars, a);
        vector::push_back(&mut scalars, na);
        let r = ristretto255::multi_scalar_mul(&points, &scalars);
        let r_c = ristretto255::point_compress(&r);
        let id = ristretto255::point_identity_compressed();
        ristretto255::compressed_point_to_bytes(r_c)
            == ristretto255::compressed_point_to_bytes(id)
    }

    /// W.22.06: MSM regrouping.
    /// `MSM([G, H, G, H], [1, 1, 1, 1]) == point_add(2G, 2H)`.
    public fun test_ristretto_msm_regrouping_tier3_binding(): bool {
        let one = ristretto255::scalar_one();
        let two = ristretto255::new_scalar_from_u64(2);
        let h = ristretto255::hash_to_point_base();
        let points = vector::empty<ristretto255::RistrettoPoint>();
        vector::push_back(&mut points, ristretto255::basepoint());
        vector::push_back(&mut points, h);
        vector::push_back(&mut points, ristretto255::basepoint());
        vector::push_back(&mut points, ristretto255::hash_to_point_base());
        let scalars = vector::empty<ristretto255::Scalar>();
        vector::push_back(&mut scalars, one);
        vector::push_back(&mut scalars, one);
        vector::push_back(&mut scalars, one);
        vector::push_back(&mut scalars, one);
        let lhs = ristretto255::multi_scalar_mul(&points, &scalars);
        let g2 = ristretto255::basepoint_mul(&two);
        let h2 = ristretto255::point_mul(&ristretto255::hash_to_point_base(), &two);
        let rhs = ristretto255::point_add(&g2, &h2);
        let l_c = ristretto255::point_compress(&lhs);
        let r_c = ristretto255::point_compress(&rhs);
        ristretto255::compressed_point_to_bytes(l_c)
            == ristretto255::compressed_point_to_bytes(r_c)
    }

    /// W.22.07: `point_mul(point_identity, 5) == point_identity`.
    public fun test_ristretto_identity_absorbs_mul_tier3_binding(): bool {
        let s = ristretto255::new_scalar_from_u64(5);
        let id = ristretto255::point_identity();
        let r = ristretto255::point_mul(&id, &s);
        let r_c = ristretto255::point_compress(&r);
        let id_c = ristretto255::point_identity_compressed();
        ristretto255::compressed_point_to_bytes(r_c)
            == ristretto255::compressed_point_to_bytes(id_c)
    }

    /// W.22.08: scalar additive inverse — `scalar_add(a, -a) == 0`.
    public fun test_scalar_add_neg_is_zero_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(12345);
        let na = ristretto255::scalar_neg(&a);
        let sum = ristretto255::scalar_add(&a, &na);
        ristretto255::scalar_to_bytes(&sum)
            == ristretto255::scalar_to_bytes(&ristretto255::scalar_zero())
    }

    /// W.22.09: scalar double negation — `scalar_neg(scalar_neg a) == a`.
    public fun test_scalar_double_neg_identity_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(777);
        let nna = ristretto255::scalar_neg(&ristretto255::scalar_neg(&a));
        ristretto255::scalar_to_bytes(&nna) == ristretto255::scalar_to_bytes(&a)
    }

    /// W.22.10: scalar 0 absorption — `scalar_mul(0, a) == 0`.
    public fun test_scalar_zero_absorbs_mul_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(999);
        let p = ristretto255::scalar_mul(&ristretto255::scalar_zero(), &a);
        ristretto255::scalar_to_bytes(&p)
            == ristretto255::scalar_to_bytes(&ristretto255::scalar_zero())
    }

    /// W.22.11: scalar multiplication commutativity — `a * b == b * a`.
    public fun test_scalar_mul_commutes_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(101);
        let b = ristretto255::new_scalar_from_u64(103);
        let ab = ristretto255::scalar_mul(&a, &b);
        let ba = ristretto255::scalar_mul(&b, &a);
        ristretto255::scalar_to_bytes(&ab) == ristretto255::scalar_to_bytes(&ba)
    }

    /// W.22.12: scalar multiplication associativity — `(a*b)*c == a*(b*c)`.
    public fun test_scalar_mul_associative_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(7);
        let b = ristretto255::new_scalar_from_u64(11);
        let c = ristretto255::new_scalar_from_u64(13);
        let ab = ristretto255::scalar_mul(&a, &b);
        let abc_l = ristretto255::scalar_mul(&ab, &c);
        let bc = ristretto255::scalar_mul(&b, &c);
        let abc_r = ristretto255::scalar_mul(&a, &bc);
        ristretto255::scalar_to_bytes(&abc_l) == ristretto255::scalar_to_bytes(&abc_r)
    }

    /// W.22.13: scalar-1 identity — `scalar_mul(1, a) == a`.
    public fun test_scalar_one_mul_identity_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(314159);
        let p = ristretto255::scalar_mul(&ristretto255::scalar_one(), &a);
        ristretto255::scalar_to_bytes(&p) == ristretto255::scalar_to_bytes(&a)
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.23 — additional core Ristretto natives.
    // W.21/W.22 cover `point_identity`, `basepoint_mul`, `point_mul`,
    // `point_add`, `multi_scalar_mul`, `basepoint_double_mul` and the
    // scalar-field laws. Four production natives remain unbound:
    //   - `point_neg`             (additive inverse for a point);
    //   - `point_sub`             (group subtraction; used inside
    //                              every sigma verifier's response
    //                              equation as `X = MSM_lhs - MSM_rhs`
    //                              after the Fiat-Shamir challenge);
    //   - `point_clone`           (deep-copy required by Move's by-
    //                              reference native ABI; `ciphertext_
    //                              clone` in `twisted_elgamal` bottoms
    //                              out here);
    //   - `double_scalar_mul`     (two-term MSM specialisation used
    //                              inside `verify_*_sigma_proof` when
    //                              the verifier checks one scalar
    //                              equation at a time);
    //   - `new_point_from_sha2_512` (hash-to-point; distinct from
    //                              `hash_to_point_base` which pins a
    //                              fixed DST output);
    //   - `new_scalar_from_bytes` + `scalar_to_bytes` roundtrip.
    //
    // A regression that corrupts `point_neg` or `point_sub` would
    // silently break every sigma verifier's FS-challenge response
    // check while leaving W.21/W.22 intact, because neither calls
    // these natives on specific operand classes. Phase W.23 closes
    // the last Ristretto-native binding gap.
    //
    // 12 new rows × `funcIdx := 40`.
    // ───────────────────────────────────────────────────────────────

    /// W.23.01: `point_add(G, point_neg(G)) == identity`.
    public fun test_ristretto_point_neg_additive_inverse_tier3_binding(): bool {
        let g = ristretto255::basepoint();
        let ng = ristretto255::point_neg(&g);
        let r = ristretto255::point_add(&g, &ng);
        let r_c = ristretto255::point_compress(&r);
        let id = ristretto255::point_identity_compressed();
        ristretto255::compressed_point_to_bytes(r_c)
            == ristretto255::compressed_point_to_bytes(id)
    }

    /// W.23.02: `point_neg(point_neg(G)) == G` — double negation.
    public fun test_ristretto_point_neg_involution_tier3_binding(): bool {
        let g = ristretto255::basepoint();
        let nng = ristretto255::point_neg(&ristretto255::point_neg(&g));
        let lhs_c = ristretto255::point_compress(&nng);
        let rhs_c = ristretto255::point_compress(&g);
        ristretto255::compressed_point_to_bytes(lhs_c)
            == ristretto255::compressed_point_to_bytes(rhs_c)
    }

    /// W.23.03: `point_sub(G, G) == identity`.
    public fun test_ristretto_point_sub_self_is_identity_tier3_binding(): bool {
        let g = ristretto255::basepoint();
        let r = ristretto255::point_sub(&g, &g);
        let r_c = ristretto255::point_compress(&r);
        let id = ristretto255::point_identity_compressed();
        ristretto255::compressed_point_to_bytes(r_c)
            == ristretto255::compressed_point_to_bytes(id)
    }

    /// W.23.04: `point_sub(3G, G) == 2G` — subtraction vs scalar-mul parity.
    public fun test_ristretto_point_sub_scalar_consistency_tier3_binding(): bool {
        let one = ristretto255::scalar_one();
        let two = ristretto255::new_scalar_from_u64(2);
        let three = ristretto255::new_scalar_from_u64(3);
        let _ = one;
        let g3 = ristretto255::basepoint_mul(&three);
        let g1 = ristretto255::basepoint();
        let lhs = ristretto255::point_sub(&g3, &g1);
        let rhs = ristretto255::basepoint_mul(&two);
        let lhs_c = ristretto255::point_compress(&lhs);
        let rhs_c = ristretto255::point_compress(&rhs);
        ristretto255::compressed_point_to_bytes(lhs_c)
            == ristretto255::compressed_point_to_bytes(rhs_c)
    }

    /// W.23.05: `point_sub(G, H) == point_add(G, point_neg(H))` — subtraction
    /// definition via negation (binds `point_sub` as genuine "add negation").
    public fun test_ristretto_point_sub_equals_add_neg_tier3_binding(): bool {
        let g = ristretto255::basepoint();
        let h = ristretto255::hash_to_point_base();
        let lhs = ristretto255::point_sub(&g, &h);
        let nh = ristretto255::point_neg(&h);
        let rhs = ristretto255::point_add(&g, &nh);
        let lhs_c = ristretto255::point_compress(&lhs);
        let rhs_c = ristretto255::point_compress(&rhs);
        ristretto255::compressed_point_to_bytes(lhs_c)
            == ristretto255::compressed_point_to_bytes(rhs_c)
    }

    /// W.23.06: `point_clone(G) == G` — deep-copy correctness.
    public fun test_ristretto_point_clone_equals_source_tier3_binding(): bool {
        let g = ristretto255::basepoint();
        let g_clone = ristretto255::point_clone(&g);
        let l_c = ristretto255::point_compress(&g_clone);
        let r_c = ristretto255::point_compress(&g);
        ristretto255::compressed_point_to_bytes(l_c)
            == ristretto255::compressed_point_to_bytes(r_c)
    }

    /// W.23.07: `point_clone(H) == H` — clone on the hash-to-point base as
    /// well (binds that `point_clone` is not specialised on the basepoint).
    public fun test_ristretto_point_clone_h_equals_h_tier3_binding(): bool {
        let h = ristretto255::hash_to_point_base();
        let h_clone = ristretto255::point_clone(&h);
        let l_c = ristretto255::point_compress(&h_clone);
        let r_c = ristretto255::point_compress(&h);
        ristretto255::compressed_point_to_bytes(l_c)
            == ristretto255::compressed_point_to_bytes(r_c)
    }

    /// W.23.08: `double_scalar_mul(a, G, b, H) == aG + bH` —
    /// specialised 2-term MSM used inside sigma verifiers.
    public fun test_ristretto_double_scalar_mul_basic_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(5);
        let b = ristretto255::new_scalar_from_u64(7);
        let g = ristretto255::basepoint();
        let h = ristretto255::hash_to_point_base();
        let lhs = ristretto255::double_scalar_mul(&a, &g, &b, &h);
        let ag = ristretto255::basepoint_mul(&a);
        let bh = ristretto255::point_mul(&h, &b);
        let rhs = ristretto255::point_add(&ag, &bh);
        let l_c = ristretto255::point_compress(&lhs);
        let r_c = ristretto255::point_compress(&rhs);
        ristretto255::compressed_point_to_bytes(l_c)
            == ristretto255::compressed_point_to_bytes(r_c)
    }

    /// W.23.09: `double_scalar_mul(0, G, 0, H) == identity` — zero-scalar
    /// boundary of the 2-term MSM.
    public fun test_ristretto_double_scalar_mul_zero_tier3_binding(): bool {
        let zero = ristretto255::scalar_zero();
        let g = ristretto255::basepoint();
        let h = ristretto255::hash_to_point_base();
        let r = ristretto255::double_scalar_mul(&zero, &g, &zero, &h);
        let r_c = ristretto255::point_compress(&r);
        let id = ristretto255::point_identity_compressed();
        ristretto255::compressed_point_to_bytes(r_c)
            == ristretto255::compressed_point_to_bytes(id)
    }

    /// W.23.10: `new_point_from_sha2_512` is deterministic — same input,
    /// same point bytes.
    public fun test_ristretto_new_point_from_sha2_512_deterministic_tier3_binding(): bool {
        let input = b"tier3-w23-hash-to-point";
        let p1 = ristretto255::new_point_from_sha2_512(input);
        let p2 = ristretto255::new_point_from_sha2_512(input);
        let c1 = ristretto255::point_compress(&p1);
        let c2 = ristretto255::point_compress(&p2);
        ristretto255::compressed_point_to_bytes(c1)
            == ristretto255::compressed_point_to_bytes(c2)
    }

    /// W.23.11: `new_point_from_sha2_512` distinguishes distinct inputs.
    public fun test_ristretto_new_point_from_sha2_512_distinct_tier3_binding(): bool {
        let p1 = ristretto255::new_point_from_sha2_512(b"tier3-w23-A");
        let p2 = ristretto255::new_point_from_sha2_512(b"tier3-w23-B");
        let c1 = ristretto255::point_compress(&p1);
        let c2 = ristretto255::point_compress(&p2);
        ristretto255::compressed_point_to_bytes(c1)
            != ristretto255::compressed_point_to_bytes(c2)
    }

    /// W.23.12: `new_scalar_from_bytes ∘ scalar_to_bytes == some`
    /// roundtrip on a non-trivial scalar. Binds the canonical
    /// little-endian serialisation surface end-to-end.
    public fun test_scalar_bytes_roundtrip_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(0x0123_4567_89ab_cdef);
        let bytes = ristretto255::scalar_to_bytes(&a);
        let rt_opt = ristretto255::new_scalar_from_bytes(bytes);
        assert!(std::option::is_some(&rt_opt), error::invalid_argument(1));
        let rt = std::option::destroy_some(rt_opt);
        ristretto255::scalar_to_bytes(&rt) == ristretto255::scalar_to_bytes(&a)
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.24 — `*_assign` vs pure-variant parity binding.
    // Every Ristretto / scalar native comes in both a pure variant
    // (`point_add`, `scalar_mul`, …) AND a mutable `*_assign`
    // variant (`point_add_assign`, `scalar_mul_assign`, …) used
    // inside hot-path loops. A regression that corrupts only the
    // `*_assign` variant (e.g. writes the wrong field of the mut
    // reference, or the in-place arithmetic uses the wrong operand
    // order) leaves every W.21 / W.22 / W.23 row intact because
    // they all exercise the pure variants. Phase W.24 closes the
    // last binding gap on the Ristretto native surface.
    //
    // 8 new rows × `funcIdx := 40`.
    // ───────────────────────────────────────────────────────────────

    /// W.24.01: `point_add_assign(p, q) == point_add(p, q)`.
    public fun test_ristretto_point_add_assign_matches_pure_tier3_binding(): bool {
        let g = ristretto255::basepoint();
        let h = ristretto255::hash_to_point_base();
        let pure = ristretto255::point_add(&g, &h);
        let pure_c = ristretto255::point_compress(&pure);
        let mut_p = ristretto255::basepoint();
        ristretto255::point_add_assign(&mut mut_p, &h);
        let mut_c = ristretto255::point_compress(&mut_p);
        ristretto255::compressed_point_to_bytes(mut_c)
            == ristretto255::compressed_point_to_bytes(pure_c)
    }

    /// W.24.02: `point_sub_assign(p, q) == point_sub(p, q)`.
    public fun test_ristretto_point_sub_assign_matches_pure_tier3_binding(): bool {
        let g = ristretto255::basepoint();
        let h = ristretto255::hash_to_point_base();
        let pure = ristretto255::point_sub(&g, &h);
        let pure_c = ristretto255::point_compress(&pure);
        let mut_p = ristretto255::basepoint();
        ristretto255::point_sub_assign(&mut mut_p, &h);
        let mut_c = ristretto255::point_compress(&mut_p);
        ristretto255::compressed_point_to_bytes(mut_c)
            == ristretto255::compressed_point_to_bytes(pure_c)
    }

    /// W.24.03: `point_mul_assign(p, s) == point_mul(p, s)`.
    public fun test_ristretto_point_mul_assign_matches_pure_tier3_binding(): bool {
        let s = ristretto255::new_scalar_from_u64(13);
        let h = ristretto255::hash_to_point_base();
        let pure = ristretto255::point_mul(&h, &s);
        let pure_c = ristretto255::point_compress(&pure);
        let mut_p = ristretto255::hash_to_point_base();
        ristretto255::point_mul_assign(&mut mut_p, &s);
        let mut_c = ristretto255::point_compress(&mut_p);
        ristretto255::compressed_point_to_bytes(mut_c)
            == ristretto255::compressed_point_to_bytes(pure_c)
    }

    /// W.24.04: `point_neg_assign(p) == point_neg(p)`.
    public fun test_ristretto_point_neg_assign_matches_pure_tier3_binding(): bool {
        let h = ristretto255::hash_to_point_base();
        let pure = ristretto255::point_neg(&h);
        let pure_c = ristretto255::point_compress(&pure);
        let mut_p = ristretto255::hash_to_point_base();
        ristretto255::point_neg_assign(&mut mut_p);
        let mut_c = ristretto255::point_compress(&mut_p);
        ristretto255::compressed_point_to_bytes(mut_c)
            == ristretto255::compressed_point_to_bytes(pure_c)
    }

    /// W.24.05: `scalar_add_assign(a, b) == scalar_add(a, b)`.
    public fun test_scalar_add_assign_matches_pure_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(7);
        let b = ristretto255::new_scalar_from_u64(11);
        let pure = ristretto255::scalar_add(&a, &b);
        let mut_a = ristretto255::new_scalar_from_u64(7);
        ristretto255::scalar_add_assign(&mut mut_a, &b);
        ristretto255::scalar_to_bytes(&mut_a) == ristretto255::scalar_to_bytes(&pure)
    }

    /// W.24.06: `scalar_sub_assign(a, b) == scalar_sub(a, b)`.
    public fun test_scalar_sub_assign_matches_pure_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(100);
        let b = ristretto255::new_scalar_from_u64(42);
        let pure = ristretto255::scalar_sub(&a, &b);
        let mut_a = ristretto255::new_scalar_from_u64(100);
        ristretto255::scalar_sub_assign(&mut mut_a, &b);
        ristretto255::scalar_to_bytes(&mut_a) == ristretto255::scalar_to_bytes(&pure)
    }

    /// W.24.07: `scalar_mul_assign(a, b) == scalar_mul(a, b)`.
    public fun test_scalar_mul_assign_matches_pure_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(5);
        let b = ristretto255::new_scalar_from_u64(13);
        let pure = ristretto255::scalar_mul(&a, &b);
        let mut_a = ristretto255::new_scalar_from_u64(5);
        ristretto255::scalar_mul_assign(&mut mut_a, &b);
        ristretto255::scalar_to_bytes(&mut_a) == ristretto255::scalar_to_bytes(&pure)
    }

    /// W.24.08: `scalar_neg_assign(a) == scalar_neg(a)`.
    public fun test_scalar_neg_assign_matches_pure_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(123_456_789);
        let pure = ristretto255::scalar_neg(&a);
        let mut_a = ristretto255::new_scalar_from_u64(123_456_789);
        ristretto255::scalar_neg_assign(&mut mut_a);
        ristretto255::scalar_to_bytes(&mut_a) == ristretto255::scalar_to_bytes(&pure)
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.25 — scalar constructors (u8/u32/u128) + predicates
    // (scalar_is_zero / scalar_is_one / scalar_equals /
    // point_equals) + point compress/decompress roundtrip +
    // `new_point_from_bytes` decoding. W.22/W.23/W.24 cover every
    // binary / unary scalar / point operation; the remaining
    // surface is (a) the non-u64 scalar constructors which carry
    // their own LE-byte encoding paths, (b) the four Boolean
    // predicates which sigma verifiers call from their response
    // equations, (c) the decompression / decode roundtrip the
    // FS-prefix assembly implicitly relies on, and (d) the
    // u32/u128 hash-to-scalar variants that feed chunk-decoded
    // balance scalars into sigma verifiers. A regression in any
    // one of these silently slips past every prior row because
    // none of them feed those natives' output into a byte
    // golden.
    //
    // 14 new rows × `funcIdx := 40`.
    // ───────────────────────────────────────────────────────────────

    /// W.25.01: `new_scalar_from_u8(42) == new_scalar_from_u64(42)` bytes.
    public fun test_scalar_from_u8_matches_u64_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u8(42);
        let b = ristretto255::new_scalar_from_u64(42);
        ristretto255::scalar_to_bytes(&a) == ristretto255::scalar_to_bytes(&b)
    }

    /// W.25.02: `new_scalar_from_u8(0) == scalar_zero()` bytes.
    public fun test_scalar_from_u8_zero_matches_scalar_zero_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u8(0);
        let z = ristretto255::scalar_zero();
        ristretto255::scalar_to_bytes(&a) == ristretto255::scalar_to_bytes(&z)
    }

    /// W.25.03: `new_scalar_from_u32(0xfedc_ba98) == new_scalar_from_u64(0xfedc_ba98)` bytes.
    public fun test_scalar_from_u32_matches_u64_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u32(0xfedc_ba98);
        let b = ristretto255::new_scalar_from_u64(0xfedc_ba98);
        ristretto255::scalar_to_bytes(&a) == ristretto255::scalar_to_bytes(&b)
    }

    /// W.25.04: `new_scalar_from_u128(0x0123_4567_89ab_cdef) == new_scalar_from_u64(0x0123_4567_89ab_cdef)` bytes.
    public fun test_scalar_from_u128_matches_u64_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u128(0x0123_4567_89ab_cdef);
        let b = ristretto255::new_scalar_from_u64(0x0123_4567_89ab_cdef);
        ristretto255::scalar_to_bytes(&a) == ristretto255::scalar_to_bytes(&b)
    }

    /// W.25.05: `scalar_is_zero(scalar_zero()) == true`.
    public fun test_scalar_is_zero_on_zero_tier3_binding(): bool {
        ristretto255::scalar_is_zero(&ristretto255::scalar_zero())
    }

    /// W.25.06: `scalar_is_zero(scalar_one()) == false`.
    public fun test_scalar_is_zero_on_one_is_false_tier3_binding(): bool {
        !ristretto255::scalar_is_zero(&ristretto255::scalar_one())
    }

    /// W.25.07: `scalar_is_one(scalar_one()) == true`.
    public fun test_scalar_is_one_on_one_tier3_binding(): bool {
        ristretto255::scalar_is_one(&ristretto255::scalar_one())
    }

    /// W.25.08: `scalar_is_one(scalar_zero()) == false`.
    public fun test_scalar_is_one_on_zero_is_false_tier3_binding(): bool {
        !ristretto255::scalar_is_one(&ristretto255::scalar_zero())
    }

    /// W.25.09: `scalar_equals(a, a) == true` and `scalar_equals(a, b) == false`.
    public fun test_scalar_equals_refl_and_distinct_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_u64(17);
        let b = ristretto255::new_scalar_from_u64(23);
        ristretto255::scalar_equals(&a, &a) && !ristretto255::scalar_equals(&a, &b)
    }

    /// W.25.10: `point_equals(G, G) == true` and `point_equals(G, H) == false`.
    public fun test_point_equals_refl_and_distinct_tier3_binding(): bool {
        let g = ristretto255::basepoint();
        let h = ristretto255::hash_to_point_base();
        ristretto255::point_equals(&g, &g) && !ristretto255::point_equals(&g, &h)
    }

    /// W.25.11: `point_equals(G, 1·G) == true` — semantic equality
    /// across different construction paths for the same point.
    public fun test_point_equals_semantic_equivalence_tier3_binding(): bool {
        let g = ristretto255::basepoint();
        let one = ristretto255::scalar_one();
        let g_via_mul = ristretto255::basepoint_mul(&one);
        ristretto255::point_equals(&g, &g_via_mul)
    }

    /// W.25.12: compress/decompress roundtrip on `G` produces a
    /// point equal to `G`.
    public fun test_point_compress_decompress_roundtrip_tier3_binding(): bool {
        let g = ristretto255::basepoint();
        let c = ristretto255::point_compress(&g);
        let d = ristretto255::point_decompress(&c);
        ristretto255::point_equals(&d, &g)
    }

    /// W.25.13: `new_point_from_bytes(basepoint_compressed_bytes)` decodes
    /// to `G` — binds the Ristretto decoding path end-to-end against the
    /// fixed basepoint bytes.
    public fun test_new_point_from_bytes_basepoint_tier3_binding(): bool {
        let bp_c = ristretto255::basepoint_compressed();
        let bytes = ristretto255::compressed_point_to_bytes(bp_c);
        let p_opt = ristretto255::new_point_from_bytes(bytes);
        assert!(std::option::is_some(&p_opt), error::invalid_argument(1));
        let p = std::option::destroy_some(p_opt);
        ristretto255::point_equals(&p, &ristretto255::basepoint())
    }

    /// W.25.14: `new_compressed_point_from_bytes` on the 32 zero-bytes
    /// decodes to the Ristretto identity element.
    public fun test_new_compressed_point_from_zero_is_identity_tier3_binding(): bool {
        let zero_bytes = vector[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                                0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                                0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                                0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8];
        let c_opt = ristretto255::new_compressed_point_from_bytes(zero_bytes);
        assert!(std::option::is_some(&c_opt), error::invalid_argument(1));
        let c = std::option::destroy_some(c_opt);
        let id_c = ristretto255::point_identity_compressed();
        ristretto255::compressed_point_to_bytes(c)
            == ristretto255::compressed_point_to_bytes(id_c)
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.26 — twisted ElGamal ciphertext algebra identities.
    // Binds every `ristretto255_twisted_elgamal` native that appears
    // in the confidential-balance encryption / homomorphic sum paths:
    //   * ciphertext_add / ciphertext_sub (group law in 𝔾² under +)
    //   * ciphertext_add_assign / ciphertext_sub_assign parity
    //   * ciphertext_clone  (deep-copy)
    //   * ciphertext_equals (component-wise point equality)
    //   * compress_ciphertext / decompress_ciphertext roundtrip
    //   * ciphertext_to_bytes / new_ciphertext_from_bytes roundtrip
    //   * new_ciphertext_no_randomness is a zero-randomness encoding
    //     of its scalar argument, matching `v·G` on the left and
    //     identity on the right.
    // A regression in any of these silently breaks homomorphic
    // balance accumulation without showing up in any earlier row.
    //
    // Helper `zero_ct_ref_for_tier3` returns a canonical zero-value
    // ciphertext with no randomness — (0·G, 0·G) = (identity, identity).
    //
    // 12 new rows × `funcIdx := 40`.
    // ───────────────────────────────────────────────────────────────

    /// Returns a canonical zero-value, zero-randomness ciphertext
    /// `(0·G, 0·G) = (identity, identity)` used as the additive
    /// identity in `ciphertext_add` binding.
    fun zero_ct_for_tier3(): twisted_elgamal::Ciphertext {
        twisted_elgamal::ciphertext_from_points(
            ristretto255::point_identity(),
            ristretto255::point_identity()
        )
    }

    /// Returns a canonical ciphertext with (G, H) as its components.
    /// Used as a deterministic non-identity witness across tests.
    fun g_h_ct_for_tier3(): twisted_elgamal::Ciphertext {
        twisted_elgamal::ciphertext_from_points(
            ristretto255::basepoint(),
            ristretto255::hash_to_point_base()
        )
    }

    /// Returns a canonical ciphertext with (H, G) as its components.
    /// Distinct from `g_h_ct_for_tier3` to witness component-wise
    /// ordering in `ciphertext_equals`.
    fun h_g_ct_for_tier3(): twisted_elgamal::Ciphertext {
        twisted_elgamal::ciphertext_from_points(
            ristretto255::hash_to_point_base(),
            ristretto255::basepoint()
        )
    }

    /// W.26.01: `ciphertext_add(ct, zero) == ct` via `ciphertext_equals`.
    public fun test_ciphertext_add_identity_tier3_binding(): bool {
        let ct = g_h_ct_for_tier3();
        let zero_ct = zero_ct_for_tier3();
        let sum = twisted_elgamal::ciphertext_add(&ct, &zero_ct);
        twisted_elgamal::ciphertext_equals(&sum, &ct)
    }

    /// W.26.02: `ciphertext_add` is commutative:
    /// `ciphertext_add(a, b) == ciphertext_add(b, a)`.
    public fun test_ciphertext_add_commutative_tier3_binding(): bool {
        let a = g_h_ct_for_tier3();
        let b = h_g_ct_for_tier3();
        let ab = twisted_elgamal::ciphertext_add(&a, &b);
        let ba = twisted_elgamal::ciphertext_add(&b, &a);
        twisted_elgamal::ciphertext_equals(&ab, &ba)
    }

    /// W.26.03: `ciphertext_sub(a, a) == (identity, identity)`.
    public fun test_ciphertext_sub_self_is_zero_tier3_binding(): bool {
        let a = g_h_ct_for_tier3();
        let diff = twisted_elgamal::ciphertext_sub(&a, &a);
        let zero_ct = zero_ct_for_tier3();
        twisted_elgamal::ciphertext_equals(&diff, &zero_ct)
    }

    /// W.26.04: `ciphertext_add(a, ciphertext_sub(b, a)) == b`
    /// — pure group-law associativity of the ElGamal ciphertext space.
    public fun test_ciphertext_add_sub_cancels_tier3_binding(): bool {
        let a = g_h_ct_for_tier3();
        let b = h_g_ct_for_tier3();
        let b_minus_a = twisted_elgamal::ciphertext_sub(&b, &a);
        let back_to_b = twisted_elgamal::ciphertext_add(&a, &b_minus_a);
        twisted_elgamal::ciphertext_equals(&back_to_b, &b)
    }

    /// W.26.05: `ciphertext_add_assign(a, b) == ciphertext_add(a, b)`
    /// bytes — in-place variant matches pure variant.
    public fun test_ciphertext_add_assign_matches_pure_tier3_binding(): bool {
        let a = g_h_ct_for_tier3();
        let b = h_g_ct_for_tier3();
        let pure = twisted_elgamal::ciphertext_add(&a, &b);
        let mut_a = g_h_ct_for_tier3();
        twisted_elgamal::ciphertext_add_assign(&mut mut_a, &b);
        twisted_elgamal::ciphertext_to_bytes(&mut_a)
            == twisted_elgamal::ciphertext_to_bytes(&pure)
    }

    /// W.26.06: `ciphertext_sub_assign(a, b) == ciphertext_sub(a, b)`
    /// bytes — in-place variant matches pure variant.
    public fun test_ciphertext_sub_assign_matches_pure_tier3_binding(): bool {
        let a = g_h_ct_for_tier3();
        let b = h_g_ct_for_tier3();
        let pure = twisted_elgamal::ciphertext_sub(&a, &b);
        let mut_a = g_h_ct_for_tier3();
        twisted_elgamal::ciphertext_sub_assign(&mut mut_a, &b);
        twisted_elgamal::ciphertext_to_bytes(&mut_a)
            == twisted_elgamal::ciphertext_to_bytes(&pure)
    }

    /// W.26.07: `ciphertext_clone(a) == a` via `ciphertext_equals`.
    public fun test_ciphertext_clone_matches_original_tier3_binding(): bool {
        let a = g_h_ct_for_tier3();
        let a_clone = twisted_elgamal::ciphertext_clone(&a);
        twisted_elgamal::ciphertext_equals(&a_clone, &a)
    }

    /// W.26.08: `ciphertext_equals` reflexivity + component-wise
    /// sensitivity. `(G, H) ≠ (H, G)` witnesses left/right order.
    public fun test_ciphertext_equals_refl_and_order_sensitive_tier3_binding(): bool {
        let a = g_h_ct_for_tier3();
        let b = h_g_ct_for_tier3();
        twisted_elgamal::ciphertext_equals(&a, &a)
            && !twisted_elgamal::ciphertext_equals(&a, &b)
    }

    /// W.26.09: compress / decompress roundtrip — `decompress_ciphertext
    /// (compress_ciphertext(a))` is `ciphertext_equals` to `a`.
    public fun test_ciphertext_compress_decompress_roundtrip_tier3_binding(): bool {
        let a = g_h_ct_for_tier3();
        let c = twisted_elgamal::compress_ciphertext(&a);
        let d = twisted_elgamal::decompress_ciphertext(&c);
        twisted_elgamal::ciphertext_equals(&d, &a)
    }

    /// W.26.10: bytes roundtrip — `new_ciphertext_from_bytes
    /// (ciphertext_to_bytes(a))` is `Some(a′)` with a′ byte-equal to a.
    public fun test_ciphertext_bytes_roundtrip_tier3_binding(): bool {
        let a = g_h_ct_for_tier3();
        let bytes = twisted_elgamal::ciphertext_to_bytes(&a);
        let rt_opt = twisted_elgamal::new_ciphertext_from_bytes(bytes);
        assert!(std::option::is_some(&rt_opt), error::invalid_argument(1));
        let rt = std::option::destroy_some(rt_opt);
        twisted_elgamal::ciphertext_to_bytes(&rt)
            == twisted_elgamal::ciphertext_to_bytes(&a)
    }

    /// W.26.11: `new_ciphertext_no_randomness(v)` produces a ciphertext
    /// whose left component equals `v·G` and right component equals
    /// identity. Specifically tested with `v == scalar_zero()` yielding
    /// `(identity, identity)`.
    public fun test_ciphertext_no_randomness_zero_is_identity_ct_tier3_binding(): bool {
        let zero_s = ristretto255::scalar_zero();
        let ct = twisted_elgamal::new_ciphertext_no_randomness(&zero_s);
        let zero_ct = zero_ct_for_tier3();
        twisted_elgamal::ciphertext_equals(&ct, &zero_ct)
    }

    /// W.26.12: `new_ciphertext_no_randomness(1) == (G, identity)`.
    public fun test_ciphertext_no_randomness_one_is_G_identity_tier3_binding(): bool {
        let one_s = ristretto255::scalar_one();
        let ct = twisted_elgamal::new_ciphertext_no_randomness(&one_s);
        let expected = twisted_elgamal::ciphertext_from_points(
            ristretto255::basepoint(),
            ristretto255::point_identity()
        );
        twisted_elgamal::ciphertext_equals(&ct, &expected)
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.27 — confidential_balance module binding + chunk-
    // scalar algebraic identities (`split_into_chunks_u64`,
    // `split_into_chunks_u128`). This module is the direct consumer
    // of every primitive bound by W.21–W.26 but had no direct
    // tier-3 rows of its own. Covers:
    //   * new_pending_balance_no_randomness / new_actual_balance_no_randomness
    //     → is_zero_balance, balance_equals
    //   * compress_balance / decompress_balance roundtrip via balance_equals
    //   * balance_to_bytes / new_pending_balance_from_bytes roundtrip
    //   * balance_to_points_c / balance_to_points_d chunk-component
    //     decomposition (4 chunks × pending, 8 chunks × actual)
    //   * add_balances_mut / sub_balances_mut additive-inverse cancel
    //   * balance_c_equals vs balance_equals ordering sensitivity
    //   * split_into_chunks_u64(0) is 4 zero-scalars
    //   * split_into_chunks_u64(0xffff) top-of-chunk-0 boundary
    //   * split_into_chunks_u128 little-endian ordering on a
    //     non-uniform 128-bit witness
    //
    // 11 new rows × `funcIdx := 40`.
    // ───────────────────────────────────────────────────────────────

    /// W.27.01: `is_zero_balance(new_pending_balance_no_randomness())` is `true`.
    public fun test_pending_balance_no_randomness_is_zero_tier3_binding(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        confidential_balance::is_zero_balance(&b)
    }

    /// W.27.02: `is_zero_balance(new_actual_balance_no_randomness())` is `true`.
    public fun test_actual_balance_no_randomness_is_zero_tier3_binding(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::is_zero_balance(&b)
    }

    /// W.27.03: compress_balance ∘ decompress_balance is identity on
    /// a zero pending balance via `balance_equals`.
    public fun test_balance_compress_decompress_roundtrip_tier3_binding(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let c = confidential_balance::compress_balance(&b);
        let d = confidential_balance::decompress_balance(&c);
        confidential_balance::balance_equals(&b, &d)
    }

    /// W.27.04: `balance_to_bytes` then `new_pending_balance_from_bytes`
    /// is `Some(_)` with bytes-equal balance.
    public fun test_pending_balance_bytes_roundtrip_tier3_binding(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let bytes = confidential_balance::balance_to_bytes(&b);
        let rt_opt = confidential_balance::new_pending_balance_from_bytes(bytes);
        assert!(std::option::is_some(&rt_opt), error::invalid_argument(1));
        let rt = std::option::destroy_some(rt_opt);
        let bytes_rt = confidential_balance::balance_to_bytes(&rt);
        bytes_rt == confidential_balance::balance_to_bytes(&b)
    }

    /// W.27.05: `balance_to_points_c` on a zero pending balance has
    /// length 4 (`PENDING_BALANCE_CHUNKS`) and every element equals
    /// the Ristretto identity.
    public fun test_pending_balance_to_points_c_zero_is_identities_tier3_binding(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let pts = confidential_balance::balance_to_points_c(&b);
        if (vector::length(&pts) != confidential_balance::get_pending_balance_chunks()) {
            return false
        };
        let id = ristretto255::point_identity();
        let i = 0;
        let ok = true;
        while (i < vector::length(&pts)) {
            let p = vector::borrow(&pts, i);
            ok = ok && ristretto255::point_equals(p, &id);
            i = i + 1;
        };
        ok
    }

    /// W.27.06: `balance_to_points_d` on a zero actual balance has
    /// length 8 (`ACTUAL_BALANCE_CHUNKS`) and every element equals
    /// the Ristretto identity.
    public fun test_actual_balance_to_points_d_zero_is_identities_tier3_binding(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        let pts = confidential_balance::balance_to_points_d(&b);
        if (vector::length(&pts) != confidential_balance::get_actual_balance_chunks()) {
            return false
        };
        let id = ristretto255::point_identity();
        let i = 0;
        let ok = true;
        while (i < vector::length(&pts)) {
            let p = vector::borrow(&pts, i);
            ok = ok && ristretto255::point_equals(p, &id);
            i = i + 1;
        };
        ok
    }

    /// W.27.07: `add_balances_mut(a, a)` then `sub_balances_mut(a, a)`
    /// leaves the balance equal to the original. Witnesses the
    /// additive-inverse cancellation of the homomorphic balance group.
    public fun test_balance_add_then_sub_is_noop_tier3_binding(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(
            0x0000_0000_0000_0042
        );
        let a_snapshot_bytes = confidential_balance::balance_to_bytes(&a);
        let rhs = confidential_balance::new_pending_balance_u64_no_randonmess(
            0x0000_0000_0000_0042
        );
        confidential_balance::add_balances_mut(&mut a, &rhs);
        confidential_balance::sub_balances_mut(&mut a, &rhs);
        confidential_balance::balance_to_bytes(&a) == a_snapshot_bytes
    }

    /// W.27.08: `balance_c_equals` is weaker than `balance_equals`:
    /// two balances with identical `C`-components but different
    /// `D`-components satisfy `balance_c_equals` but NOT
    /// `balance_equals`. Constructed via
    /// `new_pending_balance_u64_no_randonmess(v)` (D = identity) vs
    /// manual `(v·G, 1·G)` on each chunk (D = G ≠ identity).
    public fun test_balance_c_equals_is_weaker_than_balance_equals_tier3_binding(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(0xffff);
        // Rebuild `b` with the same `C`-components as `a` but with
        // `D = G` on each chunk. We do this by serializing `a`,
        // then overwriting each 64-byte chunk's right-half
        // (bytes 32..64) with the basepoint's compressed bytes.
        let bytes_a = confidential_balance::balance_to_bytes(&a);
        let bp_c = ristretto255::basepoint_compressed();
        let bp_bytes = ristretto255::compressed_point_to_bytes(bp_c);
        let chunks_n = confidential_balance::get_pending_balance_chunks();
        let bytes_b = vector::empty<u8>();
        let i = 0;
        while (i < chunks_n) {
            let off = i * 64;
            let j = 0;
            while (j < 32) {
                vector::push_back(&mut bytes_b, *vector::borrow(&bytes_a, off + j));
                j = j + 1;
            };
            let k = 0;
            while (k < 32) {
                vector::push_back(&mut bytes_b, *vector::borrow(&bp_bytes, k));
                k = k + 1;
            };
            i = i + 1;
        };
        let b_opt = confidential_balance::new_pending_balance_from_bytes(bytes_b);
        assert!(std::option::is_some(&b_opt), error::invalid_argument(1));
        let b = std::option::destroy_some(b_opt);
        confidential_balance::balance_c_equals(&a, &b)
            && !confidential_balance::balance_equals(&a, &b)
    }

    /// W.27.09: `split_into_chunks_u64(0)` yields exactly 4 zero-
    /// scalars.
    public fun test_split_into_chunks_u64_zero_is_zeros_tier3_binding(): bool {
        let chunks = confidential_balance::split_into_chunks_u64(0);
        if (vector::length(&chunks) != confidential_balance::get_pending_balance_chunks()) {
            return false
        };
        let z = ristretto255::scalar_zero();
        let ok = true;
        let i = 0;
        while (i < vector::length(&chunks)) {
            ok = ok && ristretto255::scalar_equals(vector::borrow(&chunks, i), &z);
            i = i + 1;
        };
        ok
    }

    /// W.27.10: `split_into_chunks_u64(0xffff)` yields `[0xffff, 0, 0, 0]`
    /// — top-of-chunk-0 boundary witness (masks propagate correctly).
    public fun test_split_into_chunks_u64_0xffff_boundary_tier3_binding(): bool {
        let chunks = confidential_balance::split_into_chunks_u64(0xffff);
        if (vector::length(&chunks) != confidential_balance::get_pending_balance_chunks()) {
            return false
        };
        let expected0 = ristretto255::new_scalar_from_u64(0xffff);
        let z = ristretto255::scalar_zero();
        ristretto255::scalar_equals(vector::borrow(&chunks, 0), &expected0)
            && ristretto255::scalar_equals(vector::borrow(&chunks, 1), &z)
            && ristretto255::scalar_equals(vector::borrow(&chunks, 2), &z)
            && ristretto255::scalar_equals(vector::borrow(&chunks, 3), &z)
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.28 — hash-to-scalar / hash-to-point / reduced /
    // uniform scalar constructors. The remaining Ristretto native
    // surface area that W.21–W.27 didn't cover: the five scalar-
    // bytes constructors that feed Fiat–Shamir challenges
    // (`new_scalar_from_sha2_512`, its deprecated alias
    // `new_scalar_from_sha512`, `new_scalar_uniform_from_64_bytes`,
    // `new_scalar_reduced_from_32_bytes`) plus the 64-byte-uniform
    // point decoder `new_point_from_64_uniform_bytes`. A regression
    // in the hash-to-scalar path silently shifts every sigma
    // challenge and breaks all four verifiers' soundness; prior
    // rows bound FS-message byte prefixes but did NOT bind the
    // scalar-conversion output itself. W.28 pins: (i) algebraic
    // equivalence between the deprecated alias and its canonical
    // name, (ii) input-distinguishing determinism (same input ⇒
    // same scalar bytes; distinct inputs ⇒ distinct scalar bytes),
    // (iii) uniform-from-64-bytes on the zero 64-byte input equals
    // `scalar_zero()`, (iv) reduced-from-32-bytes on zero 32-byte
    // input equals `scalar_zero()`, (v) `new_point_from_64_uniform_bytes`
    // on zero 64-byte input is `Some(·)` and deterministic (two
    // calls with the same bytes decode to `point_equals` points).
    //
    // 8 new rows × `funcIdx := 40`.
    // ───────────────────────────────────────────────────────────────

    /// W.28.01: `new_scalar_from_sha512(x)` (deprecated alias) is
    /// byte-equal to `new_scalar_from_sha2_512(x)`.
    public fun test_new_scalar_from_sha512_alias_matches_canonical_tier3_binding(): bool {
        let x = b"deadbeef";
        let a = ristretto255::new_scalar_from_sha512(x);
        let b = ristretto255::new_scalar_from_sha2_512(x);
        ristretto255::scalar_to_bytes(&a) == ristretto255::scalar_to_bytes(&b)
    }

    /// W.28.02: `new_scalar_from_sha2_512` is deterministic on the
    /// same input.
    public fun test_new_scalar_from_sha2_512_deterministic_tier3_binding(): bool {
        let x = b"tier3-w28-determinism";
        let a = ristretto255::new_scalar_from_sha2_512(x);
        let b = ristretto255::new_scalar_from_sha2_512(x);
        ristretto255::scalar_equals(&a, &b)
    }

    /// W.28.03: `new_scalar_from_sha2_512` yields distinct scalars
    /// on distinct inputs (byte-inequality + `scalar_equals` = false).
    public fun test_new_scalar_from_sha2_512_distinct_inputs_tier3_binding(): bool {
        let a = ristretto255::new_scalar_from_sha2_512(b"alpha");
        let b = ristretto255::new_scalar_from_sha2_512(b"beta");
        !ristretto255::scalar_equals(&a, &b)
            && ristretto255::scalar_to_bytes(&a) != ristretto255::scalar_to_bytes(&b)
    }

    /// W.28.04: `new_scalar_uniform_from_64_bytes(0_{64B})` yields
    /// `Some(scalar_zero())` — binds the 64-byte uniform reduction
    /// path against the canonical zero element of `ℤ/ℓ`.
    public fun test_new_scalar_uniform_from_64_bytes_zero_is_scalar_zero_tier3_binding(): bool {
        let zero64 = vector[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8];
        let s_opt = ristretto255::new_scalar_uniform_from_64_bytes(zero64);
        assert!(std::option::is_some(&s_opt), error::invalid_argument(1));
        let s = std::option::destroy_some(s_opt);
        let z = ristretto255::scalar_zero();
        ristretto255::scalar_equals(&s, &z)
    }

    /// W.28.05: `new_scalar_reduced_from_32_bytes(0_{32B})` yields
    /// `Some(scalar_zero())`.
    public fun test_new_scalar_reduced_from_32_bytes_zero_is_scalar_zero_tier3_binding(): bool {
        let zero32 = vector[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8];
        let s_opt = ristretto255::new_scalar_reduced_from_32_bytes(zero32);
        assert!(std::option::is_some(&s_opt), error::invalid_argument(1));
        let s = std::option::destroy_some(s_opt);
        let z = ristretto255::scalar_zero();
        ristretto255::scalar_equals(&s, &z)
    }

    /// W.28.06: `new_point_from_64_uniform_bytes(0_{64B})` is
    /// `Some(·)` and the decoded point is deterministic across
    /// repeated calls.
    public fun test_new_point_from_64_uniform_bytes_zero_determinism_tier3_binding(): bool {
        let zero64 = vector[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                            0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8];
        let p1_opt = ristretto255::new_point_from_64_uniform_bytes(zero64);
        let zero64_b = vector[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                              0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                              0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                              0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                              0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                              0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                              0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                              0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8];
        let p2_opt = ristretto255::new_point_from_64_uniform_bytes(zero64_b);
        assert!(std::option::is_some(&p1_opt), error::invalid_argument(1));
        assert!(std::option::is_some(&p2_opt), error::invalid_argument(1));
        let p1 = std::option::destroy_some(p1_opt);
        let p2 = std::option::destroy_some(p2_opt);
        ristretto255::point_equals(&p1, &p2)
    }

    /// W.28.07: `new_point_from_64_uniform_bytes` produces DISTINCT
    /// points on distinct inputs. Catches a regression where the
    /// decoder ignores the input bytes.
    public fun test_new_point_from_64_uniform_bytes_distinct_inputs_tier3_binding(): bool {
        let a = vector[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8];
        let b = vector[1u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8];
        let p1_opt = ristretto255::new_point_from_64_uniform_bytes(a);
        let p2_opt = ristretto255::new_point_from_64_uniform_bytes(b);
        assert!(std::option::is_some(&p1_opt), error::invalid_argument(1));
        assert!(std::option::is_some(&p2_opt), error::invalid_argument(1));
        let p1 = std::option::destroy_some(p1_opt);
        let p2 = std::option::destroy_some(p2_opt);
        !ristretto255::point_equals(&p1, &p2)
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.29 — hash-to-scalar composition identity +
    // `aptos_hash::sha2_512` primitive pins. `new_scalar_from_sha2_512
    // (x)` is defined by the Rust side as `Scalar::hash_from_bytes::
    // <Sha512>(&x)` which is algebraically equal to `Scalar::
    // from_bytes_mod_order_wide(sha2_512(x))` — i.e. it internally
    // applies SHA2-512 then reduces mod ℓ. The corresponding Move
    // surface composition `new_scalar_uniform_from_64_bytes
    // (aptos_hash::sha2_512(x))` hits exactly that same reduction
    // path. Binding these two code paths to produce the SAME scalar
    // bytes pins the correctness of both `aptos_hash::sha2_512`
    // (every FS challenge flows through it) and the Curve25519
    // canonical reduction used by every sigma verifier. Also pins
    // `sha2_512` output length (64) and input-sensitivity.
    //
    // 5 new rows × `funcIdx := 40`.
    // ───────────────────────────────────────────────────────────────

    /// W.29.01: `new_scalar_from_sha2_512(x) ==
    /// new_scalar_uniform_from_64_bytes(aptos_hash::sha2_512(x))`
    /// byte-equal on a non-trivial input. Binds the entire
    /// SHA2-512 → mod-ℓ reduction chain against its surface
    /// decomposition.
    public fun test_new_scalar_from_sha2_512_eq_uniform_of_sha2_512_tier3_binding(): bool {
        let x = b"aptos-confidential-assets-W29-01";
        let a = ristretto255::new_scalar_from_sha2_512(x);
        let hx = aptos_hash::sha2_512(x);
        let b_opt = ristretto255::new_scalar_uniform_from_64_bytes(hx);
        assert!(std::option::is_some(&b_opt), error::invalid_argument(1));
        let b = std::option::destroy_some(b_opt);
        ristretto255::scalar_to_bytes(&a) == ristretto255::scalar_to_bytes(&b)
    }

    /// W.29.02: same composition identity on a different non-
    /// trivial input — catches a regression where one of the two
    /// paths ignores input bytes but not the other.
    public fun test_new_scalar_from_sha2_512_eq_uniform_of_sha2_512_alt_tier3_binding(): bool {
        let x = b"alternative-input-W29-02-some-payload-bytes";
        let a = ristretto255::new_scalar_from_sha2_512(x);
        let hx = aptos_hash::sha2_512(x);
        let b_opt = ristretto255::new_scalar_uniform_from_64_bytes(hx);
        assert!(std::option::is_some(&b_opt), error::invalid_argument(1));
        let b = std::option::destroy_some(b_opt);
        ristretto255::scalar_to_bytes(&a) == ristretto255::scalar_to_bytes(&b)
    }

    /// W.29.03: `aptos_hash::sha2_512` output is exactly 64 bytes.
    public fun test_aptos_hash_sha2_512_output_len_is_64_tier3_binding(): bool {
        let h = aptos_hash::sha2_512(b"w29-len-witness");
        vector::length(&h) == 64
    }

    /// W.29.04: `aptos_hash::sha2_512` is deterministic — same
    /// input yields byte-equal output across repeated calls.
    public fun test_aptos_hash_sha2_512_deterministic_tier3_binding(): bool {
        let x = b"w29-determinism-witness";
        aptos_hash::sha2_512(x) == aptos_hash::sha2_512(x)
    }

    /// W.29.05: `aptos_hash::sha2_512` differs on distinct inputs.
    public fun test_aptos_hash_sha2_512_distinct_inputs_tier3_binding(): bool {
        aptos_hash::sha2_512(b"alpha-W29-05") != aptos_hash::sha2_512(b"beta-W29-05")
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.30 — Bulletproofs + Pedersen commitment public surface.
    // Covers the remaining publicly-callable functions in
    // `ristretto255_bulletproofs` and `ristretto255_pedersen` that
    // sigma + range-proof verifiers depend on transitively but that
    // no prior Tier 3 row bound directly. Structurally the
    // `prove_*` / `verify_*_range_proof` happy-path is blocked (the
    // provers are `#[test_only]`), so we bind the surrounding
    // algebraic surface — byte-roundtrips, constant pins, and full
    // Pedersen commitment group algebra. A regression inside any
    // of these would break every confidential-proof range proof
    // silently because the prior Tier 3 rows don't exercise them.
    //
    // 14 new rows × `funcIdx := 40`.
    // ───────────────────────────────────────────────────────────────

    /// W.30.01: `ristretto255_bulletproofs::get_max_range_bits() == 64`.
    /// Pins the MAX_RANGE_BITS constant against a Lean `ldTrue`
    /// witness; any drift to a different constant flips the row.
    public fun test_bp_get_max_range_bits_is_64_tier3_binding(): bool {
        ristretto255_bulletproofs::get_max_range_bits() == 64
    }

    /// W.30.02: `range_proof_to_bytes ∘ range_proof_from_bytes` is
    /// the identity on byte sequences (on an empty input).
    public fun test_bp_range_proof_empty_bytes_roundtrip_tier3_binding(): bool {
        let empty = vector::empty<u8>();
        let rp = ristretto255_bulletproofs::range_proof_from_bytes(empty);
        let out = ristretto255_bulletproofs::range_proof_to_bytes(&rp);
        vector::length(&out) == 0
    }

    /// W.30.03: same roundtrip identity on a non-trivial byte
    /// sequence (`[0u8, 1u8, …, 31u8]`).
    public fun test_bp_range_proof_nontrivial_bytes_roundtrip_tier3_binding(): bool {
        let bytes = vector[0u8, 1u8, 2u8, 3u8, 4u8, 5u8, 6u8, 7u8,
                           8u8, 9u8, 10u8, 11u8, 12u8, 13u8, 14u8, 15u8,
                           16u8, 17u8, 18u8, 19u8, 20u8, 21u8, 22u8, 23u8,
                           24u8, 25u8, 26u8, 27u8, 28u8, 29u8, 30u8, 31u8];
        let rp = ristretto255_bulletproofs::range_proof_from_bytes(bytes);
        let out = ristretto255_bulletproofs::range_proof_to_bytes(&rp);
        out == vector[0u8, 1u8, 2u8, 3u8, 4u8, 5u8, 6u8, 7u8,
                      8u8, 9u8, 10u8, 11u8, 12u8, 13u8, 14u8, 15u8,
                      16u8, 17u8, 18u8, 19u8, 20u8, 21u8, 22u8, 23u8,
                      24u8, 25u8, 26u8, 27u8, 28u8, 29u8, 30u8, 31u8]
    }

    /// Helper: Pedersen commitment `(v=1, r=0)` under the default
    /// Bulletproofs commitment key `(G, H)`. Equivalent to
    /// `1·G + 0·H = G` — one of the most deterministic non-zero
    /// witnesses the Pedersen surface admits.
    fun pc_one_zero_for_tier3(): ristretto255_pedersen::Commitment {
        ristretto255_pedersen::new_commitment_for_bulletproof(
            &ristretto255::scalar_one(),
            &ristretto255::scalar_zero()
        )
    }

    /// Helper: Pedersen commitment `(v=2, r=0)`.
    fun pc_two_zero_for_tier3(): ristretto255_pedersen::Commitment {
        ristretto255_pedersen::new_commitment_for_bulletproof(
            &ristretto255::new_scalar_from_u64(2),
            &ristretto255::scalar_zero()
        )
    }

    /// Helper: Pedersen commitment `(v=0, r=0) = identity`.
    fun pc_zero_for_tier3(): ristretto255_pedersen::Commitment {
        ristretto255_pedersen::new_commitment_for_bulletproof(
            &ristretto255::scalar_zero(),
            &ristretto255::scalar_zero()
        )
    }

    /// W.30.04: `new_commitment_for_bulletproof(0, 0)` produces a
    /// commitment whose underlying point is the Ristretto identity.
    /// A regression in the base-point selection inside
    /// `new_commitment_for_bulletproof` (e.g. using a different
    /// base) would leave this point non-identity.
    public fun test_pedersen_zero_commitment_is_identity_point_tier3_binding(): bool {
        let c = pc_zero_for_tier3();
        let p = ristretto255_pedersen::commitment_as_point(&c);
        ristretto255::point_equals(p, &ristretto255::point_identity())
    }

    /// W.30.05: `new_commitment_for_bulletproof(1, 0)` produces a
    /// commitment whose underlying point equals `G` (the Ristretto
    /// basepoint) — binds the `val_base = G` choice inside
    /// `new_commitment_for_bulletproof`.
    public fun test_pedersen_one_zero_commitment_is_basepoint_tier3_binding(): bool {
        let c = pc_one_zero_for_tier3();
        let p = ristretto255_pedersen::commitment_as_point(&c);
        ristretto255::point_equals(p, &ristretto255::basepoint())
    }

    /// W.30.06: `commitment_add(a, b) == commitment_add(b, a)` via
    /// `commitment_equals` — Pedersen commitment addition
    /// commutativity.
    public fun test_pedersen_commitment_add_commutative_tier3_binding(): bool {
        let a = pc_one_zero_for_tier3();
        let b = pc_two_zero_for_tier3();
        let ab = ristretto255_pedersen::commitment_add(&a, &b);
        let ba = ristretto255_pedersen::commitment_add(&b, &a);
        ristretto255_pedersen::commitment_equals(&ab, &ba)
    }

    /// W.30.07: `commitment_sub(a, a) == zero_commitment` via
    /// `commitment_equals`. Catches `commitment_sub` aliased to
    /// `commitment_add`.
    public fun test_pedersen_commitment_sub_self_is_zero_tier3_binding(): bool {
        let a = pc_one_zero_for_tier3();
        let diff = ristretto255_pedersen::commitment_sub(&a, &a);
        let zc = pc_zero_for_tier3();
        ristretto255_pedersen::commitment_equals(&diff, &zc)
    }

    /// W.30.08: `commitment_add(pc(1), pc(2)) == pc(3)` via
    /// `commitment_equals` — homomorphic addition on non-trivial
    /// inputs.
    public fun test_pedersen_commitment_add_matches_scalar_add_tier3_binding(): bool {
        let a = pc_one_zero_for_tier3();
        let b = pc_two_zero_for_tier3();
        let sum = ristretto255_pedersen::commitment_add(&a, &b);
        let expected = ristretto255_pedersen::new_commitment_for_bulletproof(
            &ristretto255::new_scalar_from_u64(3),
            &ristretto255::scalar_zero()
        );
        ristretto255_pedersen::commitment_equals(&sum, &expected)
    }

    /// W.30.09: `commitment_add_assign(a, b) == commitment_add(a, b)`
    /// via `commitment_equals` — in-place variant matches pure.
    public fun test_pedersen_commitment_add_assign_matches_pure_tier3_binding(): bool {
        let a = pc_one_zero_for_tier3();
        let b = pc_two_zero_for_tier3();
        let pure = ristretto255_pedersen::commitment_add(&a, &b);
        let mut_a = pc_one_zero_for_tier3();
        ristretto255_pedersen::commitment_add_assign(&mut mut_a, &b);
        ristretto255_pedersen::commitment_equals(&mut_a, &pure)
    }

    /// W.30.10: `commitment_sub_assign(a, b) == commitment_sub(a, b)`
    /// via `commitment_equals`.
    public fun test_pedersen_commitment_sub_assign_matches_pure_tier3_binding(): bool {
        let a = pc_two_zero_for_tier3();
        let b = pc_one_zero_for_tier3();
        let pure = ristretto255_pedersen::commitment_sub(&a, &b);
        let mut_a = pc_two_zero_for_tier3();
        ristretto255_pedersen::commitment_sub_assign(&mut mut_a, &b);
        ristretto255_pedersen::commitment_equals(&mut_a, &pure)
    }

    /// W.30.11: `commitment_clone(c)` equals the original via
    /// `commitment_equals`.
    public fun test_pedersen_commitment_clone_matches_original_tier3_binding(): bool {
        let c = pc_one_zero_for_tier3();
        let c2 = ristretto255_pedersen::commitment_clone(&c);
        ristretto255_pedersen::commitment_equals(&c, &c2)
    }

    /// W.30.12: `commitment_equals` is reflexive and sensitive —
    /// `pc(1) != pc(2)` witnesses that the predicate isn't a
    /// constant `true`.
    public fun test_pedersen_commitment_equals_reflexive_and_sensitive_tier3_binding(): bool {
        let a = pc_one_zero_for_tier3();
        let b = pc_two_zero_for_tier3();
        ristretto255_pedersen::commitment_equals(&a, &a)
            && !ristretto255_pedersen::commitment_equals(&a, &b)
    }

    /// W.30.13: `commitment_as_compressed_point(c)` matches
    /// `point_compress(commitment_as_point(c))` byte-for-byte on
    /// `pc(1, 0)`. Binds the two access paths to agree.
    public fun test_pedersen_commitment_as_point_vs_compressed_coherent_tier3_binding(): bool {
        let c = pc_one_zero_for_tier3();
        let p = ristretto255_pedersen::commitment_as_point(&c);
        let cp_a = ristretto255_pedersen::commitment_as_compressed_point(&c);
        let cp_b = ristretto255::point_compress(p);
        ristretto255::compressed_point_to_bytes(cp_a)
            == ristretto255::compressed_point_to_bytes(cp_b)
    }

    /// W.30.14: `randomness_base_for_bulletproof()` equals the
    /// `ristretto255::hash_to_point_base()` — binds the Bulletproofs
    /// `rand_base = H` convention against the one used inside
    /// `confidential_proof` sigma verifiers. A silent re-pointing
    /// of the randomness base to a different point would make every
    /// Pedersen commitment and every range proof systematically
    /// wrong while keeping `get_max_range_bits` and other constant
    /// pins green.
    public fun test_pedersen_randomness_base_matches_hash_to_point_base_tier3_binding(): bool {
        let h_bp = ristretto255_pedersen::randomness_base_for_bulletproof();
        let h_r = ristretto255::hash_to_point_base();
        ristretto255::point_equals(&h_bp, &h_r)
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.31 — remaining Pedersen commitment constructors /
    // accessors / byte-surface + base-point / semantic algebraic
    // identities. W.30 bound the commitment group algebra (add/sub
    // /equals/clone/*_assign) and two constant pins. W.31 closes
    // the last untested surface:
    //   * `new_commitment(v, val_base, r, rand_base)` equals
    //     `double_scalar_mul(v, val_base, r, rand_base)` as a point.
    //     Binds the *Rust* `double_scalar_mul_internal` native against
    //     the Pedersen surface-level convention.
    //   * `new_commitment_for_bulletproof(v, r)` equals
    //     `new_commitment(v, G, r, H)` via `commitment_equals` —
    //     base-point specification coherence.
    //   * `new_commitment_with_basepoint(v, r, H) == new_commitment_for_bulletproof(v, r)`.
    //   * `commitment_from_point(p)` has `commitment_as_point` equal
    //     to `p` via `point_equals` — underscore-accessor coherence.
    //   * `commitment_from_compressed(compressed_G)` yields a
    //     commitment whose `as_point` equals `G` (basepoint).
    //   * `new_commitment_from_bytes(commitment_to_bytes(c))` is
    //     `Some(c)` and byte-equal (serialization roundtrip on
    //     non-trivial input).
    //   * `new_commitment_from_bytes(all-zero-32B)` is `Some(·)` and
    //     decodes to the identity-commitment (canonical zero).
    //   * `commitment_into_point` and `commitment_as_point` agree
    //     on a cloned commitment (`commitment_into_*` consumes).
    //
    // 10 new rows × `funcIdx := 40`.
    // ───────────────────────────────────────────────────────────────

    /// W.31.01: `new_commitment(v, G, r, H) ==
    /// double_scalar_mul(v, G, r, H)` as a Ristretto point on a
    /// non-trivial input `(v=3, r=5)`.
    public fun test_pedersen_new_commitment_matches_double_scalar_mul_tier3_binding(): bool {
        let v = ristretto255::new_scalar_from_u64(3);
        let r = ristretto255::new_scalar_from_u64(5);
        let g = ristretto255::basepoint();
        let h = ristretto255::hash_to_point_base();
        let c = ristretto255_pedersen::new_commitment(&v, &g, &r, &h);
        let p_c = ristretto255_pedersen::commitment_as_point(&c);
        let expected = ristretto255::double_scalar_mul(&v, &g, &r, &h);
        ristretto255::point_equals(p_c, &expected)
    }

    /// W.31.02: `new_commitment_for_bulletproof(v, r) ==
    /// new_commitment(v, G, r, H)` via `commitment_equals`.
    /// Base-point specification coherence on `(v=7, r=11)`.
    public fun test_pedersen_bulletproof_commitment_matches_explicit_bases_tier3_binding(): bool {
        let v = ristretto255::new_scalar_from_u64(7);
        let r = ristretto255::new_scalar_from_u64(11);
        let g = ristretto255::basepoint();
        let h = ristretto255::hash_to_point_base();
        let a = ristretto255_pedersen::new_commitment_for_bulletproof(&v, &r);
        let b = ristretto255_pedersen::new_commitment(&v, &g, &r, &h);
        ristretto255_pedersen::commitment_equals(&a, &b)
    }

    /// W.31.03: `new_commitment_with_basepoint(v, r, H) ==
    /// new_commitment_for_bulletproof(v, r)` via
    /// `commitment_equals` — specialization uses `G` for
    /// `val_base`, matching the Bulletproofs default.
    public fun test_pedersen_commitment_with_basepoint_matches_bulletproof_tier3_binding(): bool {
        let v = ristretto255::new_scalar_from_u64(13);
        let r = ristretto255::new_scalar_from_u64(17);
        let h = ristretto255::hash_to_point_base();
        let a = ristretto255_pedersen::new_commitment_with_basepoint(&v, &r, &h);
        let b = ristretto255_pedersen::new_commitment_for_bulletproof(&v, &r);
        ristretto255_pedersen::commitment_equals(&a, &b)
    }

    /// W.31.04: `commitment_from_point(p)` has `commitment_as_point
    /// == p` via `point_equals`. Ensures the struct-wrapped point
    /// is the one put in.
    public fun test_pedersen_commitment_from_point_roundtrip_tier3_binding(): bool {
        let g = ristretto255::basepoint();
        let g2 = ristretto255::basepoint();
        let c = ristretto255_pedersen::commitment_from_point(g);
        let p = ristretto255_pedersen::commitment_as_point(&c);
        ristretto255::point_equals(p, &g2)
    }

    /// W.31.05: `commitment_from_compressed(basepoint_compressed())`
    /// has `commitment_as_point == G`.
    public fun test_pedersen_commitment_from_compressed_basepoint_tier3_binding(): bool {
        let bp_c = ristretto255::basepoint_compressed();
        let c = ristretto255_pedersen::commitment_from_compressed(&bp_c);
        let p = ristretto255_pedersen::commitment_as_point(&c);
        ristretto255::point_equals(p, &ristretto255::basepoint())
    }

    /// W.31.06: bytes roundtrip — `new_commitment_from_bytes
    /// (commitment_to_bytes(c)) is Some(c')` with `commitment_to_bytes
    /// (c') == commitment_to_bytes(c)` on the non-trivial commitment
    /// `pc(1, 0)`.
    public fun test_pedersen_commitment_bytes_roundtrip_nontrivial_tier3_binding(): bool {
        let c = pc_one_zero_for_tier3();
        let bytes = ristretto255_pedersen::commitment_to_bytes(&c);
        let rt_opt = ristretto255_pedersen::new_commitment_from_bytes(bytes);
        assert!(std::option::is_some(&rt_opt), error::invalid_argument(1));
        let rt = std::option::destroy_some(rt_opt);
        ristretto255_pedersen::commitment_to_bytes(&rt)
            == ristretto255_pedersen::commitment_to_bytes(&c)
    }

    /// W.31.07: `new_commitment_from_bytes(zero_32_bytes)` decodes
    /// to the identity commitment — canonical zero acceptance path.
    public fun test_pedersen_commitment_from_zero_bytes_is_identity_tier3_binding(): bool {
        let zero_bytes = vector[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                                0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                                0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                                0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8];
        let c_opt = ristretto255_pedersen::new_commitment_from_bytes(zero_bytes);
        assert!(std::option::is_some(&c_opt), error::invalid_argument(1));
        let c = std::option::destroy_some(c_opt);
        let p = ristretto255_pedersen::commitment_as_point(&c);
        ristretto255::point_equals(p, &ristretto255::point_identity())
    }

    /// W.31.08: `commitment_to_bytes(zero_commitment)` equals 32
    /// zero bytes (Ristretto identity encoding).
    public fun test_pedersen_zero_commitment_to_bytes_is_zeros_tier3_binding(): bool {
        let c = pc_zero_for_tier3();
        let bytes = ristretto255_pedersen::commitment_to_bytes(&c);
        let expected = vector[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                              0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                              0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                              0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8];
        bytes == expected
    }

    /// W.31.09: `commitment_into_point(clone(c))` extracted and
    /// re-compressed equals `commitment_as_compressed_point(c)`.
    /// Binds the consume-variant `into_point` against the
    /// borrow-variant `as_compressed_point` on `pc(1, 0)`.
    public fun test_pedersen_commitment_into_point_matches_as_compressed_tier3_binding(): bool {
        let c = pc_one_zero_for_tier3();
        let cp_a = ristretto255_pedersen::commitment_as_compressed_point(&c);
        let c_clone = ristretto255_pedersen::commitment_clone(&c);
        let p = ristretto255_pedersen::commitment_into_point(c_clone);
        let cp_b = ristretto255::point_compress(&p);
        ristretto255::compressed_point_to_bytes(cp_a)
            == ristretto255::compressed_point_to_bytes(cp_b)
    }

    /// W.31.10: `commitment_into_compressed_point(clone(c))` equals
    /// `commitment_as_compressed_point(c)` byte-for-byte — consume
    /// vs borrow variants of the compressed accessor agree on
    /// `pc(1, 0)`.
    public fun test_pedersen_commitment_into_compressed_matches_as_compressed_tier3_binding(): bool {
        let c = pc_one_zero_for_tier3();
        let cp_a = ristretto255_pedersen::commitment_as_compressed_point(&c);
        let c_clone = ristretto255_pedersen::commitment_clone(&c);
        let cp_b = ristretto255_pedersen::commitment_into_compressed_point(c_clone);
        ristretto255::compressed_point_to_bytes(cp_a)
            == ristretto255::compressed_point_to_bytes(cp_b)
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.32 — Bulletproofs verifier reject-branch direct
    // binding. W.30 / W.31 bound the byte-surface and Pedersen
    // commitment surface around Bulletproofs but never actually
    // called `verify_range_proof{,_pedersen}` or
    // `verify_batch_range_proof{,_pedersen}` themselves. The
    // accept-branch happy path remains BLOCKED (requires a valid
    // offline-generated range proof which in turn requires Lean-
    // side Bulletproofs modeling), but the REJECT branch is
    // bindable today through the native's deserialization-failure
    // path: `RangeProof::from_bytes` on an empty or short byte
    // buffer returns `Err(_)` from the `zkcrypto/bulletproofs`
    // crate, which the native translates into an `Abort` with
    // `NFE_DESERIALIZE_RANGE_PROOF = 0x01_0001 = 65537`. That
    // abort code happens to coincide with the existing Lean
    // witness `caSigmaVerifyFailedAbortDesc` at `funcIdx := 195`
    // (used by Phase D.1 sigma-reject rows for the same numeric
    // code), so every W.32 row reuses that Lean descriptor.
    //
    // A regression that silently short-circuits the verifier to
    // `Ok(true)` (e.g. `success = true` hard-coded, or the native
    // not being gated on deserialization failure) flips the VM
    // result from `Aborted(65537)` to `Ok(bool(true))`, which
    // immediately mismatches Lean `funcIdx := 195` and fails CI.
    // This is the first phase that directly exercises the four
    // Bulletproofs verifier natives.
    //
    // 8 new rows × `funcIdx := 195` (`caSigmaVerifyFailedAbortDesc`,
    // abort code 65537).
    // ───────────────────────────────────────────────────────────────

    /// Helper: all-zero vector of `n` bytes.
    fun w32_zero_bytes(n: u64): vector<u8> {
        let v = vector::empty<u8>();
        let i = 0u64;
        while (i < n) {
            vector::push_back(&mut v, 0u8);
            i = i + 1;
        };
        v
    }

    /// Helper: all-0xff vector of `n` bytes.
    fun w32_ff_bytes(n: u64): vector<u8> {
        let v = vector::empty<u8>();
        let i = 0u64;
        while (i < n) {
            vector::push_back(&mut v, 0xffu8);
            i = i + 1;
        };
        v
    }

    /// Helper: a valid (≤256 B) DST for range-proof calls.
    fun w32_valid_dst(): vector<u8> {
        b"aptos-confidential-assets-w32-test-dst"
    }

    /// W.32.01: `verify_range_proof_pedersen(pc(0,0), empty_proof, 8, dst)`
    /// aborts with `NFE_DESERIALIZE_RANGE_PROOF = 65537`. Exercises
    /// the single-proof Pedersen path: `point_compress` on the
    /// commitment, gas charge, `RangeProof::from_bytes(&[])` → Err
    /// → Abort. First-ever direct call into
    /// `verify_range_proof_pedersen` from the difftest harness.
    public fun test_bp_verify_range_proof_pedersen_empty_proof_aborts_tier3_binding(): bool {
        let c = pc_zero_for_tier3();
        let rp = ristretto255_bulletproofs::range_proof_from_bytes(vector::empty<u8>());
        let _ = ristretto255_bulletproofs::verify_range_proof_pedersen(
            &c, &rp, 8, w32_valid_dst());
        true
    }

    /// W.32.02: same as W.32.01 but with `num_bits = 16` and
    /// `pc(1, 0)` (non-identity commitment) — catches
    /// regressions that short-circuit on the identity commitment
    /// in particular.
    public fun test_bp_verify_range_proof_pedersen_empty_proof_16bit_pc_one_aborts_tier3_binding(): bool {
        let c = pc_one_zero_for_tier3();
        let rp = ristretto255_bulletproofs::range_proof_from_bytes(vector::empty<u8>());
        let _ = ristretto255_bulletproofs::verify_range_proof_pedersen(
            &c, &rp, 16, w32_valid_dst());
        true
    }

    /// W.32.03: `verify_range_proof(com=G, val_base=G, rand_base=H,
    /// empty_proof, 32, dst)` aborts with 65537. Exercises the
    /// explicit-base variant (`verify_range_proof`) which does NOT
    /// go through `point_clone`; binds the non-Pedersen entry point.
    public fun test_bp_verify_range_proof_explicit_bases_empty_proof_aborts_tier3_binding(): bool {
        let g = ristretto255::basepoint();
        let g2 = ristretto255::basepoint();
        let h = ristretto255::hash_to_point_base();
        let rp = ristretto255_bulletproofs::range_proof_from_bytes(vector::empty<u8>());
        let _ = ristretto255_bulletproofs::verify_range_proof(
            &g, &g2, &h, &rp, 32, w32_valid_dst());
        true
    }

    /// W.32.04: `verify_range_proof_pedersen(pc(0,0), junk_32_bytes,
    /// 64, dst)` aborts with 65537 — non-empty but malformed proof.
    /// Catches a regression that only rejects empty proof but
    /// accepts any non-empty buffer.
    public fun test_bp_verify_range_proof_pedersen_junk_32_bytes_aborts_tier3_binding(): bool {
        let c = pc_zero_for_tier3();
        let rp = ristretto255_bulletproofs::range_proof_from_bytes(w32_ff_bytes(32));
        let _ = ristretto255_bulletproofs::verify_range_proof_pedersen(
            &c, &rp, 64, w32_valid_dst());
        true
    }

    /// W.32.05: `verify_range_proof_pedersen(pc(0,0), zero_31_bytes,
    /// 8, dst)` aborts with 65537 — a length-31 all-zero buffer is
    /// one byte shorter than the minimum sensible range-proof
    /// serialization and fails deserialize.
    public fun test_bp_verify_range_proof_pedersen_zero_31_bytes_aborts_tier3_binding(): bool {
        let c = pc_zero_for_tier3();
        let rp = ristretto255_bulletproofs::range_proof_from_bytes(w32_zero_bytes(31));
        let _ = ristretto255_bulletproofs::verify_range_proof_pedersen(
            &c, &rp, 8, w32_valid_dst());
        true
    }

    /// W.32.06: `verify_batch_range_proof_pedersen([pc(0,0)],
    /// empty_proof, 8, dst)` aborts with 65537. Exercises the batch
    /// Pedersen path with a size-1 batch (valid batch size ∈ {1,2,4,8,16}).
    /// First-ever direct call into `verify_batch_range_proof_pedersen`
    /// from the harness; also exercises `point_clone` inside the
    /// map_ref, unblocked by the Phase D.1 feature-flag fix.
    public fun test_bp_verify_batch_range_proof_pedersen_size1_empty_aborts_tier3_binding(): bool {
        let comms = vector::empty<ristretto255_pedersen::Commitment>();
        vector::push_back(&mut comms, pc_zero_for_tier3());
        let rp = ristretto255_bulletproofs::range_proof_from_bytes(vector::empty<u8>());
        let _ = ristretto255_bulletproofs::verify_batch_range_proof_pedersen(
            &comms, &rp, 8, w32_valid_dst());
        true
    }

    /// W.32.07: `verify_batch_range_proof_pedersen([pc(0,0), pc(1,0)],
    /// empty_proof, 16, dst)` aborts with 65537. Size-2 batch with
    /// distinct commitments — catches a batch verifier that only
    /// checks the first commitment / short-circuits on identity.
    public fun test_bp_verify_batch_range_proof_pedersen_size2_empty_aborts_tier3_binding(): bool {
        let comms = vector::empty<ristretto255_pedersen::Commitment>();
        vector::push_back(&mut comms, pc_zero_for_tier3());
        vector::push_back(&mut comms, pc_one_zero_for_tier3());
        let rp = ristretto255_bulletproofs::range_proof_from_bytes(vector::empty<u8>());
        let _ = ristretto255_bulletproofs::verify_batch_range_proof_pedersen(
            &comms, &rp, 16, w32_valid_dst());
        true
    }

    /// W.32.08: `verify_batch_range_proof(comms=[G, H],
    /// val_base=G, rand_base=H, empty_proof, 32, dst)` aborts with
    /// 65537. Exercises the explicit-base batch variant
    /// (`verify_batch_range_proof`) with a size-2 vector of raw
    /// Ristretto points — no `point_clone`, no Pedersen struct.
    /// Binds the final of the four Bulletproofs verifier natives
    /// never before called from the harness.
    public fun test_bp_verify_batch_range_proof_explicit_bases_empty_aborts_tier3_binding(): bool {
        let comms = vector::empty<ristretto255::RistrettoPoint>();
        vector::push_back(&mut comms, ristretto255::basepoint());
        vector::push_back(&mut comms, ristretto255::hash_to_point_base());
        let g = ristretto255::basepoint();
        let h = ristretto255::hash_to_point_base();
        let rp = ristretto255_bulletproofs::range_proof_from_bytes(vector::empty<u8>());
        let _ = ristretto255_bulletproofs::verify_batch_range_proof(
            &comms, &g, &h, &rp, 32, w32_valid_dst());
        true
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.33 — `aptos_hash` module closure: SHA3-512 /
    // Keccak256 / RIPEMD-160 / BLAKE2b-256 primitive pins. W.29
    // bound `aptos_hash::sha2_512` because it is called directly
    // from the Move-level Fiat–Shamir challenge computation. The
    // other four public `aptos_hash` hashes are not on the
    // confidential-proof call graph today, but are still part of
    // the `aptos_hash` module's public surface — a silent drift
    // in any of them (wrong hash family, wrong output length,
    // deterministic-counter regression, input-insensitive stub)
    // would go undetected by every prior Tier 3 row. This phase
    // closes the `aptos_hash` module's primitive surface against
    // the VM so any future call site that reaches for one of
    // these hashes inherits a VM↔Lean binding row automatically.
    //
    // The most important cross-family pin is (iv): `sha3_512(x)`
    // must differ from `sha2_512(x)` on the same input. An
    // implementation mistake that aliases the two Move-level
    // wrappers to the same native (or the same Rust hash family)
    // is structurally plausible because their Move signatures
    // are identical (both `vector<u8> → vector<u8>` with 64-byte
    // output). Every other prior pin is blind to that swap.
    //
    // 12 new rows × `funcIdx := 40` (`ldTrue`).
    // ───────────────────────────────────────────────────────────────

    /// W.33.01: `aptos_hash::sha3_512(x)` output length is exactly
    /// 64 bytes on a non-trivial input.
    public fun test_aptos_hash_sha3_512_length_is_64_tier3_binding(): bool {
        vector::length(&aptos_hash::sha3_512(b"w33-01-input")) == 64
    }

    /// W.33.02: `aptos_hash::sha3_512` is deterministic on the same
    /// input.
    public fun test_aptos_hash_sha3_512_deterministic_tier3_binding(): bool {
        aptos_hash::sha3_512(b"w33-02-determinism")
            == aptos_hash::sha3_512(b"w33-02-determinism")
    }

    /// W.33.03: `aptos_hash::sha3_512` differs on distinct inputs.
    public fun test_aptos_hash_sha3_512_distinct_inputs_tier3_binding(): bool {
        aptos_hash::sha3_512(b"w33-03-alpha") != aptos_hash::sha3_512(b"w33-03-beta")
    }

    /// W.33.04 — cross-family discriminator. `sha3_512(x) !=
    /// sha2_512(x)` on the same input — catches a regression
    /// that silently aliases the two Move-level wrappers to the
    /// same Rust hash family. Neither hash-family-specific pin
    /// (W.33.01-03 / W.29.02-05) catches this alone.
    public fun test_aptos_hash_sha3_512_vs_sha2_512_differ_tier3_binding(): bool {
        let x = b"w33-04-cross-family-discriminator";
        aptos_hash::sha3_512(x) != aptos_hash::sha2_512(x)
    }

    /// W.33.05: `aptos_hash::keccak256(x)` output length is exactly
    /// 32 bytes.
    public fun test_aptos_hash_keccak256_length_is_32_tier3_binding(): bool {
        vector::length(&aptos_hash::keccak256(b"w33-05-input")) == 32
    }

    /// W.33.06: `aptos_hash::keccak256` is deterministic.
    public fun test_aptos_hash_keccak256_deterministic_tier3_binding(): bool {
        aptos_hash::keccak256(b"w33-06-determinism")
            == aptos_hash::keccak256(b"w33-06-determinism")
    }

    /// W.33.07: `aptos_hash::keccak256` differs on distinct inputs.
    public fun test_aptos_hash_keccak256_distinct_inputs_tier3_binding(): bool {
        aptos_hash::keccak256(b"w33-07-alpha") != aptos_hash::keccak256(b"w33-07-beta")
    }

    /// W.33.08 — cross-family discriminator. `keccak256(x) !=
    /// truncate_to_32(sha3_512(x))` — keccak256 and SHA3-256 /
    /// SHA3-512 are *different hash families* (NIST SHA-3 adds a
    /// domain-separation byte that Keccak does not), so even if a
    /// stub implementation tried to compute `keccak256` as the
    /// first 32 B of `sha3_512`, the result must differ. Binds
    /// Keccak's non-NIST-padding behavior against the VM.
    public fun test_aptos_hash_keccak256_vs_sha3_512_prefix_differ_tier3_binding(): bool {
        let x = b"w33-08-keccak-vs-sha3";
        let k = aptos_hash::keccak256(x);
        let s = aptos_hash::sha3_512(x);
        let i = 0u64;
        let diff = false;
        while (i < 32) {
            if (*vector::borrow(&k, i) != *vector::borrow(&s, i)) {
                diff = true;
            };
            i = i + 1;
        };
        diff
    }

    /// W.33.09: `aptos_hash::ripemd160(x)` output length is exactly
    /// 20 bytes — RIPEMD-160 is 160 bits.
    public fun test_aptos_hash_ripemd160_length_is_20_tier3_binding(): bool {
        vector::length(&aptos_hash::ripemd160(b"w33-09-input")) == 20
    }

    /// W.33.10: `aptos_hash::ripemd160` is deterministic + input-
    /// sensitive on two distinct inputs.
    public fun test_aptos_hash_ripemd160_det_and_sensitive_tier3_binding(): bool {
        let a = aptos_hash::ripemd160(b"w33-10-alpha");
        let b_ = aptos_hash::ripemd160(b"w33-10-alpha");
        let c = aptos_hash::ripemd160(b"w33-10-beta");
        (a == b_) && (a != c)
    }

    /// W.33.11: `aptos_hash::blake2b_256(x)` output length is
    /// exactly 32 bytes.
    public fun test_aptos_hash_blake2b_256_length_is_32_tier3_binding(): bool {
        vector::length(&aptos_hash::blake2b_256(b"w33-11-input")) == 32
    }

    /// W.33.12: `aptos_hash::blake2b_256` is deterministic + input-
    /// sensitive + differs from `keccak256` (another 32-byte hash
    /// — catches silent aliasing between the two fixed-32-byte
    /// hash wrappers).
    public fun test_aptos_hash_blake2b_256_distinct_from_keccak_tier3_binding(): bool {
        let x = b"w33-12-blake-vs-keccak-discriminator";
        let a = aptos_hash::blake2b_256(x);
        let b_ = aptos_hash::blake2b_256(x);
        let c = aptos_hash::keccak256(x);
        let d = aptos_hash::blake2b_256(b"w33-12-different-input");
        (a == b_) && (a != c) && (a != d)
    }

    // ───────────────────────────────────────────────────────────────
    // Phase W.34 — `aptos_hash` SipHash surface. W.33 bound every
    // `vector<u8> → vector<u8>` hash wrapper; the module also exposes
    // SipHash (`sip_hash`, `sip_hash_from_value`) as the non-
    // cryptographic hash family. These are ungated natives — still
    // part of the public `aptos_hash` ABI any future caller might
    // reach for alongside the Tier 3 crypto stack.
    //
    // 3 new rows × `funcIdx := 40` (`ldTrue`).
    // ───────────────────────────────────────────────────────────────

    /// W.34.01: `aptos_hash::sip_hash` is deterministic on the same
    /// byte input.
    public fun test_aptos_hash_sip_hash_deterministic_tier3_binding(): bool {
        let x = b"w34-01-sip-determinism";
        aptos_hash::sip_hash(x) == aptos_hash::sip_hash(x)
    }

    /// W.34.02: `aptos_hash::sip_hash` differs on distinct inputs.
    public fun test_aptos_hash_sip_hash_distinct_inputs_tier3_binding(): bool {
        aptos_hash::sip_hash(b"w34-02-alpha") != aptos_hash::sip_hash(b"w34-02-beta")
    }

    /// W.34.03: `sip_hash_from_value<T>` agrees with `sip_hash(bcs::to_bytes(&v))`
    /// on a concrete `u64` — binds the generic wrapper to BCS + `sip_hash`.
    public fun test_aptos_hash_sip_hash_from_value_matches_bcs_u64_tier3_binding(): bool {
        let v: u64 = 0x1234_5678_9abc_def0u64;
        aptos_hash::sip_hash_from_value(&v) == aptos_hash::sip_hash(bcs::to_bytes(&v))
    }

    /// W.28.08: `new_scalar_uniform_from_64_bytes` differs on
    /// distinct 64-byte inputs (reduction is input-sensitive).
    public fun test_new_scalar_uniform_from_64_bytes_distinct_inputs_tier3_binding(): bool {
        let a = vector[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8];
        let b = vector[1u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,
                       0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8];
        let sa_opt = ristretto255::new_scalar_uniform_from_64_bytes(a);
        let sb_opt = ristretto255::new_scalar_uniform_from_64_bytes(b);
        assert!(std::option::is_some(&sa_opt), error::invalid_argument(1));
        assert!(std::option::is_some(&sb_opt), error::invalid_argument(1));
        let sa = std::option::destroy_some(sa_opt);
        let sb = std::option::destroy_some(sb_opt);
        !ristretto255::scalar_equals(&sa, &sb)
    }

    /// W.27.11: `split_into_chunks_u128(0x_0000_5555_4444_3333_2222_1111_0000_ffff)`
    /// yields little-endian-by-16 chunk ordering: chunk[0]=0xffff,
    /// chunk[1]=0x0000, chunk[2]=0x1111, chunk[3]=0x2222, …,
    /// chunk[7]=0x0000. Witnesses the u128 split masking & shift
    /// composition end-to-end.
    public fun test_split_into_chunks_u128_mixed_le_ordering_tier3_binding(): bool {
        let v: u128 = 0x0000_5555_4444_3333_2222_1111_0000_ffffu128;
        let chunks = confidential_balance::split_into_chunks_u128(v);
        if (vector::length(&chunks) != confidential_balance::get_actual_balance_chunks()) {
            return false
        };
        let e0 = ristretto255::new_scalar_from_u64(0xffff);
        let e1 = ristretto255::new_scalar_from_u64(0x0000);
        let e2 = ristretto255::new_scalar_from_u64(0x1111);
        let e3 = ristretto255::new_scalar_from_u64(0x2222);
        let e4 = ristretto255::new_scalar_from_u64(0x3333);
        let e5 = ristretto255::new_scalar_from_u64(0x4444);
        let e6 = ristretto255::new_scalar_from_u64(0x5555);
        let e7 = ristretto255::new_scalar_from_u64(0x0000);
        ristretto255::scalar_equals(vector::borrow(&chunks, 0), &e0)
            && ristretto255::scalar_equals(vector::borrow(&chunks, 1), &e1)
            && ristretto255::scalar_equals(vector::borrow(&chunks, 2), &e2)
            && ristretto255::scalar_equals(vector::borrow(&chunks, 3), &e3)
            && ristretto255::scalar_equals(vector::borrow(&chunks, 4), &e4)
            && ristretto255::scalar_equals(vector::borrow(&chunks, 5), &e5)
            && ristretto255::scalar_equals(vector::borrow(&chunks, 6), &e6)
            && ristretto255::scalar_equals(vector::borrow(&chunks, 7), &e7)
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
        let msg = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            0u8, @0x0, @0x0, &ek, &chunks, &bal);
        let dst = confidential_proof::get_fiat_shamir_withdrawal_sigma_dst();
        bytes_start_with(&msg, &dst)
    }

    public fun test_fs_prefix_wd_deterministic(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let chunks = withdrawal_zero_chunks();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            7u8, @0xA, @0xB, &ek, &chunks, &bal);
        let b = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            7u8, @0xA, @0xB, &ek, &chunks, &bal);
        a == b
    }

    public fun test_fs_prefix_wd_chain_id_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let chunks = withdrawal_zero_chunks();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            1u8, @0xA, @0xB, &ek, &chunks, &bal);
        let b = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            2u8, @0xA, @0xB, &ek, &chunks, &bal);
        a != b
    }

    public fun test_fs_prefix_wd_sender_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let chunks = withdrawal_zero_chunks();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            7u8, @0xA, @0xC, &ek, &chunks, &bal);
        let b = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            7u8, @0xB, @0xC, &ek, &chunks, &bal);
        a != b
    }

    public fun test_fs_prefix_wd_contract_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let chunks = withdrawal_zero_chunks();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            7u8, @0xA, @0xB, &ek, &chunks, &bal);
        let b = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
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
        let wd = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            0u8, @0x0, @0x0, &ek, &chunks, &bal);
        let norm = difftest_confidential_proof_helpers::normalization_fs_prefix(
            0u8, @0x0, @0x0, &ek, &bal, &bal);
        wd != norm
    }

    // Normalization prefix pins
    public fun test_fs_prefix_norm_starts_with_dst(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let msg = difftest_confidential_proof_helpers::normalization_fs_prefix(
            0u8, @0x0, @0x0, &ek, &bal, &bal);
        let dst = confidential_proof::get_fiat_shamir_normalization_sigma_dst();
        bytes_start_with(&msg, &dst)
    }

    public fun test_fs_prefix_norm_deterministic(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::normalization_fs_prefix(
            3u8, @0xA, @0xB, &ek, &bal, &bal);
        let b = difftest_confidential_proof_helpers::normalization_fs_prefix(
            3u8, @0xA, @0xB, &ek, &bal, &bal);
        a == b
    }

    public fun test_fs_prefix_norm_chain_id_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::normalization_fs_prefix(
            1u8, @0xA, @0xB, &ek, &bal, &bal);
        let b = difftest_confidential_proof_helpers::normalization_fs_prefix(
            2u8, @0xA, @0xB, &ek, &bal, &bal);
        a != b
    }

    public fun test_fs_prefix_norm_sender_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::normalization_fs_prefix(
            1u8, @0xA, @0xB, &ek, &bal, &bal);
        let b = difftest_confidential_proof_helpers::normalization_fs_prefix(
            1u8, @0xC, @0xB, &ek, &bal, &bal);
        a != b
    }

    public fun test_fs_prefix_norm_contract_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::normalization_fs_prefix(
            1u8, @0xA, @0xB, &ek, &bal, &bal);
        let b = difftest_confidential_proof_helpers::normalization_fs_prefix(
            1u8, @0xA, @0xD, &ek, &bal, &bal);
        a != b
    }

    // Rotation prefix pins
    public fun test_fs_prefix_rot_starts_with_dst(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let msg = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &bal, &bal);
        let dst = confidential_proof::get_fiat_shamir_rotation_sigma_dst();
        bytes_start_with(&msg, &dst)
    }

    public fun test_fs_prefix_rot_deterministic(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::rotation_fs_prefix(
            5u8, @0xA, @0xB, &ek, &ek, &bal, &bal);
        let b = difftest_confidential_proof_helpers::rotation_fs_prefix(
            5u8, @0xA, @0xB, &ek, &ek, &bal, &bal);
        a == b
    }

    public fun test_fs_prefix_rot_chain_id_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::rotation_fs_prefix(
            1u8, @0xA, @0xB, &ek, &ek, &bal, &bal);
        let b = difftest_confidential_proof_helpers::rotation_fs_prefix(
            9u8, @0xA, @0xB, &ek, &ek, &bal, &bal);
        a != b
    }

    public fun test_fs_prefix_rot_sender_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::rotation_fs_prefix(
            1u8, @0xA, @0xB, &ek, &ek, &bal, &bal);
        let b = difftest_confidential_proof_helpers::rotation_fs_prefix(
            1u8, @0xE, @0xB, &ek, &ek, &bal, &bal);
        a != b
    }

    public fun test_fs_prefix_rot_contract_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::rotation_fs_prefix(
            1u8, @0xA, @0xB, &ek, &ek, &bal, &bal);
        let b = difftest_confidential_proof_helpers::rotation_fs_prefix(
            1u8, @0xA, @0xF, &ek, &ek, &bal, &bal);
        a != b
    }

    /// Rotation and normalization both take `(ek, bal, bal)` in the same slot-position,
    /// but rotation has an extra `ek` field and a different DST. Distinct-prefix pin.
    public fun test_fs_prefix_rot_vs_norm_distinct(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let rot = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &bal, &bal);
        let norm = difftest_confidential_proof_helpers::normalization_fs_prefix(
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
        let msg = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            3u8, @0xA, @0xB, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
            3u8, @0xA, @0xB, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        a == b
    }

    public fun test_fs_prefix_tr_chain_id_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            1u8, @0xA, @0xB, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
            2u8, @0xA, @0xB, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        a != b
    }

    public fun test_fs_prefix_tr_sender_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            1u8, @0xA, @0xB, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
            1u8, @0xE, @0xB, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        a != b
    }

    public fun test_fs_prefix_tr_contract_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let act = confidential_balance::new_actual_balance_no_randomness();
        let pend = confidential_balance::new_pending_balance_no_randomness();
        let auditor_eks = vector::empty<twisted_elgamal::CompressedPubkey>();
        let auditor_amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            1u8, @0xA, @0xB, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &empty_eks, &empty_amts);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let tr = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        let wd = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            0u8, @0xA, @0xB, &ek, &chunks, &bal);
        let b = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            0u8, @0x0, @0x0, &ek, &chunks_zero, &bal);
        let b = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
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

        let a = difftest_confidential_proof_helpers::normalization_fs_prefix(
            0u8, @0x0, @0x0, &ek, &zero, &nonzero);
        let b = difftest_confidential_proof_helpers::normalization_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0u8, @0x0, @0x0, &ek_g, &ek_h, &bal, &bal);
        let b = difftest_confidential_proof_helpers::rotation_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &zero, &nonzero);
        let b = difftest_confidential_proof_helpers::rotation_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0x0, @0x0, &ek_g, &ek_h, &act, &act, &pend, &pend, &auditor_eks, &auditor_amounts);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &zero, &nonzero, &pend, &pend, &auditor_eks, &auditor_amounts);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &sender_amt, &recipient_amt, &auditor_eks, &auditor_amounts);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &eks_gh, &auditor_amounts_1);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            0u8, @0x0, @0x0, &ek_g, &chunks, &bal);
        let b = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            0u8, @0x0, @0x0, &ek_h, &chunks, &bal);
        a != b
    }

    /// Catches: `withdrawal` transcript that silently drops `current_balance`.
    public fun test_fs_prefix_wd_current_balance_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let chunks = withdrawal_zero_chunks();
        let zero = confidential_balance::new_actual_balance_no_randomness();
        let nonzero = nonzero_actual_bal_for_fs_tests();
        let a = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            0u8, @0x0, @0x0, &ek, &chunks, &zero);
        let b = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            0u8, @0x0, @0x0, &ek, &chunks, &nonzero);
        a != b
    }

    // ── Normalization field-coverage ──

    /// Catches: `normalization` transcript that silently drops `ek`.
    public fun test_fs_prefix_norm_ek_matters(): bool {
        let ek_g = basepoint_ek_for_fs_tests();
        let ek_h = hash_base_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::normalization_fs_prefix(
            0u8, @0x0, @0x0, &ek_g, &bal, &bal);
        let b = difftest_confidential_proof_helpers::normalization_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::normalization_fs_prefix(
            0u8, @0x0, @0x0, &ek, &zero, &zero);
        let b = difftest_confidential_proof_helpers::normalization_fs_prefix(
            0u8, @0x0, @0x0, &ek, &nonzero, &zero);
        a != b
    }

    /// Dual of the above — catches `normalization` dropping `new_balance`.
    public fun test_fs_prefix_norm_new_balance_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let zero = confidential_balance::new_actual_balance_no_randomness();
        let nonzero = nonzero_actual_bal_for_fs_tests();
        let a = difftest_confidential_proof_helpers::normalization_fs_prefix(
            0u8, @0x0, @0x0, &ek, &zero, &zero);
        let b = difftest_confidential_proof_helpers::normalization_fs_prefix(
            0u8, @0x0, @0x0, &ek, &zero, &nonzero);
        a != b
    }

    // ── Rotation field-coverage ──

    /// Catches: `rotation` transcript that silently drops `current_ek`.
    public fun test_fs_prefix_rot_current_ek_matters(): bool {
        let ek_g = basepoint_ek_for_fs_tests();
        let ek_h = hash_base_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0u8, @0x0, @0x0, &ek_g, &ek_g, &bal, &bal);
        let b = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0u8, @0x0, @0x0, &ek_h, &ek_g, &bal, &bal);
        a != b
    }

    /// Catches: `rotation` transcript that silently drops `new_ek`.
    public fun test_fs_prefix_rot_new_ek_matters(): bool {
        let ek_g = basepoint_ek_for_fs_tests();
        let ek_h = hash_base_ek_for_fs_tests();
        let bal = confidential_balance::new_actual_balance_no_randomness();
        let a = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0u8, @0x0, @0x0, &ek_g, &ek_g, &bal, &bal);
        let b = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0u8, @0x0, @0x0, &ek_g, &ek_h, &bal, &bal);
        a != b
    }

    /// Catches: `rotation` transcript that silently drops `current_balance`.
    public fun test_fs_prefix_rot_current_balance_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let zero = confidential_balance::new_actual_balance_no_randomness();
        let nonzero = nonzero_actual_bal_for_fs_tests();
        let a = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &zero, &zero);
        let b = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &nonzero, &zero);
        a != b
    }

    /// Catches: `rotation` transcript that silently drops `new_balance`.
    public fun test_fs_prefix_rot_new_balance_matters(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let zero = confidential_balance::new_actual_balance_no_randomness();
        let nonzero = nonzero_actual_bal_for_fs_tests();
        let a = difftest_confidential_proof_helpers::rotation_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &zero, &zero);
        let b = difftest_confidential_proof_helpers::rotation_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0x0, @0x0, &ek_g, &ek_g, &act, &act, &pend, &pend, &aeks, &aams);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0x0, @0x0, &ek_g, &ek_g, &act, &act, &pend, &pend, &aeks, &aams);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &zero, &zero, &pend, &pend, &aeks, &aams);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &zero, &zero, &pend, &pend, &aeks, &aams);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &zero_p, &zero_p, &aeks, &aams);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &zero_p, &zero_p, &aeks, &aams);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &aeks_g, &aams);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let a = difftest_confidential_proof_helpers::transfer_fs_prefix(
            0u8, @0x0, @0x0, &ek, &ek, &act, &act, &pend, &pend, &aeks_1, &aams_zero);
        let b = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let got = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
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
        let got = difftest_confidential_proof_helpers::rotation_fs_prefix(
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
        let got = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
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
        let got = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let got = difftest_confidential_proof_helpers::normalization_fs_prefix(
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
        let got = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
        let got = difftest_confidential_proof_helpers::withdrawal_fs_prefix(
            9u8, @0xA, @0xB, &ek, &amount_chunks, &current_balance);
        got == x"4d6f76656d656e74436f6e666964656e7469616c41737365742f5769746864726177616c09000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000be2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d762a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    }

    /// Normalization FS prefix golden (1224 B).
    public fun test_fs_prefix_norm_matches_golden(): bool {
        let ek = basepoint_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let got = difftest_confidential_proof_helpers::normalization_fs_prefix(
            9u8, @0xA, @0xB, &ek, &current_balance, &new_balance);
        got == x"4d6f76656d656e74436f6e666964656e7469616c41737365742f4e6f726d616c697a6174696f6e09000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000be2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d768c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d7600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    }

    /// Rotation FS prefix golden (1251 B).
    public fun test_fs_prefix_rot_matches_golden(): bool {
        let current_ek = basepoint_ek_for_fs_tests();
        let new_ek = hash_base_ek_for_fs_tests();
        let current_balance = confidential_balance::new_actual_balance_no_randomness();
        let new_balance = confidential_balance::new_actual_balance_no_randomness();
        let got = difftest_confidential_proof_helpers::rotation_fs_prefix(
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
        let got = difftest_confidential_proof_helpers::transfer_fs_prefix(
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
            // Tier 3 binding rows (Phase W.4): VM ↔ Lean basepoint bytes +
            // distinctness + determinism pins. All four map to `funcIdx :=
            // 40` (`ldTrue`) — Lean's `RistrettoEncoding.ristrettoBasepointBytes`
            // and `confidentialAssetHashBaseBytes` hold the exact same 32
            // bytes, so a drift on either side flips the row.
            (
                "test_ristretto_basepoint_bytes_equals_tier3_golden",
                "t3_g_bytes",
            ),
            (
                "test_hash_to_point_base_bytes_equals_tier3_golden",
                "t3_h_bytes",
            ),
            ("test_ristretto_basepoint_ne_hash_base", "t3_g_ne_h"),
            ("test_hash_to_point_base_deterministic", "t3_h_det"),
            // Tier 3 binding rows (Phase W.5): true cross-engine
            // algebraic binding for the `new_scalar_from_sha2_512`
            // Fiat–Shamir hash pipeline. Each golden was computed
            // independently in Lean via
            // `scalarToBytes (scalarUniformFrom64Bytes (sha2_512 input))`
            // and pinned here byte-for-byte. A drift in the Lean
            // SHA-512 / `scalarUniformFrom64Bytes` / `scalarToBytes`
            // OR in the Move VM's `new_scalar_from_sha2_512` /
            // `scalar_to_bytes` natives flips one of these rows.
            (
                "test_new_scalar_from_sha2_512_tier3_binding",
                "t3_sha512_scalar_g1",
            ),
            (
                "test_new_scalar_from_sha2_512_empty_input_tier3_binding",
                "t3_sha512_scalar_empty",
            ),
            (
                "test_new_scalar_from_sha2_512_abc_input_tier3_binding",
                "t3_sha512_scalar_abc",
            ),
            (
                "test_new_scalar_from_sha2_512_dst_input_tier3_binding",
                "t3_sha512_scalar_dst",
            ),
            (
                "test_new_scalar_from_sha2_512_deterministic",
                "t3_sha512_scalar_det",
            ),
            (
                "test_new_scalar_from_sha2_512_distinct_inputs",
                "t3_sha512_scalar_distinct",
            ),
            // Tier 3 binding rows (Phase W.6): scalar arithmetic
            // cross-engine algebraic binding (add, sub, mul, neg,
            // invert). All goldens computed independently in Lean
            // via `ZMod ristrettoSubgroupOrder` and pinned here
            // byte-for-byte.
            ("test_scalar_add_3_5_tier3_binding", "t3_scalar_add"),
            ("test_scalar_sub_5_3_tier3_binding", "t3_scalar_sub_pos"),
            ("test_scalar_sub_3_5_tier3_binding", "t3_scalar_sub_underflow"),
            ("test_scalar_mul_7_11_tier3_binding", "t3_scalar_mul"),
            (
                "test_scalar_neg_one_equals_l_minus_one_tier3_binding",
                "t3_scalar_neg_one",
            ),
            (
                "test_scalar_neg_zero_is_zero_tier3_binding",
                "t3_scalar_neg_zero",
            ),
            ("test_scalar_invert_7_tier3_binding", "t3_scalar_inv7"),
            (
                "test_scalar_invert_2_times_2_is_one_tier3_binding",
                "t3_scalar_inv2_mul2",
            ),
            (
                "test_scalar_invert_zero_is_none_tier3_binding",
                "t3_scalar_inv0_none",
            ),
            // Tier 3 binding rows (Phase W.7): SHA-512 raw-bytes
            // cross-engine binding (no scalar reduction; pins the
            // 64-byte raw output) + `new_scalar_from_u64` LE-encoding
            // cross-engine binding. Two of the SHA-512 rows are
            // additionally pinned against NIST FIPS 180-4 §C reference
            // vectors.
            (
                "test_sha2_512_empty_input_tier3_binding",
                "t3_sha512_raw_empty",
            ),
            (
                "test_sha2_512_abc_input_tier3_binding",
                "t3_sha512_raw_abc",
            ),
            (
                "test_sha2_512_movement_input_tier3_binding",
                "t3_sha512_raw_movement",
            ),
            (
                "test_sha2_512_112_a_bytes_tier3_binding",
                "t3_sha512_raw_112a",
            ),
            (
                "test_sha2_512_128_b_bytes_tier3_binding",
                "t3_sha512_raw_128b",
            ),
            (
                "test_sha2_512_output_length_is_64",
                "t3_sha512_len64",
            ),
            (
                "test_sha2_512_distinct_inputs_distinct_outputs",
                "t3_sha512_distinct",
            ),
            (
                "test_scalar_from_u64_0_tier3_binding",
                "t3_scalar_u64_0",
            ),
            (
                "test_scalar_from_u64_1_tier3_binding",
                "t3_scalar_u64_1",
            ),
            (
                "test_scalar_from_u64_42_tier3_binding",
                "t3_scalar_u64_42",
            ),
            (
                "test_scalar_from_u64_max_u32_tier3_binding",
                "t3_scalar_u64_max32",
            ),
            (
                "test_scalar_from_u64_max_u64_tier3_binding",
                "t3_scalar_u64_max64",
            ),
            // Phase W.8 — Fiat-Shamir msm_gamma composition +
            // scalar algebraic identity cross-engine bindings.
            (
                "test_msm_gamma_1_42_0_tier3_binding",
                "t3_gamma1_42_0",
            ),
            (
                "test_msm_gamma_1_42_1_tier3_binding",
                "t3_gamma1_42_1",
            ),
            (
                "test_msm_gamma_1_1_3_tier3_binding",
                "t3_gamma1_1_3",
            ),
            (
                "test_msm_gamma_2_42_0_5_tier3_binding",
                "t3_gamma2_42_0_5",
            ),
            (
                "test_msm_gamma_2_100_7_11_tier3_binding",
                "t3_gamma2_100_7_11",
            ),
            (
                "test_scalar_add_sub_cancel_tier3_binding",
                "t3_scalar_add_sub_cancel",
            ),
            (
                "test_scalar_squared_difference_tier3_binding",
                "t3_scalar_sq_diff",
            ),
            (
                "test_scalar_mul_assoc_tier3_binding",
                "t3_scalar_mul_assoc",
            ),
            (
                "test_scalar_distributivity_lhs_tier3_binding",
                "t3_scalar_dist_lhs",
            ),
            (
                "test_scalar_distributivity_rhs_tier3_binding",
                "t3_scalar_dist_rhs",
            ),
            // Phase W.9 — scalar inversion identities +
            // prepend_domain_context byte-layout cross-engine bindings.
            (
                "test_scalar_double_inverse_7_tier3_binding",
                "t3_scalar_inv_inv_7",
            ),
            (
                "test_scalar_double_inverse_42_tier3_binding",
                "t3_scalar_inv_inv_42",
            ),
            (
                "test_scalar_double_inverse_1001_tier3_binding",
                "t3_scalar_inv_inv_1001",
            ),
            (
                "test_scalar_inv_of_product_lhs_tier3_binding",
                "t3_scalar_inv_prod_lhs",
            ),
            (
                "test_scalar_inv_of_product_rhs_tier3_binding",
                "t3_scalar_inv_prod_rhs",
            ),
            (
                "test_scalar_inv_of_neg_lhs_tier3_binding",
                "t3_scalar_inv_neg_lhs",
            ),
            (
                "test_scalar_inv_of_neg_rhs_tier3_binding",
                "t3_scalar_inv_neg_rhs",
            ),
            (
                "test_scalar_cube_diff_direct_tier3_binding",
                "t3_scalar_cube_diff_dir",
            ),
            (
                "test_scalar_cube_diff_factored_tier3_binding",
                "t3_scalar_cube_diff_fac",
            ),
            (
                "test_scalar_mul_neg_identity_tier3_binding",
                "t3_scalar_mul_neg",
            ),
            (
                "test_prepend_domain_context_empty_body_tier3_binding",
                "t3_pdc_empty",
            ),
            (
                "test_prepend_domain_context_with_suffix_tier3_binding",
                "t3_pdc_suffix",
            ),
            (
                "test_prepend_domain_context_max_chain_id_tier3_binding",
                "t3_pdc_cid_max",
            ),
            // Phase W.10 — Full FS-prefix cross-engine byte equality
            // via SHA-512 digest pin. Holy-grail binding closing the
            // loop between VM's `difftest_confidential_proof_helpers::
            // *_fs_prefix` and Lean's `SigmaVerifiers.*` transcript
            // model. Bug in either engine's prefix construction → 
            // divergent 64-byte hash → exactly one engine fails.
            (
                "test_sha2_512_of_wd_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_wd_fs",
            ),
            (
                "test_sha2_512_of_norm_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_norm_fs",
            ),
            (
                "test_sha2_512_of_rot_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_rot_fs",
            ),
            (
                "test_sha2_512_of_tr_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_tr_fs",
            ),
            // Phase W.11 — multi-fixture FS-prefix SHA-512 cross-engine
            // byte equality. W.10 bound ONE reference fixture; W.11
            // adds four fixture variants (different chain_id, amount,
            // swapped addresses, swapped eks) to multiply coverage
            // across the input-axis space and catch reference-fixture
            // hard-coding regressions.
            (
                "test_sha2_512_of_wd_v2_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_wd_v2",
            ),
            (
                "test_sha2_512_of_wd_v3_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_wd_v3",
            ),
            (
                "test_sha2_512_of_norm_v2_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_norm_v2",
            ),
            (
                "test_sha2_512_of_rot_v2_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_rot_v2",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.12 — FS CHALLENGE SCALAR cross-engine binding.
            // On top of the W.10/W.11 FS-prefix-byte bindings, these 8
            // rows pin the downstream `scalar_to_bytes(new_scalar_from_
            // sha2_512(prefix))` pipeline — the actual value every sigma
            // verifier consumes — across all 8 (fixture × variant) axes.
            // Catches a scalar-reduction regression that only manifests
            // on FS-prefix-shaped (>64 B) inputs.
            (
                "test_fs_challenge_scalar_wd_ref_tier3_binding",
                "t3_chal_wd_ref",
            ),
            (
                "test_fs_challenge_scalar_norm_ref_tier3_binding",
                "t3_chal_norm_ref",
            ),
            (
                "test_fs_challenge_scalar_rot_ref_tier3_binding",
                "t3_chal_rot_ref",
            ),
            (
                "test_fs_challenge_scalar_tr_ref_tier3_binding",
                "t3_chal_tr_ref",
            ),
            (
                "test_fs_challenge_scalar_wd_v2_tier3_binding",
                "t3_chal_wd_v2",
            ),
            (
                "test_fs_challenge_scalar_wd_v3_tier3_binding",
                "t3_chal_wd_v3",
            ),
            (
                "test_fs_challenge_scalar_norm_v2_tier3_binding",
                "t3_chal_norm_v2",
            ),
            (
                "test_fs_challenge_scalar_rot_v2_tier3_binding",
                "t3_chal_rot_v2",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.13 — TRANSFER AUDITOR-COUNT FS-prefix +
            // challenge-scalar bindings. 4 SHA-512 rows + 4 challenge-
            // scalar rows for 1, 2, 3, and 2-SWAPPED auditor
            // configurations on the transfer FS prefix. Binds the
            // critical auditor-loop-iteration surface (per-auditor ek
            // block + per-auditor amount-D-point block + correct
            // placement before sender_amount D's) that every prior W
            // phase uses 0 auditors for.
            (
                "test_sha2_512_of_tr_1_auditor_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_tr_1a",
            ),
            (
                "test_sha2_512_of_tr_2_auditor_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_tr_2a",
            ),
            (
                "test_sha2_512_of_tr_3_auditor_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_tr_3a",
            ),
            (
                "test_sha2_512_of_tr_2_auditor_swapped_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_tr_2a_swap",
            ),
            (
                "test_fs_challenge_scalar_tr_1_auditor_tier3_binding",
                "t3_chal_tr_1a",
            ),
            (
                "test_fs_challenge_scalar_tr_2_auditor_tier3_binding",
                "t3_chal_tr_2a",
            ),
            (
                "test_fs_challenge_scalar_tr_3_auditor_tier3_binding",
                "t3_chal_tr_3a",
            ),
            (
                "test_fs_challenge_scalar_tr_2_auditor_swapped_tier3_binding",
                "t3_chal_tr_2a_swap",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.14 — chain_id BOUNDARY axis coverage for
            // all four sigma protocols. 7 new fixtures × 2 bindings
            // (SHA-512 + challenge scalar) = 14 new rows pinning
            // chain_id ∈ {0x00, 0xff} (and wd_cid0 to complete the
            // withdrawal chain_id axis {0, 1, 9, 0xff}). Catches a
            // regression in chain_id byte processing that only
            // manifests at boundaries (signed/unsigned mismatch,
            // missing-value branch, silent u8→i8 coercion).
            (
                "test_sha2_512_of_wd_cid0_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_wd_cid0",
            ),
            (
                "test_fs_challenge_scalar_wd_cid0_tier3_binding",
                "t3_chal_wd_cid0",
            ),
            (
                "test_sha2_512_of_norm_cid0_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_norm_cid0",
            ),
            (
                "test_fs_challenge_scalar_norm_cid0_tier3_binding",
                "t3_chal_norm_cid0",
            ),
            (
                "test_sha2_512_of_norm_cidff_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_norm_cidff",
            ),
            (
                "test_fs_challenge_scalar_norm_cidff_tier3_binding",
                "t3_chal_norm_cidff",
            ),
            (
                "test_sha2_512_of_rot_cid0_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_rot_cid0",
            ),
            (
                "test_fs_challenge_scalar_rot_cid0_tier3_binding",
                "t3_chal_rot_cid0",
            ),
            (
                "test_sha2_512_of_rot_cidff_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_rot_cidff",
            ),
            (
                "test_fs_challenge_scalar_rot_cidff_tier3_binding",
                "t3_chal_rot_cidff",
            ),
            (
                "test_sha2_512_of_tr_cid0_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_tr_cid0",
            ),
            (
                "test_fs_challenge_scalar_tr_cid0_tier3_binding",
                "t3_chal_tr_cid0",
            ),
            (
                "test_sha2_512_of_tr_cidff_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_tr_cidff",
            ),
            (
                "test_fs_challenge_scalar_tr_cidff_tier3_binding",
                "t3_chal_tr_cidff",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.15 — amount-chunk BOUNDARY axis for
            // withdrawal FS prefix. 5 amount fixtures × 2 bindings
            // (SHA-512 + challenge scalar) = 10 new rows pinning
            // amount ∈ {0, 2^32-1, 2^32, 2^64-1, 0x0123_4567_89ab_cdef}.
            (
                "test_sha2_512_of_wd_amt_0_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_wd_amt0",
            ),
            (
                "test_fs_challenge_scalar_wd_amt_0_tier3_binding",
                "t3_chal_wd_amt0",
            ),
            (
                "test_sha2_512_of_wd_amt_u32max_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_wd_u32max",
            ),
            (
                "test_fs_challenge_scalar_wd_amt_u32max_tier3_binding",
                "t3_chal_wd_u32max",
            ),
            (
                "test_sha2_512_of_wd_amt_2p32_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_wd_2p32",
            ),
            (
                "test_fs_challenge_scalar_wd_amt_2p32_tier3_binding",
                "t3_chal_wd_2p32",
            ),
            (
                "test_sha2_512_of_wd_amt_u64max_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_wd_u64max",
            ),
            (
                "test_fs_challenge_scalar_wd_amt_u64max_tier3_binding",
                "t3_chal_wd_u64max",
            ),
            (
                "test_sha2_512_of_wd_amt_distinct_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_wd_distinct",
            ),
            (
                "test_fs_challenge_scalar_wd_amt_distinct_tier3_binding",
                "t3_chal_wd_distinct",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.16 — address-BCS BOUNDARY axis for
            // withdrawal FS prefix. 4 address fixtures × 2 bindings
            // (SHA-512 + challenge scalar) = 8 new rows.
            (
                "test_sha2_512_of_wd_addr_swap_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_wd_addr_swap",
            ),
            (
                "test_fs_challenge_scalar_wd_addr_swap_tier3_binding",
                "t3_chal_wd_addr_swap",
            ),
            (
                "test_sha2_512_of_wd_addr_zero_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_wd_addr_zero",
            ),
            (
                "test_fs_challenge_scalar_wd_addr_zero_tier3_binding",
                "t3_chal_wd_addr_zero",
            ),
            (
                "test_sha2_512_of_wd_addr_max_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_wd_addr_max",
            ),
            (
                "test_fs_challenge_scalar_wd_addr_max_tier3_binding",
                "t3_chal_wd_addr_max",
            ),
            (
                "test_sha2_512_of_wd_addr_same_fs_prefix_matches_golden_tier3_binding",
                "t3_sha512_wd_addr_same",
            ),
            (
                "test_fs_challenge_scalar_wd_addr_same_tier3_binding",
                "t3_chal_wd_addr_same",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.17 — full FS-MESSAGE axis
            // (prefix || X-point bytes). 4 fixtures × 2 bindings = 8
            // new rows binding SHA-512 + challenge scalar of the full
            // FS message, using pinned G/H bytes as synthetic X-points.
            (
                "test_sha2_512_of_wd_msg_a_tier3_binding",
                "t3_sha512_wd_msg_a",
            ),
            (
                "test_fs_challenge_scalar_wd_msg_a_tier3_binding",
                "t3_chal_wd_msg_a",
            ),
            (
                "test_sha2_512_of_wd_msg_b_tier3_binding",
                "t3_sha512_wd_msg_b",
            ),
            (
                "test_fs_challenge_scalar_wd_msg_b_tier3_binding",
                "t3_chal_wd_msg_b",
            ),
            (
                "test_sha2_512_of_wd_msg_c_tier3_binding",
                "t3_sha512_wd_msg_c",
            ),
            (
                "test_fs_challenge_scalar_wd_msg_c_tier3_binding",
                "t3_chal_wd_msg_c",
            ),
            (
                "test_sha2_512_of_wd_msg_d_tier3_binding",
                "t3_sha512_wd_msg_d",
            ),
            (
                "test_fs_challenge_scalar_wd_msg_d_tier3_binding",
                "t3_chal_wd_msg_d",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.18 — full FS-MESSAGE axis for the 3
            // non-withdrawal protocols (norm, rot, tr). 3 protocols ×
            // 2 shapes × 2 bindings = 12 new rows.
            ("test_sha2_512_of_norm_msg_a_tier3_binding", "t3_sha512_norm_msg_a"),
            ("test_fs_challenge_scalar_norm_msg_a_tier3_binding", "t3_chal_norm_msg_a"),
            ("test_sha2_512_of_norm_msg_b_tier3_binding", "t3_sha512_norm_msg_b"),
            ("test_fs_challenge_scalar_norm_msg_b_tier3_binding", "t3_chal_norm_msg_b"),
            ("test_sha2_512_of_rot_msg_a_tier3_binding", "t3_sha512_rot_msg_a"),
            ("test_fs_challenge_scalar_rot_msg_a_tier3_binding", "t3_chal_rot_msg_a"),
            ("test_sha2_512_of_rot_msg_b_tier3_binding", "t3_sha512_rot_msg_b"),
            ("test_fs_challenge_scalar_rot_msg_b_tier3_binding", "t3_chal_rot_msg_b"),
            ("test_sha2_512_of_tr_msg_a_tier3_binding", "t3_sha512_tr_msg_a"),
            ("test_fs_challenge_scalar_tr_msg_a_tier3_binding", "t3_chal_tr_msg_a"),
            ("test_sha2_512_of_tr_msg_b_tier3_binding", "t3_sha512_tr_msg_b"),
            ("test_fs_challenge_scalar_tr_msg_b_tier3_binding", "t3_chal_tr_msg_b"),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.19 — extend full FS-MESSAGE axis for norm /
            // rot / tr to 4-shape parity with withdrawal (W.17). 3
            // protocols × 2 shapes (C: G||H, D: 3×G||3×H) × 2 bindings
            // = 12 new rows.
            ("test_sha2_512_of_norm_msg_c_tier3_binding", "t3_sha512_norm_msg_c"),
            ("test_fs_challenge_scalar_norm_msg_c_tier3_binding", "t3_chal_norm_msg_c"),
            ("test_sha2_512_of_norm_msg_d_tier3_binding", "t3_sha512_norm_msg_d"),
            ("test_fs_challenge_scalar_norm_msg_d_tier3_binding", "t3_chal_norm_msg_d"),
            ("test_sha2_512_of_rot_msg_c_tier3_binding", "t3_sha512_rot_msg_c"),
            ("test_fs_challenge_scalar_rot_msg_c_tier3_binding", "t3_chal_rot_msg_c"),
            ("test_sha2_512_of_rot_msg_d_tier3_binding", "t3_sha512_rot_msg_d"),
            ("test_fs_challenge_scalar_rot_msg_d_tier3_binding", "t3_chal_rot_msg_d"),
            ("test_sha2_512_of_tr_msg_c_tier3_binding", "t3_sha512_tr_msg_c"),
            ("test_fs_challenge_scalar_tr_msg_c_tier3_binding", "t3_chal_tr_msg_c"),
            ("test_sha2_512_of_tr_msg_d_tier3_binding", "t3_sha512_tr_msg_d"),
            ("test_fs_challenge_scalar_tr_msg_d_tier3_binding", "t3_chal_tr_msg_d"),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.20 — transfer auditor-count × full
            // FS-MESSAGE axis (4 auditor variants × 2 X-shapes ×
            // 2 bindings = 16 rows).
            ("test_sha2_512_of_tr_1a_msg_a_tier3_binding", "t3_sha512_tr_1a_msg_a"),
            ("test_fs_challenge_scalar_tr_1a_msg_a_tier3_binding", "t3_chal_tr_1a_msg_a"),
            ("test_sha2_512_of_tr_1a_msg_b_tier3_binding", "t3_sha512_tr_1a_msg_b"),
            ("test_fs_challenge_scalar_tr_1a_msg_b_tier3_binding", "t3_chal_tr_1a_msg_b"),
            ("test_sha2_512_of_tr_2a_msg_a_tier3_binding", "t3_sha512_tr_2a_msg_a"),
            ("test_fs_challenge_scalar_tr_2a_msg_a_tier3_binding", "t3_chal_tr_2a_msg_a"),
            ("test_sha2_512_of_tr_2a_msg_b_tier3_binding", "t3_sha512_tr_2a_msg_b"),
            ("test_fs_challenge_scalar_tr_2a_msg_b_tier3_binding", "t3_chal_tr_2a_msg_b"),
            ("test_sha2_512_of_tr_3a_msg_a_tier3_binding", "t3_sha512_tr_3a_msg_a"),
            ("test_fs_challenge_scalar_tr_3a_msg_a_tier3_binding", "t3_chal_tr_3a_msg_a"),
            ("test_sha2_512_of_tr_3a_msg_b_tier3_binding", "t3_sha512_tr_3a_msg_b"),
            ("test_fs_challenge_scalar_tr_3a_msg_b_tier3_binding", "t3_chal_tr_3a_msg_b"),
            ("test_sha2_512_of_tr_2aswap_msg_a_tier3_binding", "t3_sha512_tr_2aswap_msg_a"),
            ("test_fs_challenge_scalar_tr_2aswap_msg_a_tier3_binding", "t3_chal_tr_2aswap_msg_a"),
            ("test_sha2_512_of_tr_2aswap_msg_b_tier3_binding", "t3_sha512_tr_2aswap_msg_b"),
            ("test_fs_challenge_scalar_tr_2aswap_msg_b_tier3_binding", "t3_chal_tr_2aswap_msg_b"),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.21 — Ristretto255 point-arithmetic
            // algebraic identity binding (12 rows).
            ("test_ristretto_identity_is_zero_bytes_tier3_binding", "t3_ristretto_identity_zero"),
            ("test_ristretto_basepoint_mul_by_one_tier3_binding", "t3_ristretto_bp_mul_1"),
            ("test_ristretto_basepoint_mul_by_zero_tier3_binding", "t3_ristretto_bp_mul_0"),
            ("test_ristretto_point_add_zero_left_tier3_binding", "t3_ristretto_add_0_L"),
            ("test_ristretto_point_add_zero_right_tier3_binding", "t3_ristretto_add_0_R"),
            ("test_ristretto_msm_single_element_tier3_binding", "t3_ristretto_msm_1"),
            ("test_ristretto_msm_zero_scalars_tier3_binding", "t3_ristretto_msm_0s"),
            ("test_ristretto_point_mul_vs_basepoint_mul_tier3_binding", "t3_ristretto_pm_vs_bm"),
            ("test_ristretto_scalar_distributivity_tier3_binding", "t3_ristretto_distrib"),
            ("test_ristretto_msm_distributive_tier3_binding", "t3_ristretto_msm_distrib"),
            ("test_ristretto_basepoint_double_mul_equivalence_tier3_binding", "t3_ristretto_bp_dbl_mul"),
            ("test_ristretto_point_add_commutes_tier3_binding", "t3_ristretto_add_commutes"),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.22 — advanced Ristretto + scalar algebraic
            // identities (13 rows; mixed-basis MSM + H-operand +
            // scalar-field laws).
            ("test_ristretto_h_mul_by_one_tier3_binding", "t3_ristretto_h_mul_1"),
            ("test_ristretto_h_mul_by_zero_tier3_binding", "t3_ristretto_h_mul_0"),
            ("test_ristretto_h_doubling_tier3_binding", "t3_ristretto_h_doubling"),
            ("test_ristretto_msm_mixed_basis_tier3_binding", "t3_ristretto_msm_mixed"),
            ("test_ristretto_msm_additive_inverse_tier3_binding", "t3_ristretto_msm_add_inv"),
            ("test_ristretto_msm_regrouping_tier3_binding", "t3_ristretto_msm_regroup"),
            ("test_ristretto_identity_absorbs_mul_tier3_binding", "t3_ristretto_id_absorb"),
            ("test_scalar_add_neg_is_zero_tier3_binding", "t3_scalar_add_neg"),
            ("test_scalar_double_neg_identity_tier3_binding", "t3_scalar_dbl_neg"),
            ("test_scalar_zero_absorbs_mul_tier3_binding", "t3_scalar_0_absorb"),
            ("test_scalar_mul_commutes_tier3_binding", "t3_scalar_mul_commutes"),
            ("test_scalar_mul_associative_tier3_binding", "t3_scalar_mul_assoc"),
            ("test_scalar_one_mul_identity_tier3_binding", "t3_scalar_1_mul"),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.23 — additional core Ristretto natives
            // (`point_neg`, `point_sub`, `point_clone`,
            // `double_scalar_mul`, `new_point_from_sha2_512`,
            // scalar-bytes roundtrip). 12 new rows × `funcIdx := 40`.
            (
                "test_ristretto_point_neg_additive_inverse_tier3_binding",
                "t3_ristretto_pt_neg_add_inv",
            ),
            (
                "test_ristretto_point_neg_involution_tier3_binding",
                "t3_ristretto_pt_neg_invol",
            ),
            (
                "test_ristretto_point_sub_self_is_identity_tier3_binding",
                "t3_ristretto_pt_sub_self",
            ),
            (
                "test_ristretto_point_sub_scalar_consistency_tier3_binding",
                "t3_ristretto_pt_sub_scalar",
            ),
            (
                "test_ristretto_point_sub_equals_add_neg_tier3_binding",
                "t3_ristretto_pt_sub_add_neg",
            ),
            (
                "test_ristretto_point_clone_equals_source_tier3_binding",
                "t3_ristretto_pt_clone_g",
            ),
            (
                "test_ristretto_point_clone_h_equals_h_tier3_binding",
                "t3_ristretto_pt_clone_h",
            ),
            (
                "test_ristretto_double_scalar_mul_basic_tier3_binding",
                "t3_ristretto_dsm_basic",
            ),
            (
                "test_ristretto_double_scalar_mul_zero_tier3_binding",
                "t3_ristretto_dsm_zero",
            ),
            (
                "test_ristretto_new_point_from_sha2_512_deterministic_tier3_binding",
                "t3_ristretto_hash2pt_det",
            ),
            (
                "test_ristretto_new_point_from_sha2_512_distinct_tier3_binding",
                "t3_ristretto_hash2pt_distinct",
            ),
            (
                "test_scalar_bytes_roundtrip_tier3_binding",
                "t3_scalar_bytes_roundtrip",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.24 — `*_assign` vs pure-variant parity
            // binding (8 rows covering every Ristretto point / scalar
            // native that has a mutable in-place variant).
            (
                "test_ristretto_point_add_assign_matches_pure_tier3_binding",
                "t3_pt_add_assign",
            ),
            (
                "test_ristretto_point_sub_assign_matches_pure_tier3_binding",
                "t3_pt_sub_assign",
            ),
            (
                "test_ristretto_point_mul_assign_matches_pure_tier3_binding",
                "t3_pt_mul_assign",
            ),
            (
                "test_ristretto_point_neg_assign_matches_pure_tier3_binding",
                "t3_pt_neg_assign",
            ),
            (
                "test_scalar_add_assign_matches_pure_tier3_binding",
                "t3_scalar_add_assign",
            ),
            (
                "test_scalar_sub_assign_matches_pure_tier3_binding",
                "t3_scalar_sub_assign",
            ),
            (
                "test_scalar_mul_assign_matches_pure_tier3_binding",
                "t3_scalar_mul_assign",
            ),
            (
                "test_scalar_neg_assign_matches_pure_tier3_binding",
                "t3_scalar_neg_assign",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.25 — scalar constructors (u8/u32/u128) +
            // predicates (scalar_is_{zero,one}, scalar_equals,
            // point_equals) + point compress/decompress roundtrip +
            // `new_point_from_bytes` + `new_compressed_point_from_bytes`
            // decoding. 14 new rows × `funcIdx := 40`.
            (
                "test_scalar_from_u8_matches_u64_tier3_binding",
                "t3_scalar_u8_eq_u64",
            ),
            (
                "test_scalar_from_u8_zero_matches_scalar_zero_tier3_binding",
                "t3_scalar_u8_0_eq_zero",
            ),
            (
                "test_scalar_from_u32_matches_u64_tier3_binding",
                "t3_scalar_u32_eq_u64",
            ),
            (
                "test_scalar_from_u128_matches_u64_tier3_binding",
                "t3_scalar_u128_eq_u64",
            ),
            (
                "test_scalar_is_zero_on_zero_tier3_binding",
                "t3_scalar_is_zero_y",
            ),
            (
                "test_scalar_is_zero_on_one_is_false_tier3_binding",
                "t3_scalar_is_zero_n",
            ),
            (
                "test_scalar_is_one_on_one_tier3_binding",
                "t3_scalar_is_one_y",
            ),
            (
                "test_scalar_is_one_on_zero_is_false_tier3_binding",
                "t3_scalar_is_one_n",
            ),
            (
                "test_scalar_equals_refl_and_distinct_tier3_binding",
                "t3_scalar_equals",
            ),
            (
                "test_point_equals_refl_and_distinct_tier3_binding",
                "t3_point_equals",
            ),
            (
                "test_point_equals_semantic_equivalence_tier3_binding",
                "t3_point_equals_sem",
            ),
            (
                "test_point_compress_decompress_roundtrip_tier3_binding",
                "t3_pt_cmp_dec_rt",
            ),
            (
                "test_new_point_from_bytes_basepoint_tier3_binding",
                "t3_pt_from_bytes_bp",
            ),
            (
                "test_new_compressed_point_from_zero_is_identity_tier3_binding",
                "t3_pt_cmp_zero_is_id",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.26 — twisted ElGamal ciphertext algebra.
            // 12 new rows × `funcIdx := 40` covering ciphertext_{add,
            // sub, add_assign, sub_assign, clone, equals, compress,
            // decompress, to_bytes, new_from_bytes, no_randomness}.
            (
                "test_ciphertext_add_identity_tier3_binding",
                "t3_ct_add_id",
            ),
            (
                "test_ciphertext_add_commutative_tier3_binding",
                "t3_ct_add_comm",
            ),
            (
                "test_ciphertext_sub_self_is_zero_tier3_binding",
                "t3_ct_sub_self",
            ),
            (
                "test_ciphertext_add_sub_cancels_tier3_binding",
                "t3_ct_add_sub_cancel",
            ),
            (
                "test_ciphertext_add_assign_matches_pure_tier3_binding",
                "t3_ct_add_assign",
            ),
            (
                "test_ciphertext_sub_assign_matches_pure_tier3_binding",
                "t3_ct_sub_assign",
            ),
            (
                "test_ciphertext_clone_matches_original_tier3_binding",
                "t3_ct_clone",
            ),
            (
                "test_ciphertext_equals_refl_and_order_sensitive_tier3_binding",
                "t3_ct_equals",
            ),
            (
                "test_ciphertext_compress_decompress_roundtrip_tier3_binding",
                "t3_ct_cmp_dec_rt",
            ),
            (
                "test_ciphertext_bytes_roundtrip_tier3_binding",
                "t3_ct_bytes_rt",
            ),
            (
                "test_ciphertext_no_randomness_zero_is_identity_ct_tier3_binding",
                "t3_ct_no_rand_zero",
            ),
            (
                "test_ciphertext_no_randomness_one_is_G_identity_tier3_binding",
                "t3_ct_no_rand_one",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.27 — confidential_balance module bindings.
            // 11 new rows × `funcIdx := 40` covering zero-balance
            // constructors, compress/decompress + bytes roundtrips,
            // balance_to_points_{c,d}, add/sub_balances_mut cancellation,
            // balance_c_equals vs balance_equals sensitivity, and the
            // u64/u128 chunk-splitters' masking + LE-ordering.
            (
                "test_pending_balance_no_randomness_is_zero_tier3_binding",
                "t3_pb_zero_is_zero",
            ),
            (
                "test_actual_balance_no_randomness_is_zero_tier3_binding",
                "t3_ab_zero_is_zero",
            ),
            (
                "test_balance_compress_decompress_roundtrip_tier3_binding",
                "t3_bal_cmp_dec_rt",
            ),
            (
                "test_pending_balance_bytes_roundtrip_tier3_binding",
                "t3_pb_bytes_rt",
            ),
            (
                "test_pending_balance_to_points_c_zero_is_identities_tier3_binding",
                "t3_pb_pts_c_zero",
            ),
            (
                "test_actual_balance_to_points_d_zero_is_identities_tier3_binding",
                "t3_ab_pts_d_zero",
            ),
            (
                "test_balance_add_then_sub_is_noop_tier3_binding",
                "t3_bal_add_sub_noop",
            ),
            (
                "test_balance_c_equals_is_weaker_than_balance_equals_tier3_binding",
                "t3_bal_c_weaker",
            ),
            (
                "test_split_into_chunks_u64_zero_is_zeros_tier3_binding",
                "t3_sp_u64_zero",
            ),
            (
                "test_split_into_chunks_u64_0xffff_boundary_tier3_binding",
                "t3_sp_u64_ffff",
            ),
            (
                "test_split_into_chunks_u128_mixed_le_ordering_tier3_binding",
                "t3_sp_u128_mixed",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.28 — hash-to-scalar / hash-to-point /
            // reduced / uniform scalar constructors. 8 new rows ×
            // `funcIdx := 40` covering sha512 alias equivalence,
            // determinism + input-sensitivity for the three hash/
            // reduction scalar constructors, and zero/distinct-input
            // determinism for the 64-byte-uniform point decoder.
            (
                "test_new_scalar_from_sha512_alias_matches_canonical_tier3_binding",
                "t3_sc_sha512_alias",
            ),
            (
                "test_new_scalar_from_sha2_512_deterministic_tier3_binding",
                "t3_sc_sha512_det",
            ),
            (
                "test_new_scalar_from_sha2_512_distinct_inputs_tier3_binding",
                "t3_sc_sha512_dist",
            ),
            (
                "test_new_scalar_uniform_from_64_bytes_zero_is_scalar_zero_tier3_binding",
                "t3_sc_uni64_zero",
            ),
            (
                "test_new_scalar_reduced_from_32_bytes_zero_is_scalar_zero_tier3_binding",
                "t3_sc_red32_zero",
            ),
            (
                "test_new_point_from_64_uniform_bytes_zero_determinism_tier3_binding",
                "t3_pt_uni64_zero_det",
            ),
            (
                "test_new_point_from_64_uniform_bytes_distinct_inputs_tier3_binding",
                "t3_pt_uni64_dist",
            ),
            (
                "test_new_scalar_uniform_from_64_bytes_distinct_inputs_tier3_binding",
                "t3_sc_uni64_dist",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.29 — SHA2-512 → scalar composition +
            // `aptos_hash::sha2_512` primitive pins. 5 new rows ×
            // `funcIdx := 40`.
            (
                "test_new_scalar_from_sha2_512_eq_uniform_of_sha2_512_tier3_binding",
                "t3_fsha_eq_uni",
            ),
            (
                "test_new_scalar_from_sha2_512_eq_uniform_of_sha2_512_alt_tier3_binding",
                "t3_fsha_eq_uni_alt",
            ),
            (
                "test_aptos_hash_sha2_512_output_len_is_64_tier3_binding",
                "t3_sha512_len64",
            ),
            (
                "test_aptos_hash_sha2_512_deterministic_tier3_binding",
                "t3_sha512_det",
            ),
            (
                "test_aptos_hash_sha2_512_distinct_inputs_tier3_binding",
                "t3_sha512_dist",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.30 — Bulletproofs + Pedersen commitment
            // public surface. 14 new rows × `funcIdx := 40` covering
            // `get_max_range_bits`, `range_proof_{from,to}_bytes`
            // roundtrips, Pedersen commitment group algebra
            // (add/sub/add_assign/sub_assign/clone/equals,
            // commutativity, self-sub-is-zero, homomorphic add
            // matching scalar add), commitment point/compressed-point
            // coherence, and `randomness_base_for_bulletproof == H`.
            (
                "test_bp_get_max_range_bits_is_64_tier3_binding",
                "t3_bp_max_bits",
            ),
            (
                "test_bp_range_proof_empty_bytes_roundtrip_tier3_binding",
                "t3_bp_rp_empty_rt",
            ),
            (
                "test_bp_range_proof_nontrivial_bytes_roundtrip_tier3_binding",
                "t3_bp_rp_nt_rt",
            ),
            (
                "test_pedersen_zero_commitment_is_identity_point_tier3_binding",
                "t3_pc_zero_is_id",
            ),
            (
                "test_pedersen_one_zero_commitment_is_basepoint_tier3_binding",
                "t3_pc_one_is_bp",
            ),
            (
                "test_pedersen_commitment_add_commutative_tier3_binding",
                "t3_pc_add_comm",
            ),
            (
                "test_pedersen_commitment_sub_self_is_zero_tier3_binding",
                "t3_pc_sub_self",
            ),
            (
                "test_pedersen_commitment_add_matches_scalar_add_tier3_binding",
                "t3_pc_add_scalar",
            ),
            (
                "test_pedersen_commitment_add_assign_matches_pure_tier3_binding",
                "t3_pc_add_assign",
            ),
            (
                "test_pedersen_commitment_sub_assign_matches_pure_tier3_binding",
                "t3_pc_sub_assign",
            ),
            (
                "test_pedersen_commitment_clone_matches_original_tier3_binding",
                "t3_pc_clone",
            ),
            (
                "test_pedersen_commitment_equals_reflexive_and_sensitive_tier3_binding",
                "t3_pc_equals",
            ),
            (
                "test_pedersen_commitment_as_point_vs_compressed_coherent_tier3_binding",
                "t3_pc_as_pt_coh",
            ),
            (
                "test_pedersen_randomness_base_matches_hash_to_point_base_tier3_binding",
                "t3_pc_rand_base_h",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.31 — remaining Pedersen commitment
            // constructors / accessors / byte-surface + base-point
            // coherence identities. 10 new rows × `funcIdx := 40`.
            (
                "test_pedersen_new_commitment_matches_double_scalar_mul_tier3_binding",
                "t3_pc_new_dsm",
            ),
            (
                "test_pedersen_bulletproof_commitment_matches_explicit_bases_tier3_binding",
                "t3_pc_bp_eq_expl",
            ),
            (
                "test_pedersen_commitment_with_basepoint_matches_bulletproof_tier3_binding",
                "t3_pc_wbp_eq_bp",
            ),
            (
                "test_pedersen_commitment_from_point_roundtrip_tier3_binding",
                "t3_pc_from_point",
            ),
            (
                "test_pedersen_commitment_from_compressed_basepoint_tier3_binding",
                "t3_pc_from_cmp",
            ),
            (
                "test_pedersen_commitment_bytes_roundtrip_nontrivial_tier3_binding",
                "t3_pc_bytes_rt",
            ),
            (
                "test_pedersen_commitment_from_zero_bytes_is_identity_tier3_binding",
                "t3_pc_zero_bytes",
            ),
            (
                "test_pedersen_zero_commitment_to_bytes_is_zeros_tier3_binding",
                "t3_pc_zero_to_bytes",
            ),
            (
                "test_pedersen_commitment_into_point_matches_as_compressed_tier3_binding",
                "t3_pc_into_pt",
            ),
            (
                "test_pedersen_commitment_into_compressed_matches_as_compressed_tier3_binding",
                "t3_pc_into_cmp",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.32 — Bulletproofs verifier reject-branch
            // direct binding. 8 new rows — each calls one of the
            // four Bulletproofs verifier natives
            // (`verify_range_proof{,_pedersen}`,
            // `verify_batch_range_proof{,_pedersen}`) with a
            // crafted invalid range proof. Deserialization fails
            // inside the native, aborting with `NFE_DESERIALIZE_RANGE_PROOF
            // = 0x01_0001 = 65537`, matched in Lean by the pre-
            // existing witness `caSigmaVerifyFailedAbortDesc` at
            // `funcIdx := 195` (Phase D.1).
            (
                "test_bp_verify_range_proof_pedersen_empty_proof_aborts_tier3_binding",
                "t3_bp_vrp_pc_empty",
            ),
            (
                "test_bp_verify_range_proof_pedersen_empty_proof_16bit_pc_one_aborts_tier3_binding",
                "t3_bp_vrp_pc1_16b",
            ),
            (
                "test_bp_verify_range_proof_explicit_bases_empty_proof_aborts_tier3_binding",
                "t3_bp_vrp_expl",
            ),
            (
                "test_bp_verify_range_proof_pedersen_junk_32_bytes_aborts_tier3_binding",
                "t3_bp_vrp_junk32",
            ),
            (
                "test_bp_verify_range_proof_pedersen_zero_31_bytes_aborts_tier3_binding",
                "t3_bp_vrp_zero31",
            ),
            (
                "test_bp_verify_batch_range_proof_pedersen_size1_empty_aborts_tier3_binding",
                "t3_bp_vbrp_s1",
            ),
            (
                "test_bp_verify_batch_range_proof_pedersen_size2_empty_aborts_tier3_binding",
                "t3_bp_vbrp_s2",
            ),
            (
                "test_bp_verify_batch_range_proof_explicit_bases_empty_aborts_tier3_binding",
                "t3_bp_vbrp_expl",
            ),
            // ───────────────────────────────────────────────────────────
            // Tier 3 Phase W.33 — `aptos_hash` module closure:
            // sha3_512 / keccak256 / ripemd160 / blake2b_256 primitive
            // pins + cross-family discriminators. 12 new rows ×
            // `funcIdx := 40`.
            (
                "test_aptos_hash_sha3_512_length_is_64_tier3_binding",
                "t3_sha3_len",
            ),
            (
                "test_aptos_hash_sha3_512_deterministic_tier3_binding",
                "t3_sha3_det",
            ),
            (
                "test_aptos_hash_sha3_512_distinct_inputs_tier3_binding",
                "t3_sha3_dist",
            ),
            (
                "test_aptos_hash_sha3_512_vs_sha2_512_differ_tier3_binding",
                "t3_sha3_vs_sha2",
            ),
            (
                "test_aptos_hash_keccak256_length_is_32_tier3_binding",
                "t3_kec_len",
            ),
            (
                "test_aptos_hash_keccak256_deterministic_tier3_binding",
                "t3_kec_det",
            ),
            (
                "test_aptos_hash_keccak256_distinct_inputs_tier3_binding",
                "t3_kec_dist",
            ),
            (
                "test_aptos_hash_keccak256_vs_sha3_512_prefix_differ_tier3_binding",
                "t3_kec_vs_sha3",
            ),
            (
                "test_aptos_hash_ripemd160_length_is_20_tier3_binding",
                "t3_rmd_len",
            ),
            (
                "test_aptos_hash_ripemd160_det_and_sensitive_tier3_binding",
                "t3_rmd_det_sens",
            ),
            (
                "test_aptos_hash_blake2b_256_length_is_32_tier3_binding",
                "t3_b2b_len",
            ),
            (
                "test_aptos_hash_blake2b_256_distinct_from_keccak_tier3_binding",
                "t3_b2b_vs_kec",
            ),
            // Tier 3 Phase W.34 — `aptos_hash` SipHash (`sip_hash`,
            // `sip_hash_from_value`). 3 new rows × `funcIdx := 40`.
            (
                "test_aptos_hash_sip_hash_deterministic_tier3_binding",
                "t3_sip_det",
            ),
            (
                "test_aptos_hash_sip_hash_distinct_inputs_tier3_binding",
                "t3_sip_dist",
            ),
            (
                "test_aptos_hash_sip_hash_from_value_matches_bcs_u64_tier3_binding",
                "t3_sip_bcs",
            ),
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
