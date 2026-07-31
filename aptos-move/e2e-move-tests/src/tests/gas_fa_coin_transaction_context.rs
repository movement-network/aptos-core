// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! End-to-end coverage that a transaction's `gas_fa_coin` (from the versioned payload's
//! `TransactionExtraConfig::V2`) is surfaced to Move via
//! `transaction_context::gas_payment_fungible_asset()`.

use crate::{assert_abort, assert_success, tests::common, MoveHarness};
use aptos_types::{
    account_address::AccountAddress,
    on_chain_config::FeatureFlag,
    transaction::{
        EntryFunction, TransactionExecutable, TransactionExtraConfig, TransactionPayload,
        TransactionPayloadInner,
    },
};
use move_core_types::{ident_str, language_storage::ModuleId};

/// The transaction_context test pack publishes to `@admin` = 0x1.
fn setup() -> (MoveHarness, AccountAddress) {
    // `TRANSACTION_PAYLOAD_V2` so the versioned payload is accepted, and `GAS_PAYABLE_FA` so a
    // transaction carrying `gas_fa_coin` is not rejected by the VM gate.
    let mut h = MoveHarness::new_with_features(
        vec![
            FeatureFlag::TRANSACTION_PAYLOAD_V2,
            FeatureFlag::GAS_PAYABLE_FA,
        ],
        vec![],
    );
    let admin = h.new_account_at(AccountAddress::ONE);
    let path = common::test_dir_path("transaction_context.data/pack");
    assert_success!(h.publish_package_cache_building(&admin, &path));
    (h, *admin.address())
}

fn entry(name: &'static str, args: Vec<Vec<u8>>) -> TransactionPayload {
    let executable = TransactionExecutable::EntryFunction(EntryFunction::new(
        ModuleId::new(
            AccountAddress::ONE,
            ident_str!("transaction_context_test").to_owned(),
        ),
        ident_str!(name).to_owned(),
        vec![],
        args,
    ));
    TransactionPayload::Payload(TransactionPayloadInner::V1 {
        executable,
        extra_config: TransactionExtraConfig::V2 {
            multisig_address: None,
            replay_protection_nonce: None,
            gas_fa_coin: None,
        },
    })
}

/// A versioned transaction that sets `gas_fa_coin = Some(fa)` makes
/// `transaction_context::gas_payment_fungible_asset()` return `Some(fa)` during execution.
#[test]
fn gas_fa_coin_is_visible_in_transaction_context() {
    let (mut h, _admin) = setup();
    let sender = h.new_account_with_key_pair();
    let fa = AccountAddress::from_hex_literal("0xfa").unwrap();

    // Entry function aborts unless the accessor returns Some(fa).
    let mut payload = entry("assert_gas_payment_fungible_asset", vec![bcs::to_bytes(&fa)
        .unwrap()]);
    if let TransactionPayload::Payload(TransactionPayloadInner::V1 { extra_config, .. }) =
        &mut payload
    {
        if let TransactionExtraConfig::V2 { gas_fa_coin, .. } = extra_config {
            *gas_fa_coin = Some(fa);
        }
    }

    let txn = h.create_transaction_payload(&sender, payload);
    assert_success!(h.run_raw(txn).status().clone());
}

/// A versioned transaction with no `gas_fa_coin` makes the accessor return `None`.
#[test]
fn absent_gas_fa_coin_reads_as_none_in_transaction_context() {
    let (mut h, _admin) = setup();
    let sender = h.new_account_with_key_pair();

    // `gas_fa_coin` left as None by `entry`; entry function aborts unless the accessor is None.
    let payload = entry("assert_no_gas_payment_fungible_asset", vec![]);
    let txn = h.create_transaction_payload(&sender, payload);
    assert_success!(h.run_raw(txn).status().clone());
}

/// With `GAS_PAYABLE_FA` disabled, `gas_payment_fungible_asset()` aborts at its feature gate with
/// `invalid_state(EGAS_PAYABLE_FA_NOT_ENABLED)` (= 196611) rather than returning a value. A plain
/// (legacy) entry-function call suffices, since the abort happens before the accessor returns.
#[test]
fn accessor_aborts_when_feature_disabled() {
    let mut h = MoveHarness::new_with_features(vec![], vec![FeatureFlag::GAS_PAYABLE_FA]);
    let admin = h.new_account_at(AccountAddress::ONE);
    let path = common::test_dir_path("transaction_context.data/pack");
    assert_success!(h.publish_package_cache_building(&admin, &path));

    let sender = h.new_account_with_key_pair();
    let status = h.run_entry_function(
        &sender,
        str::parse("0x1::transaction_context_test::assert_no_gas_payment_fungible_asset").unwrap(),
        vec![],
        vec![],
    );
    assert_abort!(status, 196611);
}
