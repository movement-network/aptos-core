// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{assert_abort, assert_success, tests::common, MoveHarness};
use aptos_framework::{natives::code::UpgradePolicy, BuildOptions, BuiltPackage};
use aptos_language_e2e_tests::account::Account;
use aptos_package_builder::PackageBuilder;
use aptos_types::{
    account_address::{create_resource_address, AccountAddress},
    object_address::create_object_code_deployment_address,
};
use move_core_types::value::MoveValue;
use std::path::PathBuf;

const EPUBLISHER_NOT_APPROVED: u64 = 0x50006;

fn framework_signer() -> Vec<u8> {
    MoveValue::Signer(AccountAddress::ONE)
        .simple_serialize()
        .unwrap()
}

fn initialize(h: &mut MoveHarness, enabled: bool, approved: Vec<AccountAddress>) {
    h.executor.exec(
        "publish_allowlist",
        "initialize",
        vec![],
        vec![
            framework_signer(),
            bcs::to_bytes(&enabled).unwrap(),
            bcs::to_bytes(&approved).unwrap(),
        ],
    );
}

fn set_enabled(h: &mut MoveHarness, enabled: bool) {
    h.executor.exec(
        "publish_allowlist",
        "set_enabled",
        vec![],
        vec![framework_signer(), bcs::to_bytes(&enabled).unwrap()],
    );
}

fn add_approved(h: &mut MoveHarness, addresses: Vec<AccountAddress>) {
    h.executor.exec(
        "publish_allowlist",
        "add_approved_addresses",
        vec![],
        vec![framework_signer(), bcs::to_bytes(&addresses).unwrap()],
    );
}

fn remove_approved(h: &mut MoveHarness, addresses: Vec<AccountAddress>) {
    h.executor.exec(
        "publish_allowlist",
        "remove_approved_addresses",
        vec![],
        vec![framework_signer(), bcs::to_bytes(&addresses).unwrap()],
    );
}

fn simple_package(address: AccountAddress, body: &str) -> PackageBuilder {
    let mut pack = PackageBuilder::new("Package").with_policy(UpgradePolicy::compat());
    pack.add_source(
        "m",
        &format!("module 0x{}::m {{ {} }}", address.to_hex(), body),
    );
    pack
}

fn object_package_path() -> PathBuf {
    common::test_dir_path("object_code_deployment.data/pack_initial")
}

fn object_build_options(object_address: AccountAddress) -> BuildOptions {
    let mut options = BuildOptions::default();
    options
        .named_addresses
        .insert("object".to_string(), object_address);
    options
}

fn next_object_code_address(h: &mut MoveHarness, publisher: &Account) -> AccountAddress {
    let sequence_number = h.sequence_number(publisher.address());
    create_object_code_deployment_address(*publisher.address(), sequence_number + 1)
}

#[test]
fn publishing_unrestricted_when_disabled() {
    let mut h = MoveHarness::new();
    let acc = h.new_account_at(AccountAddress::from_hex_literal("0xcafe").unwrap());
    initialize(&mut h, false, vec![]);

    let pack = simple_package(*acc.address(), "public fun f() {}")
        .write_to_temp()
        .unwrap();
    assert_success!(h.publish_package(&acc, pack.path()));
}

#[test]
fn account_publish_and_upgrade_require_approval() {
    let mut h = MoveHarness::new();
    let approved = h.new_account_at(AccountAddress::from_hex_literal("0xcafe").unwrap());
    let unapproved = h.new_account_at(AccountAddress::from_hex_literal("0xbeef").unwrap());
    initialize(&mut h, true, vec![*approved.address()]);

    let pack = simple_package(*unapproved.address(), "public fun f() {}")
        .write_to_temp()
        .unwrap();
    assert_abort!(
        h.publish_package(&unapproved, pack.path()),
        EPUBLISHER_NOT_APPROVED
    );

    let pack = simple_package(*approved.address(), "public fun f() {}")
        .write_to_temp()
        .unwrap();
    assert_success!(h.publish_package(&approved, pack.path()));

    remove_approved(&mut h, vec![*approved.address()]);
    let upgrade = simple_package(*approved.address(), "public fun f() {} public fun g() {}")
        .write_to_temp()
        .unwrap();
    assert_abort!(
        h.publish_package(&approved, upgrade.path()),
        EPUBLISHER_NOT_APPROVED
    );

    set_enabled(&mut h, false);
    assert_success!(h.publish_package(&approved, upgrade.path()));
}

#[test]
fn object_code_deployment_checks_publisher() {
    let mut h = MoveHarness::new();
    let publisher = h.new_account_at(AccountAddress::from_hex_literal("0xcafe").unwrap());
    initialize(&mut h, true, vec![]);

    let object_address = next_object_code_address(&mut h, &publisher);
    assert_abort!(
        h.object_code_deployment_package(
            &publisher,
            &object_package_path(),
            object_build_options(object_address),
        ),
        EPUBLISHER_NOT_APPROVED
    );

    // The object address itself does not need approval.
    add_approved(&mut h, vec![*publisher.address()]);
    let object_address = next_object_code_address(&mut h, &publisher);
    assert_success!(h.object_code_deployment_package(
        &publisher,
        &object_package_path(),
        object_build_options(object_address),
    ));
    assert_success!(h.object_code_upgrade_package(
        &publisher,
        &object_package_path(),
        object_build_options(object_address),
        object_address,
    ));

    remove_approved(&mut h, vec![*publisher.address()]);
    assert_abort!(
        h.object_code_upgrade_package(
            &publisher,
            &object_package_path(),
            object_build_options(object_address),
            object_address,
        ),
        EPUBLISHER_NOT_APPROVED
    );
}

#[test]
fn resource_account_address_requires_approval() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xcafe").unwrap());
    let resource_address = create_resource_address(*creator.address(), &[]);
    // Code lives at the resource address, so approving the creator is not enough.
    initialize(&mut h, true, vec![*creator.address()]);

    let pack = simple_package(resource_address, "public fun f() {}")
        .write_to_temp()
        .unwrap();
    let package = BuiltPackage::build(pack.path().to_owned(), BuildOptions::default())
        .expect("building package must succeed");
    let code = package.extract_code();
    let metadata = bcs::to_bytes(&package.extract_metadata().unwrap()).unwrap();
    let payload = || {
        aptos_cached_packages::aptos_stdlib::resource_account_create_resource_account_and_publish_package(
            vec![],
            metadata.clone(),
            code.clone(),
        )
    };

    assert_abort!(
        h.run_transaction_payload(&creator, payload()),
        EPUBLISHER_NOT_APPROVED
    );

    add_approved(&mut h, vec![resource_address]);
    assert_success!(h.run_transaction_payload(&creator, payload()));
}
