// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::smoke_test_environment::SwarmBuilder;
use aptos_cached_packages::aptos_stdlib;
use aptos_forge::Swarm;
use aptos_move_debugger::aptos_debugger::AptosDebugger;
use aptos_types::transaction::{ExecutionStatus, TransactionStatus};

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_mint_transfer() {
    let (swarm, mut cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(0)
        .await;
    let mut info = swarm.aptos_public_info();
    let root_cli_index = cli.add_account_with_address_to_cli(
        swarm.root_key(),
        swarm.chain_info().root_account().address(),
    );

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

    // test delegation
    let delegate_script = format!(
        r#"
script {{
    use aptos_framework::aptos_coin;
    use aptos_framework::aptos_governance;

    fun main(core_resources: &signer) {{
        let framework_signer = aptos_governance::get_signer_testnet_only(core_resources, @0x1);
        aptos_coin::delegate_mint_capability(framework_signer, @{});
        let framework_signer = aptos_governance::get_signer_testnet_only(core_resources, @0x1);
        aptos_coin::delegate_mint_capability(framework_signer, @{});
    }}
}}
"#,
        account1.address(),
        account2.address(),
    );
    assert_eq!(
        Some(true),
        cli.run_script(root_cli_index, &delegate_script)
            .await
            .unwrap()
            .success
    );

    let claim_txn = account1.sign_with_transaction_builder(
        info.transaction_factory()
            .payload(aptos_stdlib::aptos_coin_claim_mint_capability()),
    );
    info.client().submit_and_wait(&claim_txn).await.unwrap();
    let claim_txn = account2.sign_with_transaction_builder(
        info.transaction_factory()
            .payload(aptos_stdlib::aptos_coin_claim_mint_capability()),
    );
    info.client().submit_and_wait(&claim_txn).await.unwrap();
    let mint_txn = account1.sign_with_transaction_builder(
        info.transaction_factory()
            .payload(aptos_stdlib::aptos_coin_mint(account1.address(), 10000)),
    );
    info.client().submit_and_wait(&mint_txn).await.unwrap();

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
