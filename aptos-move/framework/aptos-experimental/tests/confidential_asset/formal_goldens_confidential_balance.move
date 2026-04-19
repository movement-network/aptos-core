#[test_only]
/// Goldens for `aptos_experimental::confidential_balance` invariants that the
/// Lean formalization relies on:
///
/// * `split_into_chunks_u64` / `split_into_chunks_u128` produce the correct
///   little-endian 16-bit chunk sequence.
/// * `balance_to_bytes` / `new_pending_balance_from_bytes`, and
///   `compress_balance` / `decompress_balance` are mutual inverses.
/// * `add_balances_mut` is homomorphic and commutative on chunks.
/// * `verify_actual_balance` / `verify_pending_balance` agree with the
///   test-only encryption + `split_into_chunks_*` constructors.
/// * `is_zero_balance` accepts identity-ciphertext balances.
///
/// NOTE: `sub_balances_mut` is currently implemented as `ciphertext_add_assign`
/// in the source (see `confidential_balance.move` line ~201). We therefore
/// do *not* assert `sub_balances_mut` is an inverse of `add_balances_mut`.
/// Any future fix should add a regression golden here.
module aptos_experimental::formal_goldens_confidential_balance {
    use std::option;
    use aptos_std::ristretto255;
    use aptos_experimental::confidential_balance;
    use aptos_experimental::ristretto255_twisted_elgamal as twisted_elgamal;

    fun deterministic_keypair(seed: u64): (ristretto255::Scalar, twisted_elgamal::CompressedPubkey) {
        let dk = ristretto255::new_scalar_from_u64(seed);
        let ek = twisted_elgamal::pubkey_from_secret_key(&dk);
        (dk, ek.extract())
    }

    // Chunk count and chunk-size view functions are stable constants.
    #[test]
    fun golden_chunk_constants() {
        assert!(confidential_balance::get_pending_balance_chunks() == 4, 0);
        assert!(confidential_balance::get_actual_balance_chunks() == 8, 1);
        assert!(confidential_balance::get_chunk_size_bits() == 16, 2);
    }

    // `split_into_chunks_u64(0)` is all zeros.
    #[test]
    fun golden_split_u64_zero() {
        let chunks = confidential_balance::split_into_chunks_u64(0);
        assert!(chunks.length() == 4, 0);
        let zero = ristretto255::new_scalar_from_u64(0);
        let i = 0;
        while (i < 4) {
            assert!(ristretto255::scalar_equals(&chunks[i], &zero), 100 + i);
            i = i + 1;
        };
    }

    // `split_into_chunks_u64(0xABCD_1234_5678_BEEF)` matches expected little-endian chunks.
    #[test]
    fun golden_split_u64_four_chunks_pattern() {
        let amount: u64 = 0xABCD_1234_5678_BEEF;
        let chunks = confidential_balance::split_into_chunks_u64(amount);
        assert!(chunks.length() == 4, 0);

        let expected0 = ristretto255::new_scalar_from_u64(0xBEEF);
        let expected1 = ristretto255::new_scalar_from_u64(0x5678);
        let expected2 = ristretto255::new_scalar_from_u64(0x1234);
        let expected3 = ristretto255::new_scalar_from_u64(0xABCD);

        assert!(ristretto255::scalar_equals(&chunks[0], &expected0), 1);
        assert!(ristretto255::scalar_equals(&chunks[1], &expected1), 2);
        assert!(ristretto255::scalar_equals(&chunks[2], &expected2), 3);
        assert!(ristretto255::scalar_equals(&chunks[3], &expected3), 4);
    }

    // `split_into_chunks_u128(0)` is all zeros.
    #[test]
    fun golden_split_u128_zero() {
        let chunks = confidential_balance::split_into_chunks_u128(0);
        assert!(chunks.length() == 8, 0);
        let zero = ristretto255::new_scalar_from_u64(0);
        let i = 0;
        while (i < 8) {
            assert!(ristretto255::scalar_equals(&chunks[i], &zero), 100 + i);
            i = i + 1;
        };
    }

    // `split_into_chunks_u128(u128::max)` is eight `0xFFFF` chunks.
    #[test]
    fun golden_split_u128_max_all_ffff() {
        let amount: u128 = (1u128 << 127) - 1 + (1u128 << 127);
        let chunks = confidential_balance::split_into_chunks_u128(amount);
        assert!(chunks.length() == 8, 0);
        let expected = ristretto255::new_scalar_from_u64(0xFFFF);
        let i = 0;
        while (i < 8) {
            assert!(ristretto255::scalar_equals(&chunks[i], &expected), 100 + i);
            i = i + 1;
        };
    }

    // `balance_to_bytes` → `new_actual_balance_from_bytes` is an identity.
    #[test]
    fun golden_actual_balance_to_bytes_roundtrip() {
        let (dk, ek) = deterministic_keypair(17);
        let r = confidential_balance::generate_balance_randomness();
        let balance = confidential_balance::new_actual_balance_from_u128(12345, &r, &ek);

        let bytes = confidential_balance::balance_to_bytes(&balance);
        assert!(bytes.length() == 64 * 8, 0);

        let parsed = confidential_balance::new_actual_balance_from_bytes(bytes);
        assert!(parsed.is_some(), 1);
        let parsed = parsed.extract();

        assert!(confidential_balance::balance_equals(&balance, &parsed), 2);
        assert!(confidential_balance::verify_actual_balance(&parsed, &dk, 12345), 3);
    }

    // `balance_to_bytes` → `new_pending_balance_from_bytes` is an identity.
    #[test]
    fun golden_pending_balance_to_bytes_roundtrip() {
        let (dk, ek) = deterministic_keypair(19);
        let r = confidential_balance::generate_balance_randomness();
        let balance = confidential_balance::new_pending_balance_from_u64(999, &r, &ek);

        let bytes = confidential_balance::balance_to_bytes(&balance);
        assert!(bytes.length() == 64 * 4, 0);

        let parsed = confidential_balance::new_pending_balance_from_bytes(bytes);
        assert!(parsed.is_some(), 1);
        let parsed = parsed.extract();

        assert!(confidential_balance::balance_equals(&balance, &parsed), 2);
        assert!(confidential_balance::verify_pending_balance(&parsed, &dk, 999), 3);
    }

    // Wrong-length input to the deserializer is rejected.
    #[test]
    fun golden_balance_from_bytes_wrong_length_rejected() {
        let too_short = vector[0u8, 1u8, 2u8];
        let parsed = confidential_balance::new_actual_balance_from_bytes(too_short);
        assert!(parsed.is_none(), 0);
        option::destroy_none(parsed);

        let too_short2 = vector[0u8, 1u8, 2u8];
        let parsed2 = confidential_balance::new_pending_balance_from_bytes(too_short2);
        assert!(parsed2.is_none(), 1);
        option::destroy_none(parsed2);
    }

    // `compress_balance` ∘ `decompress_balance` is an identity (value equality).
    #[test]
    fun golden_actual_balance_compress_roundtrip() {
        let (dk, ek) = deterministic_keypair(21);
        let r = confidential_balance::generate_balance_randomness();
        let balance = confidential_balance::new_actual_balance_from_u128(777, &r, &ek);

        let compressed = confidential_balance::compress_balance(&balance);
        let decompressed = confidential_balance::decompress_balance(&compressed);
        assert!(confidential_balance::balance_equals(&balance, &decompressed), 0);
        assert!(confidential_balance::verify_actual_balance(&decompressed, &dk, 777), 1);
    }

    // Homomorphic add: E(a) + E(b) decrypts to a+b (with no chunk overflow).
    #[test]
    fun golden_add_balances_homomorphic_in_plaintext() {
        let (dk, ek) = deterministic_keypair(23);

        let r_a = confidential_balance::generate_balance_randomness();
        let r_b = confidential_balance::generate_balance_randomness();
        let ba = confidential_balance::new_actual_balance_from_u128(30, &r_a, &ek);
        let bb = confidential_balance::new_actual_balance_from_u128(40, &r_b, &ek);

        confidential_balance::add_balances_mut(&mut ba, &bb);
        assert!(confidential_balance::verify_actual_balance(&ba, &dk, 70), 0);
    }

    // Add is commutative on the plaintext slot (a+b == b+a after decryption).
    #[test]
    fun golden_add_balances_commutative_in_plaintext() {
        let (dk, ek) = deterministic_keypair(27);

        let r_a = confidential_balance::generate_balance_randomness();
        let r_b = confidential_balance::generate_balance_randomness();
        let ab = confidential_balance::new_actual_balance_from_u128(12, &r_a, &ek);
        let ab_other = confidential_balance::new_actual_balance_from_u128(12, &r_a, &ek);
        let b = confidential_balance::new_actual_balance_from_u128(34, &r_b, &ek);
        let b_other = confidential_balance::new_actual_balance_from_u128(34, &r_b, &ek);

        confidential_balance::add_balances_mut(&mut ab, &b);
        confidential_balance::add_balances_mut(&mut b_other, &ab_other);

        assert!(confidential_balance::verify_actual_balance(&ab, &dk, 46), 0);
        assert!(confidential_balance::verify_actual_balance(&b_other, &dk, 46), 1);
    }

    // `is_zero_balance` accepts the canonical all-identity ciphertext balance.
    #[test]
    fun golden_is_zero_balance_of_pending_no_randomness() {
        let balance = confidential_balance::new_pending_balance_no_randomness();
        assert!(confidential_balance::is_zero_balance(&balance), 0);
    }

    // `balance_equals` is reflexive.
    #[test]
    fun golden_balance_equals_reflexive() {
        let (_, ek) = deterministic_keypair(29);
        let r = confidential_balance::generate_balance_randomness();
        let ba = confidential_balance::new_actual_balance_from_u128(555, &r, &ek);
        let bb = confidential_balance::new_actual_balance_from_u128(555, &r, &ek);
        assert!(confidential_balance::balance_equals(&ba, &bb), 0);
    }

    // `balance_c_equals` and `balance_equals` both hold for ciphertexts built
    // with the same value and the same randomness.
    //
    // Note: In Twisted ElGamal the C component is `v·G + r·H`, so it encodes
    // the randomness as well. Two encryptions of the same value with *different*
    // randomness will therefore have different C components — `balance_c_equals`
    // is not a "value-only" comparison.
    #[test]
    fun golden_balance_c_equals_matches_full_balance_equals_same_randomness() {
        let (_, ek) = deterministic_keypair(31);
        let r = confidential_balance::generate_balance_randomness();
        let ba = confidential_balance::new_actual_balance_from_u128(321, &r, &ek);
        let bb = confidential_balance::new_actual_balance_from_u128(321, &r, &ek);

        assert!(confidential_balance::balance_c_equals(&ba, &bb), 0);
        assert!(confidential_balance::balance_equals(&ba, &bb), 1);
    }

    // Different values with the same randomness should cause `balance_c_equals`
    // to return false (the value slot differs).
    #[test]
    fun golden_balance_c_equals_distinguishes_values() {
        let (_, ek) = deterministic_keypair(33);
        let r = confidential_balance::generate_balance_randomness();
        let ba = confidential_balance::new_actual_balance_from_u128(100, &r, &ek);
        let bb = confidential_balance::new_actual_balance_from_u128(200, &r, &ek);

        assert!(!confidential_balance::balance_c_equals(&ba, &bb), 0);
        assert!(!confidential_balance::balance_equals(&ba, &bb), 1);
    }
}
