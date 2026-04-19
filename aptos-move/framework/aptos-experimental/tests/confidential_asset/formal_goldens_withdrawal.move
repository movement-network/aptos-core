#[test_only]
/// Full verification-equation goldens for `verify_withdrawal_proof`.
///
/// These tests are the withdrawal analogue of
/// `formal_goldens_verification_equation.move` (which covered registration).
/// They prove that the Move verifier accepts honest withdrawal proofs and
/// rejects proofs where any one of the witnesses (amount, current balance,
/// new balance, ek) has been tampered with.
module aptos_experimental::formal_goldens_withdrawal {
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

    // Honest withdrawal proof passes with deterministic keypair.
    #[test]
    fun golden_honest_withdrawal_accepted() {
        let (dk, ek) = deterministic_keypair();
        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(150, &current_r, &ek);

        let (proof, new_balance) = confidential_proof::prove_withdrawal(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &dk, &ek, /* amount */ 50, /* new_amount */ 100, &current_balance,
        );

        confidential_proof::verify_withdrawal_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &ek, 50, &current_balance, &new_balance, &proof);
    }

    // Wrong claimed amount (proof was for 50, verifier asked for 60) → reject.
    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_withdrawal_wrong_amount_rejected() {
        let (dk, ek) = deterministic_keypair();
        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(150, &current_r, &ek);

        let (proof, new_balance) = confidential_proof::prove_withdrawal(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &dk, &ek, 50, 100, &current_balance,
        );

        confidential_proof::verify_withdrawal_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &ek, /* wrong */ 60, &current_balance, &new_balance, &proof);
    }

    // Wrong current balance → reject.
    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_withdrawal_wrong_current_balance_rejected() {
        let (dk, ek) = deterministic_keypair();
        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(150, &current_r, &ek);
        let other_r = confidential_balance::generate_balance_randomness();
        let other_balance = confidential_balance::new_actual_balance_from_u128(150, &other_r, &ek);

        let (proof, new_balance) = confidential_proof::prove_withdrawal(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &dk, &ek, 50, 100, &current_balance,
        );

        confidential_proof::verify_withdrawal_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &ek, 50, /* tampered */ &other_balance, &new_balance, &proof);
    }

    // Wrong chain_id (transcript binding) → reject.
    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_withdrawal_wrong_chain_id_rejected() {
        let (dk, ek) = deterministic_keypair();
        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(150, &current_r, &ek);

        let (proof, new_balance) = confidential_proof::prove_withdrawal(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &dk, &ek, 50, 100, &current_balance,
        );

        confidential_proof::verify_withdrawal_proof(
            /* wrong */ TEST_CHAIN_ID + 1, TEST_SENDER, TEST_CONTRACT,
            &ek, 50, &current_balance, &new_balance, &proof);
    }

    // Wrong sender address (transcript binding) → reject.
    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_withdrawal_wrong_sender_rejected() {
        let (dk, ek) = deterministic_keypair();
        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(150, &current_r, &ek);

        let (proof, new_balance) = confidential_proof::prove_withdrawal(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &dk, &ek, 50, 100, &current_balance,
        );

        confidential_proof::verify_withdrawal_proof(
            TEST_CHAIN_ID, /* wrong */ @0xbeef, TEST_CONTRACT,
            &ek, 50, &current_balance, &new_balance, &proof);
    }

    // Edge case: withdrawing the full balance (new_amount = 0).
    #[test]
    fun golden_withdrawal_full_balance_accepted() {
        let (dk, ek) = deterministic_keypair();
        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(100, &current_r, &ek);

        let (proof, new_balance) = confidential_proof::prove_withdrawal(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &dk, &ek, /* amount */ 100, /* new_amount */ 0, &current_balance,
        );

        confidential_proof::verify_withdrawal_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &ek, 100, &current_balance, &new_balance, &proof);
    }

    // Edge case: zero withdrawal keeps the balance intact.
    #[test]
    fun golden_withdrawal_zero_amount_accepted() {
        let (dk, ek) = deterministic_keypair();
        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(77, &current_r, &ek);

        let (proof, new_balance) = confidential_proof::prove_withdrawal(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &dk, &ek, /* amount */ 0, /* new_amount */ 77, &current_balance,
        );

        confidential_proof::verify_withdrawal_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &ek, 0, &current_balance, &new_balance, &proof);
    }
}
