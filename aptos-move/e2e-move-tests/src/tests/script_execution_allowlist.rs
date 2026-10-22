// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{assert_success, MoveHarness};
use aptos_cached_packages::aptos_stdlib;
use aptos_crypto::{ed25519::Ed25519Signature, HashValue};
use aptos_framework::{BuildOptions, BuiltPackage};
use aptos_language_e2e_tests::account::{Account, TransactionBuilder};
use aptos_package_builder::PackageBuilder;
use aptos_types::{
    account_address::AccountAddress,
    account_config::aptos_test_root_address,
    on_chain_config::ApprovedExecutionHashes,
    transaction::{Script, SignedTransaction, TransactionStatus},
};
use aptos_vm::AptosSimulationVM;
use move_core_types::{ident_str, language_storage::StructTag, vm_status::StatusCode};

fn script(source: &str) -> Script {
    let mut builder = PackageBuilder::new("StandaloneScript");
    builder.add_source("script.move", source);
    let path = builder.write_to_temp().unwrap();
    let package = BuiltPackage::build(path.path().to_owned(), BuildOptions::default()).unwrap();
    Script::new(package.extract_script_code().remove(0), vec![], vec![])
}

fn transaction(h: &MoveHarness, account: &Account, code: Script) -> TransactionBuilder {
    TransactionBuilder::new(account.clone())
        .script(code)
        .sequence_number(h.sequence_number(account.address()))
        .max_gas_amount(1_000_000)
        .gas_unit_price(1)
}

fn initialize(h: &mut MoveHarness) {
    let framework = h.aptos_framework_account();
    assert_success!(h.run_entry_function(
        &framework,
        "0x1::script_execution_allowlist::initialize"
            .parse()
            .unwrap(),
        vec![],
        vec![],
    ));
}

fn set_membership(h: &mut MoveHarness, sender: AccountAddress, allowed: bool) {
    let framework = h.aptos_framework_account();
    let function = if allowed { "add" } else { "remove" };
    assert_success!(h.run_entry_function(
        &framework,
        format!("0x1::script_execution_allowlist::{function}")
            .parse()
            .unwrap(),
        vec![],
        vec![bcs::to_bytes(&sender).unwrap()],
    ));
}

fn set_enabled(h: &mut MoveHarness, enabled: bool) {
    let framework = h.aptos_framework_account();
    let function = if enabled { "enable" } else { "disable" };
    assert_success!(h.run_entry_function(
        &framework,
        format!("0x1::script_execution_allowlist::{function}")
            .parse()
            .unwrap(),
        vec![],
        vec![],
    ));
}

fn assert_denied(status: TransactionStatus) {
    assert_eq!(
        status,
        TransactionStatus::Discard(StatusCode::SCRIPT_EXECUTION_NOT_ALLOWED)
    );
}

#[test]
fn enable_membership_revocation_and_entry_functions() {
    let mut h = MoveHarness::new();
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
    let bob = h.new_account_at(AccountAddress::from_hex_literal("0xb0b").unwrap());
    let retained = h.new_account_at(AccountAddress::from_hex_literal("0xcafe").unwrap());
    let code = script("script { fun main() {} }");
    let tx = transaction(&h, &alice, code.clone()).sign();
    assert_success!(h.run(tx)); // Disabled by default, even with no resource.
    initialize(&mut h);
    set_enabled(&mut h, true);
    let tx = transaction(&h, &alice, code.clone()).sign();
    assert_denied(h.run(tx)); // An enabled empty list fails closed.
    set_membership(&mut h, *retained.address(), true);
    set_membership(&mut h, *alice.address(), true);
    // Bob is never passed to add or remove, even while other members are present.
    let tx = transaction(&h, &bob, code.clone()).sign();
    assert_denied(h.run(tx));
    let tx = transaction(&h, &alice, code.clone()).sign();
    assert_success!(h.run(tx));
    set_membership(&mut h, *alice.address(), false);
    let tx = transaction(&h, &alice, code.clone()).sign();
    assert_denied(h.run(tx)); // Explicitly removed.
    let tx = transaction(&h, &bob, code.clone()).sign();
    assert_denied(h.run(tx)); // Never added or removed.
    let tx = transaction(&h, &retained, code.clone()).sign();
    assert_success!(h.run(tx)); // The list is still populated and enforced.
    let entry = TransactionBuilder::new(alice.clone())
        .payload(aptos_stdlib::aptos_coin_transfer(*bob.address(), 1))
        .sequence_number(h.sequence_number(alice.address()))
        .max_gas_amount(1_000_000)
        .gas_unit_price(1)
        .sign();
    assert_success!(h.run(entry));
    set_enabled(&mut h, false);
    let tx = transaction(&h, &alice, code).sign();
    assert_success!(h.run(tx));
}

#[test]
fn multi_agent_and_sponsored_scripts_authorize_only_primary_sender() {
    let code = script("script { fun main(_primary: signer, _secondary: signer) {} }");
    let membership_cases = [
        (false, false, false),
        (false, false, true),
        (false, true, false),
        (false, true, true),
        (true, false, false),
        (true, false, true),
        (true, true, false),
        (true, true, true),
    ];
    for sponsored in [false, true] {
        for (primary_allowed, secondary_allowed, fee_payer_allowed) in membership_cases {
            let mut h = MoveHarness::new();
            let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
            let bob = h.new_account_at(AccountAddress::from_hex_literal("0xb0b").unwrap());
            let payer = h.new_account_at(AccountAddress::from_hex_literal("0xcafe").unwrap());
            initialize(&mut h);
            set_enabled(&mut h, true);
            if primary_allowed {
                set_membership(&mut h, *alice.address(), true);
            }
            if secondary_allowed {
                set_membership(&mut h, *bob.address(), true);
            }
            if fee_payer_allowed {
                set_membership(&mut h, *payer.address(), true);
            }

            let signed = |h: &MoveHarness| {
                let builder =
                    transaction(h, &alice, code.clone()).secondary_signers(vec![bob.clone()]);
                if sponsored {
                    builder.fee_payer(payer.clone()).sign_fee_payer()
                } else {
                    builder.sign_multi_agent()
                }
            };
            let tx = signed(&h);
            if primary_allowed {
                assert_success!(h.run(tx));
                set_membership(&mut h, *alice.address(), false);
                assert_denied(h.run(signed(&h)));
            } else {
                assert_denied(h.run(tx));
            }
        }
    }
}

#[test]
fn approved_script_hash_and_privileged_senders_do_not_bypass_membership() {
    let mut h = MoveHarness::new();
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
    let root = h.new_account_at(aptos_test_root_address());
    let framework = h.aptos_framework_account();
    let code = script("script { fun main() {} }");
    initialize(&mut h);
    set_enabled(&mut h, true);
    h.set_resource(
        AccountAddress::ONE,
        StructTag {
            address: AccountAddress::ONE,
            module: ident_str!("aptos_governance").to_owned(),
            name: ident_str!("ApprovedExecutionHashes").to_owned(),
            type_args: vec![],
        },
        &ApprovedExecutionHashes {
            entries: vec![(0, HashValue::sha3_256_of(code.code()).to_vec())],
        },
    );
    for account in [&alice, &root, &framework] {
        let tx = transaction(&h, account, code.clone()).sign();
        assert_denied(h.run(tx));
    }
    initialize(&mut h);
    set_membership(&mut h, *root.address(), true);
    let tx = transaction(&h, &root, code).sign();
    assert_success!(h.run(tx));
}

#[test]
fn validation_and_simulation_reject_unlisted_script_sender() {
    assert_eq!(StatusCode::SCRIPT_EXECUTION_NOT_ALLOWED as u64, 923);
    let mut h = MoveHarness::new();
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
    let code = script("script { fun main() {} }");
    initialize(&mut h);
    set_enabled(&mut h, true);
    let sequence_before = h.sequence_number(alice.address());
    // A future sequence number must not turn a denial into mempool admission.
    let tx = transaction(&h, &alice, code.clone())
        .sequence_number(100)
        .sign();
    assert_eq!(
        h.executor.validate_transaction(tx).status(),
        Some(StatusCode::SCRIPT_EXECUTION_NOT_ALLOWED)
    );
    let raw = transaction(&h, &alice, code).raw();
    let simulation = SignedTransaction::new(
        raw,
        alice.pubkey.as_ed25519().unwrap(),
        Ed25519Signature::dummy_signature(),
    );
    let (_, output) = AptosSimulationVM::create_vm_and_simulate_signed_transaction(
        &simulation,
        h.executor.get_state_view(),
    );
    assert_eq!(
        output.status(),
        &TransactionStatus::Discard(StatusCode::SCRIPT_EXECUTION_NOT_ALLOWED)
    );
    assert_eq!(h.sequence_number(alice.address()), sequence_before);
}
