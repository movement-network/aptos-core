// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::smoke_test_environment::new_local_swarm_with_aptos;
use aptos_cached_packages::aptos_stdlib;
use aptos_forge::Swarm;
use aptos_move_debugger::aptos_debugger::AptosDebugger;
use aptos_types::transaction::{ExecutionStatus, TransactionStatus};

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_mint_transfer() {
    let swarm = new_local_swarm_with_aptos(1).await;
    let mut info = swarm.aptos_public_info();

    let account1 = info.random_account();
    info.create_user_account(account1.public_key())
        .await
        .unwrap();
    let account2 = info.random_account();
    info.create_user_account(account2.public_key())
        .await
        .unwrap();

    // NOTE(Gas): For some reason, there needs to be a lot of funds in the account in order for the
    //            test to pass.
    //            Is this caused by us increasing the default max gas amount in
    //            testsuite/forge/src/interface/aptos.rs?
    info.mint(account1.address(), 100_000_000_000)
        .await
        .unwrap();
    assert_eq!(
        info.client()
            .view_apt_account_balance(account1.address())
            .await
            .unwrap()
            .into_inner(),
        100_000_000_000
    );

    let transfer_txn = account1.sign_with_transaction_builder(
        info.transaction_factory()
            .payload(aptos_stdlib::aptos_coin_transfer(account2.address(), 40000)),
    );
    info.client().submit_and_wait(&transfer_txn).await.unwrap();
    assert_eq!(
        info.client()
            .view_apt_account_balance(account2.address())
            .await
            .unwrap()
            .into_inner(),
        40000
    );

    // Testing the AptosDebugger by reexecuting the transaction that has been published.
    println!("Testing....");
    let debugger = AptosDebugger::rest_client(info.client().clone()).unwrap();

    let txn_ver = debugger
        .get_version_by_account_sequence(account1.address(), 0)
        .await
        .unwrap()
        .unwrap();

    let output = debugger
        .execute_past_transactions(txn_ver, 1, false, 1, &[1])
        .await
        .unwrap()
        .pop()
        .unwrap();

    assert_eq!(
        output.status(),
        &TransactionStatus::Keep(ExecutionStatus::Success)
    );
}
