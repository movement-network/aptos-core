// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

/// Explicit primary-sender membership for standalone Move script execution.
/// Enforcement is enabled and disabled by framework governance.
module aptos_framework::script_execution_allowlist {
    use std::error;
    use aptos_framework::allowlist;
    use aptos_framework::event;
    use aptos_framework::system_addresses;

    const ENOT_INITIALIZED: u64 = 3;

    struct AllowedSenders has key {
        allowlist: allowlist::Allowlist,
    }

    #[event]
    struct AllowedSenderChanged has drop, store {
        sender: address,
        allowed: bool,
    }

    #[event]
    struct EnabledChanged has drop, store {
        enabled: bool,
    }

    /// Create an empty list without changing existing membership or enabling enforcement.
    /// Core-resources administration and governance proposals supply the framework signer.
    public entry fun initialize(framework: &signer) {
        system_addresses::assert_aptos_framework(framework);
        if (!exists<AllowedSenders>(@aptos_framework)) {
            move_to(framework, AllowedSenders { allowlist: allowlist::new() });
        };
    }

    public entry fun enable(framework: &signer) acquires AllowedSenders {
        system_addresses::assert_aptos_framework(framework);
        assert!(exists<AllowedSenders>(@aptos_framework), error::not_found(ENOT_INITIALIZED));
        let allowed_senders = &mut borrow_global_mut<AllowedSenders>(@aptos_framework).allowlist;
        if (allowlist::enable(allowed_senders)) {
            event::emit(EnabledChanged { enabled: true });
        };
    }

    public entry fun disable(framework: &signer) acquires AllowedSenders {
        system_addresses::assert_aptos_framework(framework);
        assert!(exists<AllowedSenders>(@aptos_framework), error::not_found(ENOT_INITIALIZED));
        let allowed_senders = &mut borrow_global_mut<AllowedSenders>(@aptos_framework).allowlist;
        if (allowlist::disable(allowed_senders)) {
            event::emit(EnabledChanged { enabled: false });
        };
    }

    public entry fun add(framework: &signer, sender: address) acquires AllowedSenders {
        system_addresses::assert_aptos_framework(framework);
        assert!(exists<AllowedSenders>(@aptos_framework), error::not_found(ENOT_INITIALIZED));
        if (allowlist::add(&mut borrow_global_mut<AllowedSenders>(@aptos_framework).allowlist, sender)) {
            event::emit(AllowedSenderChanged { sender, allowed: true });
        };
    }

    public entry fun remove(framework: &signer, sender: address) acquires AllowedSenders {
        system_addresses::assert_aptos_framework(framework);
        assert!(exists<AllowedSenders>(@aptos_framework), error::not_found(ENOT_INITIALIZED));
        if (allowlist::remove(&mut borrow_global_mut<AllowedSenders>(@aptos_framework).allowlist, sender)) {
            event::emit(AllowedSenderChanged { sender, allowed: false });
        };
    }

    #[view]
    /// Return configured members; an uninitialized list has no members.
    public fun get_allowed_senders(): vector<address> acquires AllowedSenders {
        if (exists<AllowedSenders>(@aptos_framework)) {
            allowlist::get_allowed_senders(&AllowedSenders[@aptos_framework].allowlist)
        } else {
            vector[]
        }
    }

    #[view]
    /// Check membership only. The module's enabled state determines whether enforcement is active.
    public fun is_allowed(sender: address): bool acquires AllowedSenders {
        exists<AllowedSenders>(@aptos_framework)
            && allowlist::is_allowed(&AllowedSenders[@aptos_framework].allowlist, sender)
    }

    #[view]
    public fun is_enabled(): bool acquires AllowedSenders {
        exists<AllowedSenders>(@aptos_framework) && allowlist::is_enabled(&AllowedSenders[@aptos_framework].allowlist)
    }

    #[test(framework = @aptos_framework)]
    fun test_initialize_preserves_configuration(framework: signer) acquires AllowedSenders {
        assert!(!is_allowed(@0xcafe), 0);
        assert!(!is_enabled(), 1);
        assert!(get_allowed_senders().is_empty(), 1);
        initialize(&framework);
        add(&framework, @0xcafe);
        enable(&framework);
        initialize(&framework);
        assert!(is_allowed(@0xcafe), 2);
        assert!(is_enabled(), 3);
        assert!(get_allowed_senders().length() == 1, 4);
    }

    #[test(attacker = @0xcafe)]
    #[expected_failure(abort_code = 0x50003, location = aptos_framework::system_addresses)]
    fun test_initialize_requires_framework(attacker: signer) {
        initialize(&attacker);
    }

    #[test(framework = @aptos_framework, attacker = @0xcafe)]
    #[expected_failure(abort_code = 0x50003, location = aptos_framework::system_addresses)]
    fun test_edit_requires_framework(framework: signer, attacker: signer) acquires AllowedSenders {
        initialize(&framework);
        add(&attacker, @0xcafe);
    }

    #[test(framework = @aptos_framework)]
    #[expected_failure(abort_code = 0x60003, location = Self)]
    fun test_edit_requires_initialization(framework: signer) acquires AllowedSenders {
        add(&framework, @0xcafe);
    }

    #[test(framework = @aptos_framework, attacker = @0xcafe)]
    #[expected_failure(abort_code = 0x50003, location = aptos_framework::system_addresses)]
    fun test_enable_requires_framework(framework: signer, attacker: signer) acquires AllowedSenders {
        initialize(&framework);
        enable(&attacker);
    }

    #[test(framework = @aptos_framework, attacker = @0xcafe)]
    #[expected_failure(abort_code = 0x50003, location = aptos_framework::system_addresses)]
    fun test_disable_requires_framework(framework: signer, attacker: signer) acquires AllowedSenders {
        initialize(&framework);
        disable(&attacker);
    }

    #[test(framework = @aptos_framework, attacker = @0xcafe)]
    #[expected_failure(abort_code = 0x50003, location = aptos_framework::system_addresses)]
    fun test_remove_requires_framework(framework: signer, attacker: signer) acquires AllowedSenders {
        initialize(&framework);
        remove(&attacker, @0xcafe);
    }
}
