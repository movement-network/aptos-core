// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Clean-room coverage for value-graph gas on deserialize and serialize.
//!
//! Invariant: materializing or walking a Move value must not be free relative
//! to the node count of that value. A compact BCS blob / stored item that
//! expands into many nodes has to cost more once
//! `MeterValueNodesOnDeserialize` is on.

use crate::{assert_success, tests::common, MoveHarness};
use aptos_framework::BuildOptions;
use aptos_language_e2e_tests::account::Account;
use aptos_package_builder::PackageBuilder;
use aptos_types::{account_address::AccountAddress, move_utils::MemberId};
use std::str::FromStr;

/// Elements in the bushy vector. Each `Cell` is a short wrapper chain
/// ending in four `u64`s, so a few hundred input bytes become thousands
/// of value nodes.
const BUSHY_LEN: u64 = 80;
const UNPACK_ITERS: u64 = 40;
const TABLE_KEYS: u64 = 8;

fn bushy_module_source() -> String {
    // Wrapper chain of length 8 (not a 120-deep single-field spine). Each
    // leaf holds four integers so the graph is wide as well as nested.
    r#"
module 0xcafe::bushy {
    use std::vector;
    use std::bcs;
    use aptos_std::copyable_any;
    use aptos_std::table::{Self, Table};

    struct Leaf has copy, drop, store { a: u64, b: u64, c: u64, d: u64 }
    struct W1 has copy, drop, store { x: Leaf }
    struct W2 has copy, drop, store { x: W1 }
    struct W3 has copy, drop, store { x: W2 }
    struct W4 has copy, drop, store { x: W3 }
    struct W5 has copy, drop, store { x: W4 }
    struct W6 has copy, drop, store { x: W5 }
    struct W7 has copy, drop, store { x: W6 }
    struct Cell has copy, drop, store { x: W7 }

    struct Vault has key { cells: vector<Cell> }
    struct Packed has key { item: copyable_any::Any }
    struct Shelf has key { items: Table<u64, vector<Cell>> }

    fun one_cell(): Cell {
        let leaf = Leaf { a: 1, b: 2, c: 3, d: 4 };
        let w1 = W1 { x: leaf };
        let w2 = W2 { x: w1 };
        let w3 = W3 { x: w2 };
        let w4 = W4 { x: w3 };
        let w5 = W5 { x: w4 };
        let w6 = W6 { x: w5 };
        let w7 = W7 { x: w6 };
        Cell { x: w7 }
    }

    fun grow(n: u64): vector<Cell> {
        let out = vector::empty<Cell>();
        let i = 0;
        while (i < n) {
            vector::push_back(&mut out, one_cell());
            i = i + 1;
        };
        out
    }

    public entry fun stash(s: &signer, n: u64) {
        move_to(s, Vault { cells: grow(n) });
    }

    public entry fun peek(addr: address) acquires Vault {
        let v = borrow_global<Vault>(addr);
        let _n = vector::length(&v.cells);
    }

    public entry fun stash_packed(s: &signer, n: u64) {
        move_to(s, Packed { item: copyable_any::pack(grow(n)) });
    }

    public entry fun unpack_packed(addr: address) acquires Packed {
        let Packed { item } = move_from<Packed>(addr);
        let _cells = copyable_any::unpack<vector<Cell>>(item);
    }

    public entry fun unpack_loop(n: u64, rounds: u64) {
        let packed = copyable_any::pack(grow(n));
        let i = 0;
        while (i < rounds) {
            let _cells = copyable_any::unpack<vector<Cell>>(copy packed);
            i = i + 1;
        };
    }

    public entry fun serialize_loop(n: u64, rounds: u64) {
        let cells = grow(n);
        let i = 0;
        while (i < rounds) {
            let _bytes = bcs::to_bytes(&cells);
            i = i + 1;
        };
    }

    public entry fun stash_shelf(s: &signer, n: u64, keys: u64) {
        let items = table::new<u64, vector<Cell>>();
        let k = 0;
        while (k < keys) {
            table::add(&mut items, k, grow(n));
            k = k + 1;
        };
        move_to(s, Shelf { items });
    }

    public entry fun peek_shelf(addr: address, keys: u64) acquires Shelf {
        let shelf = borrow_global<Shelf>(addr);
        let k = 0;
        while (k < keys) {
            let _n = vector::length(table::borrow(&shelf.items, k));
            k = k + 1;
        };
    }
}
"#
    .to_string()
}

fn publish_bushy(h: &mut MoveHarness, acc: &Account) {
    let mut builder = PackageBuilder::new("bushy");
    builder.add_source("bushy", &bushy_module_source());
    builder.add_local_dep(
        "AptosStdlib",
        &common::framework_dir_path("aptos-stdlib").to_string_lossy(),
    );
    builder.add_local_dep(
        "MoveStdlib",
        &common::framework_dir_path("move-stdlib").to_string_lossy(),
    );
    let dir = builder.write_to_temp().unwrap();
    assert_success!(h.publish_package_with_options(
        acc,
        dir.path(),
        BuildOptions::move_2().set_latest_language(),
    ));
}

fn entry(name: &str) -> MemberId {
    MemberId::from_str(&format!("0xcafe::bushy::{name}")).unwrap()
}

/// Two epochs (four hours) crosses the three-hour testing activation.
fn enable_value_graph_billing(h: &mut MoveHarness) {
    h.new_epoch();
    h.new_epoch();
}

fn u64_arg(v: u64) -> Vec<u8> {
    bcs::to_bytes(&v).unwrap()
}

fn addr_arg(addr: &AccountAddress) -> Vec<u8> {
    bcs::to_bytes(addr).unwrap()
}

#[test]
fn from_bytes_pays_for_the_value_graph() {
    let mut h = MoveHarness::new();
    h.modify_gas_schedule(|params| {
        params.vm.txn.max_execution_gas = 40_000_000_000.into();
    });
    let acc = h.new_account_at(AccountAddress::from_hex_literal("0xcafe").unwrap());
    publish_bushy(&mut h, &acc);

    let args = vec![u64_arg(BUSHY_LEN), u64_arg(UNPACK_ITERS)];
    let gas_off = h.evaluate_entry_function_gas(&acc, entry("unpack_loop"), vec![], args.clone());
    enable_value_graph_billing(&mut h);
    let gas_on = h.evaluate_entry_function_gas(&acc, entry("unpack_loop"), vec![], args);

    assert!(
        gas_on > gas_off,
        "from_bytes must not stay free of graph work: on={gas_on} off={gas_off}"
    );
    assert!(
        gas_on > gas_off + 20,
        "repeated unpack should make the walk dominate: on={gas_on} off={gas_off}"
    );
}

#[test]
fn serialize_pays_for_walking_the_value() {
    let mut h = MoveHarness::new();
    h.modify_gas_schedule(|params| {
        params.vm.txn.max_execution_gas = 40_000_000_000.into();
    });
    let acc = h.new_account_at(AccountAddress::from_hex_literal("0xcafe").unwrap());
    publish_bushy(&mut h, &acc);

    let args = vec![u64_arg(BUSHY_LEN), u64_arg(UNPACK_ITERS)];
    let gas_off =
        h.evaluate_entry_function_gas(&acc, entry("serialize_loop"), vec![], args.clone());
    enable_value_graph_billing(&mut h);
    let gas_on = h.evaluate_entry_function_gas(&acc, entry("serialize_loop"), vec![], args);

    assert!(
        gas_on > gas_off,
        "to_bytes must not walk the graph for free: on={gas_on} off={gas_off}"
    );
    assert!(
        gas_on > gas_off + 20,
        "repeated to_bytes should make the walk dominate: on={gas_on} off={gas_off}"
    );
}

#[test]
fn borrow_global_pays_for_the_deserialized_resource() {
    let mut h = MoveHarness::new();
    h.modify_gas_schedule(|params| {
        params.vm.txn.max_execution_gas = 40_000_000_000.into();
    });
    let acc = h.new_account_at(AccountAddress::from_hex_literal("0xcafe").unwrap());
    publish_bushy(&mut h, &acc);

    assert_success!(h.run_entry_function(&acc, entry("stash"), vec![], vec![u64_arg(BUSHY_LEN)]));

    let args = vec![addr_arg(acc.address())];
    let gas_off = h.evaluate_entry_function_gas(&acc, entry("peek"), vec![], args.clone());
    enable_value_graph_billing(&mut h);
    let gas_on = h.evaluate_entry_function_gas(&acc, entry("peek"), vec![], args);

    assert!(
        gas_on > gas_off,
        "resource load must bill the graph: on={gas_on} off={gas_off}"
    );
}

#[test]
fn large_resource_still_loads_when_the_flag_is_on() {
    let mut h = MoveHarness::new();
    h.modify_gas_schedule(|params| {
        params.vm.txn.max_execution_gas = 40_000_000_000.into();
    });
    let acc = h.new_account_at(AccountAddress::from_hex_literal("0xcafe").unwrap());
    publish_bushy(&mut h, &acc);

    assert_success!(h.run_entry_function(&acc, entry("stash"), vec![], vec![u64_arg(BUSHY_LEN)]));
    enable_value_graph_billing(&mut h);
    assert_success!(h.run_entry_function(
        &acc,
        entry("peek"),
        vec![],
        vec![addr_arg(acc.address())],
    ));
}

#[test]
fn table_borrow_pays_for_each_fresh_deserialize() {
    let mut h = MoveHarness::new();
    h.modify_gas_schedule(|params| {
        params.vm.txn.max_execution_gas = 40_000_000_000.into();
    });
    let acc = h.new_account_at(AccountAddress::from_hex_literal("0xcafe").unwrap());
    publish_bushy(&mut h, &acc);

    assert_success!(h.run_entry_function(
        &acc,
        entry("stash_shelf"),
        vec![],
        vec![u64_arg(BUSHY_LEN), u64_arg(TABLE_KEYS)],
    ));

    let args = vec![addr_arg(acc.address()), u64_arg(TABLE_KEYS)];
    let gas_off = h.evaluate_entry_function_gas(&acc, entry("peek_shelf"), vec![], args.clone());
    enable_value_graph_billing(&mut h);
    let gas_on = h.evaluate_entry_function_gas(&acc, entry("peek_shelf"), vec![], args);

    assert!(
        gas_on > gas_off,
        "table deserialize must bill the graph: on={gas_on} off={gas_off}"
    );
}

#[test]
fn large_table_value_still_loads_when_the_flag_is_on() {
    let mut h = MoveHarness::new();
    h.modify_gas_schedule(|params| {
        params.vm.txn.max_execution_gas = 40_000_000_000.into();
    });
    let acc = h.new_account_at(AccountAddress::from_hex_literal("0xcafe").unwrap());
    publish_bushy(&mut h, &acc);

    assert_success!(h.run_entry_function(
        &acc,
        entry("stash_shelf"),
        vec![],
        vec![u64_arg(BUSHY_LEN), u64_arg(1)],
    ));
    enable_value_graph_billing(&mut h);
    assert_success!(h.run_entry_function(
        &acc,
        entry("peek_shelf"),
        vec![],
        vec![addr_arg(acc.address()), u64_arg(1)],
    ));
}

#[test]
fn unpack_is_charged_not_rejected() {
    let mut h = MoveHarness::new();
    h.modify_gas_schedule(|params| {
        params.vm.txn.max_execution_gas = 40_000_000_000.into();
    });
    let acc = h.new_account_at(AccountAddress::from_hex_literal("0xcafe").unwrap());
    publish_bushy(&mut h, &acc);

    assert_success!(h.run_entry_function(
        &acc,
        entry("stash_packed"),
        vec![],
        vec![u64_arg(BUSHY_LEN)],
    ));
    enable_value_graph_billing(&mut h);
    assert_success!(h.run_entry_function(
        &acc,
        entry("unpack_packed"),
        vec![],
        vec![addr_arg(acc.address())],
    ));
}
