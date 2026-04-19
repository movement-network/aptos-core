#[test_only]
/// Serialize → deserialize round-trip goldens for every proof type.
///
/// These tests guarantee that the on-chain wire format is the exact inverse of
/// the test-only prover's serialization, which is the proposition that the
/// Lean `FunctionalSim.lean` layer relies on when it compares `ByteArray`s
/// coming out of bytecode execution with the scalar/point parsing in
/// `VerifyMath.lean`.
///
/// For each of the four proof types we:
///   1. Build an honest proof with deterministic inputs.
///   2. Serialize it to bytes with the test-only serializer.
///   3. Parse those bytes back with the public deserializer.
///   4. Re-serialize the parsed proof and assert byte-for-byte equality.
///   5. Assert the re-parsed proof verifies against the same witnesses.
///
/// This covers `deserialize_withdrawal_proof`, `deserialize_transfer_proof`,
/// `deserialize_normalization_proof`, and `deserialize_rotation_proof`.
module aptos_experimental::formal_goldens_serialize_roundtrip {
    use std::option;
    use aptos_experimental::confidential_balance;
    use aptos_experimental::confidential_proof;
    use aptos_experimental::ristretto255_twisted_elgamal::{Self as twisted_elgamal, generate_twisted_elgamal_keypair};

    const TEST_CHAIN_ID: u8 = 7;
    const TEST_SENDER: address = @0xa1;
    const TEST_CONTRACT: address = @aptos_experimental;

    #[test]
    fun golden_withdrawal_proof_serialize_roundtrip() {
        let (dk, ek) = generate_twisted_elgamal_keypair();
        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(150, &current_r, &ek);

        let (proof, new_balance) = confidential_proof::prove_withdrawal(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &dk, &ek, /* amount */ 50, /* new_amount */ 100, &current_balance,
        );

        let (sigma_bytes, zkrp_bytes) = confidential_proof::serialize_withdrawal_proof(&proof);

        let parsed = confidential_proof::deserialize_withdrawal_proof(sigma_bytes, zkrp_bytes);
        assert!(parsed.is_some(), 0);
        let parsed = parsed.extract();

        let (sigma2, zkrp2) = confidential_proof::serialize_withdrawal_proof(&parsed);
        let (sigma1_again, zkrp1_again) = confidential_proof::serialize_withdrawal_proof(&proof);
        assert!(sigma2 == sigma1_again, 1);
        assert!(zkrp2 == zkrp1_again, 2);

        confidential_proof::verify_withdrawal_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &ek, 50, &current_balance, &new_balance, &parsed,
        );
    }

    #[test]
    fun golden_withdrawal_proof_deserialize_rejects_short_sigma() {
        let parsed = confidential_proof::deserialize_withdrawal_proof(vector[0u8, 1u8, 2u8], vector[]);
        assert!(parsed.is_none(), 0);
        option::destroy_none(parsed);
    }

    #[test]
    fun golden_transfer_proof_serialize_roundtrip_no_auditor() {
        transfer_roundtrip_with_auditors(0);
    }

    #[test]
    fun golden_transfer_proof_serialize_roundtrip_single_auditor() {
        transfer_roundtrip_with_auditors(1);
    }

    #[test]
    fun golden_transfer_proof_serialize_roundtrip_two_auditors() {
        transfer_roundtrip_with_auditors(2);
    }

    fun transfer_roundtrip_with_auditors(num_auditors: u64) {
        let (sender_dk, sender_ek) = generate_twisted_elgamal_keypair();
        let (_, recipient_ek) = generate_twisted_elgamal_keypair();

        let auditor_eks = vector[];
        let i = 0;
        while (i < num_auditors) {
            let (_, auditor_ek) = generate_twisted_elgamal_keypair();
            auditor_eks.push_back(auditor_ek);
            i = i + 1;
        };

        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(
            200, &current_r, &sender_ek);

        let (proof, new_balance, sender_amount, recipient_amount, auditor_amounts) =
            confidential_proof::prove_transfer(
                TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
                &sender_dk, &sender_ek, &recipient_ek,
                /* amount */ 75, /* new_amount */ 125,
                &current_balance, &auditor_eks, /* sender_auditor_hint */ vector[],
            );

        let (sigma_bytes, zkrp_new_bytes, zkrp_amount_bytes) =
            confidential_proof::serialize_transfer_proof(&proof);

        let parsed = confidential_proof::deserialize_transfer_proof(
            sigma_bytes, zkrp_new_bytes, zkrp_amount_bytes);
        assert!(parsed.is_some(), 0);
        let parsed = parsed.extract();

        let (s2, z2, z3) = confidential_proof::serialize_transfer_proof(&parsed);
        let (s1, z1a, z1b) = confidential_proof::serialize_transfer_proof(&proof);
        assert!(s2 == s1, 1);
        assert!(z2 == z1a, 2);
        assert!(z3 == z1b, 3);

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &sender_ek, &recipient_ek,
            &current_balance, &new_balance, &sender_amount, &recipient_amount,
            &auditor_eks, &auditor_amounts, &vector[],
            &parsed,
        );
    }

    #[test]
    fun golden_normalization_proof_serialize_roundtrip() {
        let (dk, ek) = generate_twisted_elgamal_keypair();

        let amount: u128 = 1 << 16;

        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(amount / 2, &current_r, &ek);
        confidential_balance::add_balances_mut(
            &mut current_balance,
            &confidential_balance::new_actual_balance_from_u128(amount / 2, &current_r, &ek),
        );

        let (proof, new_balance) = confidential_proof::prove_normalization(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &dk, &ek, amount, &current_balance,
        );

        let (sigma_bytes, zkrp_bytes) = confidential_proof::serialize_normalization_proof(&proof);

        let parsed = confidential_proof::deserialize_normalization_proof(sigma_bytes, zkrp_bytes);
        assert!(parsed.is_some(), 0);
        let parsed = parsed.extract();

        let (sigma2, zkrp2) = confidential_proof::serialize_normalization_proof(&parsed);
        let (sigma1_again, zkrp1_again) = confidential_proof::serialize_normalization_proof(&proof);
        assert!(sigma2 == sigma1_again, 1);
        assert!(zkrp2 == zkrp1_again, 2);

        confidential_proof::verify_normalization_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &ek, &current_balance, &new_balance, &parsed,
        );
    }

    #[test]
    fun golden_rotation_proof_serialize_roundtrip() {
        let (current_dk, current_ek) = generate_twisted_elgamal_keypair();
        let (new_dk, new_ek) = generate_twisted_elgamal_keypair();

        let amount: u128 = 150;

        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(
            amount, &current_r, &current_ek);

        let (proof, new_balance) = confidential_proof::prove_rotation(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &current_dk, &new_dk, &current_ek, &new_ek, amount, &current_balance,
        );

        let (sigma_bytes, zkrp_bytes) = confidential_proof::serialize_rotation_proof(&proof);

        let parsed = confidential_proof::deserialize_rotation_proof(sigma_bytes, zkrp_bytes);
        assert!(parsed.is_some(), 0);
        let parsed = parsed.extract();

        let (sigma2, zkrp2) = confidential_proof::serialize_rotation_proof(&parsed);
        let (sigma1_again, zkrp1_again) = confidential_proof::serialize_rotation_proof(&proof);
        assert!(sigma2 == sigma1_again, 1);
        assert!(zkrp2 == zkrp1_again, 2);

        confidential_proof::verify_rotation_proof(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &current_ek, &new_ek, &current_balance, &new_balance, &parsed,
        );
    }

    #[test]
    fun golden_deserialize_rejects_wrong_length() {
        let (dk, ek) = generate_twisted_elgamal_keypair();
        let current_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(150, &current_r, &ek);

        let (proof, _new_balance) = confidential_proof::prove_withdrawal(
            TEST_CHAIN_ID, TEST_SENDER, TEST_CONTRACT,
            &dk, &ek, 50, 100, &current_balance,
        );

        let (sigma_bytes, zkrp_bytes) = confidential_proof::serialize_withdrawal_proof(&proof);
        let mut_sigma = sigma_bytes;
        mut_sigma.pop_back();

        let parsed = confidential_proof::deserialize_withdrawal_proof(mut_sigma, zkrp_bytes);
        assert!(parsed.is_none(), 0);
        option::destroy_none(parsed);
    }
}
