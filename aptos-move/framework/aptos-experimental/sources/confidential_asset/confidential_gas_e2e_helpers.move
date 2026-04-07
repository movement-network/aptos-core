// Helpers for Rust e2e-move-tests: bundle proof generation and serialization for entry payloads.
#[test_only]
module aptos_experimental::confidential_gas_e2e_helpers {
    use std::vector;
    use aptos_std::ristretto255::Scalar;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object::Object;

    use aptos_experimental::confidential_asset;
    use aptos_experimental::confidential_balance;
    use aptos_experimental::confidential_proof;
    use aptos_experimental::ristretto255_twisted_elgamal::{Self as twisted_elgamal, CompressedPubkey};

    /// `(new_balance_bytes, zkrp_new_balance, sigma_proof)` for `withdraw_to`.
    public fun pack_withdraw_to_proof(
        chain_id: u8,
        sender: address,
        dk: &Scalar,
        ek: &CompressedPubkey,
        withdraw_amount: u64,
        new_balance_amount: u128,
        token: Object<Metadata>,
    ): (vector<u8>, vector<u8>, vector<u8>) {
        let compressed = confidential_asset::actual_balance(sender, token);
        let current = confidential_balance::decompress_balance(&compressed);
        let (proof, new_balance) = confidential_proof::prove_withdrawal(
            chain_id,
            sender,
            @aptos_experimental,
            dk,
            ek,
            withdraw_amount,
            new_balance_amount,
            &current,
        );
        let new_balance_bytes = confidential_balance::balance_to_bytes(&new_balance);
        let (sigma_proof, zkrp_new_balance) = confidential_proof::serialize_withdrawal_proof(&proof);
        (new_balance_bytes, zkrp_new_balance, sigma_proof)
    }

    /// Same as `pack_confidential_transfer_proof` with no voluntary auditors (`auditor_eks` empty).
    public fun pack_confidential_transfer_proof_simple(
        chain_id: u8,
        sender: address,
        recipient: address,
        sender_dk: &Scalar,
        transfer_amount: u64,
        new_balance_amount: u128,
        token: Object<Metadata>,
    ): (
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
    ) {
        let no_extra_auditors = vector::empty<CompressedPubkey>();
        pack_confidential_transfer_proof_inner(
            chain_id,
            sender,
            recipient,
            sender_dk,
            transfer_amount,
            new_balance_amount,
            token,
            &no_extra_auditors,
        )
    }

    /// Includes voluntary auditors (each 32-byte compressed pubkey) plus optional asset auditor
    /// (first key) when `set_auditor` was called on-chain.
    public fun pack_confidential_transfer_proof_with_auditors(
        chain_id: u8,
        sender: address,
        recipient: address,
        sender_dk: &Scalar,
        transfer_amount: u64,
        new_balance_amount: u128,
        token: Object<Metadata>,
        auditor_eks: vector<vector<u8>>,
    ): (
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
    ) {
        let parsed = {
            let acc = vector::empty<CompressedPubkey>();
            let len = auditor_eks.length();
            let i = 0;
            while (i < len) {
                vector::push_back(
                    &mut acc,
                    twisted_elgamal::new_pubkey_from_bytes(auditor_eks[i]).extract(),
                );
                i = i + 1;
            };
            acc
        };
        pack_confidential_transfer_proof_inner(
            chain_id,
            sender,
            recipient,
            sender_dk,
            transfer_amount,
            new_balance_amount,
            token,
            &parsed,
        )
    }

    fun pack_confidential_transfer_proof_inner(
        chain_id: u8,
        sender: address,
        recipient: address,
        sender_dk: &Scalar,
        transfer_amount: u64,
        new_balance_amount: u128,
        token: Object<Metadata>,
        auditor_eks: &vector<CompressedPubkey>,
    ): (
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
        vector<u8>,
    ) {
        let sender_ek = confidential_asset::encryption_key(sender, token);
        let recipient_ek = confidential_asset::encryption_key(recipient, token);
        let compressed = confidential_asset::actual_balance(sender, token);
        let current = confidential_balance::decompress_balance(&compressed);
        let (
            proof,
            new_balance,
            sender_amount,
            recipient_amount,
            auditor_amounts,
        ) = confidential_proof::prove_transfer(
            chain_id,
            sender,
            @aptos_experimental,
            sender_dk,
            &sender_ek,
            &recipient_ek,
            transfer_amount,
            new_balance_amount,
            &current,
            auditor_eks,
        );
        let (sigma_proof, zkrp_new_balance, zkrp_transfer_amount) =
            confidential_proof::serialize_transfer_proof(&proof);
        (
            confidential_balance::balance_to_bytes(&new_balance),
            confidential_balance::balance_to_bytes(&sender_amount),
            confidential_balance::balance_to_bytes(&recipient_amount),
            confidential_asset::serialize_auditor_eks(auditor_eks),
            confidential_asset::serialize_auditor_amounts(&auditor_amounts),
            zkrp_new_balance,
            zkrp_transfer_amount,
            sigma_proof,
        )
    }

    /// `(new_ek_bytes, new_balance_bytes, zkrp_new_balance, sigma_proof)` for `rotate_encryption_key`.
    public fun pack_rotate_encryption_key_proof(
        chain_id: u8,
        sender: address,
        sender_dk: &Scalar,
        new_dk: &Scalar,
        new_ek: &CompressedPubkey,
        balance_amount: u128,
        token: Object<Metadata>,
    ): (vector<u8>, vector<u8>, vector<u8>, vector<u8>) {
        let sender_ek = confidential_asset::encryption_key(sender, token);
        let compressed = confidential_asset::actual_balance(sender, token);
        let current = confidential_balance::decompress_balance(&compressed);
        let (proof, new_balance) = confidential_proof::prove_rotation(
            chain_id,
            sender,
            @aptos_experimental,
            sender_dk,
            new_dk,
            &sender_ek,
            new_ek,
            balance_amount,
            &current,
        );
        let new_balance_bytes = confidential_balance::balance_to_bytes(&new_balance);
        let (sigma_proof, zkrp_new_balance) = confidential_proof::serialize_rotation_proof(&proof);
        (
            twisted_elgamal::pubkey_to_bytes(new_ek),
            new_balance_bytes,
            zkrp_new_balance,
            sigma_proof,
        )
    }
}
