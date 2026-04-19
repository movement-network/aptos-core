#[test_only]
/// Full verification-equation goldens for `verify_transfer_proof`.
///
/// Covers 0/1/2-auditor configurations (the three branch classes of the
/// multi-auditor sigma protocol) and exercises the full verification equation
/// for each. Negative tests lock in that the verifier rejects when a single
/// transcript or balance witness has been corrupted.
module aptos_experimental::formal_goldens_transfer {
    use aptos_std::ristretto255;
    use aptos_experimental::confidential_balance;
    use aptos_experimental::confidential_proof;
    use aptos_experimental::ristretto255_twisted_elgamal::{Self as twisted_elgamal, generate_twisted_elgamal_keypair};

    const TEST_CHAIN_ID: u8 = 9;
    const TEST_SENDER: address = @0xa1;
    const TEST_CONTRACT: address = @aptos_experimental;

    fun deterministic_keypair(seed: u64): (ristretto255::Scalar, twisted_elgamal::CompressedPubkey) {
        let dk = ristretto255::new_scalar_from_u64(seed);
        let ek = twisted_elgamal::pubkey_from_secret_key(&dk);
        (dk, ek.extract())
    }

    struct Ctx has drop {
        sender_dk: ristretto255::Scalar,
        sender_ek: twisted_elgamal::CompressedPubkey,
        recipient_ek: twisted_elgamal::CompressedPubkey,
        current_balance: confidential_balance::ConfidentialBalance,
        auditor_eks: vector<twisted_elgamal::CompressedPubkey>,
    }

    fun setup_ctx(num_auditors: u64): Ctx {
        let (sender_dk, sender_ek) = deterministic_keypair(42);
        let (_, recipient_ek) = deterministic_keypair(43);

        let auditor_eks = vector[];
        let i = 0;
        while (i < num_auditors) {
            let (_, ek_i) = generate_twisted_elgamal_keypair();
            auditor_eks.push_back(ek_i);
            i = i + 1;
        };

        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(
            200, &current_r, &sender_ek);

        Ctx { sender_dk, sender_ek, recipient_ek, current_balance, auditor_eks }
    }

    // 0 auditors: honest proof accepted.
    #[test]
    fun golden_honest_transfer_no_auditor_accepted() {
        let ctx = setup_ctx(0);

        let (proof, new_balance, sender_amount, recipient_amount, auditor_amounts) =
            confidential_proof::prove_transfer(
                TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
                &ctx.sender_dk, &ctx.sender_ek, &ctx.recipient_ek,
                /* amount */ 50, /* new_amount */ 150,
                &ctx.current_balance, &ctx.auditor_eks, vector[],
            );

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &ctx.sender_ek, &ctx.recipient_ek,
            &ctx.current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &ctx.auditor_eks, &auditor_amounts, &vector[],
            &proof,
        );
    }

    // 1 auditor: honest proof accepted.
    #[test]
    fun golden_honest_transfer_single_auditor_accepted() {
        let ctx = setup_ctx(1);

        let (proof, new_balance, sender_amount, recipient_amount, auditor_amounts) =
            confidential_proof::prove_transfer(
                TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
                &ctx.sender_dk, &ctx.sender_ek, &ctx.recipient_ek,
                25, 175,
                &ctx.current_balance, &ctx.auditor_eks, vector[],
            );

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &ctx.sender_ek, &ctx.recipient_ek,
            &ctx.current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &ctx.auditor_eks, &auditor_amounts, &vector[],
            &proof,
        );
    }

    // 2 auditors: honest proof accepted (regression for the g8s/g7s collision).
    #[test]
    fun golden_honest_transfer_two_auditors_accepted() {
        let ctx = setup_ctx(2);

        let (proof, new_balance, sender_amount, recipient_amount, auditor_amounts) =
            confidential_proof::prove_transfer(
                TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
                &ctx.sender_dk, &ctx.sender_ek, &ctx.recipient_ek,
                10, 190,
                &ctx.current_balance, &ctx.auditor_eks, vector[],
            );

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &ctx.sender_ek, &ctx.recipient_ek,
            &ctx.current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &ctx.auditor_eks, &auditor_amounts, &vector[],
            &proof,
        );
    }

    // Wrong recipient_ek in the verifier → reject (the transcript binds it).
    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_transfer_wrong_recipient_ek_rejected() {
        let ctx = setup_ctx(1);

        let (proof, new_balance, sender_amount, recipient_amount, auditor_amounts) =
            confidential_proof::prove_transfer(
                TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
                &ctx.sender_dk, &ctx.sender_ek, &ctx.recipient_ek,
                30, 170,
                &ctx.current_balance, &ctx.auditor_eks, vector[],
            );

        let (_, other_ek) = deterministic_keypair(999);

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &ctx.sender_ek, /* tampered */ &other_ek,
            &ctx.current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &ctx.auditor_eks, &auditor_amounts, &vector[],
            &proof,
        );
    }

    // Wrong contract address → reject.
    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_transfer_wrong_contract_rejected() {
        let ctx = setup_ctx(0);

        let (proof, new_balance, sender_amount, recipient_amount, auditor_amounts) =
            confidential_proof::prove_transfer(
                TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
                &ctx.sender_dk, &ctx.sender_ek, &ctx.recipient_ek,
                30, 170,
                &ctx.current_balance, &ctx.auditor_eks, vector[],
            );

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID, TEST_SENDER, /* wrong */ @0xdead,
            &ctx.sender_ek, &ctx.recipient_ek,
            &ctx.current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &ctx.auditor_eks, &auditor_amounts, &vector[],
            &proof,
        );
    }

    // Auditor-hint tampering → reject (binds into the Fiat–Shamir transcript).
    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_transfer_auditor_hint_mismatch_rejected() {
        let ctx = setup_ctx(1);

        let (proof, new_balance, sender_amount, recipient_amount, auditor_amounts) =
            confidential_proof::prove_transfer(
                TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
                &ctx.sender_dk, &ctx.sender_ek, &ctx.recipient_ek,
                30, 170,
                &ctx.current_balance, &ctx.auditor_eks, /* hint */ vector[0u8, 1u8, 2u8, 3u8],
            );

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &ctx.sender_ek, &ctx.recipient_ek,
            &ctx.current_balance, &new_balance,
            &sender_amount, &recipient_amount,
            &ctx.auditor_eks, &auditor_amounts,
            /* different hint */ &vector[9u8, 9u8, 9u8, 9u8],
            &proof,
        );
    }
}
