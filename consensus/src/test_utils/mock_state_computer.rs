// Copyright © Aptos Foundation
// Parts of the project are originally copyright © Meta Platforms, Inc.
// SPDX-License-Identifier: Apache-2.0

use crate::{
    error::StateSyncError, payload_manager::TPayloadManager, state_replication::StateComputer,
    transaction_deduper::TransactionDeduper, transaction_shuffler::TransactionShuffler,
};
use anyhow::{anyhow, Result};
use aptos_crypto::HashValue;
use aptos_types::{
    block_executor::config::BlockExecutorConfigFromOnchain, epoch_state::EpochState,
    ledger_info::LedgerInfoWithSignatures, on_chain_config::OnChainConsensusConfig,
};
use std::{sync::Arc, time::Duration};

<<<<<<< HEAD
pub struct EmptyStateComputer {
    executor_channel: UnboundedSender<OrderedBlocks>,
}

impl EmptyStateComputer {
    pub fn new(executor_channel: UnboundedSender<OrderedBlocks>) -> Self {
        Self { executor_channel }
    }
}

#[async_trait::async_trait]
impl StateComputer for EmptyStateComputer {
    async fn commit(
        &self,
        blocks: Vec<Arc<PipelinedBlock>>,
        commit: LedgerInfoWithSignatures,
        call_back: StateComputerCommitCallBackType,
    ) -> ExecutorResult<()> {
        assert!(!blocks.is_empty());

        if self
            .executor_channel
            .clone()
            .send(OrderedBlocks {
                ordered_blocks: blocks,
                ordered_proof: commit,
                callback: call_back,
            })
            .await
            .is_err()
        {
            debug!("Failed to send to buffer manager, maybe epoch ends");
        }

        Ok(())
    }

    async fn sync_for_duration(
        &self,
        _duration: Duration,
    ) -> Result<LedgerInfoWithSignatures, StateSyncError> {
        Err(StateSyncError::from(anyhow!(
            "sync_for_duration() is not supported by the EmptyStateComputer!"
        )))
    }

    async fn sync_to_target(
        &self,
        _target: LedgerInfoWithSignatures,
    ) -> Result<(), StateSyncError> {
        Ok(())
    }

    fn new_epoch(
        &self,
        _: &EpochState,
        _: Arc<dyn TPayloadManager>,
        _: Arc<dyn TransactionShuffler>,
        _: BlockExecutorConfigFromOnchain,
        _: Arc<dyn TransactionDeduper>,
        _: bool,
        _: bool,
        _: Option<HashValue>,
    ) {
    }

    fn end_epoch(&self) {}
}

=======
>>>>>>> e33e3c1b
/// Random Compute Result State Computer
/// When compute(), if parent id is random_compute_result_root_hash, it returns Err(Error::BlockNotFound(parent_block_id))
/// Otherwise, it returns a dummy StateComputeResult with root hash as random_compute_result_root_hash.
pub struct RandomComputeResultStateComputer {
    random_compute_result_root_hash: HashValue,
}

impl RandomComputeResultStateComputer {
    pub fn new() -> Self {
        Self {
            random_compute_result_root_hash: HashValue::random(),
        }
    }

    pub fn get_root_hash(&self) -> HashValue {
        self.random_compute_result_root_hash
    }
}

#[async_trait::async_trait]
impl StateComputer for RandomComputeResultStateComputer {
    async fn sync_for_duration(
        &self,
        _duration: Duration,
    ) -> Result<LedgerInfoWithSignatures, StateSyncError> {
        Err(StateSyncError::from(anyhow!(
            "sync_for_duration() is not supported by the RandomComputeResultStateComputer!"
        )))
    }

    async fn sync_to_target(
        &self,
        _target: LedgerInfoWithSignatures,
    ) -> Result<(), StateSyncError> {
        Ok(())
    }

    fn new_epoch(
        &self,
        _: &EpochState,
        _: Arc<dyn TPayloadManager>,
        _: Arc<dyn TransactionShuffler>,
        _: BlockExecutorConfigFromOnchain,
        _: Arc<dyn TransactionDeduper>,
        _: bool,
<<<<<<< HEAD
        _: Option<HashValue>,
=======
>>>>>>> e33e3c1b
        _: OnChainConsensusConfig,
        _: u8,
        _: Arc<crate::network::NetworkSender>,
    ) {
    }

    fn end_epoch(&self) {}
}
