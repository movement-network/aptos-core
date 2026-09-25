spec aptos_framework::attestation_policy {
    /// <high-level-req>
    /// No.: 1
    /// Requirement: A staged body has no effect before its activation time (INV-9). Staging, re-staging and
    /// cancelling never change the live body, and only activate_pending swaps it in, once its time has arrived.
    /// Criticality: Critical
    /// Implementation: stage_body and stage_attr_rules write only Policy.pending. activate_pending asserts that a body
    /// is pending and that now_seconds() >= effective_at_secs before replacing Policy.body.
    /// Enforcement: Formally verified via [high-level-req-1.1](stage_body), [high-level-req-1.2](stage_attr_rules),
    /// [high-level-req-1.3](cancel_pending) and [high-level-req-1.4](activate_pending).
    ///
    /// No.: 2
    /// Requirement: A denial always produces DECISION_DENY (INV-1). A chain-wide denial is consulted before any
    /// positive rule and wins over every vouching source.
    /// Criticality: Critical
    /// Implementation: evaluate checks the chain denial source first, then every deny_any source, before any
    /// require_all or require_any rule.
    /// Enforcement: Formally verified for the chain denial via [high-level-req-2](evaluate). The deny_any sources are
    /// consulted inside a for_each_ref loop, which the prover havocs, and are covered by unit tests
    /// (test_deny_source_beats_a_vouching_source).
    ///
    /// No.: 3
    /// Requirement: A paused policy denies with its own reason rather than silently allowing, and a policy with no
    /// positive rule allows nothing.
    /// Criticality: High
    /// Implementation: evaluate returns (DECISION_DENY, REASON_POLICY_PAUSED) when paused, and
    /// (DECISION_DENY, REASON_EMPTY_BODY) when both require lists are empty.
    /// Enforcement: Formally verified via [high-level-req-3.1](evaluate) and [high-level-req-3.2](require).
    ///
    /// No.: 4
    /// Requirement: Only an admin can stage, cancel, set step-up thresholds, set the authorizer or manage roles, only a
    /// guardian can pause, and a policy always has at least one admin.
    /// Criticality: Critical
    /// Implementation: assert_admin and the guardian check run first in every entry function, and remove_admins
    /// asserts that at least one admin remains.
    /// Enforcement: Formally verified via [high-level-req-4.1](stage_body), [high-level-req-4.2](set_paused) and
    /// [high-level-req-4.3](remove_admins).
    ///
    /// No.: 5
    /// Requirement: A body can name at most one chain-wide denial source.
    /// Criticality: Medium
    /// Implementation: stage_body asserts chain_deny has length 0 or 1.
    /// Enforcement: Formally verified via [high-level-req-5](stage_body).
    /// </high-level-req>
    spec module {
        pragma verify = true;
        pragma aborts_if_is_strict = false;
    }

    spec fun spec_now(): u64 {
        aptos_framework::timestamp::spec_now_seconds()
    }

    spec schema PolicyAdminAbortsIf {
        policy: address;
        admin: signer;
        aborts_if !exists<Policy>(policy);
        aborts_if !contains(global<Policy>(policy).admins, address_of(admin));
    }

    spec standard_version(): u64 {
        aborts_if false;
        ensures result == VERSION;
    }

    spec is_paused(policy: address): bool {
        aborts_if !exists<Policy>(policy);
        ensures result == global<Policy>(policy).paused;
    }

    spec has_pending(policy: address): bool {
        aborts_if !exists<Policy>(policy);
        ensures result == option::is_some(global<Policy>(policy).pending);
    }

    spec step_up_for(policy: address, action: u8): u64 {
        aborts_if !exists<Policy>(policy);
        let thresholds = global<Policy>(policy).step_up_above;
        ensures table::spec_contains(thresholds, action) ==> result == table::spec_get(thresholds, action);
        ensures !table::spec_contains(thresholds, action) ==> result == 0;
    }

    spec evaluate(policy: address, subject: address, action: u8, amount: u64): (u8, u16) {
        // Source lists are walked by for_each_ref loops, which the prover havocs, so abort
        // conditions inside them (a missing clock) are not enumerated.
        pragma aborts_if_is_partial;
        aborts_if !exists<Policy>(policy);
        let config = global<Policy>(policy);
        let body = config.body;
        let empty = len(body.require_any) == 0 && len(body.require_all) == 0;
        /// [high-level-req-3.1]
        ensures config.paused ==> result_1 == DECISION_DENY && result_2 == REASON_POLICY_PAUSED;
        ensures !config.paused && empty ==> result_1 == DECISION_DENY && result_2 == REASON_EMPTY_BODY;
        /// [high-level-req-2]
        ensures !config.paused && !empty && option::is_some(body.chain_deny)
            && aptos_framework::attestation::spec_is_denied(option::borrow(body.chain_deny), subject)
            ==> result_1 == DECISION_DENY && result_2 == REASON_CHAIN_DENIED;
        ensures result_1 == DECISION_ALLOW ==> result_2 == REASON_OK;
        ensures result_1 == DECISION_ALLOW || result_1 == DECISION_DENY || result_1 == DECISION_STEP_UP;
    }

    spec require(policy: address, subject: address, action: u8, amount: u64) {
        pragma aborts_if_is_partial;
        aborts_if !exists<Policy>(policy);
        /// [high-level-req-3.2]
        aborts_if global<Policy>(policy).paused;
        aborts_if len(global<Policy>(policy).body.require_any) == 0
            && len(global<Policy>(policy).body.require_all) == 0;
    }

    spec stage_body(
        admin: &signer,
        policy: address,
        require_any_sources: vector<address>,
        require_any_levels: vector<u8>,
        require_all_sources: vector<address>,
        require_all_levels: vector<u8>,
        deny_any: vector<address>,
        chain_deny: vector<address>,
        effective_at_secs: u64
    ) {
        // Source existence is checked inside loops, which the prover havocs.
        pragma aborts_if_is_partial;
        /// [high-level-req-4.1]
        include PolicyAdminAbortsIf;
        /// [high-level-req-5]
        aborts_if len(chain_deny) > 1;
        aborts_if len(require_any_sources) > MAX_SOURCES;
        aborts_if len(require_all_sources) > MAX_SOURCES;
        aborts_if len(deny_any) > MAX_SOURCES;
        aborts_if len(require_any_sources) != len(require_any_levels);
        aborts_if len(require_all_sources) != len(require_all_levels);
        let post config = global<Policy>(policy);
        /// [high-level-req-1.1]
        ensures config.body == old(global<Policy>(policy).body);
        ensures option::is_some(config.pending);
        ensures option::borrow(config.pending).effective_at_secs == effective_at_secs;
        ensures option::borrow(config.pending).body.deny_any == deny_any;
        ensures len(chain_deny) == 0 ==> option::is_none(option::borrow(config.pending).body.chain_deny);
        ensures len(chain_deny) == 1 ==> option::borrow(config.pending).body.chain_deny == option::spec_some(chain_deny[0]);
    }

    spec stage_attr_rules(
        admin: &signer,
        policy: address,
        sources: vector<address>,
        keys: vector<u16>,
        ops: vector<u8>,
        values: vector<vector<vector<u8>>>
    ) {
        pragma aborts_if_is_partial;
        include PolicyAdminAbortsIf;
        aborts_if len(sources) > MAX_RULES;
        aborts_if len(sources) != len(keys) || len(sources) != len(ops) || len(sources) != len(values);
        /// [high-level-req-1.2]
        ensures global<Policy>(policy).body == old(global<Policy>(policy).body);
        ensures option::is_some(global<Policy>(policy).pending);
    }

    spec cancel_pending(admin: &signer, policy: address) {
        include PolicyAdminAbortsIf;
        aborts_if option::is_none(global<Policy>(policy).pending);
        /// [high-level-req-1.3]
        ensures global<Policy>(policy).body == old(global<Policy>(policy).body);
        ensures option::is_none(global<Policy>(policy).pending);
    }

    spec activate_pending(_anyone: &signer, policy: address) {
        let config = global<Policy>(policy);
        aborts_if !exists<Policy>(policy);
        aborts_if option::is_none(config.pending);
        aborts_if !exists<aptos_framework::timestamp::CurrentTimeMicroseconds>(@aptos_framework);
        /// [high-level-req-1.4]
        aborts_if spec_now() < option::borrow(config.pending).effective_at_secs;
        ensures global<Policy>(policy).body == option::borrow(config.pending).body;
        ensures option::is_none(global<Policy>(policy).pending);
    }

    spec set_paused(guardian: &signer, policy: address, paused: bool) {
        aborts_if !exists<Policy>(policy);
        /// [high-level-req-4.2]
        aborts_if !contains(global<Policy>(policy).guardians, address_of(guardian));
        ensures global<Policy>(policy).paused == paused;
        ensures global<Policy>(policy).body == old(global<Policy>(policy).body);
        ensures global<Policy>(policy).pending == old(global<Policy>(policy).pending);
    }

    spec set_step_up(admin: &signer, policy: address, action: u8, threshold: u64) {
        include PolicyAdminAbortsIf;
        ensures table::spec_get(global<Policy>(policy).step_up_above, action) == threshold;
        ensures global<Policy>(policy).body == old(global<Policy>(policy).body);
    }

    spec set_authorizer(admin: &signer, policy: address, pubkey: vector<u8>, max_ttl_secs: u64) {
        include PolicyAdminAbortsIf;
        aborts_if len(pubkey) != 0 && len(pubkey) != 32;
        ensures global<Policy>(policy).authorizer_pubkey == pubkey;
        ensures global<Policy>(policy).authorizer_max_ttl_secs == max_ttl_secs;
    }

    spec remove_admins(admin: &signer, policy: address, old_admins: vector<address>) {
        pragma aborts_if_is_partial;
        include PolicyAdminAbortsIf;
        /// [high-level-req-4.3]
        ensures len(global<Policy>(policy).admins) >= 1;
    }

    spec create(deployer: &signer, admins: vector<address>, guardians: vector<address>) {
        // create_resource_account has cross-module side effects (account creation, coin
        // registration, sequence-number seed derivation) that the prover cannot model.
        pragma verify = false;
    }
}
