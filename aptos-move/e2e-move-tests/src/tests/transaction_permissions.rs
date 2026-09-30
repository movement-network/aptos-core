// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! End-to-end tests for the on-chain transaction permission table
//! (`0x1::transaction_permissions`) and its VM enforcement behind the
//! `TRANSACTION_PERMISSIONS` feature flag.

use crate::{assert_success, assert_vm_status, MoveHarness};
use aptos_framework::BuiltPackage;
use aptos_language_e2e_tests::account::{Account, TransactionBuilder};
use aptos_package_builder::PackageBuilder;
use aptos_types::{
    account_address::AccountAddress,
    on_chain_config::FeatureFlag,
    transaction::{Script, TransactionStatus},
};
use move_core_types::vm_status::StatusCode;

const KIND_DEPLOY: u8 = 0;
const KIND_UPGRADE: u8 = 1;
const KIND_SCRIPT: u8 = 2;
const KIND_OTHER: u8 = 3;

fn harness(feature_on: bool) -> MoveHarness {
    let (enabled, disabled) = if feature_on {
        (vec![FeatureFlag::TRANSACTION_PERMISSIONS], vec![])
    } else {
        (vec![], vec![FeatureFlag::TRANSACTION_PERMISSIONS])
    };
    let mut h = MoveHarness::new_with_features(enabled, disabled);
    // Idempotent: covers genesis builds from before the module existed.
    let framework = h.aptos_framework_account();
    assert_success!(h.run_entry_function(
        &framework,
        str::parse("0x1::transaction_permissions::initialize_extension").unwrap(),
        vec![],
        vec![],
    ));
    h
}

fn insert_rule_for_all(h: &mut MoveHarness, index: u64, kind: u8, allow: bool) {
    let framework = h.aptos_framework_account();
    assert_success!(h.run_entry_function(
        &framework,
        str::parse("0x1::transaction_permissions::insert_rule_for_all").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&index).unwrap(),
            bcs::to_bytes(&kind).unwrap(),
            bcs::to_bytes(&allow).unwrap(),
        ],
    ));
}

fn insert_rule_for_sender(
    h: &mut MoveHarness,
    index: u64,
    sender: AccountAddress,
    kind: u8,
    allow: bool,
) {
    let framework = h.aptos_framework_account();
    assert_success!(h.run_entry_function(
        &framework,
        str::parse("0x1::transaction_permissions::insert_rule_for_sender").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&index).unwrap(),
            bcs::to_bytes(&sender).unwrap(),
            bcs::to_bytes(&kind).unwrap(),
            bcs::to_bytes(&allow).unwrap(),
        ],
    ));
}

fn remove_rule(h: &mut MoveHarness, index: u64) {
    let framework = h.aptos_framework_account();
    assert_success!(h.run_entry_function(
        &framework,
        str::parse("0x1::transaction_permissions::remove_rule").unwrap(),
        vec![],
        vec![bcs::to_bytes(&index).unwrap()],
    ));
}

fn transfer_status(h: &mut MoveHarness, from: &Account, to: AccountAddress) -> TransactionStatus {
    h.run_entry_function(
        from,
        str::parse("0x1::aptos_account::transfer").unwrap(),
        vec![],
        vec![bcs::to_bytes(&to).unwrap(), bcs::to_bytes(&1u64).unwrap()],
    )
}

fn run_noop_script(h: &mut MoveHarness, account: &Account) -> TransactionStatus {
    let mut builder = PackageBuilder::new("Scripts");
    builder.add_source("main.move", "script { fun main() {} }");
    let path = builder.write_to_temp().unwrap();
    let package = BuiltPackage::build(
        path.path().to_owned(),
        aptos_framework::BuildOptions::default(),
    )
    .expect("building script package must succeed");
    let code = package.extract_script_code().into_iter().next().unwrap();
    // Read the sequence number from on-chain state: the harness's own counter
    // also advances on discarded transactions, which these tests produce.
    let seq = h.sequence_number(account.address());
    let txn = TransactionBuilder::new(account.clone())
        .script(Script::new(code, vec![], vec![]))
        .sequence_number(seq)
        .max_gas_amount(1_000_000)
        .gas_unit_price(1)
        .sign();
    h.run(txn)
}

fn publish_status(
    h: &mut MoveHarness,
    account: &Account,
    module_body: &str,
) -> TransactionStatus {
    let addr = *account.address();
    let mut builder = PackageBuilder::new("Package");
    builder.add_source(
        "m.move",
        &format!("module {}::m {{ {} }}", addr.to_hex_literal(), module_body),
    );
    let path = builder.write_to_temp().unwrap();
    h.publish_package(account, path.path())
}

#[test]
fn feature_off_table_is_ignored() {
    let mut h = harness(false);
    insert_rule_for_all(&mut h, 0, KIND_OTHER, false);
    insert_rule_for_all(&mut h, 0, KIND_SCRIPT, false);
    insert_rule_for_all(&mut h, 0, KIND_DEPLOY, false);

    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
    let bob = h.new_account_at(AccountAddress::from_hex_literal("0xb0b").unwrap());
    assert_success!(transfer_status(&mut h, &alice, *bob.address()));
    let status = run_noop_script(&mut h, &alice);
    assert_success!(status);
    assert_success!(publish_status(&mut h, &alice, "public entry fun noop() {}"));
}

#[test]
fn deny_other_blocks_entry_functions_and_admin_recovers() {
    let mut h = harness(true);
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
    let bob = h.new_account_at(AccountAddress::from_hex_literal("0xb0b").unwrap());

    insert_rule_for_all(&mut h, 0, KIND_OTHER, false);
    assert_eq!(
        transfer_status(&mut h, &alice, *bob.address()),
        TransactionStatus::Discard(StatusCode::TRANSACTION_NOT_PERMITTED),
    );

    // The framework account is exempt, so the deny-all table can still be
    // edited (self-bricking guard). Recovery is asserted with bob: alice's
    // harness-side sequence counter was advanced by her discarded attempt.
    remove_rule(&mut h, 0);
    assert_success!(transfer_status(&mut h, &bob, *alice.address()));
}

#[test]
fn first_match_wins_specific_allow_over_wildcard_deny() {
    let mut h = harness(true);
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
    let bob = h.new_account_at(AccountAddress::from_hex_literal("0xb0b").unwrap());

    insert_rule_for_all(&mut h, 0, KIND_OTHER, false);
    insert_rule_for_sender(&mut h, 0, *alice.address(), KIND_OTHER, true);

    assert_success!(transfer_status(&mut h, &alice, *bob.address()));
    assert_eq!(
        transfer_status(&mut h, &bob, *alice.address()),
        TransactionStatus::Discard(StatusCode::TRANSACTION_NOT_PERMITTED),
    );
}

#[test]
fn deny_script_blocks_scripts_only() {
    let mut h = harness(true);
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
    let bob = h.new_account_at(AccountAddress::from_hex_literal("0xb0b").unwrap());

    insert_rule_for_all(&mut h, 0, KIND_SCRIPT, false);
    assert_eq!(
        run_noop_script(&mut h, &alice),
        TransactionStatus::Discard(StatusCode::TRANSACTION_NOT_PERMITTED),
    );
    // Entry functions are untouched by script rules.
    assert_success!(transfer_status(&mut h, &alice, *bob.address()));
}

#[test]
fn deny_deploy_blocks_first_publish_only() {
    let mut h = harness(true);
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());

    insert_rule_for_all(&mut h, 0, KIND_DEPLOY, false);
    assert_vm_status!(
        publish_status(&mut h, &alice, "public entry fun noop() {}"),
        StatusCode::MODULE_PUBLISHING_NOT_PERMITTED
    );

    // Allow deploys again, publish, then freeze upgrades chain-wide.
    remove_rule(&mut h, 0);
    assert_success!(publish_status(&mut h, &alice, "public entry fun noop() {}"));

    insert_rule_for_all(&mut h, 0, KIND_UPGRADE, false);
    assert_vm_status!(
        publish_status(
            &mut h,
            &alice,
            "public entry fun noop() {} public entry fun noop2() {}"
        ),
        StatusCode::MODULE_PUBLISHING_NOT_PERMITTED
    );
}

#[test]
fn deploy_rules_match_specific_sender() {
    let mut h = harness(true);
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
    let bob = h.new_account_at(AccountAddress::from_hex_literal("0xb0b").unwrap());

    insert_rule_for_sender(&mut h, 0, *alice.address(), KIND_DEPLOY, false);
    assert_vm_status!(
        publish_status(&mut h, &alice, "public entry fun noop() {}"),
        StatusCode::MODULE_PUBLISHING_NOT_PERMITTED
    );
    assert_success!(publish_status(&mut h, &bob, "public entry fun noop() {}"));
}
