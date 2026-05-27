#[test_only]
module aptos_framework::confidential_proof_tests {
    use aptos_framework::confidential_balance;
    use aptos_framework::confidential_proof;
    use aptos_framework::ristretto255_twisted_elgamal::{Self as twisted_elgamal, generate_twisted_elgamal_keypair};

    // Test constants for domain separation
    const TEST_CHAIN_ID: u8 = 4;
    const TEST_SENDER: address = @0xa1;
    /// Published package account for `confidential_asset` / `confidential_proof` (matches `[addresses]` in experimental `Move.toml`).
    const TEST_CONTRACT_ADDRESS: address = @aptos_framework;
    // `TEST_TOKEN_ADDRESS` is declared further down in the registration-tests block (`@0xbeef`); reused here for
    // every transfer/withdraw/rotation/normalization callsite so all FS transcripts are domain-separated by the same
    // token address.

    struct WithdrawParameters has drop {
        ek: twisted_elgamal::CompressedPubkey,
        amount: u64,
        current_balance: confidential_balance::ConfidentialBalance,
        new_balance: confidential_balance::ConfidentialBalance,
        proof: confidential_proof::WithdrawalProof,
    }

    struct TransferParameters has drop {
        sender_ek: twisted_elgamal::CompressedPubkey,
        recipient_ek: twisted_elgamal::CompressedPubkey,
        amount: u64,
        new_amount: u128,
        current_balance: confidential_balance::ConfidentialBalance,
        new_balance: confidential_balance::ConfidentialBalance,
        sender_amount: confidential_balance::ConfidentialBalance,
        recipient_amount: confidential_balance::ConfidentialBalance,
        auditor_eks: vector<twisted_elgamal::CompressedPubkey>,
        auditor_amounts: vector<confidential_balance::ConfidentialBalance>,
        sender_auditor_hint: vector<u8>,
        proof: confidential_proof::TransferProof,
    }

    struct RotationParameters has drop {
        current_ek: twisted_elgamal::CompressedPubkey,
        new_ek: twisted_elgamal::CompressedPubkey,
        amount: u128,
        current_balance: confidential_balance::ConfidentialBalance,
        new_balance: confidential_balance::ConfidentialBalance,
        proof: confidential_proof::RotationProof,
    }

    struct NormalizationParameters has drop {
        ek: twisted_elgamal::CompressedPubkey,
        amount: u128,
        current_balance: confidential_balance::ConfidentialBalance,
        new_balance: confidential_balance::ConfidentialBalance,
        proof: confidential_proof::NormalizationProof,
    }

    fun withdraw(): WithdrawParameters {
        withdraw_with_params(150, 100, 50)
    }

    fun withdraw_with_params(current_amount: u128, new_amount: u128, amount: u64): WithdrawParameters {
        let (dk, ek) = generate_twisted_elgamal_keypair();

        let current_balance_r = confidential_balance::generate_balance_randomness();

        let current_balance = confidential_balance::new_actual_balance_from_u128(
            current_amount,
            &current_balance_r,
            &ek
        );

        let (
            proof,
            new_balance
        ) = confidential_proof::prove_withdrawal(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &dk,
            &ek,
            amount,
            new_amount,
            &current_balance,
        );

        WithdrawParameters {
            ek,
            amount,
            current_balance,
            new_balance,
            proof,
        }
    }

    fun transfer(): TransferParameters {
        transfer_with_parameters(150, 100, 50, vector[])
    }

    fun transfer_with_parameters(
        current_amount: u128,
        new_amount: u128,
        amount: u64,
        sender_auditor_hint: vector<u8>
    ): TransferParameters {
        let (sender_dk, sender_ek) = generate_twisted_elgamal_keypair();
        let (_, recipient_ek) = generate_twisted_elgamal_keypair();

        let current_balance_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(
            current_amount,
            &current_balance_r,
            &sender_ek
        );

        let (_, auditor_ek) = generate_twisted_elgamal_keypair();

        let auditor_eks = vector[auditor_ek];

        let (
            proof,
            new_balance,
            sender_amount,
            recipient_amount,
            auditor_amounts,
        ) = confidential_proof::prove_transfer(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &sender_dk,
            &sender_ek,
            &recipient_ek,
            amount,
            new_amount,
            &current_balance,
            &auditor_eks,
            sender_auditor_hint,
        );

        TransferParameters {
            sender_ek,
            recipient_ek,
            amount,
            new_amount,
            current_balance,
            new_balance,
            sender_amount,
            recipient_amount,
            auditor_eks,
            auditor_amounts,
            sender_auditor_hint,
            proof,
        }
    }

    fun rotate(): RotationParameters {
        let (current_dk, current_ek) = generate_twisted_elgamal_keypair();
        let (new_dk, new_ek) = generate_twisted_elgamal_keypair();

        let amount = 150;

        let current_balance_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(
            amount,
            &current_balance_r,
            &current_ek
        );

        let (
            proof,
            new_balance,
        ) = confidential_proof::prove_rotation(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &current_dk,
            &new_dk,
            &current_ek,
            &new_ek,
            amount,
            &current_balance
        );

        RotationParameters {
            current_ek,
            new_ek,
            amount,
            current_balance,
            new_balance,
            proof,
        }
    }

    fun normalize(): NormalizationParameters {
        let (dk, ek) = generate_twisted_elgamal_keypair();

        let amount = 1 << 16;

        let current_balance_r = confidential_balance::generate_balance_randomness();
        let current_balance = confidential_balance::new_actual_balance_from_u128(amount / 2, &current_balance_r, &ek);
        confidential_balance::add_balances_mut(
            &mut current_balance,
            &confidential_balance::new_actual_balance_from_u128(amount / 2, &current_balance_r, &ek));

        let (
            proof,
            new_balance
        ) = confidential_proof::prove_normalization(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &dk,
            &ek,
            amount,
            &current_balance,
        );

        NormalizationParameters {
            ek,
            amount,
            current_balance,
            new_balance,
            proof,
        }
    }

    #[test]
    fun success_withdraw() {
        let params = withdraw();

        confidential_proof::verify_withdrawal_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.ek,
            params.amount,
            &params.current_balance,
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_withdraw_if_wrong_amount() {
        let params = withdraw();

        confidential_proof::verify_withdrawal_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.ek,
            1000,
            &params.current_balance,
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_withdraw_if_wrong_current_balance() {
        let params = withdraw();

        confidential_proof::verify_withdrawal_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.ek,
            params.amount,
            &confidential_balance::new_actual_balance_from_u128(
                1000,
                &confidential_balance::generate_balance_randomness(),
                &params.ek
            ),
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_withdraw_if_wrong_new_balance() {
        let params = withdraw();

        confidential_proof::verify_withdrawal_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.ek,
            params.amount,
            &params.current_balance,
            &confidential_balance::new_actual_balance_from_u128(
                1000,
                &confidential_balance::generate_balance_randomness(),
                &params.ek
            ),
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_withdraw_if_negative_new_balance() {
        // 0 - 1 = max_uint128
        let max_uint128 = 340282366920938463463374607431768211455;
        let params = withdraw_with_params(0, max_uint128 - 1, 1);

        confidential_proof::verify_withdrawal_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.ek,
            params.amount,
            &params.current_balance,
            &params.new_balance,
            &params.proof);
    }

    #[test]
    fun success_transfer() {
        let params = transfer();

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.sender_ek,
            &params.recipient_ek,
            &params.current_balance,
            &params.new_balance,
            &params.sender_amount,
            &params.recipient_amount,
            &params.auditor_eks,
            &params.auditor_amounts,
            &params.sender_auditor_hint,
            &params.proof);
    }

    #[test]
    fun success_transfer_with_non_empty_auditor_hint() {
        let params = transfer_with_parameters(150, 100, 50, vector[0xabu8, 0xcdu8]);

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.sender_ek,
            &params.recipient_ek,
            &params.current_balance,
            &params.new_balance,
            &params.sender_amount,
            &params.recipient_amount,
            &params.auditor_eks,
            &params.auditor_amounts,
            &params.sender_auditor_hint,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_transfer_if_wrong_sender_auditor_hint() {
        let params = transfer_with_parameters(150, 100, 50, vector[1u8]);

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.sender_ek,
            &params.recipient_ek,
            &params.current_balance,
            &params.new_balance,
            &params.sender_amount,
            &params.recipient_amount,
            &params.auditor_eks,
            &params.auditor_amounts,
            &vector[2u8],
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_transfer_if_wrong_sender_ek() {
        let params = transfer();

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.recipient_ek,
            &params.recipient_ek,
            &params.current_balance,
            &params.new_balance,
            &params.sender_amount,
            &params.recipient_amount,
            &params.auditor_eks,
            &params.auditor_amounts,
            &params.sender_auditor_hint,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_transfer_if_wrong_recipient_ek() {
        let params = transfer();

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.sender_ek,
            &params.sender_ek,
            &params.current_balance,
            &params.new_balance,
            &params.sender_amount,
            &params.recipient_amount,
            &params.auditor_eks,
            &params.auditor_amounts,
            &params.sender_auditor_hint,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_transfer_if_wrong_current_balance() {
        let params = transfer();

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.sender_ek,
            &params.recipient_ek,
            &confidential_balance::new_actual_balance_from_u128(
                1000,
                &confidential_balance::generate_balance_randomness(),
                &params.sender_ek
            ),
            &params.new_balance,
            &params.sender_amount,
            &params.recipient_amount,
            &params.auditor_eks,
            &params.auditor_amounts,
            &params.sender_auditor_hint,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_transfer_if_negative_new_balance() {
        // 0 - 1 = max_uint128
        let max_uint128 = 340282366920938463463374607431768211455;
        let params = transfer_with_parameters(0, max_uint128 - 1, 1, vector[]);

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.sender_ek,
            &params.recipient_ek,
            &params.current_balance,
            &params.new_balance,
            &params.sender_amount,
            &params.recipient_amount,
            &params.auditor_eks,
            &params.auditor_amounts,
            &params.sender_auditor_hint,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_transfer_if_wrong_sender_amount() {
        let params = transfer();

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.sender_ek,
            &params.recipient_ek,
            &params.current_balance,
            &params.new_balance,
            &confidential_balance::new_pending_balance_from_u64(
                1000, &confidential_balance::generate_balance_randomness(), &params.recipient_ek),
            &params.recipient_amount,
            &params.auditor_eks,
            &params.auditor_amounts,
            &params.sender_auditor_hint,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_transfer_if_wrong_recipient_amount() {
        let params = transfer();

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.sender_ek,
            &params.recipient_ek,
            &params.current_balance,
            &params.new_balance,
            &params.sender_amount,
            &confidential_balance::new_pending_balance_from_u64(
                1000, &confidential_balance::generate_balance_randomness(), &params.recipient_ek),
            &params.auditor_eks,
            &params.auditor_amounts,
            &params.sender_auditor_hint,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_transfer_if_wrong_auditor_eks() {
        let params = transfer();

        let (_, auditor_ek) = generate_twisted_elgamal_keypair();
        let auditor_eks = vector[auditor_ek];

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.sender_ek,
            &params.recipient_ek,
            &params.current_balance,
            &params.new_balance,
            &params.sender_amount,
            &params.recipient_amount,
            &auditor_eks,
            &params.auditor_amounts,
            &params.sender_auditor_hint,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_transfer_if_wrong_auditor_amounts() {
        let params = transfer();

        let (_, auditor_ek) = generate_twisted_elgamal_keypair();
        let auditor_amount = confidential_balance::new_pending_balance_from_u64(
            1000,
            &confidential_balance::generate_balance_randomness(),
            &auditor_ek
        );
        let auditor_amounts = vector[auditor_amount];

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.sender_ek,
            &params.recipient_ek,
            &params.current_balance,
            &params.new_balance,
            &params.sender_amount,
            &params.recipient_amount,
            &params.auditor_eks,
            &auditor_amounts,
            &params.sender_auditor_hint,
            &params.proof);
    }

    #[test]
    fun success_rotate() {
        let params = rotate();

        confidential_proof::verify_rotation_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.current_ek,
            &params.new_ek,
            &params.current_balance,
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_rotate_if_wrong_current_ek() {
        let params = rotate();

        confidential_proof::verify_rotation_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.new_ek,
            &params.new_ek,
            &params.current_balance,
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_rotate_if_wrong_new_ek() {
        let params = rotate();

        confidential_proof::verify_rotation_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.current_ek,
            &params.current_ek,
            &params.current_balance,
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_rotate_if_wrong_current_balance() {
        let params = rotate();

        confidential_proof::verify_rotation_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.current_ek,
            &params.new_ek,
            &confidential_balance::new_actual_balance_from_u128(
                1000,
                &confidential_balance::generate_balance_randomness(),
                &params.current_ek
            ),
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_rotate_if_wrong_new_balance() {
        let params = rotate();

        confidential_proof::verify_rotation_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.current_ek,
            &params.new_ek,
            &params.current_balance,
            &confidential_balance::new_actual_balance_from_u128(
                1000,
                &confidential_balance::generate_balance_randomness(),
                &params.new_ek
            ),
            &params.proof);
    }

    #[test]
    fun success_normalize() {
        let params = normalize();

        confidential_proof::verify_normalization_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.ek,
            &params.current_balance,
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_normalize_if_wrong_ek() {
        let params = normalize();

        let (_, ek) = generate_twisted_elgamal_keypair();

        confidential_proof::verify_normalization_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &ek,
            &params.current_balance,
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_normalize_if_wrong_current_balance() {
        let params = normalize();

        confidential_proof::verify_normalization_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.ek,
            &confidential_balance::new_actual_balance_from_u128(
                1000,
                &confidential_balance::generate_balance_randomness(),
                &params.ek
            ),
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_normalize_if_wrong_new_balance() {
        let params = normalize();

        confidential_proof::verify_normalization_proof(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.ek,
            &params.current_balance,
            &confidential_balance::new_actual_balance_from_u128(
                1000,
                &confidential_balance::generate_balance_randomness(),
                &params.ek
            ),
            &params.proof);
    }

    // ==========================================
    // Registration proof tests
    // ==========================================

    const TEST_TOKEN_ADDRESS: address = @0xbeef;

    #[test]
    fun success_registration() {
        let (dk, ek) = generate_twisted_elgamal_keypair();
        let (commitment, response) = confidential_proof::prove_registration(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            &dk,
            &ek,
            TEST_TOKEN_ADDRESS,
        );

        confidential_proof::verify_registration_proof_for_test(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            &ek,
            TEST_TOKEN_ADDRESS,
            commitment,
            response,
        );
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_registration_if_wrong_ek() {
        let (dk, ek) = generate_twisted_elgamal_keypair();
        let (commitment, response) = confidential_proof::prove_registration(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            &dk,
            &ek,
            TEST_TOKEN_ADDRESS,
        );

        let (_, wrong_ek) = generate_twisted_elgamal_keypair();

        confidential_proof::verify_registration_proof_for_test(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            &wrong_ek,
            TEST_TOKEN_ADDRESS,
            commitment,
            response,
        );
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_registration_if_wrong_token() {
        let (dk, ek) = generate_twisted_elgamal_keypair();
        let (commitment, response) = confidential_proof::prove_registration(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            &dk,
            &ek,
            TEST_TOKEN_ADDRESS,
        );

        confidential_proof::verify_registration_proof_for_test(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            &ek,
            @0xdead,
            commitment,
            response,
        );
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_registration_if_wrong_chain_id() {
        let (dk, ek) = generate_twisted_elgamal_keypair();
        let (commitment, response) = confidential_proof::prove_registration(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            &dk,
            &ek,
            TEST_TOKEN_ADDRESS,
        );

        confidential_proof::verify_registration_proof_for_test(
            TEST_CHAIN_ID + 1,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            &ek,
            TEST_TOKEN_ADDRESS,
            commitment,
            response,
        );
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_registration_if_wrong_sender() {
        let (dk, ek) = generate_twisted_elgamal_keypair();
        let (commitment, response) = confidential_proof::prove_registration(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            &dk,
            &ek,
            TEST_TOKEN_ADDRESS,
        );

        confidential_proof::verify_registration_proof_for_test(
            TEST_CHAIN_ID,
            @0xb2,
            TEST_CONTRACT_ADDRESS,
            &ek,
            TEST_TOKEN_ADDRESS,
            commitment,
            response,
        );
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_registration_if_wrong_contract_address() {
        let (dk, ek) = generate_twisted_elgamal_keypair();
        let (commitment, response) = confidential_proof::prove_registration(
            TEST_CHAIN_ID,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            &dk,
            &ek,
            TEST_TOKEN_ADDRESS,
        );

        confidential_proof::verify_registration_proof_for_test(
            TEST_CHAIN_ID,
            TEST_SENDER,
            @0xc0ffee,
            &ek,
            TEST_TOKEN_ADDRESS,
            commitment,
            response,
        );
    }

    // ==========================================
    // Cross-chain replay rejection tests
    // ==========================================

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_withdraw_if_wrong_chain_id() {
        let params = withdraw();

        confidential_proof::verify_withdrawal_proof(
            TEST_CHAIN_ID + 1,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.ek,
            params.amount,
            &params.current_balance,
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_withdraw_if_wrong_sender() {
        let params = withdraw();

        confidential_proof::verify_withdrawal_proof(
            TEST_CHAIN_ID,
            @0xb2,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.ek,
            params.amount,
            &params.current_balance,
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_transfer_if_wrong_chain_id() {
        let params = transfer();

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID + 1,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.sender_ek,
            &params.recipient_ek,
            &params.current_balance,
            &params.new_balance,
            &params.sender_amount,
            &params.recipient_amount,
            &params.auditor_eks,
            &params.auditor_amounts,
            &params.sender_auditor_hint,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_transfer_if_wrong_sender() {
        let params = transfer();

        confidential_proof::verify_transfer_proof(
            TEST_CHAIN_ID,
            @0xb2,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.sender_ek,
            &params.recipient_ek,
            &params.current_balance,
            &params.new_balance,
            &params.sender_amount,
            &params.recipient_amount,
            &params.auditor_eks,
            &params.auditor_amounts,
            &params.sender_auditor_hint,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_rotate_if_wrong_chain_id() {
        let params = rotate();

        confidential_proof::verify_rotation_proof(
            TEST_CHAIN_ID + 1,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.current_ek,
            &params.new_ek,
            &params.current_balance,
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_rotate_if_wrong_sender() {
        let params = rotate();

        confidential_proof::verify_rotation_proof(
            TEST_CHAIN_ID,
            @0xb2,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.current_ek,
            &params.new_ek,
            &params.current_balance,
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_normalize_if_wrong_chain_id() {
        let params = normalize();

        confidential_proof::verify_normalization_proof(
            TEST_CHAIN_ID + 1,
            TEST_SENDER,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.ek,
            &params.current_balance,
            &params.new_balance,
            &params.proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x010001, location = confidential_proof)]
    fun fail_normalize_if_wrong_sender() {
        let params = normalize();

        confidential_proof::verify_normalization_proof(
            TEST_CHAIN_ID,
            @0xb2,
            TEST_CONTRACT_ADDRESS,
            TEST_TOKEN_ADDRESS,
            &params.ek,
            &params.current_balance,
            &params.new_balance,
            &params.proof);
    }
}
