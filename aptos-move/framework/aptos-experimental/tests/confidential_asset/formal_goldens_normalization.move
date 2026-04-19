#[test_only]
/// Full verification-equation goldens for `verify_normalization_proof`.
module aptos_experimental::formal_goldens_normalization {
    use aptos_std::ristretto255;
    use aptos_experimental::confidential_balance;
    use aptos_experimental::confidential_proof;
    use aptos_experimental::ristretto255_twisted_elgamal as twisted_elgamal;

    const TEST_CHAIN_ID: u8 = 9;
    const TEST_SENDER: address = @0xa1;
    const TEST_CONTRACT: address = @aptos_experimental;

    fun deterministic_keypair(): (ristretto255::Scalar, twisted_elgamal::CompressedPubkey) {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = twisted_elgamal::pubkey_from_secret_key(&dk);
        (dk, ek.extract())
    }

    // Builds a denormalized balance whose chunks sum to `amount` but at least
    // one chunk exceeds 2^16. Uses the two-half trick from the existing tests.
    fun build_denormalized_balance(
        amount: u128,
        ek: &twisted_elgamal::CompressedPubkey,
    ): confidential_balance::ConfidentialBalance {
        let r = confidential_balance::generate_balance_randomness();
        let half = confidential_balance::new_actual_balance_from_u128(amount / 2, &r, ek);
        let other = confidential_balance::new_actual_balance_from_u128(amount / 2, &r, ek);
        confidential_balance::add_balances_mut(&mut half, &other);
        half
    }

    #[test]
    fun golden_honest_normalization_accepted() {
        let (dk, ek) = deterministic_keypair();
        let amount: u128 = 1 << 16;
        let current_balance = build_denormalized_balance(amount, &ek);

        let (proof, new_balance) = confidential_proof::prove_normalization(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &dk, &ek, amount, &current_balance,
        );

        confidential_proof::verify_normalization_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &ek, &current_balance, &new_balance, &proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_normalization_wrong_current_balance_rejected() {
        let (dk, ek) = deterministic_keypair();
        let amount: u128 = 1 << 16;
        let current_balance = build_denormalized_balance(amount, &ek);
        let other_balance = build_denormalized_balance(amount, &ek);

        let (proof, new_balance) = confidential_proof::prove_normalization(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &dk, &ek, amount, &current_balance,
        );

        confidential_proof::verify_normalization_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &ek, /* tampered */ &other_balance, &new_balance, &proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_normalization_wrong_ek_rejected() {
        let (dk, ek) = deterministic_keypair();
        let amount: u128 = 1 << 16;
        let current_balance = build_denormalized_balance(amount, &ek);

        let (proof, new_balance) = confidential_proof::prove_normalization(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &dk, &ek, amount, &current_balance,
        );

        let wrong_dk = ristretto255::new_scalar_from_u64(99);
        let wrong_ek = twisted_elgamal::pubkey_from_secret_key(&wrong_dk).extract();

        confidential_proof::verify_normalization_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            /* tampered */ &wrong_ek, &current_balance, &new_balance, &proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_normalization_wrong_chain_id_rejected() {
        let (dk, ek) = deterministic_keypair();
        let amount: u128 = 1 << 16;
        let current_balance = build_denormalized_balance(amount, &ek);

        let (proof, new_balance) = confidential_proof::prove_normalization(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &dk, &ek, amount, &current_balance,
        );

        confidential_proof::verify_normalization_proof(
            /* wrong */ TEST_CHAIN_ID + 1, TEST_SENDER, TEST_CONTRACT,
            &ek, &current_balance, &new_balance, &proof);
    }
}
