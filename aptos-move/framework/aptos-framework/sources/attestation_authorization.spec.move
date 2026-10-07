spec aptos_framework::attestation_authorization {
    /// <high-level-req>
    /// No.: 1
    /// Requirement: An authorization is usable at most once, and only inside its validity window (INV-8).
    /// Criticality: Critical
    /// Implementation: verify_and_consume aborts if the nonce is already in Nonces.used, if now is before issued_at or
    /// at or after expires_at, and otherwise inserts the nonce before returning.
    /// Enforcement: Formally verified via [high-level-req-1](verify_and_consume) that every successful call inserts a
    /// nonce that was not present before. The window checks are audited in unit tests, because the fields are decoded
    /// by loops the prover havocs.
    ///
    /// No.: 2
    /// Requirement: Only a nonce that can no longer be replayed is ever pruned.
    /// Criticality: High
    /// Implementation: prune_nonces removes an entry only when its stored expiry is at or before now; replaying an
    /// authorization with that nonce would fail the expiry check anyway.
    /// Enforcement: Audited in unit tests (test_prune_expired_nonces). The removal loop is havocked by the prover.
    ///
    /// No.: 3
    /// Requirement: The nonce store can only be created by attestation_policy, with the policy's own signer, exactly
    /// once per policy.
    /// Criticality: High
    /// Implementation: initialize and verify_and_consume are public(friend) with attestation_policy as the only friend.
    /// Enforcement: Enforced by the friend declaration, which the compiler checks. Formally verified via
    /// [high-level-req-3](initialize) that a second initialization aborts.
    ///
    /// No.: 4
    /// Requirement: An authorization requires a configured 32-byte authorizer key and a blob of the exact fixed
    /// layout.
    /// Criticality: Medium
    /// Implementation: verify_and_consume asserts the key length and decode asserts the blob length.
    /// Enforcement: Formally verified via [high-level-req-4](verify_and_consume).
    /// </high-level-req>
    spec module {
        pragma verify = true;
        pragma aborts_if_is_strict = false;
    }

    spec is_initialized(policy: address): bool {
        aborts_if false;
        ensures result == exists<Nonces>(policy);
    }

    spec is_nonce_used(policy: address, nonce: vector<u8>): bool {
        aborts_if false;
        ensures result == (exists<Nonces>(policy)
            && table::spec_contains(global<Nonces>(policy).used, nonce));
    }

    spec bucket_ceiling(bucket: u8): u64 {
        pragma aborts_if_is_partial;
        aborts_if bucket > MAX_BUCKET;
    }

    spec authorization_message(
        policy: address,
        subject: address,
        action: u8,
        amount_bucket: u8,
        nonce: vector<u8>,
        issued_at_secs: u64,
        expires_at_secs: u64
    ): vector<u8> {
        aborts_if !exists<chain_id::ChainId>(@aptos_framework);
    }

    spec initialize(policy_account: &signer) {
        /// [high-level-req-3]
        aborts_if exists<Nonces>(std::signer::address_of(policy_account));
        ensures exists<Nonces>(std::signer::address_of(policy_account));
    }

    spec verify_and_consume(
        policy: address,
        authorizer_pubkey: vector<u8>,
        max_ttl_secs: u64,
        subject: address,
        action: u8,
        amount: u64,
        authorization: vector<u8>
    ) {
        // The blob is decoded by while loops that the prover havocs, so the decoded fields, and
        // therefore the expiry, TTL and signature checks, cannot be named here. Those are
        // covered by unit tests.
        pragma aborts_if_is_partial;
        aborts_if !exists<Nonces>(policy);
        /// [high-level-req-4]
        aborts_if len(authorizer_pubkey) != PUBKEY_LENGTH;
        aborts_if len(authorization) != 2 + NONCE_LENGTH + 16 + SIGNATURE_LENGTH;
        let used = global<Nonces>(policy).used;
        let post post_used = global<Nonces>(policy).used;
        /// [high-level-req-1]
        ensures exists nonce: vector<u8>:
            !table::spec_contains(used, nonce) && table::spec_contains(post_used, nonce);
    }

    spec prune_nonces(_anyone: &signer, policy: address, nonces: vector<vector<u8>>) {
        pragma aborts_if_is_partial;
        aborts_if !exists<Nonces>(policy);
        aborts_if len(nonces) > MAX_PRUNE;
    }
}
