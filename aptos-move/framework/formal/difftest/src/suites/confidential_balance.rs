//! VM oracles for `aptos_experimental::confidential_balance` (Phase 2 of the CA difftest plan).
//!
//! Lean coverage: see `MovementFormal.MoveModel.Programs.Confidential` — constants and simple predicates
//! are modeled; skipped cases are listed in `difftest/inventory/confidential_assets.md`.

use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use crate::compiler::compile_with_aptos_head_bundle;
use crate::schema::TestCase;
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_confidential_balance";

const TEST_SOURCE: &str = r#"
module 0x1::difftest_confidential_balance {
    use aptos_std::ristretto255;
    use aptos_experimental::confidential_balance;

    /// Call the real `#[view]` helpers on `aptos_experimental::confidential_balance` so the VM
    /// oracle exercises framework bytecode (Lean matches via trivial bytecode in `Programs/Confidential.lean`).
    public fun test_get_pending_balance_chunks(): u64 {
        confidential_balance::get_pending_balance_chunks()
    }

    public fun test_get_actual_balance_chunks(): u64 {
        confidential_balance::get_actual_balance_chunks()
    }

    public fun test_get_chunk_size_bits(): u64 {
        confidential_balance::get_chunk_size_bits()
    }

    public fun test_zero_pending_balance_to_bytes_len(): u64 {
        let b = confidential_balance::new_pending_balance_no_randomness();
        confidential_balance::balance_to_bytes(&b).length()
    }

    public fun test_zero_actual_balance_to_bytes_len(): u64 {
        let b = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::balance_to_bytes(&b).length()
    }

    public fun test_is_zero_pending(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        confidential_balance::is_zero_balance(&b)
    }

    public fun test_is_zero_actual(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::is_zero_balance(&b)
    }

    public fun test_compress_decompress_roundtrip_pending(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let c = confidential_balance::compress_balance(&b);
        let b2 = confidential_balance::decompress_balance(&c);
        confidential_balance::balance_equals(&b, &b2)
    }

    public fun test_compress_decompress_roundtrip_actual(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        let c = confidential_balance::compress_balance(&b);
        let b2 = confidential_balance::decompress_balance(&c);
        confidential_balance::balance_equals(&b, &b2)
    }

    public fun test_pending_from_wrong_len_is_none(): bool {
        std::option::is_none(&confidential_balance::new_pending_balance_from_bytes(x""))
    }

    public fun test_pending_from_short_len_is_none(): bool {
        let v = std::vector::range(0, 255).map(|_| 0u8);
        std::option::is_none(&confidential_balance::new_pending_balance_from_bytes(v))
    }

    public fun test_pending_roundtrip_bytes_ok(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let bytes = confidential_balance::balance_to_bytes(&b);
        std::option::is_some(&confidential_balance::new_pending_balance_from_bytes(bytes))
    }

    public fun test_pending_roundtrip_bytes_balance_equals_self(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let bytes = confidential_balance::balance_to_bytes(&b);
        let opt = confidential_balance::new_pending_balance_from_bytes(bytes);
        if (std::option::is_none(&opt)) {
            false
        } else {
            confidential_balance::balance_equals(&b, std::option::borrow(&opt))
        }
    }

    public fun test_add_two_zero_pending_stays_zero(): bool {
        let a = confidential_balance::new_pending_balance_no_randomness();
        let b = confidential_balance::new_pending_balance_no_randomness();
        confidential_balance::add_balances_mut(&mut a, &b);
        confidential_balance::is_zero_balance(&a)
    }

    public fun test_add_zero_amount_chunks_equal(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        confidential_balance::add_balances_mut(&mut a, &b);
        confidential_balance::balance_equals(&a, &b)
    }

    /// Lowest 16 bits of `amount` must match scalar in chunk 0 (`split_into_chunks_u64`).
    public fun test_split_into_chunks_u64_first_chunk(): bool {
        let amount = 0x000000000000ABCDu64;
        let chunks = confidential_balance::split_into_chunks_u64(amount);
        let s0 = *std::vector::borrow(&chunks, 0);
        let expected = ristretto255::new_scalar_from_u64(0xABCD);
        ristretto255::scalar_equals(&s0, &expected)
    }

    /// Lowest 16 bits of `amount` must match scalar in chunk 0 (`split_into_chunks_u128`).
    public fun test_split_into_chunks_u128_first_chunk(): bool {
        let amount = 0x0000000000000000000000000000EF01u128;
        let chunks = confidential_balance::split_into_chunks_u128(amount);
        let s0 = *std::vector::borrow(&chunks, 0);
        let expected = ristretto255::new_scalar_from_u128(0xEF01);
        ristretto255::scalar_equals(&s0, &expected)
    }

    public fun test_balance_equals_self_pending(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        confidential_balance::balance_equals(&b, &b)
    }

    public fun test_balance_c_equals_self_pending(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        confidential_balance::balance_c_equals(&b, &b)
    }

    public fun test_balance_equals_two_pending_zeros(): bool {
        let a = confidential_balance::new_pending_balance_no_randomness();
        let b = confidential_balance::new_pending_balance_no_randomness();
        confidential_balance::balance_equals(&a, &b)
    }

    public fun test_balance_c_equals_two_pending_plain_zeros(): bool {
        let a = confidential_balance::new_pending_balance_no_randomness();
        let b = confidential_balance::new_pending_balance_no_randomness();
        confidential_balance::balance_c_equals(&a, &b)
    }

    public fun test_sub_zero_pending_from_zero_stays_zero(): bool {
        let a = confidential_balance::new_pending_balance_no_randomness();
        let b = confidential_balance::new_pending_balance_no_randomness();
        confidential_balance::sub_balances_mut(&mut a, &b);
        confidential_balance::is_zero_balance(&a)
    }

    public fun test_actual_roundtrip_bytes_ok(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        let bytes = confidential_balance::balance_to_bytes(&b);
        std::option::is_some(&confidential_balance::new_actual_balance_from_bytes(bytes))
    }

    public fun test_actual_roundtrip_bytes_balance_equals_self(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        let bytes = confidential_balance::balance_to_bytes(&b);
        let opt = confidential_balance::new_actual_balance_from_bytes(bytes);
        if (std::option::is_none(&opt)) {
            false
        } else {
            confidential_balance::balance_equals(&b, std::option::borrow(&opt))
        }
    }

    public fun test_is_zero_pending_u64_zero(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        confidential_balance::is_zero_balance(&b)
    }

    public fun test_is_zero_pending_u64_one_is_false(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        !confidential_balance::is_zero_balance(&b)
    }

    public fun test_actual_from_wrong_len_is_none(): bool {
        std::option::is_none(&confidential_balance::new_actual_balance_from_bytes(x""))
    }

    public fun test_balance_c_equals_two_pending_u64_zeros(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        confidential_balance::balance_c_equals(&a, &b)
    }

    public fun test_add_two_zero_actual_stays_zero(): bool {
        let a = confidential_balance::new_actual_balance_no_randomness();
        let b = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::add_balances_mut(&mut a, &b);
        confidential_balance::is_zero_balance(&a)
    }

    public fun test_actual_from_short_len_is_none(): bool {
        let v = std::vector::range(0, 511).map(|_| 0u8);
        std::option::is_none(&confidential_balance::new_actual_balance_from_bytes(v))
    }

    public fun test_sub_zero_actual_from_zero_stays_zero(): bool {
        let a = confidential_balance::new_actual_balance_no_randomness();
        let b = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::sub_balances_mut(&mut a, &b);
        confidential_balance::is_zero_balance(&a)
    }

    public fun test_balance_equals_two_actual_zeros(): bool {
        let a = confidential_balance::new_actual_balance_no_randomness();
        let b = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::balance_equals(&a, &b)
    }

    public fun test_balance_c_equals_self_actual(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::balance_c_equals(&b, &b)
    }

    public fun test_decompress_compressed_pending_matches_plain_zero(): bool {
        let c = confidential_balance::new_compressed_pending_balance_no_randomness();
        let b = confidential_balance::decompress_balance(&c);
        let p = confidential_balance::new_pending_balance_no_randomness();
        confidential_balance::balance_equals(&b, &p)
    }

    public fun test_balance_equals_self_actual(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::balance_equals(&b, &b)
    }

    public fun test_is_zero_decompressed_compressed_pending(): bool {
        let c = confidential_balance::new_compressed_pending_balance_no_randomness();
        let b = confidential_balance::decompress_balance(&c);
        confidential_balance::is_zero_balance(&b)
    }

    public fun test_decompress_compressed_actual_matches_plain_zero(): bool {
        let c = confidential_balance::new_compressed_actual_balance_no_randomness();
        let b = confidential_balance::decompress_balance(&c);
        let a = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::balance_equals(&b, &a)
    }

    public fun test_is_zero_decompressed_compressed_actual(): bool {
        let c = confidential_balance::new_compressed_actual_balance_no_randomness();
        let b = confidential_balance::decompress_balance(&c);
        confidential_balance::is_zero_balance(&b)
    }

    public fun test_balance_c_equals_two_actual_zeros(): bool {
        let x = confidential_balance::new_actual_balance_no_randomness();
        let y = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::balance_c_equals(&x, &y)
    }

    public fun test_pending_from_257_zeros_is_none(): bool {
        let v = std::vector::range(0, 257).map(|_| 0u8);
        std::option::is_none(&confidential_balance::new_pending_balance_from_bytes(v))
    }

    public fun test_actual_from_513_zeros_is_none(): bool {
        let v = std::vector::range(0, 513).map(|_| 0u8);
        std::option::is_none(&confidential_balance::new_actual_balance_from_bytes(v))
    }

    public fun test_balance_equals_pending_plain_and_u64_zero(): bool {
        confidential_balance::balance_equals(
            &confidential_balance::new_pending_balance_no_randomness(),
            &confidential_balance::new_pending_balance_u64_no_randonmess(0),
        )
    }

    public fun test_balance_c_equals_pending_plain_and_u64_zero(): bool {
        confidential_balance::balance_c_equals(
            &confidential_balance::new_pending_balance_no_randomness(),
            &confidential_balance::new_pending_balance_u64_no_randonmess(0),
        )
    }

    public fun test_add_plain_zero_to_u64_zero_pending_stays_zero(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        let b = confidential_balance::new_pending_balance_no_randomness();
        confidential_balance::add_balances_mut(&mut a, &b);
        confidential_balance::is_zero_balance(&a)
    }

    public fun test_add_u64_zero_to_plain_zero_pending_stays_zero(): bool {
        let a = confidential_balance::new_pending_balance_no_randomness();
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        confidential_balance::add_balances_mut(&mut a, &b);
        confidential_balance::is_zero_balance(&a)
    }

    public fun test_sub_u64_zero_from_plain_zero_pending_stays_zero(): bool {
        let a = confidential_balance::new_pending_balance_no_randomness();
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        confidential_balance::sub_balances_mut(&mut a, &b);
        confidential_balance::is_zero_balance(&a)
    }

    public fun test_sub_u64_zero_from_u64_zero_pending_stays_zero(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        confidential_balance::sub_balances_mut(&mut a, &b);
        confidential_balance::is_zero_balance(&a)
    }

    public fun test_pending_u64_zero_roundtrip_bytes_balance_equals_self(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        let bytes = confidential_balance::balance_to_bytes(&b);
        let opt = confidential_balance::new_pending_balance_from_bytes(bytes);
        if (std::option::is_none(&opt)) {
            false
        } else {
            confidential_balance::balance_equals(&b, std::option::borrow(&opt))
        }
    }

    public fun test_compress_decompress_pending_u64_zero_eq_self(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        let c = confidential_balance::compress_balance(&b);
        let b2 = confidential_balance::decompress_balance(&c);
        confidential_balance::balance_equals(&b, &b2)
    }

    public fun test_balance_equals_two_u64_zero_pending(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        confidential_balance::balance_equals(&a, &b)
    }

    public fun test_split_into_chunks_u64_second_chunk(): bool {
        let amount = 0xABCD0000u64;
        let chunks = confidential_balance::split_into_chunks_u64(amount);
        let s1 = *std::vector::borrow(&chunks, 1);
        let expected = ristretto255::new_scalar_from_u64(0xABCD);
        ristretto255::scalar_equals(&s1, &expected)
    }

    public fun test_split_into_chunks_u128_second_chunk(): bool {
        let amount = 0xEF010000u128;
        let chunks = confidential_balance::split_into_chunks_u128(amount);
        let s1 = *std::vector::borrow(&chunks, 1);
        let expected = ristretto255::new_scalar_from_u128(0xEF01);
        ristretto255::scalar_equals(&s1, &expected)
    }

    public fun test_split_into_chunks_u64_third_chunk(): bool {
        let amount = 0xFACE00000000u64;
        let chunks = confidential_balance::split_into_chunks_u64(amount);
        let s2 = *std::vector::borrow(&chunks, 2);
        let expected = ristretto255::new_scalar_from_u64(0xFACE);
        ristretto255::scalar_equals(&s2, &expected)
    }

    public fun test_split_into_chunks_u64_fourth_chunk(): bool {
        let amount = 0xBEEF000000000000u64;
        let chunks = confidential_balance::split_into_chunks_u64(amount);
        let s3 = *std::vector::borrow(&chunks, 3);
        let expected = ristretto255::new_scalar_from_u64(0xBEEF);
        ristretto255::scalar_equals(&s3, &expected)
    }

    public fun test_split_into_chunks_u128_third_chunk(): bool {
        let amount = 0x123400000000u128;
        let chunks = confidential_balance::split_into_chunks_u128(amount);
        let s2 = *std::vector::borrow(&chunks, 2);
        let expected = ristretto255::new_scalar_from_u128(0x1234);
        ristretto255::scalar_equals(&s2, &expected)
    }

    public fun test_split_into_chunks_u128_fourth_chunk(): bool {
        let amount = 0xABCD000000000000u128;
        let chunks = confidential_balance::split_into_chunks_u128(amount);
        let s3 = *std::vector::borrow(&chunks, 3);
        let expected = ristretto255::new_scalar_from_u128(0xABCD);
        ristretto255::scalar_equals(&s3, &expected)
    }

    public fun test_split_into_chunks_u128_fifth_chunk(): bool {
        let amount = (0x1234 as u128) << 64;
        let chunks = confidential_balance::split_into_chunks_u128(amount);
        let s4 = *std::vector::borrow(&chunks, 4);
        let expected = ristretto255::new_scalar_from_u128(0x1234);
        ristretto255::scalar_equals(&s4, &expected)
    }

    public fun test_split_into_chunks_u128_sixth_chunk(): bool {
        let amount = (0xABCD as u128) << 80;
        let chunks = confidential_balance::split_into_chunks_u128(amount);
        let s5 = *std::vector::borrow(&chunks, 5);
        let expected = ristretto255::new_scalar_from_u128(0xABCD);
        ristretto255::scalar_equals(&s5, &expected)
    }

    public fun test_split_into_chunks_u128_seventh_chunk(): bool {
        let amount = (0x1111 as u128) << 96;
        let chunks = confidential_balance::split_into_chunks_u128(amount);
        let s6 = *std::vector::borrow(&chunks, 6);
        let expected = ristretto255::new_scalar_from_u128(0x1111);
        ristretto255::scalar_equals(&s6, &expected)
    }

    public fun test_split_into_chunks_u128_eighth_chunk(): bool {
        let amount = (0x2222 as u128) << 112;
        let chunks = confidential_balance::split_into_chunks_u128(amount);
        let s7 = *std::vector::borrow(&chunks, 7);
        let expected = ristretto255::new_scalar_from_u128(0x2222);
        ristretto255::scalar_equals(&s7, &expected)
    }

    public fun test_is_zero_actual_after_compress_decompress_no_randomness(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        let c = confidential_balance::compress_balance(&b);
        let b2 = confidential_balance::decompress_balance(&c);
        confidential_balance::is_zero_balance(&b2)
    }
}
"#;

pub struct ConfidentialBalanceSuite;

impl DiffTestSuite for ConfidentialBalanceSuite {
    fn id(&self) -> &'static str {
        "confidential_balance"
    }

    fn name(&self) -> &str {
        "0x1::difftest_confidential_balance"
    }

    fn load_module(&self, storage: &mut InMemoryStorage) -> Result<()> {
        let modules = compile_with_aptos_head_bundle(TEST_SOURCE)?;
        for module in &modules {
            let blob = module_blob(module)?;
            storage.add_module_bytes(module.self_addr(), module.self_name(), blob.into());
        }
        Ok(())
    }

    fn generate_test_cases(&self, storage: &mut InMemoryStorage) -> Result<Vec<TestCase>> {
        let mut cases = Vec::new();
        let tests: &[(&str, &str, Vec<crate::schema::TypedValue>)] = &[
            ("test_get_pending_balance_chunks", "const", vec![]),
            ("test_get_actual_balance_chunks", "const", vec![]),
            ("test_get_chunk_size_bits", "const", vec![]),
            ("test_zero_pending_balance_to_bytes_len", "len", vec![]),
            ("test_zero_actual_balance_to_bytes_len", "len", vec![]),
            ("test_is_zero_pending", "bool", vec![]),
            ("test_is_zero_actual", "bool", vec![]),
            (
                "test_compress_decompress_roundtrip_pending",
                "roundtrip",
                vec![],
            ),
            (
                "test_compress_decompress_roundtrip_actual",
                "roundtrip",
                vec![],
            ),
            ("test_pending_from_wrong_len_is_none", "none", vec![]),
            ("test_pending_from_short_len_is_none", "none", vec![]),
            ("test_pending_roundtrip_bytes_ok", "some", vec![]),
            (
                "test_pending_roundtrip_bytes_balance_equals_self",
                "rt_eq_self",
                vec![],
            ),
            ("test_add_two_zero_pending_stays_zero", "add", vec![]),
            ("test_add_zero_amount_chunks_equal", "add_u64", vec![]),
            (
                "test_split_into_chunks_u64_first_chunk",
                "split_u64",
                vec![],
            ),
            (
                "test_split_into_chunks_u128_first_chunk",
                "split_u128",
                vec![],
            ),
            ("test_balance_equals_self_pending", "eq_self", vec![]),
            ("test_balance_c_equals_self_pending", "eq_c_self", vec![]),
            ("test_balance_equals_two_pending_zeros", "eq_two0", vec![]),
            (
                "test_balance_c_equals_two_pending_plain_zeros",
                "eq_c_two0",
                vec![],
            ),
            (
                "test_sub_zero_pending_from_zero_stays_zero",
                "sub_zero",
                vec![],
            ),
            ("test_actual_roundtrip_bytes_ok", "actual_rt", vec![]),
            (
                "test_actual_roundtrip_bytes_balance_equals_self",
                "actual_rt_eq",
                vec![],
            ),
            ("test_is_zero_pending_u64_zero", "pending_u64_zero", vec![]),
            (
                "test_is_zero_pending_u64_one_is_false",
                "pending_u64_nz",
                vec![],
            ),
            ("test_actual_from_wrong_len_is_none", "actual_none", vec![]),
            (
                "test_balance_c_equals_two_pending_u64_zeros",
                "eq_c_u64",
                vec![],
            ),
            ("test_add_two_zero_actual_stays_zero", "add_actual0", vec![]),
            ("test_actual_from_short_len_is_none", "actual_short", vec![]),
            (
                "test_sub_zero_actual_from_zero_stays_zero",
                "sub_actual0",
                vec![],
            ),
            ("test_balance_equals_two_actual_zeros", "eq_actual0", vec![]),
            ("test_balance_c_equals_self_actual", "eq_c_act_self", vec![]),
            (
                "test_decompress_compressed_pending_matches_plain_zero",
                "dec_cmp_zero",
                vec![],
            ),
            ("test_balance_equals_self_actual", "eq_act_self", vec![]),
            (
                "test_is_zero_decompressed_compressed_pending",
                "dec_zero",
                vec![],
            ),
            (
                "test_decompress_compressed_actual_matches_plain_zero",
                "dec_act_zero",
                vec![],
            ),
            (
                "test_is_zero_decompressed_compressed_actual",
                "dec_act_zero2",
                vec![],
            ),
            (
                "test_balance_c_equals_two_actual_zeros",
                "eq_c_act0",
                vec![],
            ),
            ("test_pending_from_257_zeros_is_none", "pend_257", vec![]),
            ("test_actual_from_513_zeros_is_none", "act_513", vec![]),
            (
                "test_balance_equals_pending_plain_and_u64_zero",
                "eq_p_u64z",
                vec![],
            ),
            (
                "test_balance_c_equals_pending_plain_and_u64_zero",
                "eqc_p_u64z",
                vec![],
            ),
            (
                "test_add_plain_zero_to_u64_zero_pending_stays_zero",
                "add_p_u64z",
                vec![],
            ),
            (
                "test_add_u64_zero_to_plain_zero_pending_stays_zero",
                "add_u64z_p",
                vec![],
            ),
            (
                "test_sub_u64_zero_from_plain_zero_pending_stays_zero",
                "sub_p_u64z",
                vec![],
            ),
            (
                "test_sub_u64_zero_from_u64_zero_pending_stays_zero",
                "sub_u64z2",
                vec![],
            ),
            (
                "test_pending_u64_zero_roundtrip_bytes_balance_equals_self",
                "rt_u64z",
                vec![],
            ),
            (
                "test_compress_decompress_pending_u64_zero_eq_self",
                "cmp_u64z",
                vec![],
            ),
            (
                "test_balance_equals_two_u64_zero_pending",
                "eq_u642",
                vec![],
            ),
            (
                "test_split_into_chunks_u64_second_chunk",
                "split64_2",
                vec![],
            ),
            (
                "test_split_into_chunks_u128_second_chunk",
                "split128_2",
                vec![],
            ),
            (
                "test_split_into_chunks_u64_third_chunk",
                "split64_3",
                vec![],
            ),
            (
                "test_split_into_chunks_u64_fourth_chunk",
                "split64_4",
                vec![],
            ),
            (
                "test_split_into_chunks_u128_third_chunk",
                "split128_3",
                vec![],
            ),
            (
                "test_split_into_chunks_u128_fourth_chunk",
                "split128_4",
                vec![],
            ),
            (
                "test_split_into_chunks_u128_fifth_chunk",
                "split128_5",
                vec![],
            ),
            (
                "test_split_into_chunks_u128_sixth_chunk",
                "split128_6",
                vec![],
            ),
            (
                "test_split_into_chunks_u128_seventh_chunk",
                "split128_7",
                vec![],
            ),
            (
                "test_split_into_chunks_u128_eighth_chunk",
                "split128_8",
                vec![],
            ),
            (
                "test_is_zero_actual_after_compress_decompress_no_randomness",
                "act_cmp0",
                vec![],
            ),
        ];
        for (function, label, args) in tests {
            let result = run_test_case(storage, STD_ADDR, MODULE_NAME, function, args)?;
            cases.push(TestCase {
                function: format!("{} [{}]", function, label),
                type_args: None,
                args: args.clone(),
                result,
                skip_lean: false,
            });
        }
        Ok(cases)
    }
}
