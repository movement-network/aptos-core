//! Phase 4 (`confidential_asset`) — Option B re-exports (`get_*_balance_chunks`, `get_chunk_size_bits`)
//! plus real `serialize_auditor_*` on `aptos_experimental::confidential_asset` (public pure helpers;
//! not `#[test_only]`). Non-empty serializer wires (Lean `ldConst` + `ret`, real `Step`): EKs **32** / **64** / **96** / **128** / **160** / **192** B
//! (**114** / **116** / **124** / **125** / **126** / **127**); pending amounts: zero ×1 (**115**), **u64(1)** no-rand ×1 (**118**), zero ×2 (**117**),
//! one **actual** zero balance **512** B (**119**); mixed two-pending **512** B: zero then **`u64(1)`** (**120**),
//! **`u64(1)`** then zero (**121**); mixed **actual** zero + **`u64(1)`** pending **768** B (**122**–**123**).

use crate::compiler::compile_with_aptos_head_bundle;
use crate::oracle_row::vm_lean_row;
use crate::schema::TestCase;
use crate::vm::{module_blob, run_test_case, STD_ADDR};
use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use super::DiffTestSuite;

const MODULE_LAYER: &str = "difftest_confidential_asset_layer";

const TEST_SOURCE: &str = r#"
module 0x1::difftest_confidential_asset_layer {
    use std::vector;
    use aptos_experimental::confidential_asset;
    use aptos_experimental::confidential_balance;
    use aptos_experimental::ristretto255_twisted_elgamal as twisted_elgamal;

    public fun test_layer_reexport_pending_chunks(): u64 {
        confidential_balance::get_pending_balance_chunks()
    }

    public fun test_layer_reexport_actual_chunks(): u64 {
        confidential_balance::get_actual_balance_chunks()
    }

    public fun test_layer_reexport_chunk_bits(): u64 {
        confidential_balance::get_chunk_size_bits()
    }

    public fun test_serialize_auditor_eks_empty_framework(): vector<u8> {
        let auditors = vector::empty<twisted_elgamal::CompressedPubkey>();
        confidential_asset::serialize_auditor_eks(&auditors)
    }

    public fun test_serialize_auditor_amounts_empty_framework(): vector<u8> {
        let amounts = vector::empty<confidential_balance::ConfidentialBalance>();
        confidential_asset::serialize_auditor_amounts(&amounts)
    }

    /// Single valid compressed pubkey (**A_POINT** from `aptos_std::ristretto255` tests) — **32**-byte `serialize_auditor_eks` wire.
    public fun test_serialize_auditor_eks_single_a_point_framework(): vector<u8> {
        let pk = twisted_elgamal::new_pubkey_from_bytes(
            x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75",
        ).extract();
        let auditors = vector[pk];
        confidential_asset::serialize_auditor_eks(&auditors)
    }

    /// One **zero** pending balance (`new_pending_balance_no_randomness`) — **256**-byte `serialize_auditor_amounts` wire (4×64 B ciphertext encodings).
    public fun test_serialize_auditor_amounts_one_zero_pending_framework(): vector<u8> {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let amounts = vector[b];
        confidential_asset::serialize_auditor_amounts(&amounts)
    }

    /// Two **A_POINT** pubkeys — **64**-byte `serialize_auditor_eks` wire.
    public fun test_serialize_auditor_eks_two_a_points_framework(): vector<u8> {
        let pk = twisted_elgamal::new_pubkey_from_bytes(
            x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75",
        ).extract();
        let auditors = vector[pk, pk];
        confidential_asset::serialize_auditor_eks(&auditors)
    }

    /// Three **A_POINT** pubkeys — **96**-byte `serialize_auditor_eks` wire.
    public fun test_serialize_auditor_eks_three_a_points_framework(): vector<u8> {
        let pk = twisted_elgamal::new_pubkey_from_bytes(
            x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75",
        ).extract();
        let auditors = vector[pk, pk, pk];
        confidential_asset::serialize_auditor_eks(&auditors)
    }

    /// Four **A_POINT** pubkeys — **128**-byte `serialize_auditor_eks` wire.
    public fun test_serialize_auditor_eks_four_a_points_framework(): vector<u8> {
        let pk = twisted_elgamal::new_pubkey_from_bytes(
            x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75",
        ).extract();
        let auditors = vector[pk, pk, pk, pk];
        confidential_asset::serialize_auditor_eks(&auditors)
    }

    /// Five **A_POINT** pubkeys — **160**-byte `serialize_auditor_eks` wire.
    public fun test_serialize_auditor_eks_five_a_points_framework(): vector<u8> {
        let pk = twisted_elgamal::new_pubkey_from_bytes(
            x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75",
        ).extract();
        let auditors = vector[pk, pk, pk, pk, pk];
        confidential_asset::serialize_auditor_eks(&auditors)
    }

    /// Six **A_POINT** pubkeys — **192**-byte `serialize_auditor_eks` wire.
    public fun test_serialize_auditor_eks_six_a_points_framework(): vector<u8> {
        let pk = twisted_elgamal::new_pubkey_from_bytes(
            x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75",
        ).extract();
        let auditors = vector[pk, pk, pk, pk, pk, pk];
        confidential_asset::serialize_auditor_eks(&auditors)
    }

    /// Two zero pending balances — **512**-byte `serialize_auditor_amounts` wire.
    public fun test_serialize_auditor_amounts_two_zero_pending_framework(): vector<u8> {
        let b1 = confidential_balance::new_pending_balance_no_randomness();
        let b2 = confidential_balance::new_pending_balance_no_randomness();
        let amounts = vector[b1, b2];
        confidential_asset::serialize_auditor_amounts(&amounts)
    }

    /// One **`new_pending_balance_u64_no_randonmess(1)`** pending balance — **256**-byte wire (non-trivial ElGamal encoding).
    public fun test_serialize_auditor_amounts_one_u64_one_pending_framework(): vector<u8> {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let amounts = vector[b];
        confidential_asset::serialize_auditor_amounts(&amounts)
    }

    /// One **`new_actual_balance_no_randomness`** (128-bit-width zero) — **512**-byte `serialize_auditor_amounts` wire.
    public fun test_serialize_auditor_amounts_one_actual_zero_framework(): vector<u8> {
        let b = confidential_balance::new_actual_balance_no_randomness();
        let amounts = vector[b];
        confidential_asset::serialize_auditor_amounts(&amounts)
    }

    /// Zero pending then **`new_pending_balance_u64_no_randonmess(1)`** — **512**-byte wire (`balance_to_bytes` concat order).
    public fun test_serialize_auditor_amounts_zero_then_u64_one_framework(): vector<u8> {
        let b0 = confidential_balance::new_pending_balance_no_randomness();
        let b1 = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let amounts = vector[b0, b1];
        confidential_asset::serialize_auditor_amounts(&amounts)
    }

    /// **`u64(1)`** no-rand pending then zero — **512**-byte wire (vector order ≠ `test_serialize_auditor_amounts_zero_then_u64_one_framework`).
    public fun test_serialize_auditor_amounts_u64_one_then_zero_framework(): vector<u8> {
        let b0 = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let b1 = confidential_balance::new_pending_balance_no_randomness();
        let amounts = vector[b0, b1];
        confidential_asset::serialize_auditor_amounts(&amounts)
    }

    /// **Actual** zero then **`u64(1)`** no-rand pending — **768**-byte wire (512 + 256).
    public fun test_serialize_auditor_amounts_actual_zero_then_u64_one_pending_framework(): vector<u8> {
        let b0 = confidential_balance::new_actual_balance_no_randomness();
        let b1 = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let amounts = vector[b0, b1];
        confidential_asset::serialize_auditor_amounts(&amounts)
    }

    /// **`u64(1)`** pending then **actual** zero — **768**-byte wire (reverse of `..._actual_zero_then_u64_one_pending_...`).
    public fun test_serialize_auditor_amounts_u64_one_pending_then_actual_zero_framework(): vector<u8> {
        let b0 = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let b1 = confidential_balance::new_actual_balance_no_randomness();
        let amounts = vector[b0, b1];
        confidential_asset::serialize_auditor_amounts(&amounts)
    }

    /// `max_sender_auditor_hint_bytes()` exposes the `MAX_SENDER_AUDITOR_HINT_BYTES = 256` constant;
    /// oracle asserts the returned `u64` matches the pinned value.
    public fun test_layer_max_sender_auditor_hint_bytes_eq_256(): bool {
        confidential_asset::max_sender_auditor_hint_bytes() == 256
    }

    /// `serialize_auditor_eks` must preserve vector order: swapping two distinct
    /// pubkeys `[A, identity]` vs `[identity, A]` MUST produce different wire bytes.
    /// Catches: serializer that sorts, deduplicates, or reverses the input vector.
    /// Uses `A_POINT` and the compressed identity (all-zero bytes are NOT a valid
    /// Ristretto encoding) — so instead we use `A_POINT` and `basepoint_compressed`
    /// which are two distinct, valid Ristretto points.
    public fun test_serialize_auditor_eks_order_matters(): bool {
        let pk_a = twisted_elgamal::new_pubkey_from_bytes(
            x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75",
        ).extract();
        let pk_b = twisted_elgamal::new_pubkey_from_bytes(
            aptos_std::ristretto255::compressed_point_to_bytes(
                aptos_std::ristretto255::basepoint_compressed()),
        ).extract();
        let v1 = vector[pk_a, pk_b];
        let v2 = vector[pk_b, pk_a];
        let b1 = confidential_asset::serialize_auditor_eks(&v1);
        let b2 = confidential_asset::serialize_auditor_eks(&v2);
        b1 != b2
    }

    /// `serialize_auditor_eks(vec[A])` on `A_POINT` produces exactly
    /// **32 bytes** matching the compressed A_POINT encoding. Catches: header
    /// bytes / length prefix / padding regressions in the serializer.
    public fun test_serialize_auditor_eks_single_a_point_bytes_are_a_point(): bool {
        let pk = twisted_elgamal::new_pubkey_from_bytes(
            x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75",
        ).extract();
        let auditors = vector[pk];
        confidential_asset::serialize_auditor_eks(&auditors)
            == x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75"
    }

    /// `serialize_auditor_amounts` on a single NON-ZERO pending balance produces
    /// distinct bytes from the zero-balance serialization. Catches: serializer
    /// that always emits the zero encoding.
    public fun test_serialize_auditor_amounts_u64_one_differs_from_zero(): bool {
        let b_zero = confidential_balance::new_pending_balance_no_randomness();
        let b_nz = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let s_zero = confidential_asset::serialize_auditor_amounts(&vector[b_zero]);
        let s_nz = confidential_asset::serialize_auditor_amounts(&vector[b_nz]);
        s_zero != s_nz
    }

    /// `serialize_auditor_amounts([u64(1), u64(2)]) != serialize_auditor_amounts([u64(2), u64(1)])`.
    /// Order matters even at the amounts layer. Catches: amount serializer
    /// that sorts or hashes inputs.
    public fun test_serialize_auditor_amounts_order_matters(): bool {
        let b1 = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let b2 = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        let order_a = confidential_asset::serialize_auditor_amounts(&vector[b1, b2]);
        let b1_2 = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let b2_2 = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        let order_b = confidential_asset::serialize_auditor_amounts(&vector[b2_2, b1_2]);
        order_a != order_b
    }
}
"#;

pub struct ConfidentialAssetLayerSuite;

impl DiffTestSuite for ConfidentialAssetLayerSuite {
    fn id(&self) -> &'static str {
        "confidential_asset"
    }

    fn name(&self) -> &str {
        "0x1::difftest_confidential_asset_layer"
    }

    fn load_module(&self, storage: &mut InMemoryStorage) -> Result<()> {
        let modules = compile_with_aptos_head_bundle(TEST_SOURCE)?;
        for module in &modules {
            if module.self_name().as_str() != MODULE_LAYER {
                continue;
            }
            let blob = module_blob(module)?;
            storage.add_module_bytes(module.self_addr(), module.self_name(), blob.into());
        }
        Ok(())
    }

    fn generate_test_cases(&self, storage: &mut InMemoryStorage) -> Result<Vec<TestCase>> {
        let mut cases = Vec::new();
        let result = run_test_case(
            storage,
            STD_ADDR,
            MODULE_LAYER,
            "test_layer_reexport_pending_chunks",
            &[],
        )?;
        cases.push(vm_lean_row(
            "test_layer_reexport_pending_chunks [smoke]",
            vec![],
            result,
        ));
        for (function, label) in [
            ("test_layer_reexport_actual_chunks", "act_chunks"),
            ("test_layer_reexport_chunk_bits", "chunk_bits"),
            ("test_serialize_auditor_eks_empty_framework", "eks"),
            ("test_serialize_auditor_amounts_empty_framework", "amounts"),
            (
                "test_serialize_auditor_eks_single_a_point_framework",
                "eks_one_apoint",
            ),
            (
                "test_serialize_auditor_amounts_one_zero_pending_framework",
                "amounts_one_zero",
            ),
            (
                "test_serialize_auditor_eks_two_a_points_framework",
                "eks_two_apoint",
            ),
            (
                "test_serialize_auditor_eks_three_a_points_framework",
                "eks_three_apoint",
            ),
            (
                "test_serialize_auditor_eks_four_a_points_framework",
                "eks_four_apoint",
            ),
            (
                "test_serialize_auditor_eks_five_a_points_framework",
                "eks_five_apoint",
            ),
            (
                "test_serialize_auditor_eks_six_a_points_framework",
                "eks_six_apoint",
            ),
            (
                "test_serialize_auditor_amounts_two_zero_pending_framework",
                "amounts_two_zero",
            ),
            (
                "test_serialize_auditor_amounts_one_u64_one_pending_framework",
                "amounts_one_u64_1",
            ),
            (
                "test_serialize_auditor_amounts_one_actual_zero_framework",
                "amounts_one_actual_zero",
            ),
            (
                "test_serialize_auditor_amounts_zero_then_u64_one_framework",
                "amounts_zero_then_u64_1",
            ),
            (
                "test_serialize_auditor_amounts_u64_one_then_zero_framework",
                "amounts_u64_1_then_zero",
            ),
            (
                "test_serialize_auditor_amounts_actual_zero_then_u64_one_pending_framework",
                "amounts_actual_then_u64_1",
            ),
            (
                "test_serialize_auditor_amounts_u64_one_pending_then_actual_zero_framework",
                "amounts_u64_1_then_actual",
            ),
            (
                "test_layer_max_sender_auditor_hint_bytes_eq_256",
                "max_hint_bytes",
            ),
            (
                "test_serialize_auditor_eks_order_matters",
                "eks_order",
            ),
            (
                "test_serialize_auditor_eks_single_a_point_bytes_are_a_point",
                "eks_a_point_bytes",
            ),
            (
                "test_serialize_auditor_amounts_u64_one_differs_from_zero",
                "amounts_u64_1_neq_zero",
            ),
            (
                "test_serialize_auditor_amounts_order_matters",
                "amounts_order",
            ),
        ] {
            let result = run_test_case(storage, STD_ADDR, MODULE_LAYER, function, &[])?;
            cases.push(vm_lean_row(
                format!("{} [{}]", function, label),
                vec![],
                result,
            ));
        }
        Ok(cases)
    }
}
