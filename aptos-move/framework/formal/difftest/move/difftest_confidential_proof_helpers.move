/// Difftest-only Fiat–Shamir prefix assemblers for the four confidential-asset
/// sigma protocols (withdrawal / normalization / rotation / transfer).
///
/// The production `confidential_proof` module constructs the Fiat–Shamir
/// message inline inside each `fiat_shamir_*_sigma_proof_challenge` function
/// and never exposes a public *prefix* accessor. The FS *prefix* — the
/// SHA2-512-hashed message *before* the per-proof commitment `X`s are
/// appended — is the structurally interesting surface for byte-layout
/// regression testing (DST + `prepend_domain_context` + G + H + public
/// keys + balances / amount chunks + auditor data).
///
/// This harness-only module re-implements that prefix byte-for-byte using
/// ONLY public APIs from `aptos_std::ristretto255`,
/// `aptos_experimental::ristretto255_twisted_elgamal`,
/// `aptos_experimental::confidential_balance`, and
/// `aptos_experimental::confidential_proof` (the `get_fiat_shamir_*_sigma_dst`
/// accessors already exposed as `#[view]`).
///
/// # Invariant with the production FS challenge
///
/// For any inputs `(chain_id, sender, contract, …, proof_xs)`, concatenating
/// `{withdrawal,normalization,rotation,transfer}_fs_prefix(…)` with the
/// per-proof X-bytes (`point_to_bytes(&proof_xs.xN)` + for-each-ref
/// `point_to_bytes` over each `xNs` vector, then for transfer also
/// `bcs::to_bytes(&sender_auditor_hint)`) and feeding the result into
/// `ristretto255::new_scalar_from_sha2_512` MUST yield the same `Scalar`
/// as the production `fiat_shamir_*_sigma_proof_challenge`. If that
/// invariant drifts, this module MUST be updated in lock-step — the byte
/// layout is the commitment of the FS transcript hashed by every prover
/// and verifier on-chain.
///
/// # Why a harness module and not the production file
///
/// Adding public `*_fs_prefix_for_test` helpers to the production
/// `confidential_proof.move` would expand the on-chain ABI surface. The
/// harness replicates the prefix logic here so difftest rows exercise the
/// exact same serialization without modifying production. This mirrors the
/// precedent established by `difftest_registration_helpers.move`, which
/// reimplements `registration_fs_message_*` using public primitives.
module 0x1::difftest_confidential_proof_helpers {
    use std::bcs;
    use std::vector;
    use aptos_std::ristretto255;
    use aptos_experimental::confidential_balance;
    use aptos_experimental::confidential_proof;
    use aptos_experimental::ristretto255_twisted_elgamal as twisted_elgamal;

    /// Mirrors the private `confidential_proof::prepend_domain_context`
    /// helper (line ~1365 of `confidential_proof.move`): prepends
    /// `chain_id` (1 byte) followed by BCS-encoded `sender` and
    /// `contract_address` to an existing byte buffer.
    fun prepend_domain_context(
        bytes: &mut vector<u8>,
        chain_id: u8,
        sender: address,
        contract_address: address,
    ) {
        let context = vector::singleton(chain_id);
        context.append(bcs::to_bytes(&sender));
        context.append(bcs::to_bytes(&contract_address));
        context.append(*bytes);
        *bytes = context;
    }

    /// Returns `point_to_bytes(point_compress(basepoint))`. Named
    /// `g_bytes` because this is the 32-byte encoding of the Curve25519
    /// basepoint `G`, which every sigma FS message starts with (right
    /// after the DST + domain context).
    fun g_bytes(): vector<u8> {
        let bp = ristretto255::basepoint_compressed();
        ristretto255::compressed_point_to_bytes(bp)
    }

    /// Returns the 32-byte encoding of `H = hash_to_point_base()`. Every
    /// sigma FS message concatenates `G || H` at the fixed offset right
    /// after the domain context.
    fun h_bytes(): vector<u8> {
        let h = ristretto255::hash_to_point_base();
        let hc = ristretto255::point_compress(&h);
        ristretto255::compressed_point_to_bytes(hc)
    }

    // ======================================================================
    // Withdrawal FS prefix
    // Layout: DST || chain_id || sender || contract
    //      || G || H || ek || v_{1..4} || C_cur ciphertext bytes
    // Matches `confidential_proof::fiat_shamir_withdrawal_sigma_proof_challenge`
    // up to (but NOT including) the appended `X`-point block.
    // Expected length for the fixed fixture `basepoint_ek, zero_chunks,
    // new_actual_balance_no_randomness`: 837 bytes.
    // ======================================================================
    public fun withdrawal_fs_prefix(
        chain_id: u8,
        sender: address,
        contract_address: address,
        ek: &twisted_elgamal::CompressedPubkey,
        amount_chunks: &vector<ristretto255::Scalar>,
        current_balance: &confidential_balance::ConfidentialBalance,
    ): vector<u8> {
        let bytes = vector[];
        bytes.append(g_bytes());
        bytes.append(h_bytes());
        bytes.append(twisted_elgamal::pubkey_to_bytes(ek));
        amount_chunks.for_each_ref(|chunk| {
            bytes.append(ristretto255::scalar_to_bytes(chunk));
        });
        bytes.append(confidential_balance::balance_to_bytes(current_balance));
        prepend_domain_context(&mut bytes, chain_id, sender, contract_address);
        let msg = confidential_proof::get_fiat_shamir_withdrawal_sigma_dst();
        msg.append(bytes);
        msg
    }

    // ======================================================================
    // Normalization FS prefix
    // Layout: DST || chain_id || sender || contract
    //      || G || H || ek || balance_bytes(current) || balance_bytes(new)
    // Matches `confidential_proof::fiat_shamir_normalization_sigma_proof_challenge`
    // up to (but NOT including) the appended `X`-point block.
    // ======================================================================
    public fun normalization_fs_prefix(
        chain_id: u8,
        sender: address,
        contract_address: address,
        ek: &twisted_elgamal::CompressedPubkey,
        current_balance: &confidential_balance::ConfidentialBalance,
        new_balance: &confidential_balance::ConfidentialBalance,
    ): vector<u8> {
        let bytes = vector[];
        bytes.append(g_bytes());
        bytes.append(h_bytes());
        bytes.append(twisted_elgamal::pubkey_to_bytes(ek));
        bytes.append(confidential_balance::balance_to_bytes(current_balance));
        bytes.append(confidential_balance::balance_to_bytes(new_balance));
        prepend_domain_context(&mut bytes, chain_id, sender, contract_address);
        let msg = confidential_proof::get_fiat_shamir_normalization_sigma_dst();
        msg.append(bytes);
        msg
    }

    // ======================================================================
    // Rotation FS prefix
    // Layout: DST || chain_id || sender || contract
    //      || G || H || current_ek || new_ek
    //      || balance_bytes(current) || balance_bytes(new)
    // Matches `confidential_proof::fiat_shamir_rotation_sigma_proof_challenge`
    // up to (but NOT including) the appended `X`-point block.
    // ======================================================================
    public fun rotation_fs_prefix(
        chain_id: u8,
        sender: address,
        contract_address: address,
        current_ek: &twisted_elgamal::CompressedPubkey,
        new_ek: &twisted_elgamal::CompressedPubkey,
        current_balance: &confidential_balance::ConfidentialBalance,
        new_balance: &confidential_balance::ConfidentialBalance,
    ): vector<u8> {
        let bytes = vector[];
        bytes.append(g_bytes());
        bytes.append(h_bytes());
        bytes.append(twisted_elgamal::pubkey_to_bytes(current_ek));
        bytes.append(twisted_elgamal::pubkey_to_bytes(new_ek));
        bytes.append(confidential_balance::balance_to_bytes(current_balance));
        bytes.append(confidential_balance::balance_to_bytes(new_balance));
        prepend_domain_context(&mut bytes, chain_id, sender, contract_address);
        let msg = confidential_proof::get_fiat_shamir_rotation_sigma_dst();
        msg.append(bytes);
        msg
    }

    // ======================================================================
    // Transfer FS prefix
    // Layout: DST || chain_id || sender || contract
    //      || G || H || sender_ek || recipient_ek
    //      || auditor_eks (each 32 B)
    //      || balance_bytes(current_balance)
    //      || balance_bytes(recipient_amount)
    //      || for each auditor_amount: for each d in balance_to_points_d:
    //             compressed_point_to_bytes(point_compress(d))
    //      || for each d in balance_to_points_d(sender_amount):
    //             compressed_point_to_bytes(point_compress(d))
    //      || balance_bytes(new_balance)
    // Matches `confidential_proof::fiat_shamir_transfer_sigma_proof_challenge`
    // up to (but NOT including) the appended `X`-point block **and** the
    // trailing `bcs::to_bytes(sender_auditor_hint)`. The production
    // sender_auditor_hint is a per-proof opaque blob and is excluded from
    // the prefix for the same reason the `X`-points are excluded: prefix
    // testing is about the byte layout of the public inputs.
    // ======================================================================
    public fun transfer_fs_prefix(
        chain_id: u8,
        sender: address,
        contract_address: address,
        sender_ek: &twisted_elgamal::CompressedPubkey,
        recipient_ek: &twisted_elgamal::CompressedPubkey,
        current_balance: &confidential_balance::ConfidentialBalance,
        new_balance: &confidential_balance::ConfidentialBalance,
        sender_amount: &confidential_balance::ConfidentialBalance,
        recipient_amount: &confidential_balance::ConfidentialBalance,
        auditor_eks: &vector<twisted_elgamal::CompressedPubkey>,
        auditor_amounts: &vector<confidential_balance::ConfidentialBalance>,
    ): vector<u8> {
        let bytes = vector[];
        bytes.append(g_bytes());
        bytes.append(h_bytes());
        bytes.append(twisted_elgamal::pubkey_to_bytes(sender_ek));
        bytes.append(twisted_elgamal::pubkey_to_bytes(recipient_ek));
        auditor_eks.for_each_ref(|ek| {
            bytes.append(twisted_elgamal::pubkey_to_bytes(ek));
        });
        bytes.append(confidential_balance::balance_to_bytes(current_balance));
        bytes.append(confidential_balance::balance_to_bytes(recipient_amount));
        auditor_amounts.for_each_ref(|balance| {
            let ds = confidential_balance::balance_to_points_d(balance);
            ds.for_each_ref(|d| {
                bytes.append(
                    ristretto255::compressed_point_to_bytes(
                        ristretto255::point_compress(d)
                    )
                );
            });
        });
        let sender_ds = confidential_balance::balance_to_points_d(sender_amount);
        sender_ds.for_each_ref(|d| {
            bytes.append(
                ristretto255::compressed_point_to_bytes(
                    ristretto255::point_compress(d)
                )
            );
        });
        bytes.append(confidential_balance::balance_to_bytes(new_balance));
        prepend_domain_context(&mut bytes, chain_id, sender, contract_address);
        let msg = confidential_proof::get_fiat_shamir_transfer_sigma_dst();
        msg.append(bytes);
        msg
    }
}
