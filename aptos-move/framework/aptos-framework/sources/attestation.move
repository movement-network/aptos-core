/// Attestation source module for Movement. A source is an independent namespace that asserts
/// facts about addresses: who is verified, at what level, with what attributes, and who is
/// excluded. Anyone may create one, and nothing here is globally trusted, so a consumer names the
/// sources it trusts or gets no answer. Two sources may disagree about the same subject and
/// nothing is broken, because a fact is never true globally, only true according to somebody.
///
/// Each source is a resource account, following `aptos_framework::timelock`: the deployer
/// authorizes creation and pays gas but gains no role unless it is listed in the role arguments.
/// The account has no owner, so unlike an object it cannot be transferred or burned out from under
/// the integrators that hardcoded its address.
///
/// Roles, and why each is separate:
/// - Admins configure the source, register and rotate issuers, and grant roles.
/// - Issuers write facts. This is the hot key, and it deliberately cannot touch denials or roles.
/// - Sentinels may ADD denials only, which is the fast path for sanctions screening.
/// - Removers may REMOVE denials only. Mistaken denial is the dominant operational failure mode in
///   production systems of this kind, so reversal is a designed path with a different key rather
///   than an afterthought.
/// - Guardians may pause writes without needing the admin path.
/// An address may hold several roles; the overlap is allowed on purpose so authority can be handed
/// over without a gap, exactly as `timelock` allows for its canceler role.
///
/// Delayed governance comes for free by composition: an admin address may be a
/// `aptos_framework::timelock` account, in which case every configuration change inherits that
/// module's delay, multi-role and cancel semantics. This module deliberately does not reimplement
/// any of it.
///
/// Properties:
/// - Denial is evaluated before anything else and no positive write can create, modify or clear it.
/// - A fact is never active past its expiry, below its issuer's epoch, or below the source floor.
/// - Bumping an issuer's epoch invalidates every fact that issuer wrote, in one write, which is
///   the remedy for a compromised issuer key and is O(1) in the size of the cohort.
/// - Pausing blocks writes and never changes the answer `is_verified` gives. A pause must not
///   silently flip a boolean that other protocols depend on.
/// - Configuration and facts live in two separate resources so the read path touches only
///   immutable state and per-subject table keys, and gated transactions therefore never conflict
///   with one another under Block-STM.
module aptos_framework::attestation {
    use std::account::{Self, SignerCapability, create_resource_address};
    use std::bcs::to_bytes;
    use std::chain_id;
    use std::ed25519;
    use std::error;
    use std::event::emit;
    use std::signer::address_of;
    use std::simple_map::{Self, SimpleMap};
    use std::table::{Self, Table};
    use std::timestamp::now_seconds;

    friend aptos_framework::zktls;

    /// Domain separator used when deriving the resource account seed, to avoid collisions with
    /// other modules that create resource accounts.
    const DOMAIN_SEPARATOR: vector<u8> = b"aptos_framework::attestation";
    /// Domain separator for the message an issuer signs for the permissionless relay path. Keeps a
    /// relay attestation from being reinterpreted as any other signed payload.
    const DOMAIN_ATTESTATION: vector<u8> = b"aptos_framework::attestation::ATTEST";

    /// No record exists. The default for every address.
    const STATE_NONE: u8 = 0;
    /// The source asserts this subject currently qualifies.
    const STATE_ACTIVE: u8 = 1;
    /// Temporarily withheld, reversible by the issuer.
    const STATE_SUSPENDED: u8 = 2;
    /// Terminal for this record; requires re-issuance rather than un-revocation.
    const STATE_REVOKED: u8 = 3;

    /// Expiry value meaning the fact never expires on its own.
    const NEVER_EXPIRES: u64 = 18446744073709551615;
    /// Largest number of subjects one batch call may touch.
    const MAX_BATCH: u64 = 1000;
    /// Largest number of change entries retained per subject. Older entries are dropped.
    const MAX_HISTORY: u64 = 32;
    /// Largest number of attributes retained per subject.
    const MAX_ATTRS: u64 = 32;
    /// Required length of a 32-byte digest, nullifier or root.
    const DIGEST_LENGTH: u64 = 32;
    /// Required length of an ed25519 public key.
    const PUBKEY_LENGTH: u64 = 32;
    /// Required length of an ed25519 signature.
    const SIGNATURE_LENGTH: u64 = 64;
    /// Attribute keys below this value are reserved for the published vocabulary.
    const RESERVED_ATTR_KEYS: u16 = 1024;

    /// Published version of this module's interface.
    const VERSION: u64 = 1;

    /// Specified account is not an attestation source.
    const EACCOUNT_NOT_SOURCE: u64 = 1;
    /// The caller is not an admin.
    const ENOT_ADMIN: u64 = 2;
    /// The caller is not a registered, active issuer.
    const ENOT_ISSUER: u64 = 3;
    /// The caller is not a sentinel.
    const ENOT_SENTINEL: u64 = 4;
    /// The caller is not a remover.
    const ENOT_REMOVER: u64 = 5;
    /// The caller is not a guardian.
    const ENOT_GUARDIAN: u64 = 6;
    /// Writes are paused on this source.
    const EPAUSED: u64 = 7;
    /// A role list cannot contain duplicate addresses.
    const EDUPLICATE_MEMBER: u64 = 8;
    /// The source account itself cannot hold a role.
    const ESELF_CANNOT_BE_MEMBER: u64 = 9;
    /// A source must have at least one admin.
    const ENOT_ENOUGH_ADMINS: u64 = 10;
    /// Removing these admins would leave the source with zero admins.
    const EWOULD_REMOVE_ALL_ADMINS: u64 = 11;
    /// Batch argument vectors have differing lengths.
    const ELENGTH_MISMATCH: u64 = 12;
    /// The batch exceeds MAX_BATCH.
    const EBATCH_TOO_LARGE: u64 = 13;
    /// No issuer is registered under the given address or id.
    const EUNKNOWN_ISSUER: u64 = 14;
    /// An issuer is already registered under this address.
    const EDUPLICATE_ISSUER: u64 = 15;
    /// The issuer signature over the relayed attestation did not verify.
    const EBAD_SIGNATURE: u64 = 16;
    /// The attestation names an issuer epoch other than the issuer's current one.
    const ESTALE_EPOCH: u64 = 17;
    /// A newer attestation has already been recorded for this subject.
    const ENOT_MONOTONIC: u64 = 18;
    /// The subject is denied, so no positive fact may be written for it.
    const ESUBJECT_DENIED: u64 = 19;
    /// This nullifier is already bound to a different subject.
    const ENULLIFIER_BOUND: u64 = 20;
    /// No record exists for this subject.
    const ERECORD_NOT_FOUND: u64 = 21;
    /// The attribute key is in the reserved range but is not a known vocabulary key.
    const EBAD_ATTRIBUTE: u64 = 22;
    /// The provided digest, nullifier or root must be exactly 32 bytes.
    const EINVALID_BYTES_LENGTH: u64 = 23;
    /// No root has been published for the requested epoch.
    const EROOT_NOT_FOUND: u64 = 24;
    /// The record's current state does not allow this lifecycle change.
    const EINVALID_TRANSITION: u64 = 25;

    /// One entry in a subject's change history.
    struct Change has copy, drop, store {
        // Unix timestamp (seconds) of the change.
        at_secs: u64,
        // State before the change.
        prev_state: u8,
        // State after the change.
        new_state: u8,
        // Caller-supplied reason code, for the source's own vocabulary.
        reason: u16,
        // Issuer that made the change, or 0 for a zkTLS enrollment with no issuer.
        issuer_id: u16
    }

    /// What one source asserts about one subject.
    struct Record has copy, drop, store {
        state: u8,
        // Tier, 0 to 255, with meaning defined and published by the source.
        level: u8,
        // Issuer that wrote this fact, or 0 for a zkTLS enrollment.
        issuer_id: u16,
        // The issuer's epoch at the time of writing. A later bump invalidates this fact.
        issuer_epoch: u64,
        issued_at_secs: u64,
        // NEVER_EXPIRES means no expiry.
        expires_at_secs: u64,
        // Set when the state becomes STATE_REVOKED, otherwise 0.
        revoked_at_secs: u64,
        reason: u16,
        // 32 bytes identifying the attestation this fact came from, or empty for a direct write.
        attestation_digest: vector<u8>,
        attrs: SimpleMap<u16, vector<u8>>,
        history: vector<Change>
    }

    /// An exclusion. Written only by a sentinel, removed only by a remover, and unreachable from
    /// every positive write path.
    struct DenyEntry has copy, drop, store {
        reason: u16,
        // Denial takes effect at this timestamp, allowing a pre-announced effective date.
        effective_at_secs: u64,
        added_at_secs: u64
    }

    /// A published set commitment. Present for interoperability, since an EVM contract can verify
    /// the same root, and for audit, since a third party can check the published set matches the
    /// claim. It is not a storage compression device.
    struct Root has copy, drop, store {
        digest: vector<u8>,
        leaf_count: u64,
        published_at_secs: u64,
        issuer_id: u16
    }

    /// A registered issuer. `pubkey` is used only by the permissionless relay path.
    struct Issuer has copy, drop, store {
        id: u16,
        pubkey: vector<u8>,
        active: bool
    }

    /// Configuration and governance. Mutable, and deliberately never read by the check path.
    struct Source has key {
        // Addresses allowed to configure the source. Must have at least 1.
        admins: vector<address>,
        // Addresses allowed to write facts.
        issuers: vector<address>,
        // Addresses allowed to add denials only.
        sentinels: vector<address>,
        // Addresses allowed to remove denials only.
        removers: vector<address>,
        // Addresses allowed to pause and unpause writes.
        guardians: vector<address>,
        // Issuer records, keyed by address, plus the reverse index used by the relay path.
        issuer_info: Table<address, Issuer>,
        issuer_by_id: Table<u16, address>,
        next_issuer_id: u16,
        // Blocks writes only. Never consulted by is_verified. See the module doc.
        paused: bool,
        // Incremented on every published root.
        root_epoch: u64,
        roots: Table<u64, Root>,
        // Signer capability for the resource account, retained so future resources can be added.
        signer_cap: SignerCapability
    }

    /// Facts. This resource is written once at creation and never again: only its table ENTRIES
    /// change, and each entry is its own state key. That is what keeps gated transactions from
    /// conflicting with one another under Block-STM.
    struct Facts has key {
        subjects: Table<address, Record>,
        denied: Table<address, DenyEntry>,
        // One real-world identity to one subject, when the source chooses to enforce it.
        nullifiers: Table<vector<u8>, address>,
        // Per-issuer epoch, held here rather than in Source so the read path can check staleness
        // without loading mutable governance state. Written only on a bump, so in steady state
        // nothing writes it and there is no contention. After a bump the transactions that relied
        // on that issuer do re-execute, which is the intended behaviour.
        issuer_epochs: Table<u16, u64>,
        // Source-wide floor, under the single key 0. A table so that Facts itself stays immutable.
        floor_epoch: Table<u8, u64>
    }

    // =============================== Events ===============================

    #[event]
    struct CreateSource has drop, store {
        source: address,
        deployer: address,
        admins: vector<address>,
        issuers: vector<address>
    }

    #[event]
    struct AddMembers has drop, store {
        source: address,
        role: u8,
        members: vector<address>
    }

    #[event]
    struct RemoveMembers has drop, store {
        source: address,
        role: u8,
        members: vector<address>
    }

    #[event]
    struct RegisterIssuer has drop, store {
        source: address,
        issuer: address,
        id: u16
    }

    #[event]
    struct RotateIssuerKey has drop, store {
        source: address,
        id: u16
    }

    #[event]
    struct BumpIssuerEpoch has drop, store {
        source: address,
        id: u16,
        epoch: u64
    }

    #[event]
    struct SetFloorEpoch has drop, store {
        source: address,
        epoch: u64
    }

    #[event]
    struct RecordFact has drop, store {
        source: address,
        subject: address,
        state: u8,
        level: u8,
        issuer_id: u16,
        expires_at_secs: u64,
        reason: u16
    }

    #[event]
    struct SetAttribute has drop, store {
        source: address,
        subject: address,
        key: u16
    }

    #[event]
    struct PublishRoot has drop, store {
        source: address,
        epoch: u64,
        digest: vector<u8>,
        leaf_count: u64
    }

    #[event]
    struct Deny has drop, store {
        source: address,
        subject: address,
        reason: u16,
        effective_at_secs: u64
    }

    #[event]
    struct Undeny has drop, store {
        source: address,
        subject: address
    }

    #[event]
    struct SetPaused has drop, store {
        source: address,
        paused: bool
    }

    // Role discriminants, used only in events so an indexer can tell the lists apart.
    const ROLE_ADMIN: u8 = 0;
    const ROLE_ISSUER: u8 = 1;
    const ROLE_SENTINEL: u8 = 2;
    const ROLE_REMOVER: u8 = 3;
    const ROLE_GUARDIAN: u8 = 4;

    // =============================== Views ===============================

    #[view]
    /// Return the predicted address for the next source deployed by the given account. The
    /// deployer authorizes resource-account creation but gains no role unless it is listed in the
    /// role arguments to `create`.
    public fun get_next_source_address(deployer: address): address {
        let owner_nonce = account::get_sequence_number(deployer);
        create_resource_address(&deployer, create_source_seed(to_bytes(&owner_nonce)))
    }

    #[view]
    /// The single mandatory conformance function: does this source currently vouch for this
    /// subject at all. Denial, expiry and epoch staleness are all accounted for.
    public fun is_verified(source: address, subject: address): bool acquires Facts {
        let (active, _) = active_with_level(source, subject);
        active
    }

    #[view]
    /// Lifecycle state as the check path sees it, so an expired or stale record reads as
    /// STATE_NONE and a denied subject reads as STATE_REVOKED.
    public fun state_of(source: address, subject: address): u8 acquires Facts {
        let (active, _) = active_with_level(source, subject);
        if (active) {
            return STATE_ACTIVE
        };
        let facts = &Facts[source];
        if (is_denied_internal(facts, subject)) {
            return STATE_REVOKED
        };
        if (!table::contains(&facts.subjects, subject)) {
            return STATE_NONE
        };
        let record = table::borrow(&facts.subjects, subject);
        if (record.state == STATE_ACTIVE) {
            // Active but not usable, so expired or stale.
            return STATE_NONE
        };
        record.state
    }

    #[view]
    /// Tier of a currently usable fact, or 0 when there is none.
    public fun level_of(source: address, subject: address): u8 acquires Facts {
        let (_, level) = active_with_level(source, subject);
        level
    }

    /// Whether this source currently vouches for the subject, and at what level, in one pass.
    /// This is what `aptos_framework::attestation_policy` calls. Not a `#[view]` returning two
    /// values by design: callers that want one value use `is_verified` or `level_of`.
    ///
    /// Order is load-bearing. Denial is checked before anything else and cannot be overridden.
    public fun active_with_level(source: address, subject: address): (bool, u8) acquires Facts {
        assert_source_exists(source);
        let facts = &Facts[source];

        if (is_denied_internal(facts, subject)) {
            return (false, 0)
        };
        if (!table::contains(&facts.subjects, subject)) {
            return (false, 0)
        };

        let record = table::borrow(&facts.subjects, subject);
        if (record.state != STATE_ACTIVE) {
            return (false, 0)
        };
        if (record.expires_at_secs <= now_seconds()) {
            return (false, 0)
        };
        // A bump of this issuer's epoch, or a raise of the source floor, invalidates the fact.
        if (table::contains(&facts.issuer_epochs, record.issuer_id)
            && record.issuer_epoch < *table::borrow(&facts.issuer_epochs, record.issuer_id)) {
            return (false, 0)
        };
        if (record.issuer_epoch < *table::borrow(&facts.floor_epoch, 0)) {
            return (false, 0)
        };

        (true, record.level)
    }

    #[view]
    /// The full record, including history and attributes. Aborts when there is none.
    public fun record_of(source: address, subject: address): Record acquires Facts {
        assert_source_exists(source);
        let facts = &Facts[source];
        assert!(
            table::contains(&facts.subjects, subject),
            error::not_found(ERECORD_NOT_FOUND)
        );
        *table::borrow(&facts.subjects, subject)
    }

    #[view]
    /// An attribute value, or an empty vector when unset.
    public fun attribute_of(source: address, subject: address, key: u16): vector<u8> acquires Facts {
        assert_source_exists(source);
        let facts = &Facts[source];
        if (!table::contains(&facts.subjects, subject)) {
            return vector[]
        };
        let attrs = &table::borrow(&facts.subjects, subject).attrs;
        if (simple_map::contains_key(attrs, &key)) {
            *simple_map::borrow(attrs, &key)
        } else {
            vector[]
        }
    }

    #[view]
    /// Whether the subject is excluded and the exclusion is in effect now.
    public fun is_denied(source: address, subject: address): bool acquires Facts {
        assert_source_exists(source);
        is_denied_internal(&Facts[source], subject)
    }

    #[view]
    /// Reason code attached to an exclusion, or 0 when there is none.
    public fun deny_reason(source: address, subject: address): u16 acquires Facts {
        assert_source_exists(source);
        let facts = &Facts[source];
        if (table::contains(&facts.denied, subject)) {
            table::borrow(&facts.denied, subject).reason
        } else { 0 }
    }

    #[view]
    /// Expiry of the stored record, or 0 when there is none.
    public fun expires_at(source: address, subject: address): u64 acquires Facts {
        assert_source_exists(source);
        let facts = &Facts[source];
        if (table::contains(&facts.subjects, subject)) {
            table::borrow(&facts.subjects, subject).expires_at_secs
        } else { 0 }
    }

    #[view]
    /// Most recently published root.
    public fun current_root(source: address): Root acquires Source {
        assert_source_exists(source);
        let config = &Source[source];
        assert!(
            table::contains(&config.roots, config.root_epoch),
            error::not_found(EROOT_NOT_FOUND)
        );
        *table::borrow(&config.roots, config.root_epoch)
    }

    #[view]
    /// Membership of the subject in the most recently published root. OpenZeppelin shape: the
    /// subject address and the proof, with no leaf index and no commitment argument.
    public fun verify_membership(
        source: address, subject: address, proof: vector<vector<u8>>
    ): bool acquires Source {
        let root = current_root(source);
        aptos_framework::merkle_proof::verify(
            root.digest,
            aptos_framework::merkle_proof::subject_leaf(source, subject),
            proof
        )
    }

    #[view]
    public fun admins(source: address): vector<address> acquires Source {
        assert_source_exists(source);
        Source[source].admins
    }

    #[view]
    public fun issuers(source: address): vector<address> acquires Source {
        assert_source_exists(source);
        Source[source].issuers
    }

    #[view]
    public fun sentinels(source: address): vector<address> acquires Source {
        assert_source_exists(source);
        Source[source].sentinels
    }

    #[view]
    public fun removers(source: address): vector<address> acquires Source {
        assert_source_exists(source);
        Source[source].removers
    }

    #[view]
    public fun guardians(source: address): vector<address> acquires Source {
        assert_source_exists(source);
        Source[source].guardians
    }

    #[view]
    public fun is_admin(addr: address, source: address): bool acquires Source {
        assert_source_exists(source);
        Source[source].admins.contains(&addr)
    }

    #[view]
    public fun is_issuer(addr: address, source: address): bool acquires Source {
        assert_source_exists(source);
        Source[source].issuers.contains(&addr)
    }

    #[view]
    /// Stable id assigned to an issuer at registration. Aborts when unregistered.
    public fun issuer_id_of(source: address, issuer: address): u16 acquires Source {
        assert_source_exists(source);
        let config = &Source[source];
        assert!(
            table::contains(&config.issuer_info, issuer),
            error::not_found(EUNKNOWN_ISSUER)
        );
        table::borrow(&config.issuer_info, issuer).id
    }

    #[view]
    /// Effective epoch of an issuer: the larger of its own counter and the source floor. Facts
    /// written below it are no longer usable, and new writes by that issuer are stamped with it.
    /// Issuer id 0 is the zkTLS enrollment cohort, which has no registered issuer.
    public fun issuer_epoch_of(source: address, issuer_id: u16): u64 acquires Facts {
        assert_source_exists(source);
        let facts = &Facts[source];
        let own =
            if (table::contains(&facts.issuer_epochs, issuer_id)) {
                *table::borrow(&facts.issuer_epochs, issuer_id)
            } else { 0 };
        let floor = *table::borrow(&facts.floor_epoch, 0);
        if (own > floor) { own } else { floor }
    }

    #[view]
    public fun floor_epoch(source: address): u64 acquires Facts {
        assert_source_exists(source);
        *table::borrow(&Facts[source].floor_epoch, 0)
    }

    #[view]
    public fun is_paused(source: address): bool acquires Source {
        assert_source_exists(source);
        Source[source].paused
    }

    #[view]
    /// Whether an address is an attestation source. Consulted by `attestation_policy` at staging
    /// time, so a policy cannot be configured to name a source that does not exist and then abort
    /// for every subject at evaluation time.
    public fun is_source(source: address): bool {
        exists<Source>(source) && exists<Facts>(source)
    }

    #[view]
    public fun standard_version(): u64 {
        VERSION
    }

    #[view]
    /// The message an issuer signs for the permissionless relay path. Published so an issuing
    /// service can be implemented in any language without reading this module.
    public fun attestation_message(
        source: address,
        subject: address,
        issuer_id: u16,
        issuer_epoch: u64,
        level: u8,
        expires_at_secs: u64,
        issued_at_secs: u64,
        nullifier: vector<u8>
    ): vector<u8> {
        let message = vector[];
        message.append(DOMAIN_ATTESTATION);
        message.append(to_bytes(&chain_id::get()));
        message.append(to_bytes(&source));
        message.append(to_bytes(&subject));
        message.append(to_bytes(&issuer_id));
        message.append(to_bytes(&issuer_epoch));
        message.append(to_bytes(&level));
        message.append(to_bytes(&expires_at_secs));
        message.append(to_bytes(&issued_at_secs));
        message.append(to_bytes(&nullifier));
        message
    }

    // =============================== Source creation ===============================

    /// Create a new attestation source. The deployer only authorizes resource-account creation and
    /// pays gas; it gains no role unless listed in the role arguments.
    ///
    /// @param deployer Signer that authorizes resource-account creation and pays gas.
    /// @param admins Addresses allowed to configure. At least one, no duplicates, not the source.
    /// @param issuers Addresses allowed to write facts. May be empty and filled in later.
    /// @param sentinels Addresses allowed to add denials only. May be empty.
    /// @param removers Addresses allowed to remove denials only. May be empty.
    /// @param guardians Addresses allowed to pause writes. May be empty.
    /// @abort If a list has duplicates, names the source itself, or there is no admin.
    public entry fun create(
        deployer: &signer,
        admins: vector<address>,
        issuers: vector<address>,
        sentinels: vector<address>,
        removers: vector<address>,
        guardians: vector<address>
    ) {
        let (source_signer, source_signer_cap) = create_source_account(deployer);
        create_source_internal(
            &source_signer,
            address_of(deployer),
            admins,
            issuers,
            sentinels,
            removers,
            guardians,
            source_signer_cap
        );
    }

    fun create_source_internal(
        source_account: &signer,
        deployer: address,
        admins: vector<address>,
        issuers: vector<address>,
        sentinels: vector<address>,
        removers: vector<address>,
        guardians: vector<address>,
        signer_cap: SignerCapability
    ) {
        let source_address = address_of(source_account);
        assert!(admins.length() >= 1, error::invalid_argument(ENOT_ENOUGH_ADMINS));
        validate_members(&admins, source_address);
        validate_members(&issuers, source_address);
        validate_members(&sentinels, source_address);
        validate_members(&removers, source_address);
        validate_members(&guardians, source_address);

        let floor_epoch = table::new<u8, u64>();
        table::add(&mut floor_epoch, 0, 0);

        move_to(
            source_account,
            Source {
                admins,
                issuers,
                sentinels,
                removers,
                guardians,
                issuer_info: table::new<address, Issuer>(),
                issuer_by_id: table::new<u16, address>(),
                next_issuer_id: 1,
                paused: false,
                root_epoch: 0,
                roots: table::new<u64, Root>(),
                signer_cap
            }
        );
        move_to(
            source_account,
            Facts {
                subjects: table::new<address, Record>(),
                denied: table::new<address, DenyEntry>(),
                nullifiers: table::new<vector<u8>, address>(),
                issuer_epochs: table::new<u16, u64>(),
                floor_epoch
            }
        );

        emit(CreateSource { source: source_address, deployer, admins, issuers });
    }

    // =============================== Role management ===============================
    // Every function here requires an admin. An admin may itself be a `timelock` account, in which
    // case these calls inherit that module's delay and cancel semantics for free.

    /// Add admins.
    public entry fun add_admins(
        admin: &signer, source: address, new_admins: vector<address>
    ) acquires Source {
        assert_admin(source, address_of(admin));
        let config = &mut Source[source];
        add_members(&mut config.admins, &new_admins, source);
        emit(AddMembers { source, role: ROLE_ADMIN, members: new_admins });
    }

    /// Remove admins. A source may never be left with zero admins.
    public entry fun remove_admins(
        admin: &signer, source: address, old_admins: vector<address>
    ) acquires Source {
        assert_admin(source, address_of(admin));
        let config = &mut Source[source];
        remove_members(&mut config.admins, &old_admins);
        assert!(
            config.admins.length() >= 1,
            error::invalid_state(EWOULD_REMOVE_ALL_ADMINS)
        );
        emit(RemoveMembers { source, role: ROLE_ADMIN, members: old_admins });
    }

    public entry fun add_issuers(
        admin: &signer, source: address, new_issuers: vector<address>
    ) acquires Source {
        assert_admin(source, address_of(admin));
        let config = &mut Source[source];
        add_members(&mut config.issuers, &new_issuers, source);
        emit(AddMembers { source, role: ROLE_ISSUER, members: new_issuers });
    }

    public entry fun remove_issuers(
        admin: &signer, source: address, old_issuers: vector<address>
    ) acquires Source {
        assert_admin(source, address_of(admin));
        let config = &mut Source[source];
        remove_members(&mut config.issuers, &old_issuers);
        emit(RemoveMembers { source, role: ROLE_ISSUER, members: old_issuers });
    }

    public entry fun add_sentinels(
        admin: &signer, source: address, new_sentinels: vector<address>
    ) acquires Source {
        assert_admin(source, address_of(admin));
        let config = &mut Source[source];
        add_members(&mut config.sentinels, &new_sentinels, source);
        emit(AddMembers { source, role: ROLE_SENTINEL, members: new_sentinels });
    }

    public entry fun remove_sentinels(
        admin: &signer, source: address, old_sentinels: vector<address>
    ) acquires Source {
        assert_admin(source, address_of(admin));
        let config = &mut Source[source];
        remove_members(&mut config.sentinels, &old_sentinels);
        emit(RemoveMembers { source, role: ROLE_SENTINEL, members: old_sentinels });
    }

    public entry fun add_removers(
        admin: &signer, source: address, new_removers: vector<address>
    ) acquires Source {
        assert_admin(source, address_of(admin));
        let config = &mut Source[source];
        add_members(&mut config.removers, &new_removers, source);
        emit(AddMembers { source, role: ROLE_REMOVER, members: new_removers });
    }

    public entry fun remove_removers(
        admin: &signer, source: address, old_removers: vector<address>
    ) acquires Source {
        assert_admin(source, address_of(admin));
        let config = &mut Source[source];
        remove_members(&mut config.removers, &old_removers);
        emit(RemoveMembers { source, role: ROLE_REMOVER, members: old_removers });
    }

    public entry fun add_guardians(
        admin: &signer, source: address, new_guardians: vector<address>
    ) acquires Source {
        assert_admin(source, address_of(admin));
        let config = &mut Source[source];
        add_members(&mut config.guardians, &new_guardians, source);
        emit(AddMembers { source, role: ROLE_GUARDIAN, members: new_guardians });
    }

    public entry fun remove_guardians(
        admin: &signer, source: address, old_guardians: vector<address>
    ) acquires Source {
        assert_admin(source, address_of(admin));
        let config = &mut Source[source];
        remove_members(&mut config.guardians, &old_guardians);
        emit(RemoveMembers { source, role: ROLE_GUARDIAN, members: old_guardians });
    }

    /// Pause writes. Never changes the answer `is_verified` gives.
    public entry fun pause(guardian: &signer, source: address) acquires Source {
        set_paused(guardian, source, true);
    }

    public entry fun unpause(guardian: &signer, source: address) acquires Source {
        set_paused(guardian, source, false);
    }

    fun set_paused(guardian: &signer, source: address, paused: bool) acquires Source {
        assert_source_exists(source);
        assert!(
            Source[source].guardians.contains(&address_of(guardian)),
            error::permission_denied(ENOT_GUARDIAN)
        );
        Source[source].paused = paused;
        emit(SetPaused { source, paused });
    }

    // =============================== Issuer management ===============================

    /// Register an issuer and assign it a stable id. The public key is used only by the
    /// permissionless relay path, and may be empty for an issuer that only writes directly.
    ///
    /// @param admin An admin of the source.
    /// @param source The source address.
    /// @param issuer Address to register.
    /// @param pubkey 32-byte ed25519 public key, or empty.
    /// @abort If the issuer is already registered or the key length is wrong.
    public entry fun register_issuer(
        admin: &signer, source: address, issuer: address, pubkey: vector<u8>
    ) acquires Source, Facts {
        assert_admin(source, address_of(admin));
        assert!(
            pubkey.is_empty() || pubkey.length() == PUBKEY_LENGTH,
            error::invalid_argument(EINVALID_BYTES_LENGTH)
        );
        let config = &mut Source[source];
        assert!(
            !table::contains(&config.issuer_info, issuer),
            error::already_exists(EDUPLICATE_ISSUER)
        );
        let id = config.next_issuer_id;
        config.next_issuer_id = id + 1;
        table::add(&mut config.issuer_info, issuer, Issuer { id, pubkey, active: true });
        table::add(&mut config.issuer_by_id, id, issuer);
        if (!config.issuers.contains(&issuer)) {
            config.issuers.push_back(issuer);
        };
        table::add(&mut Facts[source].issuer_epochs, id, 0);
        emit(RegisterIssuer { source, issuer, id });
    }

    /// Replace an issuer's signing key. Facts already written stay valid; use
    /// `bump_issuer_epoch` to invalidate them.
    public entry fun rotate_issuer_key(
        admin: &signer, source: address, issuer: address, new_pubkey: vector<u8>
    ) acquires Source {
        assert_admin(source, address_of(admin));
        assert!(
            new_pubkey.is_empty() || new_pubkey.length() == PUBKEY_LENGTH,
            error::invalid_argument(EINVALID_BYTES_LENGTH)
        );
        let config = &mut Source[source];
        assert!(
            table::contains(&config.issuer_info, issuer),
            error::not_found(EUNKNOWN_ISSUER)
        );
        let info = table::borrow_mut(&mut config.issuer_info, issuer);
        info.pubkey = new_pubkey;
        emit(RotateIssuerKey { source, id: info.id });
    }

    /// Invalidate every fact an issuer has written, in one write. This is the remedy for a
    /// compromised issuer key and it is O(1) in the size of the cohort. Issuer id 0 bumps the
    /// zkTLS enrollment cohort, which has no registered issuer. The new epoch is one above the
    /// issuer's effective epoch, so a bump always takes effect even below a raised floor.
    public entry fun bump_issuer_epoch(
        admin: &signer, source: address, issuer_id: u16
    ) acquires Source, Facts {
        assert_admin(source, address_of(admin));
        assert!(
            issuer_id == 0 || table::contains(&Source[source].issuer_by_id, issuer_id),
            error::not_found(EUNKNOWN_ISSUER)
        );
        let epoch = issuer_epoch_of(source, issuer_id) + 1;
        table::upsert(&mut Facts[source].issuer_epochs, issuer_id, epoch);
        emit(BumpIssuerEpoch { source, id: issuer_id, epoch });
    }

    /// Invalidate every fact written below the given epoch, across all issuers including the zkTLS
    /// cohort. Strictly increasing, so lowering the floor can never resurrect a fact.
    public entry fun set_floor_epoch(
        admin: &signer, source: address, epoch: u64
    ) acquires Source, Facts {
        assert_admin(source, address_of(admin));
        let floor = table::borrow_mut(&mut Facts[source].floor_epoch, 0);
        assert!(epoch > *floor, error::invalid_argument(ENOT_MONOTONIC));
        *floor = epoch;
        emit(SetFloorEpoch { source, epoch });
    }

    // =============================== Write path 1: issuer batch ===============================
    // The only path that can be seeded at genesis and grandfathered across an existing population
    // with no action from the subjects.

    /// Record or refresh facts for many subjects at once.
    ///
    /// @param issuer A registered, active issuer of the source.
    /// @param source The source address.
    /// @param subjects Subjects to write.
    /// @param levels Tier per subject, same length as `subjects`.
    /// @param expires_at_secs Expiry per subject, same length as `subjects`.
    /// @param reason Reason code recorded in each subject's history.
    /// @abort If paused, the caller is not an issuer, the lengths differ, the batch is too large,
    ///        or any subject is denied.
    public entry fun issue_batch(
        issuer: &signer,
        source: address,
        subjects: vector<address>,
        levels: vector<u8>,
        expires_at_secs: vector<u64>,
        reason: u16
    ) acquires Source, Facts {
        let count = subjects.length();
        assert!(count <= MAX_BATCH, error::invalid_argument(EBATCH_TOO_LARGE));
        assert!(
            count == levels.length() && count == expires_at_secs.length(),
            error::invalid_argument(ELENGTH_MISMATCH)
        );
        let (issuer_id, issuer_epoch) = assert_issuer(source, address_of(issuer));
        let index = 0;
        while (index < count) {
            record_fact(
                source,
                subjects[index],
                STATE_ACTIVE,
                levels[index],
                issuer_id,
                issuer_epoch,
                expires_at_secs[index],
                now_seconds(),
                reason,
                vector[]
            );
            index += 1;
        };
    }

    /// Move many subjects to STATE_REVOKED. A subject that is already revoked is skipped, so one
    /// stale entry cannot brick a batch.
    public entry fun revoke_batch(
        issuer: &signer, source: address, subjects: vector<address>, reason: u16
    ) acquires Source, Facts {
        let count = subjects.length();
        assert!(count <= MAX_BATCH, error::invalid_argument(EBATCH_TOO_LARGE));
        let (issuer_id, _) = assert_issuer(source, address_of(issuer));
        let index = 0;
        while (index < count) {
            transition(source, subjects[index], STATE_REVOKED, issuer_id, reason);
            index += 1;
        };
    }

    /// Temporarily withhold an active subject's fact, reversibly.
    public entry fun suspend(
        issuer: &signer, source: address, subject: address, reason: u16
    ) acquires Source, Facts {
        let (issuer_id, _) = assert_issuer(source, address_of(issuer));
        transition(source, subject, STATE_SUSPENDED, issuer_id, reason);
    }

    /// Reverse a suspension. Only a suspended record can be reactivated: a revoked one needs
    /// re-issuance, and a denied subject cannot be reactivated at all. The record keeps the issuer
    /// and epoch it was issued under, so a fact killed by an epoch bump stays dead.
    public entry fun unsuspend(
        issuer: &signer, source: address, subject: address, reason: u16
    ) acquires Source, Facts {
        let (issuer_id, _) = assert_issuer(source, address_of(issuer));
        transition(source, subject, STATE_ACTIVE, issuer_id, reason);
    }

    /// Set an attribute on a subject. Every attribute written is public forever, so a source that
    /// writes jurisdiction data has made a disclosure decision on behalf of its subjects.
    public entry fun set_attribute(
        issuer: &signer, source: address, subject: address, key: u16, value: vector<u8>
    ) acquires Source, Facts {
        assert_not_paused(source);
        assert_issuer(source, address_of(issuer));
        let facts = &mut Facts[source];
        assert!(
            table::contains(&facts.subjects, subject),
            error::not_found(ERECORD_NOT_FOUND)
        );
        let record = table::borrow_mut(&mut facts.subjects, subject);
        if (simple_map::contains_key(&record.attrs, &key)) {
            *simple_map::borrow_mut(&mut record.attrs, &key) = value;
        } else {
            assert!(
                simple_map::length(&record.attrs) < MAX_ATTRS,
                error::invalid_state(EBAD_ATTRIBUTE)
            );
            simple_map::add(&mut record.attrs, key, value);
        };
        emit(SetAttribute { source, subject, key });
    }

    public entry fun remove_attribute(
        issuer: &signer, source: address, subject: address, key: u16
    ) acquires Source, Facts {
        assert_not_paused(source);
        assert_issuer(source, address_of(issuer));
        let facts = &mut Facts[source];
        assert!(
            table::contains(&facts.subjects, subject),
            error::not_found(ERECORD_NOT_FOUND)
        );
        let record = table::borrow_mut(&mut facts.subjects, subject);
        if (simple_map::contains_key(&record.attrs, &key)) {
            simple_map::remove(&mut record.attrs, &key);
        };
    }

    // ====================== Write path 2: permissionless relay ======================
    // Anyone submits, the chain verifies the issuer's signature, and the submitter pays. This is
    // what keeps the issuer's writer service off the liveness path.

    /// Record a fact from an attestation the issuer signed off chain. The caller need not be the
    /// subject or the issuer.
    ///
    /// @param source The source address.
    /// @param subject Subject the attestation is about.
    /// @param issuer_id Issuer that signed.
    /// @param issuer_epoch Must equal the issuer's current epoch, so an attestation signed before
    ///        a compromise bump is refused and one signed for a future epoch is too.
    /// @param nullifier 32 bytes binding one real-world identity to one subject, or empty to skip.
    /// @param signature 64-byte ed25519 signature over `attestation_message`.
    /// @abort If paused, the epoch is stale, the signature fails, a newer attestation is already
    ///        recorded, the nullifier is bound elsewhere, or the subject is denied.
    public entry fun redeem_attestation(
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
    ) acquires Source, Facts {
        assert_not_paused(source);
        let config = &Source[source];
        assert!(
            table::contains(&config.issuer_by_id, issuer_id),
            error::not_found(EUNKNOWN_ISSUER)
        );
        let issuer_address = *table::borrow(&config.issuer_by_id, issuer_id);
        // Same rule as assert_issuer: removing an issuer's role also stops its relayed
        // attestations.
        assert!(
            config.issuers.contains(&issuer_address),
            error::permission_denied(ENOT_ISSUER)
        );
        let info = table::borrow(&config.issuer_info, issuer_address);
        assert!(info.active, error::invalid_state(EUNKNOWN_ISSUER));
        assert!(
            info.pubkey.length() == PUBKEY_LENGTH,
            error::invalid_state(EUNKNOWN_ISSUER)
        );

        // Equality, not "at least": refuse an epoch the issuer has not entered, and refuse one
        // signed before a bump.
        assert!(
            issuer_epoch == issuer_epoch_of(source, issuer_id),
            error::invalid_state(ESTALE_EPOCH)
        );

        let message =
            attestation_message(
                source,
                subject,
                issuer_id,
                issuer_epoch,
                level,
                expires_at_secs,
                issued_at_secs,
                nullifier
            );
        assert!(
            ed25519::signature_verify_strict(
                &ed25519::new_signature_from_bytes(signature),
                &ed25519::new_unvalidated_public_key_from_bytes(info.pubkey),
                message
            ),
            error::invalid_argument(EBAD_SIGNATURE)
        );

        // Monotonicity: a kept attestation must not be replayable to push an expiry back out.
        assert_newer(source, subject, issued_at_secs);
        bind_nullifier(source, subject, nullifier);

        record_fact(
            source,
            subject,
            STATE_ACTIVE,
            level,
            issuer_id,
            issuer_epoch,
            expires_at_secs,
            issued_at_secs,
            0,
            std::aptos_hash::keccak256(message)
        );
    }

    // ====================== Write path 3: zkTLS enrollment ======================

    /// Return a signer for the source's resource account. Restricted to the `friend` list, which
    /// is the security boundary: `zktls` needs it to store its attestor set and template
    /// allowlist under the source address. Nothing outside the friend list can obtain it.
    public(friend) fun source_signer(source: address): signer acquires Source {
        assert_source_exists(source);
        account::create_signer_with_capability(&Source[source].signer_cap)
    }

    /// Record a fact from a claim `aptos_framework::zktls` has already verified against its
    /// attestor set. No issuer key is involved on this path at all.
    public(friend) fun record_verified_claim(
        source: address,
        subject: address,
        level: u8,
        expires_at_secs: u64,
        attestation_digest: vector<u8>,
        nullifier: vector<u8>
    ) acquires Source, Facts {
        assert_not_paused(source);
        assert!(
            attestation_digest.length() == DIGEST_LENGTH,
            error::invalid_argument(EINVALID_BYTES_LENGTH)
        );
        bind_nullifier(source, subject, nullifier);
        // Issuer id 0 is the zkTLS cohort, stamped with its effective epoch so a raised floor does
        // not silently kill new enrollments and a bump of id 0 kills the whole cohort.
        let cohort_epoch = issuer_epoch_of(source, 0);
        record_fact(
            source,
            subject,
            STATE_ACTIVE,
            level,
            0,
            cohort_epoch,
            expires_at_secs,
            now_seconds(),
            0,
            attestation_digest
        );
    }

    // =============================== Write path 4: exclusion ===============================
    // A separate role, a separate table, evaluated before everything else, and unreachable from
    // every positive write path.

    /// Exclude a subject. Takes effect at `effective_at_secs`, which may be in the future so a
    /// denial can be announced before it bites.
    public entry fun deny(
        sentinel: &signer,
        source: address,
        subject: address,
        reason: u16,
        effective_at_secs: u64
    ) acquires Source, Facts {
        assert_source_exists(source);
        assert!(
            Source[source].sentinels.contains(&address_of(sentinel)),
            error::permission_denied(ENOT_SENTINEL)
        );
        deny_internal(source, subject, reason, effective_at_secs);
    }

    /// Exclude many subjects at once, with a shared reason and immediate effect.
    public entry fun deny_batch(
        sentinel: &signer, source: address, subjects: vector<address>, reason: u16
    ) acquires Source, Facts {
        assert_source_exists(source);
        assert!(
            Source[source].sentinels.contains(&address_of(sentinel)),
            error::permission_denied(ENOT_SENTINEL)
        );
        let count = subjects.length();
        assert!(count <= MAX_BATCH, error::invalid_argument(EBATCH_TOO_LARGE));
        let index = 0;
        let now = now_seconds();
        while (index < count) {
            deny_internal(source, subjects[index], reason, now);
            index += 1;
        };
    }

    /// Remove an exclusion. Deliberately a different role from `deny`.
    public entry fun undeny(
        remover: &signer, source: address, subject: address
    ) acquires Source, Facts {
        assert_source_exists(source);
        assert!(
            Source[source].removers.contains(&address_of(remover)),
            error::permission_denied(ENOT_REMOVER)
        );
        let denied = &mut Facts[source].denied;
        if (table::contains(denied, subject)) {
            table::remove(denied, subject);
            emit(Undeny { source, subject });
        };
    }

    fun deny_internal(
        source: address, subject: address, reason: u16, effective_at_secs: u64
    ) acquires Facts {
        // upsert, never add: a repeated denial must be idempotent rather than abort a batch.
        table::upsert(
            &mut Facts[source].denied,
            subject,
            DenyEntry { reason, effective_at_secs, added_at_secs: now_seconds() }
        );
        emit(Deny { source, subject, reason, effective_at_secs });
    }

    // =============================== Roots ===============================

    /// Publish a set commitment for the next epoch. Rotation invalidates outstanding proofs, so
    /// publish on a fixed low-frequency cadence: it is a privacy measure, because cohort timing
    /// leaks, and a throughput one, because every gated transaction reads this slot.
    public entry fun publish_root(
        issuer: &signer, source: address, digest: vector<u8>, leaf_count: u64
    ) acquires Source, Facts {
        assert!(
            digest.length() == DIGEST_LENGTH,
            error::invalid_argument(EINVALID_BYTES_LENGTH)
        );
        let (issuer_id, _) = assert_issuer(source, address_of(issuer));
        let config = &mut Source[source];
        let epoch = config.root_epoch + 1;
        config.root_epoch = epoch;
        table::add(
            &mut config.roots,
            epoch,
            Root { digest, leaf_count, published_at_secs: now_seconds(), issuer_id }
        );
        emit(PublishRoot { source, epoch, digest, leaf_count });
    }

    // =============================== The write funnel ===============================
    // Every path above ends here, so precedence and the invariants live in one place.

    fun record_fact(
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
    ) acquires Facts {
        let now = now_seconds();
        let facts = &mut Facts[source];

        // A positive write can never overwrite, clear or ignore an exclusion.
        assert!(
            !table::contains(&facts.denied, subject),
            error::invalid_state(ESUBJECT_DENIED)
        );

        let subjects = &mut facts.subjects;
        if (table::contains(subjects, subject)) {
            let record = table::borrow_mut(subjects, subject);
            let change = Change {
                at_secs: now,
                prev_state: record.state,
                new_state: state,
                reason,
                issuer_id
            };
            record.state = state;
            record.level = level;
            record.issuer_id = issuer_id;
            record.issuer_epoch = issuer_epoch;
            record.expires_at_secs = expires_at_secs;
            record.issued_at_secs = issued_at_secs;
            record.reason = reason;
            record.attestation_digest = attestation_digest;
            if (state == STATE_REVOKED) {
                record.revoked_at_secs = now;
            };
            push_history(&mut record.history, change);
        } else {
            table::add(
                subjects,
                subject,
                Record {
                    state,
                    level,
                    issuer_id,
                    issuer_epoch,
                    issued_at_secs,
                    expires_at_secs,
                    revoked_at_secs: if (state == STATE_REVOKED) { now } else { 0 },
                    reason,
                    attestation_digest,
                    attrs: simple_map::create<u16, vector<u8>>(),
                    history: vector[
                        Change {
                            at_secs: now,
                            prev_state: STATE_NONE,
                            new_state: state,
                            reason,
                            issuer_id
                        }
                    ]
                }
            );
        };

        emit(RecordFact { source, subject, state, level, issuer_id, expires_at_secs, reason });
    }

    /// Change the state of an existing record. Used by revoke, suspend and unsuspend, all of which
    /// must not silently create a record. The record keeps the issuer id and epoch it was issued
    /// under, because validity comes from the original issuance; the acting issuer is recorded in
    /// the history entry only.
    ///
    /// Allowed: ACTIVE to SUSPENDED, SUSPENDED to ACTIVE, and ACTIVE or SUSPENDED to REVOKED.
    /// Revoking an already revoked record is a silent no-op so a batch is not bricked by one entry.
    fun transition(
        source: address,
        subject: address,
        state: u8,
        acting_issuer_id: u16,
        reason: u16
    ) acquires Facts {
        let now = now_seconds();
        let facts = &mut Facts[source];
        assert!(
            table::contains(&facts.subjects, subject),
            error::not_found(ERECORD_NOT_FOUND)
        );
        let denied = table::contains(&facts.denied, subject);
        let record = table::borrow_mut(&mut facts.subjects, subject);
        let prev_state = record.state;
        if (state == STATE_REVOKED) {
            if (prev_state == STATE_REVOKED) {
                return
            };
            assert!(
                prev_state == STATE_ACTIVE || prev_state == STATE_SUSPENDED,
                error::invalid_state(EINVALID_TRANSITION)
            );
        } else if (state == STATE_SUSPENDED) {
            assert!(
                prev_state == STATE_ACTIVE,
                error::invalid_state(EINVALID_TRANSITION)
            );
        } else {
            assert!(
                state == STATE_ACTIVE && prev_state == STATE_SUSPENDED,
                error::invalid_state(EINVALID_TRANSITION)
            );
            // Reactivation is a positive write, so it obeys the same exclusion rule as record_fact.
            assert!(!denied, error::invalid_state(ESUBJECT_DENIED));
        };
        let change = Change {
            at_secs: now,
            prev_state,
            new_state: state,
            reason,
            issuer_id: acting_issuer_id
        };
        record.state = state;
        record.reason = reason;
        if (state == STATE_REVOKED) {
            record.revoked_at_secs = now;
        };
        push_history(&mut record.history, change);
        emit(
            RecordFact {
                source,
                subject,
                state,
                level: record.level,
                issuer_id: acting_issuer_id,
                expires_at_secs: record.expires_at_secs,
                reason
            }
        );
    }

    // =============================== Helpers ===============================

    fun create_source_account(deployer: &signer): (signer, SignerCapability) {
        let deployer_nonce = account::get_sequence_number(address_of(deployer));
        account::create_resource_account(
            deployer, create_source_seed(to_bytes(&deployer_nonce))
        )
    }

    fun create_source_seed(seed: vector<u8>): vector<u8> {
        let account_seed = vector[];
        account_seed.append(DOMAIN_SEPARATOR);
        account_seed.append(seed);
        account_seed
    }

    /// Validate that a role list has no duplicates and does not name the source itself.
    fun validate_members(members: &vector<address>, source_address: address) {
        let distinct: vector<address> = vector[];
        members.for_each_ref(|member| {
            assert!(
                *member != source_address,
                error::invalid_argument(ESELF_CANNOT_BE_MEMBER)
            );
            assert!(
                !distinct.contains(member),
                error::invalid_argument(EDUPLICATE_MEMBER)
            );
            distinct.push_back(*member);
        });
    }

    fun add_members(
        list: &mut vector<address>, new_members: &vector<address>, source_address: address
    ) {
        validate_members(new_members, source_address);
        new_members.for_each_ref(|member| {
            assert!(
                !list.contains(member),
                error::invalid_argument(EDUPLICATE_MEMBER)
            );
            list.push_back(*member);
        });
    }

    fun remove_members(list: &mut vector<address>, old_members: &vector<address>) {
        old_members.for_each_ref(|member| {
            let (found, index) = list.index_of(member);
            if (found) {
                list.remove(index);
            };
        });
    }

    fun push_history(history: &mut vector<Change>, change: Change) {
        if (history.length() >= MAX_HISTORY) {
            history.remove(0);
        };
        history.push_back(change);
    }

    fun bind_nullifier(
        source: address, subject: address, nullifier: vector<u8>
    ) acquires Facts {
        if (nullifier.is_empty()) {
            return
        };
        assert!(
            nullifier.length() == DIGEST_LENGTH,
            error::invalid_argument(EINVALID_BYTES_LENGTH)
        );
        let nullifiers = &mut Facts[source].nullifiers;
        if (table::contains(nullifiers, nullifier)) {
            assert!(
                *table::borrow(nullifiers, nullifier) == subject,
                error::invalid_state(ENULLIFIER_BOUND)
            );
        } else {
            table::add(nullifiers, nullifier, subject);
        };
    }

    fun assert_newer(
        source: address, subject: address, issued_at_secs: u64
    ) acquires Facts {
        let subjects = &Facts[source].subjects;
        if (table::contains(subjects, subject)) {
            assert!(
                issued_at_secs > table::borrow(subjects, subject).issued_at_secs,
                error::invalid_argument(ENOT_MONOTONIC)
            );
        };
    }

    fun is_denied_internal(facts: &Facts, subject: address): bool {
        table::contains(&facts.denied, subject)
            && now_seconds() >= table::borrow(&facts.denied, subject).effective_at_secs
    }

    fun assert_source_exists(source: address) {
        assert!(exists<Source>(source), error::not_found(EACCOUNT_NOT_SOURCE));
        assert!(exists<Facts>(source), error::not_found(EACCOUNT_NOT_SOURCE));
    }

    fun assert_admin(source: address, addr: address) acquires Source {
        assert_source_exists(source);
        assert!(
            Source[source].admins.contains(&addr),
            error::permission_denied(ENOT_ADMIN)
        );
    }

    fun assert_not_paused(source: address) acquires Source {
        assert_source_exists(source);
        assert!(!Source[source].paused, error::invalid_state(EPAUSED));
    }

    /// Assert the caller is a registered, active issuer and return its id and current epoch.
    fun assert_issuer(source: address, addr: address): (u16, u64) acquires Source, Facts {
        assert_not_paused(source);
        let config = &Source[source];
        assert!(
            config.issuers.contains(&addr) && table::contains(&config.issuer_info, addr),
            error::permission_denied(ENOT_ISSUER)
        );
        let info = table::borrow(&config.issuer_info, addr);
        assert!(info.active, error::permission_denied(ENOT_ISSUER));
        (info.id, issuer_epoch_of(source, info.id))
    }

    // =============================== Tests ===============================

    #[test_only]
    use std::account::create_account_for_test;
    #[test_only]
    use std::timestamp;

    #[test_only]
    const SUBJECT_A: address = @0xa11;
    #[test_only]
    const SUBJECT_B: address = @0xb22;
    #[test_only]
    const SUBJECT_C: address = @0xc33;
    #[test_only]
    const NULLIFIER: vector<u8> = x"1111111111111111111111111111111111111111111111111111111111111111";
    #[test_only]
    const NULLIFIER_2: vector<u8> = x"2222222222222222222222222222222222222222222222222222222222222222";
    #[test_only]
    const ROOT: vector<u8> = x"0573ec1d2c71abd9d936aca283796fc8a9fbaddc3266ecd0c390aa1106c3df3f";
    #[test_only]
    const ONE_YEAR: u64 = 31536000;
    #[test_only]
    const LEVEL_BASIC: u8 = 1;
    #[test_only]
    const LEVEL_ENHANCED: u8 = 2;

    #[test_only]
    fun setup(framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        chain_id::initialize_for_test(framework, 4);
    }

    // Create a source whose deployer holds every role, which is the shape most tests want.
    #[test_only]
    fun create_for_test(deployer: &signer): address {
        let deployer_address = address_of(deployer);
        create_account_for_test(deployer_address);
        let source = get_next_source_address(deployer_address);
        create(
            deployer,
            vector[deployer_address],
            vector[],
            vector[deployer_address],
            vector[deployer_address],
            vector[deployer_address]
        );
        source
    }

    #[test_only]
    fun expiry() : u64 {
        now_seconds() + ONE_YEAR
    }

    // --- Creation ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_create(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let deployer_address = address_of(deployer);
        create_account_for_test(deployer_address);
        let predicted = get_next_source_address(deployer_address);
        create(deployer, vector[deployer_address], vector[], vector[], vector[], vector[]);

        // The predicted address is where the source actually landed, so a client can derive it.
        assert!(admins(predicted) == vector[deployer_address], 0);
        assert!(issuers(predicted) == vector[], 1);
        assert!(!is_paused(predicted), 2);
        assert!(floor_epoch(predicted) == 0, 3);
        // The deployer gains no role it was not listed for.
        assert!(!is_issuer(deployer_address, predicted), 4);
        // No subject is verified in a fresh source.
        assert!(!is_verified(predicted, SUBJECT_A), 5);
        assert!(state_of(predicted, SUBJECT_A) == STATE_NONE, 6);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x1000A, location = Self)]
    fun test_create_without_admin_fails(framework: &signer, deployer: &signer) {
        setup(framework);
        create_account_for_test(address_of(deployer));
        create(deployer, vector[], vector[], vector[], vector[], vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x10008, location = Self)]
    fun test_create_with_duplicate_admin_fails(framework: &signer, deployer: &signer) {
        setup(framework);
        let deployer_address = address_of(deployer);
        create_account_for_test(deployer_address);
        create(
            deployer,
            vector[deployer_address, deployer_address],
            vector[],
            vector[],
            vector[],
            vector[]
        );
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x3000B, location = Self)]
    fun test_cannot_remove_last_admin(framework: &signer, deployer: &signer) acquires Source {
        setup(framework);
        let source = create_for_test(deployer);
        remove_admins(deployer, source, vector[address_of(deployer)]);
    }

    // --- Issuing ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_issue_and_read(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        let issuer_address = address_of(deployer);
        register_issuer(deployer, source, issuer_address, vector[]);
        assert!(issuer_id_of(source, issuer_address) == 1, 0);

        issue_batch(
            deployer,
            source,
            vector[SUBJECT_A, SUBJECT_B],
            vector[LEVEL_BASIC, LEVEL_ENHANCED],
            vector[expiry(), expiry()],
            7
        );

        assert!(is_verified(source, SUBJECT_A), 1);
        assert!(is_verified(source, SUBJECT_B), 2);
        assert!(level_of(source, SUBJECT_A) == LEVEL_BASIC, 3);
        assert!(level_of(source, SUBJECT_B) == LEVEL_ENHANCED, 4);
        assert!(state_of(source, SUBJECT_A) == STATE_ACTIVE, 5);
        assert!(!is_verified(source, SUBJECT_C), 6);

        let record = record_of(source, SUBJECT_A);
        assert!(record.issuer_id == 1, 7);
        assert!(record.reason == 7, 8);
        assert!(record.history.length() == 1, 9);
        assert!(record.history[0].prev_state == STATE_NONE, 10);
        assert!(record.history[0].new_state == STATE_ACTIVE, 11);
    }

    #[test(framework = @0x1, deployer = @0x123, stranger = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    fun test_non_issuer_cannot_issue(
        framework: &signer, deployer: &signer, stranger: &signer
    ) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        issue_batch(stranger, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x1000C, location = Self)]
    fun test_issue_length_mismatch_fails(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(
            deployer,
            source,
            vector[SUBJECT_A, SUBJECT_B],
            vector[LEVEL_BASIC],
            vector[expiry()],
            0
        );
    }

    // --- Expiry and staleness (INV-3) ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_expiry_stops_verification(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[100], 0);

        timestamp::update_global_time_for_test_secs(99);
        assert!(is_verified(source, SUBJECT_A), 0);
        timestamp::update_global_time_for_test_secs(100);
        assert!(!is_verified(source, SUBJECT_A), 1);
        // The record still exists, it is simply not usable.
        assert!(state_of(source, SUBJECT_A) == STATE_NONE, 2);
        assert!(record_of(source, SUBJECT_A).state == STATE_ACTIVE, 3);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_bump_issuer_epoch_kills_cohort(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(
            deployer,
            source,
            vector[SUBJECT_A, SUBJECT_B],
            vector[LEVEL_BASIC, LEVEL_BASIC],
            vector[expiry(), expiry()],
            0
        );
        assert!(is_verified(source, SUBJECT_A), 0);
        assert!(is_verified(source, SUBJECT_B), 1);

        // One write invalidates every fact this issuer wrote.
        bump_issuer_epoch(deployer, source, 1);
        assert!(!is_verified(source, SUBJECT_A), 2);
        assert!(!is_verified(source, SUBJECT_B), 3);
        assert!(issuer_epoch_of(source, 1) == 1, 4);

        // Re-issuing under the new epoch restores them.
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
        assert!(is_verified(source, SUBJECT_A), 5);
        assert!(!is_verified(source, SUBJECT_B), 6);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_floor_epoch_kills_everything(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
        assert!(is_verified(source, SUBJECT_A), 0);
        set_floor_epoch(deployer, source, 1);
        assert!(!is_verified(source, SUBJECT_A), 1);
    }

    // --- Revocation and suspension ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_revoke_and_suspend(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(
            deployer,
            source,
            vector[SUBJECT_A, SUBJECT_B],
            vector[LEVEL_BASIC, LEVEL_BASIC],
            vector[expiry(), expiry()],
            0
        );

        suspend(deployer, source, SUBJECT_A, 11);
        assert!(!is_verified(source, SUBJECT_A), 0);
        assert!(state_of(source, SUBJECT_A) == STATE_SUSPENDED, 1);
        unsuspend(deployer, source, SUBJECT_A, 12);
        assert!(is_verified(source, SUBJECT_A), 2);

        revoke_batch(deployer, source, vector[SUBJECT_B], 13);
        assert!(!is_verified(source, SUBJECT_B), 3);
        assert!(state_of(source, SUBJECT_B) == STATE_REVOKED, 4);
        assert!(record_of(source, SUBJECT_B).revoked_at_secs == now_seconds(), 5);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x60015, location = Self)]
    fun test_suspend_unknown_subject_fails(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        suspend(deployer, source, SUBJECT_A, 0);
    }

    // --- Exclusion (INV-1, INV-2, INV-5) ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_deny_beats_a_valid_fact(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_ENHANCED], vector[expiry()], 0);
        assert!(is_verified(source, SUBJECT_A), 0);

        deny(deployer, source, SUBJECT_A, 42, now_seconds());
        assert!(!is_verified(source, SUBJECT_A), 1);
        assert!(is_denied(source, SUBJECT_A), 2);
        assert!(deny_reason(source, SUBJECT_A) == 42, 3);
        assert!(state_of(source, SUBJECT_A) == STATE_REVOKED, 4);
        assert!(level_of(source, SUBJECT_A) == 0, 5);

        // A different role reverses it, and the underlying fact is still intact.
        undeny(deployer, source, SUBJECT_A);
        assert!(!is_denied(source, SUBJECT_A), 6);
        assert!(is_verified(source, SUBJECT_A), 7);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_deny_effective_in_future(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
        deny(deployer, source, SUBJECT_A, 1, 500);
        // Announced but not yet in force.
        assert!(is_verified(source, SUBJECT_A), 0);
        timestamp::update_global_time_for_test_secs(500);
        assert!(!is_verified(source, SUBJECT_A), 1);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x30013, location = Self)]
    fun test_issue_over_denial_fails(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        deny(deployer, source, SUBJECT_A, 1, now_seconds());
        // INV-2: no positive write may clear or ignore a denial, even a valid one from an issuer.
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
    }

    #[test(framework = @0x1, deployer = @0x123, sentinel = @0x456)]
    #[expected_failure(abort_code = 0x50005, location = Self)]
    fun test_sentinel_cannot_undeny(
        framework: &signer, deployer: &signer, sentinel: &signer
    ) acquires Source, Facts {
        setup(framework);
        let deployer_address = address_of(deployer);
        create_account_for_test(deployer_address);
        let source = get_next_source_address(deployer_address);
        // A sentinel that is deliberately NOT a remover. INV-5.
        create(
            deployer,
            vector[deployer_address],
            vector[],
            vector[address_of(sentinel)],
            vector[],
            vector[]
        );
        deny(sentinel, source, SUBJECT_A, 1, now_seconds());
        undeny(sentinel, source, SUBJECT_A);
    }

    #[test(framework = @0x1, deployer = @0x123, remover = @0x456)]
    #[expected_failure(abort_code = 0x50004, location = Self)]
    fun test_remover_cannot_deny(
        framework: &signer, deployer: &signer, remover: &signer
    ) acquires Source, Facts {
        setup(framework);
        let deployer_address = address_of(deployer);
        create_account_for_test(deployer_address);
        let source = get_next_source_address(deployer_address);
        create(
            deployer,
            vector[deployer_address],
            vector[],
            vector[],
            vector[address_of(remover)],
            vector[]
        );
        deny(remover, source, SUBJECT_A, 1, now_seconds());
    }

    // --- Pausing (INV-4) ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_pause_blocks_writes_not_reads(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);

        pause(deployer, source);
        assert!(is_paused(source), 0);
        // INV-4: the answer does not change when a source is paused.
        assert!(is_verified(source, SUBJECT_A), 1);
        unpause(deployer, source);
        assert!(!is_paused(source), 2);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x30007, location = Self)]
    fun test_paused_source_rejects_writes(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        pause(deployer, source);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
    }

    // --- Attributes ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_attributes(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);

        assert!(attribute_of(source, SUBJECT_A, 1) == vector[], 0);
        set_attribute(deployer, source, SUBJECT_A, 1, x"0348");
        assert!(attribute_of(source, SUBJECT_A, 1) == x"0348", 1);
        set_attribute(deployer, source, SUBJECT_A, 1, x"0250");
        assert!(attribute_of(source, SUBJECT_A, 1) == x"0250", 2);
        remove_attribute(deployer, source, SUBJECT_A, 1);
        assert!(attribute_of(source, SUBJECT_A, 1) == vector[], 3);
        // An attribute survives a re-issue, because the record is updated rather than replaced.
        set_attribute(deployer, source, SUBJECT_A, 2, x"01");
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_ENHANCED], vector[expiry()], 0);
        assert!(attribute_of(source, SUBJECT_A, 2) == x"01", 4);
    }

    // --- Permissionless relay path ---

    #[test(framework = @0x1, deployer = @0x123, relayer = @0x456)]
    fun test_redeem_attestation(
        framework: &signer, deployer: &signer, relayer: &signer
    ) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        let (secret_key, validated_key) = ed25519::generate_keys();
        let pubkey = ed25519::validated_public_key_to_bytes(&validated_key);
        register_issuer(deployer, source, address_of(deployer), pubkey);

        let issued_at = 10;
        timestamp::update_global_time_for_test_secs(issued_at);
        let expires_at = 1000;
        let message =
            attestation_message(
                source, SUBJECT_A, 1, 0, LEVEL_ENHANCED, expires_at, issued_at, NULLIFIER
            );
        let signature =
            ed25519::signature_to_bytes(
                &ed25519::sign_arbitrary_bytes(&secret_key, message)
            );

        // Anyone may submit it. The relayer is neither the subject nor the issuer.
        redeem_attestation(
            relayer,
            source,
            SUBJECT_A,
            1,
            0,
            LEVEL_ENHANCED,
            expires_at,
            issued_at,
            NULLIFIER,
            signature
        );

        assert!(is_verified(source, SUBJECT_A), 0);
        assert!(level_of(source, SUBJECT_A) == LEVEL_ENHANCED, 1);
        assert!(record_of(source, SUBJECT_A).attestation_digest.length() == 32, 2);
    }

    #[test(framework = @0x1, deployer = @0x123, relayer = @0x456)]
    #[expected_failure(abort_code = 0x10010, location = Self)]
    fun test_redeem_with_tampered_level_fails(
        framework: &signer, deployer: &signer, relayer: &signer
    ) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        let (secret_key, validated_key) = ed25519::generate_keys();
        register_issuer(
            deployer,
            source,
            address_of(deployer),
            ed25519::validated_public_key_to_bytes(&validated_key)
        );
        let message =
            attestation_message(source, SUBJECT_A, 1, 0, LEVEL_BASIC, 1000, 10, NULLIFIER);
        let signature =
            ed25519::signature_to_bytes(
                &ed25519::sign_arbitrary_bytes(&secret_key, message)
            );
        // The relayer raises the level it submits. Every field is covered by the signature.
        redeem_attestation(
            relayer, source, SUBJECT_A, 1, 0, LEVEL_ENHANCED, 1000, 10, NULLIFIER, signature
        );
    }

    #[test(framework = @0x1, deployer = @0x123, relayer = @0x456)]
    #[expected_failure(abort_code = 0x30011, location = Self)]
    fun test_redeem_with_stale_epoch_fails(
        framework: &signer, deployer: &signer, relayer: &signer
    ) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        let (secret_key, validated_key) = ed25519::generate_keys();
        register_issuer(
            deployer,
            source,
            address_of(deployer),
            ed25519::validated_public_key_to_bytes(&validated_key)
        );
        let message =
            attestation_message(source, SUBJECT_A, 1, 0, LEVEL_BASIC, 1000, 10, NULLIFIER);
        let signature =
            ed25519::signature_to_bytes(
                &ed25519::sign_arbitrary_bytes(&secret_key, message)
            );
        // A compromise bump lands before the attestation is redeemed.
        bump_issuer_epoch(deployer, source, 1);
        redeem_attestation(
            relayer, source, SUBJECT_A, 1, 0, LEVEL_BASIC, 1000, 10, NULLIFIER, signature
        );
    }

    #[test(framework = @0x1, deployer = @0x123, relayer = @0x456)]
    #[expected_failure(abort_code = 0x10012, location = Self)]
    fun test_redeem_replay_fails(
        framework: &signer, deployer: &signer, relayer: &signer
    ) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        let (secret_key, validated_key) = ed25519::generate_keys();
        register_issuer(
            deployer,
            source,
            address_of(deployer),
            ed25519::validated_public_key_to_bytes(&validated_key)
        );
        let message =
            attestation_message(source, SUBJECT_A, 1, 0, LEVEL_BASIC, 1000, 10, NULLIFIER);
        let signature =
            ed25519::signature_to_bytes(
                &ed25519::sign_arbitrary_bytes(&secret_key, message)
            );
        redeem_attestation(
            relayer, source, SUBJECT_A, 1, 0, LEVEL_BASIC, 1000, 10, NULLIFIER, signature
        );
        // Replaying the same attestation would push the expiry back out after a revocation.
        redeem_attestation(
            relayer, source, SUBJECT_A, 1, 0, LEVEL_BASIC, 1000, 10, NULLIFIER, signature
        );
    }

    #[test(framework = @0x1, deployer = @0x123, relayer = @0x456)]
    #[expected_failure(abort_code = 0x30014, location = Self)]
    fun test_nullifier_cannot_bind_two_subjects(
        framework: &signer, deployer: &signer, relayer: &signer
    ) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        let (secret_key, validated_key) = ed25519::generate_keys();
        register_issuer(
            deployer,
            source,
            address_of(deployer),
            ed25519::validated_public_key_to_bytes(&validated_key)
        );
        let first =
            attestation_message(source, SUBJECT_A, 1, 0, LEVEL_BASIC, 1000, 10, NULLIFIER);
        redeem_attestation(
            relayer,
            source,
            SUBJECT_A,
            1,
            0,
            LEVEL_BASIC,
            1000,
            10,
            NULLIFIER,
            ed25519::signature_to_bytes(&ed25519::sign_arbitrary_bytes(&secret_key, first))
        );
        // Same identity, second address. One identity binds to one subject.
        let second =
            attestation_message(source, SUBJECT_B, 1, 0, LEVEL_BASIC, 1000, 10, NULLIFIER);
        redeem_attestation(
            relayer,
            source,
            SUBJECT_B,
            1,
            0,
            LEVEL_BASIC,
            1000,
            10,
            NULLIFIER,
            ed25519::signature_to_bytes(&ed25519::sign_arbitrary_bytes(&secret_key, second))
        );
    }

    // --- Roots ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_publish_root_and_verify_membership(
        framework: &signer, deployer: &signer
    ) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        publish_root(deployer, source, ROOT, 5);

        let root = current_root(source);
        assert!(root.digest == ROOT, 0);
        assert!(root.leaf_count == 5, 1);
        assert!(root.issuer_id == 1, 2);

        // A garbage proof does not verify against a real root. The vectors that DO verify live in
        // merkle_proof::oz_vectors, which pins them against OpenZeppelin's construction; here the
        // leaf is bound to this source address so those vectors deliberately do not apply.
        assert!(
            !verify_membership(
                source,
                SUBJECT_A,
                vector[x"0000000000000000000000000000000000000000000000000000000000000001"]
            ),
            3
        );
    }

    // --- Role management ---

    #[test(framework = @0x1, deployer = @0x123, other = @0x456)]
    fun test_role_add_and_remove(
        framework: &signer, deployer: &signer, other: &signer
    ) acquires Source {
        setup(framework);
        let source = create_for_test(deployer);
        let other_address = address_of(other);

        add_admins(deployer, source, vector[other_address]);
        assert!(is_admin(other_address, source), 0);
        add_issuers(deployer, source, vector[other_address]);
        assert!(is_issuer(other_address, source), 1);
        add_sentinels(deployer, source, vector[other_address]);
        assert!(sentinels(source).contains(&other_address), 2);
        add_removers(deployer, source, vector[other_address]);
        assert!(removers(source).contains(&other_address), 3);
        add_guardians(deployer, source, vector[other_address]);
        assert!(guardians(source).contains(&other_address), 4);

        remove_issuers(deployer, source, vector[other_address]);
        assert!(!is_issuer(other_address, source), 5);
        remove_admins(deployer, source, vector[other_address]);
        assert!(!is_admin(other_address, source), 6);
    }

    #[test(framework = @0x1, deployer = @0x123, stranger = @0x456)]
    #[expected_failure(abort_code = 0x50002, location = Self)]
    fun test_non_admin_cannot_grant_roles(
        framework: &signer, deployer: &signer, stranger: &signer
    ) acquires Source {
        setup(framework);
        let source = create_for_test(deployer);
        add_issuers(stranger, source, vector[address_of(stranger)]);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x8000F, location = Self)]
    fun test_duplicate_issuer_registration_fails(
        framework: &signer, deployer: &signer
    ) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        register_issuer(deployer, source, address_of(deployer), vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x60001, location = Self)]
    fun test_reads_on_non_source_fail(framework: &signer, deployer: &signer) acquires Facts {
        setup(framework);
        create_account_for_test(address_of(deployer));
        is_verified(@0xdead, SUBJECT_A);
    }

    // --- Two sources disagree, which is the point ---

    #[test(framework = @0x1, deployer = @0x123, other = @0x456)]
    fun test_two_sources_are_independent(
        framework: &signer, deployer: &signer, other: &signer
    ) acquires Source, Facts {
        setup(framework);
        let first = create_for_test(deployer);
        let second = create_for_test(other);
        register_issuer(deployer, first, address_of(deployer), vector[]);
        register_issuer(other, second, address_of(other), vector[]);

        issue_batch(deployer, first, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
        deny(other, second, SUBJECT_A, 1, now_seconds());

        // A fact is never true globally, only true according to somebody.
        assert!(is_verified(first, SUBJECT_A), 0);
        assert!(!is_verified(second, SUBJECT_A), 1);
        assert!(!is_denied(first, SUBJECT_A), 2);
        assert!(is_denied(second, SUBJECT_A), 3);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x30019, location = Self)]
    fun test_unsuspend_revoked_fails(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
        revoke_batch(deployer, source, vector[SUBJECT_A], 1);
        // Revocation is terminal: only re-issuance brings the subject back.
        unsuspend(deployer, source, SUBJECT_A, 2);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x30019, location = Self)]
    fun test_suspend_revoked_fails(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
        revoke_batch(deployer, source, vector[SUBJECT_A], 1);
        suspend(deployer, source, SUBJECT_A, 2);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x30019, location = Self)]
    fun test_suspend_twice_fails(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
        suspend(deployer, source, SUBJECT_A, 1);
        suspend(deployer, source, SUBJECT_A, 2);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x30019, location = Self)]
    fun test_unsuspend_active_fails(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
        unsuspend(deployer, source, SUBJECT_A, 1);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_revoke_batch_skips_revoked_and_revokes_suspended(
        framework: &signer, deployer: &signer
    ) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(
            deployer,
            source,
            vector[SUBJECT_A, SUBJECT_B],
            vector[LEVEL_BASIC, LEVEL_BASIC],
            vector[expiry(), expiry()],
            0
        );
        revoke_batch(deployer, source, vector[SUBJECT_A], 1);
        suspend(deployer, source, SUBJECT_B, 2);
        let history_before = record_of(source, SUBJECT_A).history.length();

        // A is already revoked and is skipped without an abort or a history entry.
        revoke_batch(deployer, source, vector[SUBJECT_A, SUBJECT_B], 3);
        assert!(record_of(source, SUBJECT_A).history.length() == history_before, 0);
        assert!(record_of(source, SUBJECT_A).reason == 1, 1);
        assert!(state_of(source, SUBJECT_B) == STATE_REVOKED, 2);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x30013, location = Self)]
    fun test_unsuspend_denied_fails(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
        suspend(deployer, source, SUBJECT_A, 1);
        deny(deployer, source, SUBJECT_A, 9, now_seconds());
        unsuspend(deployer, source, SUBJECT_A, 2);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_unsuspend_after_bump_stays_dead(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
        suspend(deployer, source, SUBJECT_A, 1);
        bump_issuer_epoch(deployer, source, 1);
        // Reactivating keeps the epoch the fact was issued under, which the bump killed.
        unsuspend(deployer, source, SUBJECT_A, 2);
        assert!(!is_verified(source, SUBJECT_A), 0);
        assert!(record_of(source, SUBJECT_A).issuer_epoch == 0, 1);
    }

    #[test(framework = @0x1, deployer = @0x123, second = @0x456)]
    fun test_transition_keeps_original_issuer(
        framework: &signer, deployer: &signer, second: &signer
    ) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        register_issuer(deployer, source, address_of(second), vector[]);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);

        suspend(second, source, SUBJECT_A, 1);
        unsuspend(second, source, SUBJECT_A, 2);
        let record = record_of(source, SUBJECT_A);
        assert!(record.issuer_id == 1, 0);
        // The acting issuer is still on the record, in the history.
        assert!(record.history[record.history.length() - 1].issuer_id == 2, 1);

        // So bumping the original issuer still kills the fact.
        bump_issuer_epoch(deployer, source, 1);
        assert!(!is_verified(source, SUBJECT_A), 2);
    }

    #[test(framework = @0x1, deployer = @0x123, relayer = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    fun test_removed_issuer_cannot_relay(
        framework: &signer, deployer: &signer, relayer: &signer
    ) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        let (secret_key, validated_key) = ed25519::generate_keys();
        register_issuer(
            deployer,
            source,
            address_of(deployer),
            ed25519::validated_public_key_to_bytes(&validated_key)
        );
        let message =
            attestation_message(source, SUBJECT_A, 1, 0, LEVEL_BASIC, 1000, 10, NULLIFIER);
        let signature =
            ed25519::signature_to_bytes(
                &ed25519::sign_arbitrary_bytes(&secret_key, message)
            );
        remove_issuers(deployer, source, vector[address_of(deployer)]);
        redeem_attestation(
            relayer, source, SUBJECT_A, 1, 0, LEVEL_BASIC, 1000, 10, NULLIFIER, signature
        );
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_writes_after_floor_raise_are_usable(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        set_floor_epoch(deployer, source, 3);
        // The issuer's effective epoch follows the floor, so new writes are stamped with it.
        assert!(issuer_epoch_of(source, 1) == 3, 0);
        assert!(issuer_epoch_of(source, 0) == 3, 1);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
        assert!(is_verified(source, SUBJECT_A), 2);
        assert!(record_of(source, SUBJECT_A).issuer_epoch == 3, 3);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_bump_below_floor_still_takes_effect(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        set_floor_epoch(deployer, source, 5);
        issue_batch(deployer, source, vector[SUBJECT_A], vector[LEVEL_BASIC], vector[expiry()], 0);
        assert!(is_verified(source, SUBJECT_A), 0);
        // The issuer's own counter is 0, below the floor; a bump still moves past the floor.
        bump_issuer_epoch(deployer, source, 1);
        assert!(issuer_epoch_of(source, 1) == 6, 1);
        assert!(!is_verified(source, SUBJECT_A), 2);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x10012, location = Self)]
    fun test_floor_cannot_be_lowered(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        set_floor_epoch(deployer, source, 2);
        set_floor_epoch(deployer, source, 1);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x10012, location = Self)]
    fun test_floor_cannot_be_reset_to_same(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        set_floor_epoch(deployer, source, 2);
        set_floor_epoch(deployer, source, 2);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_bump_zktls_cohort(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        // Issuer id 0 is the zkTLS cohort and needs no registration.
        assert!(issuer_epoch_of(source, 0) == 0, 0);
        bump_issuer_epoch(deployer, source, 0);
        assert!(issuer_epoch_of(source, 0) == 1, 1);
        bump_issuer_epoch(deployer, source, 0);
        assert!(issuer_epoch_of(source, 0) == 2, 2);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x6000e, location = Self)]
    fun test_bump_unknown_issuer_fails(framework: &signer, deployer: &signer) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        bump_issuer_epoch(deployer, source, 7);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_verify_membership_against_an_oz_root(
        framework: &signer, deployer: &signer
    ) acquires Source, Facts {
        setup(framework);
        let source = create_for_test(deployer);
        // Deterministic, so the root below could be built off chain before the source existed.
        assert!(source == @0x94d1a87048840daa2ccb24dd50b1176d808ab8dc170a2492845f416a7c5801b1, 0);
        register_issuer(deployer, source, address_of(deployer), vector[]);
        // StandardMerkleTree.of([[source, s] for s in a11, b22, c33, d44, e55, f66, 777],
        // ['bytes32', 'bytes32']) from @openzeppelin/merkle-tree.
        publish_root(
            deployer,
            source,
            x"6b0f31d23e28de5e4a07f4ff973ece0ecd3f044616eae7984a664250a2abdc19",
            7
        );
        let proof_a = vector[
            x"c186e553e4a1243744c5c6ebfb79c16707bd5d312b56362f596dde270a133bff",
            x"acf871e7d55582aae9aae3304b30209eae259960aa7fca4428019394da24a1b9",
            x"4faffc94448d88f74e4a8258458427d33bbdef40c08f92a3f6781d5287547d53"
        ];
        assert!(verify_membership(source, SUBJECT_A, proof_a), 1);
        assert!(!verify_membership(source, SUBJECT_B, proof_a), 2);

        // Rotating the root invalidates proofs against the old one.
        publish_root(deployer, source, ROOT, 5);
        assert!(!verify_membership(source, SUBJECT_A, proof_a), 3);
    }
}
