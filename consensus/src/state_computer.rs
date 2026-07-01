// Copyright © Aptos Foundation
// Parts of the project are originally copyright © Meta Platforms, Inc.
// SPDX-License-Identifier: Apache-2.0

use crate::{
    block_preparer::BlockPreparer, error::StateSyncError, monitor, network::NetworkSender,
    payload_manager::TPayloadManager, pipeline::pipeline_builder::PipelineBuilder,
    state_replication::StateComputer, transaction_deduper::TransactionDeduper,
    transaction_shuffler::TransactionShuffler, txn_notifier::TxnNotifier,
};
use anyhow::Result;
use aptos_config::config::BlockTransactionFilterConfig;
use aptos_consensus_notifications::ConsensusNotificationSender;
use aptos_consensus_types::common::Round;
use aptos_executor_types::BlockExecutorTrait;
use aptos_infallible::RwLock;
use aptos_logger::prelude::*;
use aptos_types::{
    account_address::AccountAddress, block_executor::config::BlockExecutorConfigFromOnchain,
    epoch_state::EpochState, ledger_info::LedgerInfoWithSignatures,
    on_chain_config::OnChainConsensusConfig, validator_signer::ValidatorSigner,
};
use fail::fail_point;
use std::{boxed::Box, sync::Arc, time::Duration};
use tokio::sync::Mutex as AsyncMutex;

#[derive(Clone, Copy, Debug, Eq, PartialEq, PartialOrd, Ord, Hash)]
struct LogicalTime {
    epoch: u64,
    round: Round,
}

impl LogicalTime {
    pub fn new(epoch: u64, round: Round) -> Self {
        Self { epoch, round }
    }
}

#[derive(Clone)]
struct MutableState {
    validators: Arc<[AccountAddress]>,
    payload_manager: Arc<dyn TPayloadManager>,
    transaction_shuffler: Arc<dyn TransactionShuffler>,
    block_executor_onchain_config: BlockExecutorConfigFromOnchain,
    transaction_deduper: Arc<dyn TransactionDeduper>,
    is_randomness_enabled: bool,
    consensus_onchain_config: OnChainConsensusConfig,
    persisted_auxiliary_info_version: u8,
    network_sender: Arc<NetworkSender>,
}

/// Basic communication with the Execution module;
/// implements StateComputer traits.
pub struct ExecutionProxy {
    executor: Arc<dyn BlockExecutorTrait>,
    txn_notifier: Arc<dyn TxnNotifier>,
    state_sync_notifier: Arc<dyn ConsensusNotificationSender>,
    write_mutex: AsyncMutex<LogicalTime>,
    txn_filter_config: Arc<BlockTransactionFilterConfig>,
    state: RwLock<Option<MutableState>>,
    enable_pre_commit: bool,
}

impl ExecutionProxy {
    pub fn new(
        executor: Arc<dyn BlockExecutorTrait>,
        txn_notifier: Arc<dyn TxnNotifier>,
        state_sync_notifier: Arc<dyn ConsensusNotificationSender>,
        txn_filter_config: BlockTransactionFilterConfig,
        enable_pre_commit: bool,
    ) -> Self {
        Self {
            executor,
            txn_notifier,
            state_sync_notifier,
            write_mutex: AsyncMutex::new(LogicalTime::new(0, 0)),
            txn_filter_config: Arc::new(txn_filter_config),
            state: RwLock::new(None),
            enable_pre_commit,
        }
    }

    pub fn pipeline_builder(&self, commit_signer: Arc<ValidatorSigner>) -> PipelineBuilder {
        let MutableState {
            validators,
            payload_manager,
            transaction_shuffler,
            block_executor_onchain_config,
            transaction_deduper,
            is_randomness_enabled,
            consensus_onchain_config,
            persisted_auxiliary_info_version,
            network_sender,
        } = self
            .state
            .read()
            .as_ref()
            .cloned()
            .expect("must be set within an epoch");

        let block_preparer = Arc::new(BlockPreparer::new(
            payload_manager.clone(),
            self.txn_filter_config.clone(),
            transaction_deduper.clone(),
            transaction_shuffler.clone(),
        ));
        PipelineBuilder::new(
            block_preparer,
            self.executor.clone(),
            validators,
            block_executor_onchain_config,
            is_randomness_enabled,
            commit_signer,
            self.state_sync_notifier.clone(),
            payload_manager,
            self.txn_notifier.clone(),
            self.enable_pre_commit,
            &consensus_onchain_config,
            persisted_auxiliary_info_version,
            network_sender,
        )
    }
}

#[async_trait::async_trait]
impl StateComputer for ExecutionProxy {
    /// Best effort state synchronization for the specified duration
    async fn sync_for_duration(
        &self,
        duration: Duration,
    ) -> Result<LedgerInfoWithSignatures, StateSyncError> {
        // Grab the logical time lock
        let mut latest_logical_time = self.write_mutex.lock().await;

        // Before state synchronization, we have to call finish() to free the
        // in-memory SMT held by the BlockExecutor to prevent a memory leak.
        self.executor.finish();

        // Inject an error for fail point testing
        fail_point!("consensus::sync_for_duration", |_| {
            Err(anyhow::anyhow!("Injected error in sync_for_duration").into())
        });

        // Invoke state sync to synchronize for the specified duration. Here, the
        // ChunkExecutor will process chunks and commit to storage. However, after
        // block execution and commits, the internal state of the ChunkExecutor may
        // not be up to date. So, it is required to reset the cache of the
        // ChunkExecutor in state sync when requested to sync.
        let result = monitor!(
            "sync_for_duration",
            self.state_sync_notifier.sync_for_duration(duration).await
        );

        // Update the latest logical time
        if let Ok(latest_synced_ledger_info) = &result {
            let ledger_info = latest_synced_ledger_info.ledger_info();
            let synced_logical_time = LogicalTime::new(ledger_info.epoch(), ledger_info.round());
            *latest_logical_time = synced_logical_time;
        }

        // Similarly, after state synchronization, we have to reset the cache of
        // the BlockExecutor to guarantee the latest committed state is up to date.
        self.executor.reset()?;

        // Return the result
        result.map_err(|error| {
            let anyhow_error: anyhow::Error = error.into();
            anyhow_error.into()
        })
    }

    /// Synchronize to a commit that is not present locally.
    async fn sync_to_target(&self, target: LedgerInfoWithSignatures) -> Result<(), StateSyncError> {
        // Grab the logical time lock and calculate the target logical time
        let mut latest_logical_time = self.write_mutex.lock().await;
        let target_logical_time =
            LogicalTime::new(target.ledger_info().epoch(), target.ledger_info().round());

        // Before state synchronization, we have to call finish() to free the
        // in-memory SMT held by BlockExecutor to prevent a memory leak.
        self.executor.finish();

        // The pipeline phase already committed beyond the target block timestamp, just return.
        if *latest_logical_time >= target_logical_time {
            warn!(
                "State sync target {:?} is lower than already committed logical time {:?}",
                target_logical_time, *latest_logical_time
            );
            return Ok(());
        }

        // This is to update QuorumStore with the latest known commit in the system,
        // so it can set batches expiration accordingly.
        // Might be none if called in the recovery path, or between epoch stop and start.
        if let Some(inner) = self.state.read().as_ref() {
            let block_timestamp = target.commit_info().timestamp_usecs();
            inner
                .payload_manager
                .notify_commit(block_timestamp, Vec::new());
        }

        // Inject an error for fail point testing
        fail_point!("consensus::sync_to_target", |_| {
            Err(anyhow::anyhow!("Injected error in sync_to_target").into())
        });

        // Invoke state sync to synchronize to the specified target. Here, the
        // ChunkExecutor will process chunks and commit to storage. However, after
        // block execution and commits, the internal state of the ChunkExecutor may
        // not be up to date. So, it is required to reset the cache of the
        // ChunkExecutor in state sync when requested to sync.
        let result = monitor!(
            "sync_to_target",
            self.state_sync_notifier.sync_to_target(target).await
        );

        // Update the latest logical time
        *latest_logical_time = target_logical_time;

        // Similarly, after state synchronization, we have to reset the cache of
        // the BlockExecutor to guarantee the latest committed state is up to date.
        self.executor.reset()?;

        // Return the result
        result.map_err(|error| {
            let anyhow_error: anyhow::Error = error.into();
            anyhow_error.into()
        })
    }

    fn new_epoch(
        &self,
        epoch_state: &EpochState,
        payload_manager: Arc<dyn TPayloadManager>,
        transaction_shuffler: Arc<dyn TransactionShuffler>,
        block_executor_onchain_config: BlockExecutorConfigFromOnchain,
        transaction_deduper: Arc<dyn TransactionDeduper>,
        randomness_enabled: bool,
<<<<<<< HEAD
        virtual_genesis_block_id: Option<HashValue>,
=======
>>>>>>> e33e3c1b
        consensus_onchain_config: OnChainConsensusConfig,
        persisted_auxiliary_info_version: u8,
        network_sender: Arc<NetworkSender>,
    ) {
        // Reset the executor with the virtual genesis block ID if provided
        if let Some(virtual_genesis_id) = virtual_genesis_block_id {
            self.executor
                .reset_with_virtual_genesis(Some(virtual_genesis_id))
                .expect("Failed to reset executor with virtual genesis");
        } else {
            self.executor.reset().expect("Failed to reset executor");
        }

        *self.state.write() = Some(MutableState {
            validators: epoch_state
                .verifier
                .get_ordered_account_addresses_iter()
                .collect::<Vec<_>>()
                .into(),
            payload_manager,
            transaction_shuffler,
            block_executor_onchain_config,
            transaction_deduper,
            is_randomness_enabled: randomness_enabled,
            consensus_onchain_config,
            persisted_auxiliary_info_version,
            network_sender,
        });
    }

    // Clears the epoch-specific state. Only a sync_to call is expected before calling new_epoch
    // on the next epoch.
    fn end_epoch(&self) {
        self.state.write().take();
    }
}
<<<<<<< HEAD

#[tokio::test]
async fn test_commit_sync_race() {
    use crate::{
        error::MempoolError, payload_manager::DirectMempoolPayloadManager,
        transaction_deduper::create_transaction_deduper,
        transaction_shuffler::create_transaction_shuffler,
    };
    use aptos_config::config::transaction_filter_type::Filter;
    use aptos_consensus_notifications::Error;
    use aptos_infallible::Mutex;
    use aptos_types::{
        aggregate_signature::AggregateSignature,
        block_executor::partitioner::ExecutableBlock,
        block_info::BlockInfo,
        contract_event::ContractEvent,
        ledger_info::LedgerInfo,
        on_chain_config::{TransactionDeduperType, TransactionShufflerType},
        transaction::{SignedTransaction, Transaction, TransactionStatus},
    };

    struct RecordedCommit {
        time: Mutex<LogicalTime>,
    }

    impl BlockExecutorTrait for RecordedCommit {
        fn committed_block_id(&self) -> HashValue {
            HashValue::zero()
        }

        fn reset(&self) -> Result<()> {
            Ok(())
        }

        fn execute_block(
            &self,
            _block: ExecutableBlock,
            _parent_block_id: HashValue,
            _onchain_config: BlockExecutorConfigFromOnchain,
        ) -> ExecutorResult<StateComputeResult> {
            Ok(StateComputeResult::new_dummy())
        }

        fn execute_and_update_state(
            &self,
            _block: ExecutableBlock,
            _parent_block_id: HashValue,
            _onchain_config: BlockExecutorConfigFromOnchain,
        ) -> ExecutorResult<()> {
            todo!()
        }

        fn ledger_update(
            &self,
            _block_id: HashValue,
            _parent_block_id: HashValue,
        ) -> ExecutorResult<StateComputeResult> {
            todo!()
        }

        fn pre_commit_block(&self, _block_id: HashValue) -> ExecutorResult<()> {
            todo!()
        }

        fn commit_ledger(
            &self,
            ledger_info_with_sigs: LedgerInfoWithSignatures,
        ) -> ExecutorResult<()> {
            *self.time.lock() = LogicalTime::new(
                ledger_info_with_sigs.ledger_info().epoch(),
                ledger_info_with_sigs.ledger_info().round(),
            );
            Ok(())
        }

        fn finish(&self) {}
    }

    #[async_trait::async_trait]
    impl TxnNotifier for RecordedCommit {
        async fn notify_failed_txn(
            &self,
            _txns: &[SignedTransaction],
            _compute_results: &[TransactionStatus],
        ) -> Result<(), MempoolError> {
            Ok(())
        }
    }

    #[async_trait::async_trait]
    impl ConsensusNotificationSender for RecordedCommit {
        async fn notify_new_commit(
            &self,
            _transactions: Vec<Transaction>,
            _subscribable_events: Vec<ContractEvent>,
        ) -> std::result::Result<(), Error> {
            Ok(())
        }

        async fn sync_for_duration(
            &self,
            _duration: std::time::Duration,
        ) -> std::result::Result<LedgerInfoWithSignatures, Error> {
            Err(Error::UnexpectedErrorEncountered(
                "sync_for_duration() is not supported by the RecordedCommit!".into(),
            ))
        }

        async fn sync_to_target(
            &self,
            target: LedgerInfoWithSignatures,
        ) -> std::result::Result<(), Error> {
            let logical_time =
                LogicalTime::new(target.ledger_info().epoch(), target.ledger_info().round());
            if logical_time <= *self.time.lock() {
                return Err(Error::NotificationError(
                    "Decreasing logical time".to_string(),
                ));
            }
            *self.time.lock() = logical_time;
            Ok(())
        }
    }

    let callback = Box::new(move |_a: &[Arc<PipelinedBlock>], _b: LedgerInfoWithSignatures| {});
    let recorded_commit = Arc::new(RecordedCommit {
        time: Mutex::new(LogicalTime::new(0, 0)),
    });
    let generate_li = |epoch, round| {
        LedgerInfoWithSignatures::new(
            LedgerInfo::new(
                BlockInfo::random_with_epoch(epoch, round),
                HashValue::zero(),
            ),
            AggregateSignature::empty(),
        )
    };
    let executor = ExecutionProxy::new(
        recorded_commit.clone(),
        recorded_commit.clone(),
        recorded_commit.clone(),
        &tokio::runtime::Handle::current(),
        TransactionFilter::new(Filter::empty()),
        true,
    );

    executor.new_epoch(
        &EpochState::empty(),
        Arc::new(DirectMempoolPayloadManager {}),
        create_transaction_shuffler(TransactionShufflerType::NoShuffling),
        BlockExecutorConfigFromOnchain::new_no_block_limit(),
        create_transaction_deduper(TransactionDeduperType::NoDedup),
        false,
        false,
        None,
    );
    executor
        .commit(vec![], generate_li(1, 1), callback.clone())
        .await
        .unwrap();
    executor
        .commit(vec![], generate_li(1, 10), callback)
        .await
        .unwrap();
    assert!(executor.sync_to_target(generate_li(1, 8)).await.is_ok());
    assert_eq!(*recorded_commit.time.lock(), LogicalTime::new(1, 10));
    assert!(executor.sync_to_target(generate_li(2, 8)).await.is_ok());
    assert_eq!(*recorded_commit.time.lock(), LogicalTime::new(2, 8));
}
=======
>>>>>>> e33e3c1b
