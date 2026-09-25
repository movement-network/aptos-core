spec aptos_framework::zktls {
    /// <high-level-req>
    /// No.: 1
    /// Requirement: Only an admin of the source can configure its verifier: create it, register attestor sets, and
    /// register or revoke templates.
    /// Criticality: Critical
    /// Implementation: initialize, set_attestor_set, register_template and revoke_template all assert
    /// attestation::is_admin before touching the Verifier.
    /// Enforcement: Formally verified via [high-level-req-1](set_attestor_set) and audited in unit tests for the
    /// remaining entry functions.
    ///
    /// No.: 2
    /// Requirement: An attestor set has a threshold of at least one and at most its size, and each rotation moves to
    /// a new epoch that is one higher than the last.
    /// Criticality: High
    /// Implementation: set_attestor_set asserts 1 <= required <= count, increments current_epoch and adds the set
    /// under the new epoch.
    /// Enforcement: Formally verified via [high-level-req-2](set_attestor_set).
    ///
    /// No.: 3
    /// Requirement: Only the current attestor epoch verifies, plus the immediately previous one until the grace
    /// deadline set at rotation. A rotated-away set stops verifying once the deadline passes, and an older one stops
    /// immediately.
    /// Criticality: Critical
    /// Implementation: epoch_accepted accepts current_epoch, or current_epoch - 1 while now < previous_deadline_secs.
    /// verify_claim_internal asserts it.
    /// Enforcement: Formally verified via [high-level-req-3.1](epoch_accepted) and [high-level-req-3.2](enroll).
    ///
    /// No.: 4
    /// Requirement: A signed claim is single use. Once a claim has been used to enroll it can never enroll again, so it
    /// can neither refresh an expiry indefinitely nor undo a revocation.
    /// Criticality: Critical
    /// Implementation: enroll records keccak256(claim) in Verifier.consumed and aborts if it is already present.
    /// verify_claim returns false for a consumed claim.
    /// Enforcement: Formally verified via [high-level-req-4.1](enroll) and [high-level-req-4.2](verify_claim).
    ///
    /// No.: 5
    /// Requirement: A claim under a revoked template never enrolls, and verify_claim never reports it as valid.
    /// Criticality: High
    /// Implementation: verify_claim_internal returns the template's active flag; enroll aborts with ETEMPLATE_REVOKED
    /// and verify_claim folds it into its result.
    /// Enforcement: Formally verified via [high-level-req-5.1](enroll) and [high-level-req-5.2](verify_claim).
    ///
    /// No.: 6
    /// Requirement: A claim is bound to the subject submitting it and to the template it is redeemed under, and a
    /// non-empty nullifier must be carried by the signed claim. A valid attestation for one person is not an
    /// attestation for whoever relays it.
    /// Criticality: Critical
    /// Implementation: claim_binds checks that the lowercase hex of bcs(subject) and of template_id both appear in the
    /// claim, and enroll checks the same for the nullifier.
    /// Enforcement: Audited in unit tests (test_claim_for_another_subject_fails, test_claim_under_another_template_fails,
    /// test_nullifier_not_in_claim_fails). The byte-search loops are not amenable to the prover.
    ///
    /// No.: 7
    /// Requirement: Distinct attestors, each a member of the epoch's set, must sign, and at least threshold of them.
    /// Criticality: Critical
    /// Implementation: verify_claim_internal recovers each signer with secp256k1::ecdsa_recover, aborts on a signer
    /// outside the set or a repeated signer, and compares the distinct count with the threshold.
    /// Enforcement: Audited in unit tests with fixed secp256k1 vectors. The recovery loop runs inside for_each_ref,
    /// which the prover havocs.
    /// </high-level-req>
    spec module {
        pragma verify = true;
        pragma aborts_if_is_strict = false;
    }

    spec fun spec_now(): u64 {
        aptos_framework::timestamp::spec_now_seconds()
    }

    spec fun spec_epoch_accepted(verifier: Verifier, epoch: u64): bool {
        epoch != 0
            && (epoch == verifier.current_epoch
                || (epoch < verifier.current_epoch
                    && verifier.current_epoch - epoch == 1
                    && spec_now() < verifier.previous_deadline_secs))
    }

    spec is_initialized(source: address): bool {
        aborts_if false;
        ensures result == exists<Verifier>(source);
    }

    spec current_epoch(source: address): u64 {
        aborts_if !exists<Verifier>(source);
        ensures result == global<Verifier>(source).current_epoch;
    }

    spec threshold(source: address, epoch: u64): u64 {
        aborts_if !exists<Verifier>(source);
        aborts_if !table::spec_contains(global<Verifier>(source).sets, epoch);
        ensures result == table::spec_get(global<Verifier>(source).sets, epoch).threshold;
    }

    spec is_template_active(source: address, template_id: vector<u8>): bool {
        aborts_if false;
        let templates = global<Verifier>(source).templates;
        ensures result == (exists<Verifier>(source)
            && table::spec_contains(templates, template_id)
            && table::spec_get(templates, template_id).active);
    }

    spec is_claim_consumed(source: address, claim: vector<u8>): bool {
        aborts_if false;
        ensures result == (exists<Verifier>(source)
            && table::spec_contains(
                global<Verifier>(source).consumed, aptos_std::aptos_hash::spec_keccak256(claim)
            ));
    }

    spec epoch_accepted(verifier: &Verifier, epoch: u64): bool {
        pragma aborts_if_is_partial;
        /// [high-level-req-3.1]
        ensures result == spec_epoch_accepted(verifier, epoch);
    }

    spec is_epoch_accepted(source: address, epoch: u64): bool {
        pragma aborts_if_is_partial;
        ensures !exists<Verifier>(source) ==> !result;
        ensures exists<Verifier>(source) ==> result == spec_epoch_accepted(global<Verifier>(source), epoch);
    }

    spec set_attestor_set(
        admin: &signer,
        source: address,
        attestor_addresses: vector<vector<u8>>,
        required: u64,
        previous_grace_secs: u64
    ) {
        // Attestor length and duplicate rejection happen inside a for_each_ref loop, which the
        // prover havocs; those paths are covered by unit tests.
        pragma aborts_if_is_partial;
        /// [high-level-req-1]
        aborts_if !aptos_framework::attestation::spec_is_source(source);
        aborts_if !contains(global<aptos_framework::attestation::Source>(source).admins, address_of(admin));
        aborts_if !exists<Verifier>(source);
        /// [high-level-req-2]
        aborts_if required < 1 || required > len(attestor_addresses);
        let post verifier = global<Verifier>(source);
        ensures verifier.current_epoch == old(global<Verifier>(source).current_epoch) + 1;
        ensures table::spec_contains(verifier.sets, verifier.current_epoch);
        ensures table::spec_get(verifier.sets, verifier.current_epoch).threshold == required;
        ensures table::spec_get(verifier.sets, verifier.current_epoch).attestors == attestor_addresses;
        ensures verifier.previous_deadline_secs >= spec_now();
        ensures verifier.consumed == old(global<Verifier>(source).consumed);
        ensures verifier.templates == old(global<Verifier>(source).templates);
    }

    spec register_template(
        admin: &signer,
        source: address,
        template_id: vector<u8>,
        grants_level: u8,
        ttl_secs: u64
    ) {
        pragma aborts_if_is_partial;
        aborts_if !exists<Verifier>(source);
        let post template = table::spec_get(global<Verifier>(source).templates, template_id);
        ensures template.active;
        ensures template.grants_level == grants_level;
        ensures template.ttl_secs == ttl_secs;
    }

    spec revoke_template(admin: &signer, source: address, template_id: vector<u8>) {
        pragma aborts_if_is_partial;
        aborts_if !exists<Verifier>(source);
        aborts_if !table::spec_contains(global<Verifier>(source).templates, template_id);
        ensures !table::spec_get(global<Verifier>(source).templates, template_id).active;
        ensures global<Verifier>(source).consumed == old(global<Verifier>(source).consumed);
    }

    spec verify_claim(
        source: address,
        template_id: vector<u8>,
        subject: address,
        claim: vector<u8>,
        signatures: vector<vector<u8>>,
        attestor_epoch: u64
    ): bool {
        pragma aborts_if_is_partial;
        aborts_if !exists<Verifier>(source);
        let verifier = global<Verifier>(source);
        /// [high-level-req-4.2]
        ensures result ==> !table::spec_contains(verifier.consumed, aptos_std::aptos_hash::spec_keccak256(claim));
        /// [high-level-req-5.2]
        ensures result ==> table::spec_get(verifier.templates, template_id).active;
        ensures result ==> spec_epoch_accepted(verifier, attestor_epoch);
    }

    spec enroll(
        user: &signer,
        source: address,
        template_id: vector<u8>,
        claim: vector<u8>,
        signatures: vector<vector<u8>>,
        attestor_epoch: u64,
        nullifier: vector<u8>
    ) {
        // The signature-recovery and byte-search loops are havocked by the prover, so only the
        // listed abort conditions are claimed, not that they are exhaustive.
        pragma aborts_if_is_partial;
        let verifier = global<Verifier>(source);
        let digest = aptos_std::aptos_hash::spec_keccak256(claim);
        aborts_if !exists<Verifier>(source);
        aborts_if !table::spec_contains(verifier.templates, template_id);
        aborts_if !table::spec_contains(verifier.sets, attestor_epoch);
        /// [high-level-req-3.2]
        aborts_if !spec_epoch_accepted(verifier, attestor_epoch);
        /// [high-level-req-5.1]
        aborts_if !table::spec_get(verifier.templates, template_id).active;
        /// [high-level-req-4.1]
        aborts_if table::spec_contains(verifier.consumed, digest);
        ensures table::spec_contains(global<Verifier>(source).consumed, digest);
        ensures global<Verifier>(source).sets == old(global<Verifier>(source).sets);
        ensures global<Verifier>(source).templates == old(global<Verifier>(source).templates);
    }
}
