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
//! **`test_registration_tagged_hash_golden_move_{first,second}`:** VM **64**-byte `vector<u8>` (corpora **`registration_tagged_hash_golden_{1,2}.hex`**); Lean **174** / **175** (`ldConst` **47** / **48** + `ret`).

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
    use aptos_experimental::ristretto255_twisted_elgamal as twisted_elgamal;
    use aptos_std::aptos_hash;
    use aptos_std::ristretto255;
    use std::error;

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

    /// 161-byte FS `msg` for the formal golden transcript (Lean: `TranscriptAlignment`).
    public fun test_registration_fs_message_golden_move(): vector<u8> {
        difftest_registration_helpers::registration_fs_message_golden_move()
    }

    /// **161**-byte FS `msg` for the second formal golden (`chain_id=42`, `@0x10`/`@0x20`/`@0x30`).
    public fun test_registration_fs_message_golden_move_second(): vector<u8> {
        difftest_registration_helpers::registration_fs_message_golden_move_second_scenario()
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

    /// Tagged SHA3-512 on the first formal FS golden `msg` (hex corpus `registration_tagged_hash_golden_1.hex`).
    public fun test_registration_tagged_hash_golden_move_first(): vector<u8> {
        difftest_registration_helpers::registration_tagged_hash_golden_move_first()
    }

    /// Tagged SHA3-512 on the second formal FS golden `msg` (`registration_tagged_hash_golden_2.hex`).
    public fun test_registration_tagged_hash_golden_move_second(): vector<u8> {
        difftest_registration_helpers::registration_tagged_hash_golden_move_second()
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
            (
                "test_registration_tagged_hash_golden_move_first",
                "reg_tagged_hash_golden_1",
            ),
            (
                "test_registration_tagged_hash_golden_move_second",
                "reg_tagged_hash_golden_2",
            ),
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
