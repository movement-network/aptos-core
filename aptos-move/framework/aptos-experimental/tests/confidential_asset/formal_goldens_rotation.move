#[test_only]
/// Full verification-equation goldens for `verify_rotation_proof`.
module aptos_experimental::formal_goldens_rotation {
    use aptos_std::ristretto255;
    use aptos_experimental::confidential_balance;
    use aptos_experimental::confidential_proof;
    use aptos_experimental::ristretto255_twisted_elgamal as twisted_elgamal;

    const TEST_CHAIN_ID: u8 = 9;
    const TEST_SENDER: address = @0xa1;
    const TEST_CONTRACT: address = @aptos_experimental;

    fun deterministic_keypair(seed: u64): (ristretto255::Scalar, twisted_elgamal::CompressedPubkey) {
        let dk = ristretto255::new_scalar_from_u64(seed);
        let ek = twisted_elgamal::pubkey_from_secret_key(&dk);
        (dk, ek.extract())
    }

    #[test]
    fun golden_honest_rotation_accepted() {
        let (current_dk, current_ek) = deterministic_keypair(42);
        let (new_dk, new_ek) = deterministic_keypair(43);

        let amount: u128 = 150;

        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(
            amount, &current_r, &current_ek);

        let (proof, new_balance) = confidential_proof::prove_rotation(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &current_dk, &new_dk, &current_ek, &new_ek, amount, &current_balance,
        );

        confidential_proof::verify_rotation_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &current_ek, &new_ek, &current_balance, &new_balance, &proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_rotation_wrong_current_ek_rejected() {
        let (current_dk, current_ek) = deterministic_keypair(42);
        let (new_dk, new_ek) = deterministic_keypair(43);
        let (_, third_ek) = deterministic_keypair(44);

        let amount: u128 = 150;

        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(
            amount, &current_r, &current_ek);

        let (proof, new_balance) = confidential_proof::prove_rotation(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &current_dk, &new_dk, &current_ek, &new_ek, amount, &current_balance,
        );

        confidential_proof::verify_rotation_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            /* tampered */ &third_ek, &new_ek,
            &current_balance, &new_balance, &proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_rotation_wrong_new_ek_rejected() {
        let (current_dk, current_ek) = deterministic_keypair(42);
        let (new_dk, new_ek) = deterministic_keypair(43);
        let (_, third_ek) = deterministic_keypair(44);

        let amount: u128 = 150;

        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(
            amount, &current_r, &current_ek);

        let (proof, new_balance) = confidential_proof::prove_rotation(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &current_dk, &new_dk, &current_ek, &new_ek, amount, &current_balance,
        );

        confidential_proof::verify_rotation_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &current_ek, /* tampered */ &third_ek,
            &current_balance, &new_balance, &proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_rotation_wrong_sender_rejected() {
        let (current_dk, current_ek) = deterministic_keypair(42);
        let (new_dk, new_ek) = deterministic_keypair(43);

        let amount: u128 = 150;

        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(
            amount, &current_r, &current_ek);

        let (proof, new_balance) = confidential_proof::prove_rotation(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &current_dk, &new_dk, &current_ek, &new_ek, amount, &current_balance,
        );

        confidential_proof::verify_rotation_proof(
            TEST_CHAIN_ID, /* wrong */ @0xdead, TEST_CONTRACT,
            &current_ek, &new_ek, &current_balance, &new_balance, &proof);
    }
}
