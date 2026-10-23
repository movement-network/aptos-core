// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

// Keep replay in its own integration-test process: concurrent VM executions share
// a process-global speculative log buffer.

use aptos_cached_packages::aptos_stdlib;
use aptos_crypto::{HashValue, PrivateKey};
use aptos_executor::chunk_executor::ChunkExecutor;
use aptos_executor_test_helpers::{
    gen_block_id, gen_ledger_info_with_sigs, integration_test_impl::create_db_and_executor,
};
use aptos_executor_types::{
    BlockExecutorTrait, ChunkExecutorTrait, TransactionReplayer, VerifyExecutionMode,
};
use aptos_types::{
    account_config::aptos_test_root_address,
    block_metadata::BlockMetadata,
    state_store::state_key::StateKey,
    test_helpers::transaction_test_helpers::{
        get_test_signed_transaction as get_test_signed_transaction_with_gas,
        TEST_BLOCK_EXECUTOR_ONCHAIN_CONFIG,
    },
    transaction::{
        signature_verified_transaction::into_signature_verified_block, Transaction, WriteSetPayload,
    },
    validator_signer::ValidatorSigner,
    write_set::TransactionWrite,
};
use aptos_vm::aptos_vm::AptosVMBlockExecutor;
use std::sync::Arc;

fn test_genesis_with_zero_min_gas_price() -> (Transaction, Vec<aptos_vm_genesis::TestValidator>) {
    let (change_set, validators) =
        aptos_vm_genesis::test_genesis_change_set_and_validators(Some(1));
    let (write_set, events) = change_set.into_inner();
    // The smoke swarm permits zero-gas transactions; preserve all other genesis defaults.
    let gas_schedule_key =
        StateKey::on_chain_config::<aptos_types::on_chain_config::GasScheduleV2>().unwrap();
    let mut write_set = write_set.into_mut();
    let gas_schedule_write = write_set.as_inner_mut().get_mut(&gas_schedule_key).unwrap();
    let mut gas_schedule = bcs::from_bytes::<aptos_types::on_chain_config::GasScheduleV2>(
        gas_schedule_write.bytes().unwrap(),
    )
    .unwrap();
    gas_schedule
        .entries
        .iter_mut()
        .find(|(name, _)| name == "txn.min_price_per_gas_unit")
        .unwrap()
        .1 = 0;
    gas_schedule_write.set_bytes(bcs::to_bytes(&gas_schedule).unwrap().into());

    (
        Transaction::GenesisTransaction(WriteSetPayload::Direct(
            aptos_types::transaction::ChangeSet::new(write_set.freeze().unwrap(), events),
        )),
        validators,
    )
}

#[test]
#[cfg_attr(feature = "consensus-only-perf-test", ignore)]
fn test_replay_retries_at_historical_block_boundary() {
    let (genesis, validators) = test_genesis_with_zero_min_gas_price();
    let genesis_key = &aptos_vm_genesis::GENESIS_KEYPAIR.0;
    let signer = ValidatorSigner::new(
        validators[0].data.owner_address,
        Arc::new(validators[0].consensus_key.clone()),
    );

    let source_path = aptos_temppath::TempPath::new();
    source_path.create_as_dir().unwrap();
    let (_, source_db, source_executor, _) =
        create_db_and_executor(source_path.path(), &genesis, false);

    let recipient =
        aptos_types::account_address::AccountAddress::from_hex_literal("0xcafe").unwrap();
    let paid_mint = Transaction::UserTransaction(get_test_signed_transaction_with_gas(
        aptos_test_root_address(),
        0,
        genesis_key,
        genesis_key.public_key(),
        Some(aptos_stdlib::aptos_coin_mint(recipient, 1)),
        4_000_000_000,
        100,
        None,
    ));
    let zero_price_mint = Transaction::UserTransaction(get_test_signed_transaction_with_gas(
        aptos_test_root_address(),
        1,
        genesis_key,
        genesis_key.public_key(),
        Some(aptos_stdlib::aptos_coin_mint(recipient, 1)),
        4_000_000_000,
        0,
        None,
    ));
    let force_end_epoch = Transaction::UserTransaction(get_test_signed_transaction_with_gas(
        aptos_test_root_address(),
        2,
        genesis_key,
        genesis_key.public_key(),
        Some(aptos_stdlib::aptos_governance_force_end_epoch_test_only()),
        4_000_000_000,
        100,
        None,
    ));

    let mut parent_block_id = source_executor.committed_block_id();
    for (index, transaction) in [paid_mint, zero_price_mint].into_iter().enumerate() {
        let block_id = gen_block_id((index + 1) as u8);
        let output = source_executor
            .execute_block(
                (block_id, into_signature_verified_block(vec![transaction])).into(),
                parent_block_id,
                TEST_BLOCK_EXECUTOR_ONCHAIN_CONFIG,
            )
            .unwrap();
        assert!(
            output.compute_status_for_input_txns().iter().all(|status| {
                matches!(
                    status,
                    aptos_types::transaction::TransactionStatus::Keep(
                        aptos_types::transaction::ExecutionStatus::Success
                    )
                )
            }),
            "mint block execution failed: {:?}",
            output.compute_status_for_input_txns(),
        );
        let ledger_info =
            gen_ledger_info_with_sigs(1, &output, block_id, std::slice::from_ref(&signer));
        source_executor
            .commit_blocks(vec![block_id], ledger_info)
            .unwrap();
        parent_block_id = source_executor.committed_block_id();
    }

    // `force_end_epoch_test_only` only produces a reconfiguration after a real block prologue
    // advances time. Keep this as its own block so the source proof carries an EoE ledger info.
    let epoch_block_id = gen_block_id(3);
    let epoch_block = into_signature_verified_block(vec![
        Transaction::BlockMetadata(BlockMetadata::new(
            epoch_block_id,
            0,
            1,
            signer.author(),
            vec![0],
            vec![],
            300_000_001,
        )),
        force_end_epoch,
    ]);
    let epoch_output = source_executor
        .execute_block(
            (epoch_block_id, epoch_block).into(),
            parent_block_id,
            TEST_BLOCK_EXECUTOR_ONCHAIN_CONFIG,
        )
        .unwrap();
    assert!(epoch_output.has_reconfiguration());
    let epoch_ledger_info = gen_ledger_info_with_sigs(
        1,
        &epoch_output,
        epoch_block_id,
        std::slice::from_ref(&signer),
    );
    source_executor
        .commit_blocks(vec![epoch_block_id], epoch_ledger_info)
        .unwrap();

    let source_reader = source_db.reader.clone();
    let last_version = source_reader.get_latest_ledger_info_version().unwrap();
    let source_ledger_info = source_reader.get_latest_ledger_info().unwrap();
    assert!(source_ledger_info.ledger_info().ends_epoch());
    let transaction_list = source_reader
        .get_transactions(1, last_version, last_version, false)
        .unwrap();
    let transaction_infos = transaction_list.proof.transaction_infos.clone();
    let write_sets = source_reader
        .get_write_set_iterator(1, last_version)
        .unwrap()
        .collect::<Result<Vec<_>, _>>()
        .unwrap();
    let event_vecs = source_reader
        .get_events_iterator(1, last_version)
        .unwrap()
        .collect::<Result<Vec<_>, _>>()
        .unwrap();

    let zero_price_mint_index = transaction_list
        .transactions
        .iter()
        .position(|transaction| {
            matches!(transaction, Transaction::UserTransaction(txn) if txn.gas_unit_price() == 0)
        })
        .unwrap();
    let replay_path = aptos_temppath::TempPath::new();
    replay_path.create_as_dir().unwrap();
    let (_, replay_db, _, _) = create_db_and_executor(replay_path.path(), &genesis, false);
    let replayer = ChunkExecutor::<AptosVMBlockExecutor>::new(replay_db.clone());
    let replay_chunk_count = replayer
        .enqueue_chunks(
            transaction_list.transactions.clone(),
            transaction_infos.clone(),
            write_sets.clone(),
            event_vecs.clone(),
            &VerifyExecutionMode::verify_all(),
        )
        .unwrap();
    assert!(replay_chunk_count >= 2);
    for _ in 0..replay_chunk_count {
        replayer.update_ledger().unwrap();
    }
    for index in 0..replay_chunk_count {
        let committed_version = replayer.commit().unwrap();
        if index + 1 == replay_chunk_count {
            assert_eq!(committed_version, last_version);
        } else {
            assert!(committed_version < last_version);
        }
    }
    assert_eq!(
        replay_db
            .reader
            .get_accumulator_root_hash(last_version)
            .unwrap(),
        source_reader
            .get_accumulator_root_hash(last_version)
            .unwrap(),
    );

    // State sync executes transaction chunks rather than replaying and applying the historical
    // outputs. Keep this in the same isolated process as the replay test because the VM shares a
    // process-global speculative log buffer.
    let state_sync_path = aptos_temppath::TempPath::new();
    state_sync_path.create_as_dir().unwrap();
    let (_, state_sync_db, _, _) = create_db_and_executor(state_sync_path.path(), &genesis, false);
    let state_sync_executor = ChunkExecutor::<AptosVMBlockExecutor>::new(state_sync_db.clone());
    state_sync_executor
        .execute_chunk(transaction_list.clone(), &source_ledger_info, None)
        .unwrap();
    state_sync_executor.commit_chunk().unwrap();
    assert_eq!(
        state_sync_db
            .reader
            .get_accumulator_root_hash(last_version)
            .unwrap(),
        source_reader
            .get_accumulator_root_hash(last_version)
            .unwrap(),
    );

    // A state-sync batch can start in the tail of one historical block and cross into the next.
    // First synchronize only the leading transaction, then request its remaining checkpoint plus
    // the first transaction of the following block.
    let first_block_end = transaction_list
        .transactions
        .iter()
        .enumerate()
        .find_map(|(index, transaction)| {
            if index > 0 && transaction.is_block_start() {
                Some(index)
            } else if transaction.is_non_reconfig_block_ending() {
                Some(index + 1)
            } else {
                None
            }
        })
        .unwrap();
    assert!(first_block_end > 1);
    let leading_partial_path = aptos_temppath::TempPath::new();
    leading_partial_path.create_as_dir().unwrap();
    let (_, leading_partial_db, _, _) =
        create_db_and_executor(leading_partial_path.path(), &genesis, false);
    let leading_partial_executor =
        ChunkExecutor::<AptosVMBlockExecutor>::new(leading_partial_db.clone());
    let leading_prefix = source_reader
        .get_transactions(1, (first_block_end - 1) as u64, last_version, false)
        .unwrap();
    leading_partial_executor
        .execute_chunk(leading_prefix, &source_ledger_info, None)
        .unwrap();
    leading_partial_executor.commit_chunk().unwrap();
    let leading_partial = source_reader
        .get_transactions(first_block_end as u64, 2, last_version, false)
        .unwrap();
    let leading_partial_last_version = leading_partial.first_transaction_version.unwrap()
        + leading_partial.transactions.len() as u64
        - 1;
    leading_partial_executor
        .execute_chunk(leading_partial, &source_ledger_info, None)
        .unwrap();
    leading_partial_executor.commit_chunk().unwrap();
    assert_eq!(
        leading_partial_db
            .reader
            .get_accumulator_root_hash(leading_partial_last_version)
            .unwrap(),
        source_reader
            .get_accumulator_root_hash(leading_partial_last_version)
            .unwrap(),
    );

    // Conversely, a batch can end before the source block's checkpoint. It must still commit
    // exactly the requested prefix without adding a boundary transaction of its own.
    let trailing_partial_path = aptos_temppath::TempPath::new();
    trailing_partial_path.create_as_dir().unwrap();
    let (_, trailing_partial_db, _, _) =
        create_db_and_executor(trailing_partial_path.path(), &genesis, false);
    let trailing_partial_executor =
        ChunkExecutor::<AptosVMBlockExecutor>::new(trailing_partial_db.clone());
    let first_block = source_reader
        .get_transactions(1, first_block_end as u64, last_version, false)
        .unwrap();
    trailing_partial_executor
        .execute_chunk(first_block, &source_ledger_info, None)
        .unwrap();
    trailing_partial_executor.commit_chunk().unwrap();
    let trailing_partial = source_reader
        .get_transactions((first_block_end + 1) as u64, 1, last_version, false)
        .unwrap();
    assert!(!trailing_partial.transactions[0].is_non_reconfig_block_ending());
    let trailing_partial_last_version = trailing_partial.first_transaction_version.unwrap();
    trailing_partial_executor
        .execute_chunk(trailing_partial, &source_ledger_info, None)
        .unwrap();
    trailing_partial_executor.commit_chunk().unwrap();
    assert_eq!(
        trailing_partial_db
            .reader
            .get_accumulator_root_hash(trailing_partial_last_version)
            .unwrap(),
        source_reader
            .get_accumulator_root_hash(trailing_partial_last_version)
            .unwrap(),
    );

    let corrupted_path = aptos_temppath::TempPath::new();
    corrupted_path.create_as_dir().unwrap();
    let (_, corrupted_db, _, _) = create_db_and_executor(corrupted_path.path(), &genesis, false);
    let mut corrupted_transaction_infos = transaction_infos.clone();
    let transaction_info = &transaction_infos[zero_price_mint_index];
    corrupted_transaction_infos[zero_price_mint_index] =
        aptos_types::transaction::TransactionInfo::new(
            transaction_info.transaction_hash(),
            HashValue::sha3_256_of(b"corrupted transaction info"),
            transaction_info.event_root_hash(),
            transaction_info.state_checkpoint_hash(),
            transaction_info.gas_used(),
            transaction_info.status().clone(),
        );

    let corrupted_state_sync_path = aptos_temppath::TempPath::new();
    corrupted_state_sync_path.create_as_dir().unwrap();
    let (_, corrupted_state_sync_db, _, _) =
        create_db_and_executor(corrupted_state_sync_path.path(), &genesis, false);
    let corrupted_state_sync_executor =
        ChunkExecutor::<AptosVMBlockExecutor>::new(corrupted_state_sync_db);
    let mut corrupted_transaction_list = transaction_list.clone();
    corrupted_transaction_list.proof.transaction_infos = corrupted_transaction_infos.clone();
    assert!(corrupted_state_sync_executor
        .execute_chunk(corrupted_transaction_list, &source_ledger_info, None)
        .is_err());

    let corrupted_replayer = ChunkExecutor::<AptosVMBlockExecutor>::new(corrupted_db);
    assert!(corrupted_replayer
        .enqueue_chunks(
            transaction_list.transactions.clone(),
            corrupted_transaction_infos.clone(),
            write_sets.clone(),
            event_vecs.clone(),
            &VerifyExecutionMode::verify_all(),
        )
        .is_err());

    let lazy_quit_path = aptos_temppath::TempPath::new();
    lazy_quit_path.create_as_dir().unwrap();
    let (_, lazy_quit_db, _, _) = create_db_and_executor(lazy_quit_path.path(), &genesis, false);
    let lazy_quit_replayer = ChunkExecutor::<AptosVMBlockExecutor>::new(lazy_quit_db);
    let lazy_quit = VerifyExecutionMode::verify_all().set_lazy_quit(true);
    lazy_quit_replayer
        .enqueue_chunks(
            transaction_list.transactions,
            corrupted_transaction_infos,
            write_sets,
            event_vecs,
            &lazy_quit,
        )
        .unwrap();
    assert!(lazy_quit.seen_error());
}
