// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Tests for `ENABLE_FUNCTION_VALUE_BCS_SERIALIZATION`: while the feature is off, BCS bytes of
//! function values cannot be observed by Move code (`bcs` natives and table keys), so no
//! on-chain state can be derived from a function value format which is not yet stable.
//! Storage writes, events, table values and calling stored function values are unaffected.

use crate::{assert_abort, assert_success, tests::common, MoveHarness};
use aptos_framework::BuildOptions;
use aptos_language_e2e_tests::account::Account;
use aptos_package_builder::PackageBuilder;
use aptos_types::{
    account_address::AccountAddress,
    on_chain_config::FeatureFlag,
    transaction::{ExecutionStatus, TransactionStatus},
};
use move_core_types::vm_status::{sub_status::NFE_BCS_SERIALIZATION_FAILURE, AbortLocation};

const SOURCE: &str = r#"
module 0x66::m {
    use std::bcs;
    use std::option;
    use std::signer;
    use aptos_std::aptos_hash;
    use aptos_std::table;
    use aptos_framework::event;

    // A function value can only be stored if it refers to a persistent function.
    #[persistent]
    fun add_to(x: u64, y: u64): u64 { x + y }

    struct Wrapper has copy, drop, store { tag: u8, f: |u64|u64 has copy+store+drop }

    struct KeyedTable has key { t: table::Table<|u64|u64 has copy+store+drop, u64> }

    struct ValuedTable has key { t: table::Table<u64, |u64|u64 has copy+store+drop> }

    struct Holder has key { f: |u64|u64 has copy+store+drop }

    #[event]
    struct Emitted has drop, store { f: |u64|u64 has copy+store+drop }

    fun captured(): |u64|u64 has copy+store+drop {
        |y| add_to(10, y)
    }

    // ---- Values whose BCS bytes are observed by Move code.

    public entry fun to_bytes_captured() {
        let _ = bcs::to_bytes(&captured());
    }

    public entry fun to_bytes_not_captured() {
        // A function value which captures nothing still serializes its identity.
        let f: |u64, u64|u64 has copy+store+drop = add_to;
        let _ = bcs::to_bytes(&f);
    }

    public entry fun to_bytes_nested() {
        let _ = bcs::to_bytes(&vector[Wrapper { tag: 1, f: captured() }]);
    }

    public entry fun serialized_size_captured() {
        let _ = bcs::serialized_size(&captured());
    }

    public entry fun sip_hash_captured() {
        let _ = aptos_hash::sip_hash_from_value(&captured());
    }

    // A value of function type which does not hold a function value is not restricted.
    public entry fun to_bytes_no_function_value() {
        let _ = bcs::to_bytes(&option::none<|u64|u64 has copy+store+drop>());
    }

    // ---- Tables keyed by a function value.

    public entry fun init_keyed_table(s: &signer) {
        move_to(s, KeyedTable { t: table::new() })
    }

    public entry fun table_add_key(s: &signer) acquires KeyedTable {
        let t = &mut borrow_global_mut<KeyedTable>(signer::address_of(s)).t;
        table::add(t, captured(), 1)
    }

    public entry fun table_contains_key(s: &signer) acquires KeyedTable {
        let t = &borrow_global<KeyedTable>(signer::address_of(s)).t;
        assert!(table::contains(t, captured()), 0)
    }

    public entry fun table_borrow_key(s: &signer) acquires KeyedTable {
        let t = &borrow_global<KeyedTable>(signer::address_of(s)).t;
        assert!(*table::borrow(t, captured()) == 1, 0)
    }

    public entry fun table_remove_key(s: &signer) acquires KeyedTable {
        let t = &mut borrow_global_mut<KeyedTable>(signer::address_of(s)).t;
        assert!(table::remove(t, captured()) == 1, 0)
    }

    // ---- Paths whose bytes are not observable by Move code.

    public entry fun table_function_value(s: &signer) {
        let t = table::new<u64, |u64|u64 has copy+store+drop>();
        table::add(&mut t, 1, captured());
        move_to(s, ValuedTable { t })
    }

    public entry fun store_function_value(s: &signer) {
        move_to(s, Holder { f: captured() })
    }

    public entry fun emit_function_value() {
        event::emit(Emitted { f: captured() })
    }

    public entry fun call_stored(s: &signer, x: u64, expected: u64) acquires Holder {
        let f = borrow_global<Holder>(signer::address_of(s)).f;
        assert!(f(x) == expected, 1)
    }
}
"#;

/// Operations which make the BCS bytes of a function value observable to Move code.
const BCS_OPERATIONS: [&str; 5] = [
    "to_bytes_captured",
    "to_bytes_not_captured",
    "to_bytes_nested",
    "serialized_size_captured",
    "sip_hash_captured",
];

/// Table operations with a key containing a function value.
const KEYED_TABLE_OPERATIONS: [&str; 4] = [
    "table_add_key",
    "table_contains_key",
    "table_borrow_key",
    "table_remove_key",
];

fn setup() -> (MoveHarness, Account) {
    let mut builder = PackageBuilder::new("Package");
    builder.add_source("m.move", SOURCE);
    builder.add_local_dep(
        "AptosFramework",
        &common::framework_dir_path("aptos-framework").to_string_lossy(),
    );
    let path = builder.write_to_temp().unwrap();

    let mut h = MoveHarness::new();
    let acc = h.new_account_at(AccountAddress::from_hex_literal("0x66").unwrap());
    assert_success!(h.publish_package_with_options(
        &acc,
        path.path(),
        BuildOptions::move_2().set_latest_language()
    ));
    (h, acc)
}

fn run(h: &mut MoveHarness, acc: &Account, name: &str) -> TransactionStatus {
    h.run_entry_function(
        acc,
        str::parse(&format!("0x66::m::{}", name)).unwrap(),
        vec![],
        vec![],
    )
}

/// A table key which cannot be serialized surfaces as a failure of the table extension,
/// attributed to `0x1::table` - the same shape as any other unusable key.
fn assert_table_key_failure(status: TransactionStatus, name: &str) {
    assert!(
        matches!(
            &status,
            TransactionStatus::Keep(ExecutionStatus::ExecutionFailure {
                location: AbortLocation::Module(module),
                ..
            }) if module.address() == &AccountAddress::ONE && module.name().as_str() == "table"
        ),
        "{}: {:?}",
        name,
        status
    );
}

fn assert_unaffected_operations_succeed(h: &mut MoveHarness, acc: &Account) {
    assert_success!(run(h, acc, "to_bytes_no_function_value"));
    assert_success!(run(h, acc, "store_function_value"));
    assert_success!(run(h, acc, "table_function_value"));
    assert_success!(run(h, acc, "emit_function_value"));
    assert_success!(h.run_entry_function(
        acc,
        str::parse("0x66::m::call_stored").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&5u64).unwrap(),
            bcs::to_bytes(&15u64).unwrap()
        ],
    ));
}

#[test]
fn function_value_bcs_serialization_is_disabled_by_default() {
    let (mut h, acc) = setup();
    assert_success!(run(&mut h, &acc, "init_keyed_table"));

    for name in BCS_OPERATIONS {
        assert_abort!(
            run(&mut h, &acc, name),
            NFE_BCS_SERIALIZATION_FAILURE,
            "{}",
            name
        );
    }
    for name in KEYED_TABLE_OPERATIONS {
        assert_table_key_failure(run(&mut h, &acc, name), name);
    }

    assert_unaffected_operations_succeed(&mut h, &acc);
}

#[test]
fn function_value_bcs_serialization_works_while_enabled() {
    let (mut h, acc) = setup();
    h.enable_features(vec![FeatureFlag::ENABLE_FUNCTION_VALUE_BCS_SERIALIZATION], vec![]);
    assert_success!(run(&mut h, &acc, "init_keyed_table"));

    for name in BCS_OPERATIONS {
        assert_success!(run(&mut h, &acc, name), "{}", name);
    }
    for name in KEYED_TABLE_OPERATIONS {
        assert_success!(run(&mut h, &acc, name), "{}", name);
    }

    assert_unaffected_operations_succeed(&mut h, &acc);
}

/// Entries stored under a function value key while the feature was on cannot be reached
/// once it is turned off again - they are not lost, just unaddressable.
#[test]
fn function_value_table_keys_are_unreachable_while_disabled() {
    let (mut h, acc) = setup();
    h.enable_features(vec![FeatureFlag::ENABLE_FUNCTION_VALUE_BCS_SERIALIZATION], vec![]);
    assert_success!(run(&mut h, &acc, "init_keyed_table"));
    assert_success!(run(&mut h, &acc, "table_add_key"));

    h.enable_features(vec![], vec![FeatureFlag::ENABLE_FUNCTION_VALUE_BCS_SERIALIZATION]);
    for name in ["table_contains_key", "table_borrow_key", "table_remove_key"] {
        assert_table_key_failure(run(&mut h, &acc, name), name);
    }

    h.enable_features(vec![FeatureFlag::ENABLE_FUNCTION_VALUE_BCS_SERIALIZATION], vec![]);
    assert_success!(run(&mut h, &acc, "table_borrow_key"));
    assert_success!(run(&mut h, &acc, "table_remove_key"));
}
