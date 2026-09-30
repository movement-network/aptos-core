/// Governance-controlled allowlist of addresses that may publish or upgrade packages.
/// Framework reserved addresses (0x1-0xa) are always allowed.
module aptos_framework::publish_allowlist {
    use std::error;
    use std::vector;

    use aptos_framework::system_addresses;

    friend aptos_framework::code;
    friend aptos_framework::object_code_deployment;

    /// The allowlist has already been initialized.
    const EALLOWLIST_ALREADY_EXISTS: u64 = 1;
    /// The allowlist has not been initialized.
    const EALLOWLIST_DOES_NOT_EXIST: u64 = 2;
    /// An address was supplied more than once.
    const EDUPLICATE_ADDRESS: u64 = 3;
    /// The address is already approved.
    const EADDRESS_ALREADY_APPROVED: u64 = 4;
    /// The address is not approved.
    const EADDRESS_NOT_APPROVED: u64 = 5;
    /// The publisher is not approved to publish or upgrade packages.
    const EPUBLISHER_NOT_APPROVED: u64 = 6;

    struct PublishAllowlist has key {
        enabled: bool,
        approved_addresses: vector<address>,
    }

    public fun initialize(
        aptos_framework: &signer,
        enabled: bool,
        approved_addresses: vector<address>,
    ) {
        system_addresses::assert_aptos_framework(aptos_framework);
        assert!(
            !exists<PublishAllowlist>(@aptos_framework),
            error::already_exists(EALLOWLIST_ALREADY_EXISTS),
        );
        assert_unique(&approved_addresses);
        move_to(aptos_framework, PublishAllowlist { enabled, approved_addresses });
    }

    public fun set_enabled(aptos_framework: &signer, enabled: bool) acquires PublishAllowlist {
        system_addresses::assert_aptos_framework(aptos_framework);
        borrow_allowlist_mut().enabled = enabled;
    }

    public fun add_approved_addresses(
        aptos_framework: &signer,
        addresses: vector<address>,
    ) acquires PublishAllowlist {
        system_addresses::assert_aptos_framework(aptos_framework);
        assert_unique(&addresses);
        let approved = &mut borrow_allowlist_mut().approved_addresses;
        vector::for_each(addresses, |addr| {
            assert!(
                !vector::contains(approved, &addr),
                error::already_exists(EADDRESS_ALREADY_APPROVED),
            );
            vector::push_back(approved, addr);
        });
    }

    public fun remove_approved_addresses(
        aptos_framework: &signer,
        addresses: vector<address>,
    ) acquires PublishAllowlist {
        system_addresses::assert_aptos_framework(aptos_framework);
        let approved = &mut borrow_allowlist_mut().approved_addresses;
        vector::for_each(addresses, |addr| {
            let (found, index) = vector::index_of(approved, &addr);
            assert!(found, error::not_found(EADDRESS_NOT_APPROVED));
            vector::remove(approved, index);
        });
    }

    #[view]
    public fun is_enabled(): bool acquires PublishAllowlist {
        exists<PublishAllowlist>(@aptos_framework)
            && borrow_global<PublishAllowlist>(@aptos_framework).enabled
    }

    #[view]
    public fun approved_addresses(): vector<address> acquires PublishAllowlist {
        if (!exists<PublishAllowlist>(@aptos_framework)) {
            return vector[]
        };
        borrow_global<PublishAllowlist>(@aptos_framework).approved_addresses
    }

    #[view]
    public fun is_publisher_allowed(publisher: address): bool acquires PublishAllowlist {
        if (!is_enabled() || system_addresses::is_framework_reserved_address(publisher)) {
            return true
        };
        vector::contains(
            &borrow_global<PublishAllowlist>(@aptos_framework).approved_addresses,
            &publisher,
        )
    }

    public(friend) fun assert_publisher_allowed(publisher: address) acquires PublishAllowlist {
        assert!(
            is_publisher_allowed(publisher),
            error::permission_denied(EPUBLISHER_NOT_APPROVED),
        );
    }

    inline fun borrow_allowlist_mut(): &mut PublishAllowlist acquires PublishAllowlist {
        assert!(
            exists<PublishAllowlist>(@aptos_framework),
            error::not_found(EALLOWLIST_DOES_NOT_EXIST),
        );
        borrow_global_mut<PublishAllowlist>(@aptos_framework)
    }

    fun assert_unique(addresses: &vector<address>) {
        let len = vector::length(addresses);
        let i = 0;
        while (i < len) {
            let j = i + 1;
            while (j < len) {
                assert!(
                    vector::borrow(addresses, i) != vector::borrow(addresses, j),
                    error::invalid_argument(EDUPLICATE_ADDRESS),
                );
                j = j + 1;
            };
            i = i + 1;
        };
    }

    #[test]
    fun test_uninitialized_allows_everyone() acquires PublishAllowlist {
        assert!(!is_enabled(), 0);
        assert!(is_publisher_allowed(@0xcafe), 1);
        assert!(approved_addresses() == vector[], 2);
    }

    #[test(aptos_framework = @aptos_framework)]
    fun test_lifecycle(aptos_framework: &signer) acquires PublishAllowlist {
        initialize(aptos_framework, false, vector[@0x42]);
        assert!(!is_enabled(), 0);
        assert!(is_publisher_allowed(@0xcafe), 1);

        set_enabled(aptos_framework, true);
        assert!(is_publisher_allowed(@0x42), 2);
        assert!(!is_publisher_allowed(@0xcafe), 3);
        assert!(is_publisher_allowed(@0x1), 4);
        assert!(is_publisher_allowed(@0x7), 5);

        add_approved_addresses(aptos_framework, vector[@0xcafe]);
        assert!(is_publisher_allowed(@0xcafe), 6);

        remove_approved_addresses(aptos_framework, vector[@0x42]);
        assert!(!is_publisher_allowed(@0x42), 7);
        assert!(approved_addresses() == vector[@0xcafe], 8);

        set_enabled(aptos_framework, false);
        assert!(is_publisher_allowed(@0x42), 9);
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 0x10003, location = Self)]
    fun test_duplicate_addresses_rejected(aptos_framework: &signer) {
        initialize(aptos_framework, true, vector[@0x42, @0x42]);
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 0x80004, location = Self)]
    fun test_add_existing_rejected(aptos_framework: &signer) acquires PublishAllowlist {
        initialize(aptos_framework, true, vector[@0x42]);
        add_approved_addresses(aptos_framework, vector[@0x42]);
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 0x60005, location = Self)]
    fun test_remove_missing_rejected(aptos_framework: &signer) acquires PublishAllowlist {
        initialize(aptos_framework, true, vector[]);
        remove_approved_addresses(aptos_framework, vector[@0x42]);
    }

    #[test(other = @0xcafe)]
    #[expected_failure(abort_code = 0x50003, location = aptos_framework::system_addresses)]
    fun test_non_framework_cannot_initialize(other: &signer) {
        initialize(other, true, vector[]);
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 0x50006, location = Self)]
    fun test_assert_rejects_unapproved(aptos_framework: &signer) acquires PublishAllowlist {
        initialize(aptos_framework, true, vector[]);
        assert_publisher_allowed(@0xcafe);
    }
}
