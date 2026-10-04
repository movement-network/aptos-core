// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! End-to-end tests that exercise serialization of enum (variant) values whose
//! layout changes across a package upgrade.
//!
//! A `RuntimeVariants` value carries a `u16` variant tag. Serialization must
//! agree with strict deserialization about which tags are valid: if a value
//! could be serialized against a layout that does not describe its tag (for
//! example a variant added by an upgrade), the resulting bytes would be
//! rejected on read, creating a serialize/deserialize asymmetry that can wedge
//! state or fail a block.
//!
//! These tests upgrade a module to add an enum variant and then store, read
//! back, and mutate a resource holding that enum at the newly added (higher)
//! variant tag, driving the value through the full serialize-on-write /
//! deserialize-on-read path in the VM. (The out-of-range rejection itself is
//! unit-tested directly in `move-vm-types`, since the bytecode verifier
//! prevents Move source from ever packing an invalid variant.)

use crate::{assert_success, MoveHarness};
use aptos_framework::BuildOptions;
use aptos_language_e2e_tests::account::Account;
use aptos_package_builder::PackageBuilder;
use aptos_types::{
    account_address::AccountAddress,
    transaction::{SignedTransaction, TransactionStatus},
};
use move_core_types::{
    identifier::Identifier,
    language_storage::StructTag,
};
use serde::Deserialize;

/// Rust mirror of `0x815::m::Data`. Variant order must match the Move
/// declaration so BCS variant indices line up (`V1` == tag 0, `V2` == tag 1).
#[derive(Deserialize, Debug, PartialEq)]
enum Data {
    V1 { x: u64 },
    V2 { x: u64, y: u8 },
}

/// Rust mirror of `0x815::m::Box`.
#[derive(Deserialize, Debug, PartialEq)]
struct Box {
    data: Data,
}

// Module before the upgrade: a single enum variant `V1`.
const MODULE_V1: &str = r#"
    module 0x815::m {
        enum Data has drop, store {
            V1 { x: u64 },
        }
        struct Box has key {
            data: Data,
        }
        public entry fun init(s: &signer, x: u64) {
            move_to(s, Box { data: Data::V1 { x } });
        }
        public entry fun set_v1(addr: address, x: u64) acquires Box {
            borrow_global_mut<Box>(addr).data = Data::V1 { x };
        }
    }
"#;

// Module after a compatible upgrade: adds a second enum variant `V2` and a
// setter that stores a value at the newly introduced (higher) tag.
const MODULE_V2: &str = r#"
    module 0x815::m {
        enum Data has drop, store {
            V1 { x: u64 },
            V2 { x: u64, y: u8 },
        }
        struct Box has key {
            data: Data,
        }
        public entry fun init(s: &signer, x: u64) {
            move_to(s, Box { data: Data::V1 { x } });
        }
        public entry fun set_v1(addr: address, x: u64) acquires Box {
            borrow_global_mut<Box>(addr).data = Data::V1 { x };
        }
        public entry fun set_v2(addr: address, x: u64, y: u8) acquires Box {
            borrow_global_mut<Box>(addr).data = Data::V2 { x, y };
        }
    }
"#;

fn box_struct_tag(addr: AccountAddress) -> StructTag {
    StructTag {
        address: addr,
        module: Identifier::new("m").unwrap(),
        name: Identifier::new("Box").unwrap(),
        type_args: vec![],
    }
}

#[test]
fn enum_variant_tag_serialization() {
    let mut h = MoveHarness::new();
    let addr = AccountAddress::from_hex_literal("0x815").unwrap();
    let acc = h.new_account_at(addr);

    // Publish V1 and store the resource at the only variant (tag 0). This
    // serializes the enum value on write.
    assert_success!(publish(&mut h, &acc, MODULE_V1));
    assert_success!(h.run_entry_function(
        &acc,
        str::parse("0x815::m::init").unwrap(),
        vec![],
        vec![bcs::to_bytes(&7u64).unwrap()],
    ));
    assert_eq!(
        h.read_resource::<Box>(&addr, box_struct_tag(addr)).unwrap(),
        Box {
            data: Data::V1 { x: 7 }
        },
        "V1 value round-trips through serialize-on-write / deserialize-on-read",
    );

    // Compatible upgrade that adds variant `V2`.
    assert_success!(publish(&mut h, &acc, MODULE_V2));

    // Overwrite the resource with the newly added variant (tag 1). Serializing
    // this value drives the `RuntimeVariants` path with a tag that did not exist
    // in the pre-upgrade layout.
    assert_success!(h.run_entry_function(
        &acc,
        str::parse("0x815::m::set_v2").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&addr).unwrap(),
            bcs::to_bytes(&9u64).unwrap(),
            bcs::to_bytes(&3u8).unwrap(),
        ],
    ));
    assert_eq!(
        h.read_resource::<Box>(&addr, box_struct_tag(addr)).unwrap(),
        Box {
            data: Data::V2 { x: 9, y: 3 }
        },
        "newly added variant round-trips after upgrade",
    );

    // The original variant must still serialize/deserialize after the upgrade.
    assert_success!(h.run_entry_function(
        &acc,
        str::parse("0x815::m::set_v1").unwrap(),
        vec![],
        vec![bcs::to_bytes(&addr).unwrap(), bcs::to_bytes(&11u64).unwrap()],
    ));
    assert_eq!(
        h.read_resource::<Box>(&addr, box_struct_tag(addr)).unwrap(),
        Box {
            data: Data::V1 { x: 11 }
        },
        "pre-existing variant still round-trips after upgrade",
    );
}

#[test]
fn enum_variant_tag_serialization_same_block_as_upgrade() {
    // The riskiest window is a value carrying a just-added variant tag being
    // serialized in the same block that introduced the variant, where a stale
    // cached layout could be observed. Publish V1 and initialize first, then run
    // the upgrade and a store at the new variant together in one block.
    let mut h = MoveHarness::new();
    let addr = AccountAddress::from_hex_literal("0x815").unwrap();
    let acc = h.new_account_at(addr);

    assert_success!(publish(&mut h, &acc, MODULE_V1));
    assert_success!(h.run_entry_function(
        &acc,
        str::parse("0x815::m::init").unwrap(),
        vec![],
        vec![bcs::to_bytes(&1u64).unwrap()],
    ));

    let upgrade_txn = create_publish_txn(&mut h, &acc, MODULE_V2);
    let set_v2_txn = h.create_entry_function(
        &acc,
        str::parse("0x815::m::set_v2").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&addr).unwrap(),
            bcs::to_bytes(&42u64).unwrap(),
            bcs::to_bytes(&7u8).unwrap(),
        ],
    );
    for status in h.run_block(vec![upgrade_txn, set_v2_txn]) {
        assert_success!(status);
    }

    assert_eq!(
        h.read_resource::<Box>(&addr, box_struct_tag(addr)).unwrap(),
        Box {
            data: Data::V2 { x: 42, y: 7 }
        },
        "new variant stored in the same block as the upgrade round-trips",
    );
}

fn publish(h: &mut MoveHarness, account: &Account, source: &str) -> TransactionStatus {
    let mut builder = PackageBuilder::new("Package");
    builder.add_source("m.move", source);
    let path = builder.write_to_temp().unwrap();
    h.publish_package_with_options(account, path.path(), BuildOptions::move_2())
}

fn create_publish_txn(h: &mut MoveHarness, account: &Account, source: &str) -> SignedTransaction {
    let mut builder = PackageBuilder::new("Package");
    builder.add_source("m.move", source);
    let path = builder.write_to_temp().unwrap();
    h.create_publish_package(
        account,
        path.path(),
        Some(BuildOptions::move_2()),
        |_| {},
    )
}
