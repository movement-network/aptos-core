/// An on-chain rule table that decides whether a transaction is allowed to run.
///
/// Each rule matches a sender (a specific account, or all accounts) and a
/// transaction kind (module deploy, module upgrade, script, or anything else)
/// and carries an allow/deny verdict. Rules are evaluated in order and the
/// first match wins; when no rule matches, the transaction is allowed.
///
/// The table is only data here: enforcement happens in the VM, which reads
/// this resource when the `TRANSACTION_PERMISSIONS` feature is enabled. The VM
/// never denies approved governance scripts, framework-reserved or
/// core-resources senders, or `aptos_governance` entry functions, so the table
/// cannot lock out the governance path needed to edit it.
module aptos_framework::transaction_permissions {
    use std::error;
    use std::option::{Self, Option};
    use std::vector;
    use aptos_framework::event;
    use aptos_framework::system_addresses;
    #[test_only]
    use aptos_framework::account::create_signer_for_test;

    friend aptos_framework::genesis;

    /// The rule index is past the end of the table.
    const ERULE_INDEX_OUT_OF_BOUNDS: u64 = 1;
    /// The table already holds the maximum number of rules.
    const ETOO_MANY_RULES: u64 = 2;
    /// The transaction kind is not one of the defined kinds.
    const EINVALID_TRANSACTION_KIND: u64 = 3;
    /// The permission table has not been initialized.
    const ENOT_INITIALIZED: u64 = 4;

    /// Rule evaluation runs unmetered during transaction validation, so the
    /// table length is capped to bound the cost of a scan.
    const MAX_RULES: u64 = 256;

    /// A transaction that publishes a package whose modules do not yet exist.
    const KIND_DEPLOY: u8 = 0;
    /// A transaction that publishes over already-existing modules.
    const KIND_UPGRADE: u8 = 1;
    /// A script transaction.
    const KIND_SCRIPT: u8 = 2;
    /// Any other transaction (entry functions, multisig).
    const KIND_OTHER: u8 = 3;

    struct Rule has copy, drop, store {
        /// The sender this rule applies to; `none` matches all accounts.
        sender: Option<address>,
        /// One of `KIND_DEPLOY`, `KIND_UPGRADE`, `KIND_SCRIPT`, `KIND_OTHER`.
        kind: u8,
        allow: bool,
    }

    /// The ordered rule table, stored under @aptos_framework. Read by the VM
    /// during transaction validation, so its layout must stay in sync with the
    /// Rust-side `OnChainConfig` mirror.
    struct TransactionPermissions has key {
        rules: vector<Rule>,
    }

    #[event]
    struct RuleInserted has drop, store {
        index: u64,
        sender: Option<address>,
        kind: u8,
        allow: bool,
    }

    #[event]
    struct RuleRemoved has drop, store {
        index: u64,
        sender: Option<address>,
        kind: u8,
        allow: bool,
    }

    /// Genesis step: create the empty rule table.
    public(friend) fun initialize(aptos_framework: &signer) {
        system_addresses::assert_aptos_framework(aptos_framework);
        if (!exists<TransactionPermissions>(@aptos_framework)) {
            move_to(aptos_framework, TransactionPermissions { rules: vector[] });
        }
    }

    /// One-off initialization for chains that upgraded past genesis, invoked
    /// through governance or a core-resources script.
    public entry fun initialize_extension(aptos_framework: &signer) {
        initialize(aptos_framework);
    }

    /// Insert a rule for one sender at `index` (0 = evaluated first; `index`
    /// equal to the current length appends). Earlier rules take precedence.
    public entry fun insert_rule_for_sender(
        aptos_framework: &signer,
        index: u64,
        sender: address,
        kind: u8,
        allow: bool,
    ) acquires TransactionPermissions {
        insert_rule(aptos_framework, index, option::some(sender), kind, allow);
    }

    /// Insert a rule matching all senders at `index` (0 = evaluated first;
    /// `index` equal to the current length appends).
    public entry fun insert_rule_for_all(
        aptos_framework: &signer,
        index: u64,
        kind: u8,
        allow: bool,
    ) acquires TransactionPermissions {
        insert_rule(aptos_framework, index, option::none(), kind, allow);
    }

    /// Insert a rule at `index`; `sender` of `none` matches all accounts.
    /// Not an entry function only because the SDK builder cannot encode
    /// `Option` arguments; use the `insert_rule_for_*` entry points or call
    /// this from a governance script.
    public fun insert_rule(
        aptos_framework: &signer,
        index: u64,
        sender: Option<address>,
        kind: u8,
        allow: bool,
    ) acquires TransactionPermissions {
        system_addresses::assert_aptos_framework(aptos_framework);
        assert_initialized();
        assert!(kind <= KIND_OTHER, error::invalid_argument(EINVALID_TRANSACTION_KIND));
        let rules = &mut borrow_global_mut<TransactionPermissions>(@aptos_framework).rules;
        assert!(vector::length(rules) < MAX_RULES, error::out_of_range(ETOO_MANY_RULES));
        assert!(index <= vector::length(rules), error::out_of_range(ERULE_INDEX_OUT_OF_BOUNDS));
        vector::insert(rules, index, Rule { sender, kind, allow });
        event::emit(RuleInserted { index, sender, kind, allow });
    }

    /// Remove the rule at `index`; later rules shift down by one.
    public entry fun remove_rule(
        aptos_framework: &signer,
        index: u64,
    ) acquires TransactionPermissions {
        system_addresses::assert_aptos_framework(aptos_framework);
        assert_initialized();
        let rules = &mut borrow_global_mut<TransactionPermissions>(@aptos_framework).rules;
        assert!(index < vector::length(rules), error::out_of_range(ERULE_INDEX_OUT_OF_BOUNDS));
        let Rule { sender, kind, allow } = vector::remove(rules, index);
        event::emit(RuleRemoved { index, sender, kind, allow });
    }

    #[view]
    /// The full rule table, in evaluation order.
    public fun get_rules(): vector<Rule> acquires TransactionPermissions {
        if (!exists<TransactionPermissions>(@aptos_framework)) {
            return vector[]
        };
        borrow_global<TransactionPermissions>(@aptos_framework).rules
    }

    #[view]
    /// The verdict of the first rule matching `sender` and `kind`, or `none`
    /// when no rule matches.
    public fun check(sender: address, kind: u8): Option<bool> acquires TransactionPermissions {
        assert!(kind <= KIND_OTHER, error::invalid_argument(EINVALID_TRANSACTION_KIND));
        if (!exists<TransactionPermissions>(@aptos_framework)) {
            return option::none()
        };
        let rules = &borrow_global<TransactionPermissions>(@aptos_framework).rules;
        let i = 0;
        let n = vector::length(rules);
        while (i < n) {
            let rule = vector::borrow(rules, i);
            let sender_matches =
                option::is_none(&rule.sender) || *option::borrow(&rule.sender) == sender;
            if (sender_matches && rule.kind == kind) {
                return option::some(rule.allow)
            };
            i = i + 1;
        };
        option::none()
    }

    #[view]
    /// Whether a transaction from `sender` of `kind` is allowed: the first
    /// matching rule's verdict, or true when no rule matches.
    public fun is_allowed(sender: address, kind: u8): bool acquires TransactionPermissions {
        let verdict = check(sender, kind);
        if (option::is_some(&verdict)) {
            *option::borrow(&verdict)
        } else {
            true
        }
    }

    public fun kind_deploy(): u8 { KIND_DEPLOY }

    public fun kind_upgrade(): u8 { KIND_UPGRADE }

    public fun kind_script(): u8 { KIND_SCRIPT }

    public fun kind_other(): u8 { KIND_OTHER }

    public fun max_rules(): u64 { MAX_RULES }

    fun assert_initialized() {
        assert!(
            exists<TransactionPermissions>(@aptos_framework),
            error::not_found(ENOT_INITIALIZED),
        );
    }

    #[test_only]
    fun framework_for_test(): signer {
        let framework = create_signer_for_test(@aptos_framework);
        initialize(&framework);
        framework
    }

    #[test]
    fun test_empty_table_allows_everything() acquires TransactionPermissions {
        framework_for_test();
        assert!(option::is_none(&check(@0xa11ce, KIND_DEPLOY)), 0);
        assert!(is_allowed(@0xa11ce, KIND_DEPLOY), 1);
        assert!(is_allowed(@0xa11ce, KIND_OTHER), 2);
        assert!(vector::is_empty(&get_rules()), 3);
    }

    #[test]
    fun test_uninitialized_views_default_to_allow() acquires TransactionPermissions {
        assert!(vector::is_empty(&get_rules()), 0);
        assert!(option::is_none(&check(@0xa11ce, KIND_SCRIPT)), 1);
        assert!(is_allowed(@0xa11ce, KIND_SCRIPT), 2);
    }

    #[test]
    fun test_initialize_is_idempotent() acquires TransactionPermissions {
        let framework = framework_for_test();
        insert_rule(&framework, 0, option::none(), KIND_SCRIPT, false);
        initialize_extension(&framework);
        assert!(vector::length(&get_rules()) == 1, 0);
    }

    #[test]
    fun test_first_match_wins() acquires TransactionPermissions {
        let framework = framework_for_test();
        // Specific allow shadows the wildcard deny behind it.
        insert_rule_for_all(&framework, 0, KIND_DEPLOY, false);
        insert_rule_for_sender(&framework, 0, @0xa11ce, KIND_DEPLOY, true);
        assert!(is_allowed(@0xa11ce, KIND_DEPLOY), 0);
        assert!(!is_allowed(@0xb0b, KIND_DEPLOY), 1);
        // Other kinds are untouched by deploy rules.
        assert!(option::is_none(&check(@0xb0b, KIND_UPGRADE)), 2);
        assert!(is_allowed(@0xb0b, KIND_SCRIPT), 3);
    }

    #[test]
    fun test_wildcard_matches_all_senders() acquires TransactionPermissions {
        let framework = framework_for_test();
        insert_rule(&framework, 0, option::none(), KIND_SCRIPT, false);
        assert!(!is_allowed(@0xa11ce, KIND_SCRIPT), 0);
        assert!(!is_allowed(@0xb0b, KIND_SCRIPT), 1);
    }

    #[test]
    fun test_remove_shifts_rules_down() acquires TransactionPermissions {
        let framework = framework_for_test();
        insert_rule(&framework, 0, option::some(@0xa11ce), KIND_SCRIPT, true);
        insert_rule(&framework, 1, option::none(), KIND_SCRIPT, false);
        remove_rule(&framework, 0);
        // The wildcard deny is now the first (and only) rule.
        assert!(!is_allowed(@0xa11ce, KIND_SCRIPT), 0);
        assert!(vector::length(&get_rules()) == 1, 1);
    }

    #[test]
    #[expected_failure(abort_code = 0x50003, location = aptos_framework::system_addresses)]
    fun test_insert_requires_framework_signer() acquires TransactionPermissions {
        framework_for_test();
        let mallory = create_signer_for_test(@0xb0b);
        insert_rule(&mallory, 0, option::none(), KIND_SCRIPT, false);
    }

    #[test]
    #[expected_failure(abort_code = 0x50003, location = aptos_framework::system_addresses)]
    fun test_remove_requires_framework_signer() acquires TransactionPermissions {
        let framework = framework_for_test();
        insert_rule(&framework, 0, option::none(), KIND_SCRIPT, false);
        let mallory = create_signer_for_test(@0xb0b);
        remove_rule(&mallory, 0);
    }

    #[test]
    #[expected_failure(abort_code = 0x10003, location = Self)]
    fun test_insert_rejects_unknown_kind() acquires TransactionPermissions {
        let framework = framework_for_test();
        insert_rule(&framework, 0, option::none(), 4, false);
    }

    #[test]
    #[expected_failure(abort_code = 0x20001, location = Self)]
    fun test_insert_rejects_index_past_end() acquires TransactionPermissions {
        let framework = framework_for_test();
        insert_rule(&framework, 1, option::none(), KIND_SCRIPT, false);
    }

    #[test]
    #[expected_failure(abort_code = 0x20001, location = Self)]
    fun test_remove_rejects_out_of_bounds() acquires TransactionPermissions {
        let framework = framework_for_test();
        remove_rule(&framework, 0);
    }

    #[test]
    #[expected_failure(abort_code = 0x60004, location = Self)]
    fun test_insert_requires_initialization() acquires TransactionPermissions {
        let framework = create_signer_for_test(@aptos_framework);
        insert_rule(&framework, 0, option::none(), KIND_SCRIPT, false);
    }

    #[test]
    #[expected_failure(abort_code = 0x20002, location = Self)]
    fun test_table_is_capped() acquires TransactionPermissions {
        let framework = framework_for_test();
        let i = 0;
        while (i <= max_rules()) {
            insert_rule(&framework, 0, option::none(), KIND_OTHER, true);
            i = i + 1;
        };
    }
}
