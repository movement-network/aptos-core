// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::MoveHarness;
use aptos_cached_packages::aptos_stdlib;
use aptos_types::{
    on_chain_config::FeatureFlag,
    transaction::{
        TransactionExecutable, TransactionExtraConfig, TransactionPayload,
        TransactionPayloadInner, TransactionStatus,
    },
};
use move_core_types::{account_address::AccountAddress, vm_status::StatusCode};

/// Builds a transaction payload in the new (versioned) format carrying an optional `gas_fa_coin`,
/// wrapping a simple APT transfer entry function as the executable.
fn transfer_payload_with_gas_fa_coin(
    recipient: AccountAddress,
    gas_fa_coin: Option<AccountAddress>,
) -> TransactionPayload {
    let executable = match aptos_stdlib::aptos_account_transfer(recipient, 1) {
        TransactionPayload::EntryFunction(entry_function) => {
            TransactionExecutable::EntryFunction(entry_function)
        },
        _ => unreachable!("aptos_account_transfer builds an entry function payload"),
    };
    TransactionPayload::Payload(TransactionPayloadInner::V1 {
        executable,
        extra_config: TransactionExtraConfig::V2 {
            multisig_address: None,
            replay_protection_nonce: None,
            gas_fa_coin,
        },
    })
}

/// A transaction that specifies a `gas_fa_coin` must be rejected while the `GAS_PAYABLE_FA` feature
/// is disabled, even though the underlying (versioned) payload format itself is enabled.
#[test]
fn gas_fa_coin_is_rejected_when_feature_disabled() {
    // TRANSACTION_PAYLOAD_V2 is on so the versioned payload format is not what triggers the gate;
    // GAS_PAYABLE_FA is off so the `gas_fa_coin` field is the sole reason for rejection.
    let mut h = MoveHarness::new_with_features(
        vec![FeatureFlag::TRANSACTION_PAYLOAD_V2],
        vec![FeatureFlag::GAS_PAYABLE_FA],
    );
    let alice = h.new_account_with_key_pair();
    let bob = h.new_account_with_key_pair();

    let payload = transfer_payload_with_gas_fa_coin(*bob.address(), Some(*bob.address()));
    let txn = h.create_transaction_payload(&alice, payload);
    let output = h.run_raw(txn);

    match output.status() {
        TransactionStatus::Discard(status) => assert_eq!(
            *status,
            StatusCode::FEATURE_UNDER_GATING,
            "expected a FEATURE_UNDER_GATING discard, but got: {:?}",
            status
        ),
        other => panic!(
            "expected a transaction carrying gas_fa_coin to be discarded, but got: {:?}",
            other
        ),
    }
}

/// Control: an identical transaction in the same feature configuration but *without* a
/// `gas_fa_coin` is accepted. This proves the rejection above is caused by `gas_fa_coin`
/// specifically, not by the versioned payload format.
#[test]
fn transaction_without_gas_fa_coin_is_not_gated() {
    let mut h = MoveHarness::new_with_features(
        vec![FeatureFlag::TRANSACTION_PAYLOAD_V2],
        vec![FeatureFlag::GAS_PAYABLE_FA],
    );
    let alice = h.new_account_with_key_pair();
    let bob = h.new_account_with_key_pair();

    let payload = transfer_payload_with_gas_fa_coin(*bob.address(), None);
    let status = h.run_transaction_payload(&alice, payload);

    assert!(
        matches!(status, TransactionStatus::Keep(_)),
        "an identical transaction without gas_fa_coin must not be gated, but got: {:?}",
        status
    );
}
