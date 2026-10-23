// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

module aptos_framework::allowlist {
    use std::error;
    use std::vector;

    const EALLOWLIST_FULL: u64 = 2;
    // Script admission scans this list in an unmetered prologue.
    const MAX_ALLOWED_SENDERS: u64 = 256;

    struct Allowlist has store {
        enabled: bool,
        senders: vector<address>,
    }

    public fun new(): Allowlist {
        Allowlist { enabled: false, senders: vector[] }
    }

    public fun enable(allowlist: &mut Allowlist): bool {
        if (allowlist.enabled) {
            false
        } else {
            allowlist.enabled = true;
            true
        }
    }

    public fun disable(allowlist: &mut Allowlist): bool {
        if (!allowlist.enabled) {
            false
        } else {
            allowlist.enabled = false;
            true
        }
    }

    public fun add(allowlist: &mut Allowlist, sender: address): bool {
        let (found, _) = vector::index_of(&allowlist.senders, &sender);
        if (found) {
            false
        } else {
            assert!(allowlist.senders.length() < MAX_ALLOWED_SENDERS, error::resource_exhausted(EALLOWLIST_FULL));
            allowlist.senders.push_back(sender);
            true
        }
    }

    public fun remove(allowlist: &mut Allowlist, sender: address): bool {
        let (found, index) = vector::index_of(&allowlist.senders, &sender);
        if (found) {
            allowlist.senders.remove(index);
            true
        } else {
            false
        }
    }

    public fun is_enabled(allowlist: &Allowlist): bool {
        allowlist.enabled
    }

    public fun is_allowed(allowlist: &Allowlist, sender: address): bool {
        vector::contains(&allowlist.senders, &sender)
    }

    public fun get_allowed_senders(allowlist: &Allowlist): vector<address> {
        allowlist.senders
    }

    #[test]
    fun test_enable_disable_preserve_members() {
        let allowlist = new();
        assert!(!is_enabled(&allowlist), 0);
        assert!(add(&mut allowlist, @0xcafe), 1);
        assert!(enable(&mut allowlist), 2);
        assert!(!enable(&mut allowlist), 3);
        assert!(is_enabled(&allowlist), 4);
        assert!(is_allowed(&allowlist, @0xcafe), 5);
        assert!(disable(&mut allowlist), 6);
        assert!(!disable(&mut allowlist), 7);
        assert!(!is_enabled(&allowlist), 8);
        assert!(is_allowed(&allowlist, @0xcafe), 9);
        let Allowlist { enabled: _, senders: _ } = allowlist;
    }

    #[test]
    fun test_capacity_remove_and_refill_preserves_members() {
        let allowlist = new();
        let i = 0;
        while (i < MAX_ALLOWED_SENDERS) {
            let bytes = std::bcs::to_bytes(&@0x100);
            bytes[31] = (i as u8);
            assert!(add(&mut allowlist, aptos_std::from_bcs::to_address(bytes)), 10);
            i = i + 1;
        };
        let before = get_allowed_senders(&allowlist);
        let replacement = @0x200;
        let absent = @0x400;
        let never_touched = @0x300;
        assert!(before.length() == MAX_ALLOWED_SENDERS, 11);
        assert!(!add(&mut allowlist, @0x100), 11);
        assert!(!remove(&mut allowlist, absent), 12);
        assert!(!is_allowed(&allowlist, never_touched), 13);
        assert!(get_allowed_senders(&allowlist) == before, 14);

        let removed = *before.borrow(MAX_ALLOWED_SENDERS - 1);
        let expected = before;
        expected.remove(MAX_ALLOWED_SENDERS - 1);
        assert!(remove(&mut allowlist, removed), 15);
        assert!(get_allowed_senders(&allowlist).length() == MAX_ALLOWED_SENDERS - 1, 16);
        assert!(!is_allowed(&allowlist, removed), 17);
        assert!(get_allowed_senders(&allowlist) == expected, 18);

        assert!(add(&mut allowlist, replacement), 19);
        expected.push_back(replacement);
        assert!(get_allowed_senders(&allowlist).length() == MAX_ALLOWED_SENDERS, 20);
        assert!(is_allowed(&allowlist, replacement), 21);
        assert!(!is_allowed(&allowlist, removed), 22);
        assert!(!is_allowed(&allowlist, never_touched), 23);
        assert!(get_allowed_senders(&allowlist) == expected, 24);
        let Allowlist { enabled: _, senders: _ } = allowlist;
    }

    #[test]
    #[expected_failure(abort_code = 0x90002, location = Self)]
    fun test_capacity() {
        let allowlist = new();
        let i = 0;
        while (i < MAX_ALLOWED_SENDERS) {
            let bytes = std::bcs::to_bytes(&@0x100);
            bytes[31] = (i as u8);
            add(&mut allowlist, aptos_std::from_bcs::to_address(bytes));
            i = i + 1;
        };
        add(&mut allowlist, @0x200);
        abort 0
    }
}
