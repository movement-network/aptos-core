// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{assert_success, MoveHarness};
use aptos_crypto::HashValue;
use aptos_framework::{
    natives::code::{MoveOption, PackageMetadata, UpgradePolicy},
    BuildOptions, BuiltPackage,
};
use aptos_language_e2e_tests::account::{Account, TransactionBuilder};
use aptos_package_builder::PackageBuilder;
use aptos_types::{
    account_address::{create_multisig_account_address, create_resource_address, AccountAddress},
    account_config::aptos_test_root_address,
    function_info::FunctionInfo,
    object_address::create_object_code_deployment_address,
    on_chain_config::{ApprovedExecutionHashes, FeatureFlag},
    transaction::{
        Auth, EntryFunction, ExecutionStatus, Multisig, MultisigTransactionPayload, Script,
        TransactionArgument, TransactionPayload, TransactionStatus,
    },
};
use move_core_types::{
    ident_str,
    language_storage::{ModuleId, StructTag},
    parser::parse_struct_tag,
    vm_status::{AbortLocation, StatusCode},
};
use std::{path::Path, sync::Arc};

type Package = (Vec<u8>, Vec<Vec<u8>>);

fn package(address: AccountAddress, add_module: bool) -> Package {
    let mut builder = PackageBuilder::new("AllowedPackage");
    builder.add_source(
        "m.move",
        &format!(
            "module {}::m {{ public fun f() {{}} }}",
            address.to_hex_literal()
        ),
    );
    if add_module {
        builder.add_source(
            "n.move",
            &format!(
                "module {}::n {{ public fun g() {{}} }}",
                address.to_hex_literal()
            ),
        );
    }
    let path = builder.write_to_temp().unwrap();
    let built = BuiltPackage::build(path.path().to_owned(), BuildOptions::default()).unwrap();
    (
        bcs::to_bytes(&built.extract_metadata().unwrap()).unwrap(),
        built.extract_code(),
    )
}

fn empty_package() -> Package {
    let metadata = PackageMetadata {
        name: "Empty".to_owned(),
        upgrade_policy: UpgradePolicy::compat(),
        upgrade_number: 0,
        source_digest: String::new(),
        manifest: vec![],
        modules: vec![],
        deps: vec![],
        extension: MoveOption::none(),
    };
    (bcs::to_bytes(&metadata).unwrap(), vec![])
}

fn entry(module: &str, function: &str, args: Vec<Vec<u8>>) -> EntryFunction {
    EntryFunction::new(
        ModuleId::new(AccountAddress::ONE, module.parse().unwrap()),
        function.parse().unwrap(),
        vec![],
        args,
    )
}

fn package_args(package: &Package) -> Vec<Vec<u8>> {
    vec![
        bcs::to_bytes(&package.0).unwrap(),
        bcs::to_bytes(&package.1).unwrap(),
    ]
}

fn publish_payload(package: &Package) -> TransactionPayload {
    TransactionPayload::EntryFunction(entry("code", "publish_package_txn", package_args(package)))
}

fn transaction(
    h: &MoveHarness,
    sender: &Account,
    payload: TransactionPayload,
) -> TransactionBuilder {
    TransactionBuilder::new(sender.clone())
        .payload(payload)
        .sequence_number(h.sequence_number(sender.address()))
        .max_gas_amount(1_000_000)
        .gas_unit_price(1)
}

fn run(h: &mut MoveHarness, sender: &Account, payload: TransactionPayload) -> TransactionStatus {
    let tx = transaction(h, sender, payload).sign();
    h.run(tx)
}

fn initialize(h: &mut MoveHarness) {
    let framework = h.aptos_framework_account();
    assert_success!(run(
        h,
        &framework,
        TransactionPayload::EntryFunction(entry("code", "initialize_publish_allowlist", vec![]))
    ));
}

fn set_allowed(h: &mut MoveHarness, sender: AccountAddress, allowed: bool) {
    let framework = h.aptos_framework_account();
    let operation = if allowed {
        "add_publish_allowlist_sender"
    } else {
        "remove_publish_allowlist_sender"
    };
    assert_success!(run(
        h,
        &framework,
        TransactionPayload::EntryFunction(entry("code", operation, vec![
            bcs::to_bytes(&sender).unwrap(),
        ]))
    ));
}

fn set_enabled(h: &mut MoveHarness, enabled: bool) {
    let framework = h.aptos_framework_account();
    let operation = if enabled {
        "enable_publish_allowlist"
    } else {
        "disable_publish_allowlist"
    };
    assert_success!(run(
        h,
        &framework,
        TransactionPayload::EntryFunction(entry("code", operation, vec![]))
    ));
}

fn assert_denied(status: TransactionStatus) {
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
        other => panic!("expected publishing allowlist denial, got {other:?}"),
    }
}

#[test]
fn publishing_controls_require_framework_authority_and_activate_immediately() {
    let mut h = MoveHarness::new();
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
    for operation in [
        "enable_publish_allowlist",
        "disable_publish_allowlist",
        "add_publish_allowlist_sender",
        "remove_publish_allowlist_sender",
    ] {
        let args = if matches!(
            operation,
            "add_publish_allowlist_sender" | "remove_publish_allowlist_sender"
        ) {
            vec![bcs::to_bytes(alice.address()).unwrap()]
        } else {
            vec![]
        };
        let unauthorized = run(
            &mut h,
            &alice,
            TransactionPayload::EntryFunction(entry("code", operation, args)),
        );
        assert!(matches!(
            unauthorized,
            TransactionStatus::Keep(ExecutionStatus::MoveAbort { code: 0x50003, .. })
        ));
    }

    initialize(&mut h);
    set_enabled(&mut h, true);
    let package = package(*alice.address(), false);
    assert_denied(run(&mut h, &alice, publish_payload(&package)));
    set_enabled(&mut h, false);
    assert_success!(run(&mut h, &alice, publish_payload(&package)));
}

fn registry(h: &MoveHarness, address: AccountAddress) -> Option<Vec<u8>> {
    h.read_resource_raw(
        &address,
        parse_struct_tag("0x1::code::PackageRegistry").unwrap(),
    )
}

#[test]
fn off_missing_empty_membership_revoke_and_mixed_bundle() {
    let mut h = MoveHarness::new();
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
    let initial = package(*alice.address(), false);
    assert_success!(run(&mut h, &alice, publish_payload(&initial)));
    initialize(&mut h);
    assert_success!(run(&mut h, &alice, publish_payload(&initial)));
    set_enabled(&mut h, true);
    assert_denied(run(&mut h, &alice, publish_payload(&initial)));
    set_allowed(&mut h, *alice.address(), true);
    let mixed = package(*alice.address(), true);
    assert_success!(run(&mut h, &alice, publish_payload(&mixed)));
    let before = registry(&h, *alice.address());
    set_allowed(&mut h, *alice.address(), false);
    assert_denied(run(&mut h, &alice, publish_payload(&mixed)));
    assert_eq!(registry(&h, *alice.address()), before);
    set_enabled(&mut h, false);
    assert_success!(run(&mut h, &alice, publish_payload(&mixed)));
}

#[test]
fn empty_publish_requests_are_checked_and_denials_charge_gas() {
    let mut h = MoveHarness::new();
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
    initialize(&mut h);
    set_enabled(&mut h, true);
    let empty = empty_package();
    let tx = transaction(&h, &alice, publish_payload(&empty)).sign();
    let sequence_before = h.sequence_number(alice.address());
    let output = h.run_raw(tx);
    assert_denied(output.status().clone());
    assert!(output.gas_used() > 0);
    assert_eq!(registry(&h, *alice.address()), None);
    assert_eq!(h.sequence_number(alice.address()), sequence_before + 1);
    set_allowed(&mut h, *alice.address(), true);
    assert_success!(run(&mut h, &alice, publish_payload(&empty)));
    assert!(registry(&h, *alice.address()).is_some());
}

#[test]
fn fee_payer_does_not_authorize_publishing() {
    let mut h = MoveHarness::new_with_features(vec![FeatureFlag::GAS_PAYER_ENABLED], vec![]);
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
    let payer = h.new_account_at(AccountAddress::from_hex_literal("0xcafe").unwrap());
    initialize(&mut h);
    set_enabled(&mut h, true);
    set_allowed(&mut h, *payer.address(), true);
    let package = package(*alice.address(), false);
    let tx = transaction(&h, &alice, publish_payload(&package))
        .fee_payer(payer.clone())
        .sign_fee_payer();
    assert_denied(h.run(tx));
    set_allowed(&mut h, *alice.address(), true);
    set_allowed(&mut h, *payer.address(), false);
    let tx = transaction(&h, &alice, publish_payload(&package))
        .fee_payer(payer)
        .sign_fee_payer();
    assert_success!(h.run(tx));
}

#[test]
fn scripts_and_approved_governance_hashes_cannot_bypass_publishing() {
    let mut h = MoveHarness::new();
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
    initialize(&mut h);
    set_enabled(&mut h, true);
    let package = package(*alice.address(), false);
    let mut builder = PackageBuilder::new("PublishScript");
    let framework = Path::new(env!("CARGO_MANIFEST_DIR")).join("../framework/aptos-framework");
    builder.add_local_dep("AptosFramework", framework.to_str().unwrap());
    builder.add_source("main.move", "script { use aptos_framework::code; fun main(s: &signer, metadata: vector<u8>, code: vector<vector<u8>>) { code::publish_package_txn(s, metadata, code) } }");
    let path = builder.write_to_temp().unwrap();
    let built = BuiltPackage::build(path.path().to_owned(), BuildOptions::default()).unwrap();
    let code = built.extract_script_code().remove(0);
    h.set_resource(
        AccountAddress::ONE,
        StructTag {
            address: AccountAddress::ONE,
            module: ident_str!("aptos_governance").to_owned(),
            name: ident_str!("ApprovedExecutionHashes").to_owned(),
            type_args: vec![],
        },
        &ApprovedExecutionHashes {
            entries: vec![(0, HashValue::sha3_256_of(&code).to_vec())],
        },
    );
    let payload = TransactionPayload::Script(Script::new(code, vec![], vec![
        TransactionArgument::U8Vector(package.0),
        TransactionArgument::Serialized(bcs::to_bytes(&package.1).unwrap()),
    ]));
    assert_denied(run(&mut h, &alice, payload.clone()));
    set_allowed(&mut h, *alice.address(), true);
    assert_success!(run(&mut h, &alice, payload));
}

#[test]
fn privileged_senders_still_need_membership() {
    let mut h = MoveHarness::new();
    initialize(&mut h);
    set_enabled(&mut h, true);
    let root = h.new_account_at(aptos_test_root_address());
    let framework = h.aptos_framework_account();
    let empty = empty_package();
    for sender in [&root, &framework] {
        assert_denied(run(&mut h, sender, publish_payload(&empty)));
    }
}

#[test]
fn resource_and_object_publish_check_sender_not_destination() {
    for object in [false, true] {
        let mut h =
            MoveHarness::new_with_features(vec![FeatureFlag::OBJECT_CODE_DEPLOYMENT], vec![]);
        let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
        initialize(&mut h);
        set_enabled(&mut h, true);
        let seed = b"allowlist-test".to_vec();
        let destination = |h: &MoveHarness| {
            if object {
                create_object_code_deployment_address(
                    *alice.address(),
                    h.sequence_number(alice.address()) + 1,
                )
            } else {
                create_resource_address(*alice.address(), &seed)
            }
        };
        let payload = |address| {
            let mut args = package_args(&package(address, false));
            if object {
                TransactionPayload::EntryFunction(entry("object_code_deployment", "publish", args))
            } else {
                args.insert(0, bcs::to_bytes(&seed).unwrap());
                TransactionPayload::EntryFunction(entry(
                    "resource_account",
                    "create_resource_account_and_publish_package",
                    args,
                ))
            }
        };
        let first = destination(&h);
        set_allowed(&mut h, first, true);
        assert_denied(run(&mut h, &alice, payload(first)));
        assert_eq!(registry(&h, first), None);
        set_allowed(&mut h, first, false);
        set_allowed(&mut h, *alice.address(), true);
        let second = destination(&h);
        assert_success!(run(&mut h, &alice, payload(second)));
        assert!(registry(&h, second).is_some());
    }
}

#[test]
fn multisig_publish_checks_executing_owner_not_multisig_address() {
    let mut h = MoveHarness::new();
    let owner = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
    initialize(&mut h);
    set_enabled(&mut h, true);
    let multisig =
        create_multisig_account_address(*owner.address(), h.sequence_number(owner.address()));
    assert_success!(run(
        &mut h,
        &owner,
        TransactionPayload::EntryFunction(entry("multisig_account", "create_with_owners", vec![
            bcs::to_bytes(&Vec::<AccountAddress>::new()).unwrap(),
            bcs::to_bytes(&1u64).unwrap(),
            bcs::to_bytes(&Vec::<String>::new()).unwrap(),
            bcs::to_bytes(&Vec::<Vec<u8>>::new()).unwrap(),
        ]))
    ));
    let inner = MultisigTransactionPayload::EntryFunction(entry(
        "code",
        "publish_package_txn",
        package_args(&package(multisig, false)),
    ));
    set_allowed(&mut h, multisig, true);
    for allowed in [false, true] {
        if allowed {
            set_allowed(&mut h, multisig, false);
            set_allowed(&mut h, *owner.address(), true);
        }
        assert_success!(run(
            &mut h,
            &owner,
            TransactionPayload::EntryFunction(entry(
                "multisig_account",
                "create_transaction",
                vec![
                    bcs::to_bytes(&multisig).unwrap(),
                    bcs::to_bytes(&bcs::to_bytes(&inner).unwrap()).unwrap(),
                ]
            ))
        ));
        // A failed inner multisig call is recorded by the successful outer transaction.
        assert_success!(run(
            &mut h,
            &owner,
            TransactionPayload::Multisig(Multisig {
                multisig_address: multisig,
                transaction_payload: Some(inner.clone()),
            })
        ));
        assert_eq!(registry(&h, multisig).is_some(), allowed);
    }
}

#[test]
fn account_abstraction_cannot_publish_during_authentication() {
    fn run_case(allowlist_enabled: bool, initialized: bool, allowed: bool) {
        // Install the authenticator before turning on publishing restrictions.
        let mut h = MoveHarness::new_with_features(vec![FeatureFlag::ACCOUNT_ABSTRACTION], vec![
            FeatureFlag::TRANSACTION_CONTEXT_EXTENSION,
        ]);
        let alice = h.new_account_at(AccountAddress::from_hex_literal("0xa11ce").unwrap());
        let bob = h.new_account_at(AccountAddress::from_hex_literal("0xb0b").unwrap());

        let metadata = empty_package().0;
        let bytes = metadata
            .iter()
            .map(|byte| byte.to_string())
            .collect::<Vec<_>>()
            .join(", ");
        let mut builder = PackageBuilder::new("AuthenticationPublisher");
        builder.add_local_dep(
            "AptosFramework",
            Path::new(env!("CARGO_MANIFEST_DIR"))
                .join("../framework/aptos-framework")
                .to_str()
                .unwrap(),
        );
        builder.add_source(
            "auth.move",
            &format!(
                "module aa::auth {{ use aptos_framework::auth_data::AbstractionAuthData; use aptos_framework::code; public fun authenticate(account: signer, _data: AbstractionAuthData): signer {{ code::publish_package_txn(&account, vector[{}], vector[]); account }} }}",
                bytes
            ),
        );
        let path = builder.write_to_temp().unwrap();
        let mut options = BuildOptions::default();
        options
            .named_addresses
            .insert("aa".to_owned(), *alice.address());
        assert_success!(h.publish_package_with_options(&alice, path.path(), options));

        if initialized {
            initialize(&mut h);
            if allowed {
                set_allowed(&mut h, *alice.address(), true);
            }
        }
        let add_auth = entry("account_abstraction", "add_authentication_function", vec![
            bcs::to_bytes(&alice.address()).unwrap(),
            bcs::to_bytes(&"auth".to_owned()).unwrap(),
            bcs::to_bytes(&"authenticate".to_owned()).unwrap(),
        ]);
        assert_success!(run(
            &mut h,
            &alice,
            TransactionPayload::EntryFunction(add_auth)
        ));

        if initialized && allowlist_enabled {
            set_enabled(&mut h, true);
        }
        let payload = aptos_cached_packages::aptos_stdlib::aptos_coin_transfer(*bob.address(), 1);
        let function = FunctionInfo::new(
            *alice.address(),
            "auth".to_owned(),
            "authenticate".to_owned(),
        );
        let tx = transaction(&h, &alice, payload)
            .raw()
            .sign_aa_transaction(
                Auth::Abstraction(function, Arc::new(|_| vec![])),
                vec![],
                vec![],
                None,
            )
            .unwrap()
            .into_inner();
        let before = registry(&h, *alice.address());
        let sequence_before = h.sequence_number(alice.address());
        let status = h.run(tx);
        if initialized && allowlist_enabled && !allowed {
            // Authentication aborts discard the transaction, including prologue effects.
            assert_eq!(status, TransactionStatus::Discard(StatusCode::ABORTED));
            assert_eq!(registry(&h, *alice.address()), before);
            assert_eq!(h.sequence_number(alice.address()), sequence_before);
        } else {
            assert_success!(status);
            // The positive controls prove the authenticator really attempted a publish.
            assert_ne!(registry(&h, *alice.address()), before);
        }
    }

    run_case(false, false, false);
    run_case(true, false, false);
    run_case(true, true, false);
    run_case(true, true, true);
}
