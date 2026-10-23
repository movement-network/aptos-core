/// PAUSED: confidential assets are disabled on Movement; interface retained for upgrade compatibility only
///
/// Sigma and range proof verification for confidential assets.
///
/// Every public function and every entry function aborts with `E_CONFIDENTIAL_ASSETS_PAUSED` (wrapped in
/// `error::unavailable`). All structs are retained with identical names, abilities and field layout because the compatible upgrade policy refuses to
/// remove or change a published struct. No resource is published, no event is emitted and no state is changed.
module aptos_framework::confidential_proof {
    use std::error;
    use std::option::Option;
    use aptos_std::ristretto255::{CompressedRistretto, Scalar};
    use aptos_std::ristretto255_bulletproofs::RangeProof;
    use aptos_framework::confidential_balance;
    use aptos_framework::ristretto255_twisted_elgamal as twisted_elgamal;

    /// Confidential assets are paused: every function in this module aborts.
    const E_CONFIDENTIAL_ASSETS_PAUSED: u64 = 1;

    /// Represents the proof structure for validating a withdrawal operation.
    struct WithdrawalProof has drop {
        /// Sigma proof ensuring that the withdrawal operation maintains balance integrity.
        sigma_proof: WithdrawalSigmaProof,
        /// Range proof ensuring that the resulting balance chunks are normalized (i.e., within the 16-bit limit).
        zkrp_new_balance: RangeProof,
    }

    /// Represents the proof structure for validating a transfer operation.
    struct TransferProof has drop {
        /// Sigma proof ensuring that the transfer operation maintains balance integrity and correctness.
        sigma_proof: TransferSigmaProof,
        /// Range proof ensuring that the resulting balance chunks for the sender are normalized (i.e., within the 16-bit limit).
        zkrp_new_balance: RangeProof,
        /// Range proof ensuring that the transferred amount chunks are normalized (i.e., within the 16-bit limit).
        zkrp_transfer_amount: RangeProof,
    }

    /// Represents the proof structure for validating a normalization operation.
    struct NormalizationProof has drop {
        /// Sigma proof ensuring that the normalization operation maintains balance integrity.
        sigma_proof: NormalizationSigmaProof,
        /// Range proof ensuring that the resulting balance chunks are normalized (i.e., within the 16-bit limit).
        zkrp_new_balance: RangeProof,
    }

    /// Represents the proof structure for validating a key rotation operation.
    struct RotationProof has drop {
        /// Sigma proof ensuring that the key rotation operation preserves balance integrity.
        sigma_proof: RotationSigmaProof,
        /// Range proof ensuring that the resulting balance chunks after key rotation are normalized (i.e., within the 16-bit limit).
        zkrp_new_balance: RangeProof,
    }

    struct WithdrawalSigmaProofXs has drop {
        x1: CompressedRistretto,
        x2: CompressedRistretto,
        x3s: vector<CompressedRistretto>,
        x4s: vector<CompressedRistretto>,
    }

    struct WithdrawalSigmaProofAlphas has drop {
        a1s: vector<Scalar>,
        a2: Scalar,
        a3: Scalar,
        a4s: vector<Scalar>,
    }

    struct WithdrawalSigmaProofGammas has drop {
        g1: Scalar,
        g2: Scalar,
        g3s: vector<Scalar>,
        g4s: vector<Scalar>,
    }

    struct WithdrawalSigmaProof has drop {
        alphas: WithdrawalSigmaProofAlphas,
        xs: WithdrawalSigmaProofXs,
    }

    struct TransferSigmaProofXs has drop {
        x1: CompressedRistretto,
        x2s: vector<CompressedRistretto>,
        x3s: vector<CompressedRistretto>,
        x4s: vector<CompressedRistretto>,
        x5: CompressedRistretto,
        x6s: vector<CompressedRistretto>,
        x7s: vector<vector<CompressedRistretto>>,
        x8s: vector<CompressedRistretto>,
    }

    struct TransferSigmaProofAlphas has drop {
        a1s: vector<Scalar>,
        a2: Scalar,
        a3s: vector<Scalar>,
        a4s: vector<Scalar>,
        a5: Scalar,
        a6s: vector<Scalar>,
    }

    struct TransferSigmaProofGammas has drop {
        g1: Scalar,
        g2s: vector<Scalar>,
        g3s: vector<Scalar>,
        g4s: vector<Scalar>,
        g5: Scalar,
        g6s: vector<Scalar>,
        g7s: vector<vector<Scalar>>,
        g8s: vector<Scalar>,
    }

    struct TransferSigmaProof has drop {
        alphas: TransferSigmaProofAlphas,
        xs: TransferSigmaProofXs,
    }

    struct NormalizationSigmaProofXs has drop {
        x1: CompressedRistretto,
        x2: CompressedRistretto,
        x3s: vector<CompressedRistretto>,
        x4s: vector<CompressedRistretto>,
    }

    struct NormalizationSigmaProofAlphas has drop {
        a1s: vector<Scalar>,
        a2: Scalar,
        a3: Scalar,
        a4s: vector<Scalar>,
    }

    struct NormalizationSigmaProofGammas has drop {
        g1: Scalar,
        g2: Scalar,
        g3s: vector<Scalar>,
        g4s: vector<Scalar>,
    }

    struct NormalizationSigmaProof has drop {
        alphas: NormalizationSigmaProofAlphas,
        xs: NormalizationSigmaProofXs,
    }

    struct RotationSigmaProofXs has drop {
        x1: CompressedRistretto,
        x2: CompressedRistretto,
        x3: CompressedRistretto,
        x4s: vector<CompressedRistretto>,
        x5s: vector<CompressedRistretto>,
    }

    struct RotationSigmaProofAlphas has drop {
        a1s: vector<Scalar>,
        a2: Scalar,
        a3: Scalar,
        a4: Scalar,
        a5s: vector<Scalar>,
    }

    struct RotationSigmaProofGammas has drop {
        g1: Scalar,
        g2: Scalar,
        g3: Scalar,
        g4s: vector<Scalar>,
        g5s: vector<Scalar>,
    }

    struct RotationSigmaProof has drop {
        alphas: RotationSigmaProofAlphas,
        xs: RotationSigmaProofXs,
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun verify_withdrawal_proof(
        _chain_id: u8,
        _sender: address,
        _contract_address: address,
        _token_address: address,
        _ek: &twisted_elgamal::CompressedPubkey,
        _amount: u64,
        _current_balance: &confidential_balance::ConfidentialBalance,
        _new_balance: &confidential_balance::ConfidentialBalance,
        _proof: &WithdrawalProof) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun verify_transfer_proof(
        _chain_id: u8,
        _sender: address,
        _contract_address: address,
        _token_address: address,
        _sender_ek: &twisted_elgamal::CompressedPubkey,
        _recipient_ek: &twisted_elgamal::CompressedPubkey,
        _current_balance: &confidential_balance::ConfidentialBalance,
        _new_balance: &confidential_balance::ConfidentialBalance,
        _sender_amount: &confidential_balance::ConfidentialBalance,
        _recipient_amount: &confidential_balance::ConfidentialBalance,
        _auditor_eks: &vector<twisted_elgamal::CompressedPubkey>,
        _auditor_amounts: &vector<confidential_balance::ConfidentialBalance>,
        _sender_auditor_hint: &vector<u8>,
        _proof: &TransferProof) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun verify_normalization_proof(
        _chain_id: u8,
        _sender: address,
        _contract_address: address,
        _token_address: address,
        _ek: &twisted_elgamal::CompressedPubkey,
        _current_balance: &confidential_balance::ConfidentialBalance,
        _new_balance: &confidential_balance::ConfidentialBalance,
        _proof: &NormalizationProof) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun verify_rotation_proof(
        _chain_id: u8,
        _sender: address,
        _contract_address: address,
        _token_address: address,
        _current_ek: &twisted_elgamal::CompressedPubkey,
        _new_ek: &twisted_elgamal::CompressedPubkey,
        _current_balance: &confidential_balance::ConfidentialBalance,
        _new_balance: &confidential_balance::ConfidentialBalance,
        _proof: &RotationProof) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun deserialize_withdrawal_proof(
        _sigma_proof_bytes: vector<u8>,
        _zkrp_new_balance_bytes: vector<u8>): Option<WithdrawalProof> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun deserialize_transfer_proof(
        _sigma_proof_bytes: vector<u8>,
        _zkrp_new_balance_bytes: vector<u8>,
        _zkrp_transfer_amount_bytes: vector<u8>): Option<TransferProof> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun deserialize_normalization_proof(
        _sigma_proof_bytes: vector<u8>,
        _zkrp_new_balance_bytes: vector<u8>): Option<NormalizationProof> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun deserialize_rotation_proof(
        _sigma_proof_bytes: vector<u8>,
        _zkrp_new_balance_bytes: vector<u8>): Option<RotationProof> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_fiat_shamir_withdrawal_sigma_dst(): vector<u8> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_fiat_shamir_transfer_sigma_dst(): vector<u8> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_fiat_shamir_normalization_sigma_dst(): vector<u8> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_fiat_shamir_rotation_sigma_dst(): vector<u8> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_fiat_shamir_registration_sigma_dst(): vector<u8> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_bulletproofs_dst(): vector<u8> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_bulletproofs_num_bits(): u64 {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }
}
