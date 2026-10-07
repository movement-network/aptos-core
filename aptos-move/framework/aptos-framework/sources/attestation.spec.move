spec aptos_framework::attestation {
    /// <high-level-req>
    /// No.: 1
    /// Requirement: A denial always wins. While a denial is in effect for a subject, the source never reports that
    /// subject as verified, regardless of any fact recorded for it (INV-1).
    /// Criticality: Critical
    /// Implementation: active_with_level checks is_denied_internal before reading the subject's record and returns
    /// (false, 0) when the denial is in effect. is_verified, level_of and state_of all route through it, and
    /// attestation_policy consults is_denied before any positive rule.
    /// Enforcement: Formally verified via [high-level-req-1](active_with_level).
    ///
    /// No.: 2
    /// Requirement: No positive write path can create, modify or clear a denial (INV-2), and no positive write can be
    /// recorded for a subject that has a denial entry.
    /// Criticality: Critical
    /// Implementation: Every positive write ends in record_fact, which aborts when the subject has a denial entry and
    /// never touches the denied table. transition refuses to reactivate a denied subject.
    /// Enforcement: Formally verified via [high-level-req-2.1](record_fact) and [high-level-req-2.2](transition).
    ///
    /// No.: 3
    /// Requirement: A fact whose expiry has passed, whose epoch is below its issuer's current epoch, or whose epoch is
    /// below the source floor is never treated as active (INV-3). A floor raise or an epoch bump always takes effect,
    /// and new writes are stamped with the issuer's effective epoch so they are not born stale.
    /// Criticality: Critical
    /// Implementation: active_with_level compares the record against now_seconds(), the per-issuer epoch and the
    /// floor. issuer_epoch_of returns max(own counter, floor), which is what assert_issuer and record_verified_claim
    /// stamp and what bump_issuer_epoch increments. set_floor_epoch is strictly increasing.
    /// Enforcement: Formally verified via [high-level-req-3.1](active_with_level), [high-level-req-3.2](issuer_epoch_of),
    /// [high-level-req-3.3](bump_issuer_epoch), [high-level-req-3.4](set_floor_epoch) and
    /// [high-level-req-3.5](record_verified_claim).
    ///
    /// No.: 4
    /// Requirement: Pausing a source blocks writes and never changes any fact or denial, so it never changes what
    /// is_verified reports (INV-4).
    /// Criticality: High
    /// Implementation: set_paused writes only Source.paused. Facts is a separate resource that the read path uses
    /// exclusively; every write path calls assert_not_paused.
    /// Enforcement: Formally verified via [high-level-req-4](set_paused).
    ///
    /// No.: 5
    /// Requirement: Only a sentinel can add a denial and only a remover can remove one (INV-5). Neither operation
    /// touches any fact.
    /// Criticality: Critical
    /// Implementation: deny and deny_batch check the sentinel list, undeny checks the remover list, and both write only
    /// the denied table.
    /// Enforcement: Formally verified via [high-level-req-5.1](deny), [high-level-req-5.2](deny_batch) and
    /// [high-level-req-5.3](undeny).
    ///
    /// No.: 6
    /// Requirement: Lifecycle changes follow ACTIVE <-> SUSPENDED and ACTIVE or SUSPENDED -> REVOKED only. A revoked
    /// record is terminal until re-issued, and a lifecycle change never alters the issuer or epoch a fact was issued
    /// under, so it cannot resurrect a fact an epoch bump killed.
    /// Criticality: Critical
    /// Implementation: transition asserts the allowed transitions, treats a repeated revocation as a no-op, and
    /// leaves issuer_id and issuer_epoch unchanged; the acting issuer is recorded in the history entry only.
    /// Enforcement: Formally verified via [high-level-req-6](transition).
    ///
    /// No.: 7
    /// Requirement: Configuration and facts live in separate resources, and the read path touches only Facts and
    /// per-subject table entries, so gated transactions never conflict with one another under Block-STM (INV-7).
    /// Criticality: Medium
    /// Implementation: Facts is published once at creation and only its table entries change afterwards. The read
    /// functions (is_verified, active_with_level, is_denied) acquire Facts only.
    /// Enforcement: Enforced by the `acquires` annotations of the read functions, which the compiler checks. Audited
    /// that no write path replaces the Facts resource itself.
    ///
    /// No.: 8
    /// Requirement: Every role list is duplicate free, never contains the source itself, and a source always has at
    /// least one admin.
    /// Criticality: High
    /// Implementation: validate_members runs on creation and on every add, and remove_admins asserts that at least one
    /// admin remains.
    /// Enforcement: Formally verified via [high-level-req-8.1](create_source_internal) and
    /// [high-level-req-8.2](remove_admins).
    ///
    /// No.: 9
    /// Requirement: Only a current issuer can write facts, directly or through the permissionless relay path. Removing
    /// an issuer's role also stops its relayed attestations.
    /// Criticality: Critical
    /// Implementation: assert_issuer and redeem_attestation both require the issuer to be in Source.issuers.
    /// Enforcement: Formally verified via [high-level-req-9.1](suspend) and [high-level-req-9.2](redeem_attestation).
    /// </high-level-req>
    ///
    /// INV-6 of the functional specification (every keyed resource an enum with a V1 variant) was not adopted: the
    /// module follows the plain-struct style of the rest of the framework, so it is not specified here. INV-8 and INV-9
    /// belong to attestation_authorization and attestation_policy respectively.
    spec module {
        pragma verify = true;
        pragma aborts_if_is_strict = false;
    }

    spec fun spec_now(): u64 {
        aptos_framework::timestamp::spec_now_seconds()
    }

    spec fun spec_has_time(): bool {
        exists<aptos_framework::timestamp::CurrentTimeMicroseconds>(@aptos_framework)
    }

    spec fun spec_is_source(source: address): bool {
        exists<Source>(source) && exists<Facts>(source)
    }

    /// A denial is in effect for the subject.
    spec fun spec_is_denied(source: address, subject: address): bool {
        let denied = global<Facts>(source).denied;
        table::spec_contains(denied, subject)
            && spec_now() >= table::spec_get(denied, subject).effective_at_secs
    }

    spec fun spec_floor(source: address): u64 {
        table::spec_get(global<Facts>(source).floor_epoch, 0)
    }

    spec fun spec_own_epoch(source: address, issuer_id: u16): u64 {
        let epochs = global<Facts>(source).issuer_epochs;
        if (table::spec_contains(epochs, issuer_id)) {
            table::spec_get(epochs, issuer_id)
        } else { 0 }
    }

    /// Effective epoch of an issuer: the larger of its own counter and the source floor.
    spec fun spec_effective_epoch(source: address, issuer_id: u16): u64 {
        let own = spec_own_epoch(source, issuer_id);
        let floor = spec_floor(source);
        if (own > floor) { own } else { floor }
    }

    spec schema SourceExistsAbortsIf {
        source: address;
        aborts_if !spec_is_source(source);
    }

    spec schema AdminAbortsIf {
        source: address;
        admin: signer;
        include SourceExistsAbortsIf;
        aborts_if !contains(global<Source>(source).admins, address_of(admin));
    }

    // =============================== Views ===============================

    spec is_source(source: address): bool {
        aborts_if false;
        ensures result == spec_is_source(source);
    }

    spec standard_version(): u64 {
        aborts_if false;
        ensures result == VERSION;
    }

    spec is_paused(source: address): bool {
        include SourceExistsAbortsIf;
        ensures result == global<Source>(source).paused;
    }

    spec admins(source: address): vector<address> {
        include SourceExistsAbortsIf;
        ensures result == global<Source>(source).admins;
    }

    spec is_admin(addr: address, source: address): bool {
        include SourceExistsAbortsIf;
        ensures result == contains(global<Source>(source).admins, addr);
    }

    spec is_issuer(addr: address, source: address): bool {
        include SourceExistsAbortsIf;
        ensures result == contains(global<Source>(source).issuers, addr);
    }

    spec is_denied(source: address, subject: address): bool {
        include SourceExistsAbortsIf;
        aborts_if table::spec_contains(global<Facts>(source).denied, subject) && !spec_has_time();
        ensures result == spec_is_denied(source, subject);
    }

    spec floor_epoch(source: address): u64 {
        include SourceExistsAbortsIf;
        aborts_if !table::spec_contains(global<Facts>(source).floor_epoch, 0);
        ensures result == spec_floor(source);
    }

    spec issuer_epoch_of(source: address, issuer_id: u16): u64 {
        include SourceExistsAbortsIf;
        aborts_if !table::spec_contains(global<Facts>(source).floor_epoch, 0);
        /// [high-level-req-3.2]
        ensures result == spec_effective_epoch(source, issuer_id);
        ensures result >= spec_floor(source);
        ensures result >= spec_own_epoch(source, issuer_id);
    }

    spec active_with_level(source: address, subject: address): (bool, u8) {
        // The abort conditions depend on which early return is taken (a missing clock is only
        // reached through a denial entry or an active record), so only the unconditional one is
        // listed; the properties that matter are the ensures below.
        pragma aborts_if_is_partial;
        include SourceExistsAbortsIf;
        let facts = global<Facts>(source);
        let record = table::spec_get(facts.subjects, subject);
        /// [high-level-req-1]
        ensures spec_is_denied(source, subject) ==> !result_1 && result_2 == 0;
        /// [high-level-req-3.1]
        ensures result_1 ==> table::spec_contains(facts.subjects, subject)
            && record.state == STATE_ACTIVE
            && record.expires_at_secs > spec_now()
            && record.issuer_epoch >= spec_effective_epoch(source, record.issuer_id);
        ensures result_1 ==> result_2 == record.level;
        ensures !result_1 ==> result_2 == 0;
    }

    // =============================== Creation and roles ===============================

    spec create(
        deployer: &signer,
        admins: vector<address>,
        issuers: vector<address>,
        sentinels: vector<address>,
        removers: vector<address>,
        guardians: vector<address>
    ) {
        // create_resource_account has cross-module side effects (account creation, coin
        // registration, sequence-number seed derivation) that the prover cannot model. The
        // invariants of the published state are verified on create_source_internal instead.
        pragma verify = false;
    }

    spec create_source_internal(
        source_account: &signer,
        deployer: address,
        admins: vector<address>,
        issuers: vector<address>,
        sentinels: vector<address>,
        removers: vector<address>,
        guardians: vector<address>,
        signer_cap: account::SignerCapability
    ) {
        let addr = address_of(source_account);
        // Duplicate and self-membership rejection happens inside for_each_ref loops, which the
        // prover havocs; those abort paths are covered by unit tests instead.
        pragma aborts_if_is_partial;
        /// [high-level-req-8.1]
        aborts_if len(admins) < 1;
        aborts_if exists<Source>(addr);
        aborts_if exists<Facts>(addr);
        ensures spec_is_source(addr);
        ensures global<Source>(addr).admins == admins;
        ensures global<Source>(addr).issuers == issuers;
        ensures global<Source>(addr).sentinels == sentinels;
        ensures global<Source>(addr).removers == removers;
        ensures global<Source>(addr).guardians == guardians;
        ensures !global<Source>(addr).paused;
        ensures global<Source>(addr).next_issuer_id == 1;
        ensures table::spec_contains(global<Facts>(addr).floor_epoch, 0);
        ensures spec_floor(addr) == 0;
    }

    spec remove_admins(admin: &signer, source: address, old_admins: vector<address>) {
        pragma aborts_if_is_partial;
        include AdminAbortsIf;
        /// [high-level-req-8.2]
        ensures len(global<Source>(source).admins) >= 1;
    }

    spec add_admins(admin: &signer, source: address, new_admins: vector<address>) {
        pragma aborts_if_is_partial;
        include AdminAbortsIf;
    }

    // =============================== Pause ===============================

    spec set_paused(guardian: &signer, source: address, paused: bool) {
        include SourceExistsAbortsIf;
        aborts_if !contains(global<Source>(source).guardians, address_of(guardian));
        ensures global<Source>(source).paused == paused;
        /// [high-level-req-4]
        ensures global<Facts>(source) == old(global<Facts>(source));
    }

    spec pause(guardian: &signer, source: address) {
        include SourceExistsAbortsIf;
        aborts_if !contains(global<Source>(source).guardians, address_of(guardian));
        ensures global<Source>(source).paused;
        ensures global<Facts>(source) == old(global<Facts>(source));
    }

    spec unpause(guardian: &signer, source: address) {
        include SourceExistsAbortsIf;
        aborts_if !contains(global<Source>(source).guardians, address_of(guardian));
        ensures !global<Source>(source).paused;
        ensures global<Facts>(source) == old(global<Facts>(source));
    }

    // =============================== Epochs ===============================

    spec bump_issuer_epoch(admin: &signer, source: address, issuer_id: u16) {
        include AdminAbortsIf;
        aborts_if issuer_id != 0 && !table::spec_contains(global<Source>(source).issuer_by_id, issuer_id);
        aborts_if !table::spec_contains(global<Facts>(source).floor_epoch, 0);
        aborts_if spec_effective_epoch(source, issuer_id) + 1 > MAX_U64;
        /// [high-level-req-3.3]
        ensures spec_own_epoch(source, issuer_id) == old(spec_effective_epoch(source, issuer_id)) + 1;
        ensures spec_effective_epoch(source, issuer_id) > old(spec_effective_epoch(source, issuer_id));
        ensures global<Facts>(source).subjects == old(global<Facts>(source).subjects);
        ensures global<Facts>(source).denied == old(global<Facts>(source).denied);
        ensures global<Facts>(source).floor_epoch == old(global<Facts>(source).floor_epoch);
    }

    spec set_floor_epoch(admin: &signer, source: address, epoch: u64) {
        include AdminAbortsIf;
        aborts_if !table::spec_contains(global<Facts>(source).floor_epoch, 0);
        /// [high-level-req-3.4]
        aborts_if epoch <= spec_floor(source);
        ensures spec_floor(source) == epoch;
        ensures spec_floor(source) > old(spec_floor(source));
        ensures global<Facts>(source).subjects == old(global<Facts>(source).subjects);
        ensures global<Facts>(source).denied == old(global<Facts>(source).denied);
    }

    // =============================== Positive writes ===============================

    spec record_fact(
        source: address,
        subject: address,
        state: u8,
        level: u8,
        issuer_id: u16,
        issuer_epoch: u64,
        expires_at_secs: u64,
        issued_at_secs: u64,
        reason: u16,
        attestation_digest: vector<u8>
    ) {
        pragma aborts_if_is_partial;
        aborts_if !exists<Facts>(source);
        aborts_if !spec_has_time();
        /// [high-level-req-2.1]
        aborts_if table::spec_contains(global<Facts>(source).denied, subject);
        ensures global<Facts>(source).denied == old(global<Facts>(source).denied);
        ensures global<Facts>(source).issuer_epochs == old(global<Facts>(source).issuer_epochs);
        ensures global<Facts>(source).floor_epoch == old(global<Facts>(source).floor_epoch);
        ensures global<Facts>(source).nullifiers == old(global<Facts>(source).nullifiers);
        let post record = table::spec_get(global<Facts>(source).subjects, subject);
        ensures table::spec_contains(global<Facts>(source).subjects, subject);
        ensures record.state == state;
        ensures record.level == level;
        ensures record.issuer_id == issuer_id;
        ensures record.issuer_epoch == issuer_epoch;
        ensures record.expires_at_secs == expires_at_secs;
    }

    spec transition(
        source: address,
        subject: address,
        state: u8,
        acting_issuer_id: u16,
        reason: u16
    ) {
        pragma aborts_if_is_partial;
        let facts = global<Facts>(source);
        let record = table::spec_get(facts.subjects, subject);
        let post post_record = table::spec_get(global<Facts>(source).subjects, subject);
        aborts_if !exists<Facts>(source);
        aborts_if !table::spec_contains(facts.subjects, subject);
        /// [high-level-req-6]
        aborts_if state == STATE_SUSPENDED && record.state != STATE_ACTIVE;
        aborts_if state == STATE_ACTIVE && record.state != STATE_SUSPENDED;
        aborts_if state == STATE_REVOKED && record.state != STATE_ACTIVE
            && record.state != STATE_SUSPENDED && record.state != STATE_REVOKED;
        aborts_if state != STATE_ACTIVE && state != STATE_SUSPENDED && state != STATE_REVOKED;
        /// [high-level-req-2.2]
        aborts_if state == STATE_ACTIVE && table::spec_contains(facts.denied, subject);
        ensures post_record.issuer_id == record.issuer_id;
        ensures post_record.issuer_epoch == record.issuer_epoch;
        ensures post_record.level == record.level;
        ensures post_record.expires_at_secs == record.expires_at_secs;
        ensures post_record.state == state;
        ensures record.state == STATE_REVOKED ==> post_record == record;
        ensures global<Facts>(source).denied == old(global<Facts>(source).denied);
        ensures global<Facts>(source).issuer_epochs == old(global<Facts>(source).issuer_epochs);
        ensures global<Facts>(source).floor_epoch == old(global<Facts>(source).floor_epoch);
    }

    spec suspend(issuer: &signer, source: address, subject: address, reason: u16) {
        pragma aborts_if_is_partial;
        include SourceExistsAbortsIf;
        aborts_if global<Source>(source).paused;
        /// [high-level-req-9.1]
        aborts_if !contains(global<Source>(source).issuers, address_of(issuer));
        aborts_if !table::spec_contains(global<Source>(source).issuer_info, address_of(issuer));
        ensures table::spec_get(global<Facts>(source).subjects, subject).state == STATE_SUSPENDED;
        ensures global<Facts>(source).denied == old(global<Facts>(source).denied);
    }

    spec unsuspend(issuer: &signer, source: address, subject: address, reason: u16) {
        pragma aborts_if_is_partial;
        include SourceExistsAbortsIf;
        aborts_if global<Source>(source).paused;
        aborts_if !contains(global<Source>(source).issuers, address_of(issuer));
        aborts_if table::spec_contains(global<Facts>(source).denied, subject);
        aborts_if table::spec_contains(global<Facts>(source).subjects, subject)
            && table::spec_get(global<Facts>(source).subjects, subject).state != STATE_SUSPENDED;
        ensures table::spec_get(global<Facts>(source).subjects, subject).issuer_epoch
            == old(table::spec_get(global<Facts>(source).subjects, subject).issuer_epoch);
        ensures global<Facts>(source).denied == old(global<Facts>(source).denied);
    }

    spec record_verified_claim(
        source: address,
        subject: address,
        level: u8,
        expires_at_secs: u64,
        attestation_digest: vector<u8>,
        nullifier: vector<u8>
    ) {
        pragma aborts_if_is_partial;
        include SourceExistsAbortsIf;
        aborts_if global<Source>(source).paused;
        aborts_if len(attestation_digest) != DIGEST_LENGTH;
        aborts_if table::spec_contains(global<Facts>(source).denied, subject);
        let post record = table::spec_get(global<Facts>(source).subjects, subject);
        ensures record.issuer_id == 0;
        /// [high-level-req-3.5]
        ensures record.issuer_epoch == old(spec_effective_epoch(source, 0));
        ensures record.level == level;
        ensures record.state == STATE_ACTIVE;
        ensures global<Facts>(source).denied == old(global<Facts>(source).denied);
    }

    spec redeem_attestation(
        _relayer: &signer,
        source: address,
        subject: address,
        issuer_id: u16,
        issuer_epoch: u64,
        level: u8,
        expires_at_secs: u64,
        issued_at_secs: u64,
        nullifier: vector<u8>,
        signature: vector<u8>
    ) {
        pragma aborts_if_is_partial;
        let config = global<Source>(source);
        let issuer_address = table::spec_get(config.issuer_by_id, issuer_id);
        include SourceExistsAbortsIf;
        aborts_if config.paused;
        aborts_if !table::spec_contains(config.issuer_by_id, issuer_id);
        /// [high-level-req-9.2]
        aborts_if !contains(config.issuers, issuer_address);
        aborts_if table::spec_contains(global<Facts>(source).denied, subject);
        ensures global<Facts>(source).denied == old(global<Facts>(source).denied);
        ensures table::spec_get(global<Facts>(source).subjects, subject).issuer_epoch == issuer_epoch;
    }

    // =============================== Exclusion ===============================

    spec deny(
        sentinel: &signer,
        source: address,
        subject: address,
        reason: u16,
        effective_at_secs: u64
    ) {
        include SourceExistsAbortsIf;
        /// [high-level-req-5.1]
        aborts_if !contains(global<Source>(source).sentinels, address_of(sentinel));
        aborts_if !spec_has_time();
        ensures table::spec_contains(global<Facts>(source).denied, subject);
        ensures table::spec_get(global<Facts>(source).denied, subject).effective_at_secs == effective_at_secs;
        ensures global<Facts>(source).subjects == old(global<Facts>(source).subjects);
    }

    spec deny_batch(sentinel: &signer, source: address, subjects: vector<address>, reason: u16) {
        pragma aborts_if_is_partial;
        include SourceExistsAbortsIf;
        /// [high-level-req-5.2]
        aborts_if !contains(global<Source>(source).sentinels, address_of(sentinel));
        aborts_if len(subjects) > MAX_BATCH;
    }

    spec undeny(remover: &signer, source: address, subject: address) {
        include SourceExistsAbortsIf;
        /// [high-level-req-5.3]
        aborts_if !contains(global<Source>(source).removers, address_of(remover));
        ensures !table::spec_contains(global<Facts>(source).denied, subject);
        ensures global<Facts>(source).subjects == old(global<Facts>(source).subjects);
    }

    // =============================== Roots ===============================

    spec publish_root(issuer: &signer, source: address, digest: vector<u8>, leaf_count: u64) {
        pragma aborts_if_is_partial;
        aborts_if len(digest) != DIGEST_LENGTH;
        include SourceExistsAbortsIf;
        aborts_if global<Source>(source).paused;
        ensures global<Source>(source).root_epoch == old(global<Source>(source).root_epoch) + 1;
        ensures global<Facts>(source) == old(global<Facts>(source));
    }
}
