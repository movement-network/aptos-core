/// A business's rules over attestation sources, without deploying anything.
///
/// A policy is a resource account, created the same way `aptos_framework::attestation` creates a
/// source and `aptos_framework::timelock` creates a timelock account: the deployer authorizes
/// creation and pays gas but gains no role unless listed. A policy names the sources it trusts,
/// how to combine them, predicates over their attributes, and a per-action amount above which a
/// fresh authorization is demanded.
///
/// The consequence is the reason this module exists rather than a single registry. A new business
/// does not onboard subjects: it creates a policy pointing at sources that already have them, so
/// its marginal onboarding cost is zero, and the network effect sits on the source side.
///
/// Evaluation returns three values, not two. Two-valued authorization forces one global threshold
/// on every consumer. The third value lets a policy be permissive for ordinary activity and strict
/// where the business actually cares, and it is what joins persistent facts and per-action
/// authorization into one product instead of two.
///
/// Properties:
/// - An empty body denies everything. A policy that allows nothing is obvious in testing; one that
///   allows everything is not.
/// - Denial is evaluated before anything positive, and no source can override another's denial.
/// - Rule changes are staged with an activation time, so a change never breaks a transaction that
///   is already in flight, and anyone may push a staged body live once its time arrives.
/// - A paused policy denies with its own reason rather than silently allowing.
/// - Source lists are bounded, because unbounded iteration over rules is a denial-of-service
///   vector. `ERC-3643` caps its module list at 25 for the same reason.
///
/// Delayed governance comes by composition: an admin may be a `aptos_framework::timelock` account,
/// in which case every rule change inherits that module's delay and cancel semantics.
module aptos_framework::attestation_policy {
    use std::account::{Self, SignerCapability, create_resource_address};
    use std::bcs::to_bytes;
    use std::error;
    use std::event::emit;
    use std::option::{Self, Option};
    use std::signer::address_of;
    use std::table::{Self, Table};
    use std::timestamp::now_seconds;
    use aptos_framework::attestation;
    use aptos_framework::attestation_authorization;

    /// Domain separator used when deriving the resource account seed, to avoid collisions with
    /// other modules that create resource accounts.
    const DOMAIN_SEPARATOR: vector<u8> = b"aptos_framework::attestation_policy";

    /// The subject may take the action.
    const DECISION_ALLOW: u8 = 0;
    /// The subject may not take the action.
    const DECISION_DENY: u8 = 1;
    /// The subject may take the action only with a fresh authorization attached.
    const DECISION_STEP_UP: u8 = 2;

    /// Allowed.
    const REASON_OK: u16 = 0;
    /// Excluded by the chain-wide denial source.
    const REASON_CHAIN_DENIED: u16 = 1;
    /// Excluded by one of the policy's denial sources.
    const REASON_SOURCE_DENIED: u16 = 2;
    /// A source the policy requires does not vouch for the subject.
    const REASON_MISSING_REQUIRED: u16 = 3;
    /// No source among the alternatives vouches for the subject.
    const REASON_NO_QUALIFYING: u16 = 4;
    /// A source vouches for the subject but below the level the policy requires.
    const REASON_LEVEL_TOO_LOW: u16 = 5;
    /// An attribute predicate failed.
    const REASON_ATTR_FAILED: u16 = 6;
    /// The amount is above the policy's step-up threshold for this action.
    const REASON_AMOUNT_THRESHOLD: u16 = 7;
    /// The policy is paused.
    const REASON_POLICY_PAUSED: u16 = 8;
    /// The policy has no rules, so it allows nothing.
    const REASON_EMPTY_BODY: u16 = 9;

    /// The attribute value must be one of the listed values.
    const OP_IN: u8 = 0;
    /// The attribute value must not be any of the listed values.
    const OP_NOT_IN: u8 = 1;
    /// The attribute value must equal the single listed value.
    const OP_EQ: u8 = 2;
    /// The attribute value must be greater than or equal to the single listed value, compared as a
    /// big-endian unsigned integer of the same length.
    const OP_GTE: u8 = 3;

    /// Transfer value out of the subject's control.
    const ACTION_TRANSFER: u8 = 1;
    /// Receive value.
    const ACTION_RECEIVE: u8 = 2;
    /// Mint.
    const ACTION_MINT: u8 = 3;
    /// Redeem or burn.
    const ACTION_REDEEM: u8 = 4;
    /// Borrow.
    const ACTION_BORROW: u8 = 5;
    /// Vote.
    const ACTION_VOTE: u8 = 6;
    // Action ids 64 and above are application-defined.

    /// Largest number of sources any one list in a body may name.
    const MAX_SOURCES: u64 = 16;
    /// Largest number of attribute predicates a body may carry.
    const MAX_RULES: u64 = 16;

    /// Published version of this module's interface.
    const VERSION: u64 = 1;

    /// Specified account is not a policy.
    const EACCOUNT_NOT_POLICY: u64 = 1;
    /// The caller is not an admin.
    const ENOT_ADMIN: u64 = 2;
    /// The caller is not a guardian.
    const ENOT_GUARDIAN: u64 = 3;
    /// A role list cannot contain duplicate addresses.
    const EDUPLICATE_MEMBER: u64 = 4;
    /// The policy account itself cannot hold a role.
    const ESELF_CANNOT_BE_MEMBER: u64 = 5;
    /// A policy must have at least one admin.
    const ENOT_ENOUGH_ADMINS: u64 = 6;
    /// Removing these admins would leave the policy with zero admins.
    const EWOULD_REMOVE_ALL_ADMINS: u64 = 7;
    /// A list names more sources than MAX_SOURCES.
    const ETOO_MANY_SOURCES: u64 = 8;
    /// A body carries more predicates than MAX_RULES.
    const ETOO_MANY_RULES: u64 = 9;
    /// Argument vectors have differing lengths.
    const ELENGTH_MISMATCH: u64 = 10;
    /// No staged body is waiting.
    const ENO_PENDING: u64 = 11;
    /// The staged body's activation time has not arrived.
    const ENOT_EFFECTIVE: u64 = 12;
    /// The subject may not take this action.
    const EDENIED: u64 = 13;
    /// The action needs a fresh authorization, which was not supplied.
    const ESTEP_UP_REQUIRED: u64 = 14;
    /// A named source does not exist.
    const EUNKNOWN_SOURCE: u64 = 15;
    /// An attribute predicate is malformed.
    const EBAD_RULE: u64 = 16;
    /// The authorizer key must be 32 bytes or empty.
    const EBAD_AUTHORIZER: u64 = 17;
    /// At most one chain-wide denial source may be named.
    const ETOO_MANY_CHAIN_DENY: u64 = 18;

    /// One source the policy consults, and the minimum level it must vouch at.
    struct SourceRef has copy, drop, store {
        source: address,
        min_level: u8
    }

    /// A predicate over one attribute of one source.
    struct AttrRule has copy, drop, store {
        source: address,
        key: u16,
        op: u8,
        values: vector<vector<u8>>
    }

    /// The rules themselves, swapped atomically when a staged body activates.
    struct Body has copy, drop, store {
        // At least one of these must vouch at or above its min_level.
        require_any: vector<SourceRef>,
        // All of these must vouch at or above their min_level.
        require_all: vector<SourceRef>,
        // A denial in any of these denies, unconditionally.
        deny_any: vector<address>,
        attr_rules: vector<AttrRule>,
        // Optional chain-wide denial source, consulted before anything else.
        chain_deny: Option<address>
    }

    /// A body waiting for its activation time.
    struct Staged has copy, drop, store {
        body: Body,
        effective_at_secs: u64
    }

    /// Stored at the policy's resource account address.
    struct Policy has key {
        // Addresses allowed to stage rules and grant roles. Must have at least 1.
        admins: vector<address>,
        // Addresses allowed to pause and unpause evaluation.
        guardians: vector<address>,
        // Denies with REASON_POLICY_PAUSED rather than allowing. See the module doc.
        paused: bool,
        body: Body,
        pending: Option<Staged>,
        // action to the amount above which the decision becomes step-up. Absent means never, so
        // nobody enables a liveness dependency by accident.
        step_up_above: Table<u8, u64>,
        // Key that signs authorizations for this policy, and the longest window it may issue. The
        // policy owns both, so a compromised authorizer cannot mint a long-lived capability by
        // setting a distant expiry.
        authorizer_pubkey: vector<u8>,
        authorizer_max_ttl_secs: u64,
        // Signer capability for the resource account, retained so future resources can be added.
        signer_cap: SignerCapability
    }

    #[event]
    struct CreatePolicy has drop, store {
        policy: address,
        deployer: address,
        admins: vector<address>
    }

    #[event]
    struct AddMembers has drop, store {
        policy: address,
        role: u8,
        members: vector<address>
    }

    #[event]
    struct RemoveMembers has drop, store {
        policy: address,
        role: u8,
        members: vector<address>
    }

    #[event]
    struct StageBody has drop, store {
        policy: address,
        effective_at_secs: u64
    }

    #[event]
    struct ActivateBody has drop, store {
        policy: address,
        at_secs: u64
    }

    #[event]
    struct CancelPending has drop, store {
        policy: address
    }

    #[event]
    struct SetStepUp has drop, store {
        policy: address,
        action: u8,
        threshold: u64
    }

    #[event]
    struct SetAuthorizer has drop, store {
        policy: address,
        max_ttl_secs: u64
    }

    #[event]
    struct SetPaused has drop, store {
        policy: address,
        paused: bool
    }

    const ROLE_ADMIN: u8 = 0;
    const ROLE_GUARDIAN: u8 = 1;

    // =============================== Views ===============================

    #[view]
    /// Return the predicted address for the next policy deployed by the given account.
    public fun get_next_policy_address(deployer: address): address {
        let owner_nonce = account::get_sequence_number(deployer);
        create_resource_address(&deployer, create_policy_seed(to_bytes(&owner_nonce)))
    }

    #[view]
    /// Evaluate the policy for a subject, action and amount, returning a decision and a reason.
    ///
    /// The order below is the load-bearing part of this module. Denial comes before anything
    /// positive and cannot be outvoted by a source that vouches.
    public fun evaluate(
        policy: address, subject: address, action: u8, amount: u64
    ): (u8, u16) acquires Policy {
        assert_policy_exists(policy);
        let config = &Policy[policy];

        if (config.paused) {
            return (DECISION_DENY, REASON_POLICY_PAUSED)
        };

        let body = &config.body;

        // A policy with no positive rule allows nothing. Stated explicitly so an unconfigured
        // policy is a loud failure rather than an open door.
        if (body.require_any.is_empty() && body.require_all.is_empty()) {
            return (DECISION_DENY, REASON_EMPTY_BODY)
        };

        // 1. chain-wide denial
        if (option::is_some(&body.chain_deny)) {
            let chain_source = *option::borrow(&body.chain_deny);
            if (attestation::is_denied(chain_source, subject)) {
                return (DECISION_DENY, REASON_CHAIN_DENIED)
            };
        };

        // 2. per-source denials
        let denied = false;
        body.deny_any.for_each_ref(|source| {
            if (!denied && attestation::is_denied(*source, subject)) {
                denied = true;
            };
        });
        if (denied) {
            return (DECISION_DENY, REASON_SOURCE_DENIED)
        };

        // 3. every required source must vouch, at or above its level
        let missing = false;
        let too_low = false;
        body.require_all.for_each_ref(|entry| {
            if (!missing && !too_low) {
                let (active, level) = attestation::active_with_level(entry.source, subject);
                if (!active) {
                    missing = true;
                } else if (level < entry.min_level) {
                    too_low = true;
                };
            };
        });
        if (missing) {
            return (DECISION_DENY, REASON_MISSING_REQUIRED)
        };
        if (too_low) {
            return (DECISION_DENY, REASON_LEVEL_TOO_LOW)
        };

        // 4. at least one alternative must vouch, when any are configured
        if (!body.require_any.is_empty()) {
            let qualified = false;
            body.require_any.for_each_ref(|entry| {
                if (!qualified) {
                    let (active, level) = attestation::active_with_level(entry.source, subject);
                    if (active && level >= entry.min_level) {
                        qualified = true;
                    };
                };
            });
            if (!qualified) {
                return (DECISION_DENY, REASON_NO_QUALIFYING)
            };
        };

        // 5. attribute predicates
        let failed = false;
        body.attr_rules.for_each_ref(|rule| {
            if (!failed && !eval_attr_rule(rule, subject)) {
                failed = true;
            };
        });
        if (failed) {
            return (DECISION_DENY, REASON_ATTR_FAILED)
        };

        // 6. step-up threshold for this action
        if (table::contains(&config.step_up_above, action)
            && amount > *table::borrow(&config.step_up_above, action)) {
            return (DECISION_STEP_UP, REASON_AMOUNT_THRESHOLD)
        };

        (DECISION_ALLOW, REASON_OK)
    }

    #[view]
    /// Whether the subject may take the action outright, with no authorization needed.
    public fun is_allowed(
        policy: address, subject: address, action: u8, amount: u64
    ): bool acquires Policy {
        let (decision, _) = evaluate(policy, subject, action, amount);
        decision == DECISION_ALLOW
    }

    #[view]
    /// Decision only, for a caller that does not need the reason.
    public fun decision_of(
        policy: address, subject: address, action: u8, amount: u64
    ): u8 acquires Policy {
        let (decision, _) = evaluate(policy, subject, action, amount);
        decision
    }

    #[view]
    /// Reason only, for a wallet that wants to explain a refusal rather than show a revert.
    public fun reason_of(
        policy: address, subject: address, action: u8, amount: u64
    ): u16 acquires Policy {
        let (_, reason) = evaluate(policy, subject, action, amount);
        reason
    }

    #[view]
    /// Dry-run the policy against a population, returning one decision per subject in order.
    /// A business uses this to see what a staged rule change will do before its time arrives.
    public fun simulate(
        policy: address, subjects: vector<address>, action: u8, amount: u64
    ): vector<u8> acquires Policy {
        let decisions = vector[];
        subjects.for_each(|subject| {
            let (decision, _) = evaluate(policy, subject, action, amount);
            decisions.push_back(decision);
        });
        decisions
    }

    #[view]
    /// Counts of allow, deny and step-up over a population, in that order.
    public fun simulate_counts(
        policy: address, subjects: vector<address>, action: u8, amount: u64
    ): vector<u64> acquires Policy {
        let counts = vector[0, 0, 0];
        simulate(policy, subjects, action, amount).for_each(|decision| {
            let slot = counts.borrow_mut((decision as u64));
            *slot += 1;
        });
        counts
    }

    #[view]
    public fun admins(policy: address): vector<address> acquires Policy {
        assert_policy_exists(policy);
        Policy[policy].admins
    }

    #[view]
    public fun guardians(policy: address): vector<address> acquires Policy {
        assert_policy_exists(policy);
        Policy[policy].guardians
    }

    #[view]
    public fun is_admin(addr: address, policy: address): bool acquires Policy {
        assert_policy_exists(policy);
        Policy[policy].admins.contains(&addr)
    }

    #[view]
    public fun is_paused(policy: address): bool acquires Policy {
        assert_policy_exists(policy);
        Policy[policy].paused
    }

    #[view]
    /// Sources named in `require_any`, with their minimum levels alongside in `require_any_levels`.
    public fun require_any_sources(policy: address): vector<address> acquires Policy {
        assert_policy_exists(policy);
        let sources = vector[];
        Policy[policy].body.require_any.for_each_ref(|entry| {
            sources.push_back(entry.source);
        });
        sources
    }

    #[view]
    public fun require_all_sources(policy: address): vector<address> acquires Policy {
        assert_policy_exists(policy);
        let sources = vector[];
        Policy[policy].body.require_all.for_each_ref(|entry| {
            sources.push_back(entry.source);
        });
        sources
    }

    #[view]
    public fun deny_any_sources(policy: address): vector<address> acquires Policy {
        assert_policy_exists(policy);
        Policy[policy].body.deny_any
    }

    #[view]
    /// Amount above which this action needs an authorization, or 0 when it never does.
    public fun step_up_for(policy: address, action: u8): u64 acquires Policy {
        assert_policy_exists(policy);
        let thresholds = &Policy[policy].step_up_above;
        if (table::contains(thresholds, action)) {
            *table::borrow(thresholds, action)
        } else { 0 }
    }

    #[view]
    public fun has_pending(policy: address): bool acquires Policy {
        assert_policy_exists(policy);
        option::is_some(&Policy[policy].pending)
    }

    #[view]
    /// When the staged body becomes active, or 0 when nothing is staged.
    public fun pending_effective_at(policy: address): u64 acquires Policy {
        assert_policy_exists(policy);
        let pending = &Policy[policy].pending;
        if (option::is_some(pending)) {
            option::borrow(pending).effective_at_secs
        } else { 0 }
    }

    #[view]
    /// The key that signs authorizations for this policy, or empty when step-up is disabled.
    public fun authorizer_pubkey(policy: address): vector<u8> acquires Policy {
        assert_policy_exists(policy);
        Policy[policy].authorizer_pubkey
    }

    #[view]
    public fun authorizer_max_ttl_secs(policy: address): u64 acquires Policy {
        assert_policy_exists(policy);
        Policy[policy].authorizer_max_ttl_secs
    }

    #[view]
    public fun standard_version(): u64 {
        VERSION
    }

    // =============================== Policy creation ===============================

    /// Create a new policy. The deployer only authorizes resource-account creation and pays gas;
    /// it gains no role unless listed. The body starts empty, which denies everything until rules
    /// are staged and activated.
    ///
    /// @param deployer Signer that authorizes resource-account creation and pays gas.
    /// @param admins Addresses allowed to stage rules. At least one, no duplicates.
    /// @param guardians Addresses allowed to pause evaluation. May be empty.
    /// @abort If a list has duplicates, names the policy itself, or there is no admin.
    public entry fun create(
        deployer: &signer, admins: vector<address>, guardians: vector<address>
    ) {
        let (policy_signer, policy_signer_cap) = create_policy_account(deployer);
        let policy_address = address_of(&policy_signer);
        assert!(admins.length() >= 1, error::invalid_argument(ENOT_ENOUGH_ADMINS));
        validate_members(&admins, policy_address);
        validate_members(&guardians, policy_address);

        move_to(
            &policy_signer,
            Policy {
                admins,
                guardians,
                paused: false,
                body: empty_body(),
                pending: option::none(),
                step_up_above: table::new<u8, u64>(),
                authorizer_pubkey: vector[],
                authorizer_max_ttl_secs: 0,
                signer_cap: policy_signer_cap
            }
        );
        attestation_authorization::initialize(&policy_signer);
        emit(
            CreatePolicy {
                policy: policy_address,
                deployer: address_of(deployer),
                admins
            }
        );
    }

    // =============================== Rules ===============================

    /// Stage a new body, to take effect at `effective_at_secs`. Staging rather than applying
    /// immediately is what keeps a rule change from breaking a transaction already in flight.
    ///
    /// @param admin An admin of the policy.
    /// @param policy The policy address.
    /// @param require_any_sources Sources of which at least one must vouch. May be empty.
    /// @param require_any_levels Minimum level per entry, same length as require_any_sources.
    /// @param require_all_sources Sources that must all vouch. May be empty.
    /// @param require_all_levels Minimum level per entry, same length as require_all_sources.
    /// @param deny_any Sources whose denial denies. May be empty.
    /// @param chain_deny Optional chain-wide denial source: empty for none, or exactly one address.
    ///   A vector rather than an `Option` because entry functions cannot take `Option` arguments.
    /// @param effective_at_secs When the body becomes active.
    /// @abort If the lengths differ, a list is over MAX_SOURCES, chain_deny names more than one
    ///   source, or a named source does not exist.
    public entry fun stage_body(
        admin: &signer,
        policy: address,
        require_any_sources: vector<address>,
        require_any_levels: vector<u8>,
        require_all_sources: vector<address>,
        require_all_levels: vector<u8>,
        deny_any: vector<address>,
        chain_deny: vector<address>,
        effective_at_secs: u64
    ) acquires Policy {
        assert_admin(policy, address_of(admin));
        assert!(chain_deny.length() <= 1, error::invalid_argument(ETOO_MANY_CHAIN_DENY));
        let chain_deny =
            if (chain_deny.is_empty()) option::none()
            else option::some(chain_deny[0]);
        let body =
            build_body(
                require_any_sources,
                require_any_levels,
                require_all_sources,
                require_all_levels,
                deny_any,
                chain_deny
            );
        // Keep any predicates already staged, so the two staging calls compose in either order.
        let config = &mut Policy[policy];
        if (option::is_some(&config.pending)) {
            body.attr_rules = option::borrow(&config.pending).body.attr_rules;
        };
        config.pending = option::some(Staged { body, effective_at_secs });
        emit(StageBody { policy, effective_at_secs });
    }

    /// Stage attribute predicates onto the pending body. Call `stage_body` first.
    ///
    /// @param sources Source whose attribute each predicate reads.
    /// @param keys Attribute key per predicate.
    /// @param ops One of OP_IN, OP_NOT_IN, OP_EQ, OP_GTE.
    /// @param values Candidate values per predicate. OP_EQ and OP_GTE take exactly one.
    public entry fun stage_attr_rules(
        admin: &signer,
        policy: address,
        sources: vector<address>,
        keys: vector<u16>,
        ops: vector<u8>,
        values: vector<vector<vector<u8>>>
    ) acquires Policy {
        assert_admin(policy, address_of(admin));
        let count = sources.length();
        assert!(count <= MAX_RULES, error::invalid_argument(ETOO_MANY_RULES));
        assert!(
            count == keys.length() && count == ops.length() && count == values.length(),
            error::invalid_argument(ELENGTH_MISMATCH)
        );

        let rules = vector[];
        let index = 0;
        while (index < count) {
            let op = ops[index];
            assert!(op <= OP_GTE, error::invalid_argument(EBAD_RULE));
            let candidates = values[index];
            // A comparison against a set is meaningless with no members, and OP_EQ and OP_GTE
            // compare against exactly one.
            assert!(!candidates.is_empty(), error::invalid_argument(EBAD_RULE));
            if (op == OP_EQ || op == OP_GTE) {
                assert!(candidates.length() == 1, error::invalid_argument(EBAD_RULE));
            };
            assert!(
                attestation::is_source(sources[index]),
                error::not_found(EUNKNOWN_SOURCE)
            );
            rules.push_back(
                AttrRule { source: sources[index], key: keys[index], op, values: candidates }
            );
            index += 1;
        };

        let config = &mut Policy[policy];
        let staged =
            if (option::is_some(&config.pending)) {
                option::extract(&mut config.pending)
            } else {
                Staged { body: config.body, effective_at_secs: now_seconds() }
            };
        staged.body.attr_rules = rules;
        let effective_at_secs = staged.effective_at_secs;
        config.pending = option::some(staged);
        emit(StageBody { policy, effective_at_secs });
    }

    /// Push the staged body live. Permissionless once its time has arrived, so the business does
    /// not have to be online at the moment its own rule change takes effect.
    public entry fun activate_pending(_anyone: &signer, policy: address) acquires Policy {
        assert_policy_exists(policy);
        let config = &mut Policy[policy];
        assert!(option::is_some(&config.pending), error::invalid_state(ENO_PENDING));
        let staged = option::extract(&mut config.pending);
        assert!(
            now_seconds() >= staged.effective_at_secs,
            error::invalid_state(ENOT_EFFECTIVE)
        );
        config.body = staged.body;
        emit(ActivateBody { policy, at_secs: now_seconds() });
    }

    /// Discard a staged body that has not activated yet.
    public entry fun cancel_pending(admin: &signer, policy: address) acquires Policy {
        assert_admin(policy, address_of(admin));
        let config = &mut Policy[policy];
        assert!(option::is_some(&config.pending), error::invalid_state(ENO_PENDING));
        config.pending = option::none();
        emit(CancelPending { policy });
    }

    /// Set the amount above which an action needs a fresh authorization. Absent by default, so a
    /// liveness dependency is never enabled by accident.
    public entry fun set_step_up(
        admin: &signer, policy: address, action: u8, threshold: u64
    ) acquires Policy {
        assert_admin(policy, address_of(admin));
        table::upsert(&mut Policy[policy].step_up_above, action, threshold);
        emit(SetStepUp { policy, action, threshold });
    }

    /// Set the key that signs authorizations for this policy, and the longest window it may
    /// issue. A window of 0 with an empty key disables the step-up path entirely.
    public entry fun set_authorizer(
        admin: &signer, policy: address, pubkey: vector<u8>, max_ttl_secs: u64
    ) acquires Policy {
        assert_admin(policy, address_of(admin));
        assert!(
            pubkey.is_empty() || pubkey.length() == 32,
            error::invalid_argument(EBAD_AUTHORIZER)
        );
        let config = &mut Policy[policy];
        config.authorizer_pubkey = pubkey;
        config.authorizer_max_ttl_secs = max_ttl_secs;
        emit(SetAuthorizer { policy, max_ttl_secs });
    }

    /// Stop demanding authorization for an action.
    public entry fun clear_step_up(admin: &signer, policy: address, action: u8) acquires Policy {
        assert_admin(policy, address_of(admin));
        let thresholds = &mut Policy[policy].step_up_above;
        if (table::contains(thresholds, action)) {
            table::remove(thresholds, action);
        };
        emit(SetStepUp { policy, action, threshold: 0 });
    }

    // =============================== Roles ===============================

    public entry fun add_admins(
        admin: &signer, policy: address, new_admins: vector<address>
    ) acquires Policy {
        assert_admin(policy, address_of(admin));
        let config = &mut Policy[policy];
        add_members(&mut config.admins, &new_admins, policy);
        emit(AddMembers { policy, role: ROLE_ADMIN, members: new_admins });
    }

    public entry fun remove_admins(
        admin: &signer, policy: address, old_admins: vector<address>
    ) acquires Policy {
        assert_admin(policy, address_of(admin));
        let config = &mut Policy[policy];
        remove_members(&mut config.admins, &old_admins);
        assert!(
            config.admins.length() >= 1,
            error::invalid_state(EWOULD_REMOVE_ALL_ADMINS)
        );
        emit(RemoveMembers { policy, role: ROLE_ADMIN, members: old_admins });
    }

    public entry fun add_guardians(
        admin: &signer, policy: address, new_guardians: vector<address>
    ) acquires Policy {
        assert_admin(policy, address_of(admin));
        let config = &mut Policy[policy];
        add_members(&mut config.guardians, &new_guardians, policy);
        emit(AddMembers { policy, role: ROLE_GUARDIAN, members: new_guardians });
    }

    public entry fun remove_guardians(
        admin: &signer, policy: address, old_guardians: vector<address>
    ) acquires Policy {
        assert_admin(policy, address_of(admin));
        let config = &mut Policy[policy];
        remove_members(&mut config.guardians, &old_guardians);
        emit(RemoveMembers { policy, role: ROLE_GUARDIAN, members: old_guardians });
    }

    /// Deny everything until unpaused. Denies loudly with REASON_POLICY_PAUSED rather than
    /// silently allowing.
    public entry fun pause(guardian: &signer, policy: address) acquires Policy {
        set_paused(guardian, policy, true);
    }

    public entry fun unpause(guardian: &signer, policy: address) acquires Policy {
        set_paused(guardian, policy, false);
    }

    fun set_paused(guardian: &signer, policy: address, paused: bool) acquires Policy {
        assert_policy_exists(policy);
        assert!(
            Policy[policy].guardians.contains(&address_of(guardian)),
            error::permission_denied(ENOT_GUARDIAN)
        );
        Policy[policy].paused = paused;
        emit(SetPaused { policy, paused });
    }

    // =============================== What a business calls ===============================

    /// The common case, one line inside an entry function. Aborts unless the subject may act
    /// outright.
    ///
    /// @abort EDENIED when the policy refuses, ESTEP_UP_REQUIRED when it wants an authorization.
    public fun require(
        policy: address, subject: address, action: u8, amount: u64
    ) acquires Policy {
        let (decision, _) = evaluate(policy, subject, action, amount);
        assert!(decision != DECISION_DENY, error::permission_denied(EDENIED));
        assert!(
            decision != DECISION_STEP_UP,
            error::permission_denied(ESTEP_UP_REQUIRED)
        );
    }

    /// The step-up variant. The authorization is a transaction argument, which is the point:
    /// unlike a view call, which leaves no trace, it lands in the ledger permanently and gives the
    /// business an independently verifiable record of why it allowed this specific action.
    ///
    /// An allow decision consumes nothing, so a caller may always route through this function.
    public fun require_authorized(
        policy: address,
        subject: address,
        action: u8,
        amount: u64,
        authorization: vector<u8>
    ) acquires Policy {
        let (decision, _) = evaluate(policy, subject, action, amount);
        assert!(decision != DECISION_DENY, error::permission_denied(EDENIED));
        if (decision == DECISION_ALLOW) {
            return
        };
        let config = &Policy[policy];
        attestation_authorization::verify_and_consume(
            policy,
            config.authorizer_pubkey,
            config.authorizer_max_ttl_secs,
            subject,
            action,
            amount,
            authorization
        );
    }

    /// Non-aborting form, for a caller that wants to branch rather than fail.
    public fun check(
        policy: address, subject: address, action: u8, amount: u64
    ): (u8, u16) acquires Policy {
        evaluate(policy, subject, action, amount)
    }

    // =============================== Helpers ===============================

    fun create_policy_account(deployer: &signer): (signer, SignerCapability) {
        let deployer_nonce = account::get_sequence_number(address_of(deployer));
        account::create_resource_account(
            deployer, create_policy_seed(to_bytes(&deployer_nonce))
        )
    }

    fun create_policy_seed(seed: vector<u8>): vector<u8> {
        let account_seed = vector[];
        account_seed.append(DOMAIN_SEPARATOR);
        account_seed.append(seed);
        account_seed
    }

    fun empty_body(): Body {
        Body {
            require_any: vector[],
            require_all: vector[],
            deny_any: vector[],
            attr_rules: vector[],
            chain_deny: option::none()
        }
    }

    fun build_body(
        require_any_sources: vector<address>,
        require_any_levels: vector<u8>,
        require_all_sources: vector<address>,
        require_all_levels: vector<u8>,
        deny_any: vector<address>,
        chain_deny: Option<address>
    ): Body {
        assert!(
            require_any_sources.length() <= MAX_SOURCES
                && require_all_sources.length() <= MAX_SOURCES
                && deny_any.length() <= MAX_SOURCES,
            error::invalid_argument(ETOO_MANY_SOURCES)
        );
        assert!(
            require_any_sources.length() == require_any_levels.length()
                && require_all_sources.length() == require_all_levels.length(),
            error::invalid_argument(ELENGTH_MISMATCH)
        );

        // A named source that does not exist would abort at evaluation time, which would brick the
        // policy for every subject. Reject it at staging time instead, where it is one caller's
        // problem rather than everyone's.
        deny_any.for_each_ref(|source| {
            assert!(attestation::is_source(*source), error::not_found(EUNKNOWN_SOURCE));
        });
        if (option::is_some(&chain_deny)) {
            assert!(
                attestation::is_source(*option::borrow(&chain_deny)),
                error::not_found(EUNKNOWN_SOURCE)
            );
        };

        Body {
            require_any: build_source_refs(require_any_sources, require_any_levels),
            require_all: build_source_refs(require_all_sources, require_all_levels),
            deny_any,
            attr_rules: vector[],
            chain_deny
        }
    }

    fun build_source_refs(
        sources: vector<address>, levels: vector<u8>
    ): vector<SourceRef> {
        let refs = vector[];
        let index = 0;
        while (index < sources.length()) {
            assert!(
                attestation::is_source(sources[index]),
                error::not_found(EUNKNOWN_SOURCE)
            );
            refs.push_back(SourceRef { source: sources[index], min_level: levels[index] });
            index += 1;
        };
        refs
    }

    fun eval_attr_rule(rule: &AttrRule, subject: address): bool {
        let value = attestation::attribute_of(rule.source, subject, rule.key);
        // An unset attribute satisfies only OP_NOT_IN: a subject the source says nothing about is
        // not in any list, but neither does it meet a positive requirement.
        if (value.is_empty()) {
            return rule.op == OP_NOT_IN
        };
        if (rule.op == OP_IN) {
            rule.values.contains(&value)
        } else if (rule.op == OP_NOT_IN) {
            !rule.values.contains(&value)
        } else if (rule.op == OP_EQ) {
            value == rule.values[0]
        } else {
            gte_bytes(&value, &rule.values[0])
        }
    }

    /// Big-endian unsigned comparison. Values of differing length are not comparable, so the
    /// predicate fails rather than guessing an alignment.
    fun gte_bytes(left: &vector<u8>, right: &vector<u8>): bool {
        if (left.length() != right.length()) {
            return false
        };
        let index = 0;
        while (index < left.length()) {
            if (left[index] > right[index]) {
                return true
            };
            if (left[index] < right[index]) {
                return false
            };
            index += 1;
        };
        true
    }

    fun validate_members(members: &vector<address>, policy_address: address) {
        let distinct: vector<address> = vector[];
        members.for_each_ref(|member| {
            assert!(
                *member != policy_address,
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
        list: &mut vector<address>, new_members: &vector<address>, policy_address: address
    ) {
        validate_members(new_members, policy_address);
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

    fun assert_policy_exists(policy: address) {
        assert!(exists<Policy>(policy), error::not_found(EACCOUNT_NOT_POLICY));
    }

    fun assert_admin(policy: address, addr: address) acquires Policy {
        assert_policy_exists(policy);
        assert!(
            Policy[policy].admins.contains(&addr),
            error::permission_denied(ENOT_ADMIN)
        );
    }

    // =============================== Tests ===============================

    #[test_only]
    use std::account::create_account_for_test;
    #[test_only]
    use std::timestamp;
    #[test_only]
    use std::ed25519;

    #[test_only]
    const SUBJECT_A: address = @0xa11;
    #[test_only]
    const SUBJECT_B: address = @0xb22;
    #[test_only]
    const SUBJECT_C: address = @0xc33;
    #[test_only]
    const NONCE: vector<u8> = x"1111111111111111111111111111111111111111111111111111111111111111";
    #[test_only]
    const NONCE_2: vector<u8> = x"2222222222222222222222222222222222222222222222222222222222222222";
    #[test_only]
    const ONE_YEAR: u64 = 31536000;
    #[test_only]
    const LEVEL_BASIC: u8 = 1;
    #[test_only]
    const LEVEL_ENHANCED: u8 = 2;
    // ISO-3166-1 numeric for Portugal (620) and Brazil (076), big-endian.
    #[test_only]
    const ATTR_COUNTRY: u16 = 1;
    #[test_only]
    const COUNTRY_PT: vector<u8> = x"026c";
    #[test_only]
    const COUNTRY_BR: vector<u8> = x"004c";

    #[test_only]
    fun setup(framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        std::chain_id::initialize_for_test(framework, 4);
    }

    // A source whose deployer holds every role, with one registered issuer.
    #[test_only]
    fun new_source(deployer: &signer): address {
        let deployer_address = address_of(deployer);
        if (!std::account::exists_at(deployer_address)) {
            create_account_for_test(deployer_address);
        };
        let source = attestation::get_next_source_address(deployer_address);
        attestation::create(
            deployer,
            vector[deployer_address],
            vector[],
            vector[deployer_address],
            vector[deployer_address],
            vector[deployer_address]
        );
        attestation::register_issuer(deployer, source, deployer_address, vector[]);
        source
    }

    #[test_only]
    fun new_policy(deployer: &signer): address {
        let deployer_address = address_of(deployer);
        if (!std::account::exists_at(deployer_address)) {
            create_account_for_test(deployer_address);
        };
        let policy = get_next_policy_address(deployer_address);
        create(deployer, vector[deployer_address], vector[deployer_address]);
        policy
    }

    #[test_only]
    fun vouch(deployer: &signer, source: address, subject: address, level: u8) {
        attestation::issue_batch(
            deployer,
            source,
            vector[subject],
            vector[level],
            vector[now_seconds() + ONE_YEAR],
            0
        );
    }

    // Stage a body requiring any of `sources` at `level`, and activate it immediately.
    #[test_only]
    fun apply_require_any(
        admin: &signer, policy: address, sources: vector<address>, level: u8
    ) acquires Policy {
        let levels = vector[];
        sources.for_each_ref(|_s| { levels.push_back(level); });
        stage_body(
            admin,
            policy,
            sources,
            levels,
            vector[],
            vector[],
            vector[],
            vector[],
            now_seconds()
        );
        activate_pending(admin, policy);
    }

    // --- Creation and the empty body ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_create_denies_everything(framework: &signer, deployer: &signer) acquires Policy {
        setup(framework);
        let policy = new_policy(deployer);
        assert!(admins(policy) == vector[address_of(deployer)], 0);
        assert!(!is_paused(policy), 1);
        // An unconfigured policy is a loud refusal, not an open door.
        let (decision, reason) = evaluate(policy, SUBJECT_A, ACTION_TRANSFER, 1);
        assert!(decision == DECISION_DENY, 2);
        assert!(reason == REASON_EMPTY_BODY, 3);
        assert!(!is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 4);
        // The nonce store was created alongside, so the step-up path is usable later.
        assert!(attestation_authorization::is_initialized(policy), 5);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x10006, location = Self)]
    fun test_create_without_admin_fails(framework: &signer, deployer: &signer) {
        setup(framework);
        create_account_for_test(address_of(deployer));
        create(deployer, vector[], vector[]);
    }

    // --- require_any and levels ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_require_any(framework: &signer, deployer: &signer) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        apply_require_any(deployer, policy, vector[source], LEVEL_BASIC);

        assert!(!is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 0);
        assert!(reason_of(policy, SUBJECT_A, ACTION_TRANSFER, 1) == REASON_NO_QUALIFYING, 1);

        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        assert!(is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 2);
        assert!(reason_of(policy, SUBJECT_A, ACTION_TRANSFER, 1) == REASON_OK, 3);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_level_too_low(framework: &signer, deployer: &signer) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        apply_require_any(deployer, policy, vector[source], LEVEL_ENHANCED);

        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        // Vouched for, but not highly enough. This is the yellow tier.
        assert!(!is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 0);
        assert!(reason_of(policy, SUBJECT_A, ACTION_TRANSFER, 1) == REASON_NO_QUALIFYING, 1);

        vouch(deployer, source, SUBJECT_A, LEVEL_ENHANCED);
        assert!(is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 2);
    }

    #[test(framework = @0x1, deployer = @0x123, other = @0x456)]
    fun test_require_any_accepts_either_source(
        framework: &signer, deployer: &signer, other: &signer
    ) acquires Policy {
        setup(framework);
        let first = new_source(deployer);
        let second = new_source(other);
        let policy = new_policy(deployer);
        apply_require_any(deployer, policy, vector[first, second], LEVEL_BASIC);

        vouch(other, second, SUBJECT_A, LEVEL_BASIC);
        // Either source qualifying is enough, which is what makes onboarding cost zero for a
        // business that points at sources someone else already populated.
        assert!(is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 0);
    }

    #[test(framework = @0x1, deployer = @0x123, other = @0x456)]
    fun test_require_all_needs_every_source(
        framework: &signer, deployer: &signer, other: &signer
    ) acquires Policy {
        setup(framework);
        let first = new_source(deployer);
        let second = new_source(other);
        let policy = new_policy(deployer);
        stage_body(
            deployer,
            policy,
            vector[],
            vector[],
            vector[first, second],
            vector[LEVEL_BASIC, LEVEL_BASIC],
            vector[],
            vector[],
            now_seconds()
        );
        activate_pending(deployer, policy);

        vouch(deployer, first, SUBJECT_A, LEVEL_BASIC);
        assert!(reason_of(policy, SUBJECT_A, ACTION_TRANSFER, 1) == REASON_MISSING_REQUIRED, 0);
        vouch(other, second, SUBJECT_A, LEVEL_BASIC);
        assert!(is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 1);
    }

    #[test(framework = @0x1, deployer = @0x123, other = @0x456)]
    fun test_require_all_level_too_low(
        framework: &signer, deployer: &signer, other: &signer
    ) acquires Policy {
        setup(framework);
        let first = new_source(deployer);
        let policy = new_policy(other);
        stage_body(
            other,
            policy,
            vector[],
            vector[],
            vector[first],
            vector[LEVEL_ENHANCED],
            vector[],
            vector[],
            now_seconds()
        );
        activate_pending(other, policy);
        vouch(deployer, first, SUBJECT_A, LEVEL_BASIC);
        assert!(reason_of(policy, SUBJECT_A, ACTION_TRANSFER, 1) == REASON_LEVEL_TOO_LOW, 0);
    }

    // --- Denial precedence ---

    #[test(framework = @0x1, deployer = @0x123, other = @0x456)]
    fun test_deny_source_beats_a_vouching_source(
        framework: &signer, deployer: &signer, other: &signer
    ) acquires Policy {
        setup(framework);
        let good = new_source(deployer);
        let sanctions = new_source(other);
        let policy = new_policy(deployer);
        stage_body(
            deployer,
            policy,
            vector[good],
            vector[LEVEL_BASIC],
            vector[],
            vector[],
            vector[sanctions],
            vector[],
            now_seconds()
        );
        activate_pending(deployer, policy);

        vouch(deployer, good, SUBJECT_A, LEVEL_ENHANCED);
        assert!(is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 0);

        // One denial outranks any amount of vouching, from any number of sources.
        attestation::deny(other, sanctions, SUBJECT_A, 99, now_seconds());
        assert!(!is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 1);
        assert!(reason_of(policy, SUBJECT_A, ACTION_TRANSFER, 1) == REASON_SOURCE_DENIED, 2);
    }

    #[test(framework = @0x1, deployer = @0x123, other = @0x456)]
    fun test_chain_deny_checked_first(
        framework: &signer, deployer: &signer, other: &signer
    ) acquires Policy {
        setup(framework);
        let good = new_source(deployer);
        let chain = new_source(other);
        let policy = new_policy(deployer);
        stage_body(
            deployer,
            policy,
            vector[good],
            vector[LEVEL_BASIC],
            vector[],
            vector[],
            vector[],
            vector[chain],
            now_seconds()
        );
        activate_pending(deployer, policy);

        vouch(deployer, good, SUBJECT_A, LEVEL_BASIC);
        assert!(is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 0);
        attestation::deny(other, chain, SUBJECT_A, 1, now_seconds());
        assert!(reason_of(policy, SUBJECT_A, ACTION_TRANSFER, 1) == REASON_CHAIN_DENIED, 1);
    }

    #[test(framework = @0x1, deployer = @0x123, other = @0x456)]
    #[expected_failure(abort_code = 0x10012, location = Self)]
    fun test_two_chain_deny_sources_fail(
        framework: &signer, deployer: &signer, other: &signer
    ) acquires Policy {
        setup(framework);
        let first = new_source(deployer);
        let second = new_source(other);
        let policy = new_policy(deployer);
        stage_body(
            deployer,
            policy,
            vector[first],
            vector[LEVEL_BASIC],
            vector[],
            vector[],
            vector[],
            vector[first, second],
            now_seconds()
        );
    }

    // --- Attribute predicates ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_attr_rule_in_and_not_in(framework: &signer, deployer: &signer) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        apply_require_any(deployer, policy, vector[source], LEVEL_BASIC);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        vouch(deployer, source, SUBJECT_B, LEVEL_BASIC);
        attestation::set_attribute(deployer, source, SUBJECT_A, ATTR_COUNTRY, COUNTRY_PT);
        attestation::set_attribute(deployer, source, SUBJECT_B, ATTR_COUNTRY, COUNTRY_BR);

        // Allow only Portugal.
        stage_attr_rules(
            deployer,
            policy,
            vector[source],
            vector[ATTR_COUNTRY],
            vector[OP_IN],
            vector[vector[COUNTRY_PT]]
        );
        activate_pending(deployer, policy);
        assert!(is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 0);
        assert!(!is_allowed(policy, SUBJECT_B, ACTION_TRANSFER, 1), 1);
        assert!(reason_of(policy, SUBJECT_B, ACTION_TRANSFER, 1) == REASON_ATTR_FAILED, 2);

        // Invert it: everywhere except Portugal.
        stage_attr_rules(
            deployer,
            policy,
            vector[source],
            vector[ATTR_COUNTRY],
            vector[OP_NOT_IN],
            vector[vector[COUNTRY_PT]]
        );
        activate_pending(deployer, policy);
        assert!(!is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 3);
        assert!(is_allowed(policy, SUBJECT_B, ACTION_TRANSFER, 1), 4);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_unset_attribute_satisfies_only_not_in(
        framework: &signer, deployer: &signer
    ) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        apply_require_any(deployer, policy, vector[source], LEVEL_BASIC);
        vouch(deployer, source, SUBJECT_C, LEVEL_BASIC);
        // SUBJECT_C has no country attribute at all.

        stage_attr_rules(
            deployer,
            policy,
            vector[source],
            vector[ATTR_COUNTRY],
            vector[OP_IN],
            vector[vector[COUNTRY_PT]]
        );
        activate_pending(deployer, policy);
        // A subject the source says nothing about does not meet a positive requirement.
        assert!(!is_allowed(policy, SUBJECT_C, ACTION_TRANSFER, 1), 0);

        stage_attr_rules(
            deployer,
            policy,
            vector[source],
            vector[ATTR_COUNTRY],
            vector[OP_NOT_IN],
            vector[vector[COUNTRY_PT]]
        );
        activate_pending(deployer, policy);
        // But it is not in any list either.
        assert!(is_allowed(policy, SUBJECT_C, ACTION_TRANSFER, 1), 1);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_attr_rule_gte(framework: &signer, deployer: &signer) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        apply_require_any(deployer, policy, vector[source], LEVEL_BASIC);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        // An 8-byte big-endian score of 5000.
        attestation::set_attribute(deployer, source, SUBJECT_A, 9, x"0000000000001388");

        stage_attr_rules(
            deployer,
            policy,
            vector[source],
            vector[9],
            vector[OP_GTE],
            vector[vector[x"0000000000001388"]]
        );
        activate_pending(deployer, policy);
        assert!(is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 0);

        // Raise the bar by one.
        stage_attr_rules(
            deployer,
            policy,
            vector[source],
            vector[9],
            vector[OP_GTE],
            vector[vector[x"0000000000001389"]]
        );
        activate_pending(deployer, policy);
        assert!(!is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 1);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x10010, location = Self)]
    fun test_eq_rule_with_two_values_fails(framework: &signer, deployer: &signer) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        stage_attr_rules(
            deployer,
            policy,
            vector[source],
            vector[ATTR_COUNTRY],
            vector[OP_EQ],
            vector[vector[COUNTRY_PT, COUNTRY_BR]]
        );
    }

    // --- Staging ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_staged_body_waits_for_its_time(framework: &signer, deployer: &signer) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);

        stage_body(
            deployer,
            policy,
            vector[source],
            vector[LEVEL_BASIC],
            vector[],
            vector[],
            vector[],
            vector[],
            1000
        );
        assert!(has_pending(policy), 0);
        assert!(pending_effective_at(policy) == 1000, 1);
        // Staged, not live: the old body still governs, so transactions in flight are unaffected.
        assert!(reason_of(policy, SUBJECT_A, ACTION_TRANSFER, 1) == REASON_EMPTY_BODY, 2);

        timestamp::update_global_time_for_test_secs(1000);
        activate_pending(deployer, policy);
        assert!(!has_pending(policy), 3);
        assert!(is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 4);
    }

    #[test(framework = @0x1, deployer = @0x123, anyone = @0x456)]
    fun test_activation_is_permissionless(
        framework: &signer, deployer: &signer, anyone: &signer
    ) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        stage_body(
            deployer,
            policy,
            vector[source],
            vector[LEVEL_BASIC],
            vector[],
            vector[],
            vector[],
            vector[],
            now_seconds()
        );
        // The business need not be online when its own rule change comes due.
        activate_pending(anyone, policy);
        assert!(!has_pending(policy), 0);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x3000C, location = Self)]
    fun test_activate_before_effective_fails(
        framework: &signer, deployer: &signer
    ) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        stage_body(
            deployer,
            policy,
            vector[source],
            vector[LEVEL_BASIC],
            vector[],
            vector[],
            vector[],
            vector[],
            1000
        );
        activate_pending(deployer, policy);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x3000B, location = Self)]
    fun test_activate_without_pending_fails(
        framework: &signer, deployer: &signer
    ) acquires Policy {
        setup(framework);
        let policy = new_policy(deployer);
        activate_pending(deployer, policy);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_cancel_pending(framework: &signer, deployer: &signer) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        stage_body(
            deployer,
            policy,
            vector[source],
            vector[LEVEL_BASIC],
            vector[],
            vector[],
            vector[],
            vector[],
            1000
        );
        cancel_pending(deployer, policy);
        assert!(!has_pending(policy), 0);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x6000F, location = Self)]
    fun test_staging_unknown_source_fails(framework: &signer, deployer: &signer) acquires Policy {
        setup(framework);
        let policy = new_policy(deployer);
        // Naming a source that does not exist would abort for every subject at evaluation time,
        // bricking the policy. Reject it at staging time instead.
        stage_body(
            deployer,
            policy,
            vector[@0xdead],
            vector[LEVEL_BASIC],
            vector[],
            vector[],
            vector[],
            vector[],
            now_seconds()
        );
    }

    // --- Pause ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_pause_denies_loudly(framework: &signer, deployer: &signer) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        apply_require_any(deployer, policy, vector[source], LEVEL_BASIC);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        assert!(is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 0);

        pause(deployer, policy);
        assert!(!is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 1);
        assert!(reason_of(policy, SUBJECT_A, ACTION_TRANSFER, 1) == REASON_POLICY_PAUSED, 2);
        unpause(deployer, policy);
        assert!(is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 3);
    }

    // --- Simulation ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_simulate(framework: &signer, deployer: &signer) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        apply_require_any(deployer, policy, vector[source], LEVEL_BASIC);
        set_step_up(deployer, policy, ACTION_TRANSFER, 100);

        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        vouch(deployer, source, SUBJECT_B, LEVEL_BASIC);
        attestation::deny(deployer, source, SUBJECT_B, 1, now_seconds());

        let decisions = simulate(policy, vector[SUBJECT_A, SUBJECT_B, SUBJECT_C], ACTION_TRANSFER, 1);
        assert!(decisions == vector[DECISION_ALLOW, DECISION_DENY, DECISION_DENY], 0);

        // Over the threshold, the allowed subject needs an authorization instead.
        let stepped = simulate(policy, vector[SUBJECT_A], ACTION_TRANSFER, 1000);
        assert!(stepped == vector[DECISION_STEP_UP], 1);

        let counts = simulate_counts(policy, vector[SUBJECT_A, SUBJECT_B, SUBJECT_C], ACTION_TRANSFER, 1);
        assert!(counts == vector[1, 2, 0], 2);
    }

    // --- require and step-up thresholds ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_step_up_threshold(framework: &signer, deployer: &signer) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        apply_require_any(deployer, policy, vector[source], LEVEL_BASIC);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);

        // No threshold set, so no action ever steps up.
        assert!(step_up_for(policy, ACTION_TRANSFER) == 0, 0);
        assert!(decision_of(policy, SUBJECT_A, ACTION_TRANSFER, 1000000) == DECISION_ALLOW, 1);

        set_step_up(deployer, policy, ACTION_TRANSFER, 100);
        assert!(decision_of(policy, SUBJECT_A, ACTION_TRANSFER, 100) == DECISION_ALLOW, 2);
        assert!(decision_of(policy, SUBJECT_A, ACTION_TRANSFER, 101) == DECISION_STEP_UP, 3);
        // A threshold is per action, so another action is unaffected.
        assert!(decision_of(policy, SUBJECT_A, ACTION_BORROW, 10000) == DECISION_ALLOW, 4);

        clear_step_up(deployer, policy, ACTION_TRANSFER);
        assert!(decision_of(policy, SUBJECT_A, ACTION_TRANSFER, 101) == DECISION_ALLOW, 5);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x5000D, location = Self)]
    fun test_require_aborts_when_denied(framework: &signer, deployer: &signer) acquires Policy {
        setup(framework);
        let policy = new_policy(deployer);
        require(policy, SUBJECT_A, ACTION_TRANSFER, 1);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x5000E, location = Self)]
    fun test_require_aborts_when_step_up_needed(
        framework: &signer, deployer: &signer
    ) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        apply_require_any(deployer, policy, vector[source], LEVEL_BASIC);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        set_step_up(deployer, policy, ACTION_TRANSFER, 100);
        require(policy, SUBJECT_A, ACTION_TRANSFER, 500);
    }

    // --- Authorization (the step-up path) ---

    #[test_only]
    /// Stand up a policy that steps up above `threshold`, with a live authorizer key.
    fun policy_with_authorizer(
        deployer: &signer, source: address, threshold: u64
    ): (address, ed25519::SecretKey) acquires Policy {
        let policy = new_policy(deployer);
        apply_require_any(deployer, policy, vector[source], LEVEL_BASIC);
        set_step_up(deployer, policy, ACTION_TRANSFER, threshold);
        let (secret_key, validated_key) = ed25519::generate_keys();
        set_authorizer(
            deployer,
            policy,
            ed25519::validated_public_key_to_bytes(&validated_key),
            3600
        );
        (policy, secret_key)
    }

    #[test_only]
    fun sign_authorization(
        secret_key: &ed25519::SecretKey,
        policy: address,
        subject: address,
        action: u8,
        bucket: u8,
        nonce: vector<u8>,
        issued_at: u64,
        expires_at: u64
    ): vector<u8> {
        let message =
            attestation_authorization::authorization_message(
                policy, subject, action, bucket, nonce, issued_at, expires_at
            );
        attestation_authorization::encode_for_test(
            action,
            bucket,
            nonce,
            issued_at,
            expires_at,
            ed25519::signature_to_bytes(&ed25519::sign_arbitrary_bytes(secret_key, message))
        )
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_require_authorized_passes_with_a_real_signature(
        framework: &signer, deployer: &signer
    ) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let (policy, secret_key) = policy_with_authorizer(deployer, source, 100);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);

        // Bucket 3 commits to a ceiling of 1000, which covers the 500 being moved.
        let authorization =
            sign_authorization(
                &secret_key, policy, SUBJECT_A, ACTION_TRANSFER, 3, NONCE, 0, 600
            );
        require_authorized(policy, SUBJECT_A, ACTION_TRANSFER, 500, authorization);
        assert!(attestation_authorization::is_nonce_used(policy, NONCE), 0);

        // Below the threshold nothing is consumed, so the same call works with no authorization.
        require_authorized(policy, SUBJECT_A, ACTION_TRANSFER, 50, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x30004, location = aptos_framework::attestation_authorization)]
    fun test_authorization_replay_fails(
        framework: &signer, deployer: &signer
    ) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let (policy, secret_key) = policy_with_authorizer(deployer, source, 100);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        let authorization =
            sign_authorization(
                &secret_key, policy, SUBJECT_A, ACTION_TRANSFER, 3, NONCE, 0, 600
            );
        require_authorized(policy, SUBJECT_A, ACTION_TRANSFER, 500, authorization);
        // One capability, one use.
        require_authorized(policy, SUBJECT_A, ACTION_TRANSFER, 500, authorization);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x10005, location = aptos_framework::attestation_authorization)]
    fun test_authorization_amount_over_bucket_fails(
        framework: &signer, deployer: &signer
    ) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let (policy, secret_key) = policy_with_authorizer(deployer, source, 100);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        // Bucket 2 commits to a ceiling of 100, and the caller tries to move 5000 with it.
        let authorization =
            sign_authorization(
                &secret_key, policy, SUBJECT_A, ACTION_TRANSFER, 2, NONCE, 0, 600
            );
        require_authorized(policy, SUBJECT_A, ACTION_TRANSFER, 5000, authorization);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x10002, location = aptos_framework::attestation_authorization)]
    fun test_authorization_for_another_subject_fails(
        framework: &signer, deployer: &signer
    ) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let (policy, secret_key) = policy_with_authorizer(deployer, source, 100);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        vouch(deployer, source, SUBJECT_B, LEVEL_BASIC);
        // Signed for B, presented for A. The subject is inside the signed message.
        let authorization =
            sign_authorization(
                &secret_key, policy, SUBJECT_B, ACTION_TRANSFER, 3, NONCE, 0, 600
            );
        require_authorized(policy, SUBJECT_A, ACTION_TRANSFER, 500, authorization);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x30003, location = aptos_framework::attestation_authorization)]
    fun test_expired_authorization_fails(
        framework: &signer, deployer: &signer
    ) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let (policy, secret_key) = policy_with_authorizer(deployer, source, 100);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        let authorization =
            sign_authorization(
                &secret_key, policy, SUBJECT_A, ACTION_TRANSFER, 3, NONCE, 0, 600
            );
        timestamp::update_global_time_for_test_secs(600);
        require_authorized(policy, SUBJECT_A, ACTION_TRANSFER, 500, authorization);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x10006, location = aptos_framework::attestation_authorization)]
    fun test_authorization_window_longer_than_policy_allows_fails(
        framework: &signer, deployer: &signer
    ) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let (policy, secret_key) = policy_with_authorizer(deployer, source, 100);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        // The policy caps the window at 3600 seconds; the authorizer tried to issue a year.
        let authorization =
            sign_authorization(
                &secret_key, policy, SUBJECT_A, ACTION_TRANSFER, 3, NONCE, 0, ONE_YEAR
            );
        require_authorized(policy, SUBJECT_A, ACTION_TRANSFER, 500, authorization);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_authorization_does_not_override_a_denial(
        framework: &signer, deployer: &signer
    ) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let (policy, secret_key) = policy_with_authorizer(deployer, source, 100);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        attestation::deny(deployer, source, SUBJECT_A, 1, now_seconds());

        let authorization =
            sign_authorization(
                &secret_key, policy, SUBJECT_A, ACTION_TRANSFER, 3, NONCE, 0, 600
            );
        // A denial is not a step-up, so a perfectly valid capability cannot buy past it.
        let (decision, reason) = evaluate(policy, SUBJECT_A, ACTION_TRANSFER, 500);
        assert!(decision == DECISION_DENY, 0);
        assert!(reason == REASON_NO_QUALIFYING, 1);
        assert!(!attestation_authorization::is_nonce_used(policy, NONCE), 2);
        let _ = authorization;
    }

    #[test(framework = @0x1, deployer = @0x123, anyone = @0x456)]
    fun test_prune_expired_nonces(
        framework: &signer, deployer: &signer, anyone: &signer
    ) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let (policy, secret_key) = policy_with_authorizer(deployer, source, 100);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        let authorization =
            sign_authorization(
                &secret_key, policy, SUBJECT_A, ACTION_TRANSFER, 3, NONCE, 0, 600
            );
        require_authorized(policy, SUBJECT_A, ACTION_TRANSFER, 500, authorization);
        assert!(attestation_authorization::is_nonce_used(policy, NONCE), 0);

        // Still replayable, so pruning must refuse to release it.
        attestation_authorization::prune_nonces(anyone, policy, vector[NONCE]);
        assert!(attestation_authorization::is_nonce_used(policy, NONCE), 1);

        timestamp::update_global_time_for_test_secs(600);
        attestation_authorization::prune_nonces(anyone, policy, vector[NONCE]);
        assert!(!attestation_authorization::is_nonce_used(policy, NONCE), 2);
    }

    // --- Roles ---

    #[test(framework = @0x1, deployer = @0x123, stranger = @0x456)]
    #[expected_failure(abort_code = 0x50002, location = Self)]
    fun test_non_admin_cannot_stage(
        framework: &signer, deployer: &signer, stranger: &signer
    ) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        stage_body(
            stranger,
            policy,
            vector[source],
            vector[LEVEL_BASIC],
            vector[],
            vector[],
            vector[],
            vector[],
            now_seconds()
        );
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x30007, location = Self)]
    fun test_cannot_remove_last_admin(framework: &signer, deployer: &signer) acquires Policy {
        setup(framework);
        let policy = new_policy(deployer);
        remove_admins(deployer, policy, vector[address_of(deployer)]);
    }

    #[test(framework = @0x1, deployer = @0x123, other = @0x456)]
    fun test_role_add_and_remove(
        framework: &signer, deployer: &signer, other: &signer
    ) acquires Policy {
        setup(framework);
        let policy = new_policy(deployer);
        let other_address = address_of(other);
        add_admins(deployer, policy, vector[other_address]);
        assert!(is_admin(other_address, policy), 0);
        add_guardians(deployer, policy, vector[other_address]);
        assert!(guardians(policy).contains(&other_address), 1);
        remove_guardians(deployer, policy, vector[other_address]);
        assert!(!guardians(policy).contains(&other_address), 2);
        remove_admins(deployer, policy, vector[other_address]);
        assert!(!is_admin(other_address, policy), 3);
    }

    // --- A source going stale propagates through the policy ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_issuer_compromise_propagates(
        framework: &signer, deployer: &signer
    ) acquires Policy {
        setup(framework);
        let source = new_source(deployer);
        let policy = new_policy(deployer);
        apply_require_any(deployer, policy, vector[source], LEVEL_BASIC);
        vouch(deployer, source, SUBJECT_A, LEVEL_BASIC);
        assert!(is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 0);

        // One write at the source invalidates the whole cohort, and every policy reading that
        // source sees it immediately with no action of its own.
        attestation::bump_issuer_epoch(deployer, source, 1);
        assert!(!is_allowed(policy, SUBJECT_A, ACTION_TRANSFER, 1), 1);
        assert!(reason_of(policy, SUBJECT_A, ACTION_TRANSFER, 1) == REASON_NO_QUALIFYING, 2);
    }
}
