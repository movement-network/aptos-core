#[test_only]
// Exercises the FULL verification equation (§6.1 of REGISTRATION_VERIFY_REVIEW.md).
//
// These tests prove that Move's verify_registration_proof accepts honest proofs
// (constructed via prove_registration with s = k - e·dk⁻¹) and rejects when
// the response scalar is corrupted. This is evidence that the verifier checks
// the equation s·H + e·ek = R, matching the Lean model in Operational.lean.
module aptos_experimental::formal_goldens_verification_equation {
    use aptos_std::ristretto255;
    use aptos_experimental::ristretto255_twisted_elgamal as twisted_elgamal;
    use aptos_experimental::confidential_proof;

    // Deterministic keypair: dk = scalar(42), ek = dk⁻¹ · H.
    fun deterministic_keypair(): (ristretto255::Scalar, twisted_elgamal::CompressedPubkey) {
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = twisted_elgamal::pubkey_from_secret_key(&dk);
        (dk, ek.extract())
    }

    // Honest proof (deterministic dk) passes verify_registration_proof.
    // This exercises the full equation: s·H + e·ek = R.
    #[test]
    fun golden_honest_proof_accepted() {
        let chain_id = 9u8;
        let sender = @0x1;
        let contract = @0x2;
        let token = @0x3;

        let (dk, ek) = deterministic_keypair();
        let (commitment, response) = confidential_proof::prove_registration(
            chain_id, sender, contract, &dk, &ek, token,
        );

        confidential_proof::verify_registration_proof_for_test(
            chain_id, sender, contract, &ek, token, commitment, response,
        );
    }

    // Corrupted response scalar (one bit flipped) → verification fails.
    // This proves the verifier actually checks the equation, not just parsing.
    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_corrupted_response_rejected() {
        let chain_id = 9u8;
        let sender = @0x1;
        let contract = @0x2;
        let token = @0x3;

        let (dk, ek) = deterministic_keypair();
        let (commitment, response) = confidential_proof::prove_registration(
            chain_id, sender, contract, &dk, &ek, token,
        );

        // Flip the first byte of the response scalar
        let bad_response = response;
        let first_byte = *bad_response.borrow(0);
        *bad_response.borrow_mut(0) = first_byte ^ 0x01;

        confidential_proof::verify_registration_proof_for_test(
            chain_id, sender, contract, &ek, token, commitment, bad_response,
        );
    }

    // Second scenario (different addresses) — honest proof still passes.
    #[test]
    fun golden_honest_proof_second_scenario() {
        let chain_id = 42u8;
        let sender = @0x10;
        let contract = @0x20;
        let token = @0x30;

        let (dk, ek) = deterministic_keypair();
        let (commitment, response) = confidential_proof::prove_registration(
            chain_id, sender, contract, &dk, &ek, token,
        );

        confidential_proof::verify_registration_proof_for_test(
            chain_id, sender, contract, &ek, token, commitment, response,
        );
    }

    // Wrong dk (different keypair) → verification fails.
    // This proves the verifier actually checks the discrete-log relation H = dk·ek.
    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun golden_wrong_dk_rejected() {
        let chain_id = 9u8;
        let sender = @0x1;
        let contract = @0x2;
        let token = @0x3;

        let (dk, ek) = deterministic_keypair();
        let (commitment, response) = confidential_proof::prove_registration(
            chain_id, sender, contract, &dk, &ek, token,
        );

        // Use a DIFFERENT ek (from dk=99 instead of dk=42)
        let wrong_dk = ristretto255::new_scalar_from_u64(99);
        let wrong_ek = twisted_elgamal::pubkey_from_secret_key(&wrong_dk).extract();

        confidential_proof::verify_registration_proof_for_test(
            chain_id, sender, contract, &wrong_ek, token, commitment, response,
        );
    }
}
