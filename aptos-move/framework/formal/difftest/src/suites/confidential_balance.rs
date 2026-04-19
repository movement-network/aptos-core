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

    // ─────────────────── STRONG tests on NON-ZERO balances ────────────────────
    // Every existing balance test feeds the zero balance, which makes homomorphic-op
    // bugs invisible (e.g. `sub_balances_mut` that accidentally calls `add_assign` —
    // a real copy-paste bug latent in `confidential_balance.move` before this row).
    // The tests below distinguish non-equal balances and exercise the non-zero
    // algebra so any regression to a trivial impl causes the VM result to drift
    // from the Lean `ldTrue` pin → **FAIL** (i.e. the bug is caught).

    /// Different u64 amounts must not compare equal. Catches: `balance_equals`
    /// that always returns `true`, or compares only length.
    public fun test_bal_different_u64_pending_not_equal(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        !confidential_balance::balance_equals(&a, &b)
    }

    /// Same, with `balance_c_equals` (only value component). Catches: `_c_equals`
    /// that ignores amount by reading the wrong chunk index.
    public fun test_bal_different_u64_pending_c_not_equal(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        !confidential_balance::balance_c_equals(&a, &b)
    }

    /// Plain-zero and u64(1) pending balances must not be equal. Catches:
    /// `balance_equals` that treats any two length-4 balances as equal.
    public fun test_bal_plain_zero_not_equal_u64_one(): bool {
        let a = confidential_balance::new_pending_balance_no_randomness();
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        !confidential_balance::balance_equals(&a, &b)
    }

    /// u64(1) is not the zero balance. Stronger than the u64(0) positive because it
    /// requires `is_zero_balance` to inspect every chunk; a bug short-circuiting on
    /// length or the first zero-chunk would slip the u64(1) test.
    public fun test_bal_u64_large_not_zero(): bool {
        // `0xF000` fits in the first 16-bit chunk and is nonzero.
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0xF000);
        !confidential_balance::is_zero_balance(&b)
    }

    /// A non-zero amount in chunk 3 (bits 48..64) must still be detected as
    /// non-zero. Catches: `is_zero_balance` that only inspects the first chunk.
    public fun test_bal_u64_high_chunk_not_zero(): bool {
        // `0xBEEF << 48` places all the mass in chunk index 3.
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0xBEEF000000000000u64);
        !confidential_balance::is_zero_balance(&b)
    }

    /// Serialized bytes must differ when the amount differs. Catches:
    /// `balance_to_bytes` that writes constants or forgets chunks.
    public fun test_bal_u64_one_bytes_differ_from_u64_two_bytes(): bool {
        let b1 = confidential_balance::balance_to_bytes(
            &confidential_balance::new_pending_balance_u64_no_randonmess(1));
        let b2 = confidential_balance::balance_to_bytes(
            &confidential_balance::new_pending_balance_u64_no_randonmess(2));
        b1 != b2
    }

    /// Homomorphic add on the balance layer: pending(1) + pending(2) ⇒ pending(3).
    /// Randomness is zero throughout, so the identity reduces to scalar addition at
    /// the chunk level. Catches: `add_balances_mut` that is a no-op / swaps operands /
    /// secretly calls `sub`.
    public fun test_bal_add_u64_one_plus_u64_two_equals_u64_three(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        confidential_balance::add_balances_mut(&mut a, &b);
        let expected = confidential_balance::new_pending_balance_u64_no_randonmess(3);
        confidential_balance::balance_equals(&a, &expected)
    }

    /// Homomorphic sub on the balance layer: pending(v) − pending(v) ⇒ pending(0).
    /// **This row catches the latent bug** in `sub_balances_mut` (which used
    /// `ciphertext_add_assign` instead of `ciphertext_sub_assign` before the fix).
    /// Under the bug, `sub(1, 1)` returned `add(1, 1) = 2`, i.e. non-zero.
    public fun test_bal_sub_u64_one_from_u64_one_is_zero(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        confidential_balance::sub_balances_mut(&mut a, &b);
        confidential_balance::is_zero_balance(&a)
    }

    /// Homomorphic sub: pending(3) − pending(2) ⇒ pending(1). Pins the full
    /// scalar-subtraction semantics, not just the "self-minus-self is zero" edge.
    public fun test_bal_sub_u64_three_minus_two_equals_one(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(3);
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        confidential_balance::sub_balances_mut(&mut a, &b);
        let expected = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        confidential_balance::balance_equals(&a, &expected)
    }

    /// Compress/decompress on a non-zero pending balance must preserve the balance.
    /// Catches: compress/decompress that silently zeros the chunks.
    public fun test_bal_compress_decompress_nonzero_pending_equals_self(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(42);
        let c = confidential_balance::compress_balance(&b);
        let b2 = confidential_balance::decompress_balance(&c);
        confidential_balance::balance_equals(&b, &b2)
    }

    /// Serialization round-trip on a non-zero pending balance. Catches: `from_bytes`
    /// that silently produces the zero balance regardless of input.
    public fun test_bal_pending_u64_one_bytes_roundtrip_equals_self(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let bytes = confidential_balance::balance_to_bytes(&b);
        let opt = confidential_balance::new_pending_balance_from_bytes(bytes);
        if (std::option::is_none(&opt)) {
            false
        } else {
            confidential_balance::balance_equals(&b, std::option::borrow(&opt))
        }
    }

    /// Non-zero bytes exist in the serialized form of pending(1). Catches:
    /// `balance_to_bytes` that zeros everything.
    public fun test_bal_pending_u64_one_bytes_contains_nonzero(): bool {
        let bytes = confidential_balance::balance_to_bytes(
            &confidential_balance::new_pending_balance_u64_no_randonmess(1));
        let i = 0;
        let found = false;
        let len = std::vector::length(&bytes);
        while (i < len) {
            if (*std::vector::borrow(&bytes, i) != 0u8) { found = true };
            i = i + 1;
        };
        found
    }

    /// `get_pending_balance_chunks` must equal `4` (the invariant used by
    /// `new_pending_balance_u64_no_randonmess` and every pending oracle row).
    /// Already covered as `u64` const, but this pins the **value** as `bool`.
    public fun test_bal_get_pending_chunks_is_four(): bool {
        confidential_balance::get_pending_balance_chunks() == 4
    }

    /// `get_actual_balance_chunks` must equal `8`.
    public fun test_bal_get_actual_chunks_is_eight(): bool {
        confidential_balance::get_actual_balance_chunks() == 8
    }

    /// `get_chunk_size_bits` must equal `16`.
    public fun test_bal_get_chunk_bits_is_sixteen(): bool {
        confidential_balance::get_chunk_size_bits() == 16
    }

    /// `split_into_chunks_u64(0)` produces 4 zero scalars. Pins the "all zeros"
    /// expansion of the splitter.
    public fun test_bal_split_u64_zero_all_chunks_zero(): bool {
        let chunks = confidential_balance::split_into_chunks_u64(0u64);
        std::vector::length(&chunks) == 4
            && ristretto255::scalar_is_zero(std::vector::borrow(&chunks, 0))
            && ristretto255::scalar_is_zero(std::vector::borrow(&chunks, 1))
            && ristretto255::scalar_is_zero(std::vector::borrow(&chunks, 2))
            && ristretto255::scalar_is_zero(std::vector::borrow(&chunks, 3))
    }

    /// `split_into_chunks_u128(0)` produces 8 zero scalars.
    public fun test_bal_split_u128_zero_all_chunks_zero(): bool {
        let chunks = confidential_balance::split_into_chunks_u128(0u128);
        std::vector::length(&chunks) == 8
            && ristretto255::scalar_is_zero(std::vector::borrow(&chunks, 0))
            && ristretto255::scalar_is_zero(std::vector::borrow(&chunks, 7))
    }

    /// `split_into_chunks_u64(1)` has chunk 0 = scalar(1) and all others zero.
    /// Catches: splitter that writes the same chunk everywhere.
    public fun test_bal_split_u64_one_only_first_chunk_nonzero(): bool {
        let chunks = confidential_balance::split_into_chunks_u64(1u64);
        let c0 = std::vector::borrow(&chunks, 0);
        let one = ristretto255::new_scalar_from_u64(1);
        ristretto255::scalar_equals(c0, &one)
            && ristretto255::scalar_is_zero(std::vector::borrow(&chunks, 1))
            && ristretto255::scalar_is_zero(std::vector::borrow(&chunks, 2))
            && ristretto255::scalar_is_zero(std::vector::borrow(&chunks, 3))
    }

    // ─────────── MASKING-precedence pins (`split_into_chunks_u64`) ───────────
    // The splitter uses `amount >> (i * 16) & 0xffff`. Move operator precedence
    // matters: the intended parse is `(amount >> (i*16)) & 0xffff` (mask AFTER
    // shift). If a future edit were to accidentally reorder this as
    // `amount >> ((i*16) & 0xffff)` — which is valid syntax and passes the
    // `0x*ABCD*0000` family of existing tests because the mask `& 0xffff` is a
    // no-op on small shift counts — the splitter would leak ALL 64 bits into
    // chunk 0. The rows below feed an amount whose value is explicitly the
    // boundary between two 16-bit chunks (`0x10000`), so a missing mask after
    // the shift is detectable as a non-zero chunk-0 scalar.

    /// `split_into_chunks_u64(0x10000)` must place chunk 0 = scalar(0)
    /// (the `& 0xffff` mask strips bit 16). Catches: operator-precedence
    /// regression in the splitter.
    public fun test_bal_split_u64_65536_chunk0_is_zero(): bool {
        let chunks = confidential_balance::split_into_chunks_u64(0x10000u64);
        ristretto255::scalar_is_zero(std::vector::borrow(&chunks, 0))
    }

    /// `split_into_chunks_u64(0x10001)` must place chunk 0 = scalar(1) (low
    /// 16 bits of `0x10001`). Catches: same precedence regression. On the
    /// buggy variant chunk 0 would be `scalar(0x10001) != scalar(1)`.
    public fun test_bal_split_u64_65537_chunk0_is_one(): bool {
        let chunks = confidential_balance::split_into_chunks_u64(0x10001u64);
        let expected = ristretto255::new_scalar_from_u64(1);
        ristretto255::scalar_equals(std::vector::borrow(&chunks, 0), &expected)
    }

    /// `split_into_chunks_u128(0x10000)` must place chunk 0 = scalar(0) and
    /// chunk 1 = scalar(1). Twin of `..._u64_65536_chunk0_is_zero` for u128.
    public fun test_bal_split_u128_65536_chunk0_is_zero_chunk1_is_one(): bool {
        let chunks = confidential_balance::split_into_chunks_u128(0x10000u128);
        let one = ristretto255::new_scalar_from_u128(1);
        ristretto255::scalar_is_zero(std::vector::borrow(&chunks, 0))
            && ristretto255::scalar_equals(std::vector::borrow(&chunks, 1), &one)
    }

    /// `split_into_chunks_u64(0xffff)` — the maximum single-chunk value —
    /// must appear verbatim in chunk 0 (low 16 bits saturated) with all
    /// higher chunks zero. Catches: splitter that always uses low ≤8 bits.
    public fun test_bal_split_u64_0xffff_chunk0_is_0xffff(): bool {
        let chunks = confidential_balance::split_into_chunks_u64(0xffffu64);
        let expected = ristretto255::new_scalar_from_u64(0xffff);
        ristretto255::scalar_equals(std::vector::borrow(&chunks, 0), &expected)
            && ristretto255::scalar_is_zero(std::vector::borrow(&chunks, 1))
            && ristretto255::scalar_is_zero(std::vector::borrow(&chunks, 2))
            && ristretto255::scalar_is_zero(std::vector::borrow(&chunks, 3))
    }

    // ─────────── is_zero_balance: chunk-by-chunk pins ───────────

    /// Non-zero mass exclusively in chunk 1 (bits 16..32) must be detected
    /// as non-zero. Catches: `is_zero_balance` that skips non-first chunks.
    public fun test_bal_u64_chunk1_only_not_zero(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0x0001_0000u64);
        !confidential_balance::is_zero_balance(&b)
    }

    /// Non-zero mass exclusively in chunk 2 (bits 32..48).
    public fun test_bal_u64_chunk2_only_not_zero(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0x0001_0000_0000u64);
        !confidential_balance::is_zero_balance(&b)
    }

    // ─────────── balance_equals ≠ balance_c_equals discriminator ───────────

    /// Build a "weird" pending balance whose `C` components are identity
    /// (32 zero bytes) but whose `D` components are the **A_POINT** (non-
    /// identity), constructed via `new_pending_balance_from_bytes`. Against
    /// the canonical zero pending balance (C = D = identity), this must give:
    ///   - `balance_c_equals(zero, weird) == true`   (both C's are identity)
    ///   - `balance_equals(zero, weird)  == false`  (D's differ)
    /// Catches: `balance_c_equals` accidentally comparing D as well (or
    /// vice versa). Depends on `ristretto255::A_POINT` being a valid Ristretto
    /// compressed encoding distinct from identity — the same fixture byte
    /// string used throughout `confidential_proof.rs`.
    public fun test_bal_c_equals_but_not_equals_when_only_d_differs(): bool {
        let weird_bytes = vector<u8>[];
        let i = 0;
        while (i < 4) {
            let j = 0;
            while (j < 32) {
                std::vector::push_back(&mut weird_bytes, 0u8);
                j = j + 1;
            };
            std::vector::append(&mut weird_bytes,
                x"e87feda199d72b83de4f5b2d45d34805c57019c6c59c42cb70ee3d19aa996f75");
            i = i + 1;
        };
        let weird_opt = confidential_balance::new_pending_balance_from_bytes(weird_bytes);
        if (std::option::is_none(&weird_opt)) {
            false
        } else {
            let weird = std::option::borrow(&weird_opt);
            let zero = confidential_balance::new_pending_balance_no_randomness();
            confidential_balance::balance_c_equals(&zero, weird)
                && !confidential_balance::balance_equals(&zero, weird)
        }
    }

    // ─────────── Arithmetic algebra pins (non-zero, commutativity,
    //               associativity, add-is-not-sub) ───────────

    /// Commutativity of `add_balances_mut` on non-zero inputs: `a + b = b + a`.
    /// Catches: add that reads `rhs` but writes back only the rhs chunks.
    public fun test_bal_add_commutes_nonzero(): bool {
        let a1 = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let b1 = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        confidential_balance::add_balances_mut(&mut a1, &b1);

        let a2 = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        let b2 = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        confidential_balance::add_balances_mut(&mut a2, &b2);

        confidential_balance::balance_equals(&a1, &a2)
    }

    /// Associativity of `add_balances_mut` on three non-zero balances:
    /// `(a + b) + c == a + (b + c)` — pinned by scalar-addition invariance
    /// in the absence of randomness.
    public fun test_bal_add_associative_nonzero(): bool {
        let ab = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let c = confidential_balance::new_pending_balance_u64_no_randonmess(3);
        confidential_balance::add_balances_mut(
            &mut ab, &confidential_balance::new_pending_balance_u64_no_randonmess(2));
        confidential_balance::add_balances_mut(&mut ab, &c);

        let bc = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        confidential_balance::add_balances_mut(
            &mut bc, &confidential_balance::new_pending_balance_u64_no_randonmess(3));
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        confidential_balance::add_balances_mut(&mut a, &bc);

        confidential_balance::balance_equals(&ab, &a)
    }

    /// Identity of addition with a NON-ZERO left operand:
    /// `add_balances_mut(pending(v), pending(0)) == pending(v)` for v = 5.
    /// Catches: `add_balances_mut` that zeros or overwrites `lhs`.
    public fun test_bal_add_zero_rhs_preserves_nonzero_lhs(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(5);
        let z = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        confidential_balance::add_balances_mut(&mut a, &z);
        let expected = confidential_balance::new_pending_balance_u64_no_randonmess(5);
        confidential_balance::balance_equals(&a, &expected)
    }

    /// Identity of subtraction with a NON-ZERO left operand:
    /// `sub_balances_mut(pending(v), pending(0)) == pending(v)` for v = 5.
    /// Critical twin of the `sub_balances_mut` bug check: this row would
    /// FAIL under the bugged `add_assign`-inside-sub variant (would produce
    /// `pending(5) + pending(0) = pending(5)` — same result — so it alone
    /// does **not** discriminate; the discriminating rows are
    /// `test_bal_sub_u64_one_from_u64_one_is_zero` and
    /// `test_bal_sub_u64_three_minus_two_equals_one`). Still useful as a
    /// positive identity pin preventing later breakage of the "zero rhs"
    /// path.
    public fun test_bal_sub_zero_rhs_preserves_nonzero_lhs(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(5);
        let z = confidential_balance::new_pending_balance_u64_no_randonmess(0);
        confidential_balance::sub_balances_mut(&mut a, &z);
        let expected = confidential_balance::new_pending_balance_u64_no_randonmess(5);
        confidential_balance::balance_equals(&a, &expected)
    }

    /// Round-trip: `(a + b) − b == a` for non-zero `a, b`. Catches any
    /// silent re-introduction of the historical `sub_balances_mut` bug
    /// (add instead of sub) because the "re-subtract" step would then add
    /// another `b` and the equality would fail.
    public fun test_bal_add_then_sub_recovers_original(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(5);
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(3);
        confidential_balance::add_balances_mut(&mut a, &b);
        confidential_balance::sub_balances_mut(&mut a, &b);
        let expected = confidential_balance::new_pending_balance_u64_no_randonmess(5);
        confidential_balance::balance_equals(&a, &expected)
    }

    /// `balance_to_bytes` is sensitive to chunk order: pending(0x00020001)
    /// (chunks = [1, 2, 0, 0]) and pending(0x00010002) (chunks = [2, 1, 0, 0])
    /// differ in the first 64 bytes. Catches: serializer that sorts, reverses,
    /// or drops trailing zero chunks.
    public fun test_bal_bytes_chunk_order_matters(): bool {
        let b1 = confidential_balance::balance_to_bytes(
            &confidential_balance::new_pending_balance_u64_no_randonmess(0x00020001u64));
        let b2 = confidential_balance::balance_to_bytes(
            &confidential_balance::new_pending_balance_u64_no_randonmess(0x00010002u64));
        b1 != b2
    }

    /// `is_zero_balance` must return `false` for a pending balance that has
    /// non-zero mass ONLY in chunk index 2 (bits 32..48). A chunk-index
    /// confusion in `is_zero_balance` that only scans indices {0, 1, 3}
    /// would slip this. Catches: off-by-one / loop-range regressions.
    public fun test_bal_u64_chunk2_only_not_zero_strict(): bool {
        // `0x1234 << 32` — exactly one 16-bit mass unit in chunk 2, nothing
        // elsewhere; `is_zero_balance` must traverse all chunks.
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0x1234_0000_0000u64);
        !confidential_balance::is_zero_balance(&b)
    }

    /// For distinct non-zero `u64(3)` and `u64(2)`, `add_balances_mut(lhs=3, rhs=2)`
    /// MUST produce a different ciphertext bag than `sub_balances_mut(lhs=3, rhs=2)`.
    /// Catches: the exact `sub_balances_mut == add_balances_mut` bug that this
    /// diff-testing campaign caught in the codebase (regression coverage at
    /// the balance layer).
    public fun test_bal_add_vs_sub_distinct_nonzero(): bool {
        let lhs_a = confidential_balance::new_pending_balance_u64_no_randonmess(3);
        let rhs_a = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        confidential_balance::add_balances_mut(&mut lhs_a, &rhs_a);
        let lhs_s = confidential_balance::new_pending_balance_u64_no_randonmess(3);
        let rhs_s = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        confidential_balance::sub_balances_mut(&mut lhs_s, &rhs_s);
        !confidential_balance::balance_equals(&lhs_a, &lhs_s)
    }

    /// `sub_balances_mut` is NOT commutative on distinct non-zero inputs:
    /// `sub(bal(5), bal(3))` encrypts `+2`, but `sub(bal(3), bal(5))` encrypts
    /// `-2`. The two must differ. Catches: `sub_balances_mut` that accidentally
    /// treats operands symmetrically (e.g., takes absolute value or wraps into
    /// the other direction).
    public fun test_bal_sub_not_commutative_on_distinct_nonzero(): bool {
        let lhs_ab = confidential_balance::new_pending_balance_u64_no_randonmess(5);
        let rhs_ab = confidential_balance::new_pending_balance_u64_no_randonmess(3);
        confidential_balance::sub_balances_mut(&mut lhs_ab, &rhs_ab);
        let lhs_ba = confidential_balance::new_pending_balance_u64_no_randonmess(3);
        let rhs_ba = confidential_balance::new_pending_balance_u64_no_randonmess(5);
        confidential_balance::sub_balances_mut(&mut lhs_ba, &rhs_ba);
        !confidential_balance::balance_equals(&lhs_ab, &lhs_ba)
    }

    /// `split_into_chunks_u64(0xffff_ffff_ffff_ffff)` — every one of the 4
    /// chunks must equal `0xffff`. Catches: chunk-splitter that masks with
    /// the wrong constant (e.g., `0xff` instead of `0xffff`), that truncates
    /// high chunks, or that shifts in the wrong direction.
    public fun test_bal_split_u64_max_all_chunks_ffff(): bool {
        let chunks = confidential_balance::split_into_chunks_u64(0xffff_ffff_ffff_ffffu64);
        let expected = ristretto255::new_scalar_from_u64(0xffffu64);
        let i = 0;
        let ok = chunks.length() == 4;
        while (i < 4) {
            if (!ristretto255::scalar_equals(&chunks[i], &expected)) { ok = false; };
            i = i + 1;
        };
        ok
    }

    /// `split_into_chunks_u128((0xffff as u128) << 112)` — only chunk 7 (the
    /// top 16 bits) is set to `0xffff`; all other chunks must be 0. Catches:
    /// splitter with off-by-one on the top chunk, or that silently drops the
    /// highest chunk.
    public fun test_bal_split_u128_top_chunk_ffff_only(): bool {
        let amount: u128 = (0xffffu128) << 112;
        let chunks = confidential_balance::split_into_chunks_u128(amount);
        let zero = ristretto255::scalar_zero();
        let ffff = ristretto255::new_scalar_from_u64(0xffffu64);
        let ok = chunks.length() == 8
            && ristretto255::scalar_equals(&chunks[7], &ffff);
        let i = 0;
        while (i < 7) {
            if (!ristretto255::scalar_equals(&chunks[i], &zero)) { ok = false; };
            i = i + 1;
        };
        ok
    }

    /// `add_balances_mut` accumulates correctly across THREE distinct
    /// non-zero operands: `0 + 1 + 2 + 3 == 6`. Catches: `add_balances_mut`
    /// that is a no-op on the accumulator or that overwrites with rhs.
    public fun test_bal_add_balances_mut_accumulates_three(): bool {
        let acc = confidential_balance::new_pending_balance_no_randomness();
        let b1 = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let b2 = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        let b3 = confidential_balance::new_pending_balance_u64_no_randonmess(3);
        confidential_balance::add_balances_mut(&mut acc, &b1);
        confidential_balance::add_balances_mut(&mut acc, &b2);
        confidential_balance::add_balances_mut(&mut acc, &b3);
        let b6 = confidential_balance::new_pending_balance_u64_no_randonmess(6);
        confidential_balance::balance_equals(&acc, &b6)
    }

    /// `sub_balances_mut` chained: `10 -= 3 -= 2 -= 1 == 4`. Catches
    /// `sub_balances_mut` that is a no-op, that adds instead of subtracts
    /// (the `sub_balances_mut` bug itself — regression coverage), or that
    /// returns the rhs.
    public fun test_bal_sub_balances_mut_chain_nonzero(): bool {
        let acc = confidential_balance::new_pending_balance_u64_no_randonmess(10);
        let b1 = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let b2 = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        let b3 = confidential_balance::new_pending_balance_u64_no_randonmess(3);
        confidential_balance::sub_balances_mut(&mut acc, &b3);
        confidential_balance::sub_balances_mut(&mut acc, &b2);
        confidential_balance::sub_balances_mut(&mut acc, &b1);
        let b4 = confidential_balance::new_pending_balance_u64_no_randonmess(4);
        confidential_balance::balance_equals(&acc, &b4)
    }

    /// `balance_to_bytes` then `new_pending_balance_from_bytes` on a
    /// non-zero pending balance roundtrips via BYTE equality (stronger than
    /// `balance_equals`, which only compares ciphertext points). Catches:
    /// serializer that loses canonical point encoding information, or a
    /// deserializer that silently accepts non-canonical bytes and re-encodes
    /// to a different canonical form.
    public fun test_bal_pending_u64_three_bytes_roundtrip_byte_equals(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(3);
        let bytes = confidential_balance::balance_to_bytes(&b);
        let b2_opt = confidential_balance::new_pending_balance_from_bytes(bytes);
        if (b2_opt.is_none()) {
            return false
        };
        let b2 = b2_opt.extract();
        let bytes2 = confidential_balance::balance_to_bytes(&b2);
        let bytes3 = confidential_balance::balance_to_bytes(&b);
        bytes2 == bytes3
    }

    /// `balance_to_bytes(zero_pending)` must be **256 zero bytes** — the
    /// concatenation of four zero-ciphertext encodings (each 64 zero bytes
    /// for `(identity, identity)`). Catches: a serializer that accidentally
    /// encodes a non-identity point in place of the identity (e.g., the
    /// basepoint), or that emits a length prefix.
    public fun test_bal_zero_pending_bytes_all_zero(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let bytes = confidential_balance::balance_to_bytes(&b);
        if (bytes.length() != 256) { return false };
        let i = 0;
        while (i < 256) {
            if (bytes[i] != 0u8) { return false };
            i = i + 1;
        };
        true
    }

    /// Dual pin for actual balance: `balance_to_bytes(zero_actual)` must be
    /// **512 zero bytes**. Catches the same class of serializer bug as
    /// `..._zero_pending_bytes_all_zero` at the 8-chunk (actual) size.
    public fun test_bal_zero_actual_bytes_all_zero(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        let bytes = confidential_balance::balance_to_bytes(&b);
        if (bytes.length() != 512) { return false };
        let i = 0;
        while (i < 512) {
            if (bytes[i] != 0u8) { return false };
            i = i + 1;
        };
        true
    }

    /// `balance_to_bytes(new_pending_balance_u64_no_randonmess(1))` — chunk 0
    /// encrypts plaintext `1` (so `left = basepoint`, `right = identity`),
    /// chunks 1..=3 encrypt plaintext `0` (both components identity). Pins:
    /// (i) the FIRST 32 bytes equal `basepoint_compressed` (so chunk-0
    /// left was serialized first); (ii) bytes[32..64] are all zero (chunk-0
    /// right = identity); (iii) bytes[64..256] are all zero (chunks 1..=3
    /// fully identity). Catches: chunk reorder (e.g., reversing the chunk
    /// vector — catastrophic for downstream arithmetic), left/right swap
    /// inside the inner `ciphertext_to_bytes`, or a serializer that emits
    /// the chunks in big-endian bit order instead of little-endian.
    public fun test_bal_pending_u64_one_byte_layout(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let bytes = confidential_balance::balance_to_bytes(&b);
        if (bytes.length() != 256) { return false };
        let first32 = bytes.slice(0, 32);
        let bp_bytes = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        if (first32 != bp_bytes) { return false };
        let i = 32;
        while (i < 256) {
            if (bytes[i] != 0u8) { return false };
            i = i + 1;
        };
        true
    }

    /// Reject a 256-byte input where the 32-byte "left" point of chunk 0 is
    /// NOT a canonical Ristretto encoding. `new_pending_balance_from_bytes`
    /// MUST return `None` (because the inner
    /// `new_ciphertext_from_bytes` validates each point). Catches a
    /// deserializer that skips point validation and silently constructs a
    /// balance containing garbage. Uses all-`0xff` as the invalid prefix
    /// (`0xff * 32` is not a valid Ristretto255 encoding).
    public fun test_bal_pending_from_bytes_invalid_chunk0_left_is_none(): bool {
        // first 32 bytes = invalid 0xff...ff, rest = zero (valid identity).
        let bytes = vector[];
        let i = 0;
        while (i < 32) {
            bytes.push_back(0xffu8);
            i = i + 1;
        };
        while (i < 256) {
            bytes.push_back(0u8);
            i = i + 1;
        };
        confidential_balance::new_pending_balance_from_bytes(bytes).is_none()
    }

    /// Dual pin for the LAST chunk: invalidate bytes[224..256] (chunk 3,
    /// "right" point). `new_pending_balance_from_bytes` MUST still return
    /// `None`. Catches a deserializer that only validates the first chunk
    /// (e.g., early-exit loop bug).
    public fun test_bal_pending_from_bytes_invalid_chunk3_right_is_none(): bool {
        let bytes = vector[];
        let i = 0;
        while (i < 224) {
            bytes.push_back(0u8);
            i = i + 1;
        };
        while (i < 256) {
            bytes.push_back(0xffu8);
            i = i + 1;
        };
        confidential_balance::new_pending_balance_from_bytes(bytes).is_none()
    }

    /// `new_compressed_pending_balance_no_randomness` must produce a value
    /// that, when decompressed, is `balance_equals` to
    /// `new_pending_balance_no_randomness`. Catches a silent divergence
    /// between the "plain" and "compressed" zero-pending constructors,
    /// which would manifest as nonsensical chain state on `register`
    /// (since `register_internal` uses the compressed variant).
    public fun test_bal_compressed_pending_no_rand_matches_plain(): bool {
        let c = confidential_balance::new_compressed_pending_balance_no_randomness();
        let b_c = confidential_balance::decompress_balance(&c);
        let b_plain = confidential_balance::new_pending_balance_no_randomness();
        confidential_balance::balance_equals(&b_c, &b_plain)
    }

    /// Dual of `..._compressed_pending_no_rand_matches_plain` for the
    /// **actual** (8-chunk) balance constructor used by `register_internal`.
    public fun test_bal_compressed_actual_no_rand_matches_plain(): bool {
        let c = confidential_balance::new_compressed_actual_balance_no_randomness();
        let b_c = confidential_balance::decompress_balance(&c);
        let b_plain = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::balance_equals(&b_c, &b_plain)
    }

    /// `new_pending_balance_from_bytes(256 zero bytes)` must decode to a
    /// balance `balance_equals` to the plain zero pending balance. Catches:
    /// decoder that silently drops chunks, returns a random balance on
    /// valid zero bytes, or otherwise does not invert `balance_to_bytes` on
    /// the canonical zero encoding.
    public fun test_bal_new_pending_from_256_zeros_equals_plain_zero(): bool {
        let bytes = vector[];
        let i = 0;
        while (i < 256) {
            bytes.push_back(0u8);
            i = i + 1;
        };
        let opt = confidential_balance::new_pending_balance_from_bytes(bytes);
        if (opt.is_none()) { return false };
        let b = opt.extract();
        let b_plain = confidential_balance::new_pending_balance_no_randomness();
        confidential_balance::balance_equals(&b, &b_plain)
    }

    /// Dual for actual balance: `new_actual_balance_from_bytes(512 zeros)`
    /// equals the plain zero actual balance.
    public fun test_bal_new_actual_from_512_zeros_equals_plain_zero(): bool {
        let bytes = vector[];
        let i = 0;
        while (i < 512) {
            bytes.push_back(0u8);
            i = i + 1;
        };
        let opt = confidential_balance::new_actual_balance_from_bytes(bytes);
        if (opt.is_none()) { return false };
        let b = opt.extract();
        let b_plain = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::balance_equals(&b, &b_plain)
    }

    /// `balance_to_bytes(decompress_balance(compress_balance(b))) == balance_to_bytes(b)`
    /// for a NON-ZERO pending balance. Pins the compress→decompress round-trip
    /// at the byte level (stronger than `balance_equals` since it sees
    /// through any silent canonical-reencoding bug). Uses `pending_u64(7)`
    /// — a non-trivial chunk-0 amount.
    public fun test_bal_compress_decompress_bytes_roundtrip_u64_seven(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(7);
        let c = confidential_balance::compress_balance(&b);
        let b2 = confidential_balance::decompress_balance(&c);
        confidential_balance::balance_to_bytes(&b) == confidential_balance::balance_to_bytes(&b2)
    }

    /// `add_balances_mut(zero, nonzero)` must equal `nonzero` via `balance_equals`.
    /// Catches an accumulator bug where `add_balances_mut` fails to write
    /// back through the mutable reference (a no-op), which would leave
    /// `lhs` at zero and make the `balance_equals` check fail.
    public fun test_bal_add_zero_plus_nonzero_equals_nonzero(): bool {
        let lhs = confidential_balance::new_pending_balance_no_randomness();
        let rhs = confidential_balance::new_pending_balance_u64_no_randonmess(7);
        confidential_balance::add_balances_mut(&mut lhs, &rhs);
        let expected = confidential_balance::new_pending_balance_u64_no_randonmess(7);
        confidential_balance::balance_equals(&lhs, &expected)
    }

    /// `balance_c_equals(pending_u64(1), pending_u64(2)) == false`. The C
    /// components differ because the value masses in chunk 0 are the
    /// basepoint and 2×basepoint respectively. Catches `balance_c_equals`
    /// that always returns `true` (broken to-short-circuit) or that only
    /// inspects one chunk without full iteration.
    public fun test_bal_c_equals_on_distinct_u64_is_false(): bool {
        let b1 = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let b2 = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        !confidential_balance::balance_c_equals(&b1, &b2)
    }

    /// Commutativity of `balance_equals`: `balance_equals(a, b) == balance_equals(b, a)`
    /// with `a = pending_u64(3)`, `b = pending_u64(2)`. Both sides must
    /// return `false` so the comparison holds. Catches an asymmetric
    /// implementation (e.g., a function that only walks `lhs.chunks` and
    /// ignores `rhs`).
    public fun test_bal_equals_commutative_distinct(): bool {
        let a = confidential_balance::new_pending_balance_u64_no_randonmess(3);
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(2);
        confidential_balance::balance_equals(&a, &b) == confidential_balance::balance_equals(&b, &a)
    }

    // --- Phase E: `balance_to_points_{c,d}` rows ---
    //
    // Previously BLOCKED(harness) because the two accessors clone each
    // chunk via `ristretto255::point_clone`, which was gated on
    // `features::bulletproofs_enabled()` reading the on-chain feature
    // bitset. Phase D.1 enables `BULLETPROOFS_NATIVES` in the harness
    // `Features` resource, making these accessors reachable. These rows
    // pin the semantics directly (the `verify_*_sigma_proof` paths in
    // `confidential_proof` rely on them extensively at Lean indices
    // beyond this phase).

    /// Vector-length pins: pending has 4 chunks, actual has 8 chunks.
    /// `balance_to_points_c` returns one `RistrettoPoint` per chunk, so
    /// the output length must match. Catches a regression that drops
    /// chunks or mis-maps through the wrong accessor.
    public fun test_bal_balance_to_points_c_pending_zero_len_is_4(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let pts = confidential_balance::balance_to_points_c(&b);
        pts.length() == 4
    }

    public fun test_bal_balance_to_points_d_pending_zero_len_is_4(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let pts = confidential_balance::balance_to_points_d(&b);
        pts.length() == 4
    }

    public fun test_bal_balance_to_points_c_actual_zero_len_is_8(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        let pts = confidential_balance::balance_to_points_c(&b);
        pts.length() == 8
    }

    public fun test_bal_balance_to_points_d_actual_zero_len_is_8(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        let pts = confidential_balance::balance_to_points_d(&b);
        pts.length() == 8
    }

    /// On a canonical zero balance (no randomness), EVERY chunk of BOTH
    /// `C` and `D` is the identity point. Catches a regression where
    /// `balance_to_points_c` is aliased to return basepoint-scaled
    /// values, or where `new_*_balance_no_randomness` accidentally
    /// encodes nonzero randomness / value.
    public fun test_bal_balance_to_points_c_zero_pending_all_identity(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let pts = confidential_balance::balance_to_points_c(&b);
        let id = ristretto255::point_identity();
        let i = 0;
        let n = pts.length();
        let all_id = true;
        while (i < n) {
            if (!ristretto255::point_equals(pts.borrow(i), &id)) { all_id = false; };
            i = i + 1;
        };
        all_id
    }

    public fun test_bal_balance_to_points_d_zero_pending_all_identity(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let pts = confidential_balance::balance_to_points_d(&b);
        let id = ristretto255::point_identity();
        let i = 0;
        let n = pts.length();
        let all_id = true;
        while (i < n) {
            if (!ristretto255::point_equals(pts.borrow(i), &id)) { all_id = false; };
            i = i + 1;
        };
        all_id
    }

    public fun test_bal_balance_to_points_c_zero_actual_all_identity(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        let pts = confidential_balance::balance_to_points_c(&b);
        let id = ristretto255::point_identity();
        let i = 0;
        let n = pts.length();
        let all_id = true;
        while (i < n) {
            if (!ristretto255::point_equals(pts.borrow(i), &id)) { all_id = false; };
            i = i + 1;
        };
        all_id
    }

    /// On `pending_u64(1)` (which places the scalar `1` in chunk 0 only),
    /// `balance_to_points_c(b)` must return `[basepoint, identity,
    /// identity, identity]` because the `C` component encrypts
    /// `v*G + r*H` and with `r = 0` this is `1*G = basepoint`.
    /// `balance_to_points_d(b)` must still return `[identity; 4]`
    /// because `D = r*Y = 0*Y = identity`. Together these pin the split
    /// between `C` and `D` at the point-extraction layer — a regression
    /// that swaps `C` and `D` would flip BOTH rows; a regression that
    /// returns the SAME accessor for both would make `d` match `c` and
    /// fail the `d_all_identity` row.
    public fun test_bal_balance_to_points_c_u64_one_chunk0_is_basepoint(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let pts = confidential_balance::balance_to_points_c(&b);
        let bp = ristretto255::basepoint();
        let id = ristretto255::point_identity();
        // chunk 0 must be basepoint.
        let chunk0_ok = ristretto255::point_equals(pts.borrow(0), &bp);
        // chunks 1..3 must be identity.
        let chunk1_ok = ristretto255::point_equals(pts.borrow(1), &id);
        let chunk2_ok = ristretto255::point_equals(pts.borrow(2), &id);
        let chunk3_ok = ristretto255::point_equals(pts.borrow(3), &id);
        chunk0_ok && chunk1_ok && chunk2_ok && chunk3_ok
    }

    public fun test_bal_balance_to_points_d_u64_one_all_identity(): bool {
        // With zero randomness, D-components are all identity regardless of value.
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let pts = confidential_balance::balance_to_points_d(&b);
        let id = ristretto255::point_identity();
        let chunk0_ok = ristretto255::point_equals(pts.borrow(0), &id);
        let chunk1_ok = ristretto255::point_equals(pts.borrow(1), &id);
        let chunk2_ok = ristretto255::point_equals(pts.borrow(2), &id);
        let chunk3_ok = ristretto255::point_equals(pts.borrow(3), &id);
        chunk0_ok && chunk1_ok && chunk2_ok && chunk3_ok
    }

    /// Direct discriminator: `balance_to_points_c(pending_u64(1))` must
    /// NOT equal `balance_to_points_d(pending_u64(1))` chunk-0
    /// (basepoint vs identity). A regression where the two accessors
    /// return the same vector would flip the row.
    public fun test_bal_balance_to_points_c_neq_d_on_u64_one(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let pts_c = confidential_balance::balance_to_points_c(&b);
        let pts_d = confidential_balance::balance_to_points_d(&b);
        !ristretto255::point_equals(pts_c.borrow(0), pts_d.borrow(0))
    }

    /// Chunk-3 (high bits) placement: on `pending_u64(1 << 48)` the
    /// scalar `1` lands in chunk 3 only. `balance_to_points_c` must
    /// return `[identity, identity, identity, basepoint]`. A regression
    /// that writes every chunk at offset 0 (ignoring the chunk index)
    /// would flip the row.
    public fun test_bal_balance_to_points_c_u64_high_chunk_is_basepoint(): bool {
        let v: u64 = 1 << 48;
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(v);
        let pts = confidential_balance::balance_to_points_c(&b);
        let bp = ristretto255::basepoint();
        let id = ristretto255::point_identity();
        let chunk0_ok = ristretto255::point_equals(pts.borrow(0), &id);
        let chunk1_ok = ristretto255::point_equals(pts.borrow(1), &id);
        let chunk2_ok = ristretto255::point_equals(pts.borrow(2), &id);
        let chunk3_ok = ristretto255::point_equals(pts.borrow(3), &bp);
        chunk0_ok && chunk1_ok && chunk2_ok && chunk3_ok
    }

    // --- Phase F: `verify_{pending,actual}_balance_for_test` rows ---
    //
    // These rows pin the decryption-consistency invariants of the two
    // new `*_for_test` public wrappers added in
    // `confidential_balance.move` (the `#[test_only]` originals cannot
    // be called from this harness without `testing: true` in the
    // bundle).
    //
    // The pure-point-arithmetic body is identical to the `#[test_only]`
    // original — each chunk's decryption `C - dk*D` must equal
    // `basepoint * chunk_value`. These rows are the direct regression
    // coverage of the balance-decryption primitive, which is exactly
    // the relation that every `verify_*_sigma_proof` recomputes
    // internally against a sigma transcript.
    //
    // NOTE: all inputs use zero randomness, so the decryption key `dk`
    // is irrelevant (we pass an arbitrary nonzero scalar). A regression
    // that uses the `dk` field as a shared secret rather than for
    // decryption would be flagged by the "wrong amount → false" row
    // below.

    public fun test_bal_verify_pending_zero_with_any_dk_is_true(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let dk = ristretto255::new_scalar_from_u64(1234567);
        confidential_balance::verify_pending_balance_for_test(&b, &dk, 0)
    }

    public fun test_bal_verify_actual_zero_with_any_dk_is_true(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        let dk = ristretto255::new_scalar_from_u64(42);
        confidential_balance::verify_actual_balance_for_test(&b, &dk, 0)
    }

    public fun test_bal_verify_pending_u64_one_matches(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let dk = ristretto255::new_scalar_from_u64(99);
        confidential_balance::verify_pending_balance_for_test(&b, &dk, 1)
    }

    /// Decryption check on u64(1) AGAINST amount=2 MUST be false.
    /// Catches a `verify_*_balance_for_test` that always returns `true`
    /// (the classic "test always passes" regression) or that compares
    /// only one chunk.
    public fun test_bal_verify_pending_u64_one_vs_two_is_false(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        let dk = ristretto255::new_scalar_from_u64(99);
        !confidential_balance::verify_pending_balance_for_test(&b, &dk, 2)
    }

    /// Boundary case: `0xffff` (chunk 0 max, no overflow) decrypts.
    public fun test_bal_verify_pending_u64_max_chunk0_matches(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(0xffff);
        let dk = ristretto255::new_scalar_from_u64(12345);
        confidential_balance::verify_pending_balance_for_test(&b, &dk, 0xffff)
    }

    /// Cross-chunk: `pending_u64(1 << 48)` places the `1` in chunk 3.
    /// A decryption that only reads chunk 0 (ignoring chunks 1..3)
    /// would return `true` for amount=0 and `false` for amount=(1<<48),
    /// flipping this row to `false`.
    public fun test_bal_verify_pending_u64_high_chunk_matches(): bool {
        let v: u64 = 1 << 48;
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(v);
        let dk = ristretto255::new_scalar_from_u64(7);
        confidential_balance::verify_pending_balance_for_test(&b, &dk, v)
    }

    /// u128 boundary: split across chunks 3 and 4 (`1 << 64`) for the
    /// actual (8-chunk) balance. Regression protection against a
    /// `verify_actual_balance_for_test` that uses the 4-chunk pending
    /// split by mistake.
    public fun test_bal_verify_actual_u128_cross_u64_chunk4_matches(): bool {
        let v: u128 = 1u128 << 64;
        let b = confidential_balance::new_actual_balance_no_randomness();
        let dk = ristretto255::new_scalar_from_u64(7);
        // The `no_randomness` actual balance encrypts 0, so amount must be 0.
        // Here we pin that verifying it against `v` (non-zero) returns false.
        // This guards against a `verify_actual_balance_for_test` that treats
        // all zero-ciphertexts as matching any amount.
        !confidential_balance::verify_actual_balance_for_test(&b, &dk, v)
    }

    /// Length-mismatch hard-abort: feeding a PENDING-length (4-chunk)
    /// balance into `verify_actual_balance_for_test` (which asserts
    /// `ACTUAL_BALANCE_CHUNKS = 8`) must abort with
    /// `error::internal(EINTERNAL_ERROR)` = **720897** (= `0xB_0001`).
    /// Captures a regression where the actual-balance verifier forgets
    /// the length assertion and silently processes fewer chunks.
    public fun test_bal_verify_actual_rejects_pending_length_aborts(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let dk = ristretto255::new_scalar_from_u64(0);
        confidential_balance::verify_actual_balance_for_test(&b, &dk, 0);
        true
    }

    /// Complementary hard-abort: feeding an ACTUAL-length (8-chunk)
    /// balance into `verify_pending_balance_for_test` (which asserts
    /// `PENDING_BALANCE_CHUNKS = 4`) must abort with **720897**.
    public fun test_bal_verify_pending_rejects_actual_length_aborts(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        let dk = ristretto255::new_scalar_from_u64(0);
        confidential_balance::verify_pending_balance_for_test(&b, &dk, 0);
        true
    }

    // --- Phase F.2: `is_zero_balance` direct coverage ---
    //
    // `is_zero_balance` is public and previously lacked any direct row.
    // It is the exact predicate used by on-chain state transitions
    // (e.g., `rotate_encryption_key` requires the sender's pending
    // balance to be zero), so a regression (always returns `true`, or
    // only inspects chunk 0) would silently break access control.

    /// Fresh pending balance with no randomness is zero.
    public fun test_bal_is_zero_balance_pending_zero_is_true(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        confidential_balance::is_zero_balance(&b)
    }

    /// Fresh actual balance with no randomness is zero.
    public fun test_bal_is_zero_balance_actual_zero_is_true(): bool {
        let b = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::is_zero_balance(&b)
    }

    /// Non-zero pending amount u64(1) is NOT zero.
    public fun test_bal_is_zero_balance_u64_one_is_false(): bool {
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(1);
        !confidential_balance::is_zero_balance(&b)
    }

    /// High-chunk placement: `pending_u64(1 << 48)` has ONLY chunk 3
    /// non-identity. `is_zero_balance` MUST return false — catches the
    /// regression where the implementation only inspects chunk 0.
    public fun test_bal_is_zero_balance_u64_high_chunk_is_false(): bool {
        let v: u64 = 1 << 48;
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(v);
        !confidential_balance::is_zero_balance(&b)
    }

    /// Chunk-2 placement: `pending_u64(1 << 32)` places a non-identity
    /// in chunk 2 ONLY. Catches `is_zero_balance` that fails to walk
    /// past the second chunk (covers partial-iteration regressions
    /// that the chunk-3 row alone wouldn't flag).
    public fun test_bal_is_zero_balance_u64_chunk2_is_false(): bool {
        let v: u64 = 1 << 32;
        let b = confidential_balance::new_pending_balance_u64_no_randonmess(v);
        !confidential_balance::is_zero_balance(&b)
    }

    /// `add + sub` roundtrip → is_zero_balance. Starting from zero,
    /// adding u64(5) and then subtracting u64(5) must land back at a
    /// zero balance. A regression in either `add_balances_mut` or
    /// `sub_balances_mut` that leaks a non-identity residue would flip
    /// this row.
    public fun test_bal_is_zero_balance_after_add_sub_roundtrip(): bool {
        let b = confidential_balance::new_pending_balance_no_randomness();
        let five = confidential_balance::new_pending_balance_u64_no_randonmess(5);
        confidential_balance::add_balances_mut(&mut b, &five);
        confidential_balance::sub_balances_mut(&mut b, &five);
        confidential_balance::is_zero_balance(&b)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Phase I — `balance_equals` vs `balance_c_equals` DISTINCTION pins.
    //
    // Goal: pin that `balance_equals` compares BOTH C and D components, while
    // `balance_c_equals` compares ONLY C. Before these pins, a silent
    // regression where `balance_equals` was changed to `balance_c_equals` (e.g.
    // as a perf "optimization") would go undetected: every self-equality and
    // every zero/zero equality test would still pass, because for those the
    // D components agree trivially. That regression is catastrophic: in
    // `verify_{pending,actual}_balance`, the final check uses `balance_equals`
    // to confirm that the amount-with-recomputed-D matches the claimed
    // balance. Collapsing that to a C-only check would break the decryption
    // consistency guarantee.
    //
    // Strategy: construct two balances `zero` and `nonzero_d` where:
    //   - zero = all 256 bytes of 0x00 (all C[i] = identity, all D[i] = identity)
    //   - nonzero_d = C[i] = identity for all i, D[0] = basepoint, D[1..] = identity
    // Then:
    //   - `balance_c_equals(zero, nonzero_d)` MUST return `true`  (C's match)
    //   - `balance_equals(zero, nonzero_d)`   MUST return `false` (D[0] differs)
    // A regression collapsing `balance_equals` to `balance_c_equals` flips the
    // second row's return to `true`, mismatching Lean `ldTrue` (since Lean
    // stub is `ldTrue`, the pin is actually `false == Lean` — but I use the
    // reverse formulation `!balance_equals(...)` to return `true` on pass).

    /// Helper: construct a pending balance where C[i] = identity for all i and
    /// D[0] = basepoint, D[1..3] = identity. Distinct from `zero` only in D[0].
    fun make_nonzero_d_pending(): confidential_balance::ConfidentialBalance {
        let bp_bytes = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        let b_bytes = std::vector::empty<u8>();
        let j = 0;
        while (j < 32) {
            std::vector::push_back(&mut b_bytes, 0u8);
            j = j + 1;
        };
        j = 0;
        while (j < 32) {
            std::vector::push_back(&mut b_bytes, *std::vector::borrow(&bp_bytes, j));
            j = j + 1;
        };
        j = 0;
        while (j < 192) {
            std::vector::push_back(&mut b_bytes, 0u8);
            j = j + 1;
        };
        std::option::destroy_some(
            confidential_balance::new_pending_balance_from_bytes(b_bytes))
    }

    /// Helper: pending balance where C[0] = basepoint, D[0] = identity,
    /// and all other chunks zero.
    fun make_nonzero_c_pending(): confidential_balance::ConfidentialBalance {
        let bp_bytes = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        let b_bytes = std::vector::empty<u8>();
        let j = 0;
        while (j < 32) {
            std::vector::push_back(&mut b_bytes, *std::vector::borrow(&bp_bytes, j));
            j = j + 1;
        };
        j = 0;
        while (j < 32) {
            std::vector::push_back(&mut b_bytes, 0u8);
            j = j + 1;
        };
        j = 0;
        while (j < 192) {
            std::vector::push_back(&mut b_bytes, 0u8);
            j = j + 1;
        };
        std::option::destroy_some(
            confidential_balance::new_pending_balance_from_bytes(b_bytes))
    }

    /// Pins `balance_c_equals == true` on two balances that share all C-components
    /// but differ in D[0].
    public fun test_bal_c_equals_true_when_d_differs(): bool {
        let zero = confidential_balance::new_pending_balance_no_randomness();
        let nonzero_d = make_nonzero_d_pending();
        confidential_balance::balance_c_equals(&zero, &nonzero_d)
    }

    /// Pins `balance_equals == false` on two balances that share all C-components
    /// but differ in D[0]. If a regression collapses `balance_equals` to a C-only
    /// check, this pin FLIPS to `true` and mismatches Lean.
    public fun test_bal_full_equals_false_when_d_differs(): bool {
        let zero = confidential_balance::new_pending_balance_no_randomness();
        let nonzero_d = make_nonzero_d_pending();
        !confidential_balance::balance_equals(&zero, &nonzero_d)
    }

    /// Symmetric: swap arguments. `balance_equals` is symmetric so this must also be false.
    public fun test_bal_full_equals_false_when_d_differs_swapped(): bool {
        let zero = confidential_balance::new_pending_balance_no_randomness();
        let nonzero_d = make_nonzero_d_pending();
        !confidential_balance::balance_equals(&nonzero_d, &zero)
    }

    /// Reverse: balances where C differs but D agrees. BOTH `balance_equals` AND
    /// `balance_c_equals` must return `false`. Pins that `balance_c_equals` actually
    /// looks at C (and isn't e.g. always returning true).
    public fun test_bal_c_equals_false_when_c_differs(): bool {
        let zero = confidential_balance::new_pending_balance_no_randomness();
        let nonzero_c = make_nonzero_c_pending();
        !confidential_balance::balance_c_equals(&zero, &nonzero_c)
    }

    /// Companion: `balance_equals(zero, nonzero_c)` must also be false.
    public fun test_bal_full_equals_false_when_c_differs(): bool {
        let zero = confidential_balance::new_pending_balance_no_randomness();
        let nonzero_c = make_nonzero_c_pending();
        !confidential_balance::balance_equals(&zero, &nonzero_c)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Phase L — length-mismatch hard-abort pins for the four chunk-sensitive
    // confidential-balance helpers: `balance_equals`, `balance_c_equals`,
    // `add_balances_mut`, `sub_balances_mut`.
    //
    // Each of these functions carries an explicit `assert!(... ==/..>=, error::internal(EINTERNAL_ERROR))`
    // guarding the chunk-length invariant. Invariant value: `EINTERNAL_ERROR = 1`
    // and `error::internal` category = `0xB` → canonical abort code
    // `0x0B_0001 = 720897`. Pinning these aborts catches silent regressions
    // where the assertion is removed, weakened, or pointed at a different
    // category (e.g. `error::invalid_argument(1) = 65537`) that would
    // mis-classify an invariant violation as a user-facing validation
    // failure and silently process the wrong number of chunks.
    //
    // Twins to the existing `test_bal_verify_{actual,pending}_rejects_*_length_aborts`
    // pins (which cover `verify_{actual,pending}_balance_for_test`). These
    // pins cover the other four chunk-sensitive helpers that share the
    // same precondition.

    /// `balance_equals(pending_4, actual_8)` — mismatched chunk counts must
    /// abort via `assert!(lhs.chunks.length() == rhs.chunks.length(), ...)`.
    public fun test_bal_balance_equals_mismatched_chunks_pending_actual_aborts(): bool {
        let p = confidential_balance::new_pending_balance_no_randomness();
        let a = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::balance_equals(&p, &a);
        true
    }

    /// Symmetric counterpart: `balance_equals(actual_8, pending_4)`.
    public fun test_bal_balance_equals_mismatched_chunks_actual_pending_aborts(): bool {
        let p = confidential_balance::new_pending_balance_no_randomness();
        let a = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::balance_equals(&a, &p);
        true
    }

    /// `balance_c_equals(pending_4, actual_8)` — same assertion, same abort.
    public fun test_bal_balance_c_equals_mismatched_chunks_pending_actual_aborts(): bool {
        let p = confidential_balance::new_pending_balance_no_randomness();
        let a = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::balance_c_equals(&p, &a);
        true
    }

    /// Symmetric: `balance_c_equals(actual_8, pending_4)`.
    public fun test_bal_balance_c_equals_mismatched_chunks_actual_pending_aborts(): bool {
        let p = confidential_balance::new_pending_balance_no_randomness();
        let a = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::balance_c_equals(&a, &p);
        true
    }

    /// `add_balances_mut(pending_4, actual_8)` — rhs > lhs violates the
    /// `assert!(lhs.chunks.length() >= rhs.chunks.length(), ...)` guard and
    /// must abort with `error::internal(1) = 720897`. Pin protects against
    /// a regression that silently truncates the addition (walking only the
    /// lhs-length prefix of rhs), which would corrupt actual-balance state.
    public fun test_bal_add_balances_mut_pending_plus_actual_aborts(): bool {
        let p = confidential_balance::new_pending_balance_no_randomness();
        let a = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::add_balances_mut(&mut p, &a);
        true
    }

    /// `sub_balances_mut(pending_4, actual_8)` — same inequality, same
    /// abort. Catches a regression that silently drops the high-chunk
    /// portion of the subtraction.
    public fun test_bal_sub_balances_mut_pending_minus_actual_aborts(): bool {
        let p = confidential_balance::new_pending_balance_no_randomness();
        let a = confidential_balance::new_actual_balance_no_randomness();
        confidential_balance::sub_balances_mut(&mut p, &a);
        true
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Phase M — cross-type byte-length rejection pins for
    // `new_pending_balance_from_bytes` / `new_actual_balance_from_bytes`.
    //
    // Each parser enforces an EXACT length (`PENDING_BALANCE_CHUNKS*64 = 256`
    // for pending, `ACTUAL_BALANCE_CHUNKS*64 = 512` for actual) before
    // decoding chunks. The existing suite pins wrong lengths BY SHAPE
    // (empty, short, 257, 513, etc.), but it does NOT pin that feeding
    // *the other balance type's* canonical byte length is also rejected.
    //
    // This is the class of bug where a future refactor accidentally swaps
    // or aliases `PENDING_BALANCE_CHUNKS` ↔ `ACTUAL_BALANCE_CHUNKS` in one
    // of the two deserializers (e.g. pending parser checks `!= 512` but
    // still slices 4 chunks, or vice versa). Such a regression would
    // silently accept the other balance type's serialized bytes and
    // produce a mis-shaped `ConfidentialBalance` — a latent type-confusion
    // vulnerability that would propagate into every downstream chunk-count
    // assertion (see Phase L).
    //
    // These pins also cover the "balance_to_bytes(actual) → pending parser"
    // case, which is the actual observable bug signature (the VM has no
    // other way to produce a 512-byte canonical balance-bytes blob than
    // via `balance_to_bytes` of an 8-chunk balance).

    /// Feeding an 8-chunk actual-size byte length (512 B of zeros) to the
    /// 4-chunk pending parser MUST return `None`. A regression swapping
    /// the constant in `new_pending_balance_from_bytes` would silently
    /// accept this input and produce a 4-chunk balance derived from the
    /// first 4 ciphertext-sized slices of an 8-chunk payload.
    public fun test_pending_from_actual_size_zeros_is_none(): bool {
        let v = std::vector::range(0, 512).map(|_| 0u8);
        std::option::is_none(&confidential_balance::new_pending_balance_from_bytes(v))
    }

    /// Feeding a 4-chunk pending-size byte length (256 B of zeros) to the
    /// 8-chunk actual parser MUST return `None`. A regression swapping
    /// the constant in `new_actual_balance_from_bytes` would silently
    /// accept this short input and walk past its end.
    public fun test_actual_from_pending_size_zeros_is_none(): bool {
        let v = std::vector::range(0, 256).map(|_| 0u8);
        std::option::is_none(&confidential_balance::new_actual_balance_from_bytes(v))
    }

    /// `balance_to_bytes(actual_zero)` is the canonical 512-byte blob for
    /// an 8-chunk balance. Feeding it into the 4-chunk pending parser
    /// MUST return `None`. This is the realistic end-to-end flow (the
    /// only production path that ever produces 512 canonical bytes of a
    /// balance encoding). Catches a type-confusion bug where the pending
    /// parser would silently accept an actual balance's serialization.
    public fun test_pending_from_actual_roundtrip_is_none(): bool {
        let a = confidential_balance::new_actual_balance_no_randomness();
        let bytes = confidential_balance::balance_to_bytes(&a);
        std::option::is_none(&confidential_balance::new_pending_balance_from_bytes(bytes))
    }

    /// Dual: `balance_to_bytes(pending_zero)` is the canonical 256-byte
    /// blob for a 4-chunk balance. Feeding it into the 8-chunk actual
    /// parser MUST return `None`.
    public fun test_actual_from_pending_roundtrip_is_none(): bool {
        let p = confidential_balance::new_pending_balance_no_randomness();
        let bytes = confidential_balance::balance_to_bytes(&p);
        std::option::is_none(&confidential_balance::new_actual_balance_from_bytes(bytes))
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
            (
                "test_bal_different_u64_pending_not_equal",
                "neq_1_2",
                vec![],
            ),
            (
                "test_bal_different_u64_pending_c_not_equal",
                "neq_c_1_2",
                vec![],
            ),
            ("test_bal_plain_zero_not_equal_u64_one", "neq_p_1", vec![]),
            ("test_bal_u64_large_not_zero", "nz_F000", vec![]),
            ("test_bal_u64_high_chunk_not_zero", "nz_hi", vec![]),
            (
                "test_bal_u64_one_bytes_differ_from_u64_two_bytes",
                "bytes_neq",
                vec![],
            ),
            (
                "test_bal_add_u64_one_plus_u64_two_equals_u64_three",
                "add_1_2_3",
                vec![],
            ),
            (
                "test_bal_sub_u64_one_from_u64_one_is_zero",
                "sub_1_1_0",
                vec![],
            ),
            (
                "test_bal_sub_u64_three_minus_two_equals_one",
                "sub_3_2_1",
                vec![],
            ),
            (
                "test_bal_compress_decompress_nonzero_pending_equals_self",
                "cmp_nz",
                vec![],
            ),
            (
                "test_bal_pending_u64_one_bytes_roundtrip_equals_self",
                "rt_nz",
                vec![],
            ),
            (
                "test_bal_pending_u64_one_bytes_contains_nonzero",
                "bytes_nz",
                vec![],
            ),
            ("test_bal_get_pending_chunks_is_four", "pch4", vec![]),
            ("test_bal_get_actual_chunks_is_eight", "ach8", vec![]),
            ("test_bal_get_chunk_bits_is_sixteen", "cb16", vec![]),
            (
                "test_bal_split_u64_zero_all_chunks_zero",
                "split_u64_z",
                vec![],
            ),
            (
                "test_bal_split_u128_zero_all_chunks_zero",
                "split_u128_z",
                vec![],
            ),
            (
                "test_bal_split_u64_one_only_first_chunk_nonzero",
                "split_u64_1",
                vec![],
            ),
            (
                "test_bal_split_u64_65536_chunk0_is_zero",
                "split_u64_65536",
                vec![],
            ),
            (
                "test_bal_split_u64_65537_chunk0_is_one",
                "split_u64_65537",
                vec![],
            ),
            (
                "test_bal_split_u128_65536_chunk0_is_zero_chunk1_is_one",
                "split_u128_65536",
                vec![],
            ),
            (
                "test_bal_split_u64_0xffff_chunk0_is_0xffff",
                "split_u64_0xffff",
                vec![],
            ),
            ("test_bal_u64_chunk1_only_not_zero", "nz_c1", vec![]),
            ("test_bal_u64_chunk2_only_not_zero", "nz_c2", vec![]),
            (
                "test_bal_c_equals_but_not_equals_when_only_d_differs",
                "c_eq_ne_d_diff",
                vec![],
            ),
            ("test_bal_add_commutes_nonzero", "add_comm_nz", vec![]),
            ("test_bal_add_associative_nonzero", "add_assoc_nz", vec![]),
            (
                "test_bal_add_zero_rhs_preserves_nonzero_lhs",
                "add_id_nz",
                vec![],
            ),
            (
                "test_bal_sub_zero_rhs_preserves_nonzero_lhs",
                "sub_id_nz",
                vec![],
            ),
            (
                "test_bal_add_then_sub_recovers_original",
                "add_sub_rt",
                vec![],
            ),
            ("test_bal_bytes_chunk_order_matters", "bytes_order", vec![]),
            (
                "test_bal_u64_chunk2_only_not_zero_strict",
                "nz_c2_strict",
                vec![],
            ),
            (
                "test_bal_add_vs_sub_distinct_nonzero",
                "add_neq_sub_nz",
                vec![],
            ),
            (
                "test_bal_sub_not_commutative_on_distinct_nonzero",
                "sub_non_comm_nz",
                vec![],
            ),
            (
                "test_bal_split_u64_max_all_chunks_ffff",
                "split_u64_max",
                vec![],
            ),
            (
                "test_bal_split_u128_top_chunk_ffff_only",
                "split_u128_top",
                vec![],
            ),
            (
                "test_bal_add_balances_mut_accumulates_three",
                "add_mut_acc3",
                vec![],
            ),
            (
                "test_bal_sub_balances_mut_chain_nonzero",
                "sub_mut_chain_nz",
                vec![],
            ),
            (
                "test_bal_pending_u64_three_bytes_roundtrip_byte_equals",
                "bytes_rt_3_nz",
                vec![],
            ),
            (
                "test_bal_zero_pending_bytes_all_zero",
                "zero_pend_bytes",
                vec![],
            ),
            (
                "test_bal_zero_actual_bytes_all_zero",
                "zero_act_bytes",
                vec![],
            ),
            (
                "test_bal_pending_u64_one_byte_layout",
                "u64_1_layout",
                vec![],
            ),
            (
                "test_bal_pending_from_bytes_invalid_chunk0_left_is_none",
                "invalid_chunk0",
                vec![],
            ),
            (
                "test_bal_pending_from_bytes_invalid_chunk3_right_is_none",
                "invalid_chunk3",
                vec![],
            ),
            (
                "test_bal_compressed_pending_no_rand_matches_plain",
                "cmp_pend_match",
                vec![],
            ),
            (
                "test_bal_compressed_actual_no_rand_matches_plain",
                "cmp_act_match",
                vec![],
            ),
            (
                "test_bal_new_pending_from_256_zeros_equals_plain_zero",
                "pend_z256",
                vec![],
            ),
            (
                "test_bal_new_actual_from_512_zeros_equals_plain_zero",
                "act_z512",
                vec![],
            ),
            (
                "test_bal_compress_decompress_bytes_roundtrip_u64_seven",
                "cmp_rt_7",
                vec![],
            ),
            (
                "test_bal_add_zero_plus_nonzero_equals_nonzero",
                "add_0_nz",
                vec![],
            ),
            (
                "test_bal_c_equals_on_distinct_u64_is_false",
                "c_eq_ne_12",
                vec![],
            ),
            (
                "test_bal_equals_commutative_distinct",
                "eq_comm",
                vec![],
            ),
            (
                "test_bal_balance_to_points_c_pending_zero_len_is_4",
                "bp_c_pzero_len4",
                vec![],
            ),
            (
                "test_bal_balance_to_points_d_pending_zero_len_is_4",
                "bp_d_pzero_len4",
                vec![],
            ),
            (
                "test_bal_balance_to_points_c_actual_zero_len_is_8",
                "bp_c_azero_len8",
                vec![],
            ),
            (
                "test_bal_balance_to_points_d_actual_zero_len_is_8",
                "bp_d_azero_len8",
                vec![],
            ),
            (
                "test_bal_balance_to_points_c_zero_pending_all_identity",
                "bp_c_pzero_id",
                vec![],
            ),
            (
                "test_bal_balance_to_points_d_zero_pending_all_identity",
                "bp_d_pzero_id",
                vec![],
            ),
            (
                "test_bal_balance_to_points_c_zero_actual_all_identity",
                "bp_c_azero_id",
                vec![],
            ),
            (
                "test_bal_balance_to_points_c_u64_one_chunk0_is_basepoint",
                "bp_c_u64_1_ch0",
                vec![],
            ),
            (
                "test_bal_balance_to_points_d_u64_one_all_identity",
                "bp_d_u64_1_id",
                vec![],
            ),
            (
                "test_bal_balance_to_points_c_neq_d_on_u64_one",
                "bp_c_neq_d",
                vec![],
            ),
            (
                "test_bal_balance_to_points_c_u64_high_chunk_is_basepoint",
                "bp_c_u64_hi_ch3",
                vec![],
            ),
            (
                "test_bal_verify_pending_zero_with_any_dk_is_true",
                "vpend_zero_true",
                vec![],
            ),
            (
                "test_bal_verify_actual_zero_with_any_dk_is_true",
                "vact_zero_true",
                vec![],
            ),
            (
                "test_bal_verify_pending_u64_one_matches",
                "vpend_u64_1_t",
                vec![],
            ),
            (
                "test_bal_verify_pending_u64_one_vs_two_is_false",
                "vpend_u64_1v2_f",
                vec![],
            ),
            (
                "test_bal_verify_pending_u64_max_chunk0_matches",
                "vpend_u64_ffff_t",
                vec![],
            ),
            (
                "test_bal_verify_pending_u64_high_chunk_matches",
                "vpend_u64_hi_t",
                vec![],
            ),
            (
                "test_bal_verify_actual_u128_cross_u64_chunk4_matches",
                "vact_u128_hi_f",
                vec![],
            ),
            (
                "test_bal_verify_actual_rejects_pending_length_aborts",
                "vact_len_abort",
                vec![],
            ),
            (
                "test_bal_verify_pending_rejects_actual_length_aborts",
                "vpend_len_abort",
                vec![],
            ),
            (
                "test_bal_is_zero_balance_pending_zero_is_true",
                "izb_pend_zero_t",
                vec![],
            ),
            (
                "test_bal_is_zero_balance_actual_zero_is_true",
                "izb_act_zero_t",
                vec![],
            ),
            (
                "test_bal_is_zero_balance_u64_one_is_false",
                "izb_u64_1_f",
                vec![],
            ),
            (
                "test_bal_is_zero_balance_u64_high_chunk_is_false",
                "izb_u64_hi_f",
                vec![],
            ),
            (
                "test_bal_is_zero_balance_u64_chunk2_is_false",
                "izb_u64_c2_f",
                vec![],
            ),
            (
                "test_bal_is_zero_balance_after_add_sub_roundtrip",
                "izb_addsub_t",
                vec![],
            ),
            // Phase I — `balance_equals` vs `balance_c_equals` distinction.
            (
                "test_bal_c_equals_true_when_d_differs",
                "bal_ceq_t_dneq",
                vec![],
            ),
            (
                "test_bal_full_equals_false_when_d_differs",
                "bal_eq_f_dneq",
                vec![],
            ),
            (
                "test_bal_full_equals_false_when_d_differs_swapped",
                "bal_eq_f_dneq_sw",
                vec![],
            ),
            (
                "test_bal_c_equals_false_when_c_differs",
                "bal_ceq_f_cneq",
                vec![],
            ),
            (
                "test_bal_full_equals_false_when_c_differs",
                "bal_eq_f_cneq",
                vec![],
            ),
            // Phase L — length-mismatch hard-abort pins for the four
            // chunk-sensitive helpers. All rows must abort with canonical
            // `error::internal(1) = 0x0B_0001 = 720897`.
            (
                "test_bal_balance_equals_mismatched_chunks_pending_actual_aborts",
                "bal_eq_mix_pa_abt",
                vec![],
            ),
            (
                "test_bal_balance_equals_mismatched_chunks_actual_pending_aborts",
                "bal_eq_mix_ap_abt",
                vec![],
            ),
            (
                "test_bal_balance_c_equals_mismatched_chunks_pending_actual_aborts",
                "bal_ceq_mix_pa_abt",
                vec![],
            ),
            (
                "test_bal_balance_c_equals_mismatched_chunks_actual_pending_aborts",
                "bal_ceq_mix_ap_abt",
                vec![],
            ),
            (
                "test_bal_add_balances_mut_pending_plus_actual_aborts",
                "bal_add_mix_abt",
                vec![],
            ),
            (
                "test_bal_sub_balances_mut_pending_minus_actual_aborts",
                "bal_sub_mix_abt",
                vec![],
            ),
            // Phase M — cross-type byte-length rejection pins for
            // `new_{pending,actual}_balance_from_bytes`. All rows must
            // return `None` (i.e. evaluate to `true` via `is_none`).
            (
                "test_pending_from_actual_size_zeros_is_none",
                "pend_from_act_size",
                vec![],
            ),
            (
                "test_actual_from_pending_size_zeros_is_none",
                "act_from_pend_size",
                vec![],
            ),
            (
                "test_pending_from_actual_roundtrip_is_none",
                "pend_from_act_rt",
                vec![],
            ),
            (
                "test_actual_from_pending_roundtrip_is_none",
                "act_from_pend_rt",
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
