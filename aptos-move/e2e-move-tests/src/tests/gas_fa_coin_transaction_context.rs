// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! End-to-end coverage for paying transaction gas in a selected fungible asset:
//! the `gas_fa_coin` from the versioned payload's `TransactionExtraConfig::V2` is surfaced to Move
//! via `transaction_context::gas_payment_fungible_asset()`, validated in the prologue, and routed
//! into that FA's governed gas pool by the epilogue.

use crate::{assert_abort, assert_success, tests::common, MoveHarness};
use aptos_language_e2e_tests::account::{Account, TransactionBuilder};
use aptos_types::{
    account_address::AccountAddress,
    on_chain_config::FeatureFlag,
    transaction::{
        EntryFunction, TransactionExecutable, TransactionExtraConfig, TransactionPayload,
        TransactionPayloadInner,
    },
};
use move_core_types::{ident_str, language_storage::ModuleId};

/// The transaction_context test pack publishes to `@admin` = 0x1, which is also @aptos_framework, so
/// the returned account doubles as the governance signer.
fn setup() -> (MoveHarness, Account) {
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
    (h, admin)
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

/// Same as `entry`, but the versioned payload elects to pay gas in the fungible asset `fa`.
fn entry_paying_gas_in_fa(
    name: &'static str,
    args: Vec<Vec<u8>>,
    fa: AccountAddress,
) -> TransactionPayload {
    let mut payload = entry(name, args);
    if let TransactionPayload::Payload(TransactionPayloadInner::V1 { extra_config, .. }) =
        &mut payload
    {
        if let TransactionExtraConfig::V2 { gas_fa_coin, .. } = extra_config {
            *gas_fa_coin = Some(fa);
        }
    }
    payload
}

fn fa_pool_balance(h: &mut MoveHarness, metadata: AccountAddress) -> u64 {
    let out = h.execute_view_function(
        str::parse("0x1::governed_gas_pool::get_fa_balance").unwrap(),
        vec![],
        vec![bcs::to_bytes(&metadata).unwrap()],
    );
    bcs::from_bytes::<u64>(&out.values.expect("view failed")[0]).unwrap()
}

fn account_fa_balance(h: &mut MoveHarness, owner: AccountAddress, metadata: AccountAddress) -> u64 {
    let out = h.execute_view_function(
        str::parse("0x1::transaction_context_test::fa_balance").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&owner).unwrap(),
            bcs::to_bytes(&metadata).unwrap(),
        ],
    );
    bcs::from_bytes::<u64>(&out.values.expect("view failed")[0]).unwrap()
}

/// The metadata address of the FA created by `create_gas_fa` for `owner`.
fn gas_fa_metadata_address(h: &mut MoveHarness, owner: AccountAddress) -> AccountAddress {
    let out = h.execute_view_function(
        str::parse("0x1::transaction_context_test::gas_fa_metadata_address").unwrap(),
        vec![],
        vec![bcs::to_bytes(&owner).unwrap()],
    );
    bcs::from_bytes::<AccountAddress>(&out.values.expect("view failed")[0]).unwrap()
}

/// Creates a gas FA owned by `who`, minting `amount` to it, and returns its metadata address.
fn create_gas_fa(h: &mut MoveHarness, who: &Account, amount: u64) -> AccountAddress {
    assert_success!(h.run_entry_function(
        who,
        str::parse("0x1::transaction_context_test::create_gas_fa").unwrap(),
        vec![],
        vec![bcs::to_bytes(&amount).unwrap()],
    ));
    gas_fa_metadata_address(h, *who.address())
}

/// Governance accepts `metadata` for gas payment at `gas_price` FA units per gas unit.
fn accept_gas_fa(h: &mut MoveHarness, admin: &Account, metadata: AccountAddress, gas_price: u64) {
    assert_success!(h.run_entry_function(
        admin,
        str::parse("0x1::governed_gas_pool::add_accepted_gas_fungible_asset").unwrap(),
        vec![],
        vec![bcs::to_bytes(&metadata).unwrap(), bcs::to_bytes(&gas_price).unwrap()],
    ));
}

/// Full flow: a transaction electing to pay gas in an accepted fungible asset passes the prologue
/// (accepted + sufficient FA balance), executes with the accessor reporting that FA, and has its gas
/// fee collected into that FA's governed gas pool.
#[test]
fn gas_paid_in_accepted_fa_routes_to_its_pool() {
    let (mut h, admin) = setup();
    let sender = h.new_account_with_key_pair();

    // 1. Sender creates a fungible asset and mints itself a large balance (this txn pays gas in APT).
    assert_success!(h.run_entry_function(
        &sender,
        str::parse("0x1::transaction_context_test::create_gas_fa").unwrap(),
        vec![],
        vec![bcs::to_bytes(&1_000_000_000_000_000u64).unwrap()],
    ));

    // 2. Look up the created FA's metadata address.
    let metadata = {
        let out = h.execute_view_function(
            str::parse("0x1::transaction_context_test::gas_fa_metadata_address").unwrap(),
            vec![],
            vec![bcs::to_bytes(sender.address()).unwrap()],
        );
        bcs::from_bytes::<AccountAddress>(&out.values.expect("view failed")[0]).unwrap()
    };

    // 3. Governance accepts the FA for gas payment with a gas price of 2 FA units per gas unit
    //    (admin == 0x1 == @aptos_framework).
    let fa_gas_price = 2u64;
    assert_success!(h.run_entry_function(
        &admin,
        str::parse("0x1::governed_gas_pool::add_accepted_gas_fungible_asset").unwrap(),
        vec![],
        vec![bcs::to_bytes(&metadata).unwrap(), bcs::to_bytes(&fa_gas_price).unwrap()],
    ));

    let pool_before = fa_pool_balance(&mut h, metadata);

    // 4. Sender submits a versioned txn paying gas in the FA. The entry function asserts the accessor
    //    reports that FA (aborts otherwise), and the epilogue routes the gas fee into its pool.
    let payload = entry_paying_gas_in_fa(
        "assert_gas_payment_fungible_asset",
        vec![bcs::to_bytes(&metadata).unwrap()],
        metadata,
    );
    let txn = h.create_transaction_payload(&sender, payload);
    let output = h.run_raw(txn);
    let gas_used = output.gas_used();
    assert_success!(output.status().clone());

    // 5. The FA's governed gas pool grew by exactly gas_used * the FA's gas price.
    let pool_after = fa_pool_balance(&mut h, metadata);
    assert_eq!(
        pool_after - pool_before,
        gas_used * fa_gas_price,
        "FA pool should grow by gas_used ({}) * price ({})",
        gas_used,
        fa_gas_price
    );
    assert!(
        pool_after > pool_before,
        "expected the FA governed gas pool to grow, before={} after={}",
        pool_before,
        pool_after
    );
}

/// A transaction electing to pay gas in a fungible asset that governance has NOT accepted is
/// rejected by the prologue (discarded), so it never executes.
#[test]
fn gas_paid_in_unaccepted_fa_is_rejected() {
    let (mut h, _admin) = setup();
    let sender = h.new_account_with_key_pair();
    assert_success!(h.run_entry_function(
        &sender,
        str::parse("0x1::transaction_context_test::create_gas_fa").unwrap(),
        vec![],
        vec![bcs::to_bytes(&1_000_000_000_000_000u64).unwrap()],
    ));
    let metadata = {
        let out = h.execute_view_function(
            str::parse("0x1::transaction_context_test::gas_fa_metadata_address").unwrap(),
            vec![],
            vec![bcs::to_bytes(sender.address()).unwrap()],
        );
        bcs::from_bytes::<AccountAddress>(&out.values.expect("view failed")[0]).unwrap()
    };

    // Not accepted by governance -> prologue discards the transaction.
    let payload = entry_paying_gas_in_fa(
        "assert_gas_payment_fungible_asset",
        vec![bcs::to_bytes(&metadata).unwrap()],
        metadata,
    );
    let txn = h.create_transaction_payload(&sender, payload);
    let status = h.run_raw(txn).status().clone();
    assert!(
        matches!(
            status,
            aptos_types::transaction::TransactionStatus::Discard(_)
        ),
        "expected an unaccepted gas FA to be discarded, got: {:?}",
        status
    );
}

/// With account abstraction DISABLED, a versioned fee-payer transaction electing to pay gas in an FA
/// takes the legacy `epilogue_gas_payer_extended` path (not the unified one). That path is now FA-
/// aware: the fee payer is charged in the FA, the fee lands in the FA's governed gas pool, and the
/// fee payer's APT is untouched.
#[test]
fn fa_fee_payer_gas_is_charged_in_fa_via_legacy_epilogue() {
    // AA off -> epilogue dispatch uses the legacy epilogue_gas_payer_extended, not unified_epilogue_v2.
    let mut h = MoveHarness::new_with_features(
        vec![
            FeatureFlag::TRANSACTION_PAYLOAD_V2,
            FeatureFlag::GAS_PAYABLE_FA,
            FeatureFlag::GAS_PAYER_ENABLED,
        ],
        vec![
            FeatureFlag::ACCOUNT_ABSTRACTION,
            FeatureFlag::DERIVABLE_ACCOUNT_ABSTRACTION,
        ],
    );
    let admin = h.new_account_at(AccountAddress::ONE);
    let path = common::test_dir_path("transaction_context.data/pack");
    assert_success!(h.publish_package_cache_building(&admin, &path));

    let alice = h.new_account_with_key_pair(); // sender
    let bob = h.new_account_with_key_pair(); // fee payer, will hold + pay in the FA

    // bob creates an FA and mints itself a large balance (APT-paid txn).
    assert_success!(h.run_entry_function(
        &bob,
        str::parse("0x1::transaction_context_test::create_gas_fa").unwrap(),
        vec![],
        vec![bcs::to_bytes(&1_000_000_000_000_000u64).unwrap()],
    ));
    let metadata = {
        let out = h.execute_view_function(
            str::parse("0x1::transaction_context_test::gas_fa_metadata_address").unwrap(),
            vec![],
            vec![bcs::to_bytes(bob.address()).unwrap()],
        );
        bcs::from_bytes::<AccountAddress>(&out.values.expect("view failed")[0]).unwrap()
    };
    let fa_gas_price = 2u64;
    assert_success!(h.run_entry_function(
        &admin,
        str::parse("0x1::governed_gas_pool::add_accepted_gas_fungible_asset").unwrap(),
        vec![],
        vec![bcs::to_bytes(&metadata).unwrap(), bcs::to_bytes(&fa_gas_price).unwrap()],
    ));

    let bob_fa_before = account_fa_balance(&mut h, *bob.address(), metadata);
    let bob_apt_before = h.read_aptos_balance(bob.address());
    let pool_before = fa_pool_balance(&mut h, metadata);

    // alice sends a versioned txn; bob sponsors gas and elects to pay it in the FA.
    let payload = entry_paying_gas_in_fa(
        "assert_gas_payment_fungible_asset",
        vec![bcs::to_bytes(&metadata).unwrap()],
        metadata,
    );
    let txn = TransactionBuilder::new(alice.clone())
        .fee_payer(bob.clone())
        .payload(payload)
        .sequence_number(h.sequence_number(alice.address()))
        .max_gas_amount(1_000_000)
        .gas_unit_price(1)
        .sign_fee_payer();
    let output = h.run_raw(txn);
    let gas_used = output.gas_used();
    let status = output.status().clone();

    let bob_fa_after = account_fa_balance(&mut h, *bob.address(), metadata);
    let bob_apt_after = h.read_aptos_balance(bob.address());
    let pool_after = fa_pool_balance(&mut h, metadata);

    assert_success!(status);
    // The fee payer was charged in the FA at gas_used * the FA's gas price, and that exact amount
    // landed in the FA's governed gas pool.
    assert_eq!(
        bob_fa_before - bob_fa_after,
        gas_used * fa_gas_price,
        "fee payer's FA charge should be gas_used ({}) * price ({})",
        gas_used,
        fa_gas_price
    );
    assert_eq!(
        bob_fa_before - bob_fa_after,
        pool_after - pool_before,
        "the FA charged to the fee payer should equal the FA pool increase"
    );
    // APT was not used to pay this transaction's gas.
    assert_eq!(
        bob_apt_before, bob_apt_after,
        "fee payer's APT should be untouched when paying gas in an FA"
    );
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

/// A transaction electing to pay gas in an accepted FA the payer cannot afford (max fee exceeds the
/// payer's FA balance) is discarded by the prologue.
#[test]
fn gas_fa_insufficient_balance_is_rejected() {
    let (mut h, admin) = setup();
    let sender = h.new_account_with_key_pair();
    // Mint the sender only a tiny FA balance.
    let metadata = create_gas_fa(&mut h, &sender, 100);
    accept_gas_fa(&mut h, &admin, metadata, 1);

    // max_gas 1000 at price 1 => max FA fee 1000 > balance 100 => prologue discard.
    let payload = entry_paying_gas_in_fa(
        "assert_gas_payment_fungible_asset",
        vec![bcs::to_bytes(&metadata).unwrap()],
        metadata,
    );
    let txn = TransactionBuilder::new(sender.clone())
        .payload(payload)
        .sequence_number(h.sequence_number(sender.address()))
        .max_gas_amount(1000)
        .gas_unit_price(1)
        .sign();
    let status = h.run_raw(txn).status().clone();
    assert!(
        matches!(
            status,
            aptos_types::transaction::TransactionStatus::Discard(_)
        ),
        "expected an underfunded FA gas payer to be discarded, got: {:?}",
        status
    );
}

/// With account abstraction DISABLED and no fee payer, a versioned transaction paying gas in an FA
/// takes the legacy `epilogue_extended` -> `epilogue_gas_payer_extended` path, charging the sender
/// (its own gas payer) in the FA at gas_used * price.
#[test]
fn fa_regular_sender_charged_via_legacy_epilogue_extended() {
    let mut h = MoveHarness::new_with_features(
        vec![
            FeatureFlag::TRANSACTION_PAYLOAD_V2,
            FeatureFlag::GAS_PAYABLE_FA,
        ],
        vec![
            FeatureFlag::ACCOUNT_ABSTRACTION,
            FeatureFlag::DERIVABLE_ACCOUNT_ABSTRACTION,
        ],
    );
    let admin = h.new_account_at(AccountAddress::ONE);
    let path = common::test_dir_path("transaction_context.data/pack");
    assert_success!(h.publish_package_cache_building(&admin, &path));

    let sender = h.new_account_with_key_pair();
    let metadata = create_gas_fa(&mut h, &sender, 1_000_000_000_000_000);
    let fa_gas_price = 2u64;
    accept_gas_fa(&mut h, &admin, metadata, fa_gas_price);

    let fa_before = account_fa_balance(&mut h, *sender.address(), metadata);
    let apt_before = h.read_aptos_balance(sender.address());
    let pool_before = fa_pool_balance(&mut h, metadata);

    let payload = entry_paying_gas_in_fa(
        "assert_gas_payment_fungible_asset",
        vec![bcs::to_bytes(&metadata).unwrap()],
        metadata,
    );
    let txn = h.create_transaction_payload(&sender, payload);
    let output = h.run_raw(txn);
    let gas_used = output.gas_used();
    assert_success!(output.status().clone());

    let fa_after = account_fa_balance(&mut h, *sender.address(), metadata);
    let apt_after = h.read_aptos_balance(sender.address());
    let pool_after = fa_pool_balance(&mut h, metadata);

    assert_eq!(
        fa_before - fa_after,
        gas_used * fa_gas_price,
        "regular sender's FA charge should be gas_used ({}) * price ({})",
        gas_used,
        fa_gas_price
    );
    assert_eq!(fa_before - fa_after, pool_after - pool_before);
    assert_eq!(
        apt_before, apt_after,
        "sender's APT should be untouched when paying gas in an FA"
    );
}

/// A transaction that aborts during execution but is kept still has its FA gas charged by the
/// epilogue (gas is collected even on failure).
#[test]
fn aborted_transaction_still_charges_fa_gas() {
    let (mut h, admin) = setup();
    let sender = h.new_account_with_key_pair();
    let metadata = create_gas_fa(&mut h, &sender, 1_000_000_000_000_000);
    let fa_gas_price = 2u64;
    accept_gas_fa(&mut h, &admin, metadata, fa_gas_price);

    let fa_before = account_fa_balance(&mut h, *sender.address(), metadata);
    let pool_before = fa_pool_balance(&mut h, metadata);

    // gas_fa_coin is set correctly, but the entry function asserts the accessor equals a DIFFERENT
    // address, so it aborts (code 1000) — while gas is still charged in the FA.
    let wrong = AccountAddress::from_hex_literal("0xdead").unwrap();
    let payload = entry_paying_gas_in_fa(
        "assert_gas_payment_fungible_asset",
        vec![bcs::to_bytes(&wrong).unwrap()],
        metadata,
    );
    let txn = h.create_transaction_payload(&sender, payload);
    let output = h.run_raw(txn);
    let gas_used = output.gas_used();
    let status = output.status().clone();

    assert_abort!(status, 1000);
    let fa_after = account_fa_balance(&mut h, *sender.address(), metadata);
    let pool_after = fa_pool_balance(&mut h, metadata);
    assert_eq!(
        fa_before - fa_after,
        gas_used * fa_gas_price,
        "FA gas should be charged even though the transaction aborted"
    );
    assert_eq!(pool_after - pool_before, gas_used * fa_gas_price);
}
