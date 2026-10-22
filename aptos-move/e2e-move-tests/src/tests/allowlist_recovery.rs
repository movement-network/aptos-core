// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{assert_success, MoveHarness};
use aptos_cached_packages::aptos_stdlib;
use aptos_crypto::HashValue;
use aptos_framework::{BuildOptions, BuiltPackage};
use aptos_language_e2e_tests::account::{Account, TransactionBuilder};
use aptos_package_builder::PackageBuilder;
use aptos_types::{
    account_address::AccountAddress,
    account_config::aptos_test_root_address,
    on_chain_config::{ConfigurationResource, OnChainConfig},
    transaction::{
        ExecutionStatus, Script, TransactionArgument, TransactionPayload, TransactionStatus,
    },
};
use move_core_types::{
    ident_str,
    language_storage::ModuleId,
    vm_status::{AbortLocation, StatusCode},
};
use std::path::Path;

type Package = (Vec<u8>, Vec<Vec<u8>>);

fn compile_script(source: &str) -> Vec<u8> {
    let mut builder = PackageBuilder::new("RehearsalScript");
    let framework = Path::new(env!("CARGO_MANIFEST_DIR")).join("../framework/aptos-framework");
    builder.add_local_dep("AptosFramework", framework.to_str().unwrap());
    builder.add_source("rehearsal.move", source);
    let path = builder.write_to_temp().unwrap();
    BuiltPackage::build(path.path().to_owned(), BuildOptions::default())
        .unwrap()
        .extract_script_code()
        .remove(0)
}

fn migration(name: &str) -> Vec<u8> {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../movement-migration");
    let path = match name.strip_prefix("script:") {
        Some(file) => root.join("script-execution-allowlist/scripts").join(file),
        None => root.join("governance").join(name),
    };
    compile_script(&std::fs::read_to_string(path).unwrap())
}

fn run(h: &mut MoveHarness, sender: &Account, payload: TransactionPayload) -> TransactionStatus {
    // Advance actual chain time before reconfiguration, and use committed sequence numbers
    // so discarded transactions cannot advance a local transaction-builder counter.
    h.executor.new_block();
    let tx = TransactionBuilder::new(sender.clone())
        .payload(payload)
        .sequence_number(h.sequence_number(sender.address()))
        .max_gas_amount(1_000_000)
        .gas_unit_price(1)
        .sign();
    h.run(tx)
}

fn script(
    h: &mut MoveHarness,
    sender: &Account,
    code: &[u8],
    args: Vec<TransactionArgument>,
) -> TransactionStatus {
    run(
        h,
        sender,
        TransactionPayload::Script(Script::new(code.to_vec(), vec![], args)),
    )
}

fn member(h: &mut MoveHarness, core: &Account, helper: &[u8], sender: &Account) {
    assert_success!(script(h, core, helper, vec![TransactionArgument::Address(
        *sender.address()
    ),]));
}

fn epoch(h: &MoveHarness) -> u64 {
    h.read_resource::<ConfigurationResource>(
        &AccountAddress::ONE,
        ConfigurationResource::struct_tag(),
    )
    .unwrap()
    .epoch()
}

fn enabled(h: &mut MoveHarness, scripts: bool, publishing: bool) {
    for (function, expected) in [
        ("script_execution_allowlist::is_enabled", scripts),
        ("code::is_publish_allowlist_enabled", publishing),
    ] {
        let result =
            h.execute_view_function(format!("0x1::{function}").parse().unwrap(), vec![], vec![]);
        assert_eq!(
            bcs::from_bytes::<bool>(&result.values.unwrap()[0]).unwrap(),
            expected
        );
    }
}

fn preflight_denied(status: TransactionStatus, expected: u64) {
    assert!(
        matches!(status, TransactionStatus::Keep(ExecutionStatus::MoveAbort {
        location: AbortLocation::Script, code, ..
    }) if code == expected),
        "unexpected preflight result: {status:?}"
    );
}

fn script_denied(status: TransactionStatus) {
    assert_eq!(
        status,
        TransactionStatus::Discard(StatusCode::UNEXPECTED_ERROR_FROM_KNOWN_MOVE_FUNCTION)
    );
}

fn publish_denied(status: TransactionStatus) {
    match status {
        TransactionStatus::Keep(ExecutionStatus::MoveAbort { location, code, .. }) => {
            assert_eq!(code, 0x5000C);
            assert_eq!(
                location,
                AbortLocation::Module(ModuleId::new(
                    AccountAddress::ONE,
                    ident_str!("code").to_owned()
                ))
            );
        },
        other => panic!("expected publishing denial, got {other:?}"),
    }
}

fn package(address: AccountAddress, version: u64) -> Package {
    let mut builder = PackageBuilder::new("RecoveryProbe");
    builder.add_source(
        "probe.move",
        &format!(
            "module {}::allowlist_recovery_probe {{ #[view] public fun version(): u64 {{ {} }} }}",
            address.to_hex_literal(),
            version
        ),
    );
    let path = builder.write_to_temp().unwrap();
    let package = BuiltPackage::build(path.path().to_owned(), BuildOptions::default()).unwrap();
    (
        bcs::to_bytes(&package.extract_metadata().unwrap()).unwrap(),
        package.extract_code(),
    )
}

fn publish(h: &mut MoveHarness, sender: &Account, package: &Package) -> TransactionStatus {
    run(
        h,
        sender,
        aptos_stdlib::code_publish_package_txn(package.0.clone(), package.1.clone()),
    )
}

fn publish_statement(package: &Package) -> String {
    let code = package
        .1
        .iter()
        .map(|bytes| format!("x\"{}\"", hex::encode(bytes)))
        .collect::<Vec<_>>()
        .join(",");
    format!(
        "aptos_framework::code::publish_package_txn(&framework, x\"{}\", vector[{}]);",
        hex::encode(&package.0),
        code
    )
}

fn approve(h: &mut MoveHarness, recovery: &Account, code: &[u8], id: u64) {
    assert_success!(run(
        h,
        recovery,
        aptos_stdlib::aptos_governance_create_proposal_v2(
            *recovery.address(),
            HashValue::sha3_256_of(code).to_vec(),
            b"rehearsal".to_vec(),
            vec![],
            false
        )
    ));
    assert_success!(run(
        h,
        recovery,
        aptos_stdlib::aptos_governance_partial_vote(*recovery.address(), id, u64::MAX, true)
    ));
    // The fixture config uses a ten-second vote; execute only after it has finished.
    h.fast_forward(11);
    h.executor.new_block();
}

#[test]
fn combined_activation_framework_upgrade_and_governance_recovery() {
    let mut h = MoveHarness::new();
    let core = h.new_account_at(aptos_test_root_address());
    let recovery = h.new_account_with_key_pair();
    let outsider = h.new_account_with_key_pair();
    assert_ne!(core.pubkey, recovery.pubkey);
    enabled(&mut h, false, false);

    let initialize_script = migration("script:initialize.move");
    let initialize_publish = migration("initialize_publish_allowlist.move");
    let add_script = migration("script:add.move");
    let remove_script = migration("script:remove.move");
    let add_publish = migration("add_publish_allowlist_sender.move");
    let remove_publish = migration("remove_publish_allowlist_sender.move");
    let enable_script = migration("script:enable.move");
    let enable_publish = migration("enable_publish_allowlist.move");
    let disable_script = migration("script:disable_by_proposal.move");
    let disable_publish = migration("disable_publish_allowlist_by_proposal.move");
    let noop = compile_script("script { fun main() {} }");
    let core_arg = TransactionArgument::Address(*core.address());
    let recovery_arg = TransactionArgument::Address(*recovery.address());

    // Establish real staking/governance state before activation. No proposal resources or
    // approvals are injected. Activation and recovery use the real helpers below.
    let initial_framework_package = package(AccountAddress::ONE, 1);
    let setup = compile_script(&format!(
        "script {{ fun main(core: &signer) {{
        let framework = aptos_framework::aptos_governance::get_signer_testnet_only(core, @0x1);
        aptos_framework::aptos_governance::update_governance_config(&framework, 1, 1, 10);
        aptos_framework::aptos_governance::initialize_partial_voting_if_needed(&framework);
        {}
    }} }}",
        publish_statement(&initial_framework_package)
    ));
    assert_success!(script(&mut h, &core, &setup, vec![]));
    assert_success!(run(
        &mut h,
        &recovery,
        aptos_stdlib::stake_initialize_stake_owner(
            50_000_000,
            *recovery.address(),
            *recovery.address()
        )
    ));
    // Funding a stake pool does not lock it; proposals require a lock beyond voting expiry.
    assert_success!(run(
        &mut h,
        &recovery,
        aptos_stdlib::stake_increase_lockup()
    ));
    assert_success!(script(&mut h, &core, &initialize_publish, vec![]));

    let before = epoch(&h);
    // Publishing activation is independent of script admission. The empty publishing list still
    // rejects the named upgrade sender, and the duplicate operator remains invalid.
    preflight_denied(
        script(&mut h, &core, &enable_publish, vec![
            core_arg.clone(),
            core_arg.clone(),
        ]),
        3,
    );
    preflight_denied(
        script(&mut h, &core, &enable_publish, vec![
            core_arg.clone(),
            recovery_arg.clone(),
        ]),
        1,
    );
    member(&mut h, &core, &add_publish, &core);
    preflight_denied(
        script(&mut h, &core, &enable_publish, vec![
            core_arg.clone(),
            recovery_arg.clone(),
        ]),
        2,
    );
    assert_eq!(epoch(&h), before);
    enabled(&mut h, false, false);

    member(&mut h, &core, &add_publish, &recovery);
    let before = epoch(&h);
    assert_success!(script(&mut h, &core, &enable_publish, vec![
        core_arg,
        recovery_arg
    ]));
    assert_eq!(epoch(&h), before);
    enabled(&mut h, false, true);

    let outsider_package = package(*outsider.address(), 1);
    let recovery_package = package(*recovery.address(), 1);
    publish_denied(publish(&mut h, &outsider, &outsider_package));
    assert_success!(publish(&mut h, &recovery, &recovery_package));

    // Script admission is configured only after publishing activation. With only the primary
    // core sender listed, the publishing helper still succeeds for named publishing members that
    // have no script membership. The outsider's helper submission is denied by the script prologue.
    assert_success!(script(&mut h, &core, &initialize_script, vec![]));
    assert_success!(script(&mut h, &core, &enable_publish, vec![
        TransactionArgument::Address(*core.address()),
        TransactionArgument::Address(*recovery.address()),
    ],));
    preflight_denied(script(&mut h, &core, &enable_script, vec![]), 2);
    member(&mut h, &core, &add_script, &core);
    assert_success!(script(&mut h, &core, &enable_script, vec![]));
    member(&mut h, &core, &add_publish, &outsider);
    assert_success!(script(&mut h, &core, &enable_publish, vec![
        TransactionArgument::Address(*outsider.address()),
        TransactionArgument::Address(*recovery.address()),
    ],));
    script_denied(script(&mut h, &outsider, &enable_publish, vec![
        TransactionArgument::Address(*outsider.address()),
        TransactionArgument::Address(*recovery.address()),
    ]));
    member(&mut h, &core, &remove_publish, &outsider);
    member(&mut h, &core, &add_script, &recovery);
    enabled(&mut h, true, true);
    script_denied(script(&mut h, &outsider, &noop, vec![]));
    assert_success!(script(&mut h, &recovery, &noop, vec![]));

    // Lose the normal operator. No transaction from core is used after these revocations.
    member(&mut h, &core, &remove_publish, &core);
    member(&mut h, &core, &remove_script, &core);
    script_denied(script(&mut h, &core, &initialize_script, vec![]));
    // Membership alone cannot resolve a proposal or obtain the framework signer.
    assert!(matches!(
        script(&mut h, &recovery, &disable_publish, vec![
            TransactionArgument::U64(0)
        ]),
        TransactionStatus::Keep(ExecutionStatus::MoveAbort { .. })
    ));
    enabled(&mut h, true, true);

    // Upgrade an existing package at 0x1 through an actual approved proposal while both
    // restrictions remain enabled. The approved code embeds the exact metadata and module bytes.
    let upgraded = package(AccountAddress::ONE, 2);
    let upgrade = compile_script(&format!(
        "script {{ fun main(proposal_id: u64) {{
        let framework = aptos_framework::aptos_governance::resolve(proposal_id, @0x1);
        {}
    }} }}",
        publish_statement(&upgraded)
    ));
    approve(&mut h, &recovery, &upgrade, 0);
    assert_success!(script(&mut h, &recovery, &upgrade, vec![
        TransactionArgument::U64(0)
    ]));
    let result = h.execute_view_function(
        "0x1::allowlist_recovery_probe::version".parse().unwrap(),
        vec![],
        vec![],
    );
    assert_eq!(
        bcs::from_bytes::<u64>(&result.values.unwrap()[0]).unwrap(),
        2
    );
    enabled(&mut h, true, true);

    approve(&mut h, &recovery, &disable_publish, 1);
    // Governance approval does not exempt an unlisted primary sender.
    script_denied(script(&mut h, &outsider, &disable_publish, vec![
        TransactionArgument::U64(1),
    ]));
    let before = epoch(&h);
    assert_success!(script(&mut h, &recovery, &disable_publish, vec![
        TransactionArgument::U64(1)
    ]));
    assert_eq!(epoch(&h), before);
    enabled(&mut h, true, false);
    assert_success!(publish(&mut h, &outsider, &outsider_package));
    script_denied(script(&mut h, &outsider, &noop, vec![]));

    approve(&mut h, &recovery, &disable_script, 2);
    let before = epoch(&h);
    assert_success!(script(&mut h, &recovery, &disable_script, vec![
        TransactionArgument::U64(2)
    ]));
    assert_eq!(epoch(&h), before);
    enabled(&mut h, false, false);
    assert_success!(script(&mut h, &outsider, &noop, vec![]));
}

#[test]
fn allowlist_state_is_scoped_to_its_policy_module() {
    let mut h = MoveHarness::new();
    let framework = h.aptos_framework_account();
    let alice = AccountAddress::from_hex_literal("0xa11ce").unwrap();
    let bob = AccountAddress::from_hex_literal("0xb0b").unwrap();
    for (function, args) in [
        ("script_execution_allowlist::initialize", vec![]),
        ("code::initialize_publish_allowlist", vec![]),
        ("script_execution_allowlist::add", vec![bcs::to_bytes(
            &alice,
        )
        .unwrap()]),
        ("code::add_publish_allowlist_sender", vec![bcs::to_bytes(
            &bob,
        )
        .unwrap()]),
        ("script_execution_allowlist::enable", vec![]),
    ] {
        assert_success!(h.run_entry_function(
            &framework,
            format!("0x1::{function}").parse().unwrap(),
            vec![],
            args,
        ));
    }
    enabled(&mut h, true, false);
    for (function, sender, expected) in [
        ("script_execution_allowlist::is_allowed", alice, true),
        ("script_execution_allowlist::is_allowed", bob, false),
        ("code::is_publish_allowlisted", alice, false),
        ("code::is_publish_allowlisted", bob, true),
    ] {
        let result =
            h.execute_view_function(format!("0x1::{function}").parse().unwrap(), vec![], vec![
                bcs::to_bytes(&sender).unwrap(),
            ]);
        assert_eq!(
            bcs::from_bytes::<bool>(&result.values.unwrap()[0]).unwrap(),
            expected
        );
    }
    for (function, args) in [
        ("code::enable_publish_allowlist", vec![]),
        ("script_execution_allowlist::remove", vec![bcs::to_bytes(
            &alice,
        )
        .unwrap()]),
        ("script_execution_allowlist::disable", vec![]),
        ("script_execution_allowlist::initialize", vec![]),
        ("code::initialize_publish_allowlist", vec![]),
    ] {
        assert_success!(h.run_entry_function(
            &framework,
            format!("0x1::{function}").parse().unwrap(),
            vec![],
            args,
        ));
    }
    enabled(&mut h, false, true);
    let scripts = h.execute_view_function(
        "0x1::script_execution_allowlist::get_allowed_senders"
            .parse()
            .unwrap(),
        vec![],
        vec![],
    );
    let publishing = h.execute_view_function(
        "0x1::code::get_publish_allowed_senders".parse().unwrap(),
        vec![],
        vec![],
    );
    assert!(
        bcs::from_bytes::<Vec<AccountAddress>>(&scripts.values.unwrap()[0])
            .unwrap()
            .is_empty()
    );
    assert_eq!(
        bcs::from_bytes::<Vec<AccountAddress>>(&publishing.values.unwrap()[0]).unwrap(),
        vec![bob]
    );
}
